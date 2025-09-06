# Paths
set -gx HOMEBREW_PREFIX /opt/homebrew
fish_add_path /usr/bin /bin /usr/sbin /sbin
fish_add_path /usr/local/bin
fish_add_path $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin
fish_add_path $HOMEBREW_PREFIX/opt/icu4c/bin $HOMEBREW_PREFIX/opt/icu4c/sbin
fish_add_path $HOMEBREW_PREFIX/opt/sqlite/bin
fish_add_path $HOME/Library/pnpm
fish_add_path $HOME/.lmstudio/bin
fish_add_path /usr/local/go/bin
fish_add_path $HOME/.cargo/bin    # rust
fish_add_path $HOME/.local/bin    # my path

# pnpm
set -Ux PNPM_HOME $HOME/Library/pnpm
fish_add_path $PNPM_HOME

# Env
set -gx EDITOR nvim
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx GEMINI_API_KEY (cat ~/.gemini_api_key)
set -gx HOMEBREW_NO_ENV_HINTS 1

# Google Cloud SDK
source $HOMEBREW_PREFIX/Caskroom/gcloud-cli/latest/google-cloud-sdk/path.fish.inc

# zoxide (command `j`)
zoxide init fish --cmd z | source

# try: https://github.com/tobi/try
set -gx TRY_PATH ~/code/hack
~/.local/try.rb init | source
# eval "$(~/.local/try.rb init | string collect)"

# fzf
fzf --fish | source
set -gx FZF_CTRL_T_COMMAND 'fd -H --type f'
# Function inspired from official CTRL-T from https://github.com/junegunn/fzf/blob/master/shell/key-bindings.fish
function fzf-dir-widget -d "List files and folders"
    set -l commandline (__fzf_parse_commandline)
    set -lx dir $commandline[1]
    set -l fzf_query $commandline[2]
    set -l prefix $commandline[3]

    set -lx FZF_DEFAULT_OPTS (__fzf_defaults \
      "--reverse --walker=dir,follow,hidden --scheme=path --multi --print0")

    set -lx FZF_DEFAULT_COMMAND
    set -lx FZF_DEFAULT_OPTS_FILE

    set -l result (eval (__fzfcmd) --walker-root=$dir --query=$fzf_query | string split0)
    and commandline -rt -- (string join -- ' ' $prefix(string escape -- $result))' '

    commandline -f repaint
end
# Search directories
bind \ce fzf-cd-proximity
bind -M insert \ce fzf-dir-widget

if status is-interactive
    # Keybindings
    fish_vi_key_bindings

    # Remove fish greeting
    function fish_greeting
    end

    # Abbreviations
    abbr -a g git
    abbr -a gs 'git status'
    abbr -a gl 'git log'
    abbr -a gp 'git push'
    abbr -a gc 'git commit'
    abbr -a gcm 'git commit -m'
    abbr -a n nvim
    abbr -a l 'ls -lah'
    abbr -a lg lazygit
    abbr -a sa 'source .venv/bin/activate.fish'
    abbr -a sd deactivate
    abbr -a ask --set-cursor 'aichat -r cli \'%\''
    abbr -a trl --set-cursor 'aichat -r trl \'%\''
    abbr -a cmd --set-cursor 'aichat -r cmd \'%\''
    abbr -a em  --set-cursor 'aichat -r emoji \'%\''
    abbr -a teach --set-cursor 'aichat -r teach \'%\''
    abbr -a t 'try'

    # Aliases
    alias dust='dust -r'
    alias grep='grep --color=auto'
    alias ls='ls -G'
    alias ghostty='/Applications/Ghostty.app/Contents/MacOS/ghostty'

    # yazi with cwd handoff
    function y
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

    # ----- Abbreviations and functions for notes -----
    abbr -a nn 'cd ~/notes; nvim .'

    # Open most recent ait/quicknote
    function nq
        set -l latest (ls -t ~/notes/AIT/quicknotes-*.md | head -n 1)

        if test -z "$latest"
            echo "No quicknotes-*.md found in "(pwd)
            return 1
        end

        nvim "$latest"
    end

    # Open most recent Registro note
    function nr
        set -l latest (ls -t ~/notes/Registro/*.md | head -n 1)
        nvim "$latest"
    end

    # ----- Retry the command passed until success -----
    function retry
        set -l attempts 1000
        set -l delay 1
        for i in (seq 1 $attempts)
            echo "-- ATTEMPT $i --"
            $argv; and break; or sleep $delay
        end
    end

    # Quick swap gconf account
    function gconf
        if test (count $argv) -eq 0
            echo "running: gcloud config configurations list"
            gcloud config configurations list
        else
            echo "running: gcloud config configurations activate $argv"
            gcloud config configurations activate $argv
            rm -f $HOME/.config/gcloud/application_default_credentials.json
            cp $HOME/.config/gcloud/$argv[1].json $HOME/.config/gcloud/application_default_credentials.json
        end
    end

    # Taken from: https://github.com/dideler/dotfiles/blob/master/functions/extract.fish
    function extract --description "Expand or extract bundled & compressed files"
      set --local ext (echo $argv[1] | awk -F. '{print $NF}')
      switch $ext
        case tar  # non-compressed, just bundled
          tar -xvf $argv[1]
        case gz
          if test (echo $argv[1] | awk -F. '{print $(NF-1)}') = tar  # tar bundle compressed with gzip
            tar -zxvf $argv[1]
          else  # single gzip
            gunzip $argv[1]
          end
        case tgz  # same as tar.gz
          tar -zxvf $argv[1]
        case bz2  # tar compressed with bzip2
          tar -jxvf $argv[1]
        case rar
          unrar x $argv[1]
        case zip
          unzip $argv[1]
        case '*'
          echo "unknown extension"
      end
    end

    # Send notification after finishing the command
    function notify
        $argv
        set -l code $status
        osascript -e "display notification \"Exit code: $code\" with title \"Terminated: $argv\""
        say "Execution finished."
    end

end

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /Users/diego/.lmstudio/bin
# End of LM Studio CLI section

