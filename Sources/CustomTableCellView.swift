import AppKit

/// Custom implementation.
class CustomTableCellView: NSTableCellView {

  /// Creates a cell with a label.
  init() {
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
}

// MARK: -

extension CustomTableCellView {

  /// Erases previous contents before inserting cell view into the column.
  override func prepareForReuse() {
    super.prepareForReuse()

    self.textField?.stringValue = ""
  }

  /// Updates the label using an object value.
  override var objectValue: Any? {
    didSet {
      self.textField?.stringValue = objectValue.map(String.init(describing:)) ?? ""
    }
  }
}
