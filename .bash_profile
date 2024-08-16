readonly myPath=/Users/diego/bin
# readonly texPath=/usr/local/texlive/2018basic/bin/x86_64-darwin
readonly pythonBrewPath=/usr/local/opt/python/libexec/bin
readonly sqliteBrewPath=/usr/local/opt/sqlite/bin
# readonly rubyPath=/usr/local/opt/ruby/bin
readonly icu4cPath=/usr/local/opt/icu4c/bin:/usr/local/opt/icu4c/sbin
readonly brewPath=/usr/local/bin # /usr/local/sbin
# readonly condaPath=/anaconda3/bin
# readonly condaAddPath=/Users/diego/miniconda2/envs/py36/bin
readonly systemPath=/usr/bin:/bin:/usr/sbin:/sbin

export BREW_PATH="${pythonBrewPath}:${icu4cPath}:${brewPath}:${systemPath}"

# export ADDITIONAL_PATH="${myPath}:${rubyPath}:${sqliteBrewPath}:${texPath}:${condaPath}:" #FULL!!
# export ADDITIONAL_PATH="${myPath}:${condaPath}:${sqliteBrewPath}:"
export ADDITIONAL_PATH="${myPath}:${sqliteBrewPath}:"

# export PATH=${myPath}:${pythonBrewPath}:${sqliteBrewPath}:${brewPath}:${texPath}:${condaPath}:${systemPath}
export PATH="${ADDITIONAL_PATH}${BREW_PATH}"

# brew() {
#     export PATH="${BREW_PATH}"
#     command brew "$@"
#     export PATH="${ADDITIONAL_PATH}${BREW_PATH}"
# }

# Some programs use the shell defined in these variables
export SHELL=/usr/local/bin/bash
export BASH=/usr/local/bin/bash

# Use English on certain programs such as nano
export LANG=en_US.UTF-8
# export LC_ALL=en_US.UTF-8

# Updated versions of network security libraries, useful for OpenAirDrop for example
export LIBARCHIVE=/usr/local/opt/libarchive/lib/libarchive.dylib
export LIBCRYPTO=/usr/local/opt/openssl@1.1/lib/libcrypto.dylib

# HISTORY EDITS (WARNING: keep them at the top)
export HISTSIZE=25000
export HISTFILESIZE=25000
export HISTFILE=/Users/diego/.bash_long_history
# export HISTCONTROL=ignoredups                 # Don't save to history if the command equals the last one
shopt -s histappend                             # Append to end of history instead of overwriting
PROMPT_DIRTRIM=6                                # Maximum height path shown in prompt

# Ruby
export LDFLAGS="-L/usr/local/opt/ruby/lib"
export CPPFLAGS="-I/usr/local/opt/ruby/include"
export PKG_CONFIG_PATH="/usr/local/opt/ruby/lib/pkgconfig"

# Colors
readonly _red="\[\e[0;31m\]"
# readonly _RED="\[\e[1;31m\]"
# readonly _green="\[\e[0;32m\]"
# # readonly _GREEN="\[\e[1;32m\]"
readonly _yellow="\[\e[0;33m\]"
# # readonly _YELLOW="\[\e[1;33m\]"
readonly _blue="\[\e[0;34m\]"
# # readonly _BLUE="\[\e[1;34m\]"
readonly _magenta="\[\e[0;35m\]"
# # readonly _MAGENTA="\[\e[1;35\]"
readonly _cyan="\[\e[0;36m\]"
# # readonly _CYAN="\[\e[1;36m\]"
readonly _white="\[\e[0;37m\]"
# # readonly _WHITE="\[\e[1;37m\]"
readonly _reset="\[\e[0m\]"
readonly _black="\[\e[0;90m\]"

    # Old basic stuff: `user@host:` \u@\h:    `shortPath` \W
    
    #         clock with       |                 |            |
    #      last exit status    |     long path   | git status |
    # PS1="${_reset[$?]:-$_RED}\A $_yellow\w$_reset$(_gitPrompt)$ "
# PS1="\A $_yellow\w$_reset$ "

# LESS and CAT
#   to locate script: 'which highlight'
#   Setup: "brew install highlight"
export LESSOPEN="| /usr/local/bin/highlight %s --out-format xterm256 --quiet --force --style darkness"
export LESS=" --RAW-CONTROL-CHARS " 
alias less='less -M -g -i -u'
alias cat="highlight $1 --out-format xterm256 --quiet --force --style darkness"

# COMPLETION SCRIPTS:
# guide: https://troymccall.com/better-bash-4--completions-on-osx/
# other completion scripts: http://davidalger.com/development/bash-completion-on-os-x-with-brew/
if [ -f /usr/local/share/bash-completion/bash_completion ]; then
    source /usr/local/share/bash-completion/bash_completion
fi

#virtualenv wrapper init
source /usr/local/bin/virtualenvwrapper.sh

# iTerm shell integration
# source ~/.iterm2_shell_integration.`basename $SHELL`

# Put git repo information in the 'status' TouchBar button of iTerm
# function _iTermTouchBarGitPrompt()
# {
#     local git_status="`git status -unormal 2>&1`"
#     local status_msg=''

#     if ! [[ "$git_status" =~ Not\ a\ git\ repo ]]; then
#         if [[ "$git_status" =~ nothing\ to\ commit ]]; then
#             local status_msg="◽️ Clean" 
#         elif [[ "$git_status" =~ Changes\ to\ be\ committed ]]; then
#             if ! [[ "$git_status" =~ Untracked\ files ]] && ! [[ "$git_status" =~ Changes\ not\ staged\ for\ commit ]]; then
#                 local status_msg="🔹 All committed"
#             else
#                 local status_msg="🔸 Committed and untracked"
#             fi
#         else
#             local status_msg="🔺 All untracked"
#         fi

#         if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
#             local branch_name=${BASH_REMATCH[1]}
#         else
#             # Detached HEAD. (branch=HEAD is a faster alternative.)
#             local branch_name="❗️(`git describe --all --contains --abbrev=4 HEAD 2> /dev/null || echo HEAD`)"
#         fi

#         it2setkeylabel set status "$branch_name $status_msg"
#     else
#         it2setkeylabel set status "Not a git repo"
#     fi
# }

# export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}_iTermTouchBarGitPrompt; history -a;"

function _gitPrompt()
{
    local git_status="`git status -unormal 2>&1`"

    if ! [[ "$git_status" =~ not\ a\ git\ repo ]]; then
        if [[ "$git_status" =~ nothing\ to\ commit ]]; then
            local git_color=$_white
        elif [[ "$git_status" =~ Changes\ to\ be\ committed ]]; then
            if ! [[ "$git_status" =~ Untracked\ files ]] && ! [[ "$git_status" =~ Changes\ not\ staged\ for\ commit ]]; then
                local git_color=$_blue
            else
                local git_color=$_magenta
            fi
        else
            local git_color=$_red
        fi

        if [[ "$git_status" =~ On\ branch\ ([^[:space:]]+) ]]; then
            branch_name=${BASH_REMATCH[1]}
        else
            # Detached HEAD. (branch=HEAD is a faster alternative.)
            branch_name="(`git describe --all --contains --abbrev=4 HEAD 2> /dev/null || echo HEAD`)"
        fi

        echo "$git_color[$branch_name]"
    else
    	echo "$_black[]"
    fi

    
}

# _condaPrompt ()
# {
#     if [ ! -z "$CONDA_DEFAULT_ENV" ]; then
#         if [ "$CONDA_DEFAULT_ENV" != "base" ]; then
#             echo "$_black [$CONDA_DEFAULT_ENV]"
#         else
#             echo "$_black [base]"
#         fi
#     else
#         echo "$_black [x]"
#     fi
# }

_virtualenvPrompt ()
{
    if [[ $VIRTUAL_ENV != "" ]]
    then
        # Strip out the path and just leave the env name
        echo " (${VIRTUAL_ENV##*/})"
    else
        # In case you don't have one activated
        # echo "$_black (/)"
        echo "$_black ()"
    fi
}

function _setPrompt()
{
    PS1="${_reset[$?]:-$_red}\A $_yellow\w$_reset$(_virtualenvPrompt)$(_gitPrompt)$_reset$ "
}
export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND ;}_setPrompt; history -a;"

# function cd() {
#   command cd "$@" || return

#   if [[ -d .git ]]; then
#     git status --short
#   fi
#   # else
#   #   ls -al
# }

# function cd() {
#   builtin cd "$@"

#   if [[ -z "$VIRTUAL_ENV" ]] ; then
#     ## If env folder is found then activate the vitualenv
#       if [[ -d ./.env ]] ; then
#         source ./.env/bin/activate
#       fi
#   else
#     ## check the current folder belong to earlier VIRTUAL_ENV folder
#     # if yes then do nothing
#     # else deactivate
#       parentdir="$(dirname "$VIRTUAL_ENV")"
#       if [[ "$PWD"/ != "$parentdir"/* ]] ; then
#         deactivate
#       fi
#   fi
# }

# Autojump
[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh
# um
if [ -f $(brew --prefix)/etc/bash_completion.d/um-completion.sh ]; then
  . $(brew --prefix)/etc/bash_completion.d/um-completion.sh
fi

# Pyspark
export PYSPARK_HOME='/Users/diego/miniconda3/bin/'
export PYSPARK_DRIVER_PYTHON=jupyter
export PYSPARK_DRIVER_PYTHON_OPTS='notebook'

# Alias e funzioni
alias hu="history -n" # Read again the history file
alias grep="grep --color=auto"
alias .="open ."
alias ..="cd .."
alias ...="cd ..; cd .."
alias s="sublime"
alias ~="cd ~"
alias hist="history | tail -n 100"
alias ls="ls -G"
alias la="ls -la"
alias nano="nano -m"
alias hg="history|grep"
alias gs="git status"
alias gsp="git stash && git pull --rebase && git stash apply"
alias gl="git log"
alias gc="git commit"
alias gcp="git cherry-pick"
alias gco="git checkout"
# alias ca="conda activate"
#alias btlog="~/Documents/Sorgenti/mouseBatteryLog/battery_mouse_keyboard_log.sh"
alias ip="ifconfig -a | perl -nle'/(\d+\.\d+\.\d+\.\d+)/ && print $1'"
alias ipext="dig +short myip.opendns.com @resolver1.opendns.com"
mc() { mkdir -p "$@"; cd "$@"; }
alias wo="workon"
alias navi="navi --print"

# alias flushdns="dscacheutil -flushcache"
#alias unloadVirtualBox="sudo /Library/Application\ Support/VirtualBox/LaunchDaemons/VirtualBoxStartup.sh stop"
#alias loadVirtualBox="sudo /Library/Application\ Support/VirtualBox/LaunchDaemons/VirtualBoxStartup.sh start"

# test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
# eval $(/usr/libexec/path_helper -s)

# Usage: compresspdf [input file] [output file] [screen*|ebook|printer|prepress]
# compresspdf() {
#     /usr/local/bin/gs -sDEVICE=pdfwrite -dNOPAUSE -dQUIET -dBATCH -dPDFSETTINGS=/${3:-"screen"} -dCompatibilityLevel=1.4 -sOutputFile="$2" "$1"
# }
function updateBrew() {
    printf "\e[0;34m> \e[1;37mbrew update\e[0m\n" &&
    brew update &&
    sleep 0.05 &&
    printf "\e[0;34m> \e[1;37mbrew upgrade\e[0m\n" && 
    brew upgrade && 
    sleep 0.05 &&
    printf "\e[0;34m> \e[1;37mbrew cleanup\e[0m\n" && 
    brew cleanup &&
    sleep 0.05 &&
    printf "\e[0;34m> \e[1;37mbrew doctor\e[0m\n" &&
    brew doctor
}

function update() {
    # printf "\e[0;34m> \e[1;37msoftwareupdate -l &\e[0m\n"
    # (softwareupdate -l 2>&1 | while read line; do echo "[softwareupdate] $line"; done) &
    
    updateBrew

    printf "\e[0;34m> \e[1;37mnpm update -g\e[0m\n" &&
    npm update -g

    printf "\e[0;34m> \e[1;37mconda update -all --yes\e[0m\n" &&
    conda update --all --yes
    printf "\e[0;34m> \e[1;37mconda clean --all --yes \e[0m\n" &&
    conda clean --all --yes
}

alias wipe-modules-batch="/Users/diego/Documents/Progetti/wipe-modules-batch/wipe_modules_batch.sh"

notify() {
    $@
    terminal-notifier -title "Terminated: $*" -message "Exit code: $?"
}

# # Presenze
# function presenze-pause() {
#     docker pause $(docker ps -a -q)
#     pkill -STOP Chrome
#     pkill -STOP Toggl
#     # sleep 0.5
#     # pkill -STOP hyperkit
#     # pkill -STOP com.docker.osx*
#     # pkill -STOP com.docker.db
#     # pkill -STOP vpnkit
#     pkill -STOP grunt

#     printf "$(date) - \e[1;31mPAUSED\e[0m: Docker, hyperkit, Chrome, Toggl\n" 
# }
# function presenze-continue() {
#     # pkill -CONT vpnkit
#     # pkill -CONT com.docker.osx*
#     # pkill -CONT com.docker.db
#     # pkill -CONT hyperkit
#     pkill -CONT grunt
#     pkill -CONT Chrome
#     pkill -CONT Toggl
#     # sleep 0.5
#     docker unpause $(docker ps -a -q)

#     printf "$(date) - \e[1;32mRUNNING\e[0m: Docker, hyperkit, Chrome, Toggl\n"
# }

# function red() {
# 	printf "\e[1;31m${*}\n"
# 	$*
# 	printf "\e[0m"
# }

# function green() {
# 	printf "\e[1;32m${*}\n"
# 	$*
# 	printf "\e[0m"
# }

# google-cloud-sdk is installed at /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk. Add your profile:
# for bash users
source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.bash.inc'
source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc'

  # for zsh users
  #   source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc'
  #   source '/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc'
# added by Anaconda3 2019.07 installer
# >>> conda init >>>
# !! Contents within this block are managed by 'conda init' !!
# function ca() {
#     __conda_setup="$(CONDA_REPORT_ERRORS=false '/anaconda3/bin/conda' shell.bash hook 2> /dev/null)"
#     if [ $? -eq 0 ]; then
#         \eval "$__conda_setup"
#     else
#         if [ -f "/anaconda3/etc/profile.d/conda.sh" ]; then
#             . "/anaconda3/etc/profile.d/conda.sh"
#             CONDA_CHANGEPS1=false conda activate base
#         fi
#         # else
#             # \export PATH="/anaconda3/bin:$PATH"
#     fi
#     unset __conda_setup

#     if [ $# -eq 1 ]; then
#         conda activate $1
#     fi
# }
# <<< conda init <<<
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi
. "$HOME/.cargo/env"

source /Users/diego/.config/broot/launcher/bash/br

# >>> coursier install directory >>>
export PATH="$PATH:/Users/diego/Library/Application Support/Coursier/bin"
# <<< coursier install directory <<<
