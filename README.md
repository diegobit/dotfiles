# My dotfiles

This repo contains the dotfiles for my system, plus a script to prepare a new MacOS device.

## 1. Install

### 1.1 Install brew and packages:

Customize the packages in `install.sh` and the personal paths at the end of the file:
```
./install.sh
```

### 1.2 To complete Colima and Docker
To complete DOCKER-COMPOSE install with colima:

```
ln -sfn $HOMEBREW_PREFIX/opt/docker-compose/bin/docker-compose ~/.docker/cli-plugins/docker-compose"
```

DOCKER BUILDX might still not work. Run the following, or in alternative, check online

```
mkdir -p ~/.docker/cli-plugins
ln -sfn $(which docker-buildx) ~/.docker/cli-plugins/docker-buildx
```

To keep using the `docker build` install but with buildkit:
https://docs.docker.com/engine/reference/commandline/buildx_install/"

```
docker buildx install
```

### 1.3 To add navi repositories

```
navi browse
```

### 1.4 Install Nerd Font for terminal and neovim

- Install either the one from powerlevel:
  https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k
- Better: install a Nerd Font: https://www.nerdfonts.com/font-downloads
  Current choice is JetBrainsMono NerdFont

## 2. Setup dotfiles
checkout the dotfiles in yout $HOME directory

```
git clone git@github.com:diegobit/dotfiles.git
cd dotfiles
```

then use GNU stow to create symlinks. For an explanation on this dotfiles management, see:
https://youtu.be/y6XCebnB9gs?si=PVgjVFBUp82NuZwH

```
stow .
```

## 3. Setup nvim

### 3.1 Python
- (After setting up pyenv and python versions) create a venv for nvim: `pyenv virtualenv pynvim`
- (now the `vim.g.python3_host_prog = "..."` in the config works)

### 3.2 Inside nvim
- open nvim to let it install plugins
- `:Mason` to check lsp servers, install what you need

## 4. Install VSCode extensions

Install VSCode, then:

```
./install_vscode_extensions.sh
```

## 5. gcloud with multiple accounts
- login with `<account_one>`, then cd into `.config/gcloud`, then copy `application_default_credentials.json` to `<account_one>.json`
- repeat for `<account_two>`
- activate one configuration with `gconf logi`

## 6. Notes
The most configured apps are (in order):
- zsh (.zshrc)
- karabiner elements (.config/karabiner)
- neovim (.config/nvim), which is customized from kickstart.vim settings
- vscode settings

