#!/bin/sh
# ローカルのDockerイメージをTrivyでスキャンし、詳細JSONを保存する。
# 使い方: scan.sh イメージ 詳細JSON
# 詳細JSONを出力しないこと。失敗時は非0で終了する。
set -eu

IMAGE="${1:?usage: scan.sh IMAGE DETAIL_JSON}"
DETAIL="${2:?usage: scan.sh IMAGE DETAIL_JSON}"

mkdir -p "$(dirname "$DETAIL")"
trivy image --image-src docker --format json --output "$DETAIL" "$IMAGE"
