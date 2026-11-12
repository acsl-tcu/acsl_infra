# 2026-10-28 backend-smoke — drone × SITL_PX4 (host: ruth)

**結論: FAIL (再現する起動失敗・前回 2026-09-14 から未解消)。** `dup all SITL_PX4` で起動する
`quadrotor_sim` と `drone2` の両方が、起動直後に **`ModuleNotFoundError: No module named 'px4_msgs'`**
で即死する。2 回連続で同じトレースバックが出た。PR は開いていない (直すには依存取り込みの方針を決める必要があり、
Dockerfile の変更は CLAUDE.md で禁止されているため → 要相談)。

## 事前確認 (ホスト使用中ゲート)

- `docker ps -a`: 空。fleet (drone2_1..4) も px4_hlc も稼働していない。
- `ss -ulnp`: PX4 系ポート (14540/14580/18570 等) を bind しているプロセスは無い。
- checkout: `~/drone` は `main` で clean、`origin/main` (5a97194, PR #246 マージ) と一致。

## 実行手順と実ログ

```
dup all SITL_PX4          # rc=0、quadrotor_sim / drone2 とも "Started"
docker ps -a              # 両方とも 1〜3 秒以内に Exited (0)
docker logs --tail 40 quadrotor_sim
docker logs --tail 40 drone2
docker rm -f quadrotor_sim drone2
（同じ手順で 2 回目）
```

quadrotor_sim (1 回目・2 回目とも同じ):
```
[launch_quadrotor_sim] Starting quadrotor simulator
Traceback (most recent call last):
  ...
  File "/root/ros2_ws/build/drone2/drone2/plant/quadrotor_sim.py", line 25, in <module>
    from px4_msgs.msg import (
ModuleNotFoundError: No module named 'px4_msgs'
[ros2run]: Process exited with failure 1
```

drone2 (1 回目・2 回目とも同じ):
```
[launch_drone2] config_path=/root/ros2_ws/config/px4/sitl_quadsim.yaml agent_index=0
[INFO] [Druth.drone_node]: Init Drone Control (Orchestrator + Tool chain)
[INFO] [Druth.drone_node]: Config loaded: /root/ros2_ws/config/px4/sitl_quadsim.yaml
Traceback (most recent call last):
  File ".../drone_main.py", line 1290, in main
  File ".../drone_main.py", line 398, in __init__
    self.fc_sensor = self._create_fc_sensor(backend, cfg)
  File ".../drone_main.py", line 797, in _create_fc_sensor
    from drone2.tools.sensor.px4_sensor import PX4Sensor
  File ".../tools/sensor/px4_sensor.py", line 29, in <module>
    from px4_msgs.msg import (
ModuleNotFoundError: No module named 'px4_msgs'
[ros2run]: Process exited with failure 1
```

`Drone ready` には到達しない。使われたイメージは `kasekiguchi/acsl-common:image_drone2_x86` (正常なフォールバック)。

## 確証指摘 (1 件・要相談) — 2026-09-14 と同じ内容で未解消

**SITL_PX4 が依存する `px4_msgs` が、main のワークスペースにもイメージにも入っていない。**

- `packages/` には今も `drone2` と `drone2_interfaces` しか無く、`.gitmodules` も無い。
- `git log origin/main -- .gitmodules packages/px4_msgs dockerfiles/dockerfile.quadrotor_sim dockerfiles/dockerfile.drone2`
  の結果は Dockerfile への過去のコミット (mavros_msgs / pyserial / control) だけ。px4_msgs は一度も入っていない。
- 前回から main 側で取り込みは行われていない (過去に取り込んだ PR #109 / ccb8b59 はテストブランチ止まりのまま)。
- 直し方の選択肢 (submodule / vendoring / イメージへの焼き込み、および PX4 の版合わせ) は
  前回レポート `2026-09-14-backend-smoke-drone-SITL_PX4.md` の「想定される対応」のとおり。管理者判断が必要。
- 静的に見る限り、EXP_PX4 も同じ import 経路なので main 単体では同じように落ちるはず (EXP は起動していない)。

**提案:** 方針が決まるまで、SITL_PX4 は rotation に入れておいても毎回同じ FAIL を出すだけになる。
取り込み方針が決まるまで rotation から外すかどうかも合わせて相談したい。

## 捨てた候補

- `chmod: cannot access '/root/ros2_ws/launcher/rosbags/*'` — 終了時の既知の無害ログ。
- `XMLPARSER Error realpath failed` — FastDDS の既知の無害 WARN。
- `image *_x86 does NOT exists. Use image_drone2_x86` — 仕様どおりの正常フォールバック。
- compose の `BASE_IMAGE/DF/USER/XDG_RUNTIME_DIR is not set` WARN — 他モードでも出ており、起動には影響しない。
- Contract WARN — node がそこまで進まないため観測できなかった。

## 後始末

- 毎回 `docker rm -f quadrotor_sim drone2` を実行し、最後に `docker ps -a` が空であることを確認した。
- ブランチ作成・コミット・PR はしていない。

## 実機安全

EXP 系は起動していない。console 操作や arm/takeoff などの駆動指令は一切送っていない。

SMOKE_RESULT: FAIL
