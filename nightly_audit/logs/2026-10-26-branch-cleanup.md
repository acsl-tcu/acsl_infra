# 2026-10-26 branch-cleanup (host: ruth)

## 結論
- **自動整理: 0 件** (switch 0 / `branch -d` 0)。`git branch --merged origin/main` は全 5 checkout で `main` だけなので、消せるブランチは無い。detached HEAD も無い。
- PR は作っていない (テーマの規定どおり)。変更したのはこのレポートだけ。
- コンテナ: `docker ps -a` は **0 本** (前回 10-15 は drone2_1..4 が Up、isaac-sim は unhealthy。今回はどれも無い)。

## checkout 別

| checkout | ブランチ | 汚れ | origin/main との関係 | 判定 |
|---|---|---|---|---|
| ~/GitHub/sb/acsl_infra | `fix/dup-image-ref-normalize` (#66 OPEN) | ?? 監査ログ 74 件 + .tmp 2 件 | HEAD ahead 1 (c44bfb0) | 注意 (継続) |
| ~/GitHub/sb/project_rf_rover | main (b54d134c) | なし | 一致 | OK |
| ~/GitHub/sb/project_drone2 | main (5a97194) | なし | 一致 | OK |
| ~/drone (deploy) | **main (5a97194)** | なし (stash 1) | 一致 | **OK (解消)** |
| ~/rover (deploy) | main (b024a537) | **M 1** / ?? 10 件 | **behind 84** | 注意 (継続・悪化) |

## 要相談

1. **~/rover: main だが behind 84。tracked の変更 1 件、untracked 10 件** (継続。前回は behind 74 / ?? 6)
   - `git status -sb`: `## main...origin/main [behind 84]` / ` M setup` (+5/-10) / `?? config/nav2/ docs/copybutton.html docs/github.theme docs/qiita.css docs/setup.md isaac_sim/config/layouts/workspace_ss.json isaac_sim/notebooks/Untitled.ipynb packages/rf_rover/rf_rover/tools/debug/gt_logger.py packages/rf_rover/rf_rover/tools/mapping/map_correct.py rosbag/`
   - **今回の新規分**: ` M setup` と `docs/` の 4 ファイル (どれも 2026-10-15 16:57〜19:31 に更新)。src (= origin/main b54d134c) と `diff -q` で比べると、**`setup`、`docs/setup.md`、`copybutton.html`、`github.theme`、`qiita.css` はすべて同じ内容**だった。最新 main のファイルを手でコピーしたように見える (git pull ではない)。
   - 前回からの `gt_logger.py`、`map_correct.py`、`config/nav2/` も、今回また `diff -q` / `diff -rq` で src と同じ内容だった。
   - このため、**untracked のファイルが origin/main の tracked ファイルと重なり、さらに `setup` の M もあって、ff merge が「would be overwritten」で止まる状態が続いている**とみられる。ここに挙げた 8 つ (setup の M と untracked 7 つ) は origin/main と同じ内容なので、元に戻すか消しても失うものは無いはず。その後 `git merge --ff-only origin/main` が通る見込み。ただしこのテーマでは restore / clean / 削除が禁止なので手を付けていない。`workspace_ss.json`、`Untitled.ipynb`、`rosbag/` を残すかどうかは持ち主が決める。コンテナは停止中なので、作業するなら今がよい。
   - tracked の docs (BCPS_NAV_INTEGRATION.md など 5 件) は src と差分があるが M にはなっていない。これは behind による古い版というだけ。

2. **acsl_infra src: `fix/dup-image-ref-normalize` に居る** (継続)
   - #66 は OPEN のまま (2026-09-18 作成)。`origin/main..HEAD` = `c44bfb0 fix: dup --image= がリポジトリ名込みの指定を解決できなかった`。
   - untracked の監査ログは 74 件 (前回 62 件)。それとは別に、**前回 run (10-25 ros2-structure) が残した一時ファイル `nightly_audit/logs/.tmp-2026-10-25-commit-msg.txt` と `.tmp-2026-10-25-pr-body.md`** がある。どちらも消してよいはずだが、ファイル削除は deny されるので手を付けていない。ログを commit する運用にするか .gitignore に入れるかは、人の判断が要る。

3. **~/drone: stash@{0} が 7 run 続けて残っている** (継続)
   - `stash@{0}: WIP on feature/omni-sl-align: ed08094 ...`。`feature/omni-sl-align` のローカルブランチはもう無い。要否の判断を。

## 解消: ~/drone が main に戻った
- 前回の「`fix/coop-estimator-true-mass` (ahead 44・PR 無し・M notebook 1・コンテナ稼働中)」は解消した。このブランチは #243 (10-16) と #245 (10-22) で **MERGED**。ローカル枝は消え、checkout は main = origin/main 5a97194 でクリーン。誰かが手で戻したとみられる (この監査は何もしていない)。
- 残っているローカルブランチはどれも未マージ: `feat/coop-load-mass-estimator` (#221 OPEN)、`fix/coop-ext-force-units` (#227 OPEN)、`feat/hlc-firmware-c` と `feature/voice_recognition` (PR 無し)。

## 情報: ローカルに残る未マージの監査ブランチ (open draft PR の head)
- rf_rover src: `audit/*` 9 本 (前回と同じ。どれも push 済みで未マージ)。
- drone2 src: `audit/*` 9 本。#225/#228/#229/#230/#231/#241/#242/#247/#248 がどれも OPEN (前回 7 本 + 新しい #247/#248)。

## 情報: リモートでマージ済みのまま残るブランチ (`git branch -r --merged origin/main`。削除はしていない)
- rf_rover: **27 本** (前回 21 本)。新しく増えたのは `docs/setup-env-actual`, `docs/setup-env-required`, `docs/setup-guide`, `docs/setup-pandoc-title`, `feature/SLAM-471`, `fix/setup-default-robot-megarover2` の 6 本。残りは前回からのもの (`24_takano`, `M2_Ishikawa`, `docs/gen-occupancy-generic`, `docs/mapping-refresh`, `feat/ev-gap-center`, `feat/map-correct-beamskip`, `fix/amcl-no-recovery-injection`, `fix/amcl-recovery`, `fix/console-s-stop`, `fix/contact-guard-band`, `fix/door-leg-through`, `fix/ev-board-approach-speed`, `fix/ev-board-depth`, `fix/ev-boarding-0928`, `fix/ev-dock-debounce-glass-carrot`, `fix/ev-door-lidar-arrival`, `fix/ev-door-lidar-gap`, `fix/ev-exit-front-guard`, `fix/physx-regression`, `fix/stuck-recover-timeout`, `timeStateControlForm`)。
- drone2: `feature/coop-cable-rope-chain` (#226 MERGED、src 側だけ)、`fix/coop-estimator-true-mass` (#243/#245 MERGED、新規)、`feature/coop-model-error` (#246 MERGED、新規。~/drone 側に出る)。
- acsl_infra: なし。

## 検証
- どの checkout も変更していないので、整理後の確認は要らない。上の状態は、各 checkout で `git status -sb` / `git branch -vv` / `git branch --merged origin/main` / `git branch -r --merged origin/main` / `git log --oneline origin/main..HEAD` / `git stash list` / `docker ps -a` / `gh pr list|view` を実際に打った結果。~/rover の「同じ内容」の判定は、src clone (main = origin/main b54d134c) との `diff -q` / `diff -rq` による。
- 今回 deny は 1 件も無かった。
