//
//  LintCommand.swift
//  SwiftLint
//
//  Created by JP Simard on 5/16/15.
//  Copyright © 2015 Realm. All rights reserved.
//

import Commandant
import Foundation
import Result
import SourceKittenFramework
import SwiftLintFramework

struct LintCommand: CommandProtocol {
    let verb = "lint"
    let function = "Print lint warnings and errors (default command)"

    func run(_ options: LintOptions) -> Result<(), CommandantError<()>> {
        var fileBenchmark = Benchmark(name: "files")
        var ruleBenchmark = Benchmark(name: "rules")
        var violations = [StyleViolation]()
        let configuration = Configuration(options: options)
        let reporter = reporterFrom(options: options, configuration: configuration)
        return configuration.visitLintableFiles(options) { linter in
            let currentViolations: [StyleViolation]
            if options.benchmark {
                let start = Date()
                let (_currentViolations, currentRuleTimes) = linter.styleViolationsAndRuleTimes
                currentViolations = _currentViolations
                fileBenchmark.record(file: linter.file, from: start)
                currentRuleTimes.forEach { ruleBenchmark.record(id: $0, time: $1) }
            } else {
                currentViolations = linter.styleViolations
            }
            linter.file.invalidateCache()
            violations += currentViolations
            reporter.reportViolations(currentViolations, realtimeCondition: true)
        }.flatMap { files in
            if LintCommand.isWarningThresholdBroken(configuration, violations: violations) {
                violations.append(LintCommand.createThresholdViolation(configuration.warningThreshold!))
                reporter.reportViolations([violations.last!], realtimeCondition: true)
            }
            reporter.reportViolations(violations, realtimeCondition: false)
            let numberOfSeriousViolations = violations.filter({ $0.severity == .error }).count
            if !options.quiet {
                LintCommand.printStatus(violations: violations, files: files,
                                        serious: numberOfSeriousViolations)
            }
            if options.benchmark {
                fileBenchmark.save()
                ruleBenchmark.save()
            }
            return LintCommand.successOrExit(numberOfSeriousViolations: numberOfSeriousViolations,
                                             strictWithViolations: options.strict && !violations.isEmpty)
        }
    }

    private static func successOrExit(numberOfSeriousViolations: Int,
                                      strictWithViolations: Bool) -> Result<(), CommandantError<()>> {
        if numberOfSeriousViolations > 0 {
            exit(2)
        } else if strictWithViolations {
            exit(3)
        }
        return .success()
    }

    private static func printStatus(violations: [StyleViolation], files: [File], serious: Int) {
        let pluralSuffix = { (collection: [Any]) -> String in
            return collection.count != 1 ? "s" : ""
        }
        queuedPrintError(
            "Done linting! Found \(violations.count) violation\(pluralSuffix(violations)), " +
            "\(serious) serious in \(files.count) file\(pluralSuffix(files))."
        )
    }

    private static func isWarningThresholdBroken(_ configuration: Configuration,
                                                 violations: [StyleViolation]) -> Bool {
        guard let warningThreshold = configuration.warningThreshold else { return false }
        let numberOfWarningViolations = violations.filter({ $0.severity == .warning }).count
        return numberOfWarningViolations >= warningThreshold
    }

    private static func createThresholdViolation(_ threshold: Int) -> StyleViolation {
        let description = RuleDescription(
            identifier: "warning_threshold",
            name: "Warning Threshold",
            description: "Number of warnings thrown is above the threshold."
        )
        return StyleViolation(
            ruleDescription: description,
            severity: .error,
            location: Location(file: "", line: 0, character: 0),
            reason: "Number of warnings exceeded threshold of \(threshold).")
    }
}

struct LintOptions: OptionsProtocol {
    let path: String
    let useSTDIN: Bool
    let configurationFile: String
    let strict: Bool
    let useScriptInputFiles: Bool
    let benchmark: Bool
    let reporter: String
    let quiet: Bool

    // swiftlint:disable line_length
    static func create(_ path: String) -> (_ useSTDIN: Bool) -> (_ configurationFile: String) -> (_ strict: Bool) -> (_ useScriptInputFiles: Bool) -> (_ benchmark: Bool) -> (_ reporter: String) -> (_ quiet: Bool) -> LintOptions {
        return { useSTDIN in { configurationFile in { strict in { useScriptInputFiles in { benchmark in { reporter in { quiet in
            self.init(path: path, useSTDIN: useSTDIN, configurationFile: configurationFile, strict: strict, useScriptInputFiles: useScriptInputFiles, benchmark: benchmark, reporter: reporter, quiet: quiet)
        }}}}}}}
    }

    static func evaluate(_ mode: CommandMode) -> Result<LintOptions, CommandantError<CommandantError<()>>> {
        // swiftlint:enable line_length
        return create
            <*> mode <| pathOption(action: "lint")
            <*> mode <| Option(key: "use-stdin", defaultValue: false,
                               usage: "lint standard input")
            <*> mode <| configOption
            <*> mode <| Option(key: "strict", defaultValue: false,
                               usage: "fail on warnings")
            <*> mode <| useScriptInputFilesOption
            <*> mode <| Option(key: "benchmark", defaultValue: false,
                               usage: "save benchmarks to benchmark_files.txt " +
                                      "and benchmark_rules.txt")
            <*> mode <| Option(key: "reporter", defaultValue: "",
                               usage: "the reporter used to log errors and warnings")
            <*> mode <| quietOption(action: "linting")
    }
}
