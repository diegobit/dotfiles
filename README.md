# My dotfiles

This repo contains the dotfiles for my system, plus a script to prepare a new MacOS device.

## Install
Install brew and packages:

```
chmod +x *.sh
./install.sh
```

## Setup dotfiles
checkout the dotfiles in yout $HOME directory

```
git clone git@github.com:diegobit/dotfiles.git
cd dotfiles
```

then use GNU stow to create symlinks

```
stow .
```

## Other personal settings
- Configure the username of .gitconfig

### gcloud
- login with ait, then cd into `.config/gcloud`, then copy `application_default_credentials.json` to ait.json
- repeat for logifuture
- activate one configuration with `gconf logi`

