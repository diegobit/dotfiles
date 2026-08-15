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

### Why colima is not stowed

Colima keeps its config *and* its state in the same directory, and that state
grows to tens of GB (`_lima/`, disk images, the container `datadisk`). So
`~/.config/colima` is a **real directory that must stay outside this repo** —
only the per-profile `colima.yaml` is versioned here and symlinked into it:

```
~/.config/colima/                      real dir, VM state, never in git
├── _lima/, _store/, ssh_config
├── default/colima.yaml  ─┐
└── amd64/colima.yaml    ─┴─→ ~/dotfiles/.config/colima/<profile>/colima.yaml
```

`.config/colima` is therefore in `.stow-local-ignore`: on a machine where
`~/.config/colima` does not exist yet, `stow .` would fold the whole directory
into one symlink pointing here, and colima would fill the working tree. The
links are created by `install.sh` instead.

`~/.config/colima` is also colima's own default when `COLIMA_HOME` is unset, so
non-fish shells (`$SHELL` is zsh) resolve to the same VMs. Never create
`~/.colima` — it silently takes precedence over everything above.
