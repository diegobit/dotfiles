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

- Install either the one from powerlevel: https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k
- or - better - install a Nerd Font: https://www.nerdfonts.com/font-downloads

  My current font is JetBrainsMono NerdFont

## 2. Setup dotfiles
checkout the dotfiles in yout $HOME directory

```
git clone git@github.com:diegobit/dotfiles.git
cd dotfiles
```

then use [GNU stow](https://www.gnu.org/software/stow/) to create symlinks. For an explanation on this dotfiles management, see [this video](https://youtu.be/y6XCebnB9gs?si=PVgjVFBUp82NuZwH).

```
stow .
```

## 3. Setup nvim

### 3.1 Python
- Install ruff on global python version (used by nvim and vscode, not sure):
  - `pyenv global XXX`
  - `pip install ruff`
- set up pynvim (for nvim plugins):
  - `pyenv virtualenv pynvim`
  - `pip install pynvim`
  - (now the `vim.g.python3_host_prog = "..."` in the config works)

### 3.2 Inside nvim
- open nvim to let it install plugins
- `:Mason` to check lsp servers, install what you need

### 3.3 Check
- You can check health with `:checkhealth`

## 4. Install VSCode extensions

Install VSCode, then:

```
./install_vscode_extensions.sh
```

## 5. Notes
The most configured apps are (in order):
- zsh (.zshrc)
- karabiner elements (.config/karabiner)
- neovim (.config/nvim), which is customized from kickstart.vim settings
- vscode settings

