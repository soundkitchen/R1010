# R-1010 UI Design Notes

## 目的

このドキュメントは、`r1010-design.pen` に含まれる現在の UI デザインの意図をまとめたものです。アプリ全体の仕様は `docs/app-spec.md` を参照します。

前提は以下です。

- バックエンドの実時間演奏は `scsynth` が担う
- GUI は編集対象の表示と操作に集中する
- `sclang` は必要なコード生成や初期化のために存在するが、通常 UI で前面には出さない
- デバッグ向けの低レベル OSC ログは通常 UI から外す

## デザイン方針

- 全体はミニマルで、操作対象と状態表示の責務を分ける
- パターン編集の文脈はメインエリア上部に集約する
- グローバルな再生状態はヘッダー側に置く
- シーケンサーは文字詰めではなく実グリッドで見せる
- シーケンサーの 16 列は中央ペインの残り幅を均等に使って広がる
- 右ペインは選択中 voice の編集に集中させる
- `engine` と `preset` は離散選択、その他は連続パラメータとして分ける

## 通常画面

`r1010-design.pen` には、通常画面として次の 2 つがあります。

- `R-1010 Minimal Dark`
- `R-1010 Minimal Light`

### ヘッダー構成

- 左: 製品名 `R-1010`
- 中央: 読み取り専用の状態表示  
  例: `playing / scsynth_online`
- 右: transport bar
  `play` と `stop` は別ボタンではなく単一トグル
  例: `stop / bpm 128 / swing 54`
  `Space` キーでも同じトグル操作を行う

### メインエリア構成

- 左ペイン: `voices`
  現在編集対象になりうる音色一覧
- 中央ペイン: シーケンサー本体
  - `pattern` セレクタ
  - `page` セグメント切替
  - `clear`
  - 16 ステップのグリッド
- 右ペイン:
  - `selected_voice`
  - `engine`
  - `preset`
  - `tap`
  - `attack`
  - `decay`
  - `tune`
  - `low pass`
  - `resonance`
  - `drive`

## シーケンサーの考え方

シーケンサーは、モノスペース文字列で疑似的に揃えるのではなく、実オブジェクトのグリッドとして構成しています。

- 上段の step 番号
- 各列の縦ガイド
- 各トラックのステップマーカー

これらは同じ座標系で配置し、列ズレが起きないようにしています。

現在の実装では、固定幅の 16 マスではなく、中央ペインの残り幅を 16 分割して step が横に広がります。右側に余白を残さず、シーケンサー面を埋める見せ方を採用しています。

step をクリックした時の現在の挙動は次の通りです。

- セルは即座に点灯 / 消灯する
- 点灯した step は accent color で強く表示する
- step を ON にしたタイミングで、その voice を単発 preview する

## Pattern / Page の役割

### Pattern

- メインエリア上部に置く
- 現在編集中の pattern を表す
- クリックで selector を開く

### Page

- Pattern の隣に置く
- 1-4 の切替をその場で行う
- Pattern と同じ「編集文脈」の UI として扱う

## 右ペインの役割

通常画面の右ペインは、選択中 voice の `voice editor` として使います。

- `selected_voice`
  現在編集対象のボイス名
- `engine`
  音の生成ファミリー
- `preset`
  その engine に対する初期値セット
- `tap`
  現在の音色を単発で preview する
- `attack` / `decay`
  現在は ADSR ではなく AD を採用
- `tune`
- `low pass`
- `resonance`
- `drive`

以前あった `osc_state` は削除しました。理由は、`scsynth` が再生の真実を持つ前提では、通常 UI に低レベルの送信ログを常設する意味が薄いためです。

`Pattern Layer` と `BPM / Swing Open` の各 board でも、この右ペイン構成を共通で使います。

`engine` と `preset` は行クリックで開く selector として扱います。どちらも右ペイン内で、その行の直下に小さなポップオーバーを出す想定です。

## Pattern Selector のバリエーション

Pattern の開いた状態は、別 board として保持しています。

- `R-1010 Pattern Layer Dark`
- `R-1010 Pattern Layer Light`

この board では以下を分離しています。

- base layer: 通常画面
- overlay layer: pattern menu

目的は、通常状態と `Menu` を開いた状態を別レイヤーで比較できるようにすることです。

## Transport 編集 UI の考え方

Transport まわりは、通常画面ではコンパクトな bar として表示し、編集状態は個別ポップオーバーで扱います。

### 採用バリエーション

- `R-1010 BPM Open Dark`
- `R-1010 BPM Open Light`
- `R-1010 Swing Open Dark`
- `R-1010 Swing Open Light`

この案では、`bpm` と `swing` は個別に開きます。`bpm` を押したときは `bpm` 用のポップオーバーだけが開き、`swing` を押したときは `swing` 用のポップオーバーだけが開く前提です。

共通ルールは以下です。

- 押した control の直下に出る
- `bpm` と `swing` で同じ位置・同じサイズの window を使う
- window 幅はやや広めに取り、スライダーの微調整をしやすくする
- 現在値の表示自体を直接編集できる見せ方にする
- スライダーと現在値の直接編集を併用する
- 許容レンジは popover 最下部ではなく、ヘッダー行の右側に出す
- `bpm` と `swing` は同じ視覚ルールで見せる
- どちらもクリック可能な control と分かるよう、通常表示でも同じテキスト色で統一する
- fullscreen scrim は置かず、macOS の popover に近い軽い見え方にする

直接入力の操作感は、現在の実装では次の通りです。

- 入力中は最低値や最高値に自動補完しない
- `Return` で確定する
- フォーカス離脱で確定する
- popover を閉じた時に確定する

このいずれかで入力を確定し、その時点で範囲外なら補正します。

## Voice Selector のバリエーション

`engine` と `preset` の開いた状態も、別 board として保持しています。

- `R-1010 Engine Open Dark`
- `R-1010 Engine Open Light`
- `R-1010 Preset Open Dark`
- `R-1010 Preset Open Light`

この案では、`engine` と `preset` はどちらも右ペイン内で個別に開きます。

- `engine`
  生成方式を選ぶ selector
  例: `kick` なら `analog`, `fm`, `sample`
- `preset`
  その engine 用の初期値セットを選ぶ selector
  例: `kick / analog` なら `round`, `punch`, `sub`, `hard`

## Settings 画面

`r1010-design.pen` には、Settings 用の次の 2 board も追加しています。

- `R-1010 Settings Dark`
- `R-1010 Settings Light`

Settings 画面は、将来的に項目が増えても積みやすいように、コンパクトな設定行として見せます。

- `color mode` という1行の設定項目を置く
- 値はプルダウンから `system / light / dark` を選ぶ
- デフォルト値は `system`
- `system` は macOS の appearance に追従する
- dark board では `dark`、light board では `light` を選択済みの例として見せる
- 説明文は常設せず、設定リストとして密度を優先する

## 現時点で採用している UI 意図

通常画面の情報設計としては、次の整理を採用しています。

- `pattern / page`: メインの編集文脈
- `play / stop / bpm / swing`: transport の操作文脈
- `playing / scsynth_online`: 読み取り専用の状態文脈
- `selected_voice / engine / preset / sound params`: voice 編集文脈

## 未確定事項

次の項目は、今後の実装方針と合わせて再検討する余地があります。

- playhead を通常 UI にどこまで見せるか
- next pattern / queued pattern を表示するか
- `shortcuts` を別 UI として残すか
