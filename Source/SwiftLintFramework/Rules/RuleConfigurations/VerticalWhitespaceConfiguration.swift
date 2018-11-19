public struct VerticalWhitespaceConfiguration: RuleConfiguration, Equatable {
    private(set) var severityConfiguration = SeverityConfiguration(.warning)
    private(set) var maxEmptyLines: Int

    public var consoleDescription: String {
        return severityConfiguration.consoleDescription + ", max_empty_lines: \(maxEmptyLines)"
    }

    public init(maxEmptyLines: Int) {
        self.maxEmptyLines = maxEmptyLines
    }

    public mutating func apply(configuration: Any) throws {
        guard let configuration = configuration as? [String: Any] else {
            throw ConfigurationError.unknownConfiguration
        }

        if let maxEmptyLines = configuration["max_empty_lines"] as? Int {
            self.maxEmptyLines = maxEmptyLines
        }

        if let severityString = configuration["severity"] as? String {
            try severityConfiguration.apply(configuration: severityString)
        }
    }
}
