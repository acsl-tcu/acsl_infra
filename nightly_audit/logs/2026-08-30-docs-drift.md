# Nightly Audit 2026-08-30 — docs-drift

- ホスト: ruth / テーマ: docs-drift (ドキュメント/コメントと実装の乖離)
- スコープ: acsl_infra, project_rf_rover, project_drone2 (targets.conf repo 行 × テーマ対象)
- 手法: 前回 (08-19) 持ち越しの消化 + 08-19 以降差分に絞った増分走査 (メインループで
  Grep/Read + git 裏取り。Explore fan-out は今回不要な規模だった)。

## 前回 (08-19) からの差分と PR 状態

- **前回 draft PR 3 本は全てマージ済み** (08-21): acsl_infra #61 / rf_rover #333 / drone2 #217。
- **rf_rover #326 (/common/occupancy 廃止) もマージ済み** (08-21) → 保留していた M10
  (MAPPING.md 追従) が解禁 → 今夜 PR 化。
- **drone2 #218 マージで M12 解消** (coop_sl.yaml の env_config_dir は /ENV 化済み。再検出しない)。
- 大きな動き: 機体資産の `~/ENV/<機体名>/omni/` namespace 化
  (drone2 ec013ad=#223: pf2/towing_drone/payload_drone、rover 8c7ff0d5→939909b3=#368:
  megarover2 統一) + 機体リポ robot_<name> 配備 (drone2 #224 / rover #369 / infra #62)。
  → 今夜の主戦場 (docs の旧 namespace 取り残し)。
- rf_rover は 08-19 以降 ~50 PR (EV 乗降・機体 plug-and-play・カメラ等) だが docs の変更は
  CLAUDE.md と新規 docs/ROBOT_IMPORT.md のみ。ROBOT_IMPORT.md の参照先
  (probe_robot_usd.py / robot_smoke_test.py / config/robot/*.yaml) は全て実在確認済み。
- ローカル checkout: 3 リポとも main・clean (rf_rover のユーザー WIP ブランチは解消済み。
  復帰作業は不要だった)。

## 確証指摘と draft PR (今夜 3 本 = 上限)

### PR 1: https://github.com/acsl-tcu/project_drone2/pull/225
`audit/docs-drift-robot-ns` — docs 7 ファイル。持ち越し候補 (a)(b)(c) + namespace 追従。
1. 旧 `~/ENV/drone2/omni/` → `~/ENV/pf2` / `~/ENV/payload_drone` / `~/ENV/towing_drone`
   (PHASE4_TEST_GUIDE / ISAAC_SL_TEST_GUIDE / setup.md / ROADMAP_ISAACSIM_SITL /
   coop_scene_spec:67。正本 = env_setup_guide.txt と config/omni/*.yaml 実値で突合)
2. `PF2_with_cable.usd` → `TowingDrone2.usd` (coop_scene_spec:25,51 / ISAAC_SL_TEST_GUIDE:174。
   coop_sl.yaml:146 が正)
3. ROADMAP_GAZEBO_SITL.md:68 `launch_gazebo_sitl.sh` → `launch_px4_sitl.sh` (持ち越し (a))
4. `cd ~/drone2` → `cd ~/drone` 3 箇所 (持ち越し (c))
5. PHASE4:79 の sitl.yaml 引用 `drone_prim_path: /World/PF2` → `/World/Drone/PF2` (実値 :56)
- `docs/setup_tcu.html` (setup.md の pandoc 生成物) は自動生成物として残置。

### PR 2: https://github.com/acsl-tcu/project_rf_rover/pull/383
`audit/docs-drift-occupancy-paths` — M10 解禁分。
1. MAPPING.md の `/common/occupancy` 6 箇所 (:24,32,54,116,302,305) を実挙動
   (`/root/environment/<建屋>/occupancy`、launch_nav2.sh `_resolve_map_yaml`) へ
2. **ランチャコメント自体の drift**: launch_nav2.sh:33 / launch_slam_toolbox.sh:56 の
   「旧 /common/occupancy にフォールバック」は直下のコード (:38 / :61 =
   `/root/environment/${ENV_BUILDING:-bld10}/`) と不一致。コメントのみ追従、`bash -n` pass。
- packages/ 内の /common/occupancy 言及 (building_reference.py:1163 等) はコード実体と
  一致するため対象外 (コード側のフォールバック撤去は実装変更 = 要相談 M18 参照)。

### PR 3: https://github.com/acsl-tcu/project_rf_rover/pull/384
`audit/docs-drift-megarover2-ns` — megarover2 統一 (939909b3) の取り残し。
1. **env_setup_guide.txt:25 の移行手順バグ**: `ln -s ../megarover/omni` が旧名のまま
   (939909b3 で mv 先だけ修正)。手順どおりだと dangling symlink → `../megarover2/omni` へ
2. ISAAC_ASSET_SETUP.md:4,10,33,40,41 の `~/ENV/rf_rover/omni/` 全面追従
   (:41 は set_rover.py:22 実値と直接矛盾)
3. ROBOT_SPEC.md:57 → 総称 `/ENV/<機体名>/omni/*.usd` (現規約)
4. set_rover.py:21 コメントのみ追従 (py_compile pass。シーンスクリプトだがコメント 1 行)

## 権限メモ (deny 原文つき)

- **NotebookEdit は don't-ask で deny**。原文: "Permission to use NotebookEdit has been
  denied because Claude Code is running in don't ask mode"。さらに Edit ツールでの .ipynb
  直接編集はツール層で拒否 ("File is a Jupyter Notebook. Use the NotebookEdit to edit
  this file.")。シェルでの書き換えは意図の迂回になるため実施せず →
  **headless 監査では notebook 修正は不能**。持ち越し候補 (d) は下記へ棚上げ。
- git/gh の PR パイプライン (fetch / checkout -b / add / commit -F / push -u /
  gh pr create --draft --body-file) は 3 本とも全行程成功。`gh pr view <n> --json ...` も許可。

## notebook 修正待ち (確証済み・NotebookEdit 許可があれば即実施可)

drone2 `isaac_sim/notebooks/` (すべて main 実測で再確証済み、2026-08-30 時点):
- setup_isaac_yc_bld7.ipynb cell0: 実行順列挙に `set_fixed_cameras` 欠落
  (sitl_yc_bld7.yaml:46 は set_gimbal と set_auto_door の間) / FPVCam prim
  `/World/Drone/PF2/FPVCam` → `/World/Drone/PF2/Model/FPVCam` (camera.parent :229 = /Model)
- 同 cell bfeb758b + cell 60a4f270: 記録出力先 `/workspace/Data/render/motion_record.usda`
  → 実既定 `/workspace/isaac_sim/recordings/motion_take01.usda` (record_motion.py:19,44)
- record_run.ipynb cell 323639ce: FPVCam prim 同上
- **注**: setup_isaac_bld10.ipynb の `/World/Drone/PF2/FPVCam` は sitl_bld10.yaml に
  camera.parent が無く body_path 直下が正 → **修正不要** (誤検知しないこと)。

## 要相談 (修正先が一意でない / 実装側変更 / 仕様解釈が必要)

### 今夜の新規
| # | 場所 | 内容 | 理由 |
|---|------|------|------|
| M18 | drone2 `docs/ROADMAP_GAZEBO_SITL.md:41` | 「(旧 launcher/launch_px4_sitl.sh (旧 start_gazebo_sitl.sh) は削除済 → dup px4_sitl 経由に統合)」— だが launcher/launch_px4_sitl.sh は実在し、同 doc :55,73,110 は存在前提。リポ内自己矛盾 | どちらが現行運用か (dup px4_sitl の実体含め) 判断要 |
| M19 | rf_rover `launcher/launch_nav2.sh:38,44` 等 | フォールバック先・save_map 先が ENV_BUILDING 依存のまま (#326 で「ENV_BUILDING 不要」化した主経路と非対称) | 実装側の整理判断。docs は実挙動へ追従済み (PR #383) |

### 状態更新
- **M10: 解消** (今夜 PR #383。マージ確認は次回)。
- **M12: 解消** (drone2 #218 マージ済み。再検出しない)。
- M9 **残存** (rover setup:21-42 は今も environments/ symlink を生成。CLAUDE.md は「廃止」
  宣言のまま。setup は編集禁止ファイル)。
- M11, M13〜M15 未再調査 (差分なしのため状態変化なしと推定)。M1〜M8 / N1・N3〜N6 /
  infra 07-17 系 4 件は今回未再走査 (前回時点で全残存)。
- 棄却リスト (08-19 版) は全て維持。**追加棄却**: drone2 YC_BLD7_LIGHTING.md の高さ既定表
  (08-19 に候補としたもの) — 現 environment_yc_bld7/config/lighting.yaml:104-110
  (1F/2F=2.9, 3F=3.1, 4F=3.6) と**一致**しており drift なし。再検出しない。

## 捨てた候補 (今夜)

- drone2 `isaac_sim/scripts/set_coop_drones.py:3,8,143` / `set_coop_payload.py:4` /
  `record_flight.py:32` の旧アセット名/パス (コード内 docstring・既定値) — コード側の
  変更はスコープ判断が要るため docs のみ追従 (:143 は既に機体別 namespace 案内に更新済み)。
- rover `setup_isaacsim*.ipynb` / `render_movie.ipynb` の cell output 内旧パス — 自動生成物。
- drone2 `docs/setup_tcu.html` — setup.md からの生成物。
- rover ISAAC_ASSET_SETUP.md のアセット一覧ツリー (rover.usd ほか) — ~/ENV は ls 不可で
  実在検証できず、env_setup_guide.txt と粒度が違うだけの可能性。パスのみ追従し一覧は温存。

## 次回への引き継ぎ

- 今夜の draft PR 3 本: drone2 #225 / rf_rover #383 / rf_rover #384 → マージ確認。
- ローカル audit ブランチ: drone2 `audit/docs-drift-robot-ns`、rf_rover
  `audit/docs-drift-occupancy-paths` / `audit/docs-drift-megarover2-ns` (push 済み、
  merge 後の -d は branch-cleanup テーマ)。checkout は 3 リポとも main 復帰済み。
- 次回 docs-drift: (1) PR 3 本のマージ確認、(2) **notebook 修正待ち節を NotebookEdit
  許可の有無を見て処理** (許可が出なければ要相談へ格上げ)、(3) M18/M19 の扱い確認、
  (4) 基準線 drone2 07e7dc6 / rf_rover 0574d833 / acsl_infra 4ccf26d 以降の差分走査。
