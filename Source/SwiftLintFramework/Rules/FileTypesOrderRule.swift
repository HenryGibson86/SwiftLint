import Foundation
import SourceKittenFramework

private enum FileType {
    case supportingType
    case mainType
    case `extension`

    static var defaultOrder: [[FileType]] {
        return [
            [.supportingType],
            [.mainType],
            [.extension]
        ]
    }
}

public struct FileTypesOrderRule: ConfigurationProviderRule, OptInRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "file_types_order",
        name: "File Types Order",
        description: "Specifies how the types within a file should be ordered.",
        kind: .style,
        nonTriggeringExamples: [
            """
            // Supporting Types
            protocol TestViewControllerDelegate {
                func didPressTrackedButton()
            }

            class TestViewController: UIViewController {
                // Type Aliases
                typealias CompletionHandler = ((TestEnum) -> Void)

                // Subtypes
                class TestClass {
                    // 10 lines
                }

                struct TestStruct {
                    // 3 lines
                }

                enum TestEnum {
                    // 5 lines
                }

                // Stored Type Properties
                static let cellIdentifier: String = "AmazingCell"

                // Stored Instance Properties
                var shouldLayoutView1: Bool!
                weak var delegate: TestViewControllerDelegate?
                private var hasLayoutedView1: Bool = false
                private var hasLayoutedView2: Bool = false

                // Computed Instance Properties
                private var hasAnyLayoutedView: Bool {
                     return hasLayoutedView1 || hasLayoutedView2
                }

                // IBOutlets
                @IBOutlet private var view1: UIView!
                @IBOutlet private var view2: UIView!

                // Initializers
                override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
                    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
                }

                required init?(coder aDecoder: NSCoder) {
                    fatalError("init(coder:) has not been implemented")
                }

                // Type Methods
                static func makeViewController() -> TestViewController {
                    // some code
                }

                // Life-Cycle Methods
                override func viewDidLoad() {
                    super.viewDidLoad()

                    view1.setNeedsLayout()
                    view1.layoutIfNeeded()
                    hasLayoutedView1 = true
                }

                override func viewDidLayoutSubviews() {
                    super.viewDidLayoutSubviews()

                    view2.setNeedsLayout()
                    view2.layoutIfNeeded()
                    hasLayoutedView2 = true
                }

                // IBActions
                @IBAction func goNextButtonPressed() {
                    goToNextVc()
                    delegate?.didPressTrackedButton()
                }

                @objc
                func goToRandomVcButtonPressed() {
                    goToRandomVc()
                }

                // MARK: Other Methods
                func goToNextVc() { /* TODO */ }

                func goToInfoVc() { /* TODO */ }

                func goToRandomVc() {
                    let viewCtrl = getRandomVc()
                    present(viewCtrl, animated: true)
                }

                private func getRandomVc() -> UIViewController { return UIViewController() }

                // Subscripts
                subscript(_ someIndexThatIsNotEvenUsed: Int) -> String {
                    get {
                        return "This is just a test"
                    }

                    set {
                        log.warning("Just a test", newValue)
                    }
                }
            }

            // Extensions
            extension TestViewController: UITableViewDataSource {
                func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                    return 1
                }

                func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                    return UITableViewCell()
                }
            }
            """
        ],
        triggeringExamples: [
            """
            class TestViewController: UIViewController {}

            // Supporting Types
            protocol TestViewControllerDelegate {
                func didPressTrackedButton()
            }
            """,
            """
            // Extensions
            extension TestViewController: UITableViewDataSource {
                func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                    return 1
                }

                func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                    return UITableViewCell()
                }
            }

            class TestViewController: UIViewController {}
            """
        ]
    )

    public func validate(file: File) -> [StyleViolation] {
        return [] // TODO: not yet implemented
    }

    private func supportingTypesSubstructures(
        in file: File,
        mainTypeSubstructure: [String: SourceKitRepresentable]
    ) -> [[String: SourceKitRepresentable]] {
        return file.structure.dictionary.substructure.filter { substructure in
            return substructure.bridge() != mainTypeSubstructure.bridge() &&
                !substructure.kind!.contains(SwiftDeclarationKind.extension.rawValue)
        }
    }

    private func mainTypeSubstructure(in file: File) -> [String: SourceKitRepresentable]? {
        let dict = file.structure.dictionary

        guard let filePath = file.path else {
            return self.mainTypeSubstructure(in: dict)
        }

        let fileName = URL(fileURLWithPath: filePath).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        guard let mainTypeSubstructure = dict.substructure.first(where: { $0.name == fileName }) else {
            return self.mainTypeSubstructure(in: file.structure.dictionary)
        }

        // specify type with name matching the files name as main type
        return mainTypeSubstructure
    }

    private func mainTypeSubstructure(in dict: [String: SourceKitRepresentable]) -> [String: SourceKitRepresentable]? {
        let priorityKinds: [SwiftDeclarationKind] = [.class, .enum, .struct]
        let priorityKindRawValues = priorityKinds.map { $0.rawValue }
        let priorityKindSubstructures = dict.substructure.filter { priorityKindRawValues.contains($0.kind!) }
        let substructuresSortedByBodyLength = priorityKindSubstructures.sorted { lhs, rhs in
            return lhs.bodyLength! > rhs.bodyLength!
        }

        guard let mainTypeSubstructure = substructuresSortedByBodyLength.first else {
            let substructuresSortedByBodyLength = dict.substructure.sorted { lhs, rhs in
                return lhs.bodyLength! > rhs.bodyLength!
            }

            // specify substructure with longest body as main type if existent
            return substructuresSortedByBodyLength.first
        }

        // specify class, enum or struct with longest body as main type
        return mainTypeSubstructure
    }
}
