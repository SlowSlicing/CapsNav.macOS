import Foundation
import OSLog

final class StatisticsStore {
    private let environment: AppEnvironment
    private let fileManager: FileManager
    private let logger = AppLogger.make(category: "StatisticsStore")

    init(environment: AppEnvironment, fileManager: FileManager = .default) {
        self.environment = environment
        self.fileManager = fileManager
    }

    func ensureStatisticsFileExists(defaultStatistics: UsageStatistics = .default) throws {
        guard !fileManager.fileExists(atPath: environment.statisticsFileURL.path) else {
            return
        }

        try save(defaultStatistics)
        logger.info("Created default statistics.json at \(self.environment.statisticsFileURL.path, privacy: .public)")
    }

    func load() throws -> UsageStatistics {
        guard fileManager.fileExists(atPath: environment.statisticsFileURL.path) else {
            logger.info("Statistics file not found, returning default.")
            return .default
        }

        let data = try Data(contentsOf: environment.statisticsFileURL)
        let statistics = try JSONDecoder.capsNav().decode(UsageStatistics.self, from: data)
        logger.info("Loaded statistics from disk.")
        return statistics
    }

    func save(_ statistics: UsageStatistics) throws {
        let encoder = JSONEncoder.capsNav()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(statistics)
        try data.write(to: environment.statisticsFileURL, options: .atomic)
        logger.info("Saved statistics. totalTriggerCount=\(statistics.totalTriggerCount, privacy: .public)")
    }

    func recordTrigger(signature: String) throws {
        var statistics = try load()
        statistics.recordTrigger(signature: signature)
        try save(statistics)
    }

    func reset() throws {
        try save(.default)
        logger.info("Reset statistics to default.")
    }
}
