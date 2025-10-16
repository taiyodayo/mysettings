# mysettings

just a repo to setup my linux boxes. nothing special here.
(PLEASE NOTE BY RUNNING THIS, YOU WILL GRANT ACCESS TO ME!)

# Mac のキッティング

最初に homebrew を設定します。
[https://brew.sh]

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

git コマンドがインストールされたので、このレポをクローンします (ssh -A で主マシンからログインして実行すると便利です)

```
git clone git@github.com:taiyodayo/mysettings.git
```

セットアップを実行します
```
cd ~/mysettings
./setup_mac_all.sh
```

Mac の 環境設定 - 共有 から Remote login 、画面共有を有効にしておくと便利です
```
# SSH/VNCはCLIでは有効にできない。システム環境設定を開く【共有】を選択
open "x-apple.systempreferences:com.apple.settings.Sharing"
```

以上で、研究室の殆どの制作物はビルド出来るようになっているはずです。

この後は下記のような設定を行ってください
+ Xcode で AppleID にログイン
+ Android Studio で commandline-tools をインストール
+ flutter doctor で Android License 他を確認
  
