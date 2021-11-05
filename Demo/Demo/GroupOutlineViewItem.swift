import AppKit
import OutlineViewDiffableDataSource

/// Default root item with buttons ‘Show’ and ‘Hide’, not intended for subclassing.
public final class MasterGroupOutlineViewItem: GroupOutlineViewItem {
  /// Display string.
  public let title: String

  /// Creates a “standard” root item for the sidebar.
  public init(id: String, title: String) {
    self.title = title
    super.init(id: id)
  }

  /// Returns an appropriate cell view type.
  public override func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type { GroupTableCellView.self }

  /// Necessary for sets.
  public override var hash: Int { title.hash }
}

// MARK: - Private API

/// Private implementation not intended for subclassing.
private final class GroupTableCellView: NSTableCellView {
  
  /// Creates a cell with a label that will be configure by AppKit.
  public init() {
    super.init(frame: .zero)

    let label = NSTextField(labelWithString: "")
    label.lineBreakMode = .byTruncatingTail
    label.allowsExpansionToolTips = true
    label.translatesAutoresizingMaskIntoConstraints = false
    label.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
    label.setContentCompressionResistancePriority(.fittingSizeCompression, for: .horizontal)
    addSubview(label)

    self.textField = label
    self.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 2),
      self.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: 1),
      self.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 2),
      self.heightAnchor.constraint(equalToConstant: 23),
    ])
  }

  @available(*, unavailable, message: "Use init")
  override init(frame frameRect: NSRect) {
    fatalError()
  }

  @available(*, unavailable, message: "Use init")
  public required init?(coder: NSCoder) {
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

  /// Retrieves new title from the associated group item.
  override var objectValue: Any? {
    didSet {
      if let label = textField, let groupItem = objectValue as? MasterGroupOutlineViewItem {
        label.stringValue = groupItem.title
      }
    }
  }
}
