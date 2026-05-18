# mysettings

mailab マシンのキッティングスクリプト。
**注意:** このスクリプトを実行すると、taiyo の GitHub ED25519 鍵が `authorized_keys` に追加されます。

## エントリーポイント (新しい機械でこれを実行する)

リポをクローンして、プラットフォームに合わせて **どちらか一つ** を実行:

| プラットフォーム | コマンド |
|------------------|----------|
| **macOS**        | `./setup_mailab_mac.sh` |
| **Ubuntu/Linux** | `./setup_mailab_ubuntu.sh` |

その他のスクリプトは全て上記のオーケストレーターから呼ばれるサブスクリプトです — 直接実行する必要はありません。

## ディレクトリ構成

```
mysettings/
├── setup_mailab_mac.sh        ← Mac エントリーポイント
├── setup_mailab_ubuntu.sh     ← Ubuntu エントリーポイント
├── migrate_to_chezmoi.sh      ← 既存マシンを chezmoi 管理に移行 (opt-in)
├── _zshrc, _p10k.zsh          ← レガシー — chezmoi 移行完了後に削除予定
├── common/                    ← Mac / Linux 両方で使うスクリプト
│   └── setup_zsh_and_keys.sh
├── mac/                       ← Mac 専用サブスクリプト
├── ubuntu/                    ← Ubuntu 専用サブスクリプト
│   └── ubuntu_on_macbook.sh   ← MacBook ハードウェア上の Ubuntu 向け追加設定
├── cli_tools/                 ← PATH に追加される運用ツール (login_check, llms_update, check_tools, …)
├── dotfiles/                  ← chezmoi ソースディレクトリ (~/.zshrc 等のテンプレート)
├── automated/                 ← Ansible playbook 版
├── certs/                     ← mailab ルート CA 証明書
└── multipass/                 ← Multipass VM 用 cloud-init bootstrap
```

## Mac のキッティング

最初に Homebrew を設定:
[https://brew.sh]

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

git コマンドがインストールされたので、このレポをクローン (ssh -A で主マシンからログインして実行すると便利):

```
git clone git@github.com:taiyodayo/mysettings.git
```

セットアップを実行 — terminal.app を推奨 (でないと ssh 接続が切れると停止する):

```
cd ~/mysettings
./setup_mailab_mac.sh
```

Mac の 環境設定 - 共有 から Remote login 、画面共有を有効にしておくと便利:
```
open "x-apple.systempreferences:com.apple.settings.Sharing"
```

ここまでで、研究室の殆どの制作物はビルド出来るようになっているはずです。

この後は下記のような設定:
+ Xcode で AppleID にログイン
+ Android Studio で commandline-tools をインストール
+ flutter doctor で Android License 他を確認

## Ubuntu のキッティング

リポをクローン:
```
git clone git@github.com:taiyodayo/mysettings.git
cd ~/mysettings
```

セットアップを実行 (一般ユーザで起動。途中で `sudo` パスワードが聞かれます):

```
./setup_mailab_ubuntu.sh
```

完了後、ログアウト/ログインして新しい shell config と docker グループを反映させてください。

MacBook ハードウェア上で Ubuntu を動かしている場合は、追加で:
```
sudo ./ubuntu/ubuntu_on_macbook.sh
```

## chezmoi 移行 (進行中)

`~/.zshrc` / `~/.gitconfig` / `~/.p10k.zsh` 等を chezmoi で管理する移行を進めています。既存のキット済みマシンを移行するには:

```
./migrate_to_chezmoi.sh
```

詳細は `dotfiles/README.md` を参照。

## Ansible 版

`automated/` 配下に同等の Ansible playbook 一式があります。リモート fleet 向け。詳細は `automated/README.md`。
