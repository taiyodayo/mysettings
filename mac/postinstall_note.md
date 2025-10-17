# setup_mac_all.sh インストール完了後にする事

# GUIアプリの設定をしよう
Macでのアプリ開発に必要なもののインストールが完了しました。
いくつかの作業はGUIでの操作が必要ですので、以下を参考にしてください

### Android Studio - 全てデフォルトを選択しながら「次へ」で進みます。
+ 起動したら 「SDK Manager」から Commandlin Tools のインストールが必要です。
初期設定が出来たら、最初のダイアログのメイン画面中央下、「More Actions」を選択すると「SDK Manager」が選択できます。
SDK Manager が開いたら、右側画面の「SDK Tools」タブから `Android SDK Command-line Tools (Latest)` を選択します

### Xcode - バックグランドでインストールされます。
+ スクリプト実行開始してから5分ほどで、「Apple ID でログイン」を求められます
AppStoreへのログインID/PWでログインしてください - 【事前にXcodeを取得済みのアカウント】が必要です。
早い回線でも20分以上かかります。ダウンロードが完了するとアプリが開きますので、下記２点を行って下さい
・iOS 開発キットを選択
・「Xcodeの環境設定」から Apple アカウントにログイン (Mailab チーム開発者として登録済みのアカウントが必要です)


# 「ED25519 暗号鍵」を作成しよう
macOS Onboarding — ED25519 SSH Key → GitHub → Post to Chat

+ Unixでは「暗号鍵」をありとあらゆる所で使用します。
自分専用の「暗号鍵」・「公開鍵（パブキー）」セットを作成してください。

+ 「公開鍵（パブキー）」 - チームメンバーや世界中の人と広く共有してください
+ 「暗号鍵（プライベートキー）」 - 誰にも絶対に見せないで、自分だけがアクセス出来る所に安全に保管してください
(自分専用の GoogleDrive へ、バックアップを推奨します)
+ Mac での手順を示します。Linux でもほぼ同様ですので必要な方は調べてみてください

## ED25519 暗号鍵作成 日本語ガイド

### 目的

ED25519 方式で **パスフレーズ付き** の SSH 鍵を作成し、**公開鍵** を GitHub に登録。動作確認後、Google Chat に投稿してサーバー権限付与の手続きを進めます。

### 1) SSH 鍵を作る

**ターミナル**で次を実行：

```bash
ssh-keygen -t ed25519 -a 100 -C "GitHub: <あなたのユーザー名> (Mac)"
```

* 保存先はそのまま **Enter**（既定: `~/.ssh/id_ed25519`）
* パスフレーズは **必ず設定**（空欄にしない）

### 2) **公開鍵** をコピー

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

* 公開鍵は `ssh-ed25519` で始まる **1 行の文字列** です。

### 3) GitHub に公開鍵を登録

1. GitHub → **Settings** → **SSH and GPG keys** → **New SSH key**
2. **Title:** 例 `Mac`
3. **Key type:** Authentication Key（既定）
4. **Key:** クリップボードから貼り付け → **Add SSH key**

（GitHub CLI を使う場合）

```bash
gh auth login
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Mac"
```

### 4) 動作確認

```bash
ssh -T git@github.com
```

* 初回は `yes` と入力して続行。
* 期待される表示：

```
Hi <あなたのユーザー名>! You've successfully authenticated, but GitHub does not provide shell access.
```

### 5) Google Chat に投稿（サーバー登録用）

以下の部屋に投稿してください：

プロジェクト以心伝心(事前の招待が必要です)：**[https://mail.google.com/chat/u/0/#chat/space/AAAAUqO4zBc](https://mail.google.com/chat/u/0/#chat/space/AAAAUqO4zBc)**

次をコピペして自分の情報に置き換えます：

```
GitHub: <あなたの github ユーザー名>
SSH Public Key:
< `cat ~/.ssh/id_ed25519.pub` コマンドで表示された内容をそのまま貼り付け >
```

> ✅ 共有してよいのは **`.pub` の行だけ**。
> ❌ **`~/.ssh/id_ed25519`（秘密鍵）** は絶対に共有しないでください！！

### 6) Git リモートを SSH に変更（推奨）

HTTPS のリポジトリを SSH に切り替える場合：

```bash
git remote -v
# org/repo は実際のパスに置換
git remote set-url origin git@github.com:org/repo.git
```

### よくあるハマりどころ

* **Permission denied (publickey)**

  * 公開鍵が GitHub に登録されているか確認。
  * 権限を調整：

    ```bash
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    ```
  * デバッグ：

    ```bash
    ssh -vT git@github.com
    ```


---

## 2) English Guide

### Goal

Create a secure SSH key (ED25519, **with a passphrase**), add the **public** key to GitHub, verify it works, then post your details in our Google Chat so we can grant server access.

### 1) Create your SSH key

Open **Terminal** and run:

```bash
ssh-keygen -t ed25519 -a 100 -C "GitHub: <your-username> (Mac)"
```

* When asked for file location, press **Enter** (default: `~/.ssh/id_ed25519`)
* When asked for a passphrase, **enter a strong passphrase** (do not leave blank)

### 2) Copy your **public** key

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

* Your public key is one long line starting with `ssh-ed25519`.

### 3) Add the public key to GitHub

1. GitHub → **Settings** → **SSH and GPG keys** → **New SSH key**
2. **Title:** e.g. `Mac`
3. **Key type:** Authentication Key (default)
4. **Key:** paste from clipboard → **Add SSH key**

*(If you use GitHub CLI:)*

```bash
gh auth login
gh ssh-key add ~/.ssh/id_ed25519.pub --title "Mac"
```

### 4) Verify it works

```bash
ssh -T git@github.com
```

* First time: type `yes` to continue.
* Expected:

```
Hi <your-username>! You've successfully authenticated, but GitHub does not provide shell access.
```

### 5) Post to Google Chat (for server registration)

Open this room and post the following:

Chat room: **[https://mail.google.com/chat/u/0/#chat/space/AAAAUqO4zBc](https://mail.google.com/chat/u/0/#chat/space/AAAAUqO4zBc)**

Copy-paste this template and fill in your info:

```
GitHub: <your-username>
SSH Public Key:
<PASTE THE ENTIRE LINE FROM ~/.ssh/id_ed25519.pub>
```

> ✅ Share **only** the `.pub` line.
> ❌ Never share `~/.ssh/id_ed25519` (private key).

### 6) Use SSH for Git remotes (recommended)

If your repo is on HTTPS, switch to SSH:

```bash
git remote -v
# Replace org/repo with your path
git remote set-url origin git@github.com:org/repo.git
```

### Quick fixes

* **Permission denied (publickey)**

  * Make sure your public key is on GitHub.
  * Check files and permissions:

    ```bash
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_ed25519
    chmod 644 ~/.ssh/id_ed25519.pub
    ```
  * Debug:

    ```bash
    ssh -vT git@github.com
    ```
* **Passphrase prompts**
  You’ll be asked once after each reboot; it’s cached for the login session.

