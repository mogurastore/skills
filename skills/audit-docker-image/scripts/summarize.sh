#!/bin/sh
# Trivy詳細JSONから小さなサマリーJSONを作る。詳細JSONを会話に読まないこと。
# 使い方: summarize.sh イメージ 詳細JSON 出力JSON
# 出力JSONは必ず書く。complete時は0、incomplete時は1で終了する。
set -eu

IMAGE="${1:?usage: summarize.sh IMAGE DETAIL_JSON OUTPUT_JSON}"
DETAIL="${2:?usage: summarize.sh IMAGE DETAIL_JSON OUTPUT_JSON}"
OUTPUT="${3:?usage: summarize.sh IMAGE DETAIL_JSON OUTPUT_JSON}"

mkdir -p "$(dirname "$OUTPUT")"
SCANNED_AT="$(date -u +%FT%TZ)"
TRIVY_VERSION="$(trivy --version 2>&1 | head -n 1 || true)"
IMAGE_ID="$(docker image inspect "$IMAGE" --format '{{.Id}}' 2>/dev/null || true)"
IMAGE_CREATED="$(docker image inspect "$IMAGE" --format '{{.Created}}' 2>/dev/null || true)"

write_incomplete() {
  # $1 = failedStep, $2 = errorSummary
  jq -n \
    --arg scannedAt "$SCANNED_AT" \
    --arg image "$IMAGE" \
    --arg failedStep "$1" \
    --arg errorSummary "$2" \
    '{status:"incomplete",scannedAt:$scannedAt,image:$image,
      failedStep:$failedStep,errorSummary:$errorSummary,
      pendingChecks:["未実施の確認事項を手動で確認する"],
      detailJsonPath:null}' > "$OUTPUT"
}

if [ ! -f "$DETAIL" ]; then
  write_incomplete "summarize" "detail JSON not found: $DETAIL"
  exit 1
fi

if ! jq empty "$DETAIL" >/dev/null 2>&1; then
  write_incomplete "summarize" "detail JSON is not valid JSON: $DETAIL"
  exit 1
fi

jq \
  --arg scannedAt "$SCANNED_AT" \
  --arg image "$IMAGE" \
  --arg imageId "$IMAGE_ID" \
  --arg imageCreated "$IMAGE_CREATED" \
  --arg trivyVersion "$TRIVY_VERSION" \
  --arg detailPath "$DETAIL" \
  '
  def rank: {"CRITICAL":0,"HIGH":1,"MEDIUM":2,"LOW":3,"UNKNOWN":4};
  def sev: (.Severity // "UNKNOWN");
  ([.Results // [] | .[]? | (.Vulnerabilities // [])[]?] | map(. + {severity: sev})) as $vulns
  | ($vulns | length) as $total
  | (reduce $vulns[] as $v ({}; .[$v.severity] += 1)) as $counts
  | ($vulns | sort_by([(rank[.severity] // 5), .VulnerabilityID]) | .[:10]
      | map({cve: .VulnerabilityID, severity: .severity, package: .PkgName,
             installedVersion: .InstalledVersion, fixedVersion: .FixedVersion,
             title: .Title})) as $findings
  | {status:"complete", scannedAt:$scannedAt, image:$image,
     imageId:$imageId, imageCreated:$imageCreated, trivyVersion:$trivyVersion,
     severityCounts:{CRITICAL:($counts.CRITICAL//0), HIGH:($counts.HIGH//0),
       MEDIUM:($counts.MEDIUM//0), LOW:($counts.LOW//0),
       UNKNOWN:($counts.UNKNOWN//0), TOTAL:$total},
     findings:$findings, omittedCount:($total - ($findings|length)),
     detailJsonPath:$detailPath}
  ' "$DETAIL" > "$OUTPUT"
