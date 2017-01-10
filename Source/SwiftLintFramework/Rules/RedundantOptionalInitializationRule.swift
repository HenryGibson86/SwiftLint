//
//  RedundantOptionalInitializationRule.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 12/24/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct RedundantOptionalInitializationRule: ASTRule, CorrectableRule, ConfigurationProviderRule {

    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "redundant_optional_initialization",
        name: "Redundant Optional Initialization",
        description: "Initializing an optional variable with nil is redundant.",
        nonTriggeringExamples: [
            "var myVar: Int?\n",
            "let myVar: Int? = nil\n",
            "var myVar: Int? = 0\n",
            "func foo(bar: Int? = 0) { }\n",
            "var myVar: Optional<Int>\n",
            "let myVar: Optional<Int> = nil\n",
            "var myVar: Optional<Int> = 0\n"
        ],
        triggeringExamples: [
            "var myVar: Int?↓ = nil\n",
            "var myVar: Optional<Int>↓ = nil\n",
            "var myVar: Int?↓=nil\n",
            "var myVar: Optional<Int>↓=nil\n"
        ],
        corrections: [
            "var myVar: Int?↓ = nil\n": "var myVar: Int?\n",
            "var myVar: Optional<Int>↓ = nil\n": "var myVar: Optional<Int>\n",
            "var myVar: Int?↓=nil\n": "var myVar: Int?\n",
            "var myVar: Optional<Int>↓=nil\n": "var myVar: Optional<Int>\n"
        ]
    )

    private let pattern = "\\s*=\\s*nil\\b"

    public func validate(file: File, kind: SwiftDeclarationKind,
                         dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        return violationRanges(in: file, kind: kind, dictionary: dictionary).map {
            StyleViolation(ruleDescription: type(of: self).description,
                           severity: configuration.severity,
                           location: Location(file: file, characterOffset: $0.location))
        }
    }

    private func violationRanges(in file: File, kind: SwiftDeclarationKind,
                                 dictionary: [String: SourceKitRepresentable]) -> [NSRange] {
        guard SwiftDeclarationKind.variableKinds().contains(kind),
            dictionary["key.setter_accessibility"] != nil,
            let type = dictionary["key.typename"] as? String,
            typeIsOptional(type),
            case let contents = file.contents.bridge(),
            let offset = (dictionary["key.offset"] as? Int64).flatMap({ Int($0) }),
            let length = (dictionary["key.length"] as? Int64).flatMap({ Int($0) }),
            let range = contents.byteRangeToNSRange(start: offset, length: length),
            let match = file.match(pattern: pattern, with: [.keyword], range: range).first else {
                return []
        }

        return [match]
    }

    private func violationRanges(in file: File, dictionary: [String: SourceKitRepresentable]) -> [NSRange] {
        return dictionary.substructure.flatMap { subDict -> [NSRange] in
            guard let kindString = subDict["key.kind"] as? String,
                let kind = SwiftDeclarationKind(rawValue: kindString) else {
                    return []
            }
            return violationRanges(in: file, dictionary: subDict) +
                violationRanges(in: file, kind: kind, dictionary: subDict)
        }
    }

    private func violationRanges(in file: File) -> [NSRange] {
        return violationRanges(in: file, dictionary: file.structure.dictionary).sorted { lh, rh in
            lh.location < rh.location
        }
    }

    public func correct(file: File) -> [Correction] {
        let violatingRanges = file.ruleEnabled(violatingRanges: violationRanges(in: file), for: self)
        var correctedContents = file.contents
        var adjustedLocations = [Int]()

        for violatingRange in violatingRanges.reversed() {
            if let indexRange = correctedContents.nsrangeToIndexRange(violatingRange) {
                correctedContents = correctedContents.replacingCharacters(in: indexRange, with: "")
                adjustedLocations.insert(violatingRange.location, at: 0)
            }
        }

        file.write(correctedContents)

        return adjustedLocations.map {
            Correction(ruleDescription: type(of: self).description,
                       location: Location(file: file, characterOffset: $0))
        }
    }

    private func typeIsOptional(_ type: String) -> Bool {
        return type.hasSuffix("?") || type.hasPrefix("Optional<")
    }

}
