#!/bin/bash
sudo pacman -S --noconfirm \
        zsh \
        git \
        ghostty \
        firefox \
        nvim \
        hyprlock \
        less \
        wl-clipboard \
        tmux \
        waybar \
        hyprpaper \
        ttf-font-awesome \
        otf-font-awesome \
        thunar \
        ripgrep

sudo pacman -Rns dolphin kitty

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

if prompt_confirm "Install lazyvim?"; then
  git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

if prompt_confirm "Install oh-my-zsh?"; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si

yay -S hyprcap
