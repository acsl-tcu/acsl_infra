# 2026-10-15 branch-cleanup (host: ruth)

## 結論
- **自動整理: 0 件** (switch 0 / `branch -d` 0)。`git branch --merged origin/main` は全 5 checkout で `main` のみ → 削除候補なし。detached HEAD なし。
- PR 作成なし (テーマ規定)。変更は本レポートのみ。
- コンテナ: `drone2_1..4` が **Up 9 hours** (前回 10-04 は ROS コンテナ 0 本)、`isaac-sim` は Up 37 hours (unhealthy)。→ ~/drone は条件を満たしても切替不可。

## checkout 別

| checkout | ブランチ | 汚れ | origin/main との関係 | 判定 |
|---|---|---|---|---|
| ~/GitHub/sb/acsl_infra | `fix/dup-image-ref-normalize` (#66 OPEN) | ?? 監査ログ 62 件 | HEAD ahead 1 (c44bfb0) | 注意 (継続) |
| ~/GitHub/sb/project_rf_rover | main (69464b74) | なし | 一致 | OK |
| ~/GitHub/sb/project_drone2 | main (608e9a6) | なし | 一致 | OK |
| ~/drone (deploy) | `fix/coop-estimator-true-mass` | M 1 / stash 1 | HEAD ahead **44**、behind 0 | **注意 (新規)** |
| ~/rover (deploy) | main (b024a537) | ?? 6 件 | **behind 74** | 注意 (継続) |

## 要相談

1. **~/drone: 未マージの作業ブランチ `fix/coop-estimator-true-mass` に居る + 未コミット変更あり + drone2 コンテナ稼働中** (新規)
   - `git status -sb`: `## fix/coop-estimator-true-mass...origin/fix/coop-estimator-true-mass` / ` M isaac_sim/notebooks/setup_isaac_coop_drone.ipynb` (11+/9-)
   - `origin/main..HEAD` は 44 コミット (a5fa931 .. 4015080、最新 2026-10-14 17:30)。リモート枝に push 済み (ahead/behind なし) だが、**このブランチの PR は無い** (`gh pr list --state all` に head 該当なし)。例:
     - `4015080 fix: per_agent の機体識別を起動引数から取る (StepContext では取れない)`
     - `a41de75 feat: per_agent で 4 機に別ゲインを入れ 1 走行で 4 点取る`
     - `221d921 fix: cableL を 3.0 -> 2.74 にする (アンカー基準と odom 基準の 8.7% ずれ)`
   - 稼働中の協調搬送実験のブランチとみられる。PR 化するかどうか、notebook の変更をどうするかは人の判断。コンテナ停止後に必要なら main へ。
   - 前回 (10-04) の最重要事項「**local main ahead 4 (52a68bd ほか) がリモートに無い**」は**解消**: local main = origin/main = 608e9a6 で、52a68bd は `origin/main` に含まれる。前回の M3 (hlc_sl_coop.yaml ほか)、?? launch_speech_recognition.sh、枝 `fix/coop-notebook-newlines` も消えた。
   - **stash@{0}** (`WIP on feature/omni-sl-align: ed08094`) は 6 run 連続で残る (`feature/omni-sl-align` のローカル枝はもう無い)。要否の判断を。
   - ほかのローカル枝はどれも未マージ: `feat/coop-load-mass-estimator` (#221 OPEN)、`fix/coop-ext-force-units` (#227 OPEN)、`feat/hlc-firmware-c` / `feature/voice_recognition` (PR 無し)。

2. **~/rover: main だが behind 74、untracked 6 件** (継続)
   - `## main...origin/main [behind 74]` (local b024a537 / origin/main 69464b74)。コンテナは停止中。
   - 前回あった tracked の変更 (M) は消え、untracked のみになった: `config/nav2/`, `isaac_sim/config/layouts/workspace_ss.json`, `isaac_sim/notebooks/Untitled.ipynb`, `packages/rf_rover/rf_rover/tools/debug/gt_logger.py`, `packages/rf_rover/rf_rover/tools/mapping/map_correct.py`, `rosbag/`。
   - `diff -q` / `diff -rq` を src (origin/main と一致) と比べると、`gt_logger.py`、`map_correct.py`、`config/nav2/` は**内容が同一**。これらは origin/main で追加された tracked ファイルなので、**untracked のまま置いてあると ff merge が「would be overwritten」で止まる。behind 74 が続く原因はおそらくこれ**。この 3 つを消せば (同一内容なので失うものはない) `git merge --ff-only origin/main` が通る見込み。ただし本テーマは削除・clean を禁じているので手を付けていない。`workspace_ss.json` / `Untitled.ipynb` / `rosbag/` は残すかどうかを持ち主が判断。
   - (試した `git ls-tree origin/main ...` は deny: "Permission to use Bash has been denied because Claude Code is running in don't ask mode." → diff -q で代わりに確認した)

3. **acsl_infra src: `fix/dup-image-ref-normalize` に在圏** (継続)
   - #66 OPEN (2026-09-18 作成)。`origin/main..HEAD` = `c44bfb0 fix: dup --image= がリポジトリ名込みの指定を解決できなかった`。
   - untracked の監査ログは 62 件 (前回 51 件)。ログを commit する運用にするか、.gitignore に入れるかは人の判断。

## 情報: ローカルに残る未マージの監査枝 (open draft PR の head)
- rf_rover src: `audit/*` 9 本 (どれも push 済み、未マージ)。
- drone2 src: `audit/*` 7 本 (#225/#228/#229/#230/#231/#241/#242、どれも OPEN)。

## 情報: リモートでマージ済みのまま残る枝 (`git branch -r --merged origin/main`、削除はしていない)
- rf_rover: 21 本 (前回 20 本)。`24_takano`, `M2_Ishikawa`, `docs/gen-occupancy-generic`, `docs/mapping-refresh`, `feat/ev-gap-center`, `feat/map-correct-beamskip`, `fix/amcl-no-recovery-injection`, `fix/amcl-recovery`, `fix/console-s-stop`, `fix/contact-guard-band`, `fix/door-leg-through`, `fix/ev-board-approach-speed`, `fix/ev-board-depth`, `fix/ev-boarding-0928`, `fix/ev-dock-debounce-glass-carrot` (新規), `fix/ev-door-lidar-arrival`, `fix/ev-door-lidar-gap`, `fix/ev-exit-front-guard`, `fix/physx-regression`, `fix/stuck-recover-timeout`, `timeStateControlForm`
- drone2 (src clone): `feature/coop-cable-rope-chain` (#226 MERGED)。~/drone 側の remote 一覧には出ない (prune 済み)。
- acsl_infra: なし。

## 検証
- どの checkout も変更していないので、整理後の確認は不要。上の状態は `git status -sb --porcelain` / `git branch -vv` / `git branch --merged origin/main` / `git log --oneline origin/main..HEAD` / `git stash list` / `docker ps -a` を各 checkout で実際に打った結果。
