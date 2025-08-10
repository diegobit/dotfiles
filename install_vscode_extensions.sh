#!/bin/bash

echo "👉 Installing VSCode extensions. Location: '$HOME/.vscode/extensions'"

# Visual Studio Code :: Package list
pkglist=(
andrewdircks.google-cloud-platform-ssh
charliermarsh.ruff
christian-kohler.path-intellisense
codezombiech.gitignore
cwan.native-ascii-converter
donjayamanne.githistory
donjayamanne.python-environment-manager
eriklynd.json-tools
github.vscode-github-actions
mechatroner.rainbow-csv
mhutchie.git-graph
miguelsolorio.fluent-icons
miguelsolorio.symbols
mikestead.dotenv
mitchdenny.ecdc
mk12.better-git-line-blame
ms-python.debugpy
ms-python.python
ms-toolsai.jupyter
ms-toolsai.jupyter-keymap
ms-toolsai.jupyter-renderers
ms-vscode-remote.remote-ssh
ms-vscode.remote-explorer
pkief.material-icon-theme
rangav.vscode-thunder-client
redhat.vscode-yaml
ryu1kn.partial-diff
sleistner.vscode-fileutils
sysoev.vscode-open-in-github
tomoki1207.pdf
vscodevim.vim
)

for i in ${pkglist[@]}; do
  code --install-extension $i
done
