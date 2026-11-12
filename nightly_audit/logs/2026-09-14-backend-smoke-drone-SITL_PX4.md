# 2026-09-14 backend-smoke — drone × SITL_PX4 (host: ruth)

**結論: FAIL (再現する起動失敗)。** `dup all SITL_PX4` で起動する 2 コンテナ
(`quadrotor_sim`, `drone2`) が両方とも起動直後に **`ModuleNotFoundError: No module named 'px4_msgs'`**
で即死する。2 回連続で同一のトレースバック。PR は開かない (修正が Dockerfile または
依存パッケージの取り込み方針という設計判断を要するため → 要相談)。

SITL_PX4 の bringup 検証が実際に走ったのは今回が初めて (07-13 / 07-21 / 08-01 / 08-12 の
4 回はいずれもホスト使用中ゲート等で smoke 未実施、`SMOKE_RESULT` 行なし)。

## 調べた範囲

- deploy = `~/drone` (project drone2)、mode = `SITL_PX4` (= `quadrotor_sim` + `drone2`、
  `project_launch.sh:255-263`)。config = `config/px4/sitl_quadsim.yaml` (backend: px4)。
- checkout 状態: ブランチ `feat/hlc-firmware-c` (clean、`origin/main` 3a53ebb を完全に含む。
  `HEAD..origin/main` は空)。切替はしなかった (稼働中の `px4_hlc` コンテナがこの checkout の
  `packages/` `scripts/` を live マウントしているため)。
  差分は HLC C 実装 / hlc_sl / ekf_sl / launch_px4_sitl.sh 等で、SITL_PX4 経路
  (quadrotor_sim, px4_sensor, PIDController, Saturation, direct estimator, launch_quadrotor_sim.sh,
  launch_drone2.sh, dockerfiles) には触れていない。**結果は main でも同じ**と判断できる。
- 同居コンテナ: `px4_hlc` (ユーザーの PX4 SITL 作業、host network、UDP 14580/18570 を bind、
  uXRCE agent なし = ROS 2 側に出ていない)。quadrotor_sim は固定ポートを持たず px4_hlc と
  DDS トピックも共有しないので、干渉なしと判断して smoke を実施した。px4_hlc には触れていない。

## 実行手順と実ログ

```
dup all SITL_PX4          # rc=0、quadrotor_sim / drone2 とも "Started"
docker ps                 # → 両コンテナとも既に居ない (Exited (0) 数秒後)
docker logs --tail 60 quadrotor_sim
docker logs --tail 60 drone2
```

quadrotor_sim (1 回目・2 回目とも同一):
```
[launch_quadrotor_sim] Starting quadrotor simulator
Traceback (most recent call last):
  ...
  File "/root/ros2_ws/build/drone2/drone2/plant/quadrotor_sim.py", line 25, in <module>
    from px4_msgs.msg import (
ModuleNotFoundError: No module named 'px4_msgs'
[ros2run]: Process exited with failure 1
```

drone2 (1 回目・2 回目とも同一):
```
[launch_drone2] config_path=/root/ros2_ws/config/px4/sitl_quadsim.yaml agent_index=0
[INFO] [Druth.drone_node]: Init Drone Control (Orchestrator + Tool chain)
[INFO] [Druth.drone_node]: Config loaded: /root/ros2_ws/config/px4/sitl_quadsim.yaml
Traceback (most recent call last):
  ...
  File "/root/ros2_ws/build/drone2/drone2/drone_main.py", line 797, in _create_fc_sensor
    from drone2.tools.sensor.px4_sensor import PX4Sensor
  File "/root/ros2_ws/build/drone2/drone2/tools/sensor/px4_sensor.py", line 29, in <module>
    from px4_msgs.msg import (
ModuleNotFoundError: No module named 'px4_msgs'
[ros2run]: Process exited with failure 1
```

`Drone ready` には到達しない。dup の rc=0 は detached 起動のためで成功を意味しない
(仕様の注意どおり)。使用 image はいずれも `kasekiguchi/acsl-common:image_drone2_x86`
(`quadrotor_sim_x86` / `drone2_x86` はローカルに無く、`dockerfile.*` が ARG ベース FROM のため
auto-build もスキップされ、フォールバックで image_drone2_x86 を使用。この表示自体は正常)。

## 確証指摘 (1 件・要相談)

**SITL_PX4 が依存する `px4_msgs` が、main のワークスペースにも image にも存在しない。**

証拠:
- `packages/drone2/package.xml:19` — `<depend>px4_msgs</depend>` を宣言。
- `packages/drone2/drone2/plant/quadrotor_sim.py:25`、`packages/drone2/drone2/tools/sensor/px4_sensor.py:29`
  — 無条件 `from px4_msgs.msg import ...` (ガードなし)。
- `packages/` には `drone2` と `drone2_interfaces` しか無い。`.gitmodules` は存在しない。
  `git log origin/main -- .gitmodules packages/px4_msgs` は空 = **main には一度も入っていない**。
- `dockerfiles/dockerfile.quadrotor_sim:7` はコメントで「px4_msgs のみ必要」と言いながら pip の
  ビルドツールしか入れていない。`dockerfile.drone2` も `ros-jazzy-mavros-msgs` のみ。
  acsl_infra 側 (`.acsl/`) にも `px4_msgs` の記述は無い (`grep -rn px4_msgs .acsl` 空)。
- 過去に取り込んだ形跡はあるが main に届いていない:
  - PR #109 (`fix: mocap で px4_msgs を必須にしない + px4_msgs を submodule 登録`, d976622) は
    base が `test/105-serial_exp` で、そこにマージ済み。main には未マージ。
  - `ccb8b59 feat: PX4実機オンボード用にpx4_msgsパッケージを追加` (packages/px4_msgs を丸ごと同梱)
    は `origin/test/142-PX4_exp` のみ。
- 実機 (EXP_PX4) は同じ `px4` backend + `px4_sensor.py` を使うので、**main 単体では EXP_PX4 も
  同じ import で落ちる**はず (今回は安全則により EXP は起動せず、静的推定のみ)。
  実機ではおそらく上記テストブランチか機体側の別ワークスペースで px4_msgs を用意している。

なぜ PR にしなかったか:
- 直し方が方針選択を含む: (a) `packages/px4_msgs` を submodule 化 (PR #109 方式) / (b) vendoring
  (ccb8b59 方式) / (c) Dockerfile で clone+build して image に焼く / (d) `px4_msgs` の版を
  どの PX4 (v1.17.0 が HLC で使用中) に合わせるか。CLAUDE.md は Dockerfile 変更を禁止しており、
  (a)(b) も README/CLAUDE.md の起動手順とセットで決める必要がある。
- import を optional 化するだけでは SITL_PX4 は動かない (根本は依存欠落)。

想定される対応 (管理者向けメモ):
1. PR #109 の `.gitmodules` 登録 (submodule) を main に持ってくる + README に
   `git submodule update --init` を明記。もしくは ccb8b59 の vendoring を main に取り込む。
2. `dockerfile.quadrotor_sim` / `dockerfile.drone2` を実際に px4_msgs を含む内容にするなら
   acsl_infra の dbuild 経由で `quadrotor_sim_x86` / `drone2_x86` を作る運用に揃える。
3. どちらにせよ、image 昇格台帳では SITL_PX4 は現 base で未 PASS のままにする。

## 捨てた候補

- `chmod: cannot access '/root/ros2_ws/launcher/rosbags/*'` — 終了時の後片付けメッセージ。
  SIM 試走でも出ている既知の無害ログ。指摘にしない。
- `XMLPARSER Error realpath failed` (FastDDS default XML) — 既知の無害 WARN。
- `image drone2_x86 does NOT exists. Use image_drone2_x86` — 仕様どおり正常フォールバック。
- `Contract ... missing=[...]` WARN — 今回は node がそこまで進まず観測できず。

## 後始末

- `docker rm -f quadrotor_sim drone2` を実施。`docker ps -a` は `px4_hlc` (ユーザー作業、未接触) のみ。
- 作成した named volume `quadrotor_sim_drone2_vscode-server` は残置 (他の dup と同じ挙動、害なし)。

## 実機安全

EXP 系は起動していない。console 操作・arm/takeoff 等の駆動指令は一切送っていない。

SMOKE_RESULT: FAIL
