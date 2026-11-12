# 2026-09-16 backend-smoke — drone × SITL_AP (ホスト: ruth)

## テーマ / 対象
- テーマ: backend-smoke (1 backend = 1晩)
- deploy = drone (稼働 checkout `~/drone`, project drone2)
- mode = SITL_AP (ArduCopter SITL `sim_vehicle.py -N` + MAVROS2 + drone2, config `ardupilot/sitl.yaml`)
- 検証基準 commit: `origin/main` = `3a53ebb` (Merge PR #226 feature/coop-cable-rope-chain)
- 使用イメージ (すべて既存, ビルド無し):
  - `kasekiguchi/acsl-common:ardupilot_sitl_x86` (67e220cba6a7)
  - `kasekiguchi/acsl-common:mavros2_x86` (77c88447d35d)
  - `kasekiguchi/acsl-common:image_drone2_x86` (efd8664cb663) ← `drone2_x86` 不在時の正常フォールバック

## 事前確認 (安全則)
- `docker ps -a`: 空 (利用者の px4_hlc 等の host-network コンテナ無し)
- `ss -ulnp`: 14540/14555/14580 等の SITL 系 UDP ポート未使用
- `~/drone` は `feat/hlc-firmware-c` (clean) → `git checkout --detach origin/main` で smoke
  → 終了後 `git checkout feat/hlc-firmware-c` で復帰 (可逆・稼働 checkout に変更なし)
- 実駆動指令 (arm/takeoff/console 操作) は一切送っていない。bringup とログ確認のみ。

## 実行手順 (2回同一シーケンス)
```
dup all SITL_AP                # 素の1コマンド (source .acsl/bashrc && ... は前綴不一致で deny、dup は profile 経由で PATH 済)
docker ps -a
docker logs --tail N drone2 / mavros2 / ardupilot_sitl
docker rm -f drone2 mavros2 ardupilot_sitl
```

## 結果: 2/2 PASS (再現する起動失敗なし)

| run | ardupilot_sitl | mavros2 | drone2 | traceback |
|-----|----------------|---------|--------|-----------|
| 1 (02:30:58) | Up, `Loaded defaults from ...copter.parm,/root/sitl.parm` | `CON: Got HEARTBEAT, connected. FCU: ArduPilot` | `Drone ready: config_name=sitl, backend=mavros, dt=0.02, hz=50`, `MAVROS warmup OK` | なし |
| 2 (02:32:57) | 同上 | 同上 | 同上 | なし |

drone2 ログ抜粋 (run 2, run 1 も同一内容):
```
[INFO] [Druth.drone_node]: Sensor: MAVROS2, tools=['mavros_sensor']
[INFO] [Druth.drone_node]: Controller: pid_controller -> saturation
[WARN] [Druth.drone_node]: Contract: saturation missing=['cascade.state'] mismatched=[]
[INFO] [Druth.drone_node]: Drone ready: config_name=sitl, backend=mavros, dt=0.02, hz=50, use_sim_time=False
[INFO] [Druth.drone_node]: MavrosActuator: warmup /mavros/cmd/arming ready (0.00s)
[INFO] [Druth.drone_node]: MavrosActuator: warmup /mavros/set_mode ready (0.25s)
[INFO] [Druth.drone_node]: MavrosSensor: /mavros/state received (0.40s after init)
[INFO] [Druth.drone_node]: MavrosSensor: SET_MESSAGE_INTERVAL msg_id=30 rate=50.0Hz OK   (31/32/33/27 も OK)
```
mavros2 ログ: `Flight software: 040507ff (b7207551)` (ArduCopter 4.5.7), IMU 検出まで到達。
ardupilot_sitl ログ: `Loaded defaults from ../Tools/autotest/default_params/copter.parm,/root/sitl.parm`
(PR #146 の `--add-param-file` 経路が有効)。

## 開いた PR
なし (指摘ゼロ)。

## 要相談 (自動修正しない・既知事項の再確認)
1. **`Flight battery` 待ちが毎回 90s 空費** (project_launch.sh:334, 管理者ファイル)。
   sim_vehicle の RiTW が `RiTW: Window access not found, logging to /tmp/ArduCopter.log` と
   ArduCopter stdout をファイルへ逃がすため docker logs にマーカーが構造的に出ない。2回とも
   `WARNING: 'Flight battery' not found in ardupilot_sitl after 90s; continuing anyway`。
   起動自体は成功するので実害はなし。代替センチネルは docker logs に出る
   `Loaded defaults from` / `UDP connection 127.0.0.1:14555` あたりが候補 (2026-07-23 レポートと同じ指摘)。
2. **`Contract: saturation missing=['cascade.state']` WARN** — テーマ仕様どおり良性扱い (Drone ready に到達)。
   `@tool_contract` / common 側に絡むので自動修正せず。
3. `[XMLPARSER Error] realpath failed No such file or directory -> loadDefaultXMLFile` (drone2 起動直後の
   Fast-DDS デフォルト XML 探索の 1 行)。動作に影響なし・全モード共通のノイズ。

## 捨てた候補
- docker compose の `DF` / `BASE_IMAGE` / `USER` / `XDG_RUNTIME_DIR` 未設定 warning: ハーネス側の
  正常表示。指摘にしない。
- `image drone2_x86 does NOT exists. Use image_drone2_x86` : テーマ仕様どおり正常フォールバック。

## 権限メモ
- `source .acsl/bashrc && dup all SITL_AP` は dontAsk で deny (原文:
  "Permission to use Bash has been denied because Claude Code is running in don't ask mode")。
  素の `dup all SITL_AP` は許可され、profile 経由で `dup` が PATH にあるので問題なし。
- `din` は `docker exec -it` なので topic 受動確認 (ros2 topic list/hz) は skip (過去回と同様)。

## 後始末
- run 1 / run 2 とも `docker rm -f drone2 mavros2 ardupilot_sitl` で片付け、`docker ps -a` 空を確認。
- `~/drone` を `feat/hlc-firmware-c` に復帰。

SMOKE_RESULT: PASS

---
**昇格台帳**: base `dabf4202bbf0` — 残り mode: SITL_PX4 SITL_GZ_PX4 SITL_OMNI (全 PASS で正式イメージ dpush)
