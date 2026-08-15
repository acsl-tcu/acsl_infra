# 夜間監査レポート 2026-07-19 — branch-cleanup

- テーマ: branch-cleanup (作業ブランチの後始末 / main へ復帰)
- ホスト: ruth / 実行: headless (don't-ask)
- 実施した変更: **なし (0件)** / PR: **なし (テーマ仕様どおり作らない)**

## ⚠ 権限ギャップ (最重要の注記)

既知の [git perm gap] が本テーマに直撃。headless では **`git` が読み取り系 (`git status`)
含め全 deny** (今夜も冒頭で2回確認、python3 も deny)。そのため:

- テーマの自動整理 (`git switch main` / `git branch -d`) は**構造的に実行不能**。
- 整理条件の判定材料のうち `git status --porcelain` (作業ツリーの汚れ) と
  `origin/main..HEAD` (祖先関係 = マージ済み判定) も**取得不能**。
- 代替として **`.git` メタデータの読み取りのみ** (Read/head/tail/grep/find, 変更は一切なし)
  で観測した: `HEAD`, `refs/heads/*`, `refs/remotes/origin/*`, `packed-refs`, reflog
  (`logs/`), `refs/stash`。SHA 一致と reflog の push 記録から「push 済みか」は確定できるが、
  「origin/main にマージ済みか」「作業ツリーがクリーンか」は確定できない。
- よって本レポートは**全件「観測+要相談」**。ハーネス allowlist に読み取り系 git
  (`git status`, `git branch`, `git log`, `git switch main`, `git branch -d`) が入るまで、
  branch-cleanup テーマは毎回この形になる。

## 調査範囲

targets.conf の全5 checkout (全て存在):

| checkout | 現在ブランチ | HEAD SHA | origin/main | 判定 |
|---|---|---|---|---|
| ~/GitHub/sb/acsl_infra | main | f4431b37 | f4431b37 (一致) | ✓ 問題なし |
| ~/GitHub/sb/project_rf_rover | **chore/yolo-compose-into-dockerfiles** | cc815ed5 | bd9d3b8d | ⚠ main 以外に置き去り |
| ~/GitHub/sb/project_drone2 | main | 3434ce50 | 3434ce50 (一致) | ✓ (ローカル限定ブランチあり) |
| ~/rover (deploy) | main | bd9d3b8d | bd9d3b8d (一致) | ✓ (stash あり) |
| ~/drone (deploy) | main | 3434ce50 | 3434ce50 (一致) | ✓ (stash あり) |

detached HEAD: なし。全リポでローカル main == origin/main (ハーネスの ff 更新は機能)。
コンテナ稼働: rover 系 8個が Up (isaac-sim, yolo, nav2, rover, bcps_bridge, rf_tf,
bcps_sim, slam_toolbox)。drone 系は稼働なし。~/rover は既に main のため切替不要で、
稼働中コンテナと干渉する操作は発生していない。

## 要相談 (人間の判断が必要 — 変更は一切加えていない)

1. **project_rf_rover (ソースクローン) が `chore/yolo-compose-into-dockerfiles` に置き去り**
   — 本テーマの想定事例そのもの。reflog 証拠:
   - 2026-06-20頃 origin/main から作成 → commit cc815ed5「chore: docker-compose_yolo.yml を
     dockerfiles/ へ移動」→ 直後に push 済み (`update by push`)。**未 push commit なし**。
   - リモート同名ブランチはその後 ec5c8206 まで fast-forward 先行 (07-07 の fetch で観測)。
   - マージ済みの傍証: main 上の checkout (~/rover, bd9d3b8d) に
     `dockerfiles/docker-compose_yolo.yml` が存在しルート側は無い = このブランチの変更内容は
     main に反映済みとみられる。ただし祖先関係の厳密確認は git deny のため未確証。
   - **推奨手動操作**: `git status` がクリーンなことを確認の上 `git switch main`。

2. **project_rf_rover にローカル作業ブランチ 17本が滞留** (main 除く)。16本は
   リモート同名ブランチと SHA 完全一致 = push 済み・ローカル固有 commit なし
   (feat/spawn-people-* 4本, fix/workspace-restore-* 6本, fix/*, chore/*, refactor/promote-environment 等)。
   残る1本は上記 1. の現在ブランチ (push 済み・リモート先行)。
   - **推奨手動操作**: `git branch --merged origin/main | grep -v main | xargs git branch -d`
     (-d は未マージを自動拒否するので安全)。

3. **project_drone2 にローカル限定ブランチ `docs/sitl-ap-stale-header`** (40fe8468)。
   2026-07-16 未明に main (3716523a) から作成、commit 1件「docs: sitl.yaml ヘッダの
   Phase 1 時代の別端末起動手順を削除」。**リモートに存在せず = 未 push・未マージ**。
   07-15 夜間監査 (backend-smoke-drone-SITL_AP) が生成したものとみられる。
   - **判断が必要**: push + PR 化するか、破棄するか。内容は docs のみで低リスク。

4. **~/rover に stash 1件** (2026-06-25頃, `refs/stash` = c4c150f1):
   「On refactor/initial-pose-config-single-source: wip-exp-notebooks」。
   未コミット変更が退避されたまま。commit / 破棄の判断が必要。
   (なお同名ローカルブランチ refactor/initial-pose-config-single-source は
   リモートと SHA 一致 = push 済み。)

5. **~/drone に stash 1件** (2026-07-09頃, `refs/stash` = 6ea8fe2f):
   「WIP on feature/omni-sl-align: ed08094 feat: omni SL を exp_esp32_sl 構成に整列…」。
   同上、判断が必要。

6. **~/drone のローカルブランチ `test/105-serial_exp`** (2b8deb24): 2026-07-02 の
   commit 2件 (Thrust2RC の output_sign 実機確認値 [1,-1,-1] 等) は **push 済み**
   (`update by push` を reflog で確認)。その後リモートは 33191ea0 まで fast-forward 先行
   = ローカルは古いだけで消失リスクなし。実機チューニング値を含む test ブランチなので
   削除推奨はしない (情報)。`fix/mavros2-abi-upgrade` はリモートと一致 (push 済み)。

7. **リモート追跡ブランチの滞留** (情報のみ、テーマ仕様によりリモート削除はしない):
   rf_rover 系 ~55本、drone2 系 ~35本の origin/* が残存。マージ済み判定
   (`git branch -r --merged origin/main`) は git deny のため未実施。GitHub 側で
   マージ済みブランチの削除設定 (delete branch on merge) の検討を推奨。

## 捨てた候補 (実施しなかった自動整理とその理由)

- rf_rover の `git switch main` + マージ済み16本の `git branch -d`: **唯一の自動整理候補**
  だったが、(a) git 全 deny で実行不能、(b) 整理条件「作業ツリーがクリーン」
  「origin/main にマージ済み」のどちらも確証不能 — テーマの安全条件を満たせないため
  権限があっても今夜は実施すべきでなかった。全て上記「要相談」へ。

## 検証

- 変更 0 件のため検証対象なし。観測は読み取りのみ (`.git` への書き込み・git コマンド実行なし)。
- 本レポートの SHA・reflog 引用は各 `.git/refs/*`, `.git/logs/*` の生データから転記。

---
*夜間自動監査 (branch-cleanup) が生成。変更・PR なし。上記「要相談」は手動対応を推奨。*
