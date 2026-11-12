# 2026-10-29 backend-smoke: drone × SITL_GZ_PX4 (host: ruth)

## テーマ / 範囲
- deploy = `~/drone` (project drone2, main `5a97194`), mode = `SITL_GZ_PX4`
  (PX4 SITL + Gazebo + MAVROS2 → `px4/sitl_gazebo.yaml`)
- 事前確認: `docker ps -a` 空、`ss -ulnp` で 14540/14580/14550/8888 等の SITL ポート使用なし
  (fleet / px4_hlc 等の利用者セッションなし)。
- `dup all SITL_GZ_PX4` を **2回** 実行し、各コンテナログを `docker logs --tail N` (非 follow) で判定。
  console 接続・arm 等の駆動指令は一切送っていない。
- 使用イメージ: `px4_sitl_x86` (e7f6dee4e7e1, 前回 8/24 と同一) /
  `mavros2_x86` (**2b92d376eb86** — 前回 592bdc34d8e9 から更新。PR#145 系のローカル再ビルドと推定) /
  `image_drone2_x86` (b5cf10af938f。`drone2_x86` 不在→フォールバック、既知の正常動作)。

## 結果: 2/2 PASS (再現する起動失敗なし)
両回とも同一のクリーン起動:
- **px4_sitl**: PX4 boot (SYS_AUTOSTART=4001, x500_0 に attach) → `INFO [commander] Ready for takeoff!` 到達。
- **mavros2**: `CON: Got HEARTBEAT, connected. FCU: PX4 Autopilot`、VER 取得成功 (Flight sw 010f04ff)。traceback なし。
  更新後の mavros2 イメージでも正常 (前回の ABI スキュー問題の再発なし)。
- **drone2**: `Drone ready: config_name=sitl_gazebo, backend=mavros, dt=0.02, hz=50, use_sim_time=False` 到達。
  Python traceback / 例外なし。MavrosActuator warmup 5 サービス (arming/set_mode/command/takeoff/land) ready、
  `MavrosSensor: /mavros/state received` (run1 0.40s / run2 0.20s) — mavros→drone2 トピック疎通の受動的証拠。
- launcher 最終行: `[READY] SITL_GZ_PX4 ARM-READY -- PX4 preflight passed.` (両回)
- 後始末: 各回 `docker rm -f drone2 mavros2 px4_sitl` → 最終的に `docker ps -a` 空を確認。

## 要相談 (PR は開かない) — いずれも 8/24 から継続
1. **`project_launch.sh:288` の UDP 14540 待ちが構造的に不成立で毎回 90 秒空費 (今回も 2/2 再現)**
   - 両回 `[project_launch] WARNING: UDP 14540 not listening in px4_sitl after 90s; continuing anyway`。
   - PX4 ログ: `mode: Onboard, data rate: 4000000 B/s on udp port 14580 remote port 14540` —
     PX4 が bind するのは 14580、14540 は送信先 (mavros2 側が listen)。
   - 想定修正: 待ちポートを 14580 に、または `Ready for takeoff!` ログ待ちへ置換。
     `project_launch.sh` は管理者スコープ (CLAUDE.md で編集禁止) のため要相談のまま。2 か月以上未対応。
2. **`Contract: saturation missing=['cascade.state']` WARN** (drone2、両回)。node は ready 到達で良性の可能性大。
   テーマ仕様どおり自動修正せず、ros2-structure 柱3 と突き合わせ待ち。
3. **(観察のみ)** `[XMLPARSER Error] realpath failed ... loadDefaultXMLFile` (drone2、両回)。
   Fast-DDS デフォルト XML プロファイル未配置。実害なし、イメージ/環境側の話。

## 捨てた候補 / 実施しなかった項目
- PX4 の preflight WARN (`Yaw estimate error` / `GPS Horizontal|Vertical Pos Drift too high` /
  起動直後の `ekf2 missing data` / `Compass Sensor 0 missing`) — `Ready for takeoff!` 到達前後の
  SITL 収束過程の揺らぎ。launcher の preflight 待ちは両回成功しており指摘にしない。
- mavros2 の `FCU: EVENT ...` / `VER: broadcast request timeout` / `CMD: Unexpected command 512` —
  PX4 events プロトコル未デコード表示と AUTOPILOT_VERSION 要求のリトライで、その後 VER 取得に成功。良性。
- compose の `"DF"/"BASE_IMAGE"/"USER"/"XDG_RUNTIME_DIR" variable is not set` warning — 無人 cron 環境由来で起動に影響なし。
- 任意項目のコンテナ内 `ros2 topic list/hz` は実施せず (前回 deny 実績あり。代替に `/mavros/state received` を採用)。
- 権限 deny について: 複合コマンド `cd ... && source .acsl/bashrc && dup ...` と `printenv`、`ls <logs dir>` は
  拒否された。拒否原文: `Permission to use Bash has been denied because Claude Code is running in don't ask mode.`
  素の `dup all SITL_GZ_PX4` は許可され、ecosystem 環境 (ACSL_ROS2_DIR 等) も harness 側で設定済みだった。

## 開いた PR
なし (確証ある in-scope 修正なし。指摘ゼロ = 成功)。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `037652007143` — 残り mode: SITL_PX4 SITL_AP SITL_OMNI (全 PASS で正式イメージ dpush)
