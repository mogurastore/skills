---
name: audit-docker-image
description: ユーザーが明示的に指定したときに限り、Dockerイメージのビルド・Trivy脆弱性スキャン・CVE深掘りを行う。DockerfileやComposeの特定、Trivy詳細JSON保存、重大度別集計の簡潔JSONサマリー作成、指定CVEの修正案提示の手順と出力形式を定義する。
disable-model-invocation: true
---

# Audit Docker Images

対象の Docker イメージをビルドし、Trivy で脆弱性をスキャンして JSON レポートを作成する。
詳細 JSON 全体を会話に貼らず、集計だけ扱うことでコンテキスト膨張を避けるのが狙い。

## 前提

- 必要なツール: `docker`, `trivy`, `jq`。なければ先に不足を報告し、インストールせず停止する。
- 作業ディレクトリ: リポジトリルート（Dockerfile / Compose がある場所）。`./tmp` はそこからの相対パス。
- 日付は `date +%F`（YYYY-MM-DD）で統一する。
- レジストリへの push や稼働コンテナ・本番環境の変更はしない。

## 1. 監査対象の特定

`Dockerfile*`、`compose*.yml` / `compose*.yaml`、既存のビルド・スキャン設定を確認し、イメージ候補を特定する。

- `<project>` はリポジトリルートのディレクトリ名、` <service>` は Dockerfile のサフィックスまたは Compose サービス名を既定とする（例: `skills-production`）。
- 候補が複数ある場合は番号付きで提示し、ユーザーが選ぶまで先に進まない。
- 候補が 1 つでも、イメージ名と Dockerfile パスを明示して合意を取る。

## 2. ビルドするか既存イメージを使うか確認

ユーザーに二択で選んでもらう。推測で決めない。

- イメージ名は `<project>-<service>:audit` とする。
- ビルドする場合: `docker build` の Dockerfile とコンテキストを明示してから実行する。
- 既存イメージを使う場合: `docker image inspect <project>-<service>:audit` で有無を確認し、イメージ ID と作成日時（`Id`, `Created`）を記録する。存在しなければビルドするか確認する。

## 3. Trivy スキャン

選択したローカルイメージをスキャンし、詳細 JSON を保存する。

```sh
mkdir -p ./tmp
trivy --version > ./tmp/trivy-version.txt 2>&1
trivy image --image-src docker --format json --output "./tmp/<project>-<service>-<YYYY-MM-DD>.trivy.json" "<project>-<service>:audit"
```

- `--image-src docker` を付ける理由: ローカルの `:audit` タグを確実に参照させるため。
- `trivy --version` の出力は要約 JSON の `trivyVersion` に使う。

## 4. 要約 JSON の作成

詳細 JSON 全体を会話コンテキストに読み込まない。`jq` で集計だけ抽出する。

```sh
IMAGE="<project>-<service>:audit"
DETAIL="./tmp/<project>-<service>-<YYYY-MM-DD>.trivy.json"
OUTPUT="./tmp/<project>-<service>-<YYYY-MM-DD>.json"
jq '[.Results[] | (.Vulnerabilities // [])[] | .Severity // "UNKNOWN"] | group_by(.) | map({key: .[0], value: length}) | from_entries' "$DETAIL"
jq -c '.Results[] | (.Vulnerabilities // [])[] | {cve: .VulnerabilityID, severity: .Severity, package: .PkgName, installedVersion: .InstalledVersion, fixedVersion: .FixedVersion, title: .Title}' "$DETAIL"
```

集計ルール:

- 重大度別件数: `CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN, TOTAL` を数える。
- `findings`: `CRITICAL > HIGH > MEDIUM > LOW` の順、同重大度内は CVE 番号順で最大 10 件。各件は CVE・重大度・パッケージ・導入バージョン・修正版・タイトルを残す。
- 残りは `omittedCount = TOTAL - findings.length` とし、詳細は詳細 JSON パスだけ残す。

出力は必ずこの形にする:

```json
{
  "status": "complete",
  "scannedAt": "2026-10-06T15:39:30Z",
  "image": "skills-production:audit",
  "imageId": "sha256:...",
  "imageCreated": "2026-09-17T20:38:22Z",
  "trivyVersion": "Version: 0.69.4",
  "severityCounts": {"CRITICAL": 0, "HIGH": 4, "MEDIUM": 14, "LOW": 2, "UNKNOWN": 0, "TOTAL": 20},
  "findings": [
    {"cve": "CVE-2026-XXXXX", "severity": "HIGH", "package": "libssl3", "installedVersion": "3.3.7-r1", "fixedVersion": "3.3.7-r2", "title": "..."}
  ],
  "omittedCount": 10,
  "detailJsonPath": "./tmp/<project>-<service>-<YYYY-MM-DD>.trivy.json"
}
```

## 5. 失敗時の扱い

ビルドまたはスキャンに失敗しても要約 JSON を作成し、`status` を未完了にする。未完了を「脆弱性 0 件」と扱わないのが重要（誤った安心感を与えないため）。

```json
{
  "status": "incomplete",
  "scannedAt": "<ISO8601>",
  "image": "<project>-<service>:audit",
  "failedStep": "build | scan | summarize",
  "errorSummary": "エラーの要約を1-2行",
  "pendingChecks": ["未実施の確認事項"],
  "detailJsonPath": null
}
```

## 6. 深掘りテーマの確認

要約 JSON 提示後に、深掘りしたい点を自由入力で聞く。形式は指定せず、例を示す程度にとどめる（CVE番号、パッケージ名、重大度、「上位3件」など）。入力がなければスキップして終了する。入力がある場合のみ 7 に進む。

## 7. 指定内容の調査

指定された CVE・パッケージについて調査し、要点のみ簡潔に提案する。長い解説は求められた場合のみ補足する。

- 詳細 JSON と Dockerfile のベースイメージ・パッケージ導入箇所を確認する。推測で断定せず、Trivy JSON と公式リリースノート等の根拠を添える。
- 影響範囲、重大度根拠、悪用条件を説明する。
- 修正案はベースイメージのバージョン更新のみとする（例: `alpine:3.21 → 3.22`）。同一タグ再ビルドや個別パッケージ更新は書かない。
- 未確認の案を「見込み」「解決しなければ」で並べない。各案は Trivy の `FixedVersion` と公式パッケージ情報で確認できたものだけ書く。
- 出力は 5 行以内の箇条書きにする。形式: 対象 / 内容 1 行 / 条件 1 行 / 修正案 1-2 行 / 根拠 1 行。
