#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating system..."
sudo pacman -Syu --noconfirm

echo "==> Installing base packages..."
sudo pacman -S --needed --noconfirm \
base-devel git curl wget neovim rsync openssh \
alacritty yazi btop fastfetch eza dust \
bluetui wiremix impala satty zoxide \
traceroute bind nmap iputils

echo "==> Installing yay..."
if ! command -v yay &>/dev/null; then
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay
makepkg -si --noconfirm
cd ~
rm -rf /tmp/yay
fi

echo "==> Installing AUR packages..."
yay -S --noconfirm \
yandex-disk \
localsend \
spotify \
onlyoffice-bin \
mattermost-desktop \
anydesk-bin \
vmware-workstation \
portproton \
discord \
yandex-browser \
vk-messenger-bin \
keepassxc \
steam \
chitubox-free-bin

echo "==> Installing Flatpak..."
sudo pacman -S --needed --noconfirm flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "==> Installing Flatpak apps..."
flatpak install -y flathub \
org.telegram.desktop \
md.obsidian.Obsidian \
org.qbittorrent.qBittorrent \
org.videolan.VLC \
com.obsproject.Studio \
org.remmina.Remmina

echo "==> Enabling services..."
sudo systemctl enable bluetooth || true

echo "==> Setting up Yandex Disk..."

if command -v yandex-disk &>/dev/null; then
mkdir -p "$HOME/Yandex.Disk"

echo
echo "Открою страницу авторизации ya.ru/device в Yandex Browser."
echo "После входа вернись в терминал и продолжи настройку yandex-disk."
echo

if command -v yandex-browser &>/dev/null; then
nohup yandex-browser "https://ya.ru/device" >/dev/null 2>&1 &
elif command -v yandex-browser-stable &>/dev/null; then
nohup yandex-browser-stable "https://ya.ru/device" >/dev/null 2>&1 &
else
echo "Yandex Browser не найден. Открой вручную: https://ya.ru/device"
fi

yandex-disk setup

systemctl --user enable --now yandex-disk.service || true

echo "Yandex Disk настроен."
else
echo "yandex-disk не установлен, пропускаю настройку."
fi

echo "Синхронизация Yandex Disk"
yandex-disk sync

echo "==> Linking ~/.ssh from Yandex Disk..."

SRC="$HOME/Yandex.Disk/backup/.ssh"
DST="$HOME/.ssh"

if [ -d "$SRC" ]; then
if [ -e "$DST" ] && [ ! -L "$DST" ]; then
echo "Найдена существующая ~/.ssh, делаю бэкап → ~/.ssh.backup"
mv "$DST" "$DST.backup"
fi

if [ -L "$DST" ]; then
echo "Симлинк уже существует, пропускаю"
else
ln -s "$SRC" "$DST"
echo "Симлинк создан: $DST -> $SRC"
fi

chmod 700 "$SRC" || true
else
echo "Источник $SRC не найден (ещё не синхронизировался?)"
fi

echo "==> Updating ~/.bashrc aliases..."

BASHRC="$HOME/.bashrc"

BLOCK=$(cat <<'EOF'

# ===== CUSTOM ALIASES (AUTO) =====

# File system
if command -v eza &> /dev/null; then
alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'
fi

if command -v zoxide &> /dev/null; then
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
)

# Проверяем, добавляли ли уже
if ! grep -q "CUSTOM ALIASES (AUTO)" "$BASHRC"; then
echo "$BLOCK" >> "$BASHRC"
echo "Aliases добавлены в ~/.bashrc"
else
echo "Aliases уже есть в ~/.bashrc, пропускаю"
fi

echo "==> Done!"
