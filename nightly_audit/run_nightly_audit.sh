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

# --- Slack 通知 (任意) ------------------------------------------------------
# 無人運用では logs/<date>-<theme>.md を誰も見に行かない。完了後に Slack へ要約を push する。
# 秘匿値は env (cron が source する ~/.config/acsl-nightly-audit.env) で渡す。未設定なら skip。
#   NIGHTLY_SLACK_WEBHOOK … Slack Incoming Webhook URL (作成時に決めた1チャンネルへ固定投稿)
#   NIGHTLY_SLACK_NOTIFY  … always(既定) | on-change (PR か「要相談」がある or rc!=0 の時だけ投稿)
# 投稿はハーネスが行う (claude には webhook を渡さない/投稿させない)。
# SLACK_OVERRIDE_TEXT を渡すと本文をそれに固定し、レポート読取・on-change ゲートを飛ばす
# (NIGHTLY_SLACK_TEST の自己テスト用)。
notify_slack() {
  set +e
  local webhook="${NIGHTLY_SLACK_WEBHOOK:-}"
  if [[ -z "$webhook" ]]; then
    echo "[slack] NIGHTLY_SLACK_WEBHOOK 未設定。skip" | tee -a "$LOG"; return 0
  fi
  local host; host="$(hostname)"
  local text
  if [[ -n "${SLACK_OVERRIDE_TEXT:-}" ]]; then
    text="$SLACK_OVERRIDE_TEXT"
  else
    local report="$LOG_DIR/${DATE}-${THEME}.md"
    local prs="" body="" has_signal=0
    if [[ -f "$report" ]]; then
      body="$(cat "$report")"
      prs="$(grep -oE 'https://github\.com/[^ )]+/pull/[0-9]+' "$report" 2>/dev/null | sort -u)"
      [[ -n "$prs" ]] && has_signal=1
      grep -qiE '要相談|要注意|warn' "$report" 2>/dev/null && has_signal=1
    fi
    [[ "${rc:-0}" != "0" ]] && has_signal=1
    if [[ "${NIGHTLY_SLACK_NOTIFY:-always}" == "on-change" && "$has_signal" == "0" ]]; then
      echo "[slack] on-change: 信号なし (PR/要相談/異常終了なし) → 投稿せず" | tee -a "$LOG"; return 0
    fi
    local status; if [[ "${rc:-0}" == "0" ]]; then status="✅"; else status="⚠️ rc=$rc"; fi
    text="🌙 *nightly-audit* ${DATE} — theme=\`${THEME}\` @${host} ${status}"
    [[ -n "$prs" ]] && text+=$'\n'"*開いた PR:*"$'\n'"$prs"
    if [[ -n "$body" ]]; then
      local maxlen=3500
      [[ ${#body} -gt $maxlen ]] && body="${body:0:$maxlen}"$'\n'"…(truncated。全文: ${report})"
      text+=$'\n''```'$'\n'"$body"$'\n''```'
    else
      text+=$'\n'"(レポート未生成: ${report})"
    fi
  fi
  local payload
  if command -v jq >/dev/null 2>&1; then
    payload="$(printf '%s' "$text" | jq -Rs '{text: .}')"
  else
    payload="$(printf '%s' "$text" | python3 -c 'import json,sys;print(json.dumps({"text":sys.stdin.read()}))')"
  fi
  if curl -fsS -X POST -H 'Content-type: application/json' --data "$payload" "$webhook" >>"$LOG" 2>&1; then
    echo "[slack] 投稿成功" | tee -a "$LOG"
  else
    echo "[slack] 投稿失敗 (webhook URL / ネットワークを確認)" | tee -a "$LOG"
  fi
}

# --- テーマ選択 -------------------------------------------------------------
mapfile -t THEMES < <(grep -vE '^\s*(#|$)' "$ROTATION")
[[ ${#THEMES[@]} -gt 0 ]] || { echo "rotation.txt が空"; exit 1; }
DOY=$(date +%j); DOY=$((10#$DOY))            # 年内通算日 (先頭0を10進化)
if [[ -n "${1:-}" ]]; then
  THEME="$1"
else
  THEME="${THEMES[$(( DOY % ${#THEMES[@]} ))]}"
fi

# backend-smoke-<deploy>-<mode> は共有テーマ themes/backend-smoke.md を使う。
# ★ 1 backend = 1晩。 drone と rover が両方 isaacsim を持てば、それぞれ別の晩 (計2晩)。
#   サブローテはしない — rotation.txt が (deploy×mode) を1行ずつ列挙して頻度を決める。
#   例: backend-smoke-drone-SIM / backend-smoke-rover-isaacsim
# deploy 名にハイフンは無い前提で、先頭の "<deploy>-" を剥がした残りを mode とする
# (mode は SITL_GZ_PX4 のように "_" を含むが "-" は含まない)。
SMOKE_DEPLOY=""; SMOKE_MODE=""; SMOKE_PATH=""
if [[ "$THEME" == backend-smoke-*-* ]]; then
  rest="${THEME#backend-smoke-}"            # <deploy>-<mode>
  SMOKE_DEPLOY="${rest%%-*}"                # 先頭セグメント = deploy
  SMOKE_MODE="${rest#*-}"                   # 残り = mode (内部の "_" は保持)
  THEME_FILE="$THEMES_DIR/backend-smoke.md"
  # targets.conf の deploy 行 (kind|name|path|project|modes) から path と許可 modes を取る
  while IFS='|' read -r kind name path project modes; do
    [[ "$(echo "$kind" | xargs)" == "deploy" ]] || continue
    [[ "$(echo "$name" | xargs)" == "$SMOKE_DEPLOY" ]] || continue
    SMOKE_PATH="$(echo "$path" | xargs)"; SMOKE_PATH="${SMOKE_PATH/#\~/$HOME}"
    SMOKE_MODES_CSV="$(echo "$modes" | xargs)"
    break
  done < <(grep -vE '^[[:space:]]*(#|$)' "$TARGETS")
  [[ -n "$SMOKE_PATH" ]] || { echo "backend-smoke: deploy '$SMOKE_DEPLOY' が targets.conf に無い"; exit 1; }
  # ★安全: mode が targets.conf の許可リストに無ければ実行しない (EXP 混入を弾く)
  IFS=',' read -ra MODES <<< "$(echo "${SMOKE_MODES_CSV:-}" | tr -d ' ')"
  ok=0; for m in "${MODES[@]}"; do [[ "$m" == "$SMOKE_MODE" ]] && ok=1; done
  [[ "$ok" == 1 ]] || { echo "backend-smoke: mode '$SMOKE_MODE' は $SMOKE_DEPLOY の許可 modes ($SMOKE_MODES_CSV) に無い。安全のため中止。"; exit 1; }
elif [[ "$THEME" == backend-smoke-* ]]; then
  echo "backend-smoke は 'backend-smoke-<deploy>-<mode>' 形式で指定する (例: backend-smoke-drone-SIM)。1 backend=1晩。"; exit 1
else
  THEME_FILE="$THEMES_DIR/${THEME}.md"
fi
[[ -f "$THEME_FILE" ]] || { echo "テーマ仕様が無い: $THEME_FILE"; exit 1; }

DATE="$(date +%Y-%m-%d)"
LOG="$LOG_DIR/${DATE}-${THEME}.run.log"
LOCK="$LOG_DIR/.lock"

# --- 多重起動防止 -----------------------------------------------------------
exec 9>"$LOCK"
if ! flock -n 9; then echo "別の監査が実行中。終了。"; exit 0; fi

echo "[nightly-audit] $DATE theme=$THEME host=$(hostname)" | tee -a "$LOG"

# --- Slack 自己テスト -------------------------------------------------------
# NIGHTLY_SLACK_TEST=1 なら claude を起動せず Slack 投稿経路だけ確かめて終了する
# (認証トークン不要。webhook と疎通を切り分けるため auth チェックより前に置く)。
if [[ "${NIGHTLY_SLACK_TEST:-0}" == "1" ]]; then
  echo "[nightly-audit] SLACK_TEST: Slack 投稿のみ試す (claude 起動なし)" | tee -a "$LOG"
  SLACK_OVERRIDE_TEXT="🔔 *nightly-audit* Slack 連携テスト — @$(hostname) ${DATE} (claude 未起動)" \
    notify_slack
  exit 0
fi

# --- プロンプト構築 ---------------------------------------------------------
PROMPT="$(cat "$HERE/driver.md")

============================================================
今日のテーマ仕様 (themes/$(basename "$THEME_FILE")):
============================================================
$(cat "$THEME_FILE")
$(if [[ -n "$SMOKE_DEPLOY" ]]; then cat <<SMOKE

============================================================
今夜の backend-smoke 対象 (★この1 backend だけ・1晩1 backend):
  deploy = ${SMOKE_DEPLOY}   (稼働 checkout: ${SMOKE_PATH})
  mode   = ${SMOKE_MODE}
他の backend/mode は今夜は回さない。上記 deploy×mode 1つだけを稼働 checkout で起動検証する。
安全則: SIM/SITL のみ・HITL は受動 (bringup/topic 確認まで)・EXP 禁止・実駆動指令を送らない。
============================================================
SMOKE
fi)

============================================================
実行日: ${DATE} / ホスト: $(hostname)
レポートは ${LOG_DIR}/${DATE}-${THEME}.md に書くこと。
============================================================"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "----- DRY_RUN: prompt -----"; echo "$PROMPT"; exit 0
fi

# --- backend-smoke: ホスト使用中ゲート (監査 2026-07-13〜15 ブロッカー B) -----
# 対象 project 以外のコンテナが Up のまま bringup すると GPU/DDS/ポートで干渉しうる。
# その場合は claude を起動せず、スキップした旨をレポート/Slack に残して正常終了する。
# 対象 project のコンテナ名 = $SMOKE_PATH/launcher/launch_<name>.sh の <name>
# (dup が CONTAINER_NAME に使う。インスタンス <name>_<inst> も同一視)。
# 常駐コンテナ (例: switchbot) は env の NIGHTLY_SMOKE_IGNORE=name1,name2 で除外する。
if [[ -n "$SMOKE_PATH" ]] && command -v docker >/dev/null 2>&1; then
  mapfile -t OWN < <(ls "$SMOKE_PATH/launcher/" 2>/dev/null | sed -nE 's/^launch_(.+)\.sh$/\1/p')
  FOREIGN=()
  while IFS= read -r c; do
    [[ -z "$c" ]] && continue
    keep=1
    for o in "${OWN[@]}"; do [[ "$c" == "$o" || "$c" == "${o}_"* ]] && { keep=0; break; }; done
    [[ ",${NIGHTLY_SMOKE_IGNORE:-}," == *",$c,"* ]] && keep=0
    [[ "$keep" == 1 ]] && FOREIGN+=("$c")
  done < <(docker ps --format '{{.Names}}' 2>/dev/null)
  if [[ ${#FOREIGN[@]} -gt 0 ]]; then
    REPORT="$LOG_DIR/${DATE}-${THEME}.md"
    {
      echo "# Nightly Audit ${DATE} — ${THEME} (host: $(hostname))"
      echo
      echo "## 結論"
      echo "**smoke スキップ (ホスト使用中ゲート・要注意)。claude 未起動・PR なし・既存コンテナには未接触。**"
      echo
      echo "対象 project (${SMOKE_DEPLOY}) 以外のコンテナが Up のため、干渉回避で bringup せず終了:"
      for c in "${FOREIGN[@]}"; do echo "- \`${c}\`"; done
      echo
      echo "常駐等で無視してよいコンテナは env の \`NIGHTLY_SMOKE_IGNORE\` (カンマ区切り) に追加する。"
    } > "$REPORT"
    echo "[nightly-audit] busy gate: 対象外コンテナ Up (${FOREIGN[*]}) → smoke スキップ" | tee -a "$LOG"
    rc=0
    notify_slack || true
    exit 0
  fi
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

# --- backend-smoke: acsl env を claude セッションに継承させる ----------------
# dup 等の acsl コマンドは deploy checkout の .acsl/bashrc が PATH/env を作る設計だが、
# cron 起動の headless セッションにはそれが無く dup が rc=127 になる
# (2026-07-13〜15 監査ブロッカー A)。dup は先頭で $ACSL_ROS2_DIR/bashrc を source して
# PROJECT/ROS_DOMAIN_ID 等を自力復元するので、ここでは PATH と WORK/ROS2 DIR だけ渡す。
# 副作用: 下の cd "${ACSL_WORK_DIR:-$HOME}" により claude は deploy checkout で起動する。
if [[ -n "$SMOKE_PATH" && -d "$SMOKE_PATH/.acsl" ]]; then
  export ACSL_WORK_DIR="$SMOKE_PATH"
  export ACSL_ROS2_DIR="$SMOKE_PATH/.acsl"
  export PATH="$SMOKE_PATH/.acsl/commands/scripts:$SMOKE_PATH/.acsl/docker/common/scripts:$PATH"
  echo "[nightly-audit] acsl env exported (ACSL_WORK_DIR=$SMOKE_PATH)" | tee -a "$LOG"
fi

# --- image-refresh: acsl infra コマンド (dbuild/dpush) を claude に継承 -------
# dbuild は $ACSL_ROS2_DIR (docker/ と dockerfiles/ の解決) と ROS_DISTRO (build-arg) が
# 必要。dontAsk では env 前置コマンド (ROS_DISTRO=... dbuild) が deny されるため、
# ここで export して Bash tool に継承させる。checkout は監査が動くこのリポ自身を使う。
if [[ "$THEME" == "image-refresh" ]]; then
  INFRA_DIR="$(cd "$HERE/.." && pwd)"
  export ACSL_ROS2_DIR="$INFRA_DIR"
  export ROS_DISTRO="jazzy"
  export PATH="$INFRA_DIR/commands/scripts:$INFRA_DIR/docker/common/scripts:$PATH"
  # dbuild --no-cache は 30〜60 分かかる。Bash tool の既定 2 分 / 上限 10 分では
  # ビルドが途中で殺されるため、このテーマだけ上限を 90 分に引き上げる。
  export BASH_DEFAULT_TIMEOUT_MS=5400000
  export BASH_MAX_TIMEOUT_MS=5400000
  echo "[nightly-audit] acsl infra env exported (ACSL_ROS2_DIR=$INFRA_DIR, ROS_DISTRO=jazzy, bash timeout 90min)" | tee -a "$LOG"
fi

# --- claude 無人起動 --------------------------------------------------------
# --bare 禁止  : --bare は CLAUDE_CODE_OAUTH_TOKEN を読まず "Not logged in" になる
#                (2.1.207 で確認)。headless は -p だけで keyring ハング等は起きない。
# dontAsk      : 許可リスト外は静かに拒否 = ハングしない。deny>ask>allow で deny 最優先。
# --settings   : audit_settings.json (allow=監査が使うコマンド, deny=破壊系ハードガード)
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PERMISSION_MODE="${NIGHTLY_PERMISSION_MODE:-dontAsk}"
SETTINGS="$HERE/audit_settings.json"

cd "${ACSL_WORK_DIR:-$HOME}"
set +e
"$CLAUDE_BIN" -p "$PROMPT" \
  --permission-mode "$PERMISSION_MODE" \
  --settings "$SETTINGS" >>"$LOG" 2>&1
rc=$?
set -e
echo "[nightly-audit] done rc=$rc" | tee -a "$LOG"

notify_slack || true

exit $rc
