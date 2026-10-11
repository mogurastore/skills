---
name: audit-docker-image
description: "DockerイメージをビルドしTrivyでスキャンして詳細JSON保存と重大度別サマリーJSON作成を行う。CVE深掘りとベースイメージ更新案提示付き。ユーザーが明示的に依頼した時のみ使う。Dockerfile audit, docker image scan, trivy, CVE fix triggers."
---

# Dockerイメージ監査

対象イメージをビルドし、Trivyでスキャンして小さなサマリーJSONを作る。詳細JSON全体を会話に貼らないこと。

## 前提条件

- 必須ツールは `docker`, `trivy`, `jq`。不足があれば報告して停止すること。インストールしないこと。
- 深掘り時のみ `regctl` (docker run経由) と `docker scout` を追加で要求する。
- 作業場所はDockerfile / Composeのあるリポジトリルート。`./tmp` はそこからの相対パス。
- `<skill-dir>` はこのSKILL.mdがあるディレクトリ。スクリプトは `<skill-dir>/scripts/scan.sh`、`<skill-dir>/scripts/summarize.sh` の絶対パスまたは相対パスで呼ぶこと。対象リポジトリの `./scripts/` には存在しない。
- レジストリへのpush、稼働コンテナや本番環境の変更をしないこと。
- Dockerfileを編集しないこと。修正案提示までとする。

## 1. 対象の特定

- `Dockerfile*`、`compose*.yml` / `compose*.yaml`、既存ビルド設定を確認し、イメージ候補を列挙する。
- `<project>` はリポジトリルートのディレクトリ名、`<service>` はDockerfileサフィックスまたはComposeサービス名を既定とする。
- 候補が複数あれば番号付きで提示し、選択されるまで進まないこと。1件でもイメージ名とDockerfileパスを明示して合意を取ること。合意なく進まないこと。
- イメージ名は `<project>-<service>:audit` に固定する。

## 2. ビルドか再利用かの確認

- 二択で質問すること。推測で決めないこと。
- ビルドする場合: Dockerfileとコンテキストを明示してから `docker build` を実行する。失敗した場合はスキャンに進まず、5の手順で `failedStep: "build"` の incomplete JSON を出力する。
- 再利用する場合: `docker image inspect <project>-<service>:audit` で存在確認する。なければビルドするか確認する。

## 3. スキャン

- 合意したイメージ名と詳細パスで `<skill-dir>/scripts/scan.sh` を実行する:
  `"<skill-dir>/scripts/scan.sh" "<project>-<service>:audit" "./tmp/<project>-<service>-YYYY-MM-DD.trivy.json"`
- スクリプト内で `--image-src docker` を付けてローカルの `:audit` タグを参照させる。日付は `date +%F` で取る。
- スキャンを実行した後に失敗した場合は詳細JSONが残らない。5に進むこと。ビルド失敗時にはスキャン失敗として扱わないこと。

## 4. サマリー作成

- 詳細JSONをコンテキストに読まず `<skill-dir>/scripts/summarize.sh` を実行する:
  `"<skill-dir>/scripts/summarize.sh" "<image>" "<detail>" "<output>"`
- 詳細JSONと出力JSONは必ず別ファイルにすること。同一パス指定はエラーになる。
- スクリプトが `scannedAt` (`date -u +%FT%TZ`)、`trivyVersion`、`imageId`、`imageCreated` を自動取得し、`complete` JSONを書く。内容は `severityCounts` (CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN, TOTAL)、重大度順・CVE番号順の上位10件 `findings`、`omittedCount = TOTAL - findings.length`、`detailJsonPath`。
- サマリーJSONの中身のみ提示すること。

## 5. 失敗時の扱い

- summarize.shは同一パス指定以外は必ず出力JSONを書く。終了0は `complete`、非0は `incomplete`。
- `incomplete` を脆弱性0件として扱わないこと。形式:
  `{"status":"incomplete","scannedAt":"...","image":"...","failedStep":"build|scan|summarize","errorSummary":"1-2行","pendingChecks":[...],"detailJsonPath":null}`
- ビルド失敗時は、サマリー出力先に次の形式のJSONを書き、`failedStep` を `build`、`errorSummary` をビルドエラーの要約にする。スキャンは実行しない。
- スキャン実行後に失敗した場合は、サマリー出力先に同じ形式のJSONを書き、`failedStep` を `scan`、`errorSummary` をスキャンエラーの要約にする。
- 失敗JSONの形式: `{"status":"incomplete","scannedAt":"...","image":"...","failedStep":"build|scan","errorSummary":"1-2行","pendingChecks":[...],"detailJsonPath":null}`。`scannedAt` は `date -u +%FT%TZ` で取得する。
- 詳細JSONが存在しないことだけを理由にscan失敗と判断しない。ビルド失敗かスキャン実行後の失敗かを、実際に実行した手順と終了結果で分類する。summarize.shを実行した場合、その失敗は `failedStep: "summarize"` とする。

## 6. 深掘り (条件付き)

- サマリー提示後に深掘りテーマを自由入力で聞く (例: CVE番号、パッケージ名、重大度、上位3件)。入力がなければ終了すること。
- 入力がある場合のみ `references/deep-dive.md` を読んで従うこと。
