_dup_completions() {
  if [[ $COMP_CWORD -eq 1 ]]; then
    local launchers
    launchers=$(ls "${ACSL_WORK_DIR}/launcher/" 2>/dev/null | sed -n 's/^launch_\(.*\)\.sh$/\1/p')
    COMPREPLY=($(compgen -W "all dev $launchers" -- "${COMP_WORDS[1]}"))
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
