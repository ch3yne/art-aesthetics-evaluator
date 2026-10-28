#!/usr/bin/env bash
# Prepare media assets for art-aesthetics evaluation in one command.
# It scans/accepts up to 4 videos, copies/downloads them, extracts frames,
# waveform/spectrogram images, and writes a manifest for the evaluator.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  bash <skill>/scripts/prepare.sh [--install-deps] [--batch DIR] [--out DIR] [--report] [--shared-prompt TEXT] [VIDEO_OR_URL ...]

Modes:
  --batch DIR      Scan a works batch directory for videos and prompt files.
  VIDEO_OR_URL     Explicit local files, direct media URLs, or page URLs.

Outputs:
  <out>/manifest.tsv
  <out>/<vN>/input.mp4
  <out>/<vN>/<vN>_frame_001.png ...
  <out>/<vN>/<vN>_waveform.png and <vN>_spectrogram.png when audio exists

Defaults:
  In batch mode, output goes to <batch>/eval-work.
  In explicit mode, output goes to ./eval-work unless --out is provided.
  Missing ffmpeg/ffprobe or yt-dlp can be installed with --install-deps.
USAGE
}

strip_file_scheme() {
  case "$1" in
    file://*) printf '%s\n' "${1#file://}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

url_without_query() {
  local value="$1"
  value="${value%%\#*}"
  value="${value%%\?*}"
  printf '%s\n' "$value"
}

is_direct_media_url() {
  local clean
  clean="$(url_without_query "$1")"
  case "$clean" in
    *.mp4|*.MP4|*.mov|*.MOV|*.m4v|*.M4V|*.webm|*.WEBM) return 0 ;;
    *) return 1 ;;
  esac
}

basename_no_ext() {
  local name
  name="$(basename "$1")"
  printf '%s\n' "${name%.*}"
}

find_prompt_for() {
  local video="$1" dir="$2" base
  base="$(basename_no_ext "$video")"
  for p in "$dir/$base-prompt.txt" "$dir/$base.prompt.txt" "$dir/$base.txt"; do
    [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

install_deps() {
  if [ ! -f "$SKILL_DIR/scripts/install-deps.sh" ]; then
    echo "ERROR: install-deps.sh not found next to prepare.sh" >&2
    return 1
  fi
  bash "$SKILL_DIR/scripts/install-deps.sh" "$@"
}

has_page_url() {
  local src clean
  for src in "$@"; do
    clean="$(strip_file_scheme "$src")"
    case "$clean" in
      http://*|https://*)
        is_direct_media_url "$clean" || return 0
        ;;
    esac
  done
  return 1
}

ensure_required_deps() {
  local auto_install="$1"; shift
  local missing=()
  local needs_ytdlp=0

  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    missing+=("ffmpeg")
  fi
  if has_page_url "$@"; then
    needs_ytdlp=1
    if ! command -v yt-dlp >/dev/null 2>&1; then
      missing+=("yt-dlp")
    fi
  fi

  if [ "${#missing[@]}" -eq 0 ]; then
    return 0
  fi

  if [ "$auto_install" = "yes" ]; then
    install_deps "${missing[@]}"
    return 0
  fi

  echo "ERROR: missing required art-eval dependencies: ${missing[*]}" >&2
  echo "Run one of these commands, then retry:" >&2
  echo "  bash \"$SKILL_DIR/scripts/install-deps.sh\" ${missing[*]}" >&2
  echo "  bash \"$SKILL_DIR/scripts/prepare.sh\" --install-deps ..." >&2
  if [ "$needs_ytdlp" -eq 1 ]; then
    echo "yt-dlp is only required here because at least one input looks like a video page URL." >&2
  fi
  exit 1
}

download_or_copy_video() {
  local src="$1" dest_dir="$2" dest media
  dest="$dest_dir/input.mp4"
  src="$(strip_file_scheme "$src")"

  if [ -f "$src" ]; then
    cp "$src" "$dest"
    return 0
  fi

  if is_direct_media_url "$src"; then
      case "$src" in
        http://*|https://*)
          curl -L -f --max-time 120 --max-filesize 524288000 -o "$dest" "$src"
          ;;
        *)
          echo "ERROR: source is not a readable file: $src" >&2
          return 1
          ;;
      esac
      return 0
  fi

  case "$src" in
    *.mp4|*.MP4|*.mov|*.MOV|*.m4v|*.M4V|*.webm|*.WEBM)
      curl -L -f --max-time 120 --max-filesize 524288000 -o "$dest" "$src"
      ;;
    http://*|https://*)
      if ! command -v yt-dlp >/dev/null 2>&1; then
        echo "ERROR: page URL requires yt-dlp, or provide a direct media URL/local file: $src" >&2
        return 1
      fi
      yt-dlp \
        --no-playlist \
        --write-info-json \
        --write-thumbnail \
        --write-sub \
        --write-auto-sub \
        --sub-langs "zh.*,en.*" \
        --merge-output-format mp4 \
        -o "$dest_dir/source.%(ext)s" \
        "$src"
      media="$(find "$dest_dir" -maxdepth 1 -type f \( -iname 'source.mp4' -o -iname 'source.mkv' -o -iname 'source.webm' -o -iname 'source.mov' -o -iname 'source.m4v' \) | head -n 1)"
      if [ -z "$media" ]; then
        echo "ERROR: yt-dlp did not produce a recognized media file for $src" >&2
        return 1
      fi
      if [ "$media" = "$dest_dir/source.mp4" ]; then
        cp "$media" "$dest"
      else
        ffmpeg -y -i "$media" -c copy "$dest"
      fi
      ;;
    *)
      echo "ERROR: source is not a readable file or supported URL: $src" >&2
      return 1
      ;;
  esac
}

extract_assets() {
  local d="$1" v="$2" dur fps
  dur="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$d/input.mp4")"
  printf '%s\n' "$dur" > "$d/duration.txt"

  # Keep frame count bounded. For short clips fps=1 produces up to 16 frames;
  # for longer clips sample 16 buckets across the whole duration.
  if awk "BEGIN{exit !($dur > 20)}"; then
    fps="$(awk "BEGIN{printf \"%.4f\", 16/$dur}")"
    ffmpeg -y -i "$d/input.mp4" -vf "fps=$fps,scale=640:-1" -frames:v 16 "$d/${v}_frame_%03d.png" >/dev/null 2>&1
  else
    ffmpeg -y -i "$d/input.mp4" -vf "fps=1,scale=640:-1" -frames:v 16 "$d/${v}_frame_%03d.png" >/dev/null 2>&1
  fi

  if ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$d/input.mp4" | grep -q .; then
    ffmpeg -y -i "$d/input.mp4" -filter_complex "showwavespic=s=1000x300" -frames:v 1 "$d/${v}_waveform.png" >/dev/null 2>&1
    ffmpeg -y -i "$d/input.mp4" -lavfi showspectrumpic=s=1000x400 -frames:v 1 "$d/${v}_spectrogram.png" >/dev/null 2>&1
    printf 'yes\n' > "$d/has_audio.txt"
  else
    printf 'no\n' > "$d/has_audio.txt"
  fi
}

batch_dir=""
out_dir=""
shared_prompt=""
report="no"
install_deps_flag="no"
declare -a sources=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --batch) batch_dir="${2:?missing --batch value}"; shift 2 ;;
    --out) out_dir="${2:?missing --out value}"; shift 2 ;;
    --shared-prompt) shared_prompt="${2:?missing --shared-prompt value}"; shift 2 ;;
    --report) report="yes"; shift ;;
    --install-deps) install_deps_flag="yes"; shift ;;
    --) shift; break ;;
    *) sources+=("$1"); shift ;;
  esac
done

if [ -n "$batch_dir" ]; then
  [ -d "$batch_dir" ] || { echo "ERROR: batch dir not found: $batch_dir" >&2; exit 1; }
  if [ "${#sources[@]}" -eq 0 ]; then
    while IFS= read -r item; do
      sources+=("$item")
    done < <(find "$batch_dir" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.webm' \) | sort)
  fi
  [ -z "$out_dir" ] && out_dir="$batch_dir/eval-work"
else
  [ -z "$out_dir" ] && out_dir="eval-work"
fi

if [ "${#sources[@]}" -eq 0 ]; then
  echo "ERROR: no videos found." >&2
  exit 1
fi
if [ "${#sources[@]}" -gt 4 ]; then
  echo "ERROR: default comparison supports up to 4 videos; found ${#sources[@]}." >&2
  exit 1
fi

ensure_required_deps "$install_deps_flag" "${sources[@]}"

mkdir -p "$out_dir"
manifest="$out_dir/manifest.tsv"
printf 'id\tsource\tinput\tprompt_file\tprompt\tframes_dir\thas_audio\tduration\n' > "$manifest"

i=1
for src in "${sources[@]}"; do
  v="v$i"
  d="$out_dir/$v"
  mkdir -p "$d"
  download_or_copy_video "$src" "$d"
  extract_assets "$d" "$v"

  prompt_file=""
  prompt="$shared_prompt"
  if [ -n "$batch_dir" ] && [ -z "$prompt" ]; then
    if prompt_file="$(find_prompt_for "$src" "$batch_dir")"; then
      prompt="$(tr '\n' ' ' < "$prompt_file")"
    else
      prompt_file=""
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$v" "$src" "$d/input.mp4" "$prompt_file" "$prompt" "$d" "$(cat "$d/has_audio.txt")" "$(cat "$d/duration.txt")" >> "$manifest"
  i=$((i + 1))
done

if [ "$report" = "yes" ]; then
  if [ -n "$batch_dir" ]; then
    mkdir -p "$batch_dir/reports"
    printf '%s\n' "$batch_dir/reports/评测报告-$(basename "$batch_dir").md" > "$out_dir/report-path.txt"
  else
    printf '%s\n' "评测报告-art-eval.md" > "$out_dir/report-path.txt"
  fi
fi

echo "Prepared art-eval assets:"
echo "  manifest: $manifest"
[ -f "$out_dir/report-path.txt" ] && echo "  report:   $(cat "$out_dir/report-path.txt")"
