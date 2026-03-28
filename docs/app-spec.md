# R-1010 App Specification

## 目的

`R-1010` は、クラシックなリズムマシンに着想を得たミニマルなステップシーケンサーアプリです。GUI でパターン編集と transport 操作を行い、SuperCollider を使って実時間の音声生成を行います。

このドキュメントは、これまでの議論で固まったアプリ仕様の土台をまとめたものです。画面構成の詳細は `docs/ui-design.md` を参照します。

## 現在の実装スナップショット

2026-03-16 時点の実装状態は次の通りです。

- SuperCollider 依存の自動探索と起動失敗時アラートは実装済み
- `sclang` / `scsynth` の live runtime 起動と bootstrap は実装済み
- `scsynth` 起動時は macOS の既定出力デバイス名と current sample rate を解決し、hardware device / hardware sample rate として明示する
- `R1010 Preview` scheme では runtime を起動せず UI だけ確認できる
- transport の `play / stop` は単一トグルで、`Space` キーでも切り替えられる
- boot 中に発行された `play / stop` は、runtime が ready になる直前に最終意図へ reconcile される
- シーケンサーは `pattern` ごとに `page 1-4` を保持し、step 編集と `clear` ができる
- 再生中の `pattern` / `page` / `clear` は、選択中 page の step snapshot を原子的に切り替える
- voice editor では `engine` / `preset` / `tap` / 6 パラメータを操作できる
- Settings は別ウィンドウで、`color mode` を `system / light / dark` から選べる

未実装の大きな項目は、playhead 表示、queued pattern、accent / velocity、`scsynth` からの current step telemetry です。

## プロダクト方針

- UI はミニマルに保つ
- 実時間演奏の安定性を見た目より優先する
- 編集文脈と状態表示の責務を明確に分ける
- 通常 UI に低レベルのデバッグ情報は出さない
- UI 上では `808` / `909` の表記は使わない

## システム構成

主要な構成要素は次の 3 つです。

- GUI アプリ
- `sclang`
- `scsynth`

責務は次のように分けます。

- GUI アプリ
  パターン編集、画面表示、ユーザー操作、状態表示を担当する
- `sclang`
  SuperCollider 言語の評価、コード生成結果の実行、初期化、`SynthDef` の準備を担当する
- `scsynth`
  音声生成と再生中の timing を担当する

## SuperCollider に関する前提

- `scsynth` は SuperCollider 言語そのものを解釈しない
- SuperCollider のコード文字列をそのまま `scsynth` に送って実行することはできない
- SuperCollider 言語の評価や `SynthDef` の構築には `sclang` が必要
- `scsynth` は主に OSC と登録済みの定義を受けて動作する

## Timing 方針

再生が始まった後の timing の主導権は `scsynth` に持たせます。これは jitter を抑えるためです。

採用方針は次の通りです。

- 再生中のマスターは `scsynth`
- GUI は 16 分音符ごとに即時 OSC を連打して発音を駆動しない
- GUI は pattern 変更、page 変更、mute、パラメータ変更などの高レベル操作を送る
- timing に依存する step 進行や発音スケジュールは `scsynth` 側に寄せる

## 状態監視の考え方

通常 UI で重要なのは `scsynth` がオンラインかどうかです。

そのため、通常画面では次を採用します。

- 表示する状態
  `scsynth_online`
- 表示しない状態
  `osc_linked`
  `sclang` の死活そのもの

補足です。

- `sclang` の内部監視自体は実装上必要になりうる
- ただし、それを通常 UI のステータスとして見せる必要はない

## アプリの主要機能

現時点で想定している主要機能は次の通りです。

- パターンの選択
- page の切替
- 16 step の打ち込み
- 現在 page の `clear`
- voice の選択
- voice ごとの `engine` 選択
- voice ごとの `preset` 選択
- voice の単発 preview (`tap`)
- transport の再生 / 停止
- `Space` キーによる再生 / 停止
- `bpm` の変更
- `swing` の変更
- voice ごとの `attack` / `decay` の変更
- voice ごとの `tune` の変更
- voice ごとの `low pass` / `resonance` の変更
- voice ごとの `drive` の変更
- `scsynth_online` の表示
- `color mode` の変更

## 画面構成

通常画面の情報設計は次の通りです。

- 左
  `voices`
- 中央
  シーケンサー本体
- 右
  voice editor

ヘッダー構成は次の通りです。

- 左
  製品名 `R-1010`
- 中央
  読み取り専用ステータス
  例: `playing / scsynth_online`
- 右
  transport bar
  `play` / `stop` は単一トグル
  例: `stop / bpm 128 / swing 54`

## Pattern / Page

`pattern` と `page` は編集文脈の UI です。

- `pattern`
  メインエリア上部に置く
  クリックで selector を開く
- `page`
  `pattern` の隣に置く
  1-4 をその場で切り替える

右上ヘッダーには `pattern` を重複表示しません。`pattern` の操作起点はメインエリア側に集約します。

現在の実装では、GUI 側が `pattern -> page -> voice -> 16 steps` の bank を保持し、選択中の `pattern / page` を runtime へ即時同期します。

- 初期パターンは `pattern A01`, `pattern A02`, `pattern A03`, `pattern B01`
- `pattern` 切替と `page` 切替は、現在は量子化せず即時反映
- 再生中の `pattern` 切替、`page` 切替、`clear` は、選択中 page の全 voice step snapshot を runtime へ 1 command で送り、server 側で buffer bank を切り替えて反映する
- 再生エンジンが保持するのは選択中 page の step 状態
- queued pattern / next pattern は未実装

## Transport

transport はグローバル操作として扱います。

- `play / stop`
  単一トグル
- `Space`
  `play / stop` のキーボードショートカット
- `bpm`
- `swing`

boot 中に `play / stop` が押された場合も、その時点の最終希望状態を保持し、起動時の初期 project sync 完了後に runtime transport へ反映します。

`bpm` と `swing` は、どちらも個別のポップオーバーで編集します。一括編集パネルは採用しません。

直接入力の挙動は次の通りです。

- 入力中の値はその場で clamp しない
- `Return` で確定する
- フォーカス離脱で確定する
- ポップオーバーを閉じた時に確定する

このいずれかの時点で確定し、許容レンジ外ならその時に補正します。

## Voice Editor

右ペインは、現在選択中の voice を編集する `voice editor` として使います。

現在の構成は次の通りです。

- `selected_voice`
  現在編集している voice 名
- `engine`
  音の生成ファミリーを選ぶ
- `preset`
  その engine に対する初期キャラクタを選ぶ
- `tap`
  現在の voice を単発で preview する
- `attack`
- `decay`
- `tune`
- `low pass`
- `resonance`
- `drive`

考え方としては、

- `engine`
  SynthDef の系統を選ぶ
- `preset`
  voice / engine ごとの初期値セットを選ぶ
- 各連続値パラメータ
  その engine / preset を詰める

です。

`engine` と `preset` は、どちらも行をクリックすると右ペイン内で個別ポップオーバーが開く想定です。

- `engine`
  例: `kick` なら `analog`, `fm`, `sample`
- `preset`
  例: `kick / analog` なら `round`, `punch`, `sub`, `hard`

## BPM / Swing 編集 UI

`bpm` と `swing` の編集 UI は同じルールで扱います。

- クリックすると control の直下に個別ポップオーバーが開く
- `bpm` と `swing` で同じ位置、同じサイズのポップオーバーを使う
- 現在値はそのまま直接編集できる見せ方にする
- スライダーでも変更できる
- 許容レンジはポップオーバー右上に表示する
- 通常の transport bar 上でも、`bpm` と `swing` は同じ視覚ルールでクリッカブルに見せる

## 右ペイン

通常 UI の右ペインは `voice editor` に集約します。以前の `shortcuts` と低レベル通信ログは、現時点のメイン画面から外します。

## Settings

Settings は別ウィンドウで、現時点では `color mode` のみを持つコンパクトな設定行です。

- `color mode` はプルダウンから `system / light / dark` を選ぶ
- デフォルトは `system`
- `system` では macOS の外観設定に追従する
- 将来的な設定追加を見越して、説明文よりも設定リストとしての密度を優先する

## デザインバリエーション

現在のデザインファイルには次の board があります。

- `R-1010 Minimal Dark`
- `R-1010 Minimal Light`
- `R-1010 Pattern Layer Dark`
- `R-1010 Pattern Layer Light`
- `R-1010 BPM Open Dark`
- `R-1010 BPM Open Light`
- `R-1010 Swing Open Dark`
- `R-1010 Swing Open Light`
- `R-1010 Engine Open Dark`
- `R-1010 Engine Open Light`
- `R-1010 Preset Open Dark`
- `R-1010 Preset Open Light`
- `R-1010 Settings Dark`
- `R-1010 Settings Light`

dark / light の 2 系統を維持しつつ、interaction の開いた状態を別 board として管理します。

## 非機能要件

- jitter を極力避けること
- UI はシンプルで視認性が高いこと
- モノスペース文字の見かけ合わせではなく、実グリッドで step 列を揃えること
- 通常 UI とデバッグ情報を分離すること

## 未確定事項

次の項目は今後の実装設計で再検討します。

- playhead を通常 UI にどこまで見せるか
- next pattern / queued pattern を表示するか
- `shortcuts` を別 UI として残すか
- accent と velocity のデータ構造をどう持つか
- `scsynth` から現在 step をどう返すか
