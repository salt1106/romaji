import Foundation

struct RequestLogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let model: String
    let endpoint: String
    let input: String
    let output: String?
    let error: String?
    let statusCode: Int?
    let latencyMilliseconds: Int?
    let inputTokens: Int?
    let outputTokens: Int?

    var succeeded: Bool { error == nil }

    init(
        id: UUID,
        date: Date,
        model: String,
        endpoint: String,
        input: String,
        output: String?,
        error: String?,
        statusCode: Int?,
        latencyMilliseconds: Int? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.model = model
        self.endpoint = endpoint
        self.input = input
        self.output = output
        self.error = error
        self.statusCode = statusCode
        self.latencyMilliseconds = latencyMilliseconds
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

@MainActor
final class RequestLogStore: ObservableObject {
    static let shared = RequestLogStore()

    @Published private(set) var entries: [RequestLogEntry] = []

    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = base.appendingPathComponent("Romaji", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("request-log.json")
        load()
    }

    func add(_ entry: RequestLogEntry) {
        entries.insert(entry, at: 0)
        entries = Array(entries.prefix(200))
        UsageStatisticsStore.shared.record(entry)
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([RequestLogEntry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

struct UsageStatistics: Codable, Sendable {
    var requestCount = 0
    var inputTokenTotal = 0
    var outputTokenTotal = 0
    var inputCharacterTotal = 0

    var tokenTotal: Int {
        inputTokenTotal + outputTokenTotal
    }
}

@MainActor
final class UsageStatisticsStore: ObservableObject {
    static let shared = UsageStatisticsStore()

    @Published private(set) var statistics = UsageStatistics()

    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = base.appendingPathComponent("Romaji", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent("usage-statistics.json")
        load()
    }

    func record(_ entry: RequestLogEntry) {
        statistics.requestCount += 1
        statistics.inputTokenTotal += entry.inputTokens ?? 0
        statistics.outputTokenTotal += entry.outputTokens ?? 0
        statistics.inputCharacterTotal += entry.input.count
        save()
    }

    func reset() {
        statistics = UsageStatistics()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(UsageStatistics.self, from: data) else {
            return
        }
        statistics = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(statistics) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
