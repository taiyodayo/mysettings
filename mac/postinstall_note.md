# setup_mac_all.sh インストール完了後にする事

Macでのアプリ開発に必要なもののインストールが完了しました。
いくつかの作業はGUIでの操作が必要ですので、以下を参考にしてください

+ Android Studio - 全てデフォルトを選択しながら「次へ」で進みます。
起動したら 「SDK Manager」から Commandlin Tools のインストールが必要です。
初期設定が出来たら、最初のダイアログのメイン画面中央下、「More Actions」を選択すると「SDK Manager」が選択できます。
SDK Manager が開いたら、右側画面の「SDK Tools」タブから `Android SDK Command-line Tools (Latest)` を選択します

+ Xcode - バックグランドでインストールされます。
スクリプト実行開始してから5分ほどで、「Apple ID でログイン」を求められます
AppStoreへのログインID/PWでログインしてください - 【事前にXcodeを取得済みのアカウント】が必要です。
早い回線でも20分以上かかります。ダウンロードが完了するとアプリが開きますので、下記２点を行って下さい
・iOS 開発キットを選択
・「Xcodeの環境設定」から Apple アカウントにログイン (Mailab チーム開発者として登録済みのアカウントが必要です)

