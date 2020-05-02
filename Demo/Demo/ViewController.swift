import AppKit
import OutlineViewDiffableDataSource

class ViewController: NSViewController {

  /// Leading outline view.
  @IBOutlet var outlineView: NSOutlineView?

  /// Trailing text view.
  @IBOutlet var textView: NSTextView?

  /// Tree item.
  struct OutlineItem: Diffable {
    let id: String
  }

  /// Diffable data source similar to `NSCollectionViewDiffableDataSource`.
  var dataSource: OutlineViewDiffableDataSource<OutlineItem>?
}

// MARK: -

extension ViewController {

  /// Configures diffable data source.
  override func viewDidLoad() {
    super.viewDidLoad()

    guard let outlineView = self.outlineView else { return }
    dataSource = .init(outlineView: outlineView)
  }
}

// MARK: - Actions

private extension ViewController {

  /// Called when you hit the button.
  @IBAction func applySnapshot(_ sender: Any?) {
    guard let textView = self.textView else { return }
    var snapshot: DiffableDataSourceSnapshot<OutlineItem> = .init()
    let lines = textView.string.components(separatedBy: .newlines)
    for line in lines {
      let items = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.isEmpty == false }.map(OutlineItem.init(id:))
      switch items.count {
      case 1:
        snapshot.appendItems([items[0]])
      case 2:
        snapshot.appendItems([items[0]])
        snapshot.appendItems([items[1]], into: items[0])
      default:
        continue
      }
    }
    let shouldAnimate = UserDefaults.standard.bool(forKey: "ShouldAnimate")
    dataSource?.applySnapshot(snapshot, animatingDifferences: shouldAnimate)
  }
}
