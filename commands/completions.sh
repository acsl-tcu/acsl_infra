# dup <target> の launcher (.sh) を解決する。
#   all → project_launch.sh / それ以外 → launcher/launch_<target>.sh
# 完全一致を優先し、無ければ dup 本体と同じ grep フォールバック (最後にマッチ) を使う。
_dup_resolve_launcher() {
  local target="$1"
  if [[ "$target" == "all" ]]; then
    [[ -f "${ACSL_WORK_DIR}/project_launch.sh" ]] && echo "${ACSL_WORK_DIR}/project_launch.sh"
    return
  fi
  if [[ -f "${ACSL_WORK_DIR}/launcher/launch_${target}.sh" ]]; then
    echo "${ACSL_WORK_DIR}/launcher/launch_${target}.sh"
    return
  fi
  local m
  m=$(ls -v "${ACSL_WORK_DIR}/launcher/" 2>/dev/null | grep "launch_${target}" | grep '\.sh$' | tail -1)
  [[ -n "$m" ]] && echo "${ACSL_WORK_DIR}/launcher/${m}"
}

# launcher の「トップレベル case "$1" in」の pattern (= サブコマンド) を列挙する。
# ネストした case (use_sim_time 判定等) の pattern は深さで除外する。
_dup_subcommands() {
  awk '
    !cap && $0 ~ /(^|[[:space:]])case[[:space:]]+"?\$(\{?1\}?)"?[[:space:]]+in([[:space:]]|$)/ { cap=1; depth=1; next }
    cap {
      if ($0 ~ /(^|[[:space:]])case[[:space:]].*[[:space:]]in([[:space:]]|$)/) { depth++; next }
      if ($0 ~ /(^|[[:space:]])esac([[:space:]]|;|$)/) { depth--; if (depth==0) cap=0; next }
      if (depth==1 && match($0, /^[[:space:]]*"?[A-Za-z0-9_:=.-]+("?\|"?[A-Za-z0-9_:=.-]+)*"?\)/)) {
        line=$0; sub(/\).*/,"",line); gsub(/[[:space:]"]/,"",line)
        n=split(line, a, "|"); for(i=1;i<=n;i++) if(a[i]!="*"&&a[i]!="") print a[i]
      }
    }
  ' "$1"
}

_dup_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ $COMP_CWORD -eq 1 ]]; then
    local launchers
    launchers=$(ls "${ACSL_WORK_DIR}/launcher/" 2>/dev/null | sed -n 's/^launch_\(.*\)\.sh$/\1/p')
    COMPREPLY=($(compgen -W "all dev $launchers" -- "$cur"))
  elif [[ $COMP_CWORD -eq 2 ]]; then
    # dup <target> <TAB> : launcher/project_launch.sh の case "$1" pattern を提示
    local launcher subs
    launcher=$(_dup_resolve_launcher "${COMP_WORDS[1]}")
    [[ -n "$launcher" && -f "$launcher" ]] || return 0
    subs=$(_dup_subcommands "$launcher")
    COMPREPLY=($(compgen -W "$subs" -- "$cur"))
  fi
}
complete -F _dup_completions dup

_drm_completions() {
  if [[ $COMP_CWORD -eq 1 ]]; then
    local containers
    containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
    COMPREPLY=($(compgen -W "all $containers" -- "${COMP_WORDS[1]}"))
  fi
}
complete -F _drm_completions drm

# setrid <1-99> は $ACSL_ROS2_DIR/commands/scripts/setrid のスクリプトに移動
# (dup 等と同じく PATH 上のコマンド)。シェル関数ではないので再 source 不要。
