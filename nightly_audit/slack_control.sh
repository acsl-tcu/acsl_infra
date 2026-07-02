#!/usr/bin/env bash
# Slack 制御ボット (poll 型)。制御チャンネルを定期取得し `!audit <cmd>` を実行する。
# webhook(送信専用)とは別の「Slack → ホスト」受信経路。NAT 内・pip 無しでも動くよう
# curl + jq だけで実装 (公開エンドポイント/WebSocket/外部パッケージ不要)。
#
# 必要 env (systemd/cron が ~/.config/acsl-nightly-audit.env を source して渡す):
#   NIGHTLY_SLACK_BOT_TOKEN        xoxb-...   (scopes: channels:history か groups:history, chat:write)
#   NIGHTLY_SLACK_CONTROL_CHANNEL  C0123...   (この channel に bot を招待しておく)
#   NIGHTLY_SLACK_ALLOW_USERS      U001,U002  (実行系コマンドを許可する Slack user ID。未設定だと実行系は無効)
#   NIGHTLY_SLACK_POLL_SEC         既定 15
#
# 実行系 (run) は run_nightly_audit.sh を起動するので、claude/gh トークンも env に必要。
# 完了通知は run 側の notify_slack (webhook) が出す。多重起動は runner の flock が防ぐ。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROTATION="$HERE/rotation.txt"
THEMES_DIR="$HERE/themes"
RUNNER="$HERE/run_nightly_audit.sh"
LOG_DIR="$HERE/logs"; mkdir -p "$LOG_DIR"
STATE="$LOG_DIR/.slack_control.last_ts"

BOT="${NIGHTLY_SLACK_BOT_TOKEN:-}"
CH="${NIGHTLY_SLACK_CONTROL_CHANNEL:-}"
ALLOW="${NIGHTLY_SLACK_ALLOW_USERS:-}"
POLL="${NIGHTLY_SLACK_POLL_SEC:-15}"

[[ -z "$BOT" || -z "$CH" ]] && {
  echo "[ctl] NIGHTLY_SLACK_BOT_TOKEN / NIGHTLY_SLACK_CONTROL_CHANNEL 未設定。終了"; exit 1; }
command -v jq >/dev/null || { echo "[ctl] jq が必要"; exit 1; }

# --- Slack Web API (curl) ---------------------------------------------------
api() { # api <method> <field=val> ...
  local method="$1"; shift
  local args=(); local kv
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  curl -sS -X POST "https://slack.com/api/$method" \
    -H "Authorization: Bearer $BOT" \
    -H "Content-type: application/x-www-form-urlencoded" "${args[@]}"
}
post() { api chat.postMessage "channel=$CH" "text=$1" >/dev/null; }

# --- テーマ照会 -------------------------------------------------------------
themes_available() { find "$THEMES_DIR" -maxdepth 1 -name '*.md' ! -name '_TEMPLATE.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//' | sort; }
themes_active()    { grep -vE '^[[:space:]]*(#|$)' "$ROTATION" 2>/dev/null; }
theme_known() {  # themes/<t>.md があるか、backend-smoke-* (共有テーマ) か
  local t="$1"
  [[ -f "$THEMES_DIR/$t.md" ]] && return 0
  [[ "$t" == backend-smoke-* && -f "$THEMES_DIR/backend-smoke.md" ]] && return 0
  return 1
}
is_active() { themes_active | grep -qxF "$1"; }   # pipe形 (grep -q + <() は競合で空読みしうる)

allowed() {  # 実行系を許可された user か (ALLOW 未設定なら不許可)
  local u="$1" x
  [[ -z "$ALLOW" ]] && return 1
  for x in ${ALLOW//,/ }; do [[ "$x" == "$u" ]] && return 0; done
  return 1
}

# --- コマンド ---------------------------------------------------------------
cmd_help() {
  post ":robot_face: *audit 制御*  使い方:
\`!audit list\`    有効/利用可能なテーマ一覧
\`!audit status\`  今日のテーマ・直近ログ
\`!audit enable <name>\`  テーマを有効化 (rotation 追記)
\`!audit disable <name>\` テーマを無効化 (rotation 削除)
\`!audit run <name>\`     今すぐ実行 (完了は通知で)"
}
# テーマの短い説明を見出し "# テーマ: <name> (<説明>)" から取り出す。
# backend-smoke-<deploy>-<mode> は共有 themes/backend-smoke.md の説明に対象を添える。
theme_desc() {
  local t="$1" f="$THEMES_DIR/$1.md" base
  [[ -f "$f" ]] || { [[ "$t" == backend-smoke-* ]] && f="$THEMES_DIR/backend-smoke.md"; }
  [[ -f "$f" ]] || return 0
  local h; h="$(grep -m1 -E '^#[[:space:]]*テーマ' "$f" 2>/dev/null)"
  [[ "$h" =~ \((.+)\) ]] && base="${BASH_REMATCH[1]}"
  if [[ "$t" == backend-smoke-*-* ]]; then
    local rest="${t#backend-smoke-}"
    printf '%s (%s × %s)' "${base:-実起動検証}" "${rest%%-*}" "${rest#*-}"
  else
    printf '%s' "${base:-}"
  fi
}
cmd_list() {
  local out=":card_index_dividers: *監査テーマ*" t d n=0
  out+=$'\n\n'"*有効 (rotation・上から日替わりで選択)*"
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    d="$(theme_desc "$t")"; out+=$'\n'"• \`$t\`${d:+ — $d}"; n=$((n+1))
  done < <(themes_active)
  ((n==0)) && out+=$'\n'"(なし)"
  out+=$'\n\n'"*利用可能 (themes/)*"
  while IFS= read -r t; do
    [[ -z "$t" ]] && continue
    d="$(theme_desc "$t")"
    if is_active "$t"; then out+=$'\n'"• \`$t\` ✅有効${d:+ — $d}"
    else                    out+=$'\n'"• \`$t\`${d:+ — $d}"; fi
  done < <(themes_available)
  out+=$'\n\n'"操作: \`!audit enable/disable/run <name>\` ・ \`!audit status\`"
  post "$out"
}
cmd_status() {
  mapfile -t T < <(themes_active)
  local sel="(有効テーマなし)"
  if ((${#T[@]})); then
    local doy; doy=$(date +%j)        # 10# で 008/009 の8進エラーを回避
    sel="${T[$((10#$doy % ${#T[@]}))]}"
  fi
  local last tailtxt=""
  last="$(ls -t "$LOG_DIR"/*.run.log 2>/dev/null | head -1)"
  [[ -n "$last" ]] && tailtxt="$(tail -n 3 "$last" 2>/dev/null)"
  post ":calendar: 今日のテーマ: *$sel*  (有効 ${#T[@]} 件)
直近ログ: ${last:-なし}
\`\`\`
${tailtxt}
\`\`\`"
}
cmd_enable() {
  local t="$1"
  theme_known "$t" || { post ":x: \`themes/$t.md\` が無い (利用可能は \`!audit list\`)"; return; }
  is_active "$t" && { post ":information_source: \`$t\` は既に有効"; return; }
  printf '%s\n' "$t" >> "$ROTATION"
  post ":white_check_mark: \`$t\` を有効化 (rotation に追記)"
}
cmd_disable() {
  local t="$1"
  is_active "$t" || { post ":information_source: \`$t\` は有効リストに無い"; return; }
  local tmp; tmp="$(mktemp)"
  awk -v t="$t" '{ s=$0; gsub(/^[ \t]+|[ \t]+$/,"",s); if(s==t) next; print }' "$ROTATION" > "$tmp" && mv "$tmp" "$ROTATION"
  post ":white_check_mark: \`$t\` を無効化 (rotation から削除)"
}
cmd_run() {
  local t="$1"
  theme_known "$t" || { post ":x: \`themes/$t.md\` が無い"; return; }
  post ":rocket: \`$t\` を実行開始 (完了は通知で報告します)"
  nohup "$RUNNER" "$t" >>"$LOG_DIR/cron.log" 2>&1 &
}

dispatch() {
  local user="$1" text="$2" tag cmd arg
  read -r tag cmd arg _ <<<"$text"
  [[ "$tag" != "!audit" ]] && return
  case "$cmd" in
    list)    cmd_list ;;
    status)  cmd_status ;;
    help|"") cmd_help ;;
    enable|disable|run)
      if ! allowed "$user"; then
        post ":lock: \`$cmd\` は許可ユーザーのみ (NIGHTLY_SLACK_ALLOW_USERS)"; return
      fi
      [[ -z "$arg" ]] && { post ":x: 使い方: \`!audit $cmd <theme>\`"; return; }
      case "$cmd" in
        enable)  cmd_enable  "$arg" ;;
        disable) cmd_disable "$arg" ;;
        run)     cmd_run     "$arg" ;;
      esac
      ;;
    *) post ":grey_question: 不明なコマンド \`$cmd\`  (\`!audit help\`)" ;;
  esac
}

# --- メインループ -----------------------------------------------------------
# 初回は履歴をリプレイしないよう「今」を基準にする (oldest は exclusive)。
if [[ -f "$STATE" ]]; then LAST="$(cat "$STATE")"; else LAST="$(date +%s).000000"; printf '%s\n' "$LAST" > "$STATE"; fi
echo "[ctl] start channel=$CH poll=${POLL}s allow=${ALLOW:-<none>}"
while true; do
  resp="$(api conversations.history "channel=$CH" "oldest=$LAST" "limit=50")"
  if [[ "$(jq -r '.ok // false' <<<"$resp" 2>/dev/null)" == "true" ]]; then
    while IFS=$'\t' read -r ts user text; do
      [[ -z "$ts" ]] && continue
      dispatch "$user" "$text"
      LAST="$ts"; printf '%s\n' "$LAST" > "$STATE"
    done < <(jq -r '.messages | sort_by(.ts) | .[]
                    | select(.subtype==null and (has("bot_id")|not))
                    | [.ts, (.user//""), (.text//"")] | @tsv' <<<"$resp")
  else
    echo "[ctl] api err: $(jq -r '.error // "?"' <<<"$resp" 2>/dev/null)"
  fi
  sleep "$POLL"
done
