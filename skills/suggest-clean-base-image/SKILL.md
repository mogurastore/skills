---
name: suggest-clean-base-image
description: "プロジェクト内のDockerfileから対象を選び、指定CVEを含まないクリーンなベースイメージタグ候補をpullなしで探索・提案する。ユーザーが明示的に依頼した時のみ使う。clean base image, regctl, docker scout, CVE fix triggers."
---

# クリーンなベースイメージ提案

指定CVEを含まないベースイメージタグ候補をレジストリ照会のみで探して提案する。`docker pull` しないこと。Dockerfileを編集しないこと。

## 前提条件

- 必須ツールは `regctl` (docker run経由) と `docker scout`。不足があれば報告して停止すること。インストールしないこと。
- 作業場所はDockerfile / Composeのあるリポジトリルート。
- レジストリ照会のみ使うこと。`docker pull` しないこと。
- Dockerfileを編集しないこと。修正案提示までとする。

## 1. 対象の特定

- `Dockerfile*`、`compose*.yml` / `compose*.yaml` を確認し、候補を列挙する。
- 候補が複数あれば番号付きで提示し、選択されるまで進まないこと。1件でもDockerfileパスを明示して合意を取ること。合意なく進まないこと。

## 2. CVE-IDの入力

- CVE-IDを自由入力で聞くこと。入力がなければ終了すること。
- 形式は `CVE-YYYY-NNNNN` を想定し、不明な入力は確認してから進むこと。

## 3. ベースイメージの特定

- 選択されたDockerfileの `FROM` 行を確認し、`BASE_IMAGE` とタグパターンを特定すること。推測で断定しないこと。

## 4. 候補探索

- 次の手順でレジストリ照会のみ行うこと。イメージとパターンは読み替えること:

```sh
# 候補タグ一覧
docker run --rm regclient/regctl:latest tag ls BASE_IMAGE --include 'PATTERN'
# 新しい順にCVE有無のみ確認 (registry:// はpullしない)
for tag in $(docker run --rm regclient/regctl:latest tag ls BASE_IMAGE --include 'PATTERN' | sort -Vr); do
  echo "=== BASE_IMAGE:$tag ==="
  docker scout cves "registry://BASE_IMAGE:$tag" --only-cve-id CVE-ID
done
```

- 判定は次の通りとすること:
  - `No vulnerable package detected` は修正済みまたは非該当。`Packages and Vulnerabilities` にCVEが出れば未修正。
  - 存在しないCVE-IDでも `No vulnerable` になるため、先にフィルタなしで当該CVEが検出されることを確認してから提案すること。
- 修正案は公式パッケージ情報で確認できたベースイメージのバージョン上げのみとすること。未確認の候補を並べないこと。

## 5. 出力

- 5行以内の箇条書きにすること: 対象 / 内容1行 / 条件1行 / 修正案1-2行 / 根拠1行。長い解説は求められた場合のみ補足すること。
