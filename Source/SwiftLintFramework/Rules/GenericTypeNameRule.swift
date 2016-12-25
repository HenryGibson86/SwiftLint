//
//  GenericTypeNameRule.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 12/25/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct GenericTypeNameRule: ASTRule, ConfigurationProviderRule {
    public var configuration = NameConfiguration(minLengthWarning: 1,
                                                 minLengthError: 0,
                                                 maxLengthWarning: 20,
                                                 maxLengthError: 1000)

    public init() {}

    public static let description = RuleDescription(
        identifier: "generic_type_name",
        name: "Generic Type Name",
        description: "Generic type name should only contain alphanumeric characters, start with an " +
                     "uppercase character and span between 1 and 20 characters in length.",
        nonTriggeringExamples: [
            "func foo<T>() {}\n",
            "func foo<T>() -> T {}\n",
            "func foo<T, U>(param: U) -> T {}\n",
            "func foo<T: Hashable, U: Rule>(param: U) -> T {}\n",
            "struct Foo<T> {}\n",
            "class Foo<T> {}\n",
            "func run(_ options: NoOptions<CommandantError<()>>) {}\n",
            "func foo(_ options: Set<type>) {}\n",
            "func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool\n",
            "func configureWith(data: Either<MessageThread, (project: Project, backing: Backing)>)\n"
        ],
        triggeringExamples: [
            "func foo<↓T_Foo>() {}\n",
            "func foo<T, ↓U_Foo>(param: U_Foo) -> T {}\n",
            "func foo<↓\(String(repeating: "T", count: 21))>() {}\n",
            "func foo<↓type>() {}\n"
        ] + ["class", "struct"].flatMap { type in
            [
                "\(type) Foo<↓T_Foo> {}\n",
                "\(type) Foo<T, ↓U_Foo> {}\n",
                "\(type) Foo<↓T_Foo, ↓U_Foo> {}\n",
                "\(type) Foo<↓\(String(repeating: "T", count: 21))> {}\n",
                "\(type) Foo<↓type> {}\n"
            ]
        }
    )

    private let pattern = regex("<(\\s*\\w.*?)>")

    public func validateFile(_ file: File,
                             kind: SwiftDeclarationKind,
                             dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        let types = genericTypesForType(file, kind: kind, dictionary: dictionary) +
                    genericTypesForFunction(file, kind: kind, dictionary: dictionary)

        return types.flatMap { validateName(name: $0.0, file: file, offset: $0.1) }
    }

    private func genericTypesForType(_ file: File,
                                     kind: SwiftDeclarationKind,
                                     dictionary: [String: SourceKitRepresentable]) -> [(String, Int)] {
        guard kind == .class || kind == .struct,
            let nameOffset = (dictionary["key.nameoffset"] as? Int64).flatMap({ Int($0) }),
            let nameLength = (dictionary["key.namelength"] as? Int64).flatMap({ Int($0) }),
            let bodyOffset = (dictionary["key.bodyoffset"] as? Int64).flatMap({ Int($0) }),
            case let contents = file.contents.bridge(),
            case let start = nameOffset + nameLength,
            case let length = bodyOffset - start,
            let range = contents.byteRangeToNSRange(start: start, length: length),
            let match = pattern.firstMatch(in: file.contents, options: [], range: range)?.rangeAt(1) else {
                return []
        }

        let genericConstraint = contents.substring(with: match)
        return extractTypesFromGenericConstraint(genericConstraint, offset: match.location, file: file)
    }

    private func genericTypesForFunction(_ file: File,
                                         kind: SwiftDeclarationKind,
                                         dictionary: [String: SourceKitRepresentable]) -> [(String, Int)] {
        guard SwiftDeclarationKind.functionKinds().contains(kind),
            let offset = (dictionary["key.nameoffset"] as? Int64).flatMap({ Int($0) }),
            let length = (dictionary["key.namelength"] as? Int64).flatMap({ Int($0) }),
            case let contents = file.contents.bridge(),
            let range = contents.byteRangeToNSRange(start: offset, length: length),
            let match = pattern.firstMatch(in: file.contents, options: [], range: range)?.rangeAt(1),
            match.location < minParameterOffset(parameters: dictionary.enclosedVarParameters, file: file) else {
            return []
        }

        let genericConstraint = contents.substring(with: match)
        return extractTypesFromGenericConstraint(genericConstraint, offset: match.location, file: file)
    }

    private func minParameterOffset(parameters: [[String: SourceKitRepresentable]], file: File) -> Int {
        let offsets = parameters.flatMap {
            ($0["key.offset"] as? Int64).flatMap({ Int($0) })
        }.flatMap {
            file.contents.bridge().byteRangeToNSRange(start: $0, length: 0)?.location
        }

        return offsets.min() ?? Int.max
    }

    private func extractTypesFromGenericConstraint(_ constraint: String, offset: Int, file: File) -> [(String, Int)] {
        guard let beforeWhere = constraint.components(separatedBy: "where").first else {
            return []
        }

        let namesAndRanges: [(String, NSRange)] = beforeWhere.split(separator: ",").flatMap { string, range in
            return string.split(separator: ":").first.map {
                let (trimmed, trimmedRange) = $0.0.trimmingWhitespaces()
                return (trimmed, NSRange(location: range.location + trimmedRange.location,
                                         length: trimmedRange.length))
            }
        }

        let contents = file.contents.bridge()
        return namesAndRanges.flatMap { (name, range) -> (String, Int)? in
            guard let byteRange = contents.NSRangeToByteRange(start: range.location + offset,
                                                              length: range.length),
                case let kinds = file.syntaxMap.tokensIn(byteRange).flatMap({ SyntaxKind(rawValue: $0.type) }),
                kinds == [.identifier] else {
                    return nil
            }

            return (name, byteRange.location)
        }
    }

    private func validateName(name: String, file: File, offset: Int) -> [StyleViolation] {
        guard !configuration.excluded.contains(name) else {
            return []
        }

        let nameCharacterSet = CharacterSet(charactersIn: name)
        if !CharacterSet.alphanumerics.isSuperset(of: nameCharacterSet) {
            return [
                StyleViolation(ruleDescription: type(of: self).description,
                               severity: .error,
                               location: Location(file: file, byteOffset: offset),
                               reason: "Generic type name should only contain alphanumeric characters: '\(name)'")
            ]
        } else if !name.substring(to: name.index(after: name.startIndex)).isUppercase() {
            return [
                StyleViolation(ruleDescription: type(of: self).description,
                               severity: .error,
                               location: Location(file: file, byteOffset: offset),
                               reason: "Generic type name should start with an uppercase character: '\(name)'")
            ]
        } else if let severity = severity(forLength: name.characters.count) {
            return [
                StyleViolation(ruleDescription: type(of: self).description,
                               severity: severity,
                               location: Location(file: file, byteOffset: offset),
                               reason: "Generic type name should be between \(configuration.minLengthThreshold) and " +
                    "\(configuration.maxLengthThreshold) characters long: '\(name)'")
            ]
        }

        return []
    }
}

extension String {
    fileprivate func split(separator: Character) -> [(String, NSRange)] {
        var offsets = [0]
        var ends = [Int]()
        var currentOffset = 0
        let components = characters.split { character in
            currentOffset += 1
            if character == separator {
                offsets.append(currentOffset)
                ends.append(currentOffset - 1)
                return true
            }

            return false
        }.map(String.init)

        ends.append(characters.count)

        let ranges = offsets.enumerated().map { index, offset -> NSRange in
            let next = ends[index]
            return NSRange(location: offset, length: next - offset)
        }

        return Array(zip(components, ranges))
    }

    fileprivate func trimmingWhitespaces() -> (String, NSRange) {
        let range = NSRange(location: 0, length: bridge().length)
        guard let match = regex("^\\s*(\\S*)\\s*$").firstMatch(in: self, options: [], range: range),
            NSEqualRanges(range, match.range) else {
            return (self, range)
        }

        let trimmedRange = match.rangeAt(1)
        return (bridge().substring(with: trimmedRange), trimmedRange)
    }
}
