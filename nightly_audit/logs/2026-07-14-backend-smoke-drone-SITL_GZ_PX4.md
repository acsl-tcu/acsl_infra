# Nightly Audit 2026-07-14 — backend-smoke-drone-SITL_GZ_PX4 (host: ruth)

## 結論
**smoke 未実施 (ブロック・前夜と同一構図)。PR なし。実機・稼働中コンテナには一切触れていない。**
2026-07-13 の監査 (SITL_PX4) で要相談としたハーネス欠陥 A が未修正のまま残っており、
今夜も headless セッションで `dup` が実行不能だった。加えてホスト使用中 (B)・checkout 非 main (C) も再発。
静的プリフライトのみ実施し、欠陥は検出しなかった。

## 今夜の対象
- deploy = drone (`~/drone`, project drone2) / mode = SITL_GZ_PX4 (targets.conf 許可内 ✓)

## ブロッカー (すべて 2026-07-13 レポートの再発 — 修正されていない)

### A. 【要相談・最重要・再発】`dup` rc=127 — ハーネスが acsl env を用意しないまま
- `dup -h` → **rc=127 `command not found`** を今夜 **2回再現** (フレークではない)。
- `run_nightly_audit.sh` には前回提案の env export (SMOKE_PATH 確定後に
  `ACSL_WORK_DIR` / `ACSL_ROS2_DIR` / PATH を export) が**入っていない**ことを目視確認
  (`run_nightly_audit.sh:121-144` — SMOKE_PATH 確定後そのままプロンプト構築へ進む)。
- 回避不能の確認 (今夜追加で検討した分):
  - `dup` の実体は `~/drone/.acsl/commands/scripts/dup`。冒頭で `$ACSL_ROS2_DIR/bashrc` を
    自己 source する設計だが、絶対パス起動は allow 前綴 `Bash(dup *)` に一致せず deny。
  - `audit_settings.json` の bash 系 allow は `Bash(bash -n *)` のみ → Write したラッパー
    スクリプトの `bash <file>` 実行も不可。source / export / env 前置は前回確認済みの deny。
- 影響: **backend-smoke 系は cron 起動では引き続き全滅**。ハーネス修正がマージされるまで
  rotation の backend-smoke 行は消化不能 (毎晩このレポートが再生産されるだけ)。
- 修正案は 2026-07-13 レポート A 節のとおり (env export 3行)。監査ハーネス自身の変更で
  セッション内では実効性検証 (claude 再起動) ができないため、今回も自動 PR は自重。

### B. 【再発】ホスト使用中 — rover スタック + isaac-sim が Up
- `docker ps` (監査時点): `slam_toolbox` / `yolo` / `nav2` / `rover` / `rf_tf` / `rf_building`
  (Up 3h), `isaac-sim` (Up 13h), `switchbot` (Up 14h)。
- SITL_GZ_PX4 は Gazebo Harmonic + PX4 SITL + MAVROS2 の 3 コンテナ構成で GPU/CPU/DDS を
  使うため、仮に dup が動いても今夜は bringup すべきでなかった。既存コンテナには読み取り
  (`docker ps`) 以外触れていない。後始末対象なし (何も起動していない)。

### C. 【再発】稼働 checkout が main でない + dirty
- `~/drone` は branch `feature/yc-bld7-flythrough`、
  変更あり (`isaac_sim/notebooks/setup_isaac_yc_bld7.ipynb` M + 未追跡 2 件)。
- この状態で smoke しても main に対する証拠にならない (前回 C と同じ)。

## 実施できた範囲 (静的プリフライト — 読み取りのみ・欠陥なし)
- `project_launch.sh:264` に `SITL_GZ_PX4` 分岐あり ✓ — 3 コンテナ構成
  (`dup px4_sitl` → UDP 14540 待ち → `dup mavros2` → HEARTBEAT 待ち → `dup drone2`)。
- default config `config/px4/sitl_gazebo.yaml` 存在・整合 ✓ — `backend: "mavros"`,
  `fcu_url: udp://:14540@...` は launch 側の `wait_for_udp_listen px4_sitl 14540` と一致。
- `dockerfiles/dockerfile.px4_sitl` / `dockerfile.mavros2` / `dockerfile.drone2` 存在 ✓。
- `docker-compose_px4_sitl.yml` 存在 ✓ / `gazebo_sitl/worlds` 存在 ✓。
- 静的レベルの欠落 (config 不在・分岐消失・dockerfile 欠落) は検出せず。

## 開いた PR
なし (0 本)。

## 捨てた候補
- なし (bringup 不能のため動的指摘の候補自体が発生せず。静的欠陥も検出せず)。

## 次回アクション (人間向け)
1. **(前回から持ち越し・最優先)** `run_nightly_audit.sh` に env export を入れ、手動リハーサルで
   `dup -h` が通るのを確認する。直るまで rotation の backend-smoke 行は空振りし続ける。
2. B (使用中ゲート) / C (branch・dirty ゲート) の要否判断も持ち越し。
3. 直ったら `backend-smoke-drone-SITL_PX4` と本件 `backend-smoke-drone-SITL_GZ_PX4` を再走。

---
*夜間自動監査 (nightly-audit) が生成。merge 判断・ハーネス変更はレビューのこと。*
