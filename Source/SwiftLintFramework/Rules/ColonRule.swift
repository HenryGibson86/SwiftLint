//
//  ColonRule.swift
//  SwiftLint
//
//  Created by JP Simard on 2015-05-16.
//  Copyright (c) 2015 Realm. All rights reserved.
//

import SourceKittenFramework

public struct ColonRule: Rule {
    public init() {}

    public static let description = RuleDescription(
        identifier: "colon",
        name: "Colon",
        description: "This rule checks whether you associate the colon with the identifier.",
        nonTriggeringExamples: [
            "let abc: Void\n",
            "let abc: [Void: Void]\n",
            "let abc: (Void, Void)\n",
            "let abc: String=\"def\"\n",
            "let abc: Int=0\n",
            "let abc: Enum=Enum.Value\n",
            "func abc(def: Void) {}\n",
            "func abc(def: Void, ghi: Void) {}\n"
        ],
        triggeringExamples: [
            "let abc:Void\n",
            "let abc:  Void\n",
            "let abc :Void\n",
            "let abc : Void\n",
            "let abc : [Void: Void]\n",
            "let abc :String=\"def\"\n",
            "let abc :Int=0\n",
            "let abc :Int = 0\n",
            "let abc:Int=0\n",
            "let abc:Int = 0\n",
            "let abc:Enum=Enum.Value\n",
            "func abc(def:Void) {}\n",
            "func abc(def:  Void) {}\n",
            "func abc(def :Void) {}\n",
            "func abc(def : Void) {}\n",
            "func abc(def: Void, ghi :Void) {}\n"
        ]
    )

    public func validateFile(file: File) -> [StyleViolation] {
        let pattern = "\\w+\\s+:\\s*\\S+|\\w+:(?:\\s{0}|\\s{2,})\\S+"

        return file.matchPattern(pattern).flatMap { range, syntaxKinds in
            if !syntaxKinds.startsWith([.Identifier, .Typeidentifier]) {
                return nil
            }

            return StyleViolation(ruleDescription: self.dynamicType.description,
                location: Location(file: file, offset: range.location),
                reason: "When specifying a type, always associate the colon with the identifier")
        }
    }
}
