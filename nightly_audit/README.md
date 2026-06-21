# Nightly Auditor — 夜間自動監査エージェント

acsl エコシステムを **1日1テーマ**で夜間に自動監査し、確証ある問題を **draft PR** まで
仕上げる。実機 (Docker/GPU/ROS2 が載ったデプロイ先) 上の cron で動く。

## 構造 (3層)

| 層 | 実体 | 役割 | 触る頻度 |
|----|------|------|----------|
| スケジューラ | `install_cron.sh` が登録する cron | 夜間に1回 `run_nightly_audit.sh` を起動 | ほぼ不変 |
| ハーネス | `run_nightly_audit.sh` | 当日テーマ選択 → プロンプト構築 → claude 無人起動 → ログ | ほぼ不変 |
| ドライバ | `driver.md` | 監査の手順・安全則 (find→検証→draft PR) | 滅多に触らない |
| **テーマ** | `themes/<name>.md` | **監査の中身 (観点/指摘条件/修正範囲/検証法)** | **ここを壁打ちで育てる** |
| ローテ表 | `rotation.txt` | 日付→テーマ (通算日 % 行数) | 自由に増減 |

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

無人 cron では対話できないため、以下が**事前に**整っている必要がある:

1. **claude の非対話認証**: cron はサブスクの対話ログインを引き継げない。
   `ANTHROPIC_API_KEY` を cron 環境に渡すか、ホストで事前ログイン済みの資格情報を使う。
   → どちらにするか要決定 (`run_nightly_audit.sh` は `CLAUDE_BIN` で実体を差し替え可)。
2. **gh の認証**: PR 作成のため cron 実行ユーザーで `gh auth status` が通ること。
3. **パーミッションモード**: 無人なので prompt 不可。既定 `acceptEdits`
   (`NIGHTLY_PERMISSION_MODE` で変更可)。完全自走には bypass 相当が要るが、
   **セキュリティ上の判断が要る**ので運用方針として明示決定する (要・相談)。
4. **ホストのスコープ**: その晩監査できるのは**このホストに存在/デプロイ済みの project**。
   backend-smoke は実際に動かせる project (例 ruth=rf_rover) のみ。複数 project を監査
   したいなら、それぞれのデプロイ先で cron を登録する (テーマは共有、対象だけホスト依存)。

## テーマ一覧 (現状)
- `docs-drift` — ドキュメント/コメントと実装の乖離 (★お手本・実績あり)
- `ros2-structure` — ROS2/パイプライン構造の健全性 (☆スタブ)
- `backend-smoke` — backend 1つを現バージョンで実起動検証 (☆スタブ・実機限定)
- `config-consistency` / `deps-drift` / `improvement` — 未作成 (rotation には予約、要・壁打ち)
