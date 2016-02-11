//
//  CustomRulesTests.swift
//  SwiftLint
//
//  Created by Scott Hoyt on 1/21/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation
import XCTest
@testable import SwiftLintFramework
import SourceKittenFramework

class CustomRulesTests: XCTestCase {

    // protocol XCTestCaseProvider
    lazy var allTests: [(String, () throws -> Void)] = [
        ("testCustomRuleConfigurationSetsCorrectly", self.testCustomRuleConfigurationSetsCorrectly),
        ("testCustomRuleConfigurationThrows", self.testCustomRuleConfigurationThrows),
        ("testCustomRules", self.testCustomRules),
    ]

    func testCustomRuleConfigurationSetsCorrectly() {
        let configDict = ["my_custom_rule": ["name": "MyCustomRule",
            "message": "Message",
            "regex": "regex",
            "match_kinds": "comment",
            "severity": "error"]]
        var comp = RegexConfig(identifier: "my_custom_rule")
        comp.name = "MyCustomRule"
        comp.message = "Message"
        comp.regex = NSRegularExpression.forcePattern("regex")
        comp.severityConfig = SeverityConfig(.Error)
        comp.matchKinds = Set([SyntaxKind.Comment])
        var compRules = CustomRulesConfig()
        compRules.customRuleConfigurations = [comp]
        do {
            var configuration = CustomRulesConfig()
            try configuration.applyConfiguration(configDict)
            XCTAssertEqual(configuration, compRules)
        } catch {
            XCTFail("Did not configure correctly")
        }
    }

    func testCustomRuleConfigurationThrows() {
        let config = 17
        var customRulesConfig = CustomRulesConfig()
        checkError(ConfigurationError.UnknownConfiguration) {
            try customRulesConfig.applyConfiguration(config)
        }
    }

    func testCustomRules() {
        var regexConfig = RegexConfig(identifier: "custom")
        regexConfig.regex = NSRegularExpression.forcePattern("pattern")
        regexConfig.matchKinds = Set([SyntaxKind.Comment])
        var customRuleConfiguration = CustomRulesConfig()
        customRuleConfiguration.customRuleConfigurations = [regexConfig]
        var customRules = CustomRules()
        customRules.configuration = customRuleConfiguration
        let file = File(contents: "// My file with\n// a pattern")
        XCTAssertEqual(customRules.validateFile(file),
            [StyleViolation(ruleDescription: regexConfig.description,
                severity: .Warning,
                location: Location(file: nil, line: 2, character: 6),
                reason: regexConfig.message)])
    }
}
