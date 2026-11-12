# 2026-10-30 backend-smoke — drone × SITL_AP (host: ruth)

## 対象・前提
- deploy: `~/drone` (drone2), mode: `SITL_AP` (config `ardupilot/sitl.yaml`)
- checkout: main = origin/main = `5a97194` (Merge PR #246), working tree clean (検証前後とも)
- 事前確認: `docker ps` 空 (fleet / px4_hlc 等の衝突なし)、`ss -ulnp` に 14550/14555/14580 等の占有なし
- 安全: SITL のみ。console 接続・arm/takeoff 等の駆動指令は一切送っていない

## 実施
`dup all SITL_AP` → 各コンテナを `docker logs --tail N` (非 follow) でスナップショット → `docker rm -f drone2 mavros2 ardupilot_sitl`。これを2回。

| 項目 | run 1 (02:30) | run 2 (02:32) |
|---|---|---|
| ardupilot_sitl 起動 | Up / `Loaded defaults from ...copter.parm,/root/sitl.parm` | 同左 |
| mavros2 | `CON: Got HEARTBEAT, connected. FCU: ArduPilot`、IMU detected | 同左 |
| drone2 | `Drone ready: config_name=sitl, backend=mavros, dt=0.02, hz=50` | 同左 |
| MAVROS warmup | arming/set_mode/command/takeoff/land 全サービス ready、SET_MESSAGE_INTERVAL 5件 OK、`/mavros/state received` | 同左 |
| Python traceback / 例外 | なし | なし |
| コンテナ状態 (数秒後) | 3つとも Up | 3つとも Up |

受動トピック確認 (`docker exec drone2 ... ros2 topic hz`) は dontAsk で拒否されたため未実施
(拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode.")。
代替の受動的な証拠として、drone2 の MavrosSensor が `/mavros/state` を受信し、mavros 側で IMU (attitude quaternion / raw IMU) を検出していることをログで確認した。

## 確証指摘
なし → PR なし。

## 既知・要相談 (前回からの継続、今回も再現)
1. **`Flight battery` を 90s 待って毎回空振り** (`project_launch.sh` の sentinel)。sim_vehicle の RiTW が ArduCopter の stdout を `/tmp/ArduCopter.log` に逃がすため、docker logs には構造的に出ない。起動が毎回 約90s 余計にかかるだけで、機能面の実害はない。管理者ファイルなので要相談 (07-23, 09-16 と同じ)。
2. `Contract: saturation missing=['cascade.state']` の WARN — 良性 (Drone ready まで到達)。テーマ規定どおり自動修正せず。
3. FastDDS `XMLPARSER Error realpath failed` — デフォルト XML が無いという表示だけで、動作に影響なし。
4. ArduCopter `--uartA` 非推奨の WARNING (将来の ArduPilot で `--serial0` に切り替える必要あり)。ardupilot_sitl イメージ / launch 側の話なので、現時点で壊れている箇所はない。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `037652007143` — 残り mode: SITL_PX4 SITL_OMNI (全 PASS で正式イメージ dpush)
