import AppKit
import Carbon
import Foundation
import ServiceManagement

struct AppShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiersRaw: UInt

    static let openDefault = AppShortcut(
        keyCode: UInt32(kVK_Return),
        modifiers: [.option]
    )
    static let submitDefault = AppShortcut(
        keyCode: UInt32(kVK_Return),
        modifiers: [.command]
    )

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRaw = modifiers.intersection(Self.relevantModifiers).rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRaw).intersection(Self.relevantModifiers)
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayName: String {
        "\(modifierDisplay)\(keyDisplay)"
    }

    func matches(_ event: NSEvent) -> Bool {
        UInt32(event.keyCode) == keyCode
            && event.modifierFlags.intersection(Self.relevantModifiers) == modifiers
    }

    private var modifierDisplay: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }

    private var keyDisplay: String {
        if let letter = Self.letterKeyNames[Int(keyCode)] {
            return letter
        }
        if let special = Self.specialKeyNames[Int(keyCode)] {
            return special
        }
        return switch Int(keyCode) {
        case kVK_Return: "Enter"
        case kVK_Space: "Space"
        case kVK_Escape: "Esc"
        case kVK_Tab: "Tab"
        case kVK_Delete: "Delete"
        default:
            "Key \(keyCode)"
        }
    }

    private static let relevantModifiers: NSEvent.ModifierFlags = [
        .command,
        .option,
        .control,
        .shift
    ]

    private static let letterKeyNames: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z"
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_UpArrow: "↑",
        kVK_DownArrow: "↓",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→"
    ]
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case japanese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .japanese: "日本語"
        }
    }
}

struct AppCopy {
    let language: AppLanguage

    var enableRomaji: String { language == .japanese ? "Romajiを有効にする" : "Enable Romaji" }
    var openComposer: String { language == .japanese ? "入力パネルを開く" : "Open Composer" }
    var settings: String { language == .japanese ? "設定..." : "Settings..." }
    var requestLog: String { language == .japanese ? "送信ログ..." : "Request Log..." }
    var quit: String { language == .japanese ? "終了" : "Quit" }
    var settingsTitle: String { language == .japanese ? "Romaji 設定" : "Romaji Settings" }
    var requestLogTitle: String { language == .japanese ? "Romaji 送信ログ" : "Romaji Request Log" }
    var placeholder: String { language == .japanese ? "ローマ字のまま入力..." : "romaji de sono mama nyuuryoku..." }
    var helpTitle: String { language == .japanese ? "Romaji 入力パネル" : "Romaji Composer" }
    var shortcutOpen: String { language == .japanese ? "入力パネルを開く" : "Open composer" }
    var shortcutNewLine: String { language == .japanese ? "改行" : "New line" }
    var shortcutSubmit: String { language == .japanese ? "変換して挿入" : "Convert & insert" }
    var shortcutClose: String { language == .japanese ? "閉じる" : "Close" }
    var fullTextHelp: String {
        language == .japanese
            ? "Full Text Modeを有効にすると、入力が折り返し・複数行になったときにパネルが広がります。"
            : "Full Text Mode expands the panel when your input wraps or spans multiple lines."
    }
    var general: String { language == .japanese ? "一般" : "General" }
    var languageLabel: String { language == .japanese ? "言語" : "Language" }
    var launchAtLogin: String { language == .japanese ? "ログイン時に起動" : "Launch at Login" }
    var loginApproval: String {
        language == .japanese
            ? "システム設定 > 一般 > ログイン項目で承認が必要です。"
            : "Approval is required in System Settings > General > Login Items."
    }
    var useOpenRouterDefaults: String { language == .japanese ? "OpenRouterの初期設定を使う" : "Use OpenRouter defaults" }
    var apiKey: String { language == .japanese ? "APIキー" : "API Key" }
    var clearAPIKey: String { language == .japanese ? "APIキーを消去" : "Clear API Key" }
    var model: String { language == .japanese ? "モデル" : "Model" }
    var endpoint: String { language == .japanese ? "エンドポイント" : "Endpoint" }
    var aiFooter: String {
        language == .japanese
            ? "OpenAI互換のchat completions APIで動作します。上のモデル名を使って指定エンドポイントに送信します。"
            : "Works with OpenAI-compatible chat completions APIs. Requests are sent to the endpoint using the model name above."
    }
    var systemPrompt: String { language == .japanese ? "送信プロンプト" : "System Prompt" }
    var resetPrompt: String { language == .japanese ? "初期プロンプトに戻す" : "Reset Prompt" }
    var promptFooter: String {
        language == .japanese
            ? "変換リクエストのsystemメッセージ全文です。ここを変えるとAIの変換方針が変わります。"
            : "This is the full system message sent with each conversion request. Changing it changes how the AI converts romaji."
    }
    var shortcuts: String { language == .japanese ? "ショートカット" : "Shortcuts" }
    var convertAndInsert: String { language == .japanese ? "変換して挿入" : "Convert & insert" }
    var resetShortcuts: String { language == .japanese ? "ショートカットをリセット" : "Reset Shortcuts" }
    var composer: String { language == .japanese ? "入力パネル" : "Composer" }
    var fullTextMode: String { language == .japanese ? "Full Text Mode" : "Full Text Mode" }
    var showShortcutHints: String { language == .japanese ? "ショートカット説明を表示" : "Show Shortcut Hints" }
    var composerFooter: String {
        language == .japanese
            ? "Full Text Modeは、ローマ字入力が折り返し・複数行になったときに入力パネルを広げます。ショートカット説明はパネル下部に表示できます。"
            : "Full Text Mode expands the composer when romaji wraps or spans multiple lines. Shortcut hints can appear at the bottom of the panel."
    }
    var accessibility: String { language == .japanese ? "アクセシビリティ" : "Accessibility" }
    var allowed: String { language == .japanese ? "許可済み" : "Allowed" }
    var notAllowed: String { language == .japanese ? "未許可" : "Not allowed" }
    var allowAccessibility: String { language == .japanese ? "アクセシビリティアクセスを許可" : "Allow accessibility access" }
    var accessibilityFooter: String {
        language == .japanese
            ? "許可ダイアログはこのボタンを押したときだけ表示します。APIキーはこのアプリの設定にローカル保存されます。"
            : "The permission prompt appears only after pressing this button. The API key is stored locally in this app's settings."
    }
    var pressShortcut: String { language == .japanese ? "ショートカットを押してください..." : "Press shortcut..." }
    var requestLogHeading: String { language == .japanese ? "送信ログ" : "Request Log" }
    var clearAll: String { language == .japanese ? "すべて削除" : "Clear All" }
    var noRequests: String { language == .japanese ? "送信ログはまだありません" : "No Requests Yet" }
    var noRequestsDetail: String {
        language == .japanese
            ? "成功・失敗した変換リクエストがここに表示されます。"
            : "Completed and failed conversions will appear here."
    }
    var input: String { language == .japanese ? "変換前" : "Input" }
    var output: String { language == .japanese ? "変換後" : "Output" }
    var error: String { language == .japanese ? "エラー" : "Error" }
    var latency: String { language == .japanese ? "待ち時間" : "Latency" }
    var inputTokens: String { language == .japanese ? "入力トークン" : "Input tokens" }
    var outputTokens: String { language == .japanese ? "出力トークン" : "Output tokens" }
    var tokenTotal: String { language == .japanese ? "総トークン" : "Total tokens" }
    var usageStatistics: String { language == .japanese ? "使用量統計" : "Usage Statistics" }
    var inputCharacters: String { language == .japanese ? "入力文字数" : "Input characters" }
    var requests: String { language == .japanese ? "送信回数" : "Requests" }
    var resetUsage: String { language == .japanese ? "統計をリセット" : "Reset Usage" }
    var resetUsageTitle: String { language == .japanese ? "使用量統計をリセットしますか？" : "Reset usage statistics?" }
    var clearLogsTitle: String { language == .japanese ? "送信ログをすべて削除しますか？" : "Clear all request logs?" }
    var cancel: String { language == .japanese ? "キャンセル" : "Cancel" }
    var cannotUndo: String { language == .japanese ? "この操作は取り消せません。" : "This action cannot be undone." }
    var copied: String { language == .japanese ? "コピー済み" : "Copied" }
    var clickToCopy: String { language == .japanese ? "クリックしてコピー" : "Click to copy" }
    var converting: String { language == .japanese ? "日本語に変換中" : "Converting to Japanese" }

    func pressToOpen(_ shortcut: String) -> String {
        language == .japanese ? "\(shortcut)で開く" : "Press \(shortcut) to open"
    }
}

@MainActor
final class AppSettings: ObservableObject {
    struct Snapshot: Sendable {
        let endpoint: String
        let model: String
        let apiKey: String
        let systemPrompt: String
    }

    static let shared = AppSettings()

    @Published var endpoint: String {
        didSet { defaults.set(endpoint, forKey: Keys.endpoint) }
    }

    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    @Published var apiKey: String {
        didSet { defaults.set(apiKey, forKey: Keys.apiKey) }
    }

    @Published var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: Keys.systemPrompt) }
    }

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            NotificationCenter.default.post(name: .romajiEnabledChanged, object: nil)
        }
    }

    @Published var openShortcut: AppShortcut {
        didSet {
            save(openShortcut, forKey: Keys.openShortcut)
            NotificationCenter.default.post(name: .romajiShortcutChanged, object: nil)
        }
    }

    @Published var submitShortcut: AppShortcut {
        didSet {
            save(submitShortcut, forKey: Keys.submitShortcut)
            NotificationCenter.default.post(name: .romajiShortcutChanged, object: nil)
        }
    }

    @Published var fullTextModeEnabled: Bool {
        didSet { defaults.set(fullTextModeEnabled, forKey: Keys.fullTextModeEnabled) }
    }

    @Published var showShortcutHints: Bool {
        didSet { defaults.set(showShortcutHints, forKey: Keys.showShortcutHints) }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            NotificationCenter.default.post(name: .romajiLanguageChanged, object: nil)
        }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let endpoint = "endpoint"
        static let model = "model"
        static let apiKey = "api-key"
        static let systemPrompt = "system-prompt"
        static let isEnabled = "is-enabled"
        static let openShortcut = "open-shortcut"
        static let submitShortcut = "submit-shortcut"
        static let fullTextModeEnabled = "full-text-mode-enabled"
        static let showShortcutHints = "show-shortcut-hints"
        static let language = "language"
    }

    private init() {
        endpoint = defaults.string(forKey: Keys.endpoint)
            ?? "https://api.openai.com/v1/chat/completions"
        model = defaults.string(forKey: Keys.model) ?? "gpt-4.1-mini"
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        systemPrompt = defaults.string(forKey: Keys.systemPrompt)
            ?? ConversionService.defaultSystemPrompt
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        openShortcut = Self.loadShortcut(
            defaults,
            key: Keys.openShortcut,
            fallback: .openDefault
        )
        submitShortcut = Self.loadShortcut(
            defaults,
            key: Keys.submitShortcut,
            fallback: .submitDefault
        )
        fullTextModeEnabled = defaults.object(forKey: Keys.fullTextModeEnabled) as? Bool ?? true
        showShortcutHints = defaults.object(forKey: Keys.showShortcutHints) as? Bool ?? false
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .english
    }

    var snapshot: Snapshot {
        Snapshot(
            endpoint: endpoint,
            model: model,
            apiKey: apiKey,
            systemPrompt: systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ConversionService.defaultSystemPrompt
                : systemPrompt
        )
    }

    var copy: AppCopy {
        AppCopy(language: language)
    }

    func useOpenRouter() {
        endpoint = "https://openrouter.ai/api/v1/chat/completions"
        if !model.contains("/") {
            model = "openai/gpt-4.1-mini"
        }
    }

    func resetShortcuts() {
        openShortcut = .openDefault
        submitShortcut = .submitDefault
    }

    func resetSystemPrompt() {
        systemPrompt = ConversionService.defaultSystemPrompt
    }

    private func save(_ shortcut: AppShortcut, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadShortcut(
        _ defaults: UserDefaults,
        key: String,
        fallback: AppShortcut
    ) -> AppShortcut {
        guard let data = defaults.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(AppShortcut.self, from: data) else {
            return fallback
        }
        return shortcut
    }
}

extension Notification.Name {
    static let romajiEnabledChanged = Notification.Name("romaji-enabled-changed")
    static let romajiShortcutChanged = Notification.Name("romaji-shortcut-changed")
    static let romajiLanguageChanged = Notification.Name("romaji-language-changed")
}

@MainActor
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published var errorMessage: String?

    private init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }
}
