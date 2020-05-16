import AppKit

/// Outline view cannot work with structs, identifiers are necessary for diffing and diagnostics, hashing is necessary for supporting drag-n-drop and expand-collapse.
public protocol OutlineViewItem: class, Identifiable, Hashable {

  /// Used to allow or deny selection for this item.
  var isSelectable: Bool { get }

  /// Used to show or hide the expansion arrow.
  var isExpandable: Bool { get }

  /// Called to create a cell view of the custom type.
  /// - Parameter tableColumn: Optional column that the view will be inserted into.
  func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type?

  /// Called to create a row view of the custom type.
  var rowViewType: NSTableRowView.Type? { get }

  /// Return true to enable drag-n-drop.
  static var allowsDragging: Bool { get }

  /// Returns ID representation for the Pasteboard item.
  var idPropertyList: Any? { get }

  /// Optional id from the Pasteboard.
  static func idFromPropertyList(_ propertyList: Any) -> ID?
}

// MARK: -

public extension OutlineViewItem {

  /// Any item can be selected by default.
  var isSelectable: Bool { true }

  /// Any item can be expanded and collapsed by default.
  var isExpandable: Bool { true }

  /// Use a standard cell view type by default.
  func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type? { nil }

  /// Use a standard row view type by default.
  var rowViewType: NSTableRowView.Type? { nil }

  /// Disable drag-n-drop by default.
  static var allowsDragging: Bool { false }

  /// All items can be dragged by default.
  var idPropertyList: Any? { id }

  /// All items can be dropped by default.
  static func idFromPropertyList(_ propertyList: Any) -> ID? { propertyList as? ID }

  /// Compares by id by default.
  static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

  /// Hashes only id by default.
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
