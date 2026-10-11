# CVE深掘り

サマリーJSON提示後にユーザーから深掘りテーマ (CVE番号、パッケージ名、重大度、上位N件など) があった場合のみ読むこと。それ以外は読まずに終えること。

## 手順

1. テーマを詳細JSONとDockerfile (`FROM` 行、パッケージ導入箇所) で確認する。推測で断定しないこと。
2. 影響範囲、重大度根拠、悪用条件を各1行で説明する。Trivy JSONのフィールドと公式リリースノートを根拠に添えること。
3. 修正案は `FixedVersion` と公式パッケージ情報で確認できたベースイメージのバージョン上げのみとする (例: `alpine:3.21` から `3.22` へ)。同一タグ再ビルドや個別パッケージ更新は書かないこと。未確認の候補を並べないこと。
4. Dockerfileを編集しないこと。修正案提示までとする。

## pullなしの候補探索

レジストリ照会のみ使うこと。`docker pull` しないこと。

```sh
# 候補タグ一覧 (イメージとパターンは読み替える)
docker run --rm regclient/regctl:latest tag ls BASE_IMAGE --include 'PATTERN'
# 新しい順にCVE有無のみ確認 (registry:// はpullしない)
for tag in $(docker run --rm regclient/regctl:latest tag ls BASE_IMAGE --include 'PATTERN' | sort -Vr); do
  echo "=== BASE_IMAGE:$tag ==="
  docker scout cves "registry://BASE_IMAGE:$tag" --only-cve-id CVE-ID
done
```

## 判定

- `No vulnerable package detected` は修正済みまたは非該当。`Packages and Vulnerabilities` にCVEが出れば未修正。
- 存在しないCVE-IDでも `No vulnerable` になるため、先にフィルタなしで当該CVEが検出されることを確認してから提案すること。
- このファイルの必須ツール: `regctl` (docker run経由) と `docker scout`。不足があれば報告して停止すること。

## 出力

5行以内の箇条書きにすること: 対象 / 内容1行 / 条件1行 / 修正案1-2行 / 根拠1行。長い解説は求められた場合のみ補足する。
