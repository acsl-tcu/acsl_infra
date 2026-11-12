# 2026-08-21 branch-cleanup (host: ruth)

テーマ: branch-cleanup (作業ブランチの後始末 / main へ復帰)。PR は作らないテーマ。
スコープ: targets.conf 全 5 行 (repo: acsl_infra / project_rf_rover / project_drone2、
deploy: ~/rover [rf_rover] / ~/drone [drone2])。全 path 存在、全件調査。

## 自動整理 (実施分)

- **project_drone2 (ソース ~/GitHub/sb/project_drone2)**: main 在圏・tree クリーンで整理条件充足。
  origin/main マージ済みローカルブランチ 2 本を `git branch -d` で削除:
  - `audit/docs-drift-sbc-dbuild-and-roadmap-path` (was c907567)
  - `feature/env-shared-assets` (was e52df81)
  - 検証: `git branch --show-current` = main、`git status --porcelain` 空、
    `git branch` 一覧から両ブランチ消滅を確認。残るローカルは
    `audit/docs-drift-env-paths` (未マージ 16b7dde・push 済み = draft PR #217 の正常 WIP) のみ。

他 checkout は「既に main で整理不要」または「注意行き」(下記) で、変更なし。

## 各 checkout の状態

| checkout | branch | tree | 判定 |
|---|---|---|---|
| acsl_infra (src) | main | untracked 7 (nightly_audit logs) | 整理不要 |
| project_rf_rover (src) | refactor/robot-spec-plug-and-play | クリーン | ユーザー WIP、触らず (注意) |
| project_drone2 (src) | main | クリーン | ✅ 整理実施 (上記) |
| ~/rover (deploy) | main | untracked 2 (csv) | 前回滞留は解消確認、注意 1 件 |
| ~/drone (deploy) | fix/coop-env-config-path | untracked 1 + stash | 触らず (注意) |

detached HEAD: なし。稼働コンテナ: `drone2` のみ (Up 4 days)。rover 系コンテナ稼働なし。

## 前回 (08-10) 持ち越しの解消確認

- **~/rover**: main 復帰済み・前回滞留のマージ済みローカルブランチ 41 本も消滅
  (`git branch --merged origin/main` = main のみ)。手動整理された模様。**解消**。
- **~/drone `fix/mavros2-abi-upgrade`**: ローカル一覧から消滅。**解消**。
- **feature/env-shared-assets 3 連 PR (#58/#320/#154)**: 全リポで取り込み済みと確認 —
  infra はローカル/リモートともブランチ消滅、rf_rover は origin ブランチ消滅 (unknown revision)、
  drone2 はマージ済み (今回ローカルを -d)。**解消**。
- **acsl_infra リモートのマージ済みブランチ 8 本**: 現在 0 本。**解消**。

## 要相談 (変更なし・人間の判断待ち)

1. **rf_rover (src) が `refactor/robot-spec-plug-and-play` 在圏**: origin/main 未マージ 2 commit
   (8109f52f, d840237d)、tree はクリーンだが**リモート未 push** (`git branch -r --contains` 空)。
   docs-drift 監査時のメモ通りユーザーの現行 WIP と判断し不触。ローカルのみのため
   消失リスクあり — push / PR 化を推奨。
2. **rf_rover (src) `feature/env-phase2`**: 未マージ 1 commit (bbd68297)・push 済み。
   PR 化するか破棄するか判断が必要。
3. **rf_rover (src) `feat/viewport-workspace-restore`**: 前回報告済み・変化なし。
   残 commit 2e0a23b4 は fix/workspace-api-name とパッチ等価で main 取込済み判定 (08-10 確定)。
   SHA 相違で -d 不可、-D はテーマ禁止 → 引き続き手動 `git branch -D` 待ち。未マージ扱いにしない。
4. **~/drone が `fix/coop-env-config-path` 在圏**: 未マージ 1 commit (e4b441c
   "fix: coop の env_config_dir が廃止済み environments/ を指したままだった")・push 済み。
   drone2 コンテナ稼働中 (Up 4 days) のため切替不可。デプロイ検証中の可能性が高い —
   PR 化 → merge 後、コンテナ停止時に main へ復帰推奨。加えて untracked `take01.mp4` と
   stash@{0} (feature/omni-sl-align WIP、前回から継続) の扱いも手動判断が必要。
5. **~/rover untracked 2 件**: `config/glass_test.csv` / `config/movable_test.csv`。
   commit / 破棄の手動判断待ち (main 在圏なので運用上の支障は小)。

## 情報 (変更せず記載のみ)

- リモートのマージ済みブランチ滞留: infra **0** / rf_rover **69** / drone2 **30**
  (rf_rover は前回 ~70 から横ばい、drone2 は ~26 → 30 微増)。リモート削除はテーマ対象外。
- ~/rover `docs/robot-spec-checklist`: 未マージ 1 commit (9d9fbcb)・push 済み。PR の帰趨は未確認。
- acsl_infra (src) の untracked は nightly_audit の過去レポート 7 件 (08-14〜08-20)。
  監査自身の生成物であり本テーマでは不触。
- draft PR 系の正常 WIP ブランチ: infra `audit/docs-drift-readme-paths` (PR #61)、
  rf_rover `audit/docs-drift-vendor-leftovers` (PR #333)、drone2 `audit/docs-drift-env-paths` (PR #217)。

## 総括

自動整理 1 checkout (drone2 ソースで -d 2 本)。前回持ち越しの大物 (~/rover の 41 本滞留・
env-shared-assets 3 連 PR) は解消を確認。破壊的操作 (reset / clean / stash / -D / リモート削除 /
コンテナ影響のある切替) は一切行っていない。PR 0 本 (テーマ仕様どおり)。

> 夜間自動監査 (branch-cleanup) が生成。
