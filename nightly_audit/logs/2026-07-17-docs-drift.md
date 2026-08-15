# Nightly Audit 2026-07-17 — docs-drift

- ホスト: ruth / テーマ: docs-drift (ドキュメント/コメントと実装の乖離)
- スコープ: acsl_infra, project_rf_rover, project_drone2 (targets.conf の repo 行 × テーマ対象、全3リポ存在)
- 手法: Explore サブエージェント3並列で走査 → 高確度候補は駆動側 (本エージェント) が Read で反証チェック。
  Bash が deny (後述) のため存在確認は Read/Glob 系のみで実施。

## ⚠ ハーネス権限ギャップ: PR 作成不能 (要対応)

**headless (don't-ask) 実行では `git` がすべて自動 deny** (`git status` 単発でも拒否。2回試行、
compound の有無に依らず)。`git checkout -b` / `commit` / `push` / `gh pr create` が実行できないため、
**今夜は確証指摘があっても draft PR を開けない**。backend-smoke (dup rc=127) ・image-refresh
(docker deny) と同系のギャップ。ハーネス (`run_nightly_audit.sh`) の allowlist に
`git checkout -b audit/*` / `git commit` / `git push -u origin audit/*` / `gh pr create --draft` 相当を
追加するまで、docs-drift 系テーマも「静的検出 + レポート」止まりになる。

以下の確証指摘は **PR にそのまま起こせる粒度** (証拠 file:line + 修正内容一意) で記録した。

---

## 確証指摘 (修正先が一意・機械的)

### A. acsl_infra

#### A1. commands/README_SYSTEMD.md — `ros2_launch_*` → `project_launch_*` リネーム取り残し
- 証拠: `commands/README_SYSTEMD.md:9-11` (フォルダ構成に `ros2_launch_service` / `ros2_launch_sh`)、
  `:27` (`ros2_launch_<project_name>_sh を書き足す`)、`:36` (`systemd => ros2_launch.service => ros2_launch.sh`)
- 実態: 実在するのは `commands/project_launch_service` / `commands/project_launch_sh` (Read で確認)。
  `ros2_launch_service` は不在 (Read → not exist)。`project_launch_service` 自身のヘッダも
  `project_launch${TARGET}.sh` を参照 (`commands/project_launch_service:5`)。ルート `README.md:181` も
  `journalctl -xeu project_launch.service`。setup.sh も project_launch 系のみ使用。
- 修正 (一意): `ros2_launch_service`→`project_launch_service`、`ros2_launch_sh`→`project_launch_sh`、
  `ros2_launch_<project_name>_sh`→`project_launch_<project_name>_sh`、
  `ros2_launch.service => ros2_launch.sh`→`project_launch.service => project_launch.sh`
- 推奨ブランチ: `audit/docs-drift-systemd-readme-project-launch` (docs: プレフィックス)

#### A2. packages/README_ROS.md:39 — 消えた `systemd_files/` へのリンク
- 証拠: `packages/README_ROS.md:39` `[systemdの設定](../systemd_files/README_SYSTEMD.md)`
- 実態: `systemd_files/` は不在。同名ファイル `commands/README_SYSTEMD.md` が実在し内容も systemd
  設定手順そのもの (Read で確認)。同名一意マッピング。
- 修正 (一意): `../systemd_files/README_SYSTEMD.md` → `../commands/README_SYSTEMD.md`

#### A3. docker/README_DOCKER.md — 壊れた相対リンク3種
- 証拠と修正 (すべて一意):
  - `:3`, `:7` `[README_SYSTEM.md](../README_SYSTEM.md)` → ルートに `README_SYSTEM.md` 不在 (Read →
    not exist)。ルート `README.md` が setup 節を持ち (hardware_setup の README も `../README.md#setup`
    へリンク) 内容一致 → **`../README.md`**
  - `:35` `[systemdの設定](../systemd_files/README_SYSTEMD.md)` → A2 と同じく **`../commands/README_SYSTEMD.md`**
  - `:156`, `:270-272` `../systemd_files/setup.sh` / `systemd_files/ros2_launch_sh` →
    **`../commands/setup.sh`** / **`commands/project_launch_sh`** (いずれも実在を Read で確認。
    ルート `README.md:178` も `commands/setup.sh` と記載)
- 注記: 2026-06-22 試走では `../systemd_files/setup.sh` を「移動先断定不可 → 要相談」と判定していたが、
  現在は `commands/` 配下に同名・同役割のファイルが揃っており一意に確定できる (テーマ md の NG 例は
  更新推奨)。同ファイルの**構成図・環境変数表** (`:24-28`, `:67-77`) の全面古さは別件で「要相談」(下記)。

#### A4. README.md:150 — Debug コマンドの設置場所が誤り
- 証拠: `README.md:150` 「docker/common/scripts 内の便利コマンド」の直下に `gpull/dps/dstop/dup/din/
  dlogs/drm/dimages/drmi` を列挙
- 実態: `gpull` のみ `docker/common/scripts/`、他8コマンドは `commands/scripts/` に実在
  (エージェント find + `AGENTS.md:17` "host scripts are under `commands/scripts/`" と整合)
- 修正 (一意): 見出しを「`commands/scripts/` 内の便利コマンド (`gpull` のみ `docker/common/scripts/`)」
  の趣旨に追従修正

### B. project_rf_rover

#### B1. AGENTS.md — パス/スクリプト名がほぼ全て旧名 (CLAUDE.md と矛盾)
- 証拠: `AGENTS.md:13` `packages/rf/rf/`、`:22` `project_launch_robot.sh, project_launch_building.sh`、
  `:23` `setup_robot, setup_building, setup_sitl`、`:37-38` `--packages-select rf sitl`
- 実態 (Read で本文確認、実体はエージェントが ls/Read で確認): 実在は `packages/rf_rover/rf_rover/`
  (setup.py: `package_name = 'rf_rover'`)、ルートは `project_launch.sh` と `setup` のみ
  (`setup` は `case "$1"` で `full/sitl/isaacsim/yolo` variant)。`CLAUDE.md` 側は実装と一致。
- 修正 (一意): `packages/rf/rf/`→`packages/rf_rover/rf_rover/`、
  `project_launch_robot.sh, project_launch_building.sh`→`project_launch.sh`、
  `setup_robot, setup_building, setup_sitl`→`setup` (variant 引数方式)、
  `--packages-select rf sitl`→`--packages-select rf_rover sitl` (2箇所)
- 推奨ブランチ: `audit/docs-drift-rf-rover-agents-md`

#### B2. README.md:135 — `./setup_sitl` は不在
- 実態: `setup` の variant 方式のみ。修正 (一意): `./setup_sitl` → `./setup sitl`

#### B3. README.md:67-76 — omni_bld10.yaml の例が実ファイルと乖離
- 証拠: 例は `map: bld10_4F` + `include: {estimator: slam.yaml, controller: building_nav.yaml}`
  (Read で本文確認)
- 実態: 実 `config/omni_bld10.yaml` は `map: bld10_{floor}F_slice`、`include:` ブロック無し。
  estimator は `localizer:` から自動ロードされ include しない (`CLAUDE.md` の Config 構造節・
  `rover.yaml:64-66` と一致)。例は `localizer: amcl` なのに `estimator/slam.yaml` を include する
  自己矛盾も含む。
- 修正 (一意): 例を実ファイルの差分記述 (localizer/odom_source/map/initial_pose、include は
  controller のみが rover.yaml 側) に追従。書き換え内容は実 yaml のコピーで確定する。

#### B4. isaac_sim/README.md:76,80 — 旧 config キー名 `bld10_*`
- 実態: 実 `config/omni_bld10.yaml` は建屋非依存キー `building_floors` / `building_usd` を使用。
  `CLAUDE.md` が「旧 `bld10_*` は後方互換フォールバック」と明記。
- 修正 (一意): `bld10_floors`→`building_floors`、`bld10_usd`→`building_usd`。
  (後方互換で動くため実害小・低優先)
- スコープ注記: `isaac_sim/scripts/` (要相談指定) の外なので README 追従は可と判断。

### C. project_drone2 (修正一意だがスコープ確認推奨)

#### C1. isaac_sim/README.md:32,57 — `set_basic.py` パスに余分な `isaac_sim/` プレフィックス
- 実態: 環境リポは repo 直下 `environments/` に配備 (`setup:17`, `.gitignore`)。全 config yaml は
  `/workspace/environments/...` を使用 (`config/omni/sitl.yaml:38` 他3件)。`isaac_sim/environments/` は不在。
- 修正 (一意): `:57` `/workspace/isaac_sim/environments/...` → `/workspace/environments/...`、
  `:32` 相対リンク → `../environments/sakai_drone_lab/omni/scripts/set_basic.py`
- スコープ注記: drone2 の AGENTS.md は `isaac_sim/` 全体を forbidden 指定。README の追従修正は機械的
  だが、リポ規約を尊重し **PR 時は本文にスコープ注記を明記** (または管理者確認後に実施)。

#### C2. docs/ROADMAP_GAZEBO_SITL.md:55 — `gazebo_sitl/launcher/launch_px4_sitl.sh`
- 実態: `gazebo_sitl/` 配下に launcher 無し。実体は `launcher/launch_px4_sitl.sh`。同 doc の `:73` は
  正しいパスで記載しており `:55` のみ取り残し。
- 修正 (一意): `gazebo_sitl/` プレフィックスを削除。

---

## 要相談 (修正先が一意に定まらない / 設計・方針判断が必要)

| # | 場所 | 内容 | 理由 |
|---|------|------|------|
| 1 | acsl_infra `README.md:317` | `~/ros2/packages/acs/acs/Plotter/sample.py` — `packages/acs` はリポに無い | acs パッケージは project 側へ移管済み。削除か project 参照への書換かは方針判断 |
| 2 | acsl_infra `packages/README_ROS.md:13-33` | フォルダ構成/一覧に acs, localization_sys, mavlink_driver, multi_v531x, switchbot_driver, whill_driver (全て不在、実在は acsl_interfaces のみ) | 旧モノレポ構成の記述。一括削除は危険 (試走時の判定を踏襲) |
| 3 | acsl_infra `docker/README_DOCKER.md:24-28,67-77` | 構成図 (`ros2_autoware/`, `env.**`) と環境変数表 (`ID` 既定9 等) が実 docker-compose.yml (OTAG/DF/ROS_DOMAIN_ID 等) と全面不一致 | 書き換え範囲が広く実装理解を要する |
| 4 | acsl_infra `commands/setup.sh:20` | else 分岐が不在の `commands/project_launch.sh` を cp (実体は `project_launch_sh`)。フォールバック時に実失敗する**コード側**の潜在バグ | ドキュメントでなく基盤スクリプトの挙動変更。修正候補 (`project_launch_sh`) はほぼ確実だが管理者確認要 |
| 5 | rf_rover `README.md:64` | config ツリーに `apriltag_map.json` (実体は environment リポ側、`rover_main.py:119` が env config_dir から読む) | 行削除+方針文言の追加が必要で単純追従でない |
| 6 | rf_rover `README.md:201,211` | `./launcher/build_robot` / `./launcher/build_building` 不在 | README 下部の legacy 節 (旧 project 名 `rf` 前提)。節ごと現行 acsl ワークフローへ整理すべきかは管理者判断 |
| 7 | drone2 `docs/ROADMAP_GAZEBO_SITL.md:68` | `launcher/launch_gazebo_sitl.sh` 不在 | 文脈上 `launch_mavros2.sh` か `launch_px4_sitl.sh` か確定できない |
| 8 | rf_rover/drone2 の `common/` 参照 | `common/acsl/tools/base.py` 等はローカル未配置 (deploy 時 clone) で検証不可 | 読み取り専用領域・未配置は正常仕様 |

## 捨てた候補 (誤検知として棄却)

- drone2 `docs/ROADMAP_MULTI_VEHICLE.md` の未存在パス群 — 「追加する」と明記された将来計画で実在主張でない。
- drone2 `README.md:58` の「set_basic + set_drone」略記 — 実際は5段だが手順の略記でありパス乖離でない。
- rf_rover `isaac_sim/README.md` の生成物 `_scene_setup.gen.py` 系 — gitignore 済み生成物で未存在は正常。
- 各リポの `dup` モード名・console サブコマンド・config キーの大部分 — 実装と突合し一致
  (drone2 は `project_launch.sh:196-460` の case と完全一致、rf_rover は setup/console/config 全て一致)。

## 検証について

- 全確証指摘は参照先の実在/不在を Read (エージェントは加えて find/ls) で直接確認済み。
- ドキュメントのみの修正のため `bash -n` / `py_compile` 対象コードへの変更は無し (setup.sh の
  コードバグは要相談#4 として PR 対象外)。

## PR

**0件** — git/gh がハーネス権限で deny のため作成不能 (冒頭のギャップ参照)。
権限追加後の初回実行では、上記 A1〜B2 あたりの低リスク3件 (A1+A2+A3 は同一根 (systemd_files→commands
リネーム取り残し) として1 PR に束ねるのが妥当、B1、B2+B3+B4 で計3本) を推奨。

## 次回への引き継ぎ

- themes/docs-drift.md の NG 例 (`../systemd_files/setup.sh` 断定不可) は現状と不一致 — `commands/`
  に同名ファイルが揃った今は一意確定可能。テーマ md の更新を推奨。
- ハーネス allowlist へ git/gh (audit ブランチ限定) の追加が必要。
