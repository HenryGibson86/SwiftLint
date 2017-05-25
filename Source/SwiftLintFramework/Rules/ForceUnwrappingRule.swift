//
//  ForceUnwrappingRule.swift
//  SwiftLint
//
//  Created by Benjamin Otto on 14/01/16.
//  Copyright © 2015 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct ForceUnwrappingRule: OptInRule, ConfigurationProviderRule {

    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "force_unwrapping",
        name: "Force Unwrapping",
        description: "Force unwrapping should be avoided.",
        nonTriggeringExamples: [
            "if let url = NSURL(string: query)",
            "navigationController?.pushViewController(viewController, animated: true)",
            "let s as! Test",
            "try! canThrowErrors()",
            "let object: Any!",
            "@IBOutlet var constraints: [NSLayoutConstraint]!",
            "setEditing(!editing, animated: true)",
            "navigationController.setNavigationBarHidden(!navigationController." +
                "navigationBarHidden, animated: true)",
            "if addedToPlaylist && (!self.selectedFilters.isEmpty || " +
                "self.searchBar?.text?.isEmpty == false) {}",
            "print(\"\\(xVar)!\")",
            "var test = (!bar)"
        ],
        triggeringExamples: [
            "let url = NSURL(string: query)↓!",
            "navigationController↓!.pushViewController(viewController, animated: true)",
            "let unwrapped = optional↓!",
            "return cell↓!",
            "let url = NSURL(string: \"http://www.google.com\")↓!",
            "let dict = [\"Boooo\": \"👻\"]func bla() -> String { return dict[\"Boooo\"]↓! }"
        ]
    )

    public func validate(file: File) -> [StyleViolation] {
        return violationRanges(in: file).map {
            return StyleViolation(ruleDescription: type(of: self).description,
                severity: configuration.severity,
                location: Location(file: file, characterOffset: $0.location))
        }
    }

    // capture previous and next of "!"
    // http://userguide.icu-project.org/strings/regexp
    private static let pattern = "([^\\s\\p{Ps}])(!)(.?)"

    private static let regularExpression = regex(pattern, options: [.dotMatchesLineSeparators])
    private static let excludingSyntaxKindsForFirstCapture = SyntaxKind.commentKeywordStringAndTypeidentifierKinds()
    private static let excludingSyntaxKindsForSecondCapture = SyntaxKind.commentAndStringKinds()
    private static let excludingSyntaxKindsForThirdCapture = [SyntaxKind.identifier]

    // swiftlint:disable:next function_body_length
    private func violationRanges(in file: File) -> [NSRange] {
        let contents = file.contents
        let nsstring = contents.bridge()
        let range = NSRange(location: 0, length: contents.utf16.count)
        let syntaxMap = file.syntaxMap
        return ForceUnwrappingRule.regularExpression
            .matches(in: contents, options: [], range: range)
            .flatMap { match -> NSRange? in
                if match.numberOfRanges < 3 { return nil }

                let firstRange = match.rangeAt(1)
                let secondRange = match.rangeAt(2)
                let violationRange = NSRange(location: NSMaxRange(firstRange), length: 0)

                guard let matchByteFirstRange = nsstring
                    .NSRangeToByteRange(start: firstRange.location, length: firstRange.length),
                    let matchByteSecondRange = nsstring
                        .NSRangeToByteRange(start: secondRange.location, length: secondRange.length)
                    else { return nil }

                let kindsInFirstRange = syntaxMap.kinds(inByteRange: matchByteFirstRange)
                let kindsInSecondRange = syntaxMap.kinds(inByteRange: matchByteSecondRange)

                // check first captured range
                // If not empty, first captured range is comment, string, keyword or typeidentifier.
                // We checks "not empty" because kinds may empty without filtering.
                guard !kindsInFirstRange
                    .contains(where: ForceUnwrappingRule.excludingSyntaxKindsForFirstCapture.contains) else {
                        return nil
                }

                // if first captured range is identifier, generate violation
                if kindsInFirstRange.contains(.identifier) {
                    return violationRange
                }

                // check second capture '!'
                let forceUnwrapNotInCommentOrString = !kindsInSecondRange
                    .contains(where: ForceUnwrappingRule.excludingSyntaxKindsForSecondCapture.contains)

                // check firstCapturedString is ")" and '!' is not within comment or string
                let firstCapturedString = nsstring.substring(with: firstRange)
                if firstCapturedString == ")" && forceUnwrapNotInCommentOrString {
                    return violationRange
                }

                // check third capture
                if match.numberOfRanges == 3 {

                    // check third captured range
                    let secondRange = match.rangeAt(3)
                    guard let matchByteThirdRange = nsstring
                        .NSRangeToByteRange(start: secondRange.location, length: secondRange.length)
                        else { return nil }

                    let thirdCaptureIsIdentifier = !syntaxMap.kinds(inByteRange: matchByteThirdRange)
                        .contains(where: ForceUnwrappingRule.excludingSyntaxKindsForThirdCapture.contains)
                    if thirdCaptureIsIdentifier { return nil }
                }

                // check structure
                if checkStructure(in: file, byteRange: matchByteFirstRange) {
                    return violationRange
                } else {
                    return nil
                }
            }
    }

    // Returns if range should generate violation
    // check deepest kind matching range in structure
    private func checkStructure(in file: File, byteRange: NSRange) -> Bool {
        let nsstring = file.contents.bridge()
        let kinds = file.structure.kinds(forByteOffset: byteRange.location)
        if let lastKind = kinds.last {
            switch lastKind.kind {
            // range is in some "source.lang.swift.decl.var.*"
            case SwiftDeclarationKind.varClass.rawValue: fallthrough
            case SwiftDeclarationKind.varGlobal.rawValue: fallthrough
            case SwiftDeclarationKind.varInstance.rawValue: fallthrough
            case SwiftDeclarationKind.varStatic.rawValue:
                let byteOffset = lastKind.byteRange.location
                let byteLength = byteRange.location - byteOffset
                if let varDeclarationString = nsstring
                    .substringWithByteRange(start: byteOffset, length: byteLength),
                    varDeclarationString.contains("=") {
                        // if declarations contains "=", range is not type annotation
                        return true
                } else {
                    // range is type annotation of declaration
                    return false
                }
            // followings have invalid "key.length" returned from SourceKitService w/ Xcode 7.2.1
//            case SwiftDeclarationKind.VarParameter.rawValue: fallthrough
//            case SwiftDeclarationKind.VarLocal.rawValue: fallthrough
            default:
                break
            }
            if lastKind.kind.hasPrefix("source.lang.swift.decl.function") {
                return true
            }
        }
        return false
    }
}
