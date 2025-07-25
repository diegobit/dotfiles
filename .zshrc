##############################
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
export ZLE_RPROMPT_INDENT=0
source /usr/local/opt/powerlevel10k/share/powerlevel10k/powerlevel10k.zsh-theme
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
source ~/.p10k.zsh

##############################
# Plugins for lazy loading
##############################
source ~/Dev/zsh_plugins/zsh-lazyload/zsh-lazyload.zsh
# source ~/Dev/zsh_plugins/evalcache/evalcache.plugin.zsh
source ~/Dev/zsh_plugins/zsh-smartcache/zsh-smartcache.plugin.zsh

##############################
# PATH
##############################
# texPath=/usr/local/texlive/2018basic/bin/x86_64-darwin
# pythonBrewPath=/usr/local/opt/python/libexec/bin
# jenvPath="$HOME/.jenv/bin"
# texPath="/Library/TeX/texbin"
local systemPath="/usr/bin:/bin:/usr/sbin:/sbin"
local brewHome="/usr/local" # /usr/local/sbin
export HOMEBREW_PREFIX=${brewHome}
local brewPath="/usr/local/bin:/usr/local/sbin"
local icu4cPath="/usr/local/opt/icu4c/bin:/usr/local/opt/icu4c/sbin"
local nodePath="/usr/local/opt/node/bin"
local nodeGlobalPath="$HOME/.npm-global/bin"
local sqlitePath="/usr/local/opt/sqlite/bin"
# local pyenvPath="$HOME/.pyenv/shims"
# local brewAdditionalPath="${pyenvPath}:${sqlitePath}:${nodePath}:${icu4cPath}"
local brewAdditionalPath="${sqlitePath}:${nodeGlobalPath}:${nodePath}:${icu4cPath}"
local goPath="/usr/local/go/bin"
local rustPath="$HOME/.cargo/bin"
local uvPath="$HOME/.local/bin"
local myPath="$HOME/bin"
local manuallyInstPath="${myPath}:${uvPath}:${goPath}:${rustPath}"
export PATH="${manuallyInstPath}:${brewAdditionalPath}:${brewPath}:${systemPath}"

# Some programs use the shell defined in these variables
export SHELL=/usr/local/bin/zsh
export ZSH=/usr/local/bin/zsh
export EDITOR=nvim
export XDG_CONFIG_HOME=~/.config # used by kickstart-nvim for example
# Updated versions of network security libraries, useful for OpenAirDrop for example
# export LIBARCHIVE=/usr/local/opt/libarchive/lib/libarchive.dylib
# export LIBCRYPTO=/usr/local/opt/openssl/lib/libcrypto.dylib

# Api key for scripts using gemini
export GEMINI_API_KEY=$(cat ~/.gemini_api_key)

##############################
# COMMON SETTINGS
##############################
# Lines configured by zsh-newuser-install
HISTFILE=~/.zsh_histfile
HISTSIZE=25000 # size memory. Do not discard least recent from memory until exit
SAVEHIST=20000 # file size
setopt INC_APPEND_HISTORY EXTENDED_HISTORY HIST_FIND_NO_DUPS AUTO_CD NOTIFY 
bindkey -v
bindkey ^R history-incremental-search-backward
bindkey ^S history-incremental-search-forward

# make ctrl-p and ctrl-n behave as up and down
autoload -Uz up-line-or-history
autoload -Uz down-line-or-history
bindkey "^P" up-line-or-history
bindkey "^N" down-line-or-history

# for allowing canc to delete forward char
bindkey    "^[[3~"          delete-char
bindkey    "^[3;5~"         delete-char

##############################
# TAB COMPLETION
##############################
# # compinstall generated lines:
# zstyle :compinstall filename '${HOME}/.zshrc'
# autoload -Uz compinit
# compinit
# # tab-completion menu
# zsty le ':completion:*' menu select
# _print_tree() {
#     echo
#     tree ${LBUFFER[(w)2]}
#     zle redisplay
# }
# zle -N _print_tree
# bindkey -M viins '^E' _print_tree
# End of lines added by compinstall

##############################
# Colors
##############################
# local _red="\e[0;31m"
# local _yellow="\e[0;33m"
local _blue="\e[0;34m"
# local _magenta="\e[0;35m"
# local _white="\e[0;37m"
local _reset="\e[0m"
# local _black="\e[0;90m"

##############################
# iterm integration
##############################
#source ~/.iterm2_shell_integration.zsh

##############################
# Zoxide
##############################
# eval "$(zoxide init --cmd j zsh)"
smartcache eval zoxide init --cmd j zsh

##############################
# PYENV
##############################
# function pyenvinit() {
#     export PYENV_ROOT="$HOME/.pyenv"
#     export PYENV_VIRTUALENV_DISABLE_PROMPT=1
#     export PATH="$pyenvPath:$PATH"
#     eval "$(pyenv init - zsh)"
#     eval "$(pyenv virtualenv-init -)"
# }
# eval "$(pyenv init - zsh)"
# eval "$(pyenv virtualenv-init -)"
# smartcache eval pyenv init - zsh
# smartcache eval pyenv virtualenv-init -

##############################
# JENV
##############################
# eval "$(jenv init -)"
# smartcache jenv init -

##############################
# RUST (path is in .zshenv)
##############################
. "$HOME/.cargo/env"

##############################
# Node version manager
##############################
eval "$(fnm env --use-on-cd --shell zsh)"

##############################
# GOOGLE CLOUD
##############################
# google-cloud-sdk is installed at /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk
# export CLOUDSDK_PYTHON=python3
source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc'
# zsh completion gcloud
#source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc'

##############################
# AUTOSUGGESTIONS
##############################
source ${brewHome}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#888888" #8495a0 #9379a0
export ZSH_AUTOSUGGEST_MANUAL_REBIND=true # could interfere with other widgets, but faster startup
# Bindings like nvim: <C-Space> accept; <C-G> accept word; <C-G> clear suggestion
bindkey '^ ' autosuggest-accept
bindkey '^G' forward-word
bindkey '^x' autosuggest-clear

##############################
# ZSH SYNTAX HIGHLIGHT
##############################
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=${HOMEBREW_PREFIX}/share/zsh-syntax-highlighting/highlighters
source ${brewHome}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

##############################
# FUZZY FINDER FZF
##############################
source ~/.fzf.zsh
# Use fd (https://github.com/sharkdp/fd) instead of the default find command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
# _fzf_compgen_path() {
#   fd --hidden --follow --exclude ".git" . "$1"
# }
# Use fd to generate the list for directory completion
# _fzf_compgen_dir() {
#   fd --type d --hidden --follow --exclude ".git" . "$1"
# }
# Setting fd as the default source for fzf
export FZF_DEFAULT_COMMAND='fd --type f'
export FZF_DEFAULT_OPTS='--height=25'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND --no-ignore-vcs"
export FZF_ALT_C_COMMAND="fd -I --max-depth 5 --type directory | proximity-sort ."

##############################
# yazi
##############################

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

##############################
# Aliases and functions
##############################
export ait=$HOME/Dev/AIT
alias dust='dust -r'
alias g="git"
alias gs="git status"
alias gc="git commit"
alias grep="grep --color=auto"
alias ip="ifconfig -a | perl -nle'/(\d+\.\d+\.\d+\.\d+)/ && print $1'; dig +short myip.opendns.com @resolver1.opendns.com"
alias l="ls -lah"
alias lg="lazygit"
alias ls="ls -G"
alias sa="source .venv/bin/activate"
alias sd="deactivate"
alias ghostty="/Applications/Ghostty.app/Contents/MacOS/ghostty"
alias n="nvim"
nd() {
    if [[ $# -lt 1 ]]; then
        echo "Error: No target specified." >&2
        return 1
    fi
    target="$1"
    # if arg is a dir, cd into it
    if [[ -d "$target" ]]; then
        cd "$target"
        nvim .
    # if arg is a file, cd into either: git root, or dirname
    elif [[ -f "$target" ]]; then
        d=$(dirname "$target")
        target=$(basename $target)
        cd "$d"
        nvim "$target"
    else
      echo "Error: '$target' is not a file or directory." >&2
      exit 1
    fi
}
ng() {
    # exit if the function has no args
    if [[ $# -lt 1 ]]; then
        echo "Error: No target specified." >&2
        return 1
    fi
    target="$1"
    # if arg is a dir, cd into it
    if [[ -d "$target" ]]; then
        cd "$target"
    # if arg is a file, cd into either: git root, or dirname
    elif [[ -f "$target" ]]; then
        d=$(dirname "$target")
        target=$(readlink -f $target)
        cd "$d"
    else
      echo "Error: '$target' is not a file or directory." >&2
      exit 1
    fi

    git_root=$(git rev-parse --show-toplevel 2> /dev/null)
    if [ $? -eq 0 ]; then
        cd "$git_root"
    fi

    nvim "$target"
}
nn() {
    cd ~/notes
    nvim .
}
nr() {
    cd ~/notes/Registro
    most_recent=$(ls -Art | tail -n 1)
    nvim $most_recent
}
yn() {
    cd ~/notes
    yazi
}

alias ask="aichat -r def"
alias trl="aichat -r tr"
alias cmd="aichat -r sh"
alias em="aichat -r em"

retry() {
  local attempts=1000
  local delay=1
  local i

  for i in $(seq 1 $attempts); do
    echo "-- ATTEMPT $i --"
    "${@}" && break || sleep $delay
  done

  return $?
}

function gconf(){
    if [ -z $1 ]; then
        echo "running: gcloud config configurations list"
        gcloud config configurations list
    else
        echo "running: gcloud config configurations list $@"
        gcloud config configurations activate $@
        rm $HOME/.config/gcloud/application_default_credentials.json
        cp $HOME/.config/gcloud/${1}.json $HOME/.config/gcloud/application_default_credentials.json
    fi
}

function untar(){
    if [ -f $1 ] ; then
        case $1 in
                *.tar.bz2)   tar xvjf $1    ;;
                *.tar.gz)    tar xvzf $1    ;;
                *.bz2)       bunzip2 $1     ;;
                *.rar)       unrar x $1     ;;
                *.gz)        gunzip $1      ;;
                *.tar)       tar xvf $1     ;;
                *.tbz2)      tar xvjf $1    ;;
                *.tgz)       tar xvzf $1    ;;
                *.zip)       unzip $1       ;;
                *.Z)         uncompress $1  ;;
                *.7z)        7z x $1        ;;
                *)           echo "Unable to extract '$1'" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

notify() {
  "$@"
  local exit_code=$?
  osascript -e "display notification \"Exit code: ${exit_code}\" with title \"Terminated: $*\""
  say "Execution finished."
}

##############################
# NEW STUFF
##############################
