# テーマ: branch-cleanup (作業ブランチの後始末 / main へ復帰)

> 各 checkout が「マージ済みの作業ブランチに置き去り」になっていないかを見て、**安全なら**
> main に戻し、ローカルの済みブランチを掃除する。**安全でなければ一切触らず「注意」を残す**。
> このテーマは driver の find→draft PR とは異なり **PR を作らない**。成果物は
> (a) 安全な範囲のローカル git 整理 と (b) レポートへの注意記載 だけ。
> 由来: 実際に deploy checkout (~/drone) がマージ済み feature ブランチに置き去りで、
> 再デプロイ時の取り違えや「main じゃない」混乱を招いた事例があった。

## 対象リポ
- `targets.conf` の全行: `kind=repo` のソース (`~/GitHub/sb/<repo>`) と
  `kind=deploy` の稼働 checkout (`~/rover`, `~/drone`)。存在しない path はスキップ。

## 観点 (チェックリスト)
- [ ] 各 checkout の現在ブランチ (`git branch --show-current`) と
      作業ツリーの汚れ (`git status --porcelain`) を確認する。
- [ ] **main 以外**に居る checkout について、現在ブランチが
      `origin/main` に**マージ済み**か (`git log --oneline origin/main..HEAD` が空、
      あるいは `git branch --merged origin/main` に現在ブランチが出る)。
- [ ] ローカルに**マージ済みで不要な作業ブランチ**が溜まっていないか
      (`git branch --merged origin/main` のうち `main` 以外)。
- [ ] detached HEAD になっていないか。

## 「整理してよい (= 自動修正)」とみなす条件
作業ツリーが**完全にクリーン** (`git status --porcelain` が空) で、現在ブランチが
**`origin/main` にマージ済み** (`origin/main..HEAD` が空) のときに限り、次を行う:
- `git switch main` で main に戻す (ローカル main はハーネスが ff 更新済み。driver §0)。
- `origin/main` にマージ済みのローカル作業ブランチを `git branch -d <name>` で削除する
  (`-d` は未マージなら git が自動拒否するので安全。**`-D` 強制削除は使わない**)。
- deploy checkout (`~/rover`, `~/drone`) は、対象 project のコンテナが**起動中**
  (`dps` / `docker ps` で確認) の場合は切替がコンテナを壊す恐れがあるため
  **整理せず「注意」に回す** (停止後に手動で、を推奨)。

## 「注意」を出す条件 (= 何も変更せずレポートへ)
以下は**一切変更を加えず** `logs/<date>-branch-cleanup.md` の「要相談」に列挙する。これが本テーマの主な警告手段:
- 作業ツリーが**汚れている** (uncommitted / untracked) のに main 以外に居る
  → 「<repo> は <branch> で未コミット変更あり。手動で commit / stash / 破棄の判断が必要」。
- 現在ブランチに **`origin/main` 未マージのコミットがある** (`origin/main..HEAD` が非空)
  → 「<repo> の <branch> は未マージ (push / PR が要るかも)」。証拠に未マージ commit を数行。
- **detached HEAD** になっている → 「<repo> が detached HEAD (<sha>)」。
- deploy checkout が整理条件を満たすが**コンテナ起動中** → 「<deploy> はコンテナ停止後に手動で main へ戻す推奨」。
- リモートに**マージ済みのまま残る**作業ブランチがある場合は情報として記載
  (`git branch -r --merged origin/main`)。**リモート削除はこのテーマでは行わない** (安全側。手動 or 別途判断)。

## やらないこと (安全境界・絶対)
- **PR を作らない / merge しない / main へ push しない / force-push しない**
  (driver の安全則をそのまま継承)。
- **`git branch -D` (強制削除) を使わない**。**リモートブランチを削除しない**
  (`git push origin --delete` / `git push -d` をしない)。
- **`git reset` / `git clean` / `git stash` / `git restore` で汚れや未マージを消さない**。
  汚れ・未マージは必ず人間に委ねる (= 注意に回す)。迷ったら触らない。
- 稼働中コンテナに影響する deploy の切替をしない (上記の起動中チェック)。

## 検証方法
- 整理した checkout で `git branch --show-current` が `main`、`git status --porcelain` が空、
  削除したブランチが `git branch` の一覧から消えていることを確認する。
- 1つも整理しなかった (全 checkout が既に main、または全て注意行き) 場合もレポートは書く
  (driver §5: 指摘ゼロ＝成功。ただし注意がある場合は必ず「要相談」に残すこと)。
