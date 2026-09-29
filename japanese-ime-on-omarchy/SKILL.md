---
name: japanese-ime-on-omarchy
description: Omarchy で fcitx5 + Mozc 日本語入力を構築する。
---

# Omarchy 日本語入力セットアップ

Omarchy（Arch Linux + Hyprland + Wayland、fcitx5 + Mozc）の fcitx5 フルセットアップ.

## 1. パッケージ

導入済みか調査し、未導入があればユーザーに実行を促す（スキル側では実行しない）。

調査: `omarchy pkg present fcitx5 fcitx5-gtk fcitx5-qt fcitx5-mozc`

提示コマンド:

```bash
omarchy pkg add fcitx5 fcitx5-gtk fcitx5-qt fcitx5-mozc
```

`fcitx5-configtool` GUI は使わない（以下の直接編集で代替）。

## 2. profile

バックアップ → `~/.config/fcitx5/profile` 編集 → サービス再起動。
`~/.config/fcitx5/profile` に `keyboard-jp` + `mozc` を登録する。

```ini
[Groups/0]
Name=Default
Default Layout=jp
DefaultIM=mozc

[Groups/0/Items/0]
Name=keyboard-jp

[Groups/0/Items/1]
Name=mozc

[GroupOrder]
0=Default
```

```bash
# profile は fcitx5-configtool 経由でしか更新されないため、既存プロセスはメモリ内の古い値でディスクを上書きする。
# 必ず停止してから書き込む。
systemctl --user stop omarchy-fcitx5.service
cp ~/.config/fcitx5/profile ~/.config/fcitx5/profile.bak.$(date +%s)
# 編集後:
systemctl --user start omarchy-fcitx5.service
sleep 3
fcitx5-remote -n    # mozc になっていることを確認
```

`fcitx5-remote -r` は使えません（profile を再読込しないため）。

## 3. ホットキー

バックアップ → `~/.config/fcitx5/config` 編集 → `fcitx5-remote -r`:

```ini
[Hotkey/TriggerKeys]
0=Zenkaku_Hankaku

[Hotkey/ActivateKeys]
0=Henkan

[Hotkey/DeactivateKeys]
0=Muhenkan
```

```ini
[Behavior]
ShareInputState=All
```

```bash
cp ~/.config/fcitx5/config ~/.config/fcitx5/config.bak.$(date +%s)
# 編集後:
fcitx5-remote -r     # config のみ対象なので -r でよい
fcitx5-remote -n
```

結果: 変換 → mozc（ひらがな）、無変換 → keyboard-jp（英語入力）、半角/全角 → トグル、`Ctrl+Space` は無効、IME 状態は全アプリで共有。

- `fcitx5-remote -e` は使わない（`Restart=always` で即再起動し dbus 名競合を起こす）
- 完了後は `fcitx5-remote -n` で確認し、実キー入力はユーザー自身に試打を依頼する

