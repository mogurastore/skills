---
name: japanese-ime-on-omarchy
description: Omarchy で fcitx5 + Mozc 日本語入力を構築する。ユーザーが日本語入力のセットアップを明示的に依頼したときにのみ使う。
---

# Omarchy 日本語入力セットアップ

Omarchy（Arch Linux + Hyprland + Wayland、fcitx5 + Mozc）の fcitx5 フルセットアップ.

## 厳守事項

- このSKILLの手順1〜3以外は実行しない。推測で補完しない。
- 手順に書いていない診断・設定・提案は、実行も提案もしない。
- 不明点・想定外の状態が出たら、手を動かす前にユーザーに確認する。
- 1ステップごとに結果を報告し、勝手に次へ進まない。
- ファイル編集は `~/.config/fcitx5/profile` と `~/.config/fcitx5/config` のみに限定する。

## スコープ外（やらないこと）

- `omarchy pkg add` の自動実行（提示のみ。スキル側では実行しない）。
- profile / config 以外のファイル編集。
- 環境変数（`GTK_IM_MODULE`、`QT_IM_MODULE`、`XMODIFIERS`等）の診断・変更提案。
- `fcitx5-remote`、`mozc`辞書、`Hyprland`設定への波及。
- `systemctl enable`、再起動、その他サービス恒久化。
- 上記が必要に見えても独断でやらず、確認を止めてユーザー判断を仰ぐ。

## 完了条件

- 手順1〜3が終わり、profileに `keyboard-jp + mozc`、configにホットキーが反映されたら完了。
- 完了後はユーザーに動作確認を依頼して終了する。追加の最適化提案はしない。

## 1. パッケージ

調査コマンドで二値判定する。1つでも未導入があれば提示コマンドに誘導して停止する。未導入があってもインストールはしない。

調査コマンド:

```bash
omarchy pkg present fcitx5 fcitx5-gtk fcitx5-qt fcitx5-mozc; echo "present_exit:$?"
```

判定:

- `present_exit:1` → 未導入あり → 提示コマンドを提示して停止し、ユーザーの実行待ちとする。
- `present_exit:0` → 導入済み → 手順2へ進む。

提示コマンド:

```bash
omarchy pkg add fcitx5 fcitx5-gtk fcitx5-qt fcitx5-mozc
```

## 2. profile

サービス停止 → バックアップ（存在する場合のみ） → `~/.config/fcitx5/profile` 編集 → サービス起動。
`~/.config/fcitx5/profile` に `keyboard-jp` + `mozc` を登録する。
既存内容は `[Groups/0]` と `[GroupOrder]` の該当箇所のみ置換し、他のセクションには触れない。
ファイルが存在しない場合はバックアップをスキップし、そのまま新規作成する。

```ini
[Groups/0]
Name=Default
Default Layout=jp
DefaultIM=keyboard-jp

[Groups/0/Items/0]
Name=keyboard-jp

[Groups/0/Items/1]
Name=mozc

[GroupOrder]
0=Default
```

```bash
# 必ず停止してからprofileに書き込む。
systemctl --user stop omarchy-fcitx5.service
if [ -f ~/.config/fcitx5/profile ]; then cp ~/.config/fcitx5/profile ~/.config/fcitx5/profile.bak.$(date +%s); fi
# 編集
systemctl --user start omarchy-fcitx5.service
```

## 3. ホットキー

バックアップ（存在する場合のみ） → `~/.config/fcitx5/config` 編集 → サービス再起動。
`~/.config/fcitx5/config` の編集だけでは反映されないため、必ず再起動して反映させる。
`[Hotkey/TriggerKeys]`、`[Hotkey/ActivateKeys]`、`[Hotkey/DeactivateKeys]`、`[Behavior]` の該当箇所のみ置換し、他のセクションには触れない。
ファイルが存在しない場合はバックアップをスキップし、そのまま新規作成する。

```ini
[Hotkey/TriggerKeys]
0=Zenkaku_Hankaku

[Hotkey/ActivateKeys]
0=Henkan

[Hotkey/DeactivateKeys]
0=Muhenkan

[Behavior]
ShareInputState=No
```

```bash
if [ -f ~/.config/fcitx5/config ]; then cp ~/.config/fcitx5/config ~/.config/fcitx5/config.bak.$(date +%s); fi
# 編集
# configは再起動するまで反映されないため、必ずrestartする。
systemctl --user restart omarchy-fcitx5.service
systemctl --user is-active omarchy-fcitx5.service
```

結果: 変換 → mozc（ひらがな）、無変換 → keyboard-jp（英語入力）、半角/全角 → トグル、`Ctrl+Space` は無効、IME 状態は各アプリで独立。

- 設定完了後はユーザーに動作確認を依頼して終了する。追加の診断・提案はしない。
