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

# setrid <1-99> : ROS_DOMAIN_ID(RID) を一発で変更する。
#   - $ACSL_ROS2_DIR/bashrc の export 行を書き換え (以後の dup が反映)
#   - 現在の対話シェルにも即 export (PS1 表示も更新)
#   - 本日分の RID 確認スタンプも更新 (= setrid 自体が日次確認を兼ねる)
# 関数で定義する理由: スクリプトだと親シェルの ROS_DOMAIN_ID を変えられないため。
setrid() {
  local id="$1"
  if ! [[ "$id" =~ ^[0-9]+$ ]] || ((id < 1 || id > 99)); then
    recho "setrid: RID は 1-99 の整数で指定してください (例: setrid 42)"
    return 1
  fi
  # set_bashrc は CWD の ./bashrc を書き換えるのでサブシェルで $ACSL_ROS2_DIR へ移動
  (cd "$ACSL_ROS2_DIR" && set_bashrc "export ROS_DOMAIN_ID" "$id" >/dev/null)
  export ROS_DOMAIN_ID="$id"
  local stamp="$ACSL_ROS2_DIR/.acsl/rid_confirmed"
  mkdir -p "$(dirname "$stamp")"
  printf '%s %s\n' "$(date +%F)" "$id" >"$stamp"
  gecho "ROS_DOMAIN_ID を ${id} に設定しました (本日分の確認済み)。"
  recho "反映には対象コンテナの再生成が必要: drestart <name> もしくは drm <name> && dup <name>"
}
