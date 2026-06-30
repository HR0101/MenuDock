# MenuDock

<div align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-5.9-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge" alt="License" />
</div>

<br />

MenuDock は、Macのメニューバーからお気に入りのアプリに瞬時にアクセスできる、シンプルで洗練されたランチャーアプリです。
Dockを探す手間を省き、よく使うアプリを一つの場所にまとめることで日々の作業をよりスムーズにします。

## 主な機能 (Features)

- **ワンクリック起動:** メニューバーのアイコンをクリックするだけで、いつでもアプリを即座に開けます。
- **グローバルショートカット対応:** お好みのショートカットキーを登録すれば、マウスを使わずにどこからでもMenuDockを呼び出せます。
- **Liquid Glassデザイン:** Macのシステムに溶け込む、洗練された半透明（ガラス風）のUIを採用。ライトモード・ダークモードにも完全対応しています。
- **直感的な操作感:**
  - アプリの追加は「＋」ボタンから選ぶだけ。
  - ドラッグ＆ドロップで自由に並び替えが可能。
  - 「削除モード」にするとアイコンがアニメーションし、直感的に削除が可能です。
- **ログイン時自動起動:** 設定からオンにすれば、Macを起動した瞬間から常に常駐します。

## インストール方法 (Installation)

1. [最新の MenuDock.dmg をダウンロードする](https://github.com/HR0101/MenuDock/releases/latest/download/MenuDock.dmg)

2. ダウンロードした `MenuDock.dmg` をダブルクリックして開きます。
3. 中にある `MenuDock.app` を、隣にある `Applications` フォルダのアイコンにドラッグ＆ドロップします。
4. `アプリケーション` フォルダから MenuDock を起動してください。

*(※初回起動時に「インターネットからダウンロードされたアプリです」という確認ダイアログが出た場合は、「開く」をクリックしてください。)*

## 使い方 (Usage)

- **アプリを追加する:** MenuDockを開き、上部の `+` ボタンをクリックして登録したいアプリを選択します。
- **並び替える:** アプリアイコンをドラッグ＆ドロップすると、好きな位置に移動できます。
- **アプリを削除する:** 上部の `-` ボタンを押して「削除モード」にします。アイコンが震え出したら、右上の `×` ボタンをクリックしてリストから外せます。
- **テーマや設定の変更:** 右上の `...` (設定ボタン) から、テーマの変更（ダーク/ライト）や、ログイン時の自動起動設定、ショートカットキーの登録が可能です。

## 開発環境 (Requirements)

- macOS 14.0 or later
- Xcode 15.0 or later (for building from source)
- SwiftData & SwiftUI

## ライセンス (License)

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
