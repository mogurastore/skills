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

`~/.config/fcitx5/profile` に `keyboard-us` + `mozc` を登録:

```ini
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=mozc

[Groups/0/Items/0]
Name=keyboard-us

[Groups/0/Items/1]
Name=mozc

[GroupOrder]
0=Default
```

```bash
cp ~/.config/fcitx5/profile ~/.config/fcitx5/profile.bak.$(date +%s)
# 編集後:
fcitx5-remote -r
```

## 3. ホットキー

バックアップ→ `~/.config/fcitx5/config` 編集→リロード:

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
fcitx5-remote -r
fcitx5-remote -n   # 現在の入力メソッド名を確認
```

結果: 変換 → mozc（ひらがな）、無変換 → keyboard-us（英語）、半角/全角 → トグル、`Ctrl+Space` は無効、IME 状態は全アプリで共有。

## 編集ルール

- 設定変更後は `fcitx5-remote -r` で明示的に再読込する
- 変換・無変換が効かない場合: `localectl status` で `jp106`、`hyprctl devices` で `Japanese` か、`~/.config/hypr/` のバインドが横取りしていないかを確認
- `/usr/share/omarchy/` は絶対に触らない（アップデートで上書きされる）
