# main executable
# resolve the directory this file lives in (bash and zsh), unless preset
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _ducttape_src="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    eval '_ducttape_src="${(%):-%x}"'
else
    _ducttape_src="$0"
fi
export DUCTTAPE_DIR="${DUCTTAPE_DIR:-$(dirname "$(realpath "$_ducttape_src")")}"
unset _ducttape_src
alias dt='just --justfile "${DUCTTAPE_DIR}/justfile"'
alias ducttape='just --justfile "${DUCTTAPE_DIR}/justfile"'

# aliases
alias a='just --justfile "${DUCTTAPE_DIR}/justfile" a'
alias d='just --justfile "${DUCTTAPE_DIR}/justfile" d'
alias di='just --justfile "${DUCTTAPE_DIR}/justfile" di'
alias dn='just --justfile "${DUCTTAPE_DIR}/justfile" dn'
alias dv='just --justfile "${DUCTTAPE_DIR}/justfile" dv'
alias dvv='just --justfile "${DUCTTAPE_DIR}/justfile" dvv'
alias ds='just --justfile "${DUCTTAPE_DIR}/justfile" ds'
alias gb='just --justfile "${DUCTTAPE_DIR}/justfile" gb'
alias k='just --justfile "${DUCTTAPE_DIR}/justfile" k'
alias m='just --justfile "${DUCTTAPE_DIR}/justfile" m'
alias p='just --justfile "${DUCTTAPE_DIR}/justfile" p'
alias s='just --justfile "${DUCTTAPE_DIR}/justfile" s'
alias t='just --justfile "${DUCTTAPE_DIR}/justfile" t'
