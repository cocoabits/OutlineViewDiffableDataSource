import AppKit
import OutlineViewDiffableDataSource

class ViewController: NSViewController {

  /// Leading outline view.
  @IBOutlet var outlineView: NSOutlineView?

  /// Trailing text view.
  @IBOutlet var textView: NSTextView?

  /// Sample item.
  struct SampleItem: OutlineViewItem {
    let id: String
  }

  /// Diffable data source similar to `NSCollectionViewDiffableDataSource`.
  var dataSource: OutlineViewDiffableDataSource<SampleItem>?
}

// MARK: -

extension ViewController {

  /// Configures diffable data source.
  override func viewDidLoad() {
    super.viewDidLoad()

    if let textView = self.textView, textView.string.isEmpty {
      textView.string = """
        Parent 1 / Child 11
        Parent 1 / Child 12
        Parent 1 / Child 13
        Parent 2
        Parent 3 / Child 31
        Parent 3 / Child 32
        Parent 3 / Child 33
        """
    }

    guard let outlineView = self.outlineView else { return }
    dataSource = .init(outlineView: outlineView)

    reloadData(animated: false)
    outlineView.expandItem(nil, expandChildren: true)
  }
}

// MARK: - Actions

private extension ViewController {

  /// Called when you hit the button.
  @IBAction func applySnapshot(_ sender: Any?) {
    reloadData(animated: UserDefaults.standard.bool(forKey: "ShouldAnimate"))
  }
}

// MARK: - Private API

private extension ViewController {

  /// Creates a snapshot from the text view contents.
  func reloadData(animated: Bool) {
    guard let textView = self.textView, let dataSource = self.dataSource else { return }
    var snapshot: DiffableDataSourceSnapshot<SampleItem> = .init()
    let lines = textView.string.components(separatedBy: .newlines)
    for line in lines {
      let items = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.isEmpty == false }.map(SampleItem.init(id:))
      switch items.count {
      case 1:
        if snapshot.itemWithIdentifier(items[0].id) == nil {
          snapshot.appendItems([items[0]])
        }
      case 2:
        if snapshot.itemWithIdentifier(items[0].id) == nil {
          snapshot.appendItems([items[0]])
        }
        if snapshot.itemWithIdentifier(items[1].id) == nil {
          snapshot.appendItems([items[1]], into: items[0])
        }
      default:
        continue
      }
    }
    dataSource.applySnapshot(snapshot, animatingDifferences: animated)
  }
}
