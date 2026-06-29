# テーマ: ros2-structure (ROS2 / パイプライン構造の健全性)

> ★試走済み (2026-06)。下記「試走で分かったこと」を踏まえ、観点を実効的な3本柱に整理した。

## 対象リポ
- project_rf_rover, project_drone2

## 試走で分かったこと (2026-06 / docs-drift と同じく組込み Grep/Glob/Read だけで走査)
**この2リポは現状この軸では健全。素朴な「`module:` が解決するか」だけでは指摘ゼロになる。**
- `module:` 登録 = 計26件 (drone2 16 + rf_rover 10)。**全て** 実ファイル + クラス + `step()` に解決。
- config 内の yaml パス参照 (`include:` / phase `reference:` / `config_file:`) も**全て**実ファイルに解決。
- → 「壊れた参照を探す」だけでは健全なリポでは何も出ない。**価値を出すには下の3本柱で広く当てる**こと。

### 走査時の落とし穴 (再発防止メモ)
- **パッケージ名に数字** (`drone2`) が入る。grep の文字クラスは必ず `[a-z0-9_]` にする
  (`[a-z_]` だと drone2 系を全部取りこぼし、「rf_rover だけ10件」と誤検出する)。
- `grep '^class'` は **Markdown のコード例も拾う** (`tools/sensor/README.md` 内の `class GPSSensor:`)。
  クラス定義の照合は **`.py` のみ**対象にする (`.md` を除外)。
- 走査は **組込みの Grep/Glob/Read で行う** (docs-drift と同方針)。`python3 - <<heredoc` を
  `dontAsk` 下で使わない (許可リスト/stdin 起因で固まりうる。実害として無人実行が停止した)。

## 観点 (3本柱 — 静的に確証できるものだけ)

### 柱1: Tool 登録の解決性 (module: パス)
- 各 config の `- module: "<pkg>.tools.<stage>.<file>.<Class>"` について:
  - ファイル `packages/<pkg>/<pkg>/tools/<stage>/<file>.py` が存在するか
  - その `.py` に `class <Class>` が定義されているか
  - その Tool クラスが **`def step(`** を持つか (パイプライン契約 `step(context)->Result`)
- ソースルート: drone2=`project_drone2/packages/drone2/drone2`,
  rf_rover=`project_rf_rover/packages/rf_rover/rf_rover`。

### 柱2: config の yaml 参照解決性
- `include.<stage>: "X.yaml"` / phase `reference: "reference/Y.yaml"` / `config_file: "Z.yaml"` が
  **`config/` 起点で実在**するか。壊れていれば起動時失敗 = 確証ある指摘。
- 参照には2形式が共存する。両方扱うこと:
  - **パス形式** `reference: "reference/takeoff_reference_enu.yaml"` (拡張子付き → ファイル実在を見る)
  - **短名形式** `reference: "takeoff_reference"` / `estimator.type: "direct"` / `backend: "sim"`
    (拡張子なし → 名前→クラス/設定のレジストリ解決。下記スコープ注意)

### 柱3: 契約の整合 (踏み込み注意・多くは要相談)
- `@tool_contract` の inputs/outputs 宣言と実際の `get_upstream`/`get_cascade_input` の整合。
- sensor の parallel で `results[-1]` 前提が崩れる add_tool をしていないか (rf_rover の既知落とし穴)。
- cascade 各段の前段出力の受け渡し (取りこぼし/型不一致)。QoS/topic名/frame_id 不一致、
  publisher 未破棄、コールバックの重い処理。ament/package.xml と実依存の齟齬。
- これらは**実行時挙動に依存**しがちで静的確証が難しい。確証できなければ backend-smoke 側 or 要相談へ。

## 「指摘」とみなす条件
- **静的に確証できるものだけ**。柱1(module/class/step 欠落)・柱2(壊れた yaml パス参照) は
  high-confidence。柱3 は「宣言と使用の明白な不一致」レベルのみ。疑いどまりは backend-smoke へ回す。
- 健全な場合は**指摘ゼロで成功**。レポートに「26件中0件・全解決」のように網羅範囲を必ず記録する。

## 自動修正してよい範囲 / スコープ境界 (重要)
- **編集可**: `tools/` (Tool 実装) と `config/` (yaml)。タイポ修正・壊れたパス参照の修正など機械的なもの。
- **編集不可 = 要相談に回す**:
  - 名前→クラスのレジストリ (`backend:` / `estimator.type:` 等の短名解決) は **`drone_main.py`
    / `rover_main.py` (管理者のみ) や `common/` (読取専用・ローカル非存在)** に在る。
    短名参照の不整合は**フラグだけ立てて PR 化せず「要相談」**にする (修正対象が編集不可領域)。
  - `drone_main.py`/`rover_main.py` の登録ロジック、`common/`、Dockerfile は触らない。

## 検証方法
- 静的指摘 (柱1/柱2): 修正後に `python -m py_compile <file>` / yaml の参照先実在を再確認。
  可能なら `colcon build --packages-select <pkg>` まで。
- 柱3 で実行時確証が要るもの: SIM backend で該当ノードを起動して例外なく回るか
  (※ 実機安全則厳守。EXP は不可、HITL は受動のみ)。確証できなければ PR にせず要相談。
