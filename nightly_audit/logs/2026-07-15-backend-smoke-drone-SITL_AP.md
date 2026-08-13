# Nightly Audit 2026-07-15 — backend-smoke-drone-SITL_AP (host: ruth)

## 結論
**smoke 未実施 (ブロック・3晩連続で同一構図)。PR なし。実機・稼働中コンテナには一切触れていない。**
07-13 (SITL_PX4) / 07-14 (SITL_GZ_PX4) で要相談としたハーネス欠陥 A が未修正のまま残っており、
今夜も headless セッションで `dup` が実行不能。ホスト使用中 (B)・checkout 非 main (C) も継続。
SITL_AP 固有の静的プリフライトを実施し、起動を阻む静的欠陥は検出しなかった (軽微な stale コメント1件のみ・要相談)。

## 今夜の対象
- deploy = drone (`~/drone`, project drone2) / mode = SITL_AP (targets.conf 許可内 ✓)

## ブロッカー (すべて既報の再発 — 修正されていない)

### A. 【要相談・最重要・3晩連続】`dup` rc=127 — ハーネスが acsl env を用意しないまま
- `dup -h` → **rc=127 `command not found`** を今夜も **2回再現**。
- `run_nightly_audit.sh:121-144` に env export (SMOKE_PATH 確定後の `ACSL_WORK_DIR` /
  `ACSL_ROS2_DIR` / PATH export) が**依然入っていない**ことを grep で確認。
- 回避策は 07-13/07-14 に全滅確認済み (絶対パス起動 / source / export / env 前置 /
  ラッパー `bash <file>` すべて deny)。今夜は再試行していない (再訪不要と記録済み)。
- 影響: rotation の backend-smoke 行は毎晩空振り。**修正案は 2026-07-13 レポート A 節の
  env export 3行のまま**。監査ハーネス自身の変更はセッション内で実効性検証できないため自動 PR は自重。

### B. 【再発】ホスト使用中 — rover スタック + isaac-sim が Up
- `docker ps` (監査時点): `yolo` / `nav2` / `rover` / `rf_tf` / `slam_toolbox` (Up 17h),
  `isaac-sim` (Up 37h, healthy), `switchbot` (Up 38h)。
- SITL_AP は ardupilot_sitl + mavros2 + drone2 の 3 コンテナ・`network_mode: host` 構成のため、
  仮に dup が動いてもポート/DDS 競合リスクがあり今夜は bringup すべきでなかった。
  既存コンテナには読み取り (`docker ps`) 以外触れていない。後始末対象なし (何も起動していない)。

### C. 【再発】稼働 checkout が main でない + dirty
- `~/drone` は branch `feature/yc-bld7-flythrough`、変更あり
  (`isaac_sim/notebooks/setup_isaac_yc_bld7.ipynb` M + 未追跡 2 件: `.ipynb_checkpoints/`,
  `launcher/launch_dev.sh`)。main に対する smoke の証拠にならない状態が継続。

## 実施できた範囲 (SITL_AP 静的プリフライト — 読み取りのみ・起動阻害の欠陥なし)
- `project_launch.sh:317-343` に `SITL_AP` 分岐あり ✓ — 3 コンテナ構成
  (`dup ardupilot_sitl` → `wait_for_docker_log ardupilot_sitl "Flight battery"` →
  `dup mavros2` → `"Got HEARTBEAT"` 待ち → `dup drone2` + warmup 失敗時 restart)。
- default config `config/ardupilot/sitl.yaml` 存在・整合 ✓ — `backend: "mavros"`,
  `fcu_url: udp://:14555@` は `launcher/launch_ardupilot_sitl.sh:137` の
  `--uartA udpclient:127.0.0.1:14555` (MAVProxy なし Phase 1.5 構成) と一致。
- `docker-compose_ardupilot_sitl.yml` 存在 ✓ — image 明示 (`ardupilot_sitl_x86`) /
  `network_mode: host` / parm マウント `docs/ardupilot_sitl_gps.parm:/root/sitl.parm`。
  parm 実在 ✓、launcher 側の `/root/sitl.parm` 参照 (`launch_ardupilot_sitl.sh:77`) と一致 ✓。
- compose の command `/common/ros_launcher/launch_ardupilot_sitl.sh` は base compose
  (`.acsl/docker/docker-compose.yml:75`) の `$ACSL_WORK_DIR/launcher:/common/ros_launcher`
  マウントで `launcher/launch_ardupilot_sitl.sh` に解決 ✓ (一次調査では「実体なし」に見えたが反証済み)。
- `dockerfiles/dockerfile.ardupilot_sitl` 存在 ✓。include される config
  (`sensor/none.yaml`, `estimator/direct.yaml`, `controller/pid.yaml`, `reference/*_enu.yaml` 3種) 全て実在 ✓。
- `bash -n` OK: `project_launch.sh` / `launcher/launch_ardupilot_sitl.sh`。

## 開いた PR
なし (0 本)。

## 捨てた候補 / 要相談 (軽微)
- **反証済み**: 「compose command の `/common/ros_launcher/launch_ardupilot_sitl.sh` が実体なし」
  → base compose のマウントで解決される。指摘ではない。
- **要相談 (軽微・docs)**: `config/ardupilot/sitl.yaml:4-5` (origin/main も同一) のヘッダ手順が
  「1. 別端末で `./gazebo_sitl/start_ardupilot_sitl.sh`」と Phase 1 時代の手順を記載しているが、
  当該スクリプトは存在せず (gazebo_sitl/ には monitor_mavros.sh / restart_px4.sh / worlds のみ)、
  `project_launch.sh:415` は「SITL_AP は別端末起動不要」と明記 (Phase 1.5 で dup 内起動に移行済み)。
  誤解を招く stale コメントだが、テーマの指摘定義 (再現する起動失敗) 外・自動修正範囲も壁打ち中の
  ため PR は開かず要相談で残す。修正するなら手順 1 行を削除するだけの機械的変更。

## 次回アクション (人間向け)
1. **(3晩連続持ち越し・最優先)** `run_nightly_audit.sh` に env export を入れ、手動リハーサルで
   `dup -h` が通るのを確認する。直るまで rotation の backend-smoke 行は空振りし続ける
   (07-13/07-14/07-15 で SITL_PX4 / SITL_GZ_PX4 / SITL_AP を消化できず)。
2. B (ホスト使用中ゲート) / C (branch・dirty ゲート) の要否判断も持ち越し。
3. `config/ardupilot/sitl.yaml` の stale ヘッダ手順 (上記・要相談) の扱いを決める。
4. 直ったら SITL_PX4 / SITL_GZ_PX4 / 本件 SITL_AP を再走。

---
*夜間自動監査 (nightly-audit) が生成。merge 判断・ハーネス変更はレビューのこと。*
