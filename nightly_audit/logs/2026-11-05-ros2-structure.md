# 2026-11-05 ros2-structure (host: ruth)

## スコープ
差分走査。対象は前回 (10-25) の基準線から origin/main まで。
- project_rf_rover: b54d134c..12ecea99 (3 コミット)
  - 実質は #473 (required_sensors + SensorReadiness)
- project_drone2: 5a97194..e418898 (7 コミット)
  - #254 (required_sensors + SensorReadiness + sensor_catalog.yaml)
  - #250 (px4_msgs 遅延 import)
  - #251 / #252 (quadrotor_sim config)
  - #255 (docs)

新しい仕組み (required_sensors / sensor_catalog / SensorReadiness) を柱1〜3 で当てた。

## 確認結果
### rf_rover: 指摘 0
- top-level config は 9 件 (rover.yaml base を除く)。全件が `required_sensors` を宣言している。
- 宣言名 (rplidar_front/back, d435i, rover_odo, rtx_lidar, camera) は全て `sensor_catalog` に存在する。
- `topic_from_config` の参照先も全件実在する:
  - `scan.front_topics` / `scan.back_topics` (rover.yaml:277,290,293)
  - `camera.rgb_topic` (rover.yaml:338 と exp 系の上書き)
  - `isaac_sim.camera.rgb_topic` (omni_bld10:147 / omni_yc_bld7:146)
  - `camera.detections_topic`
- SensorReadiness は Tool 登録されていない独立ヘルパーなので、sensor parallel の `results[-1]` 落とし穴には当たらない。

### drone2: 確証指摘 1 → draft PR
- top-level config は 36 件。全件が `required_sensors` を宣言し、宣言名は全て sensor_catalog.yaml に存在する。
- 実センサーの購読トピックとの突き合わせ:
  - 一致: px4_odom (`{ns}/fmu/out`)、omni_odom (`{omni_prefix}`)、mocap_vrpn / mocap_vrpn_load / mocap_pose / vio / gps / rc。
  - **不一致**: 協調マルチ機体の `omni_load_odom`。
- **指摘 (#257)**: `omni/coop_sl.yaml` と `coop_sl_circle.yaml` では readiness が `/omni/load/odom` を待つ。
  - 実際の荷物 odom は `/dr{i}/omni/load/odom` で、購読する OmniSensor (`omni_sensor.py:105-113`) も、配信する bridge (`omni_sl_bridge.py:142-153`) と coop_sim_node (`:116-117`) もこちら。
  - 原因: `sensor_readiness.py:78-93` は継承の `omni.load_odom_topic` (`sitl_sl.yaml:26`) を生のまま使う。
  - 結果、arm が永久に拒否される。
  - 修正: coop_sl.yaml に config 側の `sensor_catalog.omni_load_odom: {topic: "{omni_prefix}/load/odom"}` 上書きを追加 (config/ 内のみ)。
  - PR: https://github.com/acsl-tcu/project_drone2/pull/257 (draft)
  - 検証は静的な読み取りのみ。python3 でのトピック解決再現は deny された (原文: 「Permission to use Bash has been denied because Claude Code is running in don't ask mode.」。`python3 -I <script>` と `python3 <script>` の両方)。Isaac 起動も無人では不可。
  - ラベルは付けていない (ラベル系は既知の全 deny)。

## 要相談 (新規)
- **M54** (drone2): ardupilot exp 系のコメントと実際の購読トピックが食い違う。
  - 実際の購読: `sensor/mocap_mavros_rc.yaml:5` の MocapMavrosSensor は `/vrpn/drone/pose`。
  - コメント: `ardupilot/exp_onboard.yaml:16,61` は「MocapSensor で /vrpn_mocap/<tracker>/pose を受信」と書く。
  - `dup mocap` (vrpn_mocap) の publish 名が `/vrpn_mocap/<tracker>/pose` (exp_esp32 系の規約) なら、実機で mocap が届かない。readiness の `mocap` も `/vrpn/drone/pose` を待つ。
  - コメントとトピックのどちらが正かは地上局構成次第で、EXP 系は検証不可。
- **M55** (drone2, 設計): 規約の一般化。
  - `topic_from_config` で得たトピックに、OmniSensor と同じ drone_id 強制規則 (`/<id>/` で始まらなければ付け替え) を当てていない。
  - #257 は config 局所の修正。将来ほかの fleet config で同じ問題が再発しうるので、`sensor_readiness.py` 側に寄せるかを管理者判断に回す。

## 滞留・持ち越し
- 前回までの要相談・滞留 PR (#248 / #242 close 推奨 / #231 等) は今回の差分では触られていない。状態は不変。
- 棄却 (再提起しない) は前回のリストどおり。

## 次回基準線
rf_rover 12ecea99 / drone2 e418898
