import AppKit
import OutlineViewDiffableDataSource

/// Sidebar iitems.
struct MasterItem: OutlineViewItem {

  /// Unique identifier of the item.
  let id: String

  /// Visible string.
  let title: String

  /// Returns custom cell view type.
  func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type? {
    MasterCellView.self
  }

  /// Creates a new item ready for insertion into the sidebar.
  init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

// MARK: - Internal API

extension MasterItem {

  /// Creates a new item an identifier inherited from the title.
  init(title: String) {
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
