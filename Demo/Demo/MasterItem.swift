import AppKit
import OutlineViewDiffableDataSource

/// Sidebar iitems.
class MasterItem: OutlineViewItem, Codable {

  /// Unique identifier of the item.
  let id: String

  /// Visible string.
  let title: String

  /// Enable drag-n-drop.
  static let allowsDragging: Bool = true

  /// Creates a new item ready for insertion into the sidebar.
  init(id: String, title: String) {
    self.id = id
    self.title = title
  }

  /// Returns custom cell view type.
  func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type? {
    MasterCellView.self
  }
}

// MARK: -

extension MasterItem {

  /// Creates a new item an identifier inherited from the title.
  convenience init(title: String) {
    self.init(id: title.lowercased().replacingOccurrences(of: " ", with: "-"), title: title)
  }
}

// MARK: - Private API

final private class MasterCellView: CustomTableCellView {

  /// Shows the sidebar item title.
  override func updateContents() {
    guard let textField = textField, let masterItem = objectValue as? MasterItem else { return super.updateContents() }
    textField.stringValue = masterItem.title
  }
}
