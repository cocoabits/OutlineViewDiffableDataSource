import AppKit
import OutlineViewDiffableDataSource

/// Sidebar iitems.
class MasterOutlineViewItem: OutlineViewItem {
  /// Visible string.
  let title: String

  /// Creates a new item ready for insertion into the sidebar.
  init(id: String, title: String) {
    self.title = title
    super.init(id: id)
  }
  
  /// Returns a private cell view type.
  override func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type { MasterCellView.self }

  /// Necessary for supporting drag-n-drop and expand-collapse.
  override var hash: Int { title.hash }
}

// MARK: - Private API

final private class MasterCellView: NSTableCellView {

  /// Creates a cell with a label.
  init() {
    super.init(frame: .zero)

    let label = NSTextField(labelWithString: "")
    label.translatesAutoresizingMaskIntoConstraints = false
    label.lineBreakMode = .byTruncatingTail
    label.allowsExpansionToolTips = true
    label.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
    label.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)
    addSubview(label)

    self.textField = label
    self.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 2),
      self.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
      self.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: 1),
      self.heightAnchor.constraint(equalToConstant: 22),
    ])
  }

  @available(*, unavailable, message: "Use init")
  override init(frame frameRect: NSRect) {
    fatalError()
  }

  @available(*, unavailable, message: "Use init")
  required init?(coder: NSCoder) {
    fatalError()
  }

  // MARK: -

  /// Erases previous title.
  override func prepareForReuse() {
    super.prepareForReuse()

    if let label = textField {
      label.stringValue = ""
    }
  }

  /// Retrieves new title from the associated master item.
  override var objectValue: Any? {
    didSet {
      if let label = textField, let masterItem = objectValue as? MasterOutlineViewItem {
        label.stringValue = masterItem.title
      }
    }
  }
}
