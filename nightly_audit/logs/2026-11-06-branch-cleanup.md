# 2026-11-06 branch-cleanup (host: ruth)

## 結論
- **自動整理 1 件**: `~/drone` のローカル枝 `audit/backend-smoke-sitl-px4-empty-config-param`
  (PR #251 MERGED、`git branch --merged origin/main` に出る) を `git branch -d` で削除。
  `Deleted branch audit/backend-smoke-sitl-px4-empty-config-param (was 2b8f735).`
- 全 5 checkout が **main = origin/main** (ahead/behind なし)。detached HEAD なし。
- `docker ps` 結果: 起動中コンテナ 0 本 → deploy checkout の整理は可能だった。
- PR 作成なし (テーマ規定)。

## checkout ごとの状態

| checkout | branch | 追従 | 作業ツリー | 備考 |
|---|---|---|---|---|
| ~/GitHub/sb/acsl_infra | main 9e0f8f6 | = origin/main | untracked はログだけ (logs/ 08-14〜11-05) | #66 は OPEN 一覧から消えた。前回あった `.tmp-2026-10-25-*` 2 件は無くなっている。stash なし |
| ~/GitHub/sb/project_rf_rover | main 12ecea99 | = origin/main | クリーン | ローカルの audit/* 10 本は全部 OPEN draft PR (#441-#447, #463-#465, #475) の head → 残す |
| ~/GitHub/sb/project_drone2 | main e418898 | = origin/main | クリーン | ローカルの audit/* 11 本は全部 OPEN draft PR (#225, #228-#231, #241, #242, #247, #248, #256, #257) の head → 残す |
| ~/drone (deploy) | main e418898 | = origin/main | クリーン | 1 本削除 (上記)。stash@{0} omni-sl-align はまだある (8 run 連続) |
| ~/rover (deploy) | main 12ecea99 | = origin/main | untracked 3 件 | **前回の behind 84 は解消** (人が main を最新にした。前回の ` M setup` と docs/ の untracked も無くなった) |

## 要相談 (変更していない)

1. **~/drone と ~/rover: squash merge 済みなのに `-d` で消せない枝** (`--merged` に出ないので -d は失敗する。消すなら人の判断で `-D`)
   - ~/drone `feat/required-sensors-gate` (bc0e91c) → PR #254 MERGED
   - ~/drone `fix/sitl-px4-config-pass` (78d407b) → PR #252 MERGED
   - ~/rover `feat/required-sensors-gate` (61e57556) → PR #473 MERGED
2. **~/drone: origin/main に未マージのローカル枝** (作業中とみられる。情報として記載)
   - `fix/coop-ext-force-units` → PR #227 OPEN (origin/main..: 17 commit)
   - `feat/coop-load-mass-estimator` → PR #221 DRAFT (1 commit d394a2f)
   - `feat/hlc-firmware-c` (00630cb) → PR なし。origin/main.. は約 47 commit (coop-ext-force-units の上に積んでいる)
   - `feature/voice_recognition` (6d35e4d "Add packages") → PR なし
3. **~/drone stash@{0}** `WIP on feature/omni-sl-align: ed08094` — 8 run 連続で残っている。要否は人が判断すること (stash は触らない)。
4. **~/rover untracked**: `isaac_sim/config/layouts/workspace_ss.json`, `isaac_sim/notebooks/Untitled.ipynb`, `rosbag/`
   — どれも実行時に生成されたものとみられる。main 上にあり切替は不要なので害はない。.gitignore に足すかどうかは人が判断すること。
5. **リモートにマージ済みのまま残っている枝** (情報のみ。リモートは削除していない)
   - rf_rover (src 側の取得で見えた分、5 本): 24_takano, M2_Ishikawa, docs/gen-occupancy-generic, docs/mapping-refresh, timeStateControlForm
     (前回の 27 本から減った。~/rover 側は fetch 時点の違いで audit/docs-drift-newton-lidar-status と fix/door-confirm-ev-board も見える)
   - drone2 (~/drone 側): audit/backend-smoke-sitl-px4-empty-config-param, feature/coop-model-error, fix/coop-estimator-true-mass
6. acsl_infra の untracked ログ (08-14〜11-05、約 87 件) はまだコミットされていない。運用の判断が要る。

## 検証
- ~/drone: `git branch` から当該の枝が消えたことを確認した。current は main、`git status --porcelain --branch` は `## main...origin/main` だけ。
- その他の checkout は変更していない。
