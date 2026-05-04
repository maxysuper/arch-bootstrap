#!/usr/bin/env bash

set -u

PACMAN_PACKAGES=(
  base-devel
  git
  curl
  wget
  neovim
  rsync
  openssh
  alacritty
  yazi
  btop
  fastfetch
  eza
  dust
  bluetui
  wiremix
  impala
  satty
  zoxide
  traceroute
  bind
  nmap
  iputils
  ripgrep
  fd
  fzf
  unzip
  npm
  tree-sitter-cli
  github-cli
  lazygit
  flatpak
)

AUR_PACKAGES=(
  yandex-disk
  localsend
  spotify
  onlyoffice-bin
  mattermost-desktop
  anydesk-bin
  portproton
  discord
  yandex-browser
  vk-messenger-bin
  keepassxc
  chitubox-free-bin
)

PROBLEM_AUR_PACKAGES=(
  timeshift
  vmware-workstation
)

FLATPAK_APPS=(
  org.telegram.desktop
  md.obsidian.Obsidian
  org.qbittorrent.qBittorrent
  org.videolan.VLC
  com.obsproject.Studio
  org.remmina.Remmina
  com.valvesoftware.Steam
)

log() {
  echo
  echo "==> $1"
}

pkg_installed() {
  pacman -Q "$1" &>/dev/null
}

safe_pacman_install() {
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      echo "pacman: $pkg уже установлен"
      continue
    fi

    echo "pacman: установка $pkg"
    sudo pacman -S --needed --noconfirm "$pkg" || {
      echo "WARN: не удалось установить $pkg, пропускаю"
    }
  done
}

safe_yay_install() {
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      echo "yay: $pkg уже установлен"
      continue
    fi

    echo "yay: установка $pkg"
    yay -S --needed --noconfirm "$pkg" || {
      echo "WARN: не удалось установить $pkg, пропускаю"
    }
  done
}

update_system() {
  log "Updating system"
  sudo pacman -Syu --noconfirm || {
    echo "WARN: обновление системы завершилось с ошибкой, продолжаю"
  }
}

install_pacman_packages() {
  log "Installing pacman packages"
  safe_pacman_install "${PACMAN_PACKAGES[@]}"
}

install_yay() {
  log "Installing yay"

  if command -v yay &>/dev/null; then
    echo "yay уже установлен"
    return
  fi

  safe_pacman_install base-devel git

  rm -rf /tmp/yay
  git clone https://aur.archlinux.org/yay.git /tmp/yay || {
    echo "ERROR: не удалось скачать yay"
    return
  }

  (
    cd /tmp/yay
    makepkg -si --noconfirm
  ) || {
    echo "ERROR: не удалось установить yay"
    return
  }

  rm -rf /tmp/yay
}

install_aur_packages() {
  log "Installing AUR packages"

  if ! command -v yay &>/dev/null; then
    echo "WARN: yay не найден, пропускаю AUR"
    return
  fi

  safe_yay_install "${AUR_PACKAGES[@]}"
}

install_problem_packages() {
  log "Installing problem packages separately"

  if ! command -v yay &>/dev/null; then
    echo "WARN: yay не найден, пропускаю problem packages"
    return
  fi

  safe_yay_install timeshift

  echo
  echo "==> Installing VMware separately"
  if pkg_installed vmware-workstation; then
    echo "vmware-workstation уже установлен"
  else
    yay -S --needed --noconfirm vmware-workstation || {
      echo "WARN: vmware-workstation не установился, пропускаю"
    }
  fi

  sudo systemctl enable --now vmware-networks.service 2>/dev/null || true
  sudo systemctl enable --now vmware-usbarbitrator.service 2>/dev/null || true
}

install_flatpak_apps() {
  log "Installing Flatpak apps"

  if ! command -v flatpak &>/dev/null; then
    echo "WARN: flatpak не найден"
    return
  fi

  flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo || true

  for app in "${FLATPAK_APPS[@]}"; do
    echo "flatpak: установка $app"
    flatpak install -y flathub "$app" || {
      echo "WARN: не удалось установить $app, пропускаю"
    }
  done
}

yandex_disk_is_configured() {
  systemctl --user is-active --quiet yandex-disk.service && return 0
  pgrep -x yandex-disk &>/dev/null && return 0
  [ -f "$HOME/.config/yandex-disk/config.cfg" ] && return 0
  return 1
}

setup_yandex_disk() {
  log "Setting up Yandex Disk"

  if ! command -v yandex-disk &>/dev/null; then
    echo "yandex-disk не установлен, пропускаю"
    return
  fi

  if yandex_disk_is_configured; then
    echo "Yandex Disk уже настроен или демон запущен, пропускаю setup"
    return
  fi

  mkdir -p "$HOME/Yandex.Disk"

  echo "Открою страницу авторизации: https://ya.ru/device"

  if command -v yandex-browser &>/dev/null; then
    nohup yandex-browser "https://ya.ru/device" >/dev/null 2>&1 &
  else
    echo "Yandex Browser не найден. Открой вручную: https://ya.ru/device"
  fi

  echo
  echo "Дальше запустится интерактивный yandex-disk setup."
  echo "Для стандартного пути используй: $HOME/Yandex.Disk"
  echo

  yandex-disk setup || {
    echo "WARN: yandex-disk setup завершился с ошибкой или был прерван"
    return
  }

  systemctl --user enable --now yandex-disk.service || true
}

setup_ssh_symlink() {
  log "Linking ~/.ssh from Yandex Disk"

  SRC="$HOME/Yandex.Disk/backup/.ssh"
  DST="$HOME/.ssh"

  if [ ! -d "$SRC" ]; then
    echo "Источник не найден: $SRC"
    echo "Дождись синхронизации Yandex Disk и запусти скрипт повторно"
    return
  fi

  if [ -e "$DST" ] && [ ! -L "$DST" ]; then
    BACKUP="$DST.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Найдена существующая ~/.ssh, делаю бэкап: $BACKUP"
    mv "$DST" "$BACKUP"
  fi

  if [ -L "$DST" ]; then
    echo "Симлинк ~/.ssh уже существует"
  else
    ln -s "$SRC" "$DST"
    echo "Создан симлинк: $DST -> $SRC"
  fi

  chmod 700 "$SRC" || true
  find "$SRC" -type f -exec chmod 600 {} \; || true
}

setup_bashrc_aliases() {
  log "Updating ~/.bashrc aliases"

  BASHRC="$HOME/.bashrc"
  touch "$BASHRC"

  if grep -q "CUSTOM ALIASES (AUTO)" "$BASHRC"; then
    echo "Aliases уже есть, пропускаю"
    return
  fi

  cat >>"$BASHRC" <<'EOF'

# ===== CUSTOM ALIASES (AUTO) =====

# File system
if command -v eza &> /dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

if command -v zoxide &> /dev/null; then
  eval "$(zoxide init bash)"

  alias cd="zd"
  zd() {
    if (( $# == 0 )); then
      builtin cd ~ || return
    elif [[ -d $1 ]]; then
      builtin cd "$1" || return
    else
      if ! z "$@"; then
        echo "Error: Directory not found"
        return 1
      fi

      printf "\U000F17A9 "
      pwd
    fi
  }
fi

open() (
  xdg-open "$@" >/dev/null 2>&1 &
)

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ===== END CUSTOM ALIASES =====
EOF

  echo "Aliases добавлены"
}

setup_lazyvim() {
  log "Setting up LazyVim"

  NVIM_CONFIG="$HOME/.config/nvim"

  if [ -d "$NVIM_CONFIG" ] && [ ! -L "$NVIM_CONFIG" ]; then
    BACKUP="$NVIM_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Найден существующий nvim config, делаю бэкап: $BACKUP"
    mv "$NVIM_CONFIG" "$BACKUP"
  fi

  if [ ! -d "$NVIM_CONFIG" ]; then
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG" || {
      echo "WARN: не удалось скачать LazyVim"
      return
    }

    rm -rf "$NVIM_CONFIG/.git"
    echo "LazyVim установлен"
  else
    echo "nvim config уже существует, пропускаю"
  fi
}

setup_git() {
  log "Setting up Git"

  git config --global init.defaultBranch main
  git config --global pull.rebase false

  if ! git config --global user.name &>/dev/null; then
    read -rp "Git user.name: " GIT_NAME
    [ -n "$GIT_NAME" ] && git config --global user.name "$GIT_NAME"
  fi

  if ! git config --global user.email &>/dev/null; then
    read -rp "Git user.email: " GIT_EMAIL
    [ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
  fi

  echo
  echo "Для авторизации GitHub:"
  echo "  gh auth login"
  echo
  echo "Для работы с репой:"
  echo "  git clone git@github.com:maxysuper/arch-bootstrap.git"
  echo "  cd arch-bootstrap"
  echo "  lazygit"
}

cleanup_flatpak() {
  log "Cleaning unused Flatpak runtimes"
  flatpak uninstall --unused -y || true
}

main() {
  update_system
  install_pacman_packages
  install_yay
  install_aur_packages
  install_problem_packages
  install_flatpak_apps
  setup_yandex_disk
  setup_ssh_symlink
  setup_bashrc_aliases
  setup_lazyvim
  setup_git
  cleanup_flatpak

  log "Done"
}

main "$@"
