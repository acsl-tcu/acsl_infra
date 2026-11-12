# 2026-09-15 backend-smoke: drone × SITL_GZ_PX4 (host: ruth)

## テーマ / 範囲
- deploy = `~/drone` (project drone2), mode = `SITL_GZ_PX4` (PX4 SITL + Gazebo + MAVROS2 → `px4/sitl_gazebo.yaml`)
- 前回 PASS: 2026-08-24 (2/2 PASS, `logs/2026-08-24-backend-smoke-drone-SITL_GZ_PX4.md`)
- 今夜は **`dup` を1回も起動していない** (下記のとおりホスト使用中)。console 操作・駆動指令も一切なし。
  コンテナを起動していないので後始末対象もなし (`docker ps` は着手時と同じ状態のまま)。

## 結果: BLOCKED (ホスト使用中のため bringup 検証を実施できず)

### ホスト使用中の証拠
`docker ps` (02:30 JST 時点):
```
2440dc537284   kasekiguchi/acsl-common:px4_sitl_x86   "/bin/bash /common/r…"   8 hours ago   Up 8 hours   px4_hlc
```
- `docker inspect px4_hlc`: `net=host`、cmd=`/common/ros_launcher/launch_px4_hlc.sh`、
  `~/drone/{config,launcher,packages,scripts,gazebo_sitl,common,...}` を live マウント。
  利用者の feature ブランチ `feat/hlc-firmware-c` (`docker-compose_px4_hlc.yml` / `launcher/launch_px4_hlc.sh`
  はそのブランチ限定) の HLC ファームウェア実験用コンテナ。
- `docker logs --tail 40 px4_hlc`: PX4 SITL + Gazebo (`gz_bridge ... model name: x500_0`) が boot 済みで
  `Ready for takeoff!` → `Armed by internal command` → `Takeoff detected` → hlc_controller が軌道 0→1→3 と
  切り替え中 (シミュレーション上で飛行状態)。直近 30 分のログ出力は無いが、コンテナは稼働継続中。
- `ss -ulnp`: ホストで UDP **14580 / 18570 / 14280 / 13030** が bind 済み = 上記 px4_hlc 内 PX4 の mavlink
  (`on udp port 14580 remote port 14540` 等) が握っている。

### なぜ今夜の `dup all SITL_GZ_PX4` を打たなかったか
1. **ポート衝突**: `docker-compose_px4_sitl.yml:15` は `network_mode: host`。監査用 px4_sitl の PX4 も
   同じ 14580/18570 を bind しようとして px4_hlc と衝突する。さらに `config/px4/sitl_gazebo.yaml:18` の
   `fcu_url: "udp://:14540@127.0.0.1:14557"` で mavros2 が 14540 を開くと、px4_hlc 側 PX4 (remote port 14540 へ
   送信中) の HEARTBEAT を受けて**利用者の飛行中 SITL に接続してしまう**。drone2 は standby でも mavros2 は
   param 取得・stream rate 要求を送るため、利用者の実験を汚す上に監査結果も混同されて判定不能。
2. **Gazebo の共存**: px4_hlc は `ipc: host` + host network で gz sim を動かしている。監査用 px4_sitl の
   gz_bridge が既存 world (`default` / `x500_0`) に attach する可能性があり、切り分け不能。
3. **利用者コンテナを止めない**: 8 時間稼働中の px4_hlc は監査の対象外であり、`docker rm -f` は利用者の作業を
   破壊する。driver の安全側原則に従い触らない。
4. **checkout の切替もしない**: `~/drone` は `feat/hlc-firmware-c` (clean, origin と同期) で、px4_hlc が
   `config/` `packages/` `scripts/` を live マウント中。`git checkout --detach origin/main` すると稼働中
   コンテナの中身が差し替わるため実施しなかった。

「1 回失敗」でも「フレーク」でもなく、検証自体を安全に開始できない状況 → テーマ仕様どおり **BLOCKED**。
(ホストが空く時間帯に再実行すれば通常どおり検証できる。前回 8/24 は 2/2 PASS。)

## 代替として行った静的確認 (PASS の根拠にはしない)
- `origin/main` (3a53ebb, PR #226 マージ) で **前回 PASS (8/24) 以降に SITL_GZ_PX4 の bringup 経路
  (`project_launch.sh` / `launcher/` / `config/px4` / `config/sensor` / `config/actuator` /
  `docker-compose_px4_sitl.yml` / `docker-compose_mavros2.yml` / `drone_main.py` / `tools/sensor` /
  `tools/actuator` / `package.xml` / `setup.py`) に触れたコミットは 0 件**。
- 同期間のツール修正 2 件 (967d7a1: `ekf_sl_dynamics_estimator.py` `sl_takeoff_reference.py`、
  da015ac: `time_varying_reference.py` `hlc_sl_controller.py`) は `sitl_gazebo.yaml` の include
  (`sensor/none` `estimator/direct` `reference/*_enu` `controller/pid`) に含まれない。
- ただし **Docker イメージは前回 PASS 以降に作り直されている**:
  `image_drone2_x86` efd8664cb663 (5 日前、前回は別 ID) / `mavros2_x86` 77c88447d35d (6 日前、前回 592bdc34d8e9)。
  `px4_sitl_x86` e7f6dee4e7e1 は前回と同一。イメージ側の ABI ずれ (9/13 SIM で判明した種類) は実起動でしか
  検出できないため、静的一致だけで PASS とは判定しない。

## 要相談 (持ち越し・PR は開かない)
1. **`project_launch.sh:288` の `wait_for_udp_listen px4_sitl 14540 90 3` が構造的に不成立で毎回 90 秒空費**
   (8/24 レポート #1)。`origin/main` でも同じ行が残っていることを `git grep` で確認。
   PX4 が bind するのは 14580 で、14540 は mavros2 側が listen するポート。`project_launch.sh` は
   管理者スコープのため要相談のまま。
2. `Contract: saturation missing=['cascade.state']` WARN (8/24 #2) — 今夜は未起動のため再確認できず。
3. **監査運用**: 利用者の長時間 SITL (host network) と smoke が同じホストで衝突する。harness 側で
   「`docker ps` に host-network の px4/ardupilot 系コンテナがあれば BLOCKED 即決」を前処理に入れると、
   毎晩の判定が機械化できる (今回は手動判定)。

## 権限メモ
- `ls /home/sekiguchi/GitHub/sb/acsl_infra/nightly_audit/state` (cwd 外の絶対パス) は deny。拒否原文:
  `Permission to use Bash has been denied because Claude Code is running in don't ask mode. ...`
  昇格台帳の現状確認は省略 (Read/Write ツールでレポート出力は可能)。

## 開いた PR
なし。

SMOKE_RESULT: BLOCKED
