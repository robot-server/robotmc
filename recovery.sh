#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

usage() {
    echo "Usage: $0 [backup-archive]"
    echo
    echo "Restores a mc-backup tar archive into MINECRAFT_DIR using itzg/mc-backup."
    echo "If backup-archive is omitted and BACKUP_METHOD=rclone, the newest remote backup is downloaded first."
    echo "Otherwise, the newest file in ./backup is used."
    echo "Set KEEP_DOWNLOADED_BACKUP=1 to retain a remote backup downloaded for restore."
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ $# -gt 1 ]; then
    usage
    exit 1
fi

env_file=${ENV_FILE:-.env}
if [ -f "$env_file" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
fi

minecraft_dir=${MINECRAFT_DIR:-./minecraft}
backup_dir=${BACKUP_DIR:-./backup}
mc_backup_image=${MC_BACKUP_IMAGE:-itzg/mc-backup:latest}
backup_name=${BACKUP_NAME:-world}
downloaded_backup=0

case "$minecraft_dir" in
    /*) minecraft_abs=$minecraft_dir ;;
    *) minecraft_abs="$(pwd -P)/${minecraft_dir#./}" ;;
esac

case "$backup_dir" in
    /*) backup_abs=$backup_dir ;;
    *) backup_abs="$(pwd -P)/${backup_dir#./}" ;;
esac

mkdir -p "$backup_abs"

rclone_env_args=(
    -e RCLONE_CONFIG_S3_TYPE=s3
    -e RCLONE_CONFIG_S3_PROVIDER="${S3_PROVIDER:-}"
    -e RCLONE_CONFIG_S3_REGION="${S3_REGION:-}"
    -e RCLONE_CONFIG_S3_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
    -e RCLONE_CONFIG_S3_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
    -e RCLONE_CONFIG_S3_ENDPOINT="${AWS_ENDPOINT_URL_S3:-}"
)

require_var() {
    local name=$1

    if [ -z "${!name:-}" ]; then
        echo "$name is required to restore from remote backup." >&2
        return 1
    fi
}

require_remote_restore_env() {
    require_var S3_PROVIDER
    require_var AWS_ACCESS_KEY_ID
    require_var AWS_SECRET_ACCESS_KEY
    require_var AWS_ENDPOINT_URL_S3
    require_var S3_BUCKET_NAME
}

remote_path() {
    local bucket=${S3_BUCKET_NAME:-}
    local path=${S3_BUCKET_PATH:-}

    if [ -z "$bucket" ]; then
        echo "S3_BUCKET_NAME is required to restore from remote backup." >&2
        return 1
    fi

    if [ -n "$path" ]; then
        echo "${bucket}/${path}"
    else
        echo "$bucket"
    fi
}

file_mtime() {
    if stat -f "%m" "$1" >/dev/null 2>&1; then
        stat -f "%m" "$1"
    else
        stat -c "%Y" "$1"
    fi
}

find_newest_local_backup() {
    local candidate
    local mtime
    local newest=
    local newest_mtime=-1
    local candidates

    shopt -s nullglob
    candidates=("$backup_abs"/*)
    shopt -u nullglob

    for candidate in "${candidates[@]}"; do
        if [ ! -f "$candidate" ]; then
            continue
        fi

        mtime=$(file_mtime "$candidate") || continue
        if [ -z "$newest" ] || [ "$mtime" -gt "$newest_mtime" ]; then
            newest=$candidate
            newest_mtime=$mtime
        fi
    done

    echo "$newest"
}

download_latest_remote_backup() {
    local remote
    local latest

    require_remote_restore_env
    remote=$(remote_path)
    latest=$(
        docker run --rm \
            --entrypoint rclone \
            "${rclone_env_args[@]}" \
            "$mc_backup_image" \
            lsf --files-only --format tp "s3:${remote}" \
            | awk -F ';' -v prefix="${backup_name}-" 'index($2, prefix) == 1 { print }' \
            | sort \
            | tail -n 1 \
            | cut -d ';' -f 2-
    )

    if [ -z "$latest" ]; then
        echo "No remote backup archive found."
        return 1
    fi

    echo "Downloading remote backup: $latest"
    docker run --rm \
        --entrypoint rclone \
        "${rclone_env_args[@]}" \
        -v "$backup_abs:/backups" \
        "$mc_backup_image" \
        copyto "s3:${remote%/}/$latest" "/backups/$latest"

    backup="${backup_abs}/$latest"
    downloaded_backup=1
}

if [ $# -eq 1 ]; then
    backup=$1
elif [ "${BACKUP_METHOD:-}" = "rclone" ]; then
    download_latest_remote_backup
else
    backup=$(find_newest_local_backup)
fi

if [ -z "${backup:-}" ] || [ ! -f "$backup" ]; then
    echo "No backup archive found."
    exit 1
fi

case "$backup" in
    /*) backup_abs_file=$backup ;;
    *) backup_abs_file="$(pwd -P)/${backup#./}" ;;
esac

timestamp=$(date +%Y-%m-%d_%H-%M-%S)
previous_dir="${minecraft_abs}.before-restore-${timestamp}"

echo "Backup: $backup_abs_file"
echo "Target: $minecraft_abs"
echo "Previous data will be moved to: $previous_dir"

if [ "${FORCE_RESTORE:-}" != "1" ]; then
    read -r -p "Type RESTORE to continue: " confirm
    if [ "$confirm" != "RESTORE" ]; then
        echo "Restore cancelled."
        exit 1
    fi
fi

docker compose stop minecraft mc-backup >/dev/null 2>&1 || true

if [ -e "$minecraft_abs" ]; then
    mv "$minecraft_abs" "$previous_dir"
fi

mkdir -p "$minecraft_abs"

restore_backup_dir="${backup_abs}/.restore-${timestamp}"
restore_backup_file="${restore_backup_dir}/$(basename "$backup_abs_file")"
mkdir -p "$restore_backup_dir"
if ! ln "$backup_abs_file" "$restore_backup_file" 2>/dev/null; then
    cp "$backup_abs_file" "$restore_backup_file"
fi
cleanup_restore_dir=$restore_backup_dir
trap 'rm -rf "$cleanup_restore_dir"' EXIT

restore_failed=0
docker run --rm \
    --entrypoint restore-tar-backup \
    -v "$minecraft_abs:/data" \
    -v "$restore_backup_dir:/backups:ro" \
    "$mc_backup_image" || restore_failed=1

if [ "${restore_failed:-0}" = "1" ]; then
    rm -rf "$minecraft_abs"
    if [ -e "$previous_dir" ]; then
        mv "$previous_dir" "$minecraft_abs"
        echo "Restore failed. Rolled back to previous data." >&2
    else
        echo "Restore failed. Removed partial restored data." >&2
    fi
    exit 1
fi

if [ "$downloaded_backup" = "1" ] && [ "${KEEP_DOWNLOADED_BACKUP:-}" != "1" ]; then
    rm -f "$backup_abs_file"
fi

echo "Restore complete."
