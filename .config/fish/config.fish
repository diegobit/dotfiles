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
fish_add_path $HOME/go/bin        # go
fish_add_path $HOME/.local/bin    # my path
fish_add_path /Users/diego/.opencode/bin

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
    abbr -a gll 'git log --oneline --graph --decorate --all'
    abbr -a gp 'git push'
    abbr -a gb 'git branch -vv'
    abbr -a gc 'git commit'
    abbr -a gsw 'git switch'
    abbr -a gr 'git restore'
    abbr -a gcp 'git cherry-pick'
    abbr -a ga 'git add -p'
    abbr -a gw 'git worktree'
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
    abbr -a o 'opencode'
    abbr -a c 'codex'

    # Aliases
    alias dust='dust -r'
    alias grep='grep --color=auto'
    alias ls='ls -G'

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
    function qn
        # set -l latest (ls -t ~/notes/AIT/quicknotes-*.md | head -n 1)

        # if test -z "$latest"
        #     echo "No quicknotes-*.md found in "(pwd)
        #     return 1
        # end

        cd ~/notes/AIT
        nvim quicknotes.md
    end

    # Open most recent Registro note
    function rn
        set -l latest (ls -t ~/notes/Registro/*.md | head -n 1)
        cd ~/notes/Registro
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
    function notify --description 'Run a command, then macOS notify; no args -> just say Finished'
        if test (count $argv) -gt 0
            # Run the command and capture its exit status
            $argv
            set -l code $status

            # Build a readable title and escape quotes for AppleScript
            set -l title (string join ' ' $argv)
            set -l title (string replace -a '"' '\"' -- $title)

            osascript -e "display notification \"Exit code: $code\" with title \"Terminated: $title\""
            say "Finished."
            return $code
        else
            osascript -e 'display notification "Finished" with title "notify"'
            say "Finished"
            return 0
        end
    end

    # Sent notification to Pushover Device
    function pushover --description 'Send a Pushover notification' --argument-names msg
        set -l token (string trim -- (cat ~/.pushover-token))
        set -l user  (string trim -- (cat ~/.pushover-user))
        set -l where (prompt_pwd)

        if test -n "$msg"
            set msg "$msg ($where)"
        else
            set msg "Plin plon! ($where)"
        end

        curl -sS --fail \
            --form-string "token=$token" \
            --form-string "user=$user" \
            --form-string "message=$msg" \
            https://api.pushover.net/1/messages.json >/dev/null
    end

    function tg --description 'Send a Telegram message to myself' --argument-names msg
        set -l token (string trim -- (cat ~/.telegram-bot-token))
        set -l chat  (string trim -- (cat ~/.telegram-chat-id))
        set -l where (prompt_pwd)

        if test -n "$msg"
            set msg "$msg ($where)"
        else
            set msg "Plin plon! ($where)"
        end

        curl -sS --fail --max-time 10 \
            --form-string "chat_id=$chat" \
            --form-string "text=$msg" \
            "https://api.telegram.org/bot$token/sendMessage" >/dev/null
    end

    # Create a new worktree and branch from within current git directory.
    function gwa
        if test (count $argv) -lt 1
            echo "Usage: gwa <branch-name>"
            return 1
        end

        # Make sure we're inside a git worktree/repo
        git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
            echo "gwa: not inside a git repository"
            return 1
        end

        set -l branch $argv[1]
        set -l base (basename (pwd))
        set -l path "../$base--$branch"

        # -b creates a new branch; this fails if branch already exists (often desirable).
        git worktree add -b $branch $path; or return $status
        # mise trust $path
        cd $path
    end

    # Remove worktree and branch from within active worktree directory.
    function gwd
        git rev-parse --is-inside-work-tree >/dev/null 2>&1; or begin
            echo "gwd: not inside a git repository/worktree"
            return 1
        end

        set -l cwd (pwd)
        set -l worktree (basename $cwd)

        # Split on first '--'
        set -l parts (string split -m 1 -- '--' $worktree)
        if test (count $parts) -lt 2
            echo "gwd: current directory name doesn't look like a worktree (<root>--<branch>): $worktree"
            return 1
        end

        set -l root $parts[1]
        set -l branch $parts[2]
        set -l repo_dir "../$root"

        # Extra guard: ensure repo_dir is a git repo
        git -C $repo_dir rev-parse --git-dir >/dev/null 2>&1; or begin
            echo "gwd: can't find main repo at $repo_dir"
            return 1
        end

        if not gum confirm "Remove worktree and branch? [$worktree]"
            return 0
        end

        # Remove *this* worktree by absolute path, from the main repo.
        cd $repo_dir
        git -C $repo_dir worktree remove $cwd --force; or return $status
        git -C $repo_dir branch -D $branch
    end

    function tiktoken-len --argument-names path
        set -l model gpt-5

        # If stdin is piped (not a TTY), read from stdin
        if not isatty stdin
            set -l tmp (mktemp -t tiktoken-len.XXXXXX)
            cat > "$tmp"
            tiktoken --model $model "$tmp" | wc -l | string trim
            rm -f "$tmp"
            return $status
        end

        # Otherwise, require a path argument
        if test -z "$path"
            echo "usage: tiktoken-len <file>  OR  echo 'text' | tiktoken-len" >&2
            return 2
        end

        if not test -f "$path"
            echo "tiktoken-len: not a file: $path" >&2
            return 1
        end

        tiktoken --model $model "$path" | wc -l | string trim
    end

end
