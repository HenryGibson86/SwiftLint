//
//  LineLengthRule.swift
//  SwiftLint
//
//  Created by JP Simard on 2015-05-16.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import SourceKittenFramework

public struct LineLengthRule: ConfigurationProviderRule {
    public var configuration = RuleLevelsConfig(warning: 100, error: 200)

    public init() {}

    public static let description = RuleDescription(
        identifier: "line_length",
        name: "Line Length",
        description: "Lines should not span too many characters."
    )

    public func validateFile(file: File) -> [StyleViolation] {
        return file.lines.flatMap { line in
            let length = line.content.characters.count
            for param in configuration.params where length > param.value {
                return StyleViolation(ruleDescription: self.dynamicType.description,
                    severity: param.severity,
                    location: Location(file: file.path, line: line.index),
                    reason: "Line should be \(configuration.warning.value) characters or less: " +
                    "currently \(length) characters")
            }
            return nil
        }
    }
}
