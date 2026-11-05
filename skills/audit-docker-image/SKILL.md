---
name: audit-docker-image
description: "DockerイメージをビルドしTrivyでスキャンして詳細JSONを保存する。スキャン専用。ベースイメージ選定は扱わない。ユーザーが明示的に依頼した時のみ使う。Dockerfile audit, docker image scan, trivy triggers."
---

# Dockerイメージ監査

対象イメージをビルドし、Trivyでスキャンして詳細JSONを保存する。サマリーJSONは作成しない。詳細JSON全体を会話に貼らないこと。

## 前提条件

- 必須ツールは `docker`, `trivy`。不足があれば報告して停止すること。インストールしないこと。
- 作業場所はDockerfile / Composeのあるリポジトリルート。`./tmp` はそこからの相対パス。
- `<skill-dir>` はこのSKILL.mdがあるディレクトリ。スキャンスクリプトは `<skill-dir>/scripts/scan.sh` を絶対パスまたは相対パスで呼ぶこと。対象リポジトリの `./scripts/` には存在しない。
- レジストリへのpush、稼働コンテナや本番環境の変更をしないこと。
- Dockerfileを編集しないこと。

## 1. 対象の特定

- `Dockerfile*`、`compose*.yml` / `compose*.yaml`、既存ビルド設定を確認し、イメージ候補を列挙する。
- `<project>` はリポジトリルートのディレクトリ名、`<service>` はDockerfileサフィックスまたはComposeサービス名を既定とする。
- 候補が複数あれば番号付きで提示し、選択されるまで進まないこと。1件でもイメージ名とDockerfileパスを明示して合意を取ること。合意なく進まないこと。
- イメージ名は `<project>-<service>:audit` に固定する。

## 2. ビルドか再利用かの確認

- 二択で質問すること。推測で決めないこと。
- ビルドする場合: Dockerfileとコンテキストを明示してから `docker build` を実行する。失敗した場合はスキャンに進まず、失敗したこととエラーの要約を報告する。
- 再利用する場合: `docker image inspect <project>-<service>:audit` で存在確認する。なければビルドするか確認する。

## 3. スキャン

- 合意したイメージ名と詳細パスで `<skill-dir>/scripts/scan.sh` を実行する:
  `"<skill-dir>/scripts/scan.sh" "<project>-<service>:audit" "./tmp/<project>-<service>-YYYY-MM-DD-HHMMSS.trivy.json"`
- スクリプト内で `--image-src docker` を付けてローカルの `:audit` タグを参照させる。日時は `date +%F-%H%M%S` で取る。
- スキャンを実行した後に失敗した場合は詳細JSONが残らない。ビルド失敗と混同せず、スキャン失敗としてエラーの要約を報告する。

## 4. 失敗時の扱い

- 失敗時はJSONを作成せず、失敗した手順 (build または scan) とエラーの要約を報告する。脆弱性0件と誤解させないこと。
- ビルド失敗かスキャン実行後の失敗かを、実際に実行した手順と終了結果で分類する。詳細JSONが存在しないことだけを理由にscan失敗と判断しない。

## 5. 終了

- 成功時は詳細JSONの保存先を報告して終了すること。CVE解説やベースイメージ更新案は扱わないこと。
- 後から特定CVEの有無を聞かれた場合は、報告済みの詳細JSONからそのCVEを直接検索して答えること。重大度や上位件数で絞らず、検出された場合は該当するパッケージと重大度も示す。詳細JSONが見つからない、または読めない場合は、未検出と断定せずその旨を伝える。
- クリーンなベースイメージを探す場合は `suggest-clean-base-image` スキルを使うこと。
