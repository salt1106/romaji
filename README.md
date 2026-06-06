# Romaji

[English README](README.en.md)

Romaji は、ローマ字のまま雑に入力した文章をAIで自然な日本語に変換し、元のアプリの入力欄へ挿入する macOS 26 用メニューバーアプリです。

かな変換・漢字変換・細かいタイプミスを気にせず、思考をそのままローマ字で打って、あとからAIに日本語へ整えてもらうための道具です。

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
- OpenAI互換 Chat Completions API のAPIキー

自分でビルドする場合だけ、Xcode Command Line Tools と Swift 6.2 以降が必要です。

OpenRouter を使う場合は、設定画面の `OpenRouterの初期設定を使う` からエンドポイントとモデルの初期値を入れられます。

おすすめモデル: `openai/gpt-5.4-mini`

理由: 応答が速く、料金も安めなので、このアプリのような短いローマ字変換用途に向いています。

Google AI Studio / Gemini API を使う場合:

- Endpoint: `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`
- モデル候補: `gemini-2.5-flash-lite`
- Google AI Studio上で `gemini-3.1-flash-lite` が使える場合は、それも高速で優秀な候補です。

Gemini系モデルも速度とコスト面で魅力がありますが、変換するテキストはGoogleのAPIへ送信されます。機密情報や個人情報を含む文章を入力する場合は注意してください。

## ダウンロードして使う

[Releases](https://github.com/salt1106/romaji/releases) から `Romaji.app.zip` をダウンロードしてください。

ZIPを展開して、`Romaji.app` を `/Applications` に移動します。

配布しているアプリは ad-hoc 署名で、公証はしていません。初回起動時に macOS が「開発元を検証できません」のような警告を出す場合があります。その場合は Finder で `Romaji.app` を右クリック、または controlクリックして、`開く` を選んでください。

## 自分でビルドする

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

個人で作っているオープンソースアプリなので、念のため、機密性の高い文章やAPIキーを入力する前に、ソースコードをご自身でも確認・検証してください。

## ライセンス

MIT
