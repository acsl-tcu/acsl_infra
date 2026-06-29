# Nightly Auditor — 夜間自動監査エージェント

acsl エコシステムを **1日1テーマ**で夜間に自動監査し、確証ある問題を **draft PR** まで
仕上げる。実機 (Docker/GPU/ROS2 が載ったデプロイ先) 上の cron で動く。

## 構造 (3層)

| 層 | 実体 | 役割 | 触る頻度 |
|----|------|------|----------|
| スケジューラ | `install_cron.sh` が登録する cron | 夜間に1回 `run_nightly_audit.sh` を起動 | ほぼ不変 |
| ハーネス | `run_nightly_audit.sh` | 当日テーマ選択 → **全リポ main 最新化** → プロンプト構築 → claude 無人起動 → ログ | ほぼ不変 |
| ドライバ | `driver.md` | 監査の手順・安全則 (find→検証→draft PR) | 滅多に触らない |
| **テーマ** | `themes/<name>.md` | **監査の中身 (観点/指摘条件/修正範囲/検証法)** | **ここを壁打ちで育てる** |
| ローテ表 | `rotation.txt` | 日付→テーマ (通算日 % 行数) | 自由に増減 |
| 権限境界 | `audit_settings.json` | allow/deny (deny 最優先のハードガード) | 新コマンド追加時のみ |
| 監査対象 | `targets.conf` | repo (静的) / deploy (backend-smoke) の一覧・安全モード | 対象増減時 |

**テーマを足す** = `themes/_TEMPLATE.md` をコピーして書き、`rotation.txt` に1行足すだけ。
ドライバ/ハーネスは触らなくてよい。

## 動かし方

```bash
# 手動テスト (claude は起動せずプロンプトだけ確認)
DRY_RUN=1 ./run_nightly_audit.sh docs-drift

# 手動で1回実行 (テーマ明示)
./run_nightly_audit.sh docs-drift

# cron 登録 (既定 02:30 毎日)。時刻変更は AT="0 3 * * *" ./install_cron.sh
./install_cron.sh
./install_cron.sh --remove     # 解除
```

ログは `logs/` に出る (`<date>-<theme>.run.log` = 実行ログ、`<date>-<theme>.md` = 監査レポート)。

## 自律境界 (要点)
- 各リポ `CLAUDE.md` の「頼まれない限り push/PR しない」に対し、**本監査は in-scope な
  draft PR を開く常設承認**。merge / main 直 push / force-push / 他人の PR 改変は禁止。
- 1指摘=1ブランチ `audit/<theme>-<slug>`、draft PR、label `nightly-audit`、最大3本/晩。
- 各リポの編集可否スコープ厳守 (`common/` 不可、`drone_main.py`/`setup` 等は原則不可)。
- 確信が持てない/設計判断が要るものは PR にせずレポートに「要相談」で残す。

## ⚠️ 無人運用の前提 (cron 登録前に要整備)

無人 cron では対話できない。**cron はキーチェーン/`~/.claude/.credentials.json` の対話ログイン
資格を TTY 無しで使えない**ので、認証は必ず env で渡す。`install_cron.sh` が
`~/.config/acsl-nightly-audit.env` の雛形を作るので、そこに記入する。

1. **claude の非対話認証** (どちらか一方):
   - `CLAUDE_CODE_OAUTH_TOKEN` — 対話マシンで一度 `claude setup-token` を実行して 1 年有効
     トークンを発行 (Pro/Max サブスク)。**サブスク勢の推奨**。
   - `ANTHROPIC_API_KEY` — Claude Console の API キー (API 課金, CI 向き)。
   - 起動は `--bare` (OAuth refresh/keyring/plugin ロードをスキップ。無いとハングしうる)。
     `run_nightly_audit.sh` が付与済み。
2. **gh の認証**: `gh auth status` が通るか、`GH_TOKEN` を env に設定 (PR 作成のため)。
3. **git identity**: `git config --global user.name/user.email` がホストで設定済みであること。
4. **パーミッション**: 無人なので prompt 不可。既定 **`dontAsk`** = 許可リスト外は静かに拒否
   (ハングしない)。許可/拒否は `audit_settings.json` で管理 (**deny > ask > allow**、deny が
   常に最優先)。`NIGHTLY_PERMISSION_MODE` で変更可。`acceptEdits` は git/gh/colcon を
   承認待ちにしてストールするので**使わない**。完全自走の `bypassPermissions` は隔離ホスト
   限定 (安全分類器も無効化されるため非推奨)。
5. **監査対象 (この PC で一元管理)**: `targets.conf` に列挙する。複数 PC に撒くのではなく、
   ソースクローン (`~/GitHub/sb/<repo>`) と稼働 checkout (`~/rover`, `~/drone`) が揃った
   この 1 台の cron で完結させる。
   - `repo` 行 = 静的解析・PR をソースクローンで。
   - `deploy` 行 = backend-smoke を稼働 checkout で実起動検証。

### 🔔 Slack 通知 (任意)
md レポートはプル型で気づけないので、完了後にハーネスが要約を Slack へ push できる。
1. Slack で **Incoming Webhook** を作り、投稿先チャンネルを選んで Webhook URL を得る
   (Slack App → Incoming Webhooks → Add New Webhook to Workspace)。
2. env ファイル (`~/.config/acsl-nightly-audit.env`) に設定:
   - `export NIGHTLY_SLACK_WEBHOOK=https://hooks.slack.com/services/...`
   - `export NIGHTLY_SLACK_NOTIFY=always`  (既定。`on-change` にすると PR/「要相談」/異常終了の時だけ投稿)
3. 投稿内容: `theme / host / rc / 開いた PR の URL / レポート本文 (3500字で truncate)`。
   未設定なら skip (通知無しで通常動作)。投稿は**ハーネスが行い**、claude には webhook を渡さない。
- bot token + `chat.postMessage` で動的にチャンネルを選ぶ方式も可能だが、固定チャンネルなら
  webhook が最小構成。`run_nightly_audit.sh` の `notify_slack()` を差し替えれば対応できる。

### ⛔ 実機安全 (絶対)
**この cron は実機に触れない。アクチュエーション (モーター/プロペラ/車輪) を伴う一切をしない。**
- backend-smoke で動かすのは **SIM / SITL (純ソフトウェア)** のみ。**HITL は受動検証まで**
  (bringup・トピック確認。arm/takeoff/モーター/cmd 送出は禁止)。
- **EXP 系 (実機) は回さない**。targets.conf の `modes` に書かない。
- 三重で守る: ① targets.conf に EXP を載せない ② driver.md の安全則 ③ audit_settings.json で
  `dup * EXP*` を deny (deny は allow より優先)。

### 許可リスト (audit_settings.json) の保守
`dontAsk` では allow に無いコマンドは静かに拒否される = 監査が必要な探索コマンドが
列挙漏れだと**黙って実行されず取りこぼす**。新しいコマンドを使い始めたら allow に足す。
逆に破壊系 (force-push, main への push, `rm -rf`, `reset --hard`, `gh pr merge`, `common/`
編集, `~/ENV`/`.env` 読取) は deny で固定。deny は allow より優先なので安全側に倒れる。

## テーマ一覧 (現状)
- `docs-drift` — ドキュメント/コメントと実装の乖離 (★お手本・実績あり)
- `ros2-structure` — ROS2/パイプライン構造の健全性 (☆スタブ)
- `branch-cleanup` — main 以外に置き去りの checkout を整理 (クリーン&マージ済みなら main へ復帰+済みブランチ削除、それ以外は「要相談」で注意)
- `backend-smoke` — backend 1つを現バージョンで実起動検証 (☆スタブ・実機限定)
- `config-consistency` / `deps-drift` / `improvement` — 未作成 (rotation には予約、要・壁打ち)
