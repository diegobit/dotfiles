# dotfiles

This repo contains my dotfiles plus a script to configure a new MacOS device.

## Install

### Install brew and packages:

Customize the packages in `install.sh` and the personal paths at the end of the file:
```
git clone git@github.com:diegobit/dotfiles.git
cd dotfiles
./install.sh
```
### Install Nerd Font for terminal and neovim

- https://www.nerdfonts.com/font-downloads

My current font is JetBrainsMono NerdFont. For sure install the symbols only

## Setup dotfiles
Use [GNU stow](https://www.gnu.org/software/stow/) to create symlinks. For an explanation on this dotfiles management, see [this video](https://youtu.be/y6XCebnB9gs?si=PVgjVFBUp82NuZwH).

```
stow .
```

## Setup nvim

### Inside nvim
- open nvim to let it install plugins
- `:Mason` to check lsp servers, install what you need

### Check
- You can check health with `:checkhealth`

## Install VSCode extensions

Install VSCode, then:

```
./install_vscode_extensions.sh
```

## Notes
The most configured apps are (in order):
- zsh (.zshrc)
- karabiner elements (.config/karabiner)
- neovim (.config/nvim), which is customized from kickstart.vim settings
- ghostty

Customized, but older and not maintained anymore:
- kitty
- aerospace

