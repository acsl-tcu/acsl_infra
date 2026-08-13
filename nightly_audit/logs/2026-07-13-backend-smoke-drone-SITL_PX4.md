# Nightly Audit 2026-07-13 — backend-smoke-drone-SITL_PX4 (host: ruth)

## 結論
**smoke 未実施 (ブロック)。PR なし。実機・稼働中コンテナには一切触れていない。**
`dup` を起動できない環境で監査が走っており (下記 A)、さらにホストが使用中 (下記 B) だったため、
安全側に倒して bringup を行わなかった。ハーネス側の修正が必要 (要相談 3 件)。

## 今夜の対象
- deploy = drone (`~/drone`, project drone2) / mode = SITL_PX4 (targets.conf 許可内)

## ブロッカー (いずれも独立に bringup を不可能/不適切にした)

### A. 【要相談・最重要】headless 監査環境では `dup` が実行不能 (ハーネスの環境ギャップ)
- 症状: `dup -h` → **rc=127 `command not found`** (権限は `Bash(dup *)` で通っている。純粋に PATH の問題)。
- 原因: acsl コマンド群は `~/drone/.acsl/bashrc` の source で PATH/env
  (`ACSL_ROS2_DIR`, `ACSL_WORK_DIR` 等) に入る設計だが、
  `run_nightly_audit.sh` は claude 起動前にこれを用意しない
  (`run_nightly_audit.sh:223` の `cd "${ACSL_WORK_DIR:-$HOME}"` は既存 env 前提)。
  ユーザーの `~/.bashrc` / `~/.profile` にも acsl 行は無い (grep で確認)。
- セッション内での自力回復も全滅 (dontAsk allow は前綴一致のため):
  - `source .acsl/bashrc && dps` → **deny**
  - `export PATH=... && dps` → **deny**
  - `PATH=... ACSL_ROS2_DIR=... dps` (env 前置) → **deny**
  - `git -C <path> ...` も deny (`git log*` 等の前綴に不一致)。`cd` 単体→別呼び出しは可。
- 影響: **backend-smoke 系テーマは現構成の cron 起動では全滅する** (drone/rover の全 mode)。
  2026-06 の drone-SIM 試走が通ったのは、env が揃った対話シェルからの手動起動だったためと推測。
- 修正案 (要相談 — 監査ハーネス自身の変更のため自動 PR は自重):
  `run_nightly_audit.sh` で `SMOKE_PATH` 確定後、claude 起動前に
  ```bash
  export ACSL_WORK_DIR="$SMOKE_PATH"
  export ACSL_ROS2_DIR="$SMOKE_PATH/.acsl"
  export PATH="$SMOKE_PATH/.acsl/commands/scripts:$SMOKE_PATH/.acsl/docker/common/scripts:$PATH"
  ```
  を追加 (子プロセスの Bash tool シェルへ継承させる)。
  ※未検証の残リスク: Bash tool がプロファイル初期化で PATH をリセットする場合は効かない。
  次回 cron 前に `NIGHTLY_NO_SYNC=1 DRY_RUN=0` 相当の手動リハーサルで `dup -h` が通るか確認を推奨。
  `audit_settings.json` に `Bash(source *)` を足す案は権限境界が広がりすぎるため非推奨。

### B. 【要相談】ホストが使用中 — rover スタック + isaac-sim が稼働中だった
- `docker ps` (監査時点): `slam_toolbox` / `yolo` / `nav2` / `rover` / `rf_tf` / `isaac-sim`
  が Up 19〜31 分。誰かが rover / Isaac Sim を実行中。
- ここに drone SITL (quadrotor_sim + drone2) を bringup すると GPU/CPU/DDS で干渉しうるため、
  仮に dup が動いても今夜は起動すべきでなかった。**既存コンテナには読み取り以外触れていない**
  (docker rm 等は一切実行せず。後始末対象も無し — 当監査は何も起動していない)。
- 修正案: ハーネスに実行前ゲートを追加 —「対象 project 以外のコンテナが Up なら
  backend-smoke をスキップしてその旨をレポート/Slack に残す」。

### C. 【要相談】稼働 checkout が main でない + dirty
- `~/drone` は branch `feature/yc-bld7-flythrough`、未コミット変更あり
  (`isaac_sim/notebooks/setup_isaac_yc_bld7.ipynb` ほか)。
- backend-smoke は「現バージョン (main) の実起動検証」が趣旨だが、この状態で dup しても
  検証対象は main ではなくユーザーの WIP になる。指摘を出しても main に対する証拠にならない。
- 修正案: テーマ仕様に「deploy checkout が main 以外/dirty の晩はスキップ (レポートのみ)」を明文化。

## 実施できた範囲 (静的プリフライト — 読み取りのみ)
- targets.conf: drone×SITL_PX4 は許可 modes 内 ✓
- `~/drone/project_launch.sh:255` に `SITL_PX4` 分岐あり → `dup quadrotor_sim` + `dup drone2 px4/sitl_quadsim.yaml` ✓
- default config `~/drone/config/px4/sitl_quadsim.yaml` 存在 ✓
- 静的レベルでの欠落 (config 不在・分岐消失など) は検出せず。

## 開いた PR
なし (0 本)。ハーネス修正 (A/B) は監査基盤自身の変更 + セッション内で修正後の実効性を
検証できない (claude 再起動が必要) ため、driver の「検証できないものは PR にしない」に従い要相談とした。

## 捨てた候補
- 「`image drone2_x86 does NOT exists. Use image_drone2_x86`」類のフォールバック表示 — テーマ仕様どおり指摘対象外 (今回はそもそも未起動)。

## 次回アクション (人間向け)
1. A の env export を `run_nightly_audit.sh` に入れ、手動リハーサルで `dup -h` が通ることを確認。
2. B の稼働中ゲート、C のブランチ/dirty ゲートの要否を判断。
3. 直ったら rotation で `backend-smoke-drone-SITL_PX4` を再走させる (今夜分は未検証のまま)。

---
*夜間自動監査 (nightly-audit) が生成。merge 判断・ハーネス変更はレビューのこと。*
