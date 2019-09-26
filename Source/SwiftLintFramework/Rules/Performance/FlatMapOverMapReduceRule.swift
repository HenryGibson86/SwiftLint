import SourceKittenFramework

public struct FlatMapOverMapReduceRule: CallPairRule, OptInRule, ConfigurationProviderRule, AutomaticTestableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "flatmap_over_map_reduce",
        name: "FlatMap over map and reduce",
        description: "Prefer `flatMap` over `map` followed by `reduce([], +)`.",
        kind: .performance,
        nonTriggeringExamples: [
            "let foo = bar.map { $0.count }.reduce(0, +)",
            "let foo = bar.flatMap { $0.array }"
        ],
        triggeringExamples: [
            "let foo = ↓bar.map { $0.array }.reduce([], +)"
        ]
    )

    public func validate(file: File) -> [StyleViolation] {
        let pattern = "[\\}\\)]\\s*\\.reduce\\s*\\(\\[\\s*\\],\\s*\\+\\s*\\)"
        return validate(file: file, pattern: pattern, patternSyntaxKinds: [.identifier],
                        callNameSuffix: ".map", severity: configuration.severity)
    }
}
