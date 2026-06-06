# Romaji

Romaji は、ローマ字のまま雑に入力した文章をAIで自然な日本語に変換し、元のアプリの入力欄へ挿入する macOS 26 用メニューバーアプリです。

かな変換・漢字変換・細かいタイプミスを気にせず、思考をそのままローマ字で打って、あとからAIに日本語へ整えてもらうための道具です。

## いまの配布状態

現時点では「ソースコード公開」です。

そのため、GitHubからZIPをダウンロードするだけでは、すぐに起動できる完成済みアプリとしては使えません。使うには、このリポジトリを手元でビルドする必要があります。

ダウンロードするだけで使えるようにするには、別途ビルド済みの `.app` / `.zip` / `.dmg` を GitHub Releases などで配布する必要があります。さらに、macOSで警告なく使いやすくするには Developer ID 署名と公証が必要です。

## 主な機能

- macOS 26 の Liquid Glass 風フローティング入力パネル
- OpenRouter など OpenAI互換 Chat Completions API に対応
- APIキー、エンドポイント、モデル、送信プロンプトを設定可能
- ショートカットを変更可能
- 変換後の日本語を元のアプリの入力欄へ挿入
- 送信ログ
  - 変換前テキスト
  - 変換後テキスト
  - ステータス
  - 待ち時間
  - 入力/出力トークン
- 使用量統計
  - 入力トークン合計
  - 出力トークン合計
  - 総トークン
  - 入力文字数
  - 送信回数
- 英語/日本語UI切り替え
- ログイン時起動

## 必要なもの

- macOS 26
- Xcode Command Line Tools
- Swift 6.2 以降
- OpenAI互換 Chat Completions API のAPIキー

OpenRouter を使う場合は、設定画面の `OpenRouterの初期設定を使う` からエンドポイントとモデルの初期値を入れられます。

## ビルドして使う

```sh
zsh scripts/build-app.sh
open /Applications/Romaji.app
```

初回起動後、メニューバーの Romaji アイコンから `設定...` を開いて、APIキー、モデル、エンドポイントを設定してください。

## 署名について

標準では ad-hoc 署名でビルドします。

Apple Development 証明書で署名したい場合は、`ROMAJI_SIGNING_IDENTITY` を指定してください。

```sh
ROMAJI_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" zsh scripts/build-app.sh
```

同じ署名IDでビルドし続けると、macOSのアクセシビリティ権限が更新のたびに外れにくくなります。

## 初期ショートカット

- `⌥ Enter`: 入力パネルを開く/閉じる
- `Enter`: 改行
- `⌘ Enter`: 日本語へ変換して挿入
- `Esc`: 閉じる

ショートカットは設定画面から変更できます。

## 使い方

1. Romaji を起動します。
2. `⌥ Enter` で入力パネルを開きます。
3. ローマ字のまま文章を入力します。
4. `⌘ Enter` で変換します。
5. 変換後の日本語が元の入力欄へ挿入されます。

## プライバシー

APIキーや設定値は、このMac内のアプリ設定に保存されます。リポジトリにはAPIキーは含まれません。

変換するテキストは、設定したAPIエンドポイントへ送信されます。送信ログと使用量統計はローカルの Romaji 用 Application Support ディレクトリに保存されます。

## ライセンス

MIT
