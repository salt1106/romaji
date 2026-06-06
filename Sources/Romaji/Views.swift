import AppKit
import Carbon
import SwiftUI

@MainActor
final class ComposerModel: ObservableObject {
    @Published var text = ""
    @Published var isConverting = false
    @Published var errorMessage: String?

    var onDismiss: (() -> Void)?
    var onInsert: ((String) -> Void)?
    var onSizeChange: ((CGSize) -> Void)?

    var visualLineCount: Int {
        let newlineLines = max(text.components(separatedBy: "\n").count, 1)
        let longestLine = text
            .components(separatedBy: "\n")
            .map(\.count)
            .max() ?? 0
        let estimatedWrappedLines = max(Int(ceil(Double(longestLine) / 58.0)), 1)
        let estimatedLines = max(newlineLines, estimatedWrappedLines)
        let cap = AppSettings.shared.fullTextModeEnabled ? 8 : 5
        return min(max(estimatedLines, 1), cap)
    }

    var isFullTextModeActive: Bool {
        AppSettings.shared.fullTextModeEnabled && visualLineCount > 1
    }

    var inputHeight: CGFloat {
        34 + CGFloat(visualLineCount - 1) * 26
    }

    var panelHeight: CGFloat {
        let hintHeight: CGFloat = AppSettings.shared.showShortcutHints ? 34 : 0
        return 68 + CGFloat(visualLineCount - 1) * 26 + hintHeight
    }

    var panelWidth: CGFloat {
        isFullTextModeActive ? 760 : 680
    }

    var panelSize: CGSize {
        CGSize(width: panelWidth, height: panelHeight)
    }

    func reset() {
        text = ""
        isConverting = false
        errorMessage = nil
    }

    func submit() {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !isConverting else { return }

        isConverting = true
        errorMessage = nil
        Task {
            let startedAt = ContinuousClock.now
            do {
                let settings = AppSettings.shared.snapshot
                let result = try await ConversionService().convert(
                    source,
                    settings: settings
                )
                RequestLogStore.shared.add(
                    RequestLogEntry(
                        id: UUID(),
                        date: Date(),
                        model: settings.model,
                        endpoint: settings.endpoint,
                        input: source,
                        output: result.text,
                        error: nil,
                        statusCode: result.statusCode,
                        latencyMilliseconds: startedAt.duration(to: .now).milliseconds,
                        inputTokens: result.inputTokens,
                        outputTokens: result.outputTokens
                    )
                )
                isConverting = false
                onInsert?(result.text)
            } catch {
                let settings = AppSettings.shared.snapshot
                let statusCode: Int?
                if case let ConversionService.ConversionError.server(code, _) = error {
                    statusCode = code
                } else {
                    statusCode = nil
                }
                RequestLogStore.shared.add(
                    RequestLogEntry(
                        id: UUID(),
                        date: Date(),
                        model: settings.model,
                        endpoint: settings.endpoint,
                        input: source,
                        output: nil,
                        error: error.localizedDescription,
                        statusCode: statusCode,
                        latencyMilliseconds: startedAt.duration(to: .now).milliseconds
                    )
                )
                isConverting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ComposerView: View {
    @ObservedObject var model: ComposerModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let copy = settings.copy

        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse, isActive: model.isConverting)

                ZStack(alignment: .topLeading) {
                    if model.text.isEmpty {
                        Text(copy.placeholder)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 5)
                            .padding(.leading, 5)
                    }

                    ComposerTextView(
                        text: $model.text,
                        onSubmit: model.submit,
                        onCancel: { model.onDismiss?() }
                    )
                    .frame(height: model.inputHeight)
                    .disabled(model.isConverting)
                }

                if model.isConverting {
                    ConversionActivityView()
                } else if let errorMessage = model.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .help(errorMessage)
                } else if !model.text.isEmpty {
                    Button {
                        model.text = ""
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }

                Button {
                    model.submit()
                } label: {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isConverting)
                .symbolEffect(.pulse, isActive: model.isConverting)
            }

            if settings.showShortcutHints {
                HStack {
                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    } else if model.isConverting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text(copy.converting)
                        }
                        .foregroundStyle(.tint)
                    } else {
                        Text(copy.pressToOpen(settings.openShortcut.displayName))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("esc")
                        .keyboardHint()
                    Text(copy.shortcutClose)
                        .foregroundStyle(.secondary)
                    Text("↵")
                        .keyboardHint()
                    Text(copy.shortcutNewLine)
                        .foregroundStyle(.secondary)
                    Text(settings.submitShortcut.displayName)
                        .keyboardHint()
                    Text(copy.shortcutSubmit)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: model.panelWidth, height: model.panelHeight)
        .glassEffect(
            .regular.tint(.accentColor.opacity(model.isConverting ? 0.18 : 0.08)),
            in: .rect(cornerRadius: 24)
        )
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .animation(.snappy(duration: 0.25), value: model.visualLineCount)
        .animation(.snappy(duration: 0.25), value: model.panelWidth)
        .animation(.easeInOut(duration: 0.2), value: model.isConverting)
        .onChange(of: model.visualLineCount, initial: true) {
            model.onSizeChange?(model.panelSize)
        }
        .onChange(of: settings.fullTextModeEnabled) {
            model.onSizeChange?(model.panelSize)
        }
        .onChange(of: settings.showShortcutHints) {
            model.onSizeChange?(model.panelSize)
        }
    }
}

struct ConversionActivityView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.tint)
                    .frame(width: 5, height: 5)
                    .scaleEffect(isAnimating ? 1 : 0.45)
                    .opacity(isAnimating ? 1 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.14),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 30, height: 30)
        .glassEffect(.regular.tint(.accentColor.opacity(0.2)), in: .circle)
        .onAppear { isAnimating = true }
    }
}

struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = CommandTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .systemFont(ofSize: 20, weight: .medium)
        textView.textContainerInset = NSSize(width: 2, height: 3)
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CommandTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.onSubmit = onSubmit
        textView.onCancel = onCancel
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

final class CommandTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if AppSettings.shared.submitShortcut.matches(event) {
            onSubmit?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if AppSettings.shared.submitShortcut.matches(event) {
            onSubmit?()
            return
        }
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        super.keyDown(with: event)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var loginItem = LoginItemManager.shared

    var body: some View {
        let copy = settings.copy

        Form {
            Section(copy.general) {
                Toggle(copy.enableRomaji, isOn: $settings.isEnabled)
                Picker(copy.languageLabel, selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                Toggle(
                    copy.launchAtLogin,
                    isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    )
                )
                if loginItem.requiresApproval {
                    Label(copy.loginApproval, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if let errorMessage = loginItem.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(copy.useOpenRouterDefaults) {
                    settings.useOpenRouter()
                }
                HStack {
                    SecureField(copy.apiKey, text: $settings.apiKey)
                    if !settings.apiKey.isEmpty {
                        Button(copy.clearAPIKey) {
                            settings.apiKey = ""
                        }
                        .controlSize(.small)
                    }
                }
                TextField(copy.model, text: $settings.model)
                TextField(copy.endpoint, text: $settings.endpoint)
            } header: {
                Text("AI API")
            } footer: {
                Text(copy.aiFooter)
            }

            Section {
                TextEditor(text: $settings.systemPrompt)
                    .font(.body.monospaced())
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
                Button(copy.resetPrompt) {
                    settings.resetSystemPrompt()
                }
            } header: {
                Text(copy.systemPrompt)
            } footer: {
                Text(copy.promptFooter)
            }

            Section(copy.shortcuts) {
                LabeledContent(copy.openComposer) {
                    ShortcutRecorder(shortcut: $settings.openShortcut)
                }
                LabeledContent(copy.convertAndInsert) {
                    ShortcutRecorder(shortcut: $settings.submitShortcut)
                }
                LabeledContent(copy.shortcutClose, value: "Esc")
                Button(copy.resetShortcuts) {
                    settings.resetShortcuts()
                }
            }

            Section {
                Toggle(copy.fullTextMode, isOn: $settings.fullTextModeEnabled)
                Toggle(copy.showShortcutHints, isOn: $settings.showShortcutHints)
                Toggle(copy.keepConvertedTextInClipboard, isOn: $settings.keepConvertedTextInClipboard)
            } header: {
                Text(copy.composer)
            } footer: {
                Text(copy.composerFooter)
            }

            Section {
                LabeledContent(
                    copy.accessibility,
                    value: TextInserter.hasAccessibilityPermission ? copy.allowed : copy.notAllowed
                )
                Button(copy.allowAccessibility) {
                    TextInserter.requestAccessibilityPermission()
                }
                .disabled(TextInserter.hasAccessibilityPermission)
            } footer: {
                Text(copy.accessibilityFooter)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560, height: 760)
        .onAppear { loginItem.refresh() }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: AppShortcut

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.bezelStyle = .rounded
        button.target = context.coordinator
        button.action = #selector(Coordinator.startRecording(_:))
        button.onRecord = { shortcut in
            context.coordinator.shortcut = shortcut
        }
        context.coordinator.button = button
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.shortcut = shortcut
        context.coordinator.button = button
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut)
    }

    final class Coordinator: NSObject {
        @Binding var shortcut: AppShortcut
        weak var button: ShortcutRecorderButton?

        init(shortcut: Binding<AppShortcut>) {
            _shortcut = shortcut
        }

        @MainActor @objc func startRecording(_ sender: ShortcutRecorderButton) {
            sender.isRecording = true
            sender.window?.makeFirstResponder(sender)
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var shortcut: AppShortcut = .openDefault {
        didSet { updateTitle() }
    }
    var onRecord: ((AppShortcut) -> Void)?
    var isRecording = false {
        didSet { updateTitle() }
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == kVK_Escape {
            isRecording = false
            return
        }
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }
        let newShortcut = AppShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        shortcut = newShortcut
        onRecord?(newShortcut)
        isRecording = false
    }

    private func updateTitle() {
        title = isRecording ? AppSettings.shared.copy.pressShortcut : shortcut.displayName
    }
}

struct RequestLogView: View {
    @ObservedObject private var store = RequestLogStore.shared
    @ObservedObject private var usageStore = UsageStatisticsStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var copiedID: String?
    @State private var showClearConfirmation = false
    @State private var showUsageResetConfirmation = false

    var body: some View {
        let text = settings.copy
        let usage = usageStore.statistics

        VStack(spacing: 0) {
            HStack {
                Text(text.requestLogHeading)
                    .font(.title2.bold())
                Spacer()
                Button(text.resetUsage) {
                    showUsageResetConfirmation = true
                }
                .disabled(usage.requestCount == 0 && usage.tokenTotal == 0 && usage.inputCharacterTotal == 0)
                Button(text.clearAll, role: .destructive) {
                    showClearConfirmation = true
                }
                .disabled(store.entries.isEmpty)
            }
            .padding()

            UsageStatisticsCard(usage: usage)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if store.entries.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.tint)
                        .symbolEffect(.pulse)
                    Text(text.noRequests)
                        .font(.title3.bold())
                    Text(text.noRequestsDetail)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
                .glassEffect(.regular.tint(.accentColor.opacity(0.08)), in: .rect(cornerRadius: 24))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.entries) { entry in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            statusPill(entry)
                            Text(Self.timestampFormatter.string(from: entry.date))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(entry.model)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        CopyableLogText(
                            title: text.input,
                            text: entry.input,
                            monospaced: true,
                            copied: copiedID == "\(entry.id)-input"
                        ) {
                            copy(entry.input, id: "\(entry.id)-input")
                        }

                        if let output = entry.output {
                            CopyableLogText(
                                title: text.output,
                                text: output,
                                copied: copiedID == "\(entry.id)-output"
                            ) {
                                copy(output, id: "\(entry.id)-output")
                            }
                        }
                        if let error = entry.error {
                            CopyableLogText(title: text.error, text: error, isError: true) {}
                        }

                        HStack(spacing: 18) {
                            metric(text.latency, latency(entry.latencyMilliseconds))
                            metric(text.inputTokens, entry.inputTokens.map(String.init) ?? "—")
                            metric(text.outputTokens, entry.outputTokens.map(String.init) ?? "—")
                            Spacer()
                            Text(entry.endpoint)
                                .lineLimit(1)
                                .foregroundStyle(.tertiary)
                        }
                        .font(.caption.monospacedDigit())
                    }
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .background {
            LinearGradient(
                colors: [.accentColor.opacity(0.06), .clear, .accentColor.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .alert(text.clearLogsTitle, isPresented: $showClearConfirmation) {
            Button(text.cancel, role: .cancel) {}
            Button(text.clearAll, role: .destructive) { store.clear() }
        } message: {
            Text(text.cannotUndo)
        }
        .alert(text.resetUsageTitle, isPresented: $showUsageResetConfirmation) {
            Button(text.cancel, role: .cancel) {}
            Button(text.resetUsage, role: .destructive) { usageStore.reset() }
        } message: {
            Text(text.cannotUndo)
        }
    }

    private func statusPill(_ entry: RequestLogEntry) -> some View {
        Label(
            entry.statusCode.map(String.init) ?? (entry.succeeded ? "OK" : "ERROR"),
            systemImage: entry.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(entry.succeeded ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular.tint(entry.succeeded ? .green.opacity(0.12) : .red.opacity(0.12)), in: .capsule)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        Text("\(title): \(value)")
            .foregroundStyle(.secondary)
    }

    private func latency(_ milliseconds: Int?) -> String {
        guard let milliseconds else { return "—" }
        return String(format: "%.2f s", Double(milliseconds) / 1_000)
    }

    private func copy(_ text: String, id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedID == id { copiedID = nil }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return formatter
    }()
}

struct UsageStatisticsCard: View {
    let usage: UsageStatistics
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let text = settings.copy

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(text.usageStatistics, systemImage: "chart.bar.xaxis")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                alignment: .leading,
                spacing: 12
            ) {
                usageMetric(text.inputTokens, usage.inputTokenTotal)
                usageMetric(text.outputTokens, usage.outputTokenTotal)
                usageMetric(text.tokenTotal, usage.tokenTotal)
                usageMetric(text.inputCharacters, usage.inputCharacterTotal)
                usageMetric(text.requests, usage.requestCount)
            }
        }
        .padding(14)
        .glassEffect(.regular.tint(.accentColor.opacity(0.08)), in: .rect(cornerRadius: 18))
    }

    private func usageMetric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(value))
                .font(.title3.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

struct CopyableLogText: View {
    let title: String
    let text: String
    var monospaced = false
    var copied = false
    var isError = false
    let onCopy: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        let copy = settings.copy

        Button(action: onCopy) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label(copied ? copy.copied : copy.clickToCopy, systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(copied ? Color.green : Color.secondary)
                }
                Text(text)
                    .font(monospaced ? .body.monospaced() : .body)
                    .foregroundStyle(isError ? .red : .primary)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
            .padding(10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

private extension Duration {
    var milliseconds: Int {
        let components = self.components
        return Int(components.seconds * 1_000)
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}

private extension View {
    func keyboardHint() -> some View {
        self
            .fontDesign(.monospaced)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .glassEffect(.regular, in: .rect(cornerRadius: 7))
    }
}
