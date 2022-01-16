# Sticky Notes

## 概要

オンラインで付箋を共有できるツールです。IISで運用します。

## 使い方

- Addボタンをクリックすると付箋紙が追加されます。
- 付箋紙をダブルクリックすると付箋紙の内容を編集することができます。
- 付箋紙は移動及びサイズ変更をすることができます。
- 付箋紙のLINKをクリックすることで指定のURLを開くことができます。
- Downloadボタンをクリックすると付箋紙のJSONデータをダウンロードすることができます。

## セットアップ

- 「build.bat」を実行すると「StickyNotes.ashx」がコンパイルされます。
- コントロールパネルの「プログラムと機能」から「Windowsの機能の有効化または無効化」を選択して「インターネットインフォメーションサービス」をインストールしてください。
- 当プログラムはWebSocketを使用しているため「インターネットインフォメーションサービス」の「WebSocketプロトコル」を併せてインストールしてください。
- インターネットインフォメーションサービス（IIS）マネージャーを起動して「Webサイトの追加」を行ってください。
- 接続するサーバーのURLに合わせて「index.html」の「socket = new WebSocket("ws://localhost:8000/StickyNotes.ashx");」を修正してください。

## 注意点

本ツールのご利用に関して当方は一切責任を負いません。