# Nightly audit 2026-11-01 — backend-smoke (drone × SITL_PX4)

- ホスト: ruth
- deploy: `/home/sekiguchi/drone` (main @ 9372292 = origin/main, clean)
  - 前回 PASS (10/31) からの差分: #254 `required_sensors` 宣言 + arm 前 readiness ゲート
- 起動コマンド: `dup all SITL_PX4 sitl_quadsim.yaml` (→ `px4/sitl_quadsim.yaml`)

## 事前確認
- `docker ps -a`: コンテナなし (fleet / px4_hlc 稼働なし)
- `ss -ulnp`: 14540/14580/8888 等 PX4 系ポートの使用なし → host 空き

## 結果 (2/2 PASS)
| run | コンテナ | drone2 | quadrotor_sim | traceback |
|-----|---------|--------|---------------|-----------|
| 1 (21:30:25) | drone2, quadrotor_sim Up | `Drone ready: config_name=sitl_quadsim, backend=px4, dt=0.02, hz=50, use_sim_time=False` | `QuadrotorSim ready: dt=0.005, hz=200` | なし |
| 2 (21:30:47) | 同上 | 同上 | 同上 | なし |

- #254 の readiness 宣言も正常にロード: `sensor readiness: px4_odom ← ['/fmu/out/vehicle_odometry'] (max_age=2.0s)`
- `config/px4/sitl_quadsim.yaml` は `required_sensors: [px4_odom]` を宣言済み (起動エラーなし)
- arm / takeoff 等のコンソール操作は一切送っていない (bringup 判定のみ)

## 既知・良性 (指摘にしない)
- `Contract: saturation missing=['cascade.state']` WARN — 従来通り。Ready に到達。要相談扱い継続 (自動修正しない)
- `XMLPARSER Error realpath failed ... loadDefaultXMLFile` — Fast DDS のデフォルト XML 不在の通知。両コンテナで出るが動作に影響なし
- `image drone2_x86 does NOT exists. Use image_drone2_x86` — harness の正常フォールバック
- compose の `DF` / `BASE_IMAGE` 未設定 warning — 起動に影響なし

## 未実施
- 受動トピック確認 (`ros2 topic list` via `docker exec`) は権限で拒否されたため未実施 (任意項目)。
  拒否メッセージ原文: "Permission to use Bash has been denied because Claude Code is running in don't ask mode."
  (`docker exec drone2 bash -lc "source /opt/ros/jazzy/setup.bash && ros2 topic list"` に対して)
- 起動直後のスナップショットのため heartbeat (`sensors=OK/NG`) 行は未観測。

## 後始末
- `docker rm -f drone2 quadrotor_sim` (各 run 後) → `docker ps -a` 空を確認

## 確証指摘 / PR
- なし (指摘ゼロ)

SMOKE_RESULT: PASS
