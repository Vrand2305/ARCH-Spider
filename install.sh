#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/ARCH-Spider-backup-$STAMP"
mkdir -p "$BACKUP"

backup_path() {
  local p="$1"
  if [ -e "$HOME/$p" ]; then
    mkdir -p "$BACKUP/$(dirname "$p")"
    cp -a "$HOME/$p" "$BACKUP/$p"
  fi
}

while IFS= read -r -d '' item; do
  rel="${item#$ROOT/config/}"
  backup_path "$rel"
  mkdir -p "$HOME/$(dirname "$rel")"
  cp -a "$item" "$HOME/$rel"
done < <(find "$ROOT/config" -mindepth 1 -maxdepth 99 -print0)

while IFS= read -r -d '' item; do
  rel="${item#$ROOT/home/}"
  backup_path "$rel"
  mkdir -p "$HOME/$(dirname "$rel")"
  cp -a "$item" "$HOME/$rel"
done < <(find "$ROOT/home" -mindepth 1 -maxdepth 99 -print0 2>/dev/null || true)

# Repoint wallpaper references from the source home to the destination user.
if [ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
  sed -i "s#file:///home/bporras@confia.local/Descargas/1379597.jpg#file://${HOME}/.local/share/wallpapers/1379597.jpg#g" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
fi
if [ -f "$HOME/.config/plasmarc" ]; then
  sed -i "s#/home/bporras@confia.local/Descargas/1379597.jpg#${HOME}/.local/share/wallpapers/1379597.jpg#g" "$HOME/.config/plasmarc"
fi

if command -v yay >/dev/null 2>&1; then
  yay -S --needed - < "$ROOT/packages-pacman.txt" || true
  [ ! -s "$ROOT/packages-aur.txt" ] || yay -S --needed - < "$ROOT/packages-aur.txt" || true
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed - < "$ROOT/packages-pacman.txt" || true
fi

printf '\nConfiguración instalada. Copia de seguridad: %s\n' "$BACKUP"
printf 'Cierra sesión o reinicia Plasma para aplicar todos los cambios.\n'
