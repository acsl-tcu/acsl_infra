# Nightly Audit 2026-08-19 — docs-drift

- ホスト: ruth / テーマ: docs-drift (ドキュメント/コメントと実装の乖離)
- スコープ: acsl_infra, project_rf_rover, project_drone2 (targets.conf repo 行 × テーマ対象)
- 手法: Explore 3並列 (rf_rover=very thorough / drone2=very thorough / acsl_infra=medium)
  → 駆動側が main 実体で file:line 単位に再検証してから PR 化。
  **注意**: rf_rover のローカル checkout がユーザーの `feature/env-phase2` (WIP, PR #326)
  だったため、Explore の結果は駆動側が main へ checkout し直して全件再検証した
  (作業後 `feature/env-phase2` へ復帰済み)。

## 前回 (08-08) からの差分と PR 状態

- **前回 PR は全てマージ済み**: rf_rover #321 (08-12) / #322 / #323、acsl_infra #56 (08-10)、
  drone2 #153 (08-10)。ros2-structure の rf_rover #324 もマージ済み。持ち越しの
  「マージ待ち」項目はゼロに。
- rf_rover: 08-14 に**建屋機能の環境リポ移管 (ad5c9021, vendor 自己完結)** —
  scene/ から gen_bld10/gen_yc_bld7/auto_door_runtime/elevator_action_runtime/
  spawn_people/set_lights/floor_loader 等 12 本を削除し環境リポへ。08-15 に
  ENV_BUILDING 自動 export (4f6c377b)。→ 今夜の主戦場1。
- acsl_infra: env-phase2 (#59) で建屋別バインドマウント廃止 (/common/occupancy bind 削除、
  /root/environment/<name> は entrypoint symlink 化)、disaac キャッシュ /root 化 (#60)。
  compose/entrypoint のコメントは実装と一致しており乖離なし。
- drone2: **前回まで休眠 → 08-01 以降 ~200 コミット**の大活動 (yc_bld7 フライスルー撮影、
  Path Editor、coop 吊り下げ、照明自動配置、ENV 化 f335b78)。→ 今夜の主戦場2。
- rf_rover open PR: #326 (env-phase2: launcher の地図パス差し替え)、#327 (ROBOT_SPEC.md) —
  正常な WIP。#326 は /common/occupancy 系 docs 追従の前提になるため下記要相談参照。

## 確証指摘と draft PR (今夜 3 本)

### PR 1: https://github.com/acsl-tcu/acsl_infra/pull/61
`audit/docs-drift-readme-paths` — README.md のみ。
1. コンテナ内パス `/root/project_ws/src/ros_packages` (4箇所) → `/root/ros2_ws/...`
   (`docker-compose.yml:43,103` の実体。project_ws は grep 0 件の旧名)
2. `dup all` 注記 `commands/project_launch.sh` → `$ACSL_WORK_DIR/project_launch.sh`
   (`dup:38,147` / `completions.sh:7`)
3. フォルダツリーの迷い込み1文字「ダ」削除 (前回持ち越しの同乗案件)

### PR 2: https://github.com/acsl-tcu/project_rf_rover/pull/333
`audit/docs-drift-vendor-leftovers` — vendor 移管 (ad5c9021)・ENV_BUILDING 自動化
(4f6c377b) の残骸追従。docs/config コメントのみ、実装・設定値は無変更。
1. isaac_sim/README.md: 削除済み 3 スクリプトへの**リンク切れ** (:88 spawn_people /
   :108 auto_door_runtime / :121 elevator_action_runtime) → vendor 所在
   (`/ENV/bld10/repo/omni/scripts/`) 表記へ (scene/readme.md:3-8 の既存文言に統一)
2. scene/readme.md: 6/3 撤去済み `archive_unused_20260330/` 記述削除 (22a90b81 で消失、
   実体不在を ls 確認)、debug/ 一覧を実体 18 本へ ls 突合 (旧 5 本)、補足 2 行を
   robot 諸元 sim.usd (`set_env.py:74-76`) / `isaac_sim.building_usd`
   (`omni_bld10.yaml:115` = Bld10_260507.usd) の現行解決へ
3. docs/EXPERIMENT_YC_BLD7.md:80: gen_yc_bld7.py の所在を環境リポへ
   (EV_XY_RADIUS=3.0 自体は `git show ad5c9021~1` で実在確認)
4. config/omni_bld10.yaml:33 コメント: 不在の `gen_bld10_trial` → `gen_bld10` (:45 実キー)
5. config/omni_yc_bld7.yaml:18 コメント: ENV_BUILDING 手動 export 前提 →
   project_launch.sh の自動 export へ

### PR 3: https://github.com/acsl-tcu/project_drone2/pull/217
`audit/docs-drift-env-paths` — ENV 化 (f335b78) への docs 追従。
1. isaac_sim/README.md:32 の**リンク切れ** `[environments/sakai_drone_lab/.../set_basic.py](...)`
   (environments/ は gitignore・リポ内不在) → config 正本 `sitl.yaml:38` の
   `/ENV/sakai_drone_lab/repo/omni/scripts/set_basic.py` 表記へ
2. 同 :57 Jupyter 手動実行例の旧 `/workspace/environments/...` → 同上
3. docs/PHASE4_TEST_GUIDE.md:76 の sitl.yaml 引用例 env_config_dir → 実ファイル
   (`sitl.yaml:46` = `/ENV/sakai_drone_lab/repo/config`) に一致

## 権限メモ (deny 原文つき)

- `git pull --ff-only` → deny。原文: "Permission to use Bash has been denied because
  Claude Code is running in don't ask mode"。素の `git pull` 未検証 (ハーネスが fetch 済みで
  不要だったため)。
- `ls /home/sekiguchi/ENV/yc_bld7/repo/omni/scripts/` → deny (原文: "Permission to use
  Bash with command ls /home/sekiguchi/ENV/... has been denied")。**~/ENV 配下は ls 不可**
  (秘匿アセット領域)。vendor 実体の確認は `git show <移管前コミット>:<path>` で代替した。
- 一方 `git show <rev>:<path> | grep -n <pat>` は**パイプ付きでも許可された** (2 回成功)。
  「パイプは全 deny」という過去メモは少なくとも git show | grep には当てはまらない。
- **Explore サブエージェント内では git/gh が全 deny** (rf_rover 担当が git show を打てず
  ブランチ違いを補正できなかった)。fan-out はファイル読み専任にし、git 裏取りは
  メインループで行う運用が正。
- PR パイプライン (checkout -b origin/main / add / commit -F / push -u /
  gh pr create --draft --body-file) は 3 リポとも全行程成功。ラベル付与は未試行
  (08-08 に deny 実測済みのため PR 本文明記で代替)。

## 要相談 (修正先が一意でない / 実装側変更 / 仕様解釈が必要)

### 今夜の新規
| # | 場所 | 内容 | 理由 |
|---|------|------|------|
| M9 | rf_rover `CLAUDE.md` (環境リポ節) vs `setup:21-44` | CLAUDE.md/ad5c9021 は「environments/ シンボリックリンク運用を廃止」と宣言するが、setup は今も `environments/<name>` symlink を生成する (mkdir + ln -sfn)。リポ内矛盾 | setup 側の更新漏れか意図的併存かの確認要 (setup は編集禁止ファイル) |
| M10 | rf_rover `docs/MAPPING.md:24,32,54,61,116,302,305` | /common/occupancy 前提の記述 6 箇所。acsl_infra 側は bind 廃止済み、rover 側コード/launcher の差し替えは open PR #326 が進行中 | **#326 マージ後に一括追従すべき** (先回りすると PR と競合/齟齬) |
| M11 | rf_rover `docs/PEOPLE_SIM_ROADMAP.md` / `docs/BCPS_SIM_RUNTIME_MERGE.md` / `docs/PR_VIDEO_ROADMAP.md:201` | vendor 移管でロードマップ/移植経緯文書の前提 (scene/ 直下の実体) が変化。BCPS_SIM_RUNTIME_MERGE.md:128 は自己矛盾も (`isaac_sim/config/bcps_sim.json` 不在、:124 が正) | 歴史文書化 or 棚卸しの判断要 |
| M12 | drone2 `config/omni/coop_sl.yaml:130` | `env_config_dir: /workspace/environments/...` — omni config で唯一 ENV 化されていない (sitl/sitl_pid/sitl_sl は /ENV 済み) | config 値の変更 = 実装側。coop 起動への影響確認要 |
| M13 | drone2 `config/reference/yc_bld7_spline_3f.yaml:4` / `bld10_spline_4f.yaml:4` | path_file が指す `yc_bld7_3f.json` / `bld10_4f.json` が config/paths/ に不在 (コメントアウトの変種 config からのみ参照) | ファイル削除 or 経路 JSON 復元の判断要 |
| M14 | acsl_infra `commands/scripts/gpush:29-30` / `docker/common/scripts/gpull:63-64` | 旧「プロジェクト内包型」environments ループが「共有型への移行完了まで併存」コメント付きで残存 (新 ~/ENV ループと並走) | 意図的な暫定コード。撤去時期はフェーズ3の運用判断 |
| M15 | acsl_infra (欠落) | ~/ENV 共有アセット規約・env_sync・disaac を説明する .md がリポ内に皆無 (compose/entrypoint のコメントのみ) | 欠落補完 (置き場所・文言の判断要)。M1 (WSL2 DDS 節欠落) と同種 |

### 確証あり・一意だが PR 枠 (3本/晩) 超過 → **次回 docs-drift の PR 候補** (再調査不要)
- drone2 `docs/ROADMAP_GAZEBO_SITL.md:68`: `launch_gazebo_sitl.sh` → `launch_px4_sitl.sh`
  (同ファイル :41,55,73,110 は改名注記済み、:68 だけ未追従)
- drone2 `docs/coop_scene_spec.md:25,39,51` / `docs/ISAAC_SL_TEST_GUIDE.md:174`:
  `PF2_with_cable.usd` → `TowingDrone2.usd` (`coop_sl.yaml:137` が正、doc:69 と自己矛盾。
  `set_coop_drones.py:3,8,143` のコメントも同罪だがコード側は要スコープ判断)
- drone2 `~/drone2` → `~/drone` (PHASE4_TEST_GUIDE.md:60,95 / GAZEBO_SITL_TEST_GUIDE.md:44。
  デプロイ実体・docs/setup.md:53 のプロンプトと不一致)
- drone2 notebooks (要 NotebookEdit): setup_isaac_yc_bld7 cell0 の実行順に
  `set_fixed_cameras` 欠落 (`sitl_yc_bld7.yaml:46`)、FPVCam prim パス
  `/World/Drone/PF2/FPVCam` → `/World/Drone/PF2/Model/FPVCam` (record_run も同罪)、
  記録出力先 `/workspace/Data/render/motion_record.usda` → 実既定
  `/workspace/isaac_sim/recordings/motion_take01.usda` (`record_motion.py:43-44`)
- drone2 `docs/YC_BLD7_LIGHTING.md:51,66`: 高さ既定表が env リポ実値と不一致
  (1F の既定は 2.9 でなく 3.6 — `environment_yc_bld7/config/lighting.yaml:17-21`)。
  :57 の Z1 踊り場 2 灯目 (z+5.8) 欠落も

### 継続 (今夜、現状を実測確認)
- **M1〜M8: 全て残存** (acsl_infra M1 WSL2 DDS 節 / M2 setup.sh:15 rules パス /
  M3 for_new_project --env-file、rf_rover M4 手動 clone 手順 / M5 旧アーキ README
  (+`packages/rf_rover/rf_rover/readme.md:270-275` 同根) / M6 CLAUDE.md の不在 `stop` /
  M7 MegaRover3 vs megarover2 / M8 rear_swing 0.25 コメント 2 箇所 —
  docs/OBSTACLE_AVOIDANCE.md:268 は 0.1 更新済みでコメントのみ取り残し。ただし現値 0.1 では
  「12cm ≪ 0.1」が偽になるため単純追従不可のまま)。
- **N1 残存** (orient 保持記述: BCPS_NAV_INTEGRATION.md:51,53,56 / PHASE_FLOW.md:34,40 /
  tscf_controller.py:63。実装は回頭後即 clear = phase_actions.py:246,251,282,287)。
  **N2 は解消と判定** (omni_bld10.yaml:17 の backend: action 記述は rover_main.py:411-427 と
  一致 — 今後は再検出しない)。**N3 残存** (arrive_settle_sec、bcps_interface.py:70 のみ)。
- drone2 **N4〜N6 残存** (N4 sbc_onboard_setup.md:125 mavros2 ベースタグ — 現 setup:51 も
  image_drone2 で状況不変 / N5 ./setup mocap 記述皆無 / N6 isaac-sim 6.0.0-dev2 —
  現 setup:83 は 6.0.1、**setup:79 のコメントも dev2 のまま**でリポ内競合は継続)。
- acsl_infra 07-17 系 4 件残存 (README.md:317 packages/acs / README_ROS.md リンク切れ 6 本 +
  `multi_v531x` 誤記 / README_DOCKER.md env.** 11 箇所 — 今夜の走査で **dockerfile.base 不在・
  compose service 表齟齬・volumes 表の過不足・環境変数表の全キー不一致**も追加確認、
  節ごと書き直しが妥当 / setup.sh:20 の cp)。

## 捨てた候補 (棄却理由つき)

- rf_rover config の `building_module: gen_bld10` / `runtime_behaviors` 等のモジュール名 —
  set_env.py が環境リポ優先で解決する正しい設定値 (omni_yc_bld7.yaml:50 コメントも所在明記済み)。
- rf_rover `rover_main.py:741,751` / `docs/ISAAC_IFC_METADATA_TOOLS.md:145` 等の
  auto_door_runtime 「挙動」言及 — 実体は vendor に存在し記述は現行も正。
- rf_rover `isaac_sim/README.md:30` の `tools/bundle_py.py` 表記 — リポルート相対の慣行と
  解せば正 (実体 tools/bundle_py.py)。曖昧でノイズのため見送り。
- drone2 `docs/PATH_EDITOR_GUIDE.md:31` の `max_tilt` — UI ラベル (index.html:74) は
  max_tilt であり「UI の表記」としては正。config キー max_tilt_deg との対応は曖昧で見送り。
- drone2 `GAZEBO_SITL_TEST_GUIDE.md:89,94` の start_gazebo_sitl.sh — 「以前は〜」の
  歴史記述で残置可。
- notebooks の実行済み cell output 内の旧パス — 自動生成物 (再実行で消える)。
- omni_yc_bld7.yaml:9 の `environments/yc_bld7/config/bcps_sim.json` — entrypoint symlink
  経由で解決する慣行表記 (EXPERIMENT_YC_BLD7.md:8 等も同表記で統一されている)。

## 次回への引き継ぎ

- 今夜の draft PR 3 本: acsl_infra #61 / rf_rover #333 / drone2 #217。
- ローカル audit ブランチ: acsl_infra `audit/docs-drift-readme-paths`、rf_rover
  `audit/docs-drift-vendor-leftovers`、drone2 `audit/docs-drift-env-paths` (push 済み、
  merge 後 -d は branch-cleanup テーマ)。checkout は acsl_infra/drone2 = main、
  **rf_rover = feature/env-phase2 (ユーザーの WIP に復帰済み)**。
- 次回 docs-drift: (1) 上記 PR 3 本のマージ確認、(2) 「次回 PR 候補」節の drone2 4 件を
  そのまま PR 化 (再調査不要、main 実測済み)、(3) M9 (setup vs CLAUDE.md 矛盾) と
  M10 (#326 マージ後の MAPPING.md 追従) の状態確認、(4) 08-19 以降の差分走査。
