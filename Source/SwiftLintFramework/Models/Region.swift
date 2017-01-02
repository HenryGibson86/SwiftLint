//
//  Region.swift
//  SwiftLint
//
//  Created by JP Simard on 8/29/15.
//  Copyright © 2015 Realm. All rights reserved.
//

import Foundation
import SourceKittenFramework

public struct Region {
    let start: Location
    let end: Location
    let disabledRuleIdentifiers: Set<String>

    public init(start: Location, end: Location, disabledRuleIdentifiers: Set<String>) {
        self.start = start
        self.end = end
        self.disabledRuleIdentifiers = disabledRuleIdentifiers
    }

    public func contains(_ location: Location) -> Bool {
        return start <= location && end >= location
    }

    public func isRuleEnabled(_ rule: Rule) -> Bool {
        return !isRuleDisabled(rule)
    }

    public func isRuleDisabled(_ rule: Rule) -> Bool {
        let description = type(of: rule).description
        let identifiers = Array(description.allAliases) + [description.identifier]
        return !disabledRuleIdentifiers.intersection(identifiers).isEmpty
    }
}
