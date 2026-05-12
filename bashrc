# bashrc for acsl project
shopt -s histappend
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# --- tab completion ---
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
