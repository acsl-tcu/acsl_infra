#!/usr/bin/env bash
# このホストの crontab に夜間監査ジョブを冪等登録する。
#   install_cron.sh            # 既定 02:30 で登録
#   AT="0 3 * * *" install_cron.sh   # 時刻を変える (cron 式)
# アンインストール: install_cron.sh --remove
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$HERE/run_nightly_audit.sh"
chmod +x "$RUNNER" "$HERE"/*.sh 2>/dev/null || true

MARK="# acsl-nightly-audit"           # 識別タグ (冪等更新/削除に使う)
AT="${AT:-30 2 * * *}"                # 既定 02:30 毎日 (ホスト localtime)
ENV_FILE="${NIGHTLY_ENV_FILE:-$HOME/.config/acsl-nightly-audit.env}"

current="$(crontab -l 2>/dev/null || true)"
cleaned="$(printf '%s\n' "$current" | grep -vF "$MARK" || true)"

if [[ "${1:-}" == "--remove" ]]; then
  printf '%s\n' "$cleaned" | crontab -
  echo "removed nightly-audit cron."
  exit 0
fi

# cron は env が最小。トークン等はこの env ファイルから読む (無ければ雛形を作る)。
if [[ ! -f "$ENV_FILE" ]]; then
  mkdir -p "$(dirname "$ENV_FILE")"
  cat > "$ENV_FILE" <<EOF
# acsl 夜間監査の無人実行 env。cron がこれを source する。chmod 600 推奨。
# どちらか一方の認証トークンを設定 (対話ログイン資格は cron では使えない):
#   CLAUDE_CODE_OAUTH_TOKEN=...   # 対話マシンで \`claude setup-token\` 発行 (サブスク, 1年)
#   ANTHROPIC_API_KEY=sk-ant-...  # Claude Console の API キー
# PR 作成用 (gh が未認証なら):
#   GH_TOKEN=ghp_...
# Slack 通知 (任意。設定すると完了後に要約を指定チャンネルへ投稿。未設定なら無効):
#   NIGHTLY_SLACK_WEBHOOK=https://hooks.slack.com/services/XXX/YYY/ZZZ  # Incoming Webhook URL
#   NIGHTLY_SLACK_NOTIFY=always   # always(既定) | on-change (PR/要相談/異常時のみ)
# Slack 制御ボット (任意。slack_control.sh / slack_control.service 用。Slack からコマンド):
#   NIGHTLY_SLACK_BOT_TOKEN=xoxb-...        # Bot token (scopes: channels:history|groups:history, chat:write)
#   NIGHTLY_SLACK_CONTROL_CHANNEL=C0123...  # 制御チャンネル ID (bot を招待しておく)
#   NIGHTLY_SLACK_ALLOW_USERS=U001,U002     # enable/disable/run を許可する Slack user ID (未設定だと実行系は無効)
export HOME="$HOME"
export ACSL_WORK_DIR="${ACSL_WORK_DIR:-$HOME}"
# export CLAUDE_CODE_OAUTH_TOKEN=
# export GH_TOKEN=
# export NIGHTLY_SLACK_WEBHOOK=
# export NIGHTLY_SLACK_NOTIFY=always
# export NIGHTLY_SLACK_BOT_TOKEN=
# export NIGHTLY_SLACK_CONTROL_CHANNEL=
# export NIGHTLY_SLACK_ALLOW_USERS=
EOF
  chmod 600 "$ENV_FILE"
  echo "env 雛形を作成: $ENV_FILE (トークンを記入してから cron が機能します)"
fi

# cron 行: env を source → ディレクトリ移動 → 実行。/bin/sh でも動くよう '. file' を使う。
line="$AT . $ENV_FILE; cd $HERE && ./run_nightly_audit.sh >> $HERE/logs/cron.log 2>&1 $MARK"
{ printf '%s\n' "$cleaned"; printf '%s\n' "$line"; } | grep -vE '^\s*$' | crontab -
echo "installed:"; crontab -l | grep -F "$MARK"
echo "→ 次に $ENV_FILE にトークンを記入してください。"
