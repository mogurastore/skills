#!/bin/sh
# ローカルのDockerイメージをTrivyでスキャンし、詳細JSONを保存する。
# 使い方: scan.sh イメージ 詳細JSON
# 成功時のみ詳細JSONを残す。失敗時は部分ファイルを消して非0で終了する。
set -eu

IMAGE="${1:?usage: scan.sh IMAGE DETAIL_JSON}"
DETAIL="${2:?usage: scan.sh IMAGE DETAIL_JSON}"

mkdir -p "$(dirname "$DETAIL")"
TMP="$(mktemp "$(dirname "$DETAIL")/.trivy-scan.XXXXXX")"
trap 'rm -f "$TMP"' EXIT INT HUP TERM
if ! trivy image --image-src docker --format json --output "$TMP" "$IMAGE"; then
  exit 1
fi
mv "$TMP" "$DETAIL"
trap - EXIT INT HUP TERM
