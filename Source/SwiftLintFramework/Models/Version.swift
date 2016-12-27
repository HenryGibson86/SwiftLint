//
//  Version.swift
//  SwiftLint
//
//  Created by Marcelo Fabri on 27/12/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import Foundation

public struct Version {
    public let value: String

    public static let current: Version = {
        if let value = Bundle(identifier: "io.realm.SwiftLintFramework")?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return Version(value: value)
        }

        return Version(value: "0.15.0")
    }()
}
