import Foundation
import SourceKittenFramework

public struct AnyObjectProtocolRule: ASTRule, CorrectableRule, ConfigurationProviderRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "anyobject_protocol",
        name: "AnyObject Protocol",
        description: "Prefer using `AnyObject` over `class` for class-only protocols.",
        kind: .lint,
        minSwiftVersion: .four,
        nonTriggeringExamples: [
            "protocol SomeProtocol {}",
            "protocol SomeClassOnlyProtocol: AnyObject {}",
            "protocol SomeClassOnlyProtocol: AnyObject, SomeInheritedProtocol {}",
            "@objc protocol SomeClassOnlyProtocol: AnyObject, SomeInheritedProtocol {}"
        ],
        triggeringExamples: [
            "protocol SomeClassOnlyProtocol: ↓class {}",
            "protocol SomeClassOnlyProtocol: ↓class, SomeInheritedProtocol {}",
            "@objc protocol SomeClassOnlyProtocol: ↓class, SomeInheritedProtocol {}"
        ],
        corrections: [
            "protocol SomeClassOnlyProtocol: ↓class {}":
                "protocol SomeClassOnlyProtocol: AnyObject {}",
            "protocol SomeClassOnlyProtocol: ↓class, SomeInheritedProtocol {}":
                "protocol SomeClassOnlyProtocol: AnyObject, SomeInheritedProtocol {}",
            "protocol SomeClassOnlyProtocol: SomeInheritedProtocol, ↓class {}":
                "protocol SomeClassOnlyProtocol: SomeInheritedProtocol, AnyObject {}",
            "@objc protocol SomeClassOnlyProtocol: ↓class, SomeInheritedProtocol {}":
                "@objc protocol SomeClassOnlyProtocol: AnyObject, SomeInheritedProtocol {}"
        ]
    )

    // MARK: - ASTRule

    public func validate(file: File,
                         kind: SwiftDeclarationKind,
                         dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        return violationRanges(in: file, kind: kind, dictionary: dictionary).map {
            StyleViolation(ruleDescription: type(of: self).description,
                           severity: configuration.severity,
                           location: Location(file: file, characterOffset: $0.location))
        }
    }

    // MARK: - CorrectableRule

    public func correct(file: File) -> [Correction] {
        let matches = file.ruleEnabled(violatingRanges: violationRanges(in: file), for: self)
        var correctedContents = file.contents
        var adjustedLocations: [Int] = []

        for violatingRange in matches.reversed() {
            if let range = file.contents.nsrangeToIndexRange(violatingRange) {
                correctedContents = correctedContents.replacingCharacters(in: range, with: "AnyObject")
                adjustedLocations.insert(violatingRange.location, at: 0)
            }
        }

        file.write(correctedContents)

        return adjustedLocations.map {
            Correction(ruleDescription: type(of: self).description,
                       location: Location(file: file, characterOffset: $0))
        }
    }

    // MARK: - Private

    private func violationRanges(in file: File) -> [NSRange] {
        return violationRanges(in: file, dictionary: file.structure.dictionary).sorted { $0.location < $1.location }
    }

    private func violationRanges(in file: File,
                                 dictionary: [String: SourceKitRepresentable]) -> [NSRange] {
        let ranges = dictionary.substructure.flatMap { subDict -> [NSRange] in
            var ranges = violationRanges(in: file, dictionary: subDict)

            if let kind = subDict.kind.flatMap(SwiftDeclarationKind.init(rawValue:)) {
                ranges += violationRanges(in: file, kind: kind, dictionary: subDict)
            }

            return ranges
        }

        return ranges.unique
    }

    private func violationRanges(in file: File,
                                 kind: SwiftDeclarationKind,
                                 dictionary: [String: SourceKitRepresentable]) -> [NSRange] {
        guard kind == .protocol else { return [] }

        return dictionary.elements.compactMap { subDict -> NSRange? in
            guard
                let offset = subDict.offset,
                let length = subDict.length,
                let content = file.contents.bridge().substringWithByteRange(start: offset, length: length),
                content == "class"
                else {
                    return nil
            }

            return file.contents.bridge().byteRangeToNSRange(start: offset, length: length)
        }
    }
}
