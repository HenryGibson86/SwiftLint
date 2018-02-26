//
//  ExplicitTypeInterfaceConfigurationTests.swift
//  SwiftLint
//
//  Created by Rounak Jain on 2/24/18.
//  Copyright © 2018 Realm. All rights reserved.
//

@testable import SwiftLintFramework
import XCTest

class ExplicitTypeInterfaceConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = ExplicitTypeInterfaceConfiguration()
        XCTAssertEqual(config.severityConfiguration.severity, .warning)
        XCTAssertEqual(config.allowedKinds, Set([.varInstance, .varClass, .varStatic, .varLocal]))
    }

    func testApplyingCustomConfiguration() throws {
        var config = ExplicitTypeInterfaceConfiguration()
        try config.apply(configuration: ["severity": "error",
                                         "excluded": ["local"]])
        XCTAssertEqual(config.severityConfiguration.severity, .error)
        XCTAssertEqual(config.allowedKinds, Set([.varInstance, .varClass, .varStatic]))
    }

    func testInvalidKeyInCustomConfiguration() {
        var config = ExplicitTypeInterfaceConfiguration()
        checkError(ConfigurationError.unknownConfiguration) {
            try config.apply(configuration: ["invalidKey": "error"])
        }
    }

    func testInvalidTypeOfCustomConfiguration() {
        var config = ExplicitTypeInterfaceConfiguration()
        checkError(ConfigurationError.unknownConfiguration) {
            try config.apply(configuration: "invalidKey")
        }
    }

    func testInvalidTypeOfValueInCustomConfiguration() {
        var config = ExplicitTypeInterfaceConfiguration()
        checkError(ConfigurationError.unknownConfiguration) {
            try config.apply(configuration: ["severity": 1])
        }
    }

}
