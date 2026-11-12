# 夜間監査レポート 2026-09-07 — backend-smoke (rover × SIM)

- テーマ: backend-smoke
- 対象: deploy=rover (稼働 checkout `/home/sekiguchi/rover`, project rf_rover) × mode=SIM
- ホスト: ruth
- 結果: **BLOCKED** (ホスト使用中のため bringup 検証を実施せず)
- 開いた PR: なし
- 起動したコンテナ: なし (後始末対象なし)

## 判定理由 (ホスト使用中)

`dup all SIM` を叩く前に稼働状態を確認した結果、ユーザーの実験セッションが
ホスト上に生きており、監査の bringup がそれに干渉すると判断した。

### 1. ユーザーのローバー系コンテナが稼働中 (Up 4 days)

`docker ps` の出力:

```
CONTAINER ID   IMAGE                                        STATUS      NAMES
cb45f87af136   kasekiguchi/acsl-common:yolo_x86             Up 4 days   yolo
39410388337d   kasekiguchi/acsl-common:nav2_x86             Up 4 days   nav2
959f39d624bf   kasekiguchi/acsl-common:image_rf_rover_x86   Up 4 days   rover
aa8a52e988ee   kasekiguchi/acsl-common:image_rf_rover_x86   Up 4 days   bcps_bridge
aa0f0a7b4059   kasekiguchi/acsl-common:image_rf_rover_x86   Up 4 days   rf_tf
```

`docker inspect rover` より、この `rover` は **isaacsim モード** (`launch_rover.sh
localizer:=amcl config_path:=omni_yc_bld7.yaml`, `ENV_BUILDING=yc_bld7`,
`ROS_DOMAIN_ID=8`, `ROS_USE_SIM_TIME=true`) で起動されたもの。`docker logs --tail 40 rover`
の末尾は `status:move Goal:[1,12] ... Est:AMCL[...]` のハートビートで、走行実験の状態
(経路・目標・AMCL 推定) が保持されている。直近 24h のログ出力は無い (`docker logs --since 24h`
が空) ため現在はアイドルだが、セッションは片付けられておらず、ユーザーが再開する前提の
状態と見なした。

### 2. `dup all SIM` を重ねると同一 RID 上で二重起動になる

`project_launch.sh` の SIM 分岐は `dup rf_tf` → `dup bcps_bridge sim` → `dup rover
localizer:=amcl config_path:=local.yaml` → `dup nav2 localization ...` を順に呼ぶ
(`project_launch.sh:232-260`)。`dup` は同名コンテナが Running かつ launch 引数付きの場合、
コンテナ名を `<name>_<arg>` に付け替えて**別コンテナを追加起動**する
(`.acsl/commands/scripts/dup:160-162`)。つまり既存の `rover`/`nav2`/`rf_tf`/`bcps_bridge`
を残したまま `rover_localizer_amcl` 等が同じ `ROS_DOMAIN_ID=8` に立ち、`/Druth/robot_node`・
`/amcl`・`/map_server`・TF publisher が重複する。さらにランチャはホストから
`ros2 lifecycle set /map_server configure` / `/amcl configure` を打つ
(`project_launch.sh:266-269`) ため、ユーザー側の既存 `amcl`/`map_server` を再 configure
してしまう可能性が高い。ユーザーのセッションを壊さずに検証する手段が無い。

既存コンテナを `docker rm -f` して場所を空けることはユーザーの実験状態の破壊になるため
行わなかった (driver の「破壊的操作は行わない」原則)。

### 3. 稼働 checkout に未コミットの作業中差分がある

`git status -sb` は `## main...origin/main` (HEAD は origin/main と同じ 97bcd9a) だが、
作業ツリーに **34 ファイル変更 (+2596/-1705) + 未追跡 8 件**がある (`git diff --stat`)。
含まれるもの: `config/rover.yaml`, `packages/rf_rover/rf_rover/rover_main.py`,
`tools/sensor/building_sensor.py`, `tools/controller/saturation.py`,
`tools/controller/obstacle_avoid.py`, `tools/phase/phase_actions.py`, `packages/rf_rover/setup.py`
など SIM bringup の経路そのもの。コンテナは `ACSL_WORK_DIR` を bind-mount するので、
このまま起動しても検証対象は **origin/main ではなくユーザーの WIP** になり、失敗しても
main の問題と切り分けられない。また `audit/...` ブランチを origin/main から切るには
`git stash` 等でユーザーの作業ツリーを動かす必要があり、稼働コンテナがその作業ツリーを
マウントしている状況では許容できない。

以上 1〜3 から、今夜は bringup を実施せず BLOCKED とする。

## 実施した範囲 (読み取りのみ・ホスト状態は一切変更していない)

- `targets.conf` 確認: rover の許可 mode は `SIM,isaacsim`。今夜の SIM は許可内。
- `docker ps` / `docker ps -a` / `docker inspect rover` / `docker logs --tail N` (非 follow)
- `pgrep -fa isaac`: ホスト側に Isaac Sim プロセスは無し (コンテナのみ残存)。
- `git status -sb` / `git diff --stat` / `git log origin/main`
- 次回に向けた読み取り確認:
  - SIM 既定 config `config/local.yaml` は origin/main に存在 (`odom_source: cmd`,
    `initial_pose: [0,0,0]`。localizer/map は rover.yaml 供給)。
  - SIM 分岐は `rplidar_front`/`rplidar_back` コンテナ (`rplidar_x86`) も起動する
    (`project_launch.sh:42-43`)。`docker images` に `rplidar_x86` / `image_rf_rover_x86` /
    `nav2_x86` はいずれも存在するため、イメージ欠落での即死は無い見込み。
  - launcher/ に `launch_rover.sh` / `launch_nav2.sh` / `launch_rf_tf.sh` /
    `launch_bcps_bridge.sh` / `launch_rplidar.sh` が揃っている。

## 確証指摘

なし (bringup 未実施のため判定不能)。

## 要相談

1. **監査ホストの占有ポリシー**: ruth 上でユーザーの Isaac Sim セッション用コンテナが
   数日単位で残る運用のため、rover の backend-smoke は毎回 BLOCKED になりうる。
   harness 側で「`docker ps` に `rover`/`nav2` が居たら BLOCKED」を事前判定するか、
   監査専用の別 checkout + 別 `ROS_DOMAIN_ID` (`setrid`) で隔離起動する設計を検討したい。
   ただし後者でもコンテナ名衝突 (`rover` 等) は `dup` の名前付け替えで回避されるが、
   COMPOSE_PROJECT_NAME や `docker rm -f` 後始末の名前解決が複雑になる。
2. **稼働 checkout の dirty tree**: 稼働 checkout でユーザーが直接開発しているため、
   「origin/main を基準に検証する」前提が成立しない。監査用 worktree
   (`git worktree add`) を別ディレクトリに作って `ACSL_WORK_DIR` を差し替える案が有力。
3. **権限の観察 (deny 原文)**: `audit_settings.json` の allow に `Bash(ls *)` /
   `Bash(cat *)` があるにもかかわらず、cwd 外の絶対/相対パスを対象にした
   `cat /home/sekiguchi/GitHub/sb/acsl_infra/nightly_audit/targets.conf`、
   `ls /home/sekiguchi/GitHub/sb/acsl_infra/nightly_audit/logs`、
   `ls ../GitHub/sb/acsl_infra/nightly_audit/logs`、`cd /home/sekiguchi/GitHub/sb/acsl_infra/nightly_audit`、
   `who` が次のメッセージで拒否された:
   > Permission to use Bash has been denied because Claude Code is running in don't ask mode. IMPORTANT: You *may* attempt to accomplish this action using other tools ...

   一方 allow 未記載の `pgrep -fa isaac` は許可された。cwd 外パスを含むコマンドが
   deny されている可能性がある (driver 0.5 の「cd を単独で打つ」手順も cd 自体が
   deny されたため機能しなかった)。Read/Write ツールは cwd 外でも動作したので今回は
   支障なかったが、次回以降のために harness の allow 規則を確認されたい。

## 捨てた候補

なし (候補を立てる段階まで進んでいない)。

## 後始末

監査はコンテナを 1 本も起動していない。`docker ps` はユーザーの 5 コンテナ
(yolo/nav2/rover/bcps_bridge/rf_tf) のまま。作業ツリー・ブランチも一切変更していない。

SMOKE_RESULT: BLOCKED
