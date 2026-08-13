# Nightly Audit 2026-07-30 — branch-cleanup

- ホスト: ruth / 実行: 夜間自動監査 (headless)
- テーマ: branch-cleanup (checkout の main 復帰 + マージ済みローカルブランチ掃除)
- 対象: targets.conf 全 5 行 (repo: acsl_infra, project_rf_rover, project_drone2 / deploy: ~/rover, ~/drone)。全 path 存在、スキップなし。

## 結果サマリ

**自動整理 0 件・破壊的変更 0 件。** 全 5 checkout が既に `main` 上に居る (detached HEAD なし)。
マージ済みで削除可能なローカルブランチは deploy 側に 2 本あるが、いずれも
「作業ツリー完全クリーン」のゲート条件を満たさず (両 deploy とも uncommitted 変更あり、
~/rover はコンテナ稼働中)、テーマの安全則に従い**一切変更せず要相談に回した**。

## 各 checkout の状態

| checkout | branch | tree | マージ済みローカルbr | 備考 |
|---|---|---|---|---|
| ~/GitHub/sb/acsl_infra | main | untracked のみ (監査ログ18本) | なし | 問題なし |
| ~/GitHub/sb/project_rf_rover | main | クリーン | なし | ローカル br 4本は全て push 済み (下記) |
| ~/GitHub/sb/project_drone2 | main | クリーン | なし | ローカル br 1本 = open draft PR #153 |
| ~/rover (deploy, rf_rover) | main | **汚れ** (M×5, ??×2) | `fix/yolo-real-camera-config` | **コンテナ8個稼働中** (21分前起動あり=作業中) |
| ~/drone (deploy, drone2) | main | **汚れ** (M×7, ??×3) | `fix/mavros2-abi-upgrade` | stash 1件残存 |

## 要相談 (変更せず人間の判断待ち)

1. **~/rover: マージ済みローカルブランチ `fix/yolo-real-camera-config` が削除可能**
   (PR #230 は 2026-07-29T17:31Z に merged 済みを `gh pr view 230` で確認)。
   ただし tree 汚れ (`config/omni_yc_bld7.yaml`, notebooks×3, rviz×1 が M / untracked 2件) +
   コンテナ稼働中 (yolo/nav2/rover/bcps_bridge/rf_tf が 21 分前起動、slam_toolbox/bcps_sim/isaac-sim も Up)
   のため自動削除を見送り。作業終了後に手動で `git branch -d fix/yolo-real-camera-config` を推奨。
2. **~/drone: マージ済みローカルブランチ `fix/mavros2-abi-upgrade` が削除可能**
   (`git branch --merged origin/main` に出現、push 済み)。tree 汚れ
   (coop/omni 系 config×4, docs, notebook, script が M / untracked 3件 — 進行中の作業に見える)
   のため自動削除を見送り。手が空いたら `git branch -d fix/mavros2-abi-upgrade` を推奨。
3. **~/drone: stash 残存** — `stash@{0}: WIP on feature/omni-sl-align: ed08094`。
   テーマ安全則により stash には触らない。必要なら手動で pop / drop の判断を。
4. **rf_rover ソース: `feat/viewport-workspace-restore` が未マージ・PR なし**。
   push 済み (origin と同期、未マージ commit は `2e0a23b4 fix(viewport): Kit 6 の正しい API 名
   dump_workspace/restore_workspace に直す` の1件のみ)。PR を開くか破棄するか判断待ち。
5. **~/drone: `test/105-serial_exp` がリモートより 66 commit 遅れ**の古い sha で残存。
   origin/main 未マージのため -d 対象外。実験用ブランチと思われる — 不要なら手動整理を。

## 情報 (対応不要・記録のみ)

- **07-19 持ち越しの解消確認**: (a) rf_rover ソースの `chore/yolo-*` 置き去り → **解消**
  (main 復帰済み・ローカル chore ブランチなし)。(b) drone2 の未 push ローカル docs ブランチ →
  **解消** (現存せず。現在の docs ブランチは PR #153 として push 済み)。(c) ~/rover の stash →
  **解消** (stash list 空)。(d) ~/drone の stash → **残存** (上記 要相談 3)。
- rf_rover ソースのローカル br 3 本 (`audit/docs-drift-bcps-keys-and-paths`,
  `audit/ros2-structure-manifest-deps`, `audit/ros2-structure-stale-comments`) は
  open draft PR #223/#224/#225 に対応 — レビュー待ちのため保持が正しい。
- rf_rover ソースのローカル main は origin/main が PR #229 merge 時点 (0c5d9044) で、
  GitHub 上は #230 が merge 済み — ハーネス fetch のタイミング差。次回 fetch で追随、対応不要。
- リモートのマージ済みブランチ (テーマ規定によりリモート削除は行わない):
  rf_rover に約 65 本、drone2 に 26 本が merged のまま残存。まとめて消すなら
  `gh pr list --state merged` と突き合わせて手動 or 別テーマで。
- `gh pr list --state open` (rf_rover) が #230 を OPEN と表示したが、`gh pr view 230` の
  live 照会では MERGED (2026-07-29T17:31:26Z)。list 側の表示ずれと判断、実害なし。

## 検証

- 変更を加えていないため検証対象なし。全判定コマンド (`git branch --show-current` /
  `git status --porcelain` / `git branch --merged origin/main` / `git branch -vv` /
  `git stash list` / `docker ps` / `gh pr view`) は素の1コマンドで実行し、権限 deny は 0 件。

---
夜間自動監査 (branch-cleanup) が生成。整理 0 件 = 成功終了 (driver §5)。
