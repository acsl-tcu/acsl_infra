# Nightly Audit 2026-09-12 — branch-cleanup

- テーマ: branch-cleanup (作業ブランチの後始末 / main へ復帰)
- ホスト: ruth / 実行: 夜間自動監査 (PR は作らないテーマ)
- 対象: targets.conf 全 5 checkout (acsl_infra / project_rf_rover / project_drone2 のソース、~/rover / ~/drone の deploy)
- コンテナ: `docker ps` の稼働コンテナ **0 件** (rover 系・drone 系とも停止中)

## 結果サマリ

**自動整理 0 件 (整理条件を満たす checkout / ブランチが存在しない = 成功)。detached HEAD なし。**
前回 (09-01) 要相談だった「~/drone main behind 4」は解消 (main = origin/main 3a53ebb)。
一方 **~/drone が `fix/coop-ext-force-units` (未マージ・PR #227 OPEN) に在圏**しており、
これが今回唯一の「main 以外に居る checkout」。未マージのため触らず要相談。

| checkout | branch | tree | ローカル余剰 br | 判定 |
|---|---|---|---|---|
| acsl_infra (src) | main (= origin 689683d) | untracked (監査ログ 29 件のみ) | なし | OK |
| project_rf_rover (src) | main (= origin fbfb7997) | **クリーン** (前回の WIP 汚れは解消) | audit/docs-drift-newton-lidar-status (#435 draft) / feat/viewport-workspace-restore (squash 済) | OK (正常 WIP) |
| project_drone2 (src) | main (= origin 3a53ebb) | クリーン | audit/* 5 本 (全て open draft PR) | OK (正常 WIP) |
| ~/rover (deploy) | main (= origin fbfb799) | **汚れ** (M 2 + untracked 2) | なし | 注意 |
| ~/drone (deploy) | **fix/coop-ext-force-units** (未マージ 17 commit) | クリーン | feat/coop-load-mass-estimator (#221 draft) | **注意** |

## 実施した整理

なし。各 checkout で `git branch --merged origin/main` に main 以外のローカルブランチは出ず、
main 以外に居る唯一の checkout (~/drone) は `origin/main..HEAD` が非空 (未マージ) のため整理条件外。
ブランチ削除・切替・stash 操作は一切行っていない。

## 前回 (2026-09-01) からの解消確認

- **~/drone: main の behind 4 → 解消** (ローカル main 3a53ebb = origin/main。ハーネス ff が効いた)。
- **~/drone: untracked take01.mp4 → 消滅** (`git status --porcelain` 空)。
- **rf_rover src: main 上の未コミット WIP (M11 + untracked) → 解消** (作業ツリー完全クリーン)。
  前回の audit 枝 5 本 (#383/#384/#431-433) もローカルから消滅 (#438 merge 後に整理済み)。
- **~/rover: コンテナ多数稼働中 → 全停止** (docker ps 空)。ただし WIP 汚れは残存 (後述)。
- **rf_rover リモート滞留: 61 本 → 8 本** (大幅に手動整理済み)。

## 要相談 (変更せずに記載)

1. **~/drone が `fix/coop-ext-force-units` 在圏 (未マージ)**。`origin/main..HEAD` = 17 commit
   (b6f9650 fix: 牽引点外力の単位… 〜 a0c4c98 fix(ekf): 遠心力項を |ω x pT|^2 に直す…)。
   PR #227 は OPEN (non-draft, MERGEABLE, 09-11 更新)。作業ツリーはクリーン・push 済み
   (origin/fix/coop-ext-force-units と一致) で、drone 系コンテナは非稼働。
   **#227 merge 後に `git switch main` + `git pull --ff-only` で main へ復帰を推奨**。
   merge 前に切り替えると再デプロイ時に取り違える恐れがあるので、現状は意図的な在圏と判断し不触。
2. **~/rover: main 上に未コミット変更あり (継続)** — M `config/rover.yaml` (+5) /
   M `isaac_sim/notebooks/setup_isaacsim_yc_bld7.ipynb` (+361/-1481) +
   untracked `isaac_sim/config/layouts/workspace_ss.json` / `isaac_sim/scripts/newton_compat.py`。
   前回より縮小 (M14+3 → M2+2) だが notebook の大差分は残存。src 側 (rf_rover) はクリーンになったので、
   この deploy 側の変更が最後の未保存分。コンテナ停止中の今なら安全に commit / ブランチ化できる。
3. **~/drone: stash@{0}** (WIP on feature/omni-sl-align ed08094) 継続 (前回・前々回報告済み、変化なし)。
   本テーマは stash を触らない。不要なら手動 `git stash drop` を。
4. 情報: **~/drone に `feat/coop-load-mass-estimator`** (d394a2f・未マージ・#221 draft) 継続在圏。
5. 情報: リモートのマージ済みブランチ滞留 — **drone2 25 本** (前回 0 本 → 増加。feature/coop-cable-rope-chain
   ほか feat/ekf-dynamics-main, fix/gc-pauses, refactor/ground-effect-phase-free 等)、
   rf_rover **8 本** (24_takano / M2_Ishikawa / chore/audit-followups / docs/gen-occupancy-generic /
   docs/mapping-refresh / feat/plot-log / fix/max-wz-rate / timeStateControlForm)、
   infra **2 本** (feat/isaac-onnxruntime / fix/nightly-triage-0901)。リモート削除は本テーマ対象外。
   drone2 の「0 本 → 25 本」は 09-01 の計測が fetch 前だった可能性 (前回値の方が疑わしい)。

## 正常 WIP (削除しない)

- rf_rover src: `audit/docs-drift-newton-lidar-status` (#435 draft, 09-09)。
- rf_rover src: `feat/viewport-workspace-restore` — #35 は 06-02 に MERGED (squash)。ローカル 2e0a23b4 が
  `origin/main..` に残るのは squash のため。`-d` は拒否されるので手動 `git branch -D` 待ち (変化なし)。
  今回 `git cherry` でのパッチ等価再確認は権限 deny (下記引用)。08-10 の等価確認結果を維持。
- drone2 src: `audit/docs-drift-robot-ns` (#225) / `audit/docs-drift-coop-rope-defaults` (#228) /
  `audit/ros2-structure-hlc-xd28` (#229) / `audit/ros2-structure-sl-takeoff-zstop-reset` (#230) /
  `audit/ros2-structure-hlc-sl-ext-force-path` (#231) — いずれも open draft PR。
- acsl_infra src: untracked の監査ログ 29 件 (08-14〜09-11) は本監査の成果物。main 在圏なので注意対象外だが、
  溜まっているので一括 commit を検討 (別途)。

## 権限 deny 実測 (今回)

- `git cherry origin/main feat/viewport-workspace-restore` および `git submodule status` (~/rover) が deny:
  「Permission to use Bash has been denied because Claude Code is running in don't ask mode.」
  いずれも情報取得のみで、監査結論に影響なし。

## 検証

- 各 checkout で `git branch --show-current` / `git status --porcelain` / `git log --oneline origin/main..HEAD` /
  `git branch --merged origin/main` / `git branch -vv` / `git branch -r --merged origin/main` を
  素の単一コマンドで実測。`docker ps` で稼働コンテナ 0 件を確認。
- 変更操作は一切行っていないため、事後検証は「何も変わっていないこと」= 上記実測値そのもの。

> 本レポートは夜間自動監査 (branch-cleanup) が生成。記載の手動作業は実施前に人間が確認すること。
