# 2026-08-24 backend-smoke: drone × SITL_GZ_PX4 (host: ruth)

## テーマ / 範囲
- deploy = `~/drone` (project drone2), mode = `SITL_GZ_PX4` (PX4 SITL + Gazebo + MAVROS2 → `px4/sitl_gazebo.yaml`)
- ホスト空き確認 (`docker ps` 空) → `dup all SITL_GZ_PX4` を **2回** 実行し、各コンテナログ
  (`docker logs --tail N`、非 follow) で bringup を判定。console 操作・arm 等の駆動指令は一切送っていない。
- 使用イメージ: `kasekiguchi/acsl-common:px4_sitl_x86` (e7f6dee4e7e1) /
  `mavros2_x86` (592bdc34d8e9) / `image_drone2_x86` (drone2_x86 不在→フォールバック。既知の正常動作)。

## 結果: 2/2 PASS (再現する起動失敗なし)
両運転とも同一のクリーン起動:
- **px4_sitl**: Gazebo server ready → `px4_sitl.parm` 投入 → PX4 boot →
  `INFO [commander] Ready for takeoff!` 到達。GL エラー (`libGL error: failed to load driver: nouveau` 等) は
  ヘッドレス環境の GUI 描画分のみで、Gazebo server / PX4 本体は正常。
- **mavros2**: 全 plugin 初期化 → `CON: Got HEARTBEAT, connected. FCU: PX4 Autopilot`。traceback なし。
- **drone2**: `Drone ready: config_name=sitl_gazebo, backend=mavros, dt=0.02, hz=50` 到達。
  Python traceback / 例外なし。MavrosActuator warmup 4 サービス ready、
  `MavrosSensor: /mavros/state received` (0.60s / 1.40s) — mavros→drone2 のトピック疎通の受動的証拠。
- launcher 最終行: `[READY] SITL_GZ_PX4 ARM-READY -- PX4 preflight passed.` (両回)
- 後始末: `docker rm -f drone2 mavros2 px4_sitl` → `docker ps` 空を確認 (両回)。

## 要相談 (PR は開かない)
1. **`project_launch.sh` の UDP 14540 待ちが構造的に成立せず、毎回90秒を空費 (2/2 再現)**
   - 症状: 両運転で `[project_launch] WARNING: UDP 14540 not listening in px4_sitl after 90s; continuing anyway`。
     起動自体はその後成功するが、SITL_GZ_PX4 の bringup が常に +90秒遅くなる。
   - 証拠: `project_launch.sh:283-288` は「PX4 が UDP 14540 を listen 開始するまで待つ」意図で
     `wait_for_udp_listen px4_sitl 14540 90 3` を呼ぶ。しかし PX4 ログでは
     `INFO [mavlink] mode: Onboard, data rate: 4000000 B/s on udp port 14580 remote port 14540` —
     PX4 が bind するローカルポートは **14580** で、14540 は送信先 (listen するのは mavros2 側)。
     px4_sitl コンテナ内で 14540 が listen 状態になることはなく、この待ちは必ずタイムアウトする。
   - 想定修正: 待ちポートを 14580 (PX4 の onboard mavlink ローカルポート) にする、または
     `Ready for takeoff!` 等のログ待ちに置き換える。
   - `project_launch.sh` はデプロイインフラ (CLAUDE.md で編集禁止・管理者スコープ) のため PR は開かず要相談。
2. **`Contract: saturation missing=['cascade.state']` WARN** (drone2、両回) — 試走時から既知。
   node は `Drone ready` に到達しており良性の可能性大 (cascade 入力は実行時に揃う init 時チェック)。
   テーマ仕様どおり自動修正せず、ros2-structure 柱3 と突き合わせ待ちのまま。
3. **(低優先・観察のみ)** drone2 起動直後の
   `[XMLPARSER Error] realpath failed No such file or directory -> loadDefaultXMLFile` (両回)。
   Fast-DDS のデフォルト XML プロファイル読込失敗で、node は正常に ready 到達。実害は観測されず。
   イメージ/環境変数 (プロファイルパス設定) 側の話なので infra 扱い。

## 捨てた候補 / 実施できなかった項目
- 任意項目の「コンテナ内 `ros2 topic list/hz`」は権限 deny でスキップ。拒否原文:
  `Permission to use Bash has been denied because Claude Code is running in don't ask mode. ...`
  (`docker exec drone2 ros2 topic list` および `docker exec drone2 bash -lc "ros2 topic list"` の両方)。
  代替として drone2 ログの `/mavros/state received` + warmup サービス ready を受動的証拠に採用。
- `image drone2_x86 does NOT exists. Use image_drone2_x86` 表示 — テーマ仕様どおり正常フォールバックで指摘ではない。
- PX4 の一過性 preflight WARN (`Yaw estimate error` / `GPS Pos Drift`) — `Ready for takeoff!` 到達後の
  SITL 収束過程の揺らぎで、launcher の preflight 待ちは両回成功しており指摘にしない。

## 開いた PR
なし (確証ある in-scope 修正なし。指摘ゼロ = 成功)。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `04cd06a81929` — 残り mode: SIM SITL_PX4 SITL_AP SITL_OMNI (全 PASS で正式イメージ dpush)
