#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
platform="auto"
dest=""
force=0
dry_run=0

# Supported platform directories include platform/linux and platform/windows.
layered_config_names=("mpv.conf" "input.conf")

usage() {
    cat <<'USAGE'
Usage: ./setup.sh [--platform auto|linux|windows|macos] [--dest PATH] [--force] [--dry-run]

Installs base mpv config plus the current platform layer.
USAGE
}

die() {
    printf 'setup.sh: %s\n' "$*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --platform)
            [[ $# -ge 2 ]] || die '--platform requires a value'
            platform="$2"
            shift 2
            ;;
        --platform=*)
            platform="${1#*=}"
            shift
            ;;
        --dest)
            [[ $# -ge 2 ]] || die '--dest requires a value'
            dest="$2"
            shift 2
            ;;
        --dest=*)
            dest="${1#*=}"
            shift
            ;;
        --force)
            force=1
            shift
            ;;
        --dry-run)
            dry_run=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

detect_platform() {
    case "${OSTYPE:-}" in
        linux*) printf 'linux' ;;
        darwin*) printf 'macos' ;;
        msys*|cygwin*|win32*|mingw*) printf 'windows' ;;
        *)
            case "$(uname -s 2>/dev/null || true)" in
                Linux*) printf 'linux' ;;
                Darwin*) printf 'macos' ;;
                MINGW*|MSYS*|CYGWIN*) printf 'windows' ;;
                *) die 'could not auto-detect platform; pass --platform linux, windows, or macos' ;;
            esac
            ;;
    esac
}

default_dest() {
    case "$1" in
        windows)
            if [[ -n "${APPDATA:-}" ]]; then
                printf '%s/mpv' "$APPDATA"
            else
                printf '%s/AppData/Roaming/mpv' "$HOME"
            fi
            ;;
        linux|macos)
            printf '%s/mpv' "${XDG_CONFIG_HOME:-$HOME/.config}"
            ;;
        *)
            die "unsupported platform: $1"
            ;;
    esac
}

is_layered_config() {
    local name="$1"
    local layered

    for layered in "${layered_config_names[@]}"; do
        [[ "$name" == "$layered" ]] && return 0
    done

    return 1
}

ensure_destination() {
    if [[ -d "$dest" && "$force" -ne 1 ]]; then
        shopt -s nullglob dotglob
        local entries=("$dest"/*)
        shopt -u nullglob dotglob

        if ((${#entries[@]} > 0)); then
            die "destination is not empty: $dest. Re-run with --force to overwrite managed files."
        fi
    fi

    if [[ "$dry_run" -eq 1 ]]; then
        printf 'Would create destination: %s\n' "$dest"
    else
        mkdir -p "$dest"
    fi
}

copy_tree_except_layered_config() {
    local src="$1"
    [[ -d "$src" ]] || return 0

    shopt -s nullglob dotglob
    local item
    for item in "$src"/*; do
        local name="${item##*/}"
        if is_layered_config "$name"; then
            continue
        fi

        if [[ "$dry_run" -eq 1 ]]; then
            printf 'Would copy %s -> %s\n' "$item" "$dest"
        else
            cp -R "$item" "$dest/"
        fi
    done
    shopt -u nullglob dotglob
}

compose_config() {
    local file_name="$1"
    local sources=(
        "$repo_dir/base/$file_name"
        "$repo_dir/platform/$platform/$file_name"
    )
    local existing=()
    local src

    for src in "${sources[@]}"; do
        [[ -f "$src" ]] && existing+=("$src")
    done

    ((${#existing[@]} > 0)) || return 0

    if [[ "$dry_run" -eq 1 ]]; then
        printf 'Would compose_config %s from: %s\n' "$file_name" "${existing[*]}"
        return 0
    fi

    local tmp="$dest/$file_name.tmp.$$"
    : > "$tmp"

    local index=0
    for src in "${existing[@]}"; do
        if ((index > 0)); then
            printf '\n' >> "$tmp"
        fi
        cat "$src" >> "$tmp"
        index=$((index + 1))
    done

    printf '\n' >> "$tmp"

    mv "$tmp" "$dest/$file_name"
}

case "$platform" in
    auto) platform="$(detect_platform)" ;;
    linux|windows|macos) ;;
    *) die "unsupported platform: $platform" ;;
esac

if [[ -z "$dest" ]]; then
    dest="$(default_dest "$platform")"
fi

ensure_destination
copy_tree_except_layered_config "$repo_dir/base"
copy_tree_except_layered_config "$repo_dir/platform/$platform"

for config_name in "${layered_config_names[@]}"; do
    compose_config "$config_name"
done

printf 'Installed mpv config for %s to %s\n' "$platform" "$dest"
