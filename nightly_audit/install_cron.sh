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

current="$(crontab -l 2>/dev/null || true)"
cleaned="$(printf '%s\n' "$current" | grep -vF "$MARK" || true)"

if [[ "${1:-}" == "--remove" ]]; then
  printf '%s\n' "$cleaned" | crontab -
  echo "removed nightly-audit cron."
  exit 0
fi

line="$AT cd $HERE && ./run_nightly_audit.sh >> $HERE/logs/cron.log 2>&1 $MARK"
{ printf '%s\n' "$cleaned"; printf '%s\n' "$line"; } | grep -vE '^\s*$' | crontab -
echo "installed:"; crontab -l | grep -F "$MARK"
