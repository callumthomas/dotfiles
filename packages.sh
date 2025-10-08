#!/bin/bash
sudo pacman -S --noconfirm zsh git ghostty firefox nvim

prompt_confirm() {
  while true; do
    read -r -p "${1:-Proceed?} [y/n]: " REPLY
    case $REPLY in
    [yY])
      echo "Installing oh-my-zsh..."
      return 0
      ;;
    [nN])
      echo "Skipping."
      return 1
      ;;
    *) echo "Invalid input, please answer y or n." ;;
    esac
  done
}

if prompt_confirm "Install oh-my-zsh?"; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
