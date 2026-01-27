# dotfiles

This repo contains my dotfiles plus a script to configure a new MacOS device.

Favourite heavily configured tools:

| ghostty | fish+tide | neovim | karabiner elements | opencode | aichat |
|---|---|---|---|---|---|

Cool low configuration ones:

| fzf | try | yazi | ripgrep | zoxide | lazygit | uv | colima |
|---|---|---|---|---|---|---|---|


# How to get specific dotfiles

Eg. you want to get my nvim configuration:

```
cd ~
git clone git@github.com:diegobit/dotfiles.git
cd dotfiles/
stow .config/nvim
```

# Everything from scratch

## Install

### Install brew and packages:

Customize the packages in `install.sh` and the personal paths at the end of the file:
```
git clone git@github.com:diegobit/dotfiles.git
cd dotfiles
./install.sh
```

## Setup dotfiles
Use [GNU stow](https://www.gnu.org/software/stow/) to create symlinks. For an explanation on this dotfiles management, see [this video](https://youtu.be/y6XCebnB9gs?si=PVgjVFBUp82NuZwH).

```
cd dotfiles
stow .
```

## Setup nvim

### Inside nvim
- open nvim to let it install plugins
- `:Mason` to check lsp servers, install what you need

### Check
- You can check health with `:checkhealth`

## If needs to run fish config:

`tide configure`

Left prompt:

```
set -U tide_left_prompt_items pwd git newline character
```

Right prompt (minimal and complete):

```
set -U tide_right_prompt_items status cmd_duration context jobs python shlvl
set -U tide_right_prompt_items status cmd_duration context jobs direnv node python rustc java php ruby go gcloud kubectl terraform shlvl
```

## Install VSCode extensions

Install VSCode, then:

```
./install_vscode_extensions.sh
```

## Colima and docker

After everything, run:
`sudo ln -sf /Users/diego/.config/colima/default/docker.sock /var/run/docker.sock`
