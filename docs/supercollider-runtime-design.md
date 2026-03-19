# R-1010 SuperCollider Runtime Design

## 目的

このドキュメントは、`R-1010` における `sclang` / `scsynth` の扱いと、アプリ起動時の依存解決、実行時の責務分離、シーケンサー実行系の設計方針をまとめたものです。

前提は次の通りです。

- `sclang` と `scsynth` は必須依存
- アプリ起動時に両方を解決できなければ継続しない
- timing の主導権は `scsynth` に持たせる
- GUI は pattern 編集と高レベル操作を担当する
- GUI は必要な SuperCollider コードを生成し、`sclang` に渡す
- `sclang` はコード評価、初期化、`SynthDef` 構築、`scsynth` への橋渡しを担当する
- 音色編集は `engine` / `preset` / per-voice parameter の 3 層で扱う

## 現在の実装スナップショット

2026-03-16 時点で、runtime 周りの現行実装は次の通りです。

- `sclang` / `scsynth` の自動探索は実装済み
- 起動失敗時は、未検出と runtime 初期化失敗でアラートを分けている
- `scsynth` は空き UDP ポートを自動探索して起動する
- `scsynth` 起動時は CoreAudio から既定出力デバイス名と current sample rate を取得し、`-H` / `-S` で明示する
- `sclang` は bootstrap script を `.load` で読み込み、常駐ブリッジとして使う
- `play` / `stop` / `setTempo` / `setSwing` / `setPatternPage` / `setSteps` / `setVoiceEngine` / `setVoicePreset` / `setVoiceParams` / `previewVoice` は実装済み
- boot 中に更新された `stateStore.isPlaying` は、ready 遷移前に runtime transport へ reconcile する
- GUI は pattern bank を保持し、現在選択中の page だけを runtime へ同期する
- 再生中の page / pattern / clear は、inactive step buffer bank へ全 voice snapshot を書いてから active bank を切り替える
- `R1010_SKIP_RUNTIME_BOOT=1` で preview mode に入り、runtime を立ち上げずに UI を確認できる

未実装の大きな項目は、queued pattern、accent / velocity、`current_step` telemetry の UI 利用です。

## 設計原則

- 再生中の step 進行は GUI で駆動しない
- GUI は 16 分音符ごとの発音を直接スケジュールしない
- GUI から送るのは transport、pattern 更新、page 切替、mute、パラメータ変更などの高レベル命令に限定する
- `sclang` は長寿命のブリッジプロセスとして扱う
- `scsynth` は長寿命のオーディオエンジンとして扱う
- 通常 UI に見せる状態は原則として `scsynth_online` を中心にする
- `engine` は `SynthDef` family を選び、`preset` は初期値セットを選ぶ
- `preset` 適用後も各パラメータは個別に上書きできる

## 全体構成

実行時の主要コンポーネントは次の 6 つです。

- `AppBootstrapCoordinator`
  アプリ起動時の依存解決と初期化全体を統括する
- `SuperColliderLocator`
  `sclang` と `scsynth` の所在を解決する
- `SuperColliderRuntime`
  `sclang` / `scsynth` の起動、監視、停止を管理する
- `SclangBridge`
  GUI からの高レベル命令を `sclang` に渡す
- `EngineScriptBuilder`
  初期化用コード、`SynthDef`、ランタイム更新コードを生成する
- `SequencerStateStore`
  GUI 側の pattern / page / voice / transport 状態を保持する

責務分担は次の通りです。

- GUI
  - UI 描画
  - パターン編集
  - transport 操作
  - 依存未検出時のアラート表示
  - SuperCollider 向けコード生成
  - 高レベル命令の送信
- `sclang`
  - SuperCollider コードの評価
  - `SynthDef` の登録
  - bus / buffer / group の初期化
  - `scsynth` への接続と命令送出
  - GUI から来た命令の翻訳
- `scsynth`
  - 音声生成
  - サーバ側 clock / sequencer 実行
  - step 進行
  - swing を含む timing 制御
  - 必要最小限の telemetry 送信

## 起動時の依存解決

### 方針

Homebrew 版か手動インストール版かを分岐するのではなく、最終的に使う `sclang` と `scsynth` の実体を解決します。

初期探索順は次の通りです。

1. 環境変数オーバーライド
   - `R1010_SCLANG_PATH`
   - `R1010_SCSYNTH_PATH`
2. `/Applications/SuperCollider.app`
3. `~/Applications/SuperCollider.app`
4. `/opt/homebrew/Caskroom/supercollider/*/SuperCollider.app`
5. `/usr/local/Caskroom/supercollider/*/SuperCollider.app`
6. `/opt/homebrew/bin/{sclang,scsynth}`
7. `/usr/local/bin/{sclang,scsynth}`

`.app` バンドルを見つけた場合は、次の固定パスを解決対象にします。

- `Contents/MacOS/sclang`
- `Contents/Resources/scsynth`

### 検証条件

起動継続には次の条件を満たす必要があります。

- `sclang` が存在する
- `scsynth` が存在する
- 両方が実行可能である

いずれかを満たさない場合は、アラート表示後に終了します。

### 未検出時の挙動

アラート内容は次を想定します。

- タイトル
  `SuperCollider is required`
- 本文
  `R-1010 を起動するには SuperCollider のインストールが必要です。公式ダウンロード、または Homebrew の "brew install --cask supercollider" を利用してください。`
- アクション
  `Quit`

オプションで `Open Download Page` を追加してもよいですが、初版では `Quit` のみで十分です。

## ランタイム初期化シーケンス

起動時のシーケンスは次のようにします。

1. `AppBootstrapCoordinator` が `SuperColliderLocator` を呼ぶ
2. `sclang` / `scsynth` を解決できなければアラート表示後に終了
3. `SuperColliderRuntime` が `scsynth` を起動する
4. `scsynth` のオンライン確認が取れたら `sclang` を起動する
5. GUI は `EngineScriptBuilder` で bootstrap 用コードを生成し、`Application Support/R-1010/Generated/` に書き出す
6. `sclang` は `"path".load;` で bootstrap script を評価する
7. bootstrap 内で `SynthDef` 登録、group / bus / buffer 初期化、sequencer 構築を行う
8. GUI は現在の project state を runtime へ初期同期する
9. boot 中に `play / stop` が押されていれば、`stateStore.isPlaying` の最終値へ transport を reconcile する
10. ここまで成功したら GUI は通常状態に遷移する
11. どこかで失敗したらアラート表示後に終了する

初版では、起動に失敗した状態で UI を開き続けるより、明確に終了する方が扱いやすいです。

### 現在の起動実装の補足

- `scsynth` の優先ポートは `57140...57148`
- それが埋まっている場合は `57149...57520` から空きポートを探索する
- `address in use` では自動で次の候補ポートを試す
- audio 初期化エラーの切り分けのため、まず `-I 0` 付きの入力無効プロファイルを試し、その後に通常プロファイルを試す
- 既定出力デバイス名と sample rate を解決できた場合は `-H <device-name>` / `-S <sample-rate>` を優先して付与し、起動先デバイスと pitch / tempo のずれを減らす
- `-H` / `-S` 付きプロファイルで起動できない場合は `-H` のみ、`-S` のみ、最後に未指定プロファイルへ段階的にフォールバックする
- boot 中に transport が複数回トグルされた場合も、ready 遷移前に最後の希望状態へ収束させる
- アプリ終了時には `sclang` / `scsynth` を停止する

## コード生成の方針

### 基本方針

GUI は raw OSC を都度組み立てて `scsynth` を直接叩くのではなく、必要な SuperCollider コードを生成して `sclang` に渡します。

ただし、すべての操作を生コード文字列で都度送るのは避けます。運用上は次の 2 系統に分けます。

- 起動時コード
  bootstrap、`SynthDef`、初期 group / bus / buffer 定義
- 実行時命令
  transport、pattern 更新、mute、tempo 変更などの構造化コマンド

### 起動時コード

起動時には GUI が bootstrap コードを生成します。内容は次を含みます。

- `scsynth` 接続設定
- `SynthDef` 群
- voice ごとのノード構成
- sequencer 用 group / bus / buffer
- サーバ側 clock / step driver
- GUI 通信用の最小限の応答処理
- voice role ごとの engine family 定義
- preset ごとの初期 parameter set 定義

bootstrap は毎回の起動で再生成してよいです。出力先は `Application Support/R-1010/Generated/` のような専用領域を想定します。

### 実行時命令

実行中は GUI から `SclangBridge` に対して構造化コマンドを送ります。現在の実装コマンドは次です。

- `setTempo`
- `setSwing`
- `setPatternPage`
- `setSteps`
- `play`
- `stop`
- `setVoiceEngine`
- `setVoicePreset`
- `setVoiceParams`
- `previewVoice`

次は未実装です。

- `setVoiceMute`
- `reloadSynthDefs`

`SclangBridge` はこれを `sclang` 側の command handler に渡し、必要な buffer 更新やノード更新に変換します。

`setVoicePreset` は、対象 voice の現在 parameter をその preset の初期値でまとめて更新するコマンドとして扱います。その後の微調整は `setVoiceParams` で反映します。

`setPatternPage` は、選択中 page の全 voice step snapshot を 1 command で渡し、server 側では inactive bank に全 voice 分の buffer を書き込んでから sequencer synth の buffer 参照先を一括で切り替えます。これにより、再生中の page / pattern / clear で 1 tick だけ古い voice と新しい voice が混在する状態を避けます。

`setSteps` は単一 voice の step 編集用 command として残し、現在 active な bank のみを更新します。page / pattern の切替時は、常に `setPatternPage` が全 voice snapshot を上書きする前提です。

## 音色モデル

音色編集は次の 3 層に分けます。

- `voice role`
  `kick`, `snare`, `clap`, `closed_hat`, `open_hat` などの役割
- `engine`
  生成方式。実装上は `SynthDef` family
- `preset`
  その engine に対する初期値セット

その上で、各 voice は現在次の連続値 parameter を持ちます。

- `attack`
- `decay`
- `tune`
- `lowPass`
- `resonance`
- `drive`

現時点では ADSR ではなく AD を採用し、envelope parameter は `attack` と `decay` に絞ります。

### engine / preset の関係

- `engine`
  音の骨格を決める
- `preset`
  初期キャラクタを決める
- 各 parameter
  最終的な音作りを詰める

つまり、`preset` を選ぶと各 parameter はその preset の値に更新されますが、その後も GUI から個別に変更できます。

### voice role ごとの候補例

初版では、voice role ごとに許可する engine を分ける想定です。

- `kick`
  `analog`, `fm`, `sample`
- `snare`
  `analog`, `noise`, `fm`, `sample`
- `clap`
  `noise`, `sample`
- `closed_hat`, `open_hat`
  `metal`, `noise`, `sample`

`round` や `punch` のような名前は万能 engine 名ではなく、各 engine の中で使う preset 名として扱います。

## `sclang` ブリッジ設計

`sclang` は一回ごとの使い捨てではなく、長寿命の常駐ブリッジとして扱います。

役割は次の通りです。

- 起動時 bootstrap の評価
- GUI からの構造化コマンド受信
- コマンドを SuperCollider オブジェクト操作や OSC 送信に変換
- `scsynth` 側の初期化完了や軽量 telemetry の GUI 返却

GUI と `sclang` の通信方式は、初版ではローカル専用の単純な方式に絞ります。候補は次の 2 つです。

- 標準入出力ベースの line protocol
- localhost の OSC / UDP

実装初段では、起動と bootstrap の安定性を優先して標準入出力ベースの line protocol を採ります。

理由は次の通りです。

- bootstrap script をそのまま注入しやすい
- GUI 側の実装量を抑えて起動系を先に固められる
- `SclangBridge` の抽象を維持しておけば、将来 OSC に差し替えられる

現在は、起動時 bootstrap を file load し、実行時 command は `~r1010Command...value(...)` の 1 行関数呼び出しとして `stdin` に送っています。各 command には sentinel を付け、`sclang` 側の出力で完了確認を取ります。

## `scsynth` 主導のシーケンサー設計

### 原則

再生中の時間軸は `scsynth` に持たせます。

つまり、次は採用しません。

- GUI 側の timer による step 駆動
- GUI から各 step ごとに発音 OSC を送る方式
- `sclang` 側の言語クロックをマスターにする方式

### 実行モデル

`scsynth` 側に sequencer 用のサーバノードを作り、そこが step を進めます。

構成は次を想定します。

- clock driver
  - bpm と swing を受け取る
  - step trigger を生成する
- step counter
  - 16 step 単位で現在位置を進める
  - page や pattern の参照位置を決める
- per-voice trigger logic
  - 現在 step の gate / velocity / accent を読む
  - 該当 voice の `SynthDef` を発火する

step データは `scsynth` が読みやすい形で保持します。初版では buffer ベースを第一候補にします。

### buffer ベースを採る理由

- GUI から step 配列をまとめて更新しやすい
- `sclang` が buffer へ変換して `scsynth` に渡しやすい
- 再生中でも高レベル更新を反映しやすい
- voice 数が増えてもモデルを保ちやすい

初版のデータ単位は次を想定します。

- 1 pattern = 4 pages
- 1 page = 16 steps
- voice ごとに step 情報を保持

ただし現在の実装では、runtime が pattern bank 全体を保持しているわけではありません。

- GUI 側が全 pattern / page bank を保持する
- runtime が保持するのは、現在選択中 page の 16 step buffer
- `pattern` や `page` を切り替えた時は、GUI が現在選択中 page の全 voice 状態を再送する

step 情報は段階的に拡張できるようにします。

- 初版
  - gate
- 次段階
  - velocity
  - accent

## GUI 側の状態モデル

GUI は編集状態とランタイム状態を分けて持ちます。

### 編集状態

- `selectedPattern`
- `selectedPage`
- `selectedVoice`
- voice ごとの `engine`
- voice ごとの `preset`
- voice ごとの parameter
  - `attack`
  - `decay`
  - `tune`
  - `lowPass`
  - `resonance`
  - `drive`
- step データ

現在の実装では、GUI 側の `SequencerStateStore` が `pattern A01`, `pattern A02`, `pattern A03`, `pattern B01` を持ち、それぞれに `page 1-4` の step bank を保持します。

### ランタイム状態

- `dependencyStatus`
  - `missing`
  - `resolved`
- `engineStatus`
  - `idle`
  - `booting`
  - `ready`
  - `failed`
- `scsynthOnline`
- `transportState`
  - `playing`
  - `stopped`

通常 UI に強く出すのは `scsynthOnline` と `transportState` です。

## 更新反映ポリシー

GUI での編集結果は、毎 step のイベントではなく、状態更新としてエンジンに渡します。

### 反映種別

- 即時更新してよいもの
  - mute
  - bpm
  - swing
  - 非再生時の step 編集
- 量子的に反映したいもの
  - 再生中の pattern 切替
  - 再生中の page 切替
  - 将来の queued pattern

現在の実装では、次のように扱っています。

- step 編集は再生中でも即時で buffer 更新
- `pattern` / `page` 切替も現在は即時反映
- `pattern` / `page` 切替時は全 voice の steps / engine / preset / params を再同期

つまり、量子化された page / pattern 切替は今後の課題です。

## Telemetry 方針

通常 UI では低レベル通信ログを出しません。

ただし内部的には、必要最小限の telemetry は受け取れるようにしておきます。

候補は次です。

- `R1010_BOOTSTRAP_READY`
- `engine_error`
- `current_step`
- `transport_started`
- `transport_stopped`

`current_step` は playhead 表示を採用するときにのみ UI で使います。初版では内部利用に留めてもよいです。

## 障害時の扱い

起動前後の障害は、通常操作の問題として隠さず、明確に失敗として扱います。

### 即時終了するケース

- `sclang` / `scsynth` を解決できない
- `scsynth` の起動に失敗する
- `sclang` の起動に失敗する
- bootstrap に失敗して `R1010_BOOTSTRAP_READY` に到達しない

### 起動後に回復を試みてもよいケース

- telemetry の一時欠落
- 一部 voice の再構築失敗
- 将来の hot reload 失敗

ただし初版では、起動後の回復戦略を過剰に入れず、まずは起動成功パスを確実にします。

## 推奨モジュール分割

macOS アプリ側では次の単位に分けるのが扱いやすいです。

- `SuperColliderLocator`
  SuperCollider 実体の探索と検証
- `SuperColliderPaths`
  解決済み `sclang` / `scsynth` パスの値オブジェクト
- `AppBootstrapCoordinator`
  起動シーケンス全体の制御
- `SuperColliderRuntime`
  プロセスのライフサイクル管理
- `SclangBridge`
  GUI と `sclang` のコマンド送受信
- `EngineScriptBuilder`
  bootstrap / `SynthDef` / runtime code 生成
- `SequencerStateStore`
  GUI 編集状態の管理
- `EngineCommand`
  GUI からエンジンへ送る高レベル命令の定義

## 実装状況

### 実装済み

- `SuperColliderLocator`
- 起動時アラートと終了
- `scsynth` / `sclang` の起動と停止
- bootstrap script 生成と完了確認
- `SclangBridge`
- buffer ベースの current page step 管理
- `play` / `stop` / `setTempo` / `setSwing`
- `setVoiceEngine` / `setVoicePreset` / `setVoiceParams`
- `previewVoice`

### 部分実装

- page / pattern 切替
  GUI 側 bank と current page 再同期は実装済み
  専用 command と量子化切替は未実装

### 未実装

- velocity / accent
- queued pattern
- playhead telemetry の UI 表示
- voice mute
- hot reload / voice 再構築

## 初版で明確に避けるもの

- GUI timer をマスターにすること
- GUI から各 step を都度発音させること
- 起動時に `brew` コマンドへ依存すること
- 通常 UI に低レベル OSC ログを常設すること
- すべての操作を raw code string の逐次 eval に寄せること

## 現時点の結論

`R-1010` の起動系と演奏系は、次の一本化した設計で進めるのが妥当です。

- 起動時に `sclang` / `scsynth` を自動探索する
- 見つからなければアラート表示後に終了する
- 見つかったら `scsynth` を先に立ち上げ、次に `sclang` を常駐ブリッジとして起動する
- GUI は bootstrap と `SynthDef` を生成して `sclang` に渡す
- 再生中の master sequence は `scsynth` に持たせる
- GUI は高レベル状態更新だけを送る

この形であれば、起動依存チェック、SuperCollider 連携、jitter を避ける再生設計を矛盾なく接続できます。
