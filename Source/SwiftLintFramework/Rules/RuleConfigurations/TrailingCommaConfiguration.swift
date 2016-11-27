//
//  TrailingCommaConfiguration.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 25/11/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation

public struct TrailingCommaConfiguration: RuleConfiguration, Equatable {
    private(set) var severityConfiguration = SeverityConfiguration(.Warning)
    private(set) var mandatoryComma: Bool

    public var consoleDescription: String {
        return severityConfiguration.consoleDescription + ", mandatory_comma: \(mandatoryComma)"
    }

    public init(mandatoryComma: Bool = false) {
        self.mandatoryComma = mandatoryComma
    }

    public mutating func applyConfiguration(configuration: AnyObject) throws {
        guard let configuration = configuration as? [String: AnyObject] else {
            throw ConfigurationError.UnknownConfiguration
        }

        mandatoryComma = (configuration["mandatory_comma"] as? Bool == true)

        if let severityString = configuration["severity"] as? String {
            try severityConfiguration.applyConfiguration(severityString)
        }
    }
}

public func == (lhs: TrailingCommaConfiguration,
                rhs: TrailingCommaConfiguration) -> Bool {
    return lhs.mandatoryComma == rhs.mandatoryComma &&
        lhs.severityConfiguration == rhs.severityConfiguration
}
