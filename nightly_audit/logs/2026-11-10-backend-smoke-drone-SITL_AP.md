# 2026-11-10 backend-smoke: drone × SITL_AP (ruth)

## 範囲
- deploy: `/home/sekiguchi/drone` (HEAD `e418898`, main, clean)
- 起動コマンド: `dup all SITL_AP sitl.yaml` (→ `ardupilot/sitl.yaml`) を 2 回実行
- 事前確認: `docker ps` が空。`ss -ulnp` で 14550/14555/5760 系の衝突なし (fleet/px4_hlc 非稼働)
- イメージ: `image_drone2_x86` 71ed265e90d2 (11/9 と同一) / `mavros2_x86` 49cf96fd151d / `ardupilot_sitl_x86` 67e220cba6a7
- 実機・console 操作は一切していない (arm/takeoff 等の送出なし)

## 結果 (2/2 で再現する起動失敗)
| run | ardupilot_sitl | mavros2 | drone2 |
|-----|----------------|---------|--------|
| 1 (02:30) | Up (ArduCopter 起動) | Up, `Got HEARTBEAT` 検出 | **Exited(0)**, traceback |
| 2 (02:32) | Up | Up, `Got HEARTBEAT` 検出 | **Exited(0)**, traceback |

drone2 のコンテナログ (`docker logs --tail` で取得。2 回とも同じ内容):
```
[Druth.drone_node]: Controller: pid_controller -> saturation
[Druth.drone_node]: Console server on port 7720
Traceback (most recent call last):
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 712, in __init__
    self._validate_contracts(agent)
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 728, in _validate_contracts
    from acsl.types.contract import validate_category_contracts
ImportError: cannot import name 'validate_category_contracts' from 'acsl.types.contract'
  (/root/.venv/lib/python3.12/site-packages/acsl/types/contract.py). Did you mean: 'validate_pipeline_contracts'?
[ros2run]: Process exited with failure 1
```
`Drone ready` には到達しなかった。ツールチェーンの構築 (sensor=mavros_sensor、required_sensors の readiness 登録、reference/controller) までは正常に進んでいた。

## 確証指摘
1. **acsl v0.8.0 への退行による ImportError (既知・継続中)**
   - 11/7 SIM、11/8 SITL_PX4、11/9 SITL_GZ_PX4 と同じ原因。モードには依存しない。
   - 原因: `.acsl/dockerfiles/dockerfile.base_ros_{x86,arm}` が `project_common@v0.8.0` を固定している。
     この固定のせいで、イメージを再ビルドすると新しい acsl (`validate_category_contracts` を持つ版) が失われる。
   - 修正は Dockerfile、`update_common`、イメージ再ビルドのいずれかが必要。どれも監査の編集スコープ外 (Docker / common) なので **PR は作らない。要相談**。
     対応を要する: 管理者による `update_common` + イメージ再ビルド、または base Dockerfile の固定バージョンの引き上げ。

## 要相談 (補足・FAIL 要因ではない)
- `project_launch` が ardupilot_sitl のログから `'Flight battery'` を待つ処理が 2/2 で 90s タイムアウトした。
  ArduCopter 自体は起動しており、mavros2 は HEARTBEAT を受信している。待機文字列が現在の SITL 出力と合っていないため、毎回 90 秒を無駄にしている可能性がある (SITL_GZ_PX4 の 14540 待ちと同じ類型)。
  `project_launch.sh` は管理者の管轄なので未修正。
- 前回までと同様、`project_launch` は drone2 が死んでいても `warmup status unclear; continuing` で正常終了する (rc=0)。判定には `docker logs drone2` が必須。

## 開いた PR
なし (確証指摘はスコープ外の修正が必要なため)

## 後始末
`docker rm -f drone2 mavros2 ardupilot_sitl` を各 run の後に実行した。最後に `docker ps -a` が空であることを確認済み。

SMOKE_RESULT: FAIL
