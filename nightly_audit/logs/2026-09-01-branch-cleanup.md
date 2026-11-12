# Nightly Audit 2026-09-01 — branch-cleanup

- テーマ: branch-cleanup (作業ブランチの後始末 / main へ復帰)
- ホスト: ruth / 実行: 夜間自動監査 (PR は作らないテーマ)
- 対象: targets.conf 全 5 checkout (acsl_infra / project_rf_rover / project_drone2 のソース、~/rover / ~/drone の deploy)

## 結果サマリ

**全 5 checkout が main 在圏・detached HEAD なし・自動整理 0 件 (整理対象なし = 成功)。**
前回 (08-21) 持ち越しの大半が解消していた。~/drone は main に復帰済みだが origin/main より 4 commit 遅れ (要相談)。

| checkout | branch | tree | ローカル余剰 br | 判定 |
|---|---|---|---|---|
| acsl_infra (src) | main | untracked (監査ログのみ) | なし | OK |
| project_rf_rover (src) | main | **汚れ** (M14 + untracked 2) | audit/* 5本 + viewport (全て正常 WIP) | 注意 |
| project_drone2 (src) | main | クリーン | audit/docs-drift-robot-ns (PR #225 WIP) | OK |
| ~/rover (deploy) | main | **汚れ** (M14 + untracked 3) | なし | 注意 (コンテナ稼働中) |
| ~/drone (deploy) | main (**behind 4**) | untracked (take01.mp4) | feat/coop-load-mass-estimator (未マージ) | 注意 |

## 実施した整理

なし。`git branch --merged origin/main` で main 以外に出るローカルブランチはどの checkout にも存在せず、
main 以外に居る checkout もなかった。ブランチ削除・切替は一切行っていない。

## 前回 (2026-08-21) からの解消確認

- **rf_rover src**: `refactor/robot-spec-plug-and-play` (未 push WIP)・`feature/env-phase2`・
  `docs/robot-spec-checklist` の 3 ブランチがローカルから消滅 (手動処理済みと判断)。
- **~/drone**: `fix/coop-env-config-path` 在圏が解消、main に復帰済み。前回稼働していた drone2
  コンテナは消滅 (docker ps -a に痕跡なし)。`fix/mavros2-abi-upgrade` 等も残っていない。
- **~/rover**: untracked の config/glass_test.csv / movable_test.csv が消滅 (解消)。
- **drone2 リモート**: マージ済み滞留 30本 → **0本** (解消)。

## 要相談 (変更せずに記載)

1. **~/drone: main が origin/main より 4 commit 遅れ** (07e7dc6 / 9918235 / 96610ce / ec013ad —
   #223 env-robot-namespaces と #224 setup-robot-repos)。ハーネスの ff 更新が効いていない。
   作業ツリーは take01.mp4 (untracked) のみで、drone2 系コンテナは非稼働のため、
   `git pull --ff-only` での手動更新は安全にできる状態。環境 namespace 変更 (#223) を含むので
   次回デプロイ前に更新推奨。
2. **rf_rover src (~/GitHub/sb/project_rf_rover): main 上に未コミット変更あり** — M 11 ファイル
   (robot_spec.py / rover_main.py / obstacle_avoid.py / isaac_sim scene 系 / config/robot 等) +
   untracked (config/plot/, plot_log.py)。ユーザー WIP と判断し不触。ブランチ化 or commit を推奨
   (前回 WIP ブランチ `refactor/robot-spec-plug-and-play` の後継作業に見える)。
3. **~/rover: main 上に未コミット変更あり** (src とほぼ同内容 + omni_yc_bld7.yaml,
   setup_isaacsim_yc_bld7.ipynb, scene_setup_progress.log 等)。rover 系コンテナ多数稼働中
   (rover/nav2/yolo/rf_tf/isaac-sim ほか Up 12h〜3d) の実作業中 deploy のため不触。
4. **~/drone: stash@{0}** (WIP on feature/omni-sl-align) と **untracked take01.mp4** 継続 (前回報告済み・変化なし)。
5. 情報: **~/drone に `feat/coop-load-mass-estimator`** (未マージ・push 済み d394a2f) が新規在圏。
   PR 化の判断待ちと思われる。
6. 情報: リモートのマージ済みブランチ滞留 — rf_rover **61本** (前回 69)、infra **1本**
   (feat/isaac-onnxruntime)、drone2 0本。リモート削除は本テーマ対象外。

## 正常 WIP (削除しない)

- rf_rover src: `audit/docs-drift-megarover2-ns` (#384) / `audit/docs-drift-occupancy-paths` (#383) /
  `audit/ros2-structure-mr2-minrange-dup` (#433) / `audit/ros2-structure-odom-src-comment` (#431) /
  `audit/ros2-structure-unused-imports` (#432) — いずれも open draft PR。
- rf_rover src: `feat/viewport-workspace-restore` — パッチ等価で main 取込済み確定 (08-10)、
  手動 `git branch -D` 待ち。**未マージ扱いしない** (変化なし)。
- drone2 src: `audit/docs-drift-robot-ns` (#225 draft)。

## 検証

- 各 checkout で `git branch --show-current` / `git status --porcelain` /
  `git branch --merged origin/main` / `git branch -vv` を素の単一コマンドで実測。
- 変更操作は一切行っていないため、事後検証は「何も変わっていないこと」= 上記実測値そのもの。

> 本レポートは夜間自動監査 (branch-cleanup) が生成。記載の手動作業は実施前に人間が確認すること。
