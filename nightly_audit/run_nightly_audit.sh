#!/usr/bin/env bash
# Nightly Auditor エントリポイント (cron が呼ぶ)。
#   1. その日のテーマを rotation.txt から決める
#   2. driver.md + themes/<theme>.md を結合してプロンプトを作る
#   3. claude を無人 (headless) 起動して監査させる
#   4. ログを残す。多重起動はロックで防ぐ。
#
# 使い方:
#   run_nightly_audit.sh                # 当日のテーマを自動選択して実行
#   run_nightly_audit.sh docs-drift     # テーマを明示 (手動テスト用)
#   DRY_RUN=1 run_nightly_audit.sh      # プロンプトを表示するだけ (claude を起動しない)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="$HERE/themes"
LOG_DIR="$HERE/logs"
ROTATION="$HERE/rotation.txt"
mkdir -p "$LOG_DIR"

# --- テーマ選択 -------------------------------------------------------------
if [[ -n "${1:-}" ]]; then
  THEME="$1"
else
  mapfile -t THEMES < <(grep -vE '^\s*(#|$)' "$ROTATION")
  [[ ${#THEMES[@]} -gt 0 ]] || { echo "rotation.txt が空"; exit 1; }
  DOY=$(date +%j); DOY=$((10#$DOY))          # 年内通算日 (先頭0を10進化)
  THEME="${THEMES[$(( DOY % ${#THEMES[@]} ))]}"
fi
THEME_FILE="$THEMES_DIR/${THEME}.md"
[[ -f "$THEME_FILE" ]] || { echo "テーマ仕様が無い: $THEME_FILE"; exit 1; }

DATE="$(date +%Y-%m-%d)"
LOG="$LOG_DIR/${DATE}-${THEME}.run.log"
LOCK="$LOG_DIR/.lock"

# --- 多重起動防止 -----------------------------------------------------------
exec 9>"$LOCK"
if ! flock -n 9; then echo "別の監査が実行中。終了。"; exit 0; fi

echo "[nightly-audit] $DATE theme=$THEME host=$(hostname)" | tee -a "$LOG"

# --- プロンプト構築 ---------------------------------------------------------
PROMPT="$(cat "$HERE/driver.md")

============================================================
今日のテーマ仕様 (themes/${THEME}.md):
============================================================
$(cat "$THEME_FILE")

============================================================
実行日: ${DATE} / ホスト: $(hostname)
レポートは ${LOG_DIR}/${DATE}-${THEME}.md に書くこと。
============================================================"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "----- DRY_RUN: prompt -----"; echo "$PROMPT"; exit 0
fi

# --- claude 無人起動 --------------------------------------------------------
# 無人実行の要件 (README 参照):
#   - 非対話の認証 (ANTHROPIC_API_KEY もしくは事前ログイン済みの資格情報)
#   - gh が cron ユーザーで認証済み (PR 作成のため)
#   - パーミッション: 無人なので prompt できない。許可モードは運用方針で決める。
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PERMISSION_MODE="${NIGHTLY_PERMISSION_MODE:-acceptEdits}"

cd "${ACSL_WORK_DIR:-$HOME}"
set +e
"$CLAUDE_BIN" -p "$PROMPT" --permission-mode "$PERMISSION_MODE" >>"$LOG" 2>&1
rc=$?
set -e
echo "[nightly-audit] done rc=$rc" | tee -a "$LOG"
exit $rc
