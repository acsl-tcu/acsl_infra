# Nightly Audit 2026-09-23 — branch-cleanup

- テーマ: branch-cleanup (作業ブランチの後始末 / main へ復帰)
- ホスト: ruth / 実行: 夜間自動監査 (PR は作らないテーマ)
- 対象: targets.conf 全 5 checkout (acsl_infra / project_rf_rover / project_drone2 のソース、~/rover / ~/drone の deploy)
- コンテナ: `docker ps` で **9 件稼働中** (すべて rf_rover 系: rover / nav2 / yolo / bcps_bridge / rf_tf /
  isaac-sim / slam_toolbox / rf_building / bcps_sim)。drone 系は 0 件。

## 結果サマリ

**自動整理 0 件 (整理条件を満たす checkout / ブランチが存在しない = 成功)。detached HEAD なし。**
`git branch --merged origin/main` に `main` 以外のローカルブランチが出た checkout は **5 つとも 0 本** で、
削除候補そのものが無い。main 以外に居る 3 checkout はいずれも `origin/main..HEAD` が非空 (未マージ) で整理条件外。

今回の最重要は **rf_rover ソースの `fix/door-leg-through` が 18 commit 未マージかつ「リモート未 push」**
(ローカルにしか存在しない) こと。さらに **~/rover の未コミット変更が、その同じ作業の実体と一致**していた
(下記 検証 参照) ため、この作業は「commit 済みだが push されていない 1 箇所」と「未コミットの 1 箇所」に
しか無い状態。バックアップ観点で人間の判断が要る。

| checkout | branch | tree | origin/main..HEAD | ローカル余剰 br | 判定 |
|---|---|---|---|---|---|
| acsl_infra (src) | fix/dup-image-ref-normalize (push 済) | untracked (監査ログ 40 件のみ) | 1 commit (PR #66 OPEN) | なし | 注意 (軽微) |
| project_rf_rover (src) | **fix/door-leg-through (未 push)** | クリーン | **18 commit** | audit/* 6 本 (全て open draft PR) | **注意 (重要)** |
| project_drone2 (src) | main (= origin 3a53ebb) | クリーン | 0 | audit/* 5 本 (全て open draft PR) | OK |
| ~/rover (deploy) | main (**behind 8**) | **汚れ** (M 20 + untracked 3) | 0 | なし | 注意 (コンテナ稼働中) |
| ~/drone (deploy) | **feature/voice_recognition** (push 済) | **汚れ** (untracked 1) | 1 commit | fix/coop-ext-force-units / feat/coop-load-mass-estimator / feat/hlc-firmware-c | 注意 |

## 実施した整理

なし。切替・ブランチ削除・stash/reset/clean/restore は一切行っていない。
- 5 checkout すべてで `git branch --merged origin/main` の結果は `main` のみ (drone2 は `* main`)。削除候補ゼロ。
- main 以外に居る 3 checkout (infra / rf_rover src / ~/drone) は全て未マージ commit を持つため、
  テーマの整理条件 (クリーン かつ `origin/main..HEAD` が空) を満たさない。
- ~/rover は main 在圏だが作業ツリーが汚れており、かつ rf_rover 系コンテナ 9 本が稼働中。二重に不触。

## 要相談 (変更せずに記載)

1. **【重要】rf_rover ソースの `fix/door-leg-through` が 18 commit ぶん「ローカルのみ」** —
   `git branch -vv` で upstream 表示が無く、`git branch -r --list "origin/fix/*"` は
   `origin/fix/ev-door-lidar-gap` のみ。つまり **origin に同名ブランチが存在しない = 未 push**。
   最新 commit は本日付 (`0858097c 2026-09-23 fix(gtlog): ワークスペースを明示 source して…`)。
   内容は障害物ガード / ドア通過 / スタック復帰 / gt_logger など走行系の実装 18 commit
   (`bbba372b fix: 直線上の leg 終端で…` 〜 `0858097c`)。作業ツリーはクリーン。
   **push (または draft PR 化) してバックアップを取ることを推奨**。本テーマは push しないので未実施。
2. **~/rover: main 在圏のまま未コミット変更 20 ファイル + untracked 3 (継続・拡大)** —
   M: `config/building/elevator.yaml` / `config/building/link.yaml` /
   `config/controller/building_nav.yaml` / `config/rover.yaml` / `docs/BCPS_NAV_INTEGRATION.md` /
   `docs/DEVELOPMENT_GUIDE.md` / `isaac_sim/notebooks/setup_isaacsim_yc_bld7.ipynb` /
   `launcher/launch_rover.sh` / `project_launch.sh` / `packages/rf_rover/**` 11 ファイル。
   untracked: `isaac_sim/config/layouts/workspace_ss.json` / `isaac_sim/notebooks/Untitled.ipynb` /
   `packages/rf_rover/rf_rover/tools/debug/gt_logger.py`。
   **ただしこれは「失われる恐れのある独自変更」ではなく、上記 1 の作業の実体とほぼ一致**することを実測で確認
   (検証節)。**~/rover 固有で src 側に無いのは notebook 2 件 (実行結果差分) と workspace_ss.json のみ**。
   加えてローカル main が **behind 8** (b024a537 vs origin/main a0453bab) — ハーネスの ff が汚れで止まった形。
   コンテナ稼働中のため今回は不触。停止後に「汚れを commit/破棄 → `git pull --ff-only`」を推奨。
3. **~/drone が `feature/voice_recognition` 在圏 (未マージ 1 commit) + untracked 1** —
   `6d35e4d 2026-09-04 Add packages` が `origin/main..HEAD` に残る。push 済み
   (`[origin/feature/voice_recognition]` と一致) だが PR は無し。
   untracked `launcher/launch_speech_recognition.sh` が未コミットで残る。
   drone 系コンテナは停止中なので、人間が判断すれば main 復帰は安全に行える状態。
   09-12 に報告した `fix/coop-ext-force-units` 在圏からは移動済み (下記「解消確認」)。
4. **acsl_infra ソースが `fix/dup-image-ref-normalize` 在圏 (未マージ 1 commit)** —
   `c44bfb0 fix: dup --image= がリポジトリ名込みの指定を解決できなかった`、PR **#66 OPEN** (09-18)、push 済み。
   PR が開いている以上は意図的な在圏と判断し不触。**#66 merge 後に main 復帰を推奨**。
   なお **untracked の監査ログが 40 件** (08-14〜09-22) に増加。commit されていないのでこのホストが
   飛ぶと監査履歴が消える。一括 commit を検討 (本テーマは commit しない)。
5. **~/drone: stash@{0}** (WIP on feature/omni-sl-align ed08094) が 4 run 連続で継続 (変化なし)。
   本テーマは stash を触らない。不要なら手動 `git stash drop` を。
6. 情報: **~/drone にローカル未マージ枝 3 本が在圏** — `fix/coop-ext-force-units` (a0c4c98, PR #227 **OPEN**)、
   `feat/coop-load-mass-estimator` (d394a2f, PR #221 draft)、
   **`feat/hlc-firmware-c` (00630cb, 新規・PR 無し・push 済)**。いずれも未マージにつき削除対象外。
7. 情報: リモートのマージ済み滞留ブランチ — **drone2 1 本** (`feature/coop-cable-rope-chain`。前回 25 本 → 大幅減)、
   **rf_rover 6 本** (`24_takano` / `M2_Ishikawa` / `docs/gen-occupancy-generic` / `docs/mapping-refresh` /
   `fix/ev-door-lidar-gap` / `timeStateControlForm`。前回 8 本、`chore/audit-followups` と `fix/max-wz-rate` と
   `feat/plot-log` は削除済み)、**infra 0 本** (前回 2 本 → 整理済み)。リモート削除は本テーマ対象外。

## 前回 (2026-09-12) からの解消確認

- **~/drone が `fix/coop-ext-force-units` に置き去り → 解消** (現在 `feature/voice_recognition`)。
  ただし PR #227 は依然 OPEN・未マージで、ブランチはローカルに残る (上記 6)。
- **rf_rover src の `feat/viewport-workspace-restore` (手動 `-D` 待ちだった squash 済み枝) → 消滅**。
  `audit/docs-drift-newton-lidar-status` も #435 merge 済みでローカルから消滅。手動整理が入った。
- **リモート滞留の大幅削減** — drone2 25 → 1 本、infra 2 → 0 本、rf_rover 8 → 6 本。
- **~/rover のコンテナ → 全停止だったものが 9 本稼働へ (逆行)**。今回は整理不可の理由の一つ。
- **~/rover の WIP 汚れ → 拡大** (M2+2 → M20+3)。ただし実体は rf_rover src の commit 済み作業と一致 (上記 2)。
- **acsl_infra が main → 非 main へ (新規注意)**。PR #66 待ち。

## 正常 WIP (削除しない)

- rf_rover src: `audit/docs-drift-metadata-tool-path` (#441) / `audit/docs-drift-claude-md-followup` (#442) /
  `audit/docs-drift-agents-modes` (#443) / `audit/ros2-structure-ev-config-defaults` (#445) /
  `audit/ros2-structure-front-sector-min` (#446) / `audit/ros2-structure-saturation-note` (#447) —
  全て open draft PR。
- drone2 src: `audit/docs-drift-robot-ns` (#225) / `audit/docs-drift-coop-rope-defaults` (#228) /
  `audit/ros2-structure-hlc-xd28` (#229) / `audit/ros2-structure-sl-takeoff-zstop-reset` (#230) /
  `audit/ros2-structure-hlc-sl-ext-force-path` (#231) — 全て open draft PR。#225 は 08-29 から 3 週超の滞留。
- infra src: `fix/dup-image-ref-normalize` (#66 OPEN)。

## 検証

- 5 checkout すべてで `git branch --show-current` / `git status --porcelain` /
  `git log --oneline origin/main..HEAD` / `git branch -vv` / `git branch --merged origin/main` /
  `git branch -r --merged origin/main` を **素の単一コマンド**で実測 (cwd は `cd <path>` 単独呼び出しで移動)。
  `git stash list` を ~/rover (空) と ~/drone (1 件) で確認。`docker ps` で稼働 9 件を確認。
- **要相談 2 の「~/rover の汚れ = src の commit 済み作業」の裏取り**:
  `diff -rq ~/rover/packages/rf_rover/rf_rover <src>/packages/rf_rover/rf_rover` の相違は
  **`__pycache__` の .pyc のみ** (.py ソースは全一致)。`diff -rq ~/rover/docs <src>/docs` は相違なし。
  `project_launch.sh` / `launcher/launch_rover.sh` も一致。`config/` の相違は `config/rover.yaml` のみで、
  中身は **コメントアウト行 5 行の差** (`# robot: "robot/nova_carter.yaml"` 等のローカル選択メモ)。
  `isaac_sim/notebooks/setup_isaacsim_yc_bld7.ipynb` のみ実差分あり。
  → deploy 側の未コミット変更は src の `fix/door-leg-through` にほぼ載っている、と結論。
- 変更操作は一切行っていないため、事後検証は「何も変わっていないこと」= 上記実測値そのもの。

## 権限 deny 実測 (今回)

- なし。今回使用した全コマンド (`git` 各種 / `docker ps` / `gh pr list` / `diff` / `ls`) が通った。
  前回 deny された `git cherry` / `git submodule status` は今回不要だったため未使用。

> 本レポートは夜間自動監査 (branch-cleanup) が生成。記載の手動作業は実施前に人間が確認すること。
