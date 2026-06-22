#!/usr/bin/env bash
# Nightly Auditor エントリポイント (cron が呼ぶ)。
#   1. その日のテーマを rotation.txt から決める
#   2. targets.conf の全リポ (デプロイ先含む) の main を最新化する
#   3. driver.md + themes/<theme>.md を結合してプロンプトを作る
#   4. claude を無人 (headless) 起動して監査させる
#   5. ログを残す。多重起動はロックで防ぐ。
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
TARGETS="$HERE/targets.conf"
mkdir -p "$LOG_DIR"

# 監査前に targets.conf の全リポ (デプロイ先含む) の main を最新化する。
# 安全策: main 上でクリーンなら ff pull、そうでなければ checkout せず local main ref
# だけを ff 更新、それも無理ならスキップしてログ (実機/作業中の checkout を壊さない)。
# 監査ブランチは driver が origin/main から切るので、fetch 済みであることが要点。
# NIGHTLY_NO_SYNC=1 で無効化 (テスト用)。
sync_targets() {
  local logf="$1"
  [[ "${NIGHTLY_NO_SYNC:-0}" == "1" ]] && { echo "[sync] skip (NIGHTLY_NO_SYNC=1)" | tee -a "$logf"; return 0; }
  [[ -f "$TARGETS" ]] || { echo "[sync] targets.conf 無し。skip" | tee -a "$logf"; return 0; }
  grep -vE '^[[:space:]]*(#|$)' "$TARGETS" | while IFS='|' read -r kind name path project modes; do
    path="$(echo "$path" | xargs)"; path="${path/#\~/$HOME}"
    [[ -d "$path/.git" ]] || { echo "[sync] $path: .git 無し skip" | tee -a "$logf"; continue; }
    git -C "$path" fetch origin --quiet 2>>"$logf" || { echo "[sync] $path: fetch 失敗" | tee -a "$logf"; continue; }
    local cur dirty
    cur="$(git -C "$path" symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)"
    dirty="$(git -C "$path" status --porcelain)"
    if [[ "$cur" == "main" && -z "$dirty" ]]; then
      git -C "$path" pull --ff-only origin main --quiet 2>>"$logf" \
        && echo "[sync] $path: main を ff pull" | tee -a "$logf" \
        || echo "[sync] $path: ff pull 不可 (要手動)" | tee -a "$logf"
    elif git -C "$path" fetch origin main:main --quiet 2>>"$logf"; then
      echo "[sync] $path: local main を ff 更新 (作業ブランチ=$cur は不変)" | tee -a "$logf"
    else
      echo "[sync] $path: main 更新スキップ (branch=$cur, dirty=$([[ -n $dirty ]] && echo yes || echo no))。origin/main は fetch 済" | tee -a "$logf"
    fi
  done
}

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

# --- 無人実行の前提チェック (README「無人運用の前提」参照) -------------------
# cron は対話ログインの資格 (keyring / ~/.claude/.credentials.json) を TTY 無しで
# 使えない。必ず env でトークンを渡す。どちらか一方が要る:
#   CLAUDE_CODE_OAUTH_TOKEN  … 対話マシンで `claude setup-token` 発行 (サブスク, 1年)
#   ANTHROPIC_API_KEY        … Claude Console の API キー
if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "[nightly-audit] FATAL: CLAUDE_CODE_OAUTH_TOKEN も ANTHROPIC_API_KEY も未設定。" \
       "cron 環境では対話ログイン資格は使えない。README 参照。" | tee -a "$LOG"
  exit 2
fi
# gh (PR 作成) も無人で通る必要がある。
if ! gh auth status >/dev/null 2>&1 && [[ -z "${GH_TOKEN:-}" ]]; then
  echo "[nightly-audit] WARN: gh 未認証 & GH_TOKEN 未設定。PR 作成に失敗しうる。" | tee -a "$LOG"
fi

# --- 全リポの main を最新化 (必ず監査の前に) --------------------------------
echo "[nightly-audit] sync targets to latest main ..." | tee -a "$LOG"
sync_targets "$LOG" || true   # sync の不調で監査全体を止めない (origin/main は fetch 済)

# --- claude 無人起動 --------------------------------------------------------
# --bare       : OAuth refresh / keyring / plugin ロードをスキップ (無人必須)
# dontAsk      : 許可リスト外は静かに拒否 = ハングしない。deny>ask>allow で deny 最優先。
# --settings   : audit_settings.json (allow=監査が使うコマンド, deny=破壊系ハードガード)
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PERMISSION_MODE="${NIGHTLY_PERMISSION_MODE:-dontAsk}"
SETTINGS="$HERE/audit_settings.json"

cd "${ACSL_WORK_DIR:-$HOME}"
set +e
"$CLAUDE_BIN" --bare -p "$PROMPT" \
  --permission-mode "$PERMISSION_MODE" \
  --settings "$SETTINGS" >>"$LOG" 2>&1
rc=$?
set -e
echo "[nightly-audit] done rc=$rc" | tee -a "$LOG"
exit $rc
