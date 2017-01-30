//
//  LineLengthRuleTests.swift
//  SwiftLint
//
//  Created by Javier Hernández on 06/01/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import SourceKittenFramework
@testable import SwiftLintFramework
import XCTest

class LineLengthRuleTests: XCTestCase {

    let longFunctionDeclaration = "public func superDuperLongFunctionDeclaration(a: String, b: String, " +
        "c: String, d: String, e: String, f: String, g: String, h: String, i: String, " +
        "j: String, k: String, l: String, m: String, n: String, o: String, p: String, " +
        "q: String, r: String, s: String, t: String, u: String, v: String, w: String, " +
    "x: String, y: String, z: String) {\n"

    let longComment = String(repeating: "/", count: 121) + "\n"
    let longBlockComment = "/*" + String(repeating: " ", count: 121) + "*/\n"

    func testLineLength() {
        verifyRule(LineLengthRule.description, commentDoesntViolate: false, stringDoesntViolate: false)
    }

    func testLineLengthWithIgnoreFunctionDeclaraionsEnabled() {
        let baseDescription = LineLengthRule.description
        let triggeringExamples = baseDescription.triggeringExamples
        let nonTriggeringExamples = baseDescription.nonTriggeringExamples + [longFunctionDeclaration]
        let description = RuleDescription(identifier: baseDescription.identifier,
                                          name: baseDescription.name,
                                          description: baseDescription.description,
                                          nonTriggeringExamples: nonTriggeringExamples,
                                          triggeringExamples: triggeringExamples,
                                          corrections: baseDescription.corrections)
        verifyRule(description, ruleConfiguration: ["ignores_function_declarations": true],
                   commentDoesntViolate: false, stringDoesntViolate: false)
    }

    func testLineLengthWithIgnoreCommentsEnabled() {
        let baseDescription = LineLengthRule.description
        let triggeringExamples = [longFunctionDeclaration]
        let nonTriggeringExamples = [longComment, longBlockComment]
        let description = RuleDescription(identifier: baseDescription.identifier,
                                          name: baseDescription.name,
                                          description: baseDescription.description,
                                          nonTriggeringExamples: nonTriggeringExamples,
                                          triggeringExamples: triggeringExamples,
                                          corrections: baseDescription.corrections)
        verifyRule(description, ruleConfiguration: ["ignores_comments": true],
                   commentDoesntViolate: false, stringDoesntViolate: false, skipCommentTests: true)
    }

    func testLineLengthWithIgnoreURLsEnabled() {
        let url = "https://github.com/realm/SwiftLint"
        let triggeringLines = [String(repeating: "/", count: 121) + "\(url)\n"]
        let nonTriggeringLines = ["\(url) " + String(repeating: "/", count: 118) + " \(url)\n",
            "\(url)/" + String(repeating: "a", count: 120)]

        let baseDescription = LineLengthRule.description
        let nonTriggeringExamples = baseDescription.nonTriggeringExamples + nonTriggeringLines
        let triggeringExamples = baseDescription.triggeringExamples + triggeringLines
        let description = RuleDescription(identifier: baseDescription.identifier,
                                          name: baseDescription.name,
                                          description: baseDescription.description,
                                          nonTriggeringExamples: nonTriggeringExamples,
                                          triggeringExamples: triggeringExamples,
                                          corrections: baseDescription.corrections)

        verifyRule(description, ruleConfiguration: ["ignores_urls": true],
                   commentDoesntViolate: false, stringDoesntViolate: false)
    }
}

extension LineLengthRuleTests {
    static var allTests: [(String, (LineLengthRuleTests) -> () throws -> Void)] {
        return [
            ("testLineLength", testLineLength),
            ("testLineLengthWithIgnoreURLsEnabled", testLineLengthWithIgnoreURLsEnabled)
        ]
    }
}
