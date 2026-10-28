#!/usr/bin/env bash
# Install optional system dependencies used by art-eval.
# Idempotent: already-installed tools are skipped.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash <skill>/scripts/install-deps.sh [ffmpeg] [yt-dlp]

Examples:
  bash <skill>/scripts/install-deps.sh
  bash <skill>/scripts/install-deps.sh ffmpeg
  bash <skill>/scripts/install-deps.sh yt-dlp

Supported installers:
  macOS:  Homebrew
  Linux:  apt-get, dnf, yum, pacman, zypper, apk
  Python: pipx or pip, as fallback for yt-dlp
  Windows: winget, when available from the current shell
USAGE
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_ffmpeg=0
need_ytdlp=0

if [ "$#" -eq 0 ]; then
  need_ffmpeg=1
  need_ytdlp=1
else
  while [ "$#" -gt 0 ]; do
    case "$1" in
      ffmpeg) need_ffmpeg=1; shift ;;
      yt-dlp|ytdlp) need_ytdlp=1; shift ;;
      --help|-h) usage; exit 0 ;;
      *) echo "ERROR: unknown dependency: $1" >&2; usage >&2; exit 2 ;;
    esac
  done
fi

missing=()
if [ "$need_ffmpeg" -eq 1 ] && ! has_cmd ffmpeg; then
  missing+=("ffmpeg")
fi
if [ "$need_ytdlp" -eq 1 ] && ! has_cmd yt-dlp; then
  missing+=("yt-dlp")
fi

if [ "${#missing[@]}" -eq 0 ]; then
  echo "art-eval dependencies are already installed."
  exit 0
fi

echo "Installing missing art-eval dependencies: ${missing[*]}"

install_with_brew() {
  has_cmd brew || return 1
  pkgs=()
  for dep in "${missing[@]}"; do
    pkgs+=("$dep")
  done
  brew install "${pkgs[@]}"
}

install_with_apt() {
  has_cmd apt-get || return 1
  pkgs=()
  for dep in "${missing[@]}"; do
    case "$dep" in
      ffmpeg) pkgs+=("ffmpeg") ;;
      yt-dlp) pkgs+=("yt-dlp") ;;
    esac
  done
  if [ "$(id -u)" -eq 0 ]; then
    apt-get update
    apt-get install -y "${pkgs[@]}"
  else
    sudo apt-get update
    sudo apt-get install -y "${pkgs[@]}"
  fi
}

install_with_dnf() {
  has_cmd dnf || return 1
  pkgs=()
  for dep in "${missing[@]}"; do
    pkgs+=("$dep")
  done
  if [ "$(id -u)" -eq 0 ]; then
    dnf install -y "${pkgs[@]}"
  else
    sudo dnf install -y "${pkgs[@]}"
  fi
}

install_with_yum() {
  has_cmd yum || return 1
  pkgs=()
  for dep in "${missing[@]}"; do
    pkgs+=("$dep")
  done
  if [ "$(id -u)" -eq 0 ]; then
    yum install -y "${pkgs[@]}"
  else
    sudo yum install -y "${pkgs[@]}"
  fi
}

install_with_pacman() {
  has_cmd pacman || return 1
  pkgs=()
  for dep in "${missing[@]}"; do
    pkgs+=("$dep")
  done
  if [ "$(id -u)" -eq 0 ]; then
    pacman -Sy --needed --noconfirm "${pkgs[@]}"
  else
    sudo pacman -Sy --needed --noconfirm "${pkgs[@]}"
  fi
}

install_with_zypper() {
  has_cmd zypper || return 1
  pkgs=()
  for dep in "${missing[@]}"; do
    pkgs+=("$dep")
  done
  if [ "$(id -u)" -eq 0 ]; then
    zypper --non-interactive install "${pkgs[@]}"
  else
    sudo zypper --non-interactive install "${pkgs[@]}"
  fi
}

install_with_apk() {
  has_cmd apk || return 1
  pkgs=()
  for dep in "${missing[@]}"; do
    pkgs+=("$dep")
  done
  if [ "$(id -u)" -eq 0 ]; then
    apk add --no-cache "${pkgs[@]}"
  else
    sudo apk add --no-cache "${pkgs[@]}"
  fi
}

install_with_winget() {
  has_cmd winget || return 1
  for dep in "${missing[@]}"; do
    case "$dep" in
      ffmpeg) winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements ;;
      yt-dlp) winget install --id yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements ;;
    esac
  done
}

install_ytdlp_python_fallback() {
  [ "$need_ytdlp" -eq 1 ] || return 1
  has_cmd yt-dlp && return 0
  if has_cmd pipx; then
    pipx install yt-dlp
    return 0
  fi
  if has_cmd python3; then
    python3 -m pip install --user --upgrade yt-dlp
    return 0
  fi
  return 1
}

if install_with_brew ||
   install_with_apt ||
   install_with_dnf ||
   install_with_yum ||
   install_with_pacman ||
   install_with_zypper ||
   install_with_apk ||
   install_with_winget; then
  :
else
  # yt-dlp can still be installed without a system package manager.
  if [ "${#missing[@]}" -eq 1 ] && [ "${missing[0]}" = "yt-dlp" ]; then
    install_ytdlp_python_fallback || {
      echo "ERROR: no supported installer found for yt-dlp." >&2
      exit 1
    }
  else
    cat >&2 <<'ERR'
ERROR: no supported installer found.
Install dependencies manually, then retry:
  macOS:  brew install ffmpeg yt-dlp
  Ubuntu: sudo apt-get update && sudo apt-get install -y ffmpeg yt-dlp
  Fedora: sudo dnf install -y ffmpeg yt-dlp
  Arch:   sudo pacman -Sy --needed ffmpeg yt-dlp
  Windows: winget install Gyan.FFmpeg && winget install yt-dlp.yt-dlp
ERR
    exit 1
  fi
fi

missing_after=()
[ "$need_ffmpeg" -eq 1 ] && ! has_cmd ffmpeg && missing_after+=("ffmpeg")
[ "$need_ytdlp" -eq 1 ] && ! has_cmd yt-dlp && missing_after+=("yt-dlp")

if [ "${#missing_after[@]}" -gt 0 ]; then
  echo "ERROR: install completed but still missing: ${missing_after[*]}" >&2
  echo "If a tool was installed into a user-local bin directory, restart the shell or update PATH." >&2
  exit 1
fi

echo "Installed art-eval dependencies successfully."
