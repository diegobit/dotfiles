#!/usr/bin/env bash

# ---------------------------------------------
# Install command-line tools using Homebrew.
# ---------------------------------------------

if [ ! "$?" -eq 0 ] ; then
    echo "Homebrew not installed. Attempting to install Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ ! "$?" -eq 0 ] ; then
        echo "Something went wrong. Exiting..." && exit 1
    fi
fi

brew update
brew upgrade

# ---------------------------------------------
# Basics
# ---------------------------------------------
brew install coreutils # gnu utils
brew install bash
brew install zsh
brew install git

# ---------------------------------------------
# For dotfiles symlinks
# ---------------------------------------------
brew install stow

# ---------------------------------------------
# Terminal/zsh
# ---------------------------------------------
brew install --cask kitty
brew install zsh-autosuggestions
brew install zsh-syntax-highlighting
brew install romkatv/powerlevel10k/powerlevel10k
brew install ripgrep
brew install fzf
brew install yazi
broot --set-install-state installed
brew install lazygit
brew install fd
brew install zoxide

# cht.sh
curl -s https://cht.sh/:cht.sh | sudo tee /usr/local/bin/cht.sh && sudo chmod +x /usr/local/bin/cht.sh

# ---------------------------------------------
# Neovim
# ---------------------------------------------
brew install neovim
brew install luarocks
npm i -g jshint # for javascript linting in nvim

# ---------------------------------------------
# Fonts
# ---------------------------------------------
brew install --cask font-jetbrains-mono
brew install --cask font-fira-code
brew install --cask font-symbols-only-nerd-font # font for kitty

# ---------------------------------------------
# Tools
# ---------------------------------------------
brew install dust
brew install tmux
brew install htop
brew install php # for Alfred workflows
brew install yt-dlp # like youtube-dl
brew install qlstephen # quicklook files
brew install --cask jupyter-notebook-viewer
brew install jq # json tool! Also required for formatting in nvim

# ---------------------------------------------
# Programming Languages and Frameworks, work
# ---------------------------------------------

# GCLOUD
brew install google-cloud-sdk

# PYTHON: pyenv and pyright
# `pyenv local <env>` is not enough for pyright, it checks `$PYENV_VERSION`, which is
# only set by `pyenv activate` or `pyenv shell`. Otherwise pyright checks `pyrightconfig.json`,
# so with this plugin, we can do `pyenv pyright` to create the file in the root of the project.
brew install pyenv pyenv-virtualenv
git clone https://github.com/alefpereira/pyenv-pyright.git $(pyenv root)/plugins/pyenv-pyright
# requirements to build python with pyenv: https://github.com/pyenv/pyenv/wiki#suggested-build-environment
brew install openssl readline sqlite3 xz zlib tcl-tk

# NODEJS (yarn also required for some nvim plugins)
brew install node
brew install yarn

# RUST
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

echo "👉 Install docker and colima"
brew install docker docker-credential-helper docker-buildx docker-completion docker-compose
brew install colima

# OTHERS
brew install ngrok
# brew install terraform
# brew install jmeter
# brew install gcc

# JAVA
# brew install maven
# brew install jenv # probably avoid openjdk

# NOT SURE WIREGUARD IS NEEDED. Install app
# brew install wireguard-go
# brew install wireguard-tools

# ---------------------------------------------
# Remove outdated versions from the cellar
# ---------------------------------------------

brew cleanup

# ---------------------------------------------
# Global gitignore 
# ---------------------------------------------

echo "Adding things to global gitignore"
echo ".DS_Store" >> ~/.gitignore_global
echo "._.DS_Store" >> ~/.gitignore_global
echo "**/.DS_Store" >> ~/.gitignore_global
echo "**/._.DS_Store" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global

# ---------------------------------------------
# Initialize a few things
# ---------------------------------------------
echo "Making a Dev folder if it doesn't already exist"
mkdir -p "$HOME/Dev"
echo "Making it also inside Documents for clous synched ones"
mkdir -p "$HOME/Documents/Dev"
echo "Making a Playground folder"
mkdir -p "$HOME/Dev/plg"
echo "Link the iCloud Obsidian dir to the home dir"
ln -s "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Note" "$HOME/notes"

# ---------------------------------------------
# Manual actions
# ---------------------------------------------
echo "⚠️  Proceed with manual steps from README.md"
