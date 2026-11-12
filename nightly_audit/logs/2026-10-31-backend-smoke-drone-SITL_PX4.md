# 2026-10-31 backend-smoke — drone × SITL_PX4 (host: ruth)

## ★★ 3 回目の実行 (2026-10-31 08:07 JST) — 結論: PASS (PR #251 マージ後の main e37e754)

**変化:** PR #251 (空の `-p config:=` を渡さない修正) が main にマージされた (e37e754)。`~/drone` は main で clean、origin/main と一致している。
- 事前確認: `docker ps` は空。`ss -ulnp` で PX4 系のポート (14540/14580/18570 等) を使っているプロセスは無い。fleet も px4_hlc も動いていない。
- `dup all SITL_PX4` を **2 回**実行した。2 回とも同じ結果だった:
  - quadrotor_sim: `[quadrotor_sim]: QuadrotorSim ready: dt=0.005, hz=200`
  - drone2: `Sensor: PX4 (uXRCE-DDS), tools=['px4_sensor']` … `Drone ready: config_name=sitl_quadsim, backend=px4, dt=0.02, hz=50, use_sim_time=False` → `Executor: SingleThreadedExecutor`
  - ready の後も `docker ps -a` で両方 Up のまま (1 回目は約 5 秒後に再確認、2 回目は 3 秒後)。数秒後にログを取り直しても traceback / 例外は出ていない。
- WARN: `Contract: saturation missing=['cascade.state'] mismatched=[]`。既知で、良性の可能性が高い (node は ready に到達している)。自動修正はしない。要相談 (ros2-structure 柱3 と突き合わせる)。
- 良性のノイズ (以前と同じ): `XMLPARSER Error realpath failed`、`image *_x86 does NOT exists. Use image_drone2_x86`、compose の `DF`/`BASE_IMAGE` WARN。
- 任意の受動トピック確認は未実施: `docker exec drone2 bash -lc "ros2 topic list"` が拒否された。原文: `Permission to use Bash has been denied because Claude Code is running in don't ask mode.`
- 残る要相談: SITL_PX4 では quadrotor_sim に config が渡らない。そのため `sitl_quadsim.yaml` の initial_position/attitude が反映されない (`project_launch.sh` が CONFIG_PATH を設定しない。管理者の領域)。
- PR は開いていない (今回の新しい指摘は無い)。
- 後始末: 毎回 `docker rm -f quadrotor_sim drone2` を実行し、最後に `docker ps -a` が空であることを確認した。`~/drone` は main (clean)。
- 実機安全: EXP 系は起動していない。console 操作や駆動指令は一切送っていない。

---
(以下は同日に行った 1 回目・2 回目の実行の記録。どちらも FAIL で、原因は解消済み)

## ★ 再実行 (2026-10-31 07:58 JST) — 結論: FAIL (原因が変わった)。修正 PR を開いた: https://github.com/acsl-tcu/project_drone2/pull/251

**変化:** 前回の実行の後に ruth の `image_drone2_x86` が再ビルドされていた (ID 9c7d83a113de)。**px4_msgs の欠落は解消**している。
drone2 は `Drone ready: config_name=sitl_quadsim, backend=px4, dt=0.02, hz=50` まで進む。
ただし、その後ろに隠れていた別の起動失敗で、**quadrotor_sim が即死する (main 12e8ce4 で 2 回再現)**。

```
[launch_quadrotor_sim] Starting quadrotor simulator
[ERROR] [rcl]: Failed to parse global arguments
  File "/root/ros2_ws/build/drone2/drone2/plant/quadrotor_sim.py", line 254, in main
    rclpy.init(args=args)
rclpy._rclpy_pybind11.RCLError: failed to initialize rcl: Couldn't parse parameter override rule: '-p config:='. Error: error not set, at ./src/rcl/arguments.c:352
[ros2run]: Process exited with failure 1
```
(`docker ps -a`: quadrotor_sim は起動後 2 秒で Exited (0)。drone2 は Up のまま)

- **原因:** `launcher/launch_quadrotor_sim.sh:14` が `-p config:="${CONFIG_PATH:-}"` を渡している。
  SITL_PX4 (`project_launch.sh:261` の `dup quadrotor_sim`) は CONFIG_PATH を設定しないので、値が空の `config:=` になる。rcl はこれを parse できない。このコードは a384b17 で入った。
- **修正 (PR #251, draft):** CONFIG_PATH が空でないときだけ `-p` を付ける。
  `launcher/` は `/common/ros_launcher` にライブマウントされているので、ブランチを checkout したまま `dup all SITL_PX4` を **2 回**実行して確認した:
  quadrotor_sim は `QuadrotorSim ready: dt=0.005, hz=200`、drone2 は `Drone ready ... backend=px4` が出て、どちらも Up のまま。traceback は無かった。`bash -n` も OK。
- 確信度: 高。ただし `launcher/` は CLAUDE.md の「編集してよい」一覧に入っていない (禁止一覧にも入っていない)。そのことを PR に明記した。
- **要相談:**
  - (1) SITL_PX4 の quadrotor_sim には config が渡らない。そのため `sitl_quadsim.yaml` の initial_position/attitude が反映されない。直すには `project_launch.sh` で CONFIG_PATH を設定する必要がある (管理者の領域)。
  - (2) project_drone2 にラベル `nightly-audit` が存在せず、`gh pr create --label` が `could not add label: 'nightly-audit' not found` で失敗した。そのためラベルなしで draft を開いた。ラベルの作成は行っていない。
- 観測した Contract WARN: `saturation missing=['cascade.state']` (既知・良性の可能性大。node は ready に到達している。自動修正はしない)。
- `ros2 topic list` (任意・受動) は `docker exec drone2 bash -lc ...` が拒否された (原文: `Permission to use Bash has been denied because Claude Code is running in don't ask mode.`)。トピックは未確認。
- 後始末: 毎回 `docker rm -f quadrotor_sim drone2` を実行し、最後に `docker ps -a` が空であることを確認した。`~/drone` は main (clean) に戻した。
- 判定: main の状態では SITL_PX4 は起動しない → **FAIL**。PR #251 がマージされれば PASS になる見込み。
- 実機安全: EXP 系は起動していない。console 操作や駆動指令は一切送っていない。

---
(以下は同日に行った前回の実行の記録)

**結論: FAIL (再現する起動失敗)。** `dup all SITL_PX4` で起動する `quadrotor_sim` と `drone2` の両方が、
起動直後に **`ModuleNotFoundError: No module named 'px4_msgs'`** で落ちる。2 回とも同じトレースバックだった。
ソース側の修正 (PR #250: px4_msgs を submodule で取り込み、`setup` の `build_project` でビルドする) は
main に入っている。しかし **ruth の `image_drone2_x86` がまだ再ビルドされていない** ので、修正が実行環境に反映されていない。
PR は開いていない (直すにはイメージの再ビルドが必要で、CLAUDE.md で禁止されている → 要相談)。

## 事前確認 (ホスト使用中ゲート)

- `docker ps`: 空。fleet (drone2_1..4) も px4_hlc も動いていない。
- `ss -ulnp`: PX4 系のポート (14540/14580/18570 等) を使っているプロセスは無い。
- checkout: `~/drone` は `main` で clean。`origin/main` (12e8ce4, PR #250 マージ / 2026-10-30T22:40+09:00) と一致する。
- `packages/px4_msgs` の submodule は中身が入っている (CMakeLists.txt / msg / srv / package.xml がある)。
  `.gitmodules` に `packages/px4_msgs -> https://github.com/PX4/px4_msgs.git` が登録されている。

## 実行手順と実ログ

```
dup all SITL_PX4                         # rc=0。quadrotor_sim / drone2 とも "Started"
docker ps -a                             # 2 つとも 1〜2 秒で Exited (0)
docker logs --tail 60 quadrotor_sim
docker logs --tail 60 drone2
docker rm -f quadrotor_sim drone2
(同じ手順で 2 回目。結果も同じ)
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

`Drone ready` まで進まない。使ったイメージは `kasekiguchi/acsl-common:image_drone2_x86` (正常なフォールバック)。

## 確証指摘 (1 件・要相談) — PR #250 は main に入ったが、ホストのイメージが古いまま

**原因:** PR #250 (961b3f7) で px4_msgs をどう供給するかは次の 2 つで決まる:
- `.gitmodules` / `packages/px4_msgs` (submodule。ここはできている)
- `setup` の中の `build_project px4_msgs drone2 drone2_interfaces` (全 4 箇所)

`build_project` は build コンテナの中で colcon build を実行し、その結果を `dcommit` で
`image_drone2_x86` に**焼き込む** (`.acsl/commands/scripts/build_project:46-53`)。
一方 `dup` はビルドせず、イメージに入っている `/root/ros2_ws/install` をそのまま使う
(`docker-compose.yml:103` でマウントされるのは `packages` → `src/ros_packages` だけで、install はマウントされない)。
したがって **PR #250 のマージ後に ruth で `./setup` (または `build_project px4_msgs drone2 drone2_interfaces`) を
実行していなければ、イメージには px4_msgs が入らない。** 今回の traceback はこの状態と矛盾しない。

**直し方 (管理者の作業):** ruth で `cd ~/drone && ./setup` (引数なし = `build_project px4_msgs drone2 drone2_interfaces`) を実行する。
これでイメージの再ビルドと commit が行われる。終わったら、次回の SITL_PX4 smoke で PASS するか確認する。
この監査は「Docker イメージを変更しない」という制約 (CLAUDE.md) があるので、自分では実行していない。

**付記 (要相談・提案):**
- ソース (main) とホストのイメージがずれていることを `dup` は検出しない。px4_msgs のように後からワークスペースに
  加えたパッケージは、各ホストで `setup` を実行し直さないと反映されない。`setup` 再実行の告知
  (PR 本文 / README) を出すか、`dup` 側に「`packages/` 下のパッケージが install に無い」ことを知らせる WARN を入れるか、
  検討してほしい (acsl_infra 側の設計判断なので PR にはしていない)。
- 他ホストの drone checkout と EXP_PX4 も、`setup` を再実行するまでは同じ理由で落ちるはず (EXP は起動していない)。

## 捨てた候補

- `chmod: cannot access '/root/ros2_ws/launcher/rosbags/*'` — 終了時に毎回出る既知の無害ログ。
- `XMLPARSER Error realpath failed` — FastDDS の既知の無害 WARN。
- `image *_x86 does NOT exists. Use image_drone2_x86` / `ARG-based FROM; skipping auto-build` — 仕様どおりの正常フォールバック。
- compose の `DF` / `BASE_IMAGE is not set` WARN — 他のモードでも出ており、起動には影響しない。
- Contract WARN — node がそこまで進まないので観測できなかった。

## 権限メモ

次のコマンドは拒否された。拒否メッセージの原文は
`Permission to use Bash has been denied because Claude Code is running in don't ask mode.`:
- `git submodule status`
- `git ls-tree HEAD packages/px4_msgs`
- `docker image inspect --format '{{.Created}}' ...`
- `docker run --rm <image> ls /root/ros2_ws/install`

このため、イメージの作成日時とイメージ内の install の一覧は直接確認できていない。
「イメージに px4_msgs が無い」という結論は、2 回とも同じだった traceback を根拠にしている。

## 後始末

- 毎回 `docker rm -f quadrotor_sim drone2` を実行し、最後に `docker ps -a` が空であることを確認した。
- ブランチ作成・コミット・PR はしていない。

## 実機安全

EXP 系は起動していない。console 操作や arm/takeoff などの駆動指令は一切送っていない。

(最終判定は 3 回目の実行 (main e37e754) に基づく)

SMOKE_RESULT: PASS

---
**🎖 昇格**: drone の全 mode (SIM,SITL_PX4,SITL_GZ_PX4,SITL_AP,*SITL_OMNI) が base `037652007143` 由来で PASS。派生イメージは Hub へ push しない方針 — 各ホストは `gpull common` で取り込む (pull + setup full のローカル再ビルド)
