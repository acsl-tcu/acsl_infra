# Nightly Audit 2026-09-10 — docs-drift

- ホスト: ruth / テーマ: docs-drift (ドキュメント/コメントと実装の乖離)
- スコープ: acsl_infra, project_rf_rover, project_drone2 (targets.conf repo 行 × テーマ対象)
- 手法: 前回 (08-30) 持ち越しの消化 + 基準線 (drone2 07e7dc6 / rf_rover 0574d833 /
  acsl_infra 4ccf26d) 以降の差分に絞った増分走査 (メインループで grep/Read + git 裏取り)。
- 実機安全: 実機・SITL いずれも起動していない (静的走査のみ)。

## 前回 (08-30) からの差分と PR 状態

- **前回 draft PR 3 本は全て未マージ (OPEN)**: drone2 #225 / rf_rover #383 / rf_rover #384
  (`gh pr view --json state` で確認)。#225 の対象行 (coop_scene_spec.md の
  `PF2_with_cable.usd` / `/ENV/drone2/omni/`) は main 上に残存 → 今夜は重複させず、
  同ファイルの別行のみ修正した (PR #228。#225 との hunk は 4 行以上離れており競合しない見込み)。
- 基準線以降の差分:
  - drone2: 19 commit (#226 coop ケーブル自前生成 → rope_chain.py 新設、二段階離陸、
    docs/coop_update_guide.md 新規、coop_scene_spec.md +60 行)。
  - rf_rover: ~50 PR (EV 乗降 nav、whill/go2/rbq10 機体追加、**Newton (Isaac Sim 6)
    車輪機体対応** = docs/NEWTON_RUNBOOK.md 新規 + NEWTON_MIGRATION.md +100 行)。
  - acsl_infra: 2 commit (dockerfile.isaac_sim に onnxruntime / 監査ハーネス修正)。
    docs 変更なし → 指摘なし。
- ローカル checkout: drone2・infra は main clean。**rf_rover は main 上にユーザー WIP**
  (`console` 変更 + 未追跡 `config/plot/`, `packages/rf_rover/rf_rover/plot_log.py`)。
  audit ブランチには持ち込まず (`git add` はファイル指定)、main に復帰済み。触っていない。

## 確証指摘と draft PR (今夜 2 本)

### PR 1: https://github.com/acsl-tcu/project_drone2/pull/228
`audit/docs-drift-coop-rope-defaults` — 98d6a40 (「生成ケーブルの質量・節数をアセット内蔵の
鎖に合わせる」) が `config/omni/coop_sl.yaml` だけを変えて docs が未追従 (`git show --stat` で確認)。
1. `docs/coop_scene_spec.md:52,55` 比較表「自前生成 (既定値)」 `0.249m × 12` / `0.24kg/本`
   → 実既定 `segments: 6` (0.498m/link) / `rope_mass: 0.12` (coop_sl.yaml:245,253)
2. 同 `:75,80,81` 生成構造ツリー `seg_0…seg_11` / `link_00…link_10` / `seg_11↔Hook`
   → 6 節ぶん (`lib/rope_chain.py:32-39` の命名規則 seg_0..seg_{N-1} / link_00..link_{N-2})
3. 同 `:97` 「4本×12節 = 48 剛体増」→ 24
4. 同 `:130` 「coop_sl.yaml (設定済み)」ブロックの `attach_path_template: .../RopeChain/Hook`
   → 実値 `.../Cable/Hook` (coop_sl.yaml:289、同 doc :61-63 の既定説明とも整合)
5. `config/omni/coop_sl.yaml:253` コメント「1リンク 0.01kg」→ 0.12/6 = **0.02kg**
   (同ファイル :241「0.02kg/link」・:247「seg 0.02kg×6」・coop_update_guide.md:103 と一致)。
   コメントのみ、キー/値は不変。
- 検証: 修正後の参照先を grep/Read で再確認。config/ は drone2 CLAUDE.md の編集可スコープ。

### PR 2: https://github.com/acsl-tcu/project_rf_rover/pull/435
`audit/docs-drift-newton-lidar-status` — `docs/NEWTON_MIGRATION.md:31` (PhysX 依存点表の
PhysX Lidar 行) 「rover2.usd 内蔵の front LiDAR publisher (車輪機体) は未対応のまま」が
**同文書 :98** (車輪機体表「USD 内蔵 LiDAR (rover2.usd) … `sensors.lidar_front.sim_create_newton:
true` で RTX 生成に倒す」) と矛盾。`NEWTON_RUNBOOK.md:61-62` と `config/robot/megarover2.yaml:54`
(`sim_create_newton: true`) も後者と一致。`git log -L31,31` で両行が同一コミット 4273ab83
(複数日を squash) で入ったことを確認 → 取り残し。末尾一文を下表参照に置換 (docs のみ)。

## 権限メモ (deny 原文つき)

- **NotebookEdit は今夜も deny** (drone2 audit ブランチ上で record_run.ipynb cell 323639ce
  に対して実測)。原文: "Permission to use NotebookEdit has been denied because Claude Code is
  running in don't ask mode"。前回方針どおり、notebook 修正は**要相談 M24 へ格上げ** (下記)。
- git/gh PR パイプライン (fetch / checkout -b / add <file> / commit -F / push -u /
  gh pr create --draft --body-file) は 2 リポとも全行程成功。`git log -L<n>,<n>:<file>` /
  `git show <rev> --stat --format=%s` / `git diff <rev> origin/main -- <paths>` も許可。
  `gh pr view <n> --json mergeable,files` 許可 (mergeable は UNKNOWN が返った)。

## 要相談 (修正先が一意でない / 実装側変更 / 仕様解釈が必要)

### 今夜の新規
| # | 場所 | 内容 | 理由 |
|---|------|------|------|
| M22 | rf_rover `docs/NEWTON_MIGRATION.md:69,84-85,140-141` | 「EV runtime は Newton 未対応」「未対応: EV/自動ドア runtime の scene query、建屋込みの車輪機体走行 (箱床のみ検証)」「残: 建屋込みでの走行・AMCL 収束、EV/自動ドア runtime」— 同文書 :100-108 と `NEWTON_RUNBOOK.md:8-9,71-75` (2F→EV→1F 通し、KinematicMirror、環境リポのエンジン判定) で解消済み | 日付付きの経緯記述が複数文にまたがり、削除か「→対応済」注記かの判断要 |
| M23 | rf_rover `docs/NEWTON_RUNBOOK.md:153,159-161` | `scratchpad/wheel_bld7_test.py` / `run_wheel_bld7.sh` / `wheel_box_test.py` を「ヘッドレス再現環境」として案内 — `scratchpad/` はリポ未追跡 (`git log --all -- scratchpad` 空、~/rover にも無し) | ローカル作業ファイル。リポへ取り込むか記述を外すかは作者判断 |
| M24 | drone2 `isaac_sim/notebooks/setup_isaac_yc_bld7.ipynb` (cell0 :14 FPVCam prim、:55/:100 記録出力先、実行順列挙の `set_fixed_cameras` 欠落) / `record_run.ipynb` cell 323639ce (FPVCam prim) | 08-30 確証済みの notebook 4 修正。今夜も main 上で grep 再確認 (sitl_yc_bld7.yaml:46,229 / record_motion.py:19,44 と不一致のまま) | **headless では NotebookEdit deny で修正不能** → 手動修正を依頼。setup_isaac_bld10.ipynb の FPVCam は正 (誤検知しない) |
| M25 | rf_rover `isaac_sim/scripts/scene/readme.md:10-19` | 「ここに残るのは…」一覧に `front_lidar.py` / `rtx_lidar.py` / `engine_articulation.py` / `legged_bridge.py` / `newton_compat.py` / `caster_orient.py` / `set_mapping_box.py` 等が無い。CLAUDE.md の同趣旨の列挙 (twist_bridge / back_lidar / camera_bridge / set_rover / robot_spec / local_ref_marker) も同様 | 列挙の追加は各ファイルの説明文を書く判断が要る (機械的でない) |
| M26 | drone2 `config/omni/coop_sl.yaml:215-224` | 「何が変わるか (アセット 6 節 → 生成 12 節)」「3m を 6 本の剛体棒で表す粗さが無くなる」「4 本 x 12 節 = 48 剛体」の解説ブロック — 既定が 6 節 (98d6a40) になった今は説明の前提自体が失効 | 数値差し替えでは意味が通らず、ブロックの書き直しが要る (PR #228 では :253 の算術のみ修正) |

### 状態更新
- M18 (drone2 ROADMAP_GAZEBO_SITL.md:41 vs :55,73,110 の launch_px4_sitl.sh 自己矛盾): **残存** (行不変)。
- M19 (rf_rover launch_nav2.sh の ENV_BUILDING フォールバック): 未再調査 (ランチャ差分なし)。
- M9 残存 (rover setup:21-42 は今回も差分なし)。M1〜M8・M11・M13〜M17・N1・N3〜N6・
  infra 07-17 系 4 件は未再走査 (前回時点で全残存)。
- 棄却リスト (08-19 / 08-30 版) は全て維持。

## 検証済み・指摘なし (再検出しない)

- drone2 `docs/coop_update_guide.md` (新規): `dup all SITL_OMNI_MULTI 4 omni/coop_sl_circle.yaml`
  (project_launch.sh:422 / config 実在)、`isaac_sim/tests/run_offline.sh` / `run_sim.sh` /
  `test_coop_rope.py`、`update_common` / `disaac` (acsl_infra/commands/scripts)、
  「notebook の cell 5 (アセット読み直し)」(setup_isaac_coop_drone.ipynb :257 に実在)、
  sl_takeoff_coop.yaml の `two_stage/stage1_te/dwell/stage2_te/taut_margin`、hlc_sl_coop.yaml の
  `R23: 0.1` / `use_estimated_load_mass: false` / `load_mass_tau` / `load_mass_max`、
  sl_coop_omni.yaml `mL_freeze_until_lifted` — 全て実在・実値一致。
- rf_rover `docs/NEWTON_RUNBOOK.md` (新規): 設定キー一覧 (`wheel_accel/decel`, `sim_create_newton`,
  `blind_sectors_deg`, `sim.newton.*` 9 キー, `isaac_sim.newton.*` 8 キー, `perf.*` 3 キー,
  `door_wait_maxw` / `ev_hard_stop_*` / `max_wz_rate`) は config または読み手コード
  (wheel_sphere_colliders.py:73-85 / newton_compat.py:219-290,539-545 / set_env.py:1183-1199)
  で実在。`ros2 run rf_rover lidar_blind_probe` は setup.py:32 に entry point あり。
  `/workspace/isaac_sim/yc_bld7.py` / `setup_rover_physics.py` 実在。
- rf_rover `docs/OBSTACLE_AVOIDANCE.md` / `ROBOT_SPEC.md` / `ROBOT_IMPORT.md` 追記分:
  `calib.BuildingSensor.front/back_blind_sectors_deg` (rover_main.py:206-210)、
  `sim.newton.{wheel,caster}_{torsional,rolling}_friction` (wheel_sphere_colliders.py:73-76)、
  setup の ROBOTS 追加 (whill/go2/rbq10 は config/robot/ に実在) — 一致。
- `~/ENV/rbq10/omni/src/vendor_bridge/RUNBOOK.md` 参照 (NEWTON_*.md) — ~/ENV は ls 不可のため
  未検証 (秘匿領域、指摘にしない)。

## 捨てた候補 (今夜)

- rf_rover `NEWTON_RUNBOOK.md:4` の `~/ENV/...RUNBOOK.md` — 検証不能 (上記)。
- drone2 `coop_update_guide.md:85` 「詳細は `docs/` ではなくメモ参照」— 参照先が不特定で
  drift の定義に当たらない。
- drone2 `coop_scene_spec.md:135` 「アセット内の prim 名 (`/Drone/RopeChain/Hook` …)」—
  アセット側の記述としては正しい (生成時は Cable/Hook だが :130 の修正で文脈は通る)。

## 次回への引き継ぎ

- draft PR: drone2 #225 / #228、rf_rover #383 / #384 / #435 → マージ確認。
- ローカル audit ブランチ: drone2 `audit/docs-drift-coop-rope-defaults`、rf_rover
  `audit/docs-drift-newton-lidar-status` (push 済み、merge 後の -d は branch-cleanup テーマ)。
  checkout は 3 リポとも main 復帰済み (rf_rover のユーザー WIP は main 上にそのまま)。
- 次回 docs-drift: (1) PR 5 本のマージ確認、(2) M24 (notebook) は手動修正待ち — NotebookEdit が
  許可されない限り再調査不要、(3) M22/M23/M25/M26 の扱い確認、(4) 基準線
  drone2 3a53ebb / rf_rover ae36f052 / acsl_infra 689683d 以降の差分走査。
