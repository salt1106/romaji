# Romaji

[日本語 README](README.ja.md)

Romaji is a macOS 26 menu bar app that lets you type Japanese as loose romaji,
convert it with an OpenAI-compatible Chat Completions API, and insert the
converted Japanese back into the app you were using.

The app is built for quick, low-friction drafting: open the floating composer,
type romaji without worrying too much about typos or kana/kanji conversion, then
convert and paste the result.

## Features

- Floating Liquid Glass composer for macOS 26
- OpenAI-compatible API support, including OpenRouter
- Custom endpoint, model, API key, and system prompt
- Configurable shortcuts
- Accessibility-based insertion back into the previous text field
- Request log with input/output text, latency, status, and token usage
- Usage statistics for total input tokens, output tokens, total tokens, input
  characters, and request count
- English and Japanese UI
- Optional launch at login

## Requirements

- macOS 26
- An OpenAI-compatible Chat Completions API key

Xcode command line tools and Swift are only required when building from source.

## Download

Download `Romaji.app.zip` from [Releases](https://github.com/salt1106/romaji/releases).
Unzip it and move `Romaji.app` to `/Applications`.

The release build is ad-hoc signed and not notarized. On first launch, macOS may
show a warning that the developer cannot be verified. In that case, open it from
Finder with right-click or control-click, then choose `Open`.

## Build From Source

```sh
zsh scripts/build-app.sh
open /Applications/Romaji.app
```

By default, the build script uses ad-hoc signing. If you want a stable Apple
Development signature, set `ROMAJI_SIGNING_IDENTITY`:

```sh
ROMAJI_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" zsh scripts/build-app.sh
```

Using the same signing identity across builds helps macOS keep Accessibility
permission attached to the app.

## Setup

1. Launch `Romaji.app`.
2. Open the menu bar item and choose `Settings...`.
3. Enter your API key, endpoint, and model.
4. Grant Accessibility access when prompted.

OpenRouter defaults can be filled from Settings with `Use OpenRouter defaults`.

## Default Shortcuts

- `⌥ Enter`: Open or close the composer
- `Enter`: New line
- `⌘ Enter`: Convert and insert
- `Esc`: Close

Shortcuts can be changed in Settings.

## Privacy

Romaji stores settings locally using macOS user defaults. API keys are not stored
in this repository. Text you convert is sent to the API endpoint you configure.
Request logs and usage statistics are stored locally under the app support
directory for Romaji.

This is a personal open-source project. Please review and verify the source code
yourself before entering sensitive text or API keys.

## License

MIT
