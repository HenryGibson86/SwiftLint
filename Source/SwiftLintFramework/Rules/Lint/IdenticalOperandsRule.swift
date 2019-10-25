import Foundation
import SourceKittenFramework

public struct IdenticalOperandsRule: ConfigurationProviderRule, OptInRule, AutomaticTestableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    private static let operators = ["==", "!=", "===", "!==", ">", ">=", "<", "<="]

    public static let description = RuleDescription(
        identifier: "identical_operands",
        name: "Identical Operands",
        description: "Comparing two identical operands is likely a mistake.",
        kind: .lint,
        nonTriggeringExamples: operators.flatMap { operation in
            [
                "1 \(operation) 2",
                "foo \(operation) bar",
                "prefixedFoo \(operation) foo",
                "foo.aProperty \(operation) foo.anotherProperty",
                "self.aProperty \(operation) self.anotherProperty",
                "\"1 \(operation) 1\"",
                "self.aProperty \(operation) aProperty",
                "lhs.aProperty \(operation) rhs.aProperty",
                "lhs.identifier \(operation) rhs.identifier",
                "i \(operation) index",
                "$0 \(operation) 0",
                "keyValues?.count ?? 0 \(operation) 0",
                "string \(operation) string.lowercased()",
                """
                let num: Int? = 0
                _ = num != nil && num \(operation) num?.byteSwapped
                """
            ]
        } + [
            "func evaluate(_ mode: CommandMode) -> Result<AutoCorrectOptions, CommandantError<CommandantError<()>>>",
            "let array = Array<Array<Int>>()",
            "guard Set(identifiers).count != identifiers.count else { return }"
        ],
        triggeringExamples: operators.flatMap { operation in
            [
                "↓1 \(operation) 1",
                "↓foo \(operation) foo",
                "↓foo.aProperty \(operation) foo.aProperty",
                "↓self.aProperty \(operation) self.aProperty",
                "↓$0 \(operation) $0"
            ]
        }
    )

    private struct Operand {
        /// Index of first token in tokens
        let index: Int

        // tokens in this operand
        let tokens: [SyntaxToken]
    }

    public func validate(file: File) -> [StyleViolation] {
        let operators = type(of: self).operators.joined(separator: "|")
        return file.matchesAndTokens(matching: "\\s(" + operators + ")\\s")
            .filter { _, tokens in tokens.isEmpty }
            .compactMap { result, _ -> NSRange? in
                let contents = file.contents.bridge()
                let operatorRange = result.range(at: 1)
                guard let operatorByteRange = contents.NSRangeToByteRange(start: operatorRange.location,
                                                                          length: operatorRange.length) else {
                                                                            return nil
                }

                // grab index of first token after the operator
                let tokens = file.syntaxMap.tokens
                guard let rightTokenIndex = tokens.firstIndex(where: { $0.offset >= operatorByteRange.upperBound }),
                    rightTokenIndex > 0 else {
                        return nil
                }
                let (leftOperand, rightOperand) = operandsStartingFromIndexes(leftTokenIndex: rightTokenIndex - 1,
                                                                              rightTokenIndex: rightTokenIndex,
                                                                              file: file)

                guard leftOperand.tokens.count == rightOperand.tokens.count else {
                    return nil
                }

                // Make sure both operands have same token types
                guard zip(leftOperand.tokens, rightOperand.tokens).allSatisfy({ $0.0.type == $0.1.type }) else {
                    return nil
                }

                // Make sure that every part of the operand part is equal to previous on
                guard zip(leftOperand.tokens, rightOperand.tokens).allSatisfy({
                    contents.subStringWithSyntaxToken($0.0) == contents.subStringWithSyntaxToken($0.1) }) else {
                    return nil
                }

                guard let leftmostToken = leftOperand.tokens.first else {
                    return nil
                }

                // last check is to check if we have ?? to the left of the leftmost token
                if leftOperand.index != 0 {
                    let previousToken = tokens[leftOperand.index - 1]
                    guard !contents.isNilCoalecingOperatorBetweenTokens(previousToken, leftmostToken) else {
                        return nil
                    }
                }

                let violationRange = file.contents.byteRangeToNSRange(start: leftmostToken.offset,
                                                                      length: leftmostToken.length)
                return violationRange
            }
            .map { range in
                return StyleViolation(ruleDescription: type(of: self).description,
                                      severity: configuration.severity,
                                      location: Location(file: file, characterOffset: range.location))
            }
    }

    private func operandsStartingFromIndexes(leftTokenIndex: Int, rightTokenIndex: Int, file: File)
        -> (leftOperand: Operand, rightOperand: Operand) {
            let tokens = file.syntaxMap.tokens

            // expand to the left
            var currentIndex = leftTokenIndex
            var leftMostToken = tokens[currentIndex]
            var leftTokens = [leftMostToken]
            while currentIndex > 0 {
                let prevToken = tokens[currentIndex - 1]

                guard file.contents.isDotBetweenTokens(prevToken, leftMostToken) else { break }

                leftTokens.insert(prevToken, at: 0)
                currentIndex -= 1
                leftMostToken = prevToken
            }

            // expand to the right
            currentIndex = rightTokenIndex
            var rightMostToken = tokens[currentIndex]
            var rightTokens = [rightMostToken]
            while currentIndex < tokens.count - 1 {
                let nextToken = tokens[currentIndex + 1]

                guard file.contents.isDotBetweenTokens(rightMostToken, nextToken) else { break }

                rightTokens.append(nextToken)
                currentIndex += 1
                rightMostToken = nextToken
            }

            return (Operand(index: leftTokenIndex - leftTokens.count + 1, tokens: leftTokens),
                    Operand(index: rightTokenIndex, tokens: rightTokens))
    }
}

private extension NSString {
    func subStringWithSyntaxToken(_ syntaxToken: SyntaxToken) -> String? {
        return substringWithByteRange(start: syntaxToken.offset, length: syntaxToken.length)
    }

    func subStringBetweenTokens(_ startToken: SyntaxToken, _ endToken: SyntaxToken) -> String? {
        return substringWithByteRange(start: startToken.offset + startToken.length,
                                      length: endToken.offset - startToken.offset - startToken.length)
    }

    func isDotBetweenTokens(_ startToken: SyntaxToken, _ endToken: SyntaxToken) -> Bool {
        return isRegexBetweenTokens(startToken, "\\.", endToken)
    }

    func isNilCoalecingOperatorBetweenTokens(_ startToken: SyntaxToken, _ endToken: SyntaxToken) -> Bool {
        return isRegexBetweenTokens(startToken, "\\?\\?", endToken)
    }

    func isRegexBetweenTokens(_ startToken: SyntaxToken, _ regexString: String, _ endToken: SyntaxToken) -> Bool {
        guard let betweenTokens = subStringBetweenTokens(startToken, endToken) else { return false }

        let range = NSRange(location: 0, length: betweenTokens.utf16.count)
        return !regex("^\\s*\(regexString)\\s*$").matches(in: betweenTokens, options: [], range: range).isEmpty
    }
}
