#!/bin/sh
# ローカルのDockerイメージをTrivyでスキャンし、詳細JSONを保存する。
# 使い方: scan.sh イメージ 詳細JSON
# 成功時のみ詳細JSONを残す。失敗時は部分ファイルを消して非0で終了する。
set -eu

IMAGE="${1:?usage: scan.sh IMAGE DETAIL_JSON}"
DETAIL="${2:?usage: scan.sh IMAGE DETAIL_JSON}"

mkdir -p "$(dirname "$DETAIL")"
if ! trivy image --image-src docker --format json --output "$DETAIL" "$IMAGE"; then
  rm -f "$DETAIL"
  exit 1
fi
