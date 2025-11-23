#!/usr/bin/env bash

# ---------------------------------------------
# Install command-line tools using Homebrew.
# ---------------------------------------------

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >> /Users/diego/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/diego/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

brew update
brew upgrade

# ---------------------------------------------
# Basics
# ---------------------------------------------
brew install coreutils # gnu utils
# brew install bash
brew install zsh
brew install git

# ---------------------------------------------
# For dotfiles symlinks
# ---------------------------------------------
brew install stow

# ---------------------------------------------
# Terminal/zsh
# ---------------------------------------------
# brew install --cask kitty
brew install zsh-autosuggestions
brew install zsh-syntax-highlighting
brew install powerlevel10k
brew install ripgrep
brew install fzf
brew install yazi
brew install lazygit
brew install fd
brew install zoxide
brew install tree

# NODEJS (yarn also required for some nvim plugins).
# Move global to have all permissions (eg. claude complaints otherwise)
# brew install node
# brew install yarn
# mkdir -p /Users/diego/.npm-global
# npm -g config set prefix /Users/diego/.npm-global

brew install node
curl -fsSL https://get.pnpm.io/install.sh | sh -
source ~/.zshrc
pnpm env use --global 22

# ---------------------------------------------
# Aerospace
# ---------------------------------------------
# brew install --cask nikitabobko/tap/aerospace
# brew install borders

# ---------------------------------------------
# Neovim
# ---------------------------------------------
brew install neovim
brew install luarocks
pnpm i -g jshint # for javascript linting in nvim
brew install tflint # terraform lint

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
# brew install yt-dlp # like youtube-dl
brew install qlstephen # quicklook files
brew install --cask jupyter-notebook-viewer
brew install jq # json tool! Also required for formatting in nvim
brew install parallel

# ---------------------------------------------
# AI
# ---------------------------------------------
brew install aichat
brew install opencode-ai/tap/opencode
# pnpm install -g @anthropic-ai/claude-code

# ---------------------------------------------
# Programming Languages and Frameworks, work
# ---------------------------------------------

# GCLOUD
brew install google-cloud-sdk

# PYTHON: uv
curl -LsSf https://astral.sh/uv/install.sh | sh
# jupytext working in neovim
uv tool install jupytext

# RUST
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# install proximity-sort: for fzf and ALT-T
cargo install proximity-sort

echo "👉 Install docker and colima"
brew install docker docker-credential-helper docker-buildx docker-completion docker-compose
brew install colima
brew install qemu

# OTHERS
brew install openssl
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
# Colima with docker
# ---------------------------------------------
mkdir -p ~/.docker/cli-plugins/
ln -sfn $HOMEBREW_PREFIX/opt/docker-compose/bin/docker-compose ~/.docker/cli-plugins/docker-compose
ln -sfn $(which docker-buildx) ~/.docker/cli-plugins/docker-buildx
docker buildx install

# --------------------------------------------- 
# MacOS settings
# https://macos-defaults.com/
# --------------------------------------------- 
defaults write com.apple.finder "FXPreferredViewStyle" -string "Nlsv"
defaults write com.apple.finder "FXRemoveOldTrashItems" -bool "true"
defaults write com.apple.finder "FXEnableExtensionChangeWarning" -bool "false"
defaults write NSGlobalDomain "AppleShowAllExtensions" -bool "true"
defaults write NSGlobalDomain "NSCloseAlwaysConfirmsChanges" -bool "false"
killall Finder

defaults write com.apple.AppleMultitouchTrackpad "FirstClickThreshold" -int "0"

defaults write com.apple.dock "expose-group-apps" -bool "true"
killall Dock

defaults write com.apple.Music "userWantsPlaybackNotifications" -bool "false"
killall Music

defaults write com.apple.LaunchServices "LSQuarantine" -bool "false"

# ---------------------------------------------
# Rectangle custom settings
# ---------------------------------------------
defaults write com.knollsoft.Rectangle almostMaximizeHeight -float 0.8
defaults write com.knollsoft.Rectangle almostMaximizeWidth -float 0.6
defaults write com.knollsoft.Rectangle sizeOffset -float 150
defaults write com.knollsoft.Rectangle applyGapsToMaximize -int 3

# ---------------------------------------------
# Manual actions
# ---------------------------------------------
echo "⚠️  Proceed with manual steps from README.md"
