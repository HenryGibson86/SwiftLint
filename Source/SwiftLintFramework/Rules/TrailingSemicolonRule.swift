//
//  TrailingSemiColonRule.swift
//  SwiftLint
//
//  Created by JP Simard on 11/17/15.
//  Copyright © 2015 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

extension File {
    fileprivate func violatingTrailingSemicolonRanges() -> [NSRange] {
        return matchPattern("(;+([^\\S\\n]?)*)+;?$",
                            excludingSyntaxKinds: SyntaxKind.commentAndStringKinds())
    }
}

public struct TrailingSemicolonRule: CorrectableRule, ConfigurationProviderRule {

    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "trailing_semicolon",
        name: "Trailing Semicolon",
        description: "Lines should not have trailing semicolons.",
        nonTriggeringExamples: [ "let a = 0\n" ],
        triggeringExamples: [
            "let a = 0↓;\n",
            "let a = 0↓;\nlet b = 1\n",
            "let a = 0↓;;\n",
            "let a = 0↓;    ;;\n",
            "let a = 0↓; ; ;\n"
        ],
        corrections: [
            "let a = 0;\n": "let a = 0\n",
            "let a = 0;\nlet b = 1\n": "let a = 0\nlet b = 1\n",
            "let a = 0;;\n": "let a = 0\n",
            "let a = 0;    ;;\n": "let a = 0\n",
            "let a = 0; ; ;\n": "let a = 0\n"
        ]
    )

    public func validateFile(_ file: File) -> [StyleViolation] {
        return file.violatingTrailingSemicolonRanges().map {
            StyleViolation(ruleDescription: type(of: self).description,
                severity: configuration.severity,
                location: Location(file: file, characterOffset: $0.location))
        }
    }

    public func correctFile(_ file: File) -> [Correction] {
        let violatingRanges = file.ruleEnabledViolatingRanges(
            file.violatingTrailingSemicolonRanges(),
            forRule: self
        )
        let adjustedRanges = violatingRanges.reduce([NSRange]()) { adjustedRanges, element in
            let adjustedLocation = element.location - adjustedRanges.count
            let adjustedRange = NSRange(location: adjustedLocation, length: element.length)
            return adjustedRanges + [adjustedRange]
        }
        if adjustedRanges.isEmpty {
            return []
        }
        var correctedContents = file.contents
        for range in adjustedRanges {
            if let indexRange = correctedContents.nsrangeToIndexRange(range) {
                correctedContents = correctedContents
                    .replacingCharacters(in: indexRange, with: "")
            }
        }
        file.write(correctedContents)
        return adjustedRanges.map {
            Correction(ruleDescription: type(of: self).description,
                location: Location(file: file, characterOffset: $0.location))
        }
    }
}
