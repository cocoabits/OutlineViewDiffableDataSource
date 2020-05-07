import AppKit
import SwiftUI
import OutlineViewDiffableDataSource

/// Editor for the single selected item in the sidebar.
final class SingleViewController: NSViewController {

  /// Multiline text editor for the outline contents.
  private lazy var scrollableEditor: NSScrollView = {
    let scrollView = NSTextView.scrollablePlainDocumentContentTextView()
    scrollView.borderType = .lineBorder
    if let textView = scrollView.documentView as? NSTextView {
      textView.textContainerInset = NSMakeSize(8, 8)
      textView.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
    }
    return scrollView
  }()

  /// Sidebar data source.
  private let snapshotBinding: Binding<DiffableDataSourceSnapshot<MasterItem>>

  /// Creates a new editor for a single sidebar item.
  init(binding: Binding<DiffableDataSourceSnapshot<MasterItem>>) {
    self.snapshotBinding = binding

    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable, message: "IB is denied")
  required init?(coder: NSCoder) {
    fatalError()
  }
}

// MARK: -

extension SingleViewController {

  /// Creates a vertical stack of controls.
  override func loadView() {
    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.distribution = .fill
    stackView.addView(scrollableEditor, in: .center)
    stackView.addView(NSButton(title: "Append Item Contents", target: self, action: #selector(appendItemContents(_:))), in: .center)
    stackView.addView(NSButton(title: "Remove Selected Item", target: self, action: #selector(removeSelectedItem(_:))), in: .center)
    stackView.setHuggingPriority(.fittingSizeCompression, for: .horizontal)
    view = stackView
  }
}

// MARK: - Actions

private extension SingleViewController {

  /// Inserts item contents.
  @IBAction func appendItemContents(_ sender: Any?) {
    guard let textView = scrollableEditor.documentView as? NSTextView else { return }
    let lines = textView.string.components(separatedBy: .newlines)

    guard let selectedItem = representedObject as? MasterItem else { return }
    var snapshot = snapshotBinding.wrappedValue
    for line in lines {
      let items = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.isEmpty == false }.map(MasterItem.init(title:))
      switch items.count {
      case 1:
        if snapshot.itemWithIdentifier(items[0].id) == nil {
          snapshot.appendItems([items[0]], into: selectedItem)
        }
      case 2:
        if snapshot.itemWithIdentifier(items[0].id) == nil {
          snapshot.appendItems([items[0]], into: selectedItem)
        }
        if snapshot.itemWithIdentifier(items[1].id) == nil {
          snapshot.appendItems([items[1]], into: items[0])
        }
      default:
        continue
      }
    }
    snapshotBinding.wrappedValue = snapshot
  }

  /// Removes selected item.
  @IBAction func removeSelectedItem(_ sender: Any?) {
    guard let selectedItem = representedObject as? MasterItem else { return }
    var snapshot = snapshotBinding.wrappedValue
    snapshot.deleteItems([selectedItem])
    snapshotBinding.wrappedValue = snapshot
  }
}
