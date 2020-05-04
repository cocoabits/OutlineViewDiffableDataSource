import AppKit

/// View model for the outline view row.
public protocol OutlineViewItem: Identifiable {

  /// Used to allow or deny selection for this item.
  var isSelectable: Bool { get }

  /// Used to show or hide the expansion arrow.
  var isExpandable: Bool { get }

  /// Called to create a cell view of the custom type.
  /// - Parameter tableColumn: Optional column that the view will be inserted into.
  func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type?

  /// Called to create a row view of the custom type.
  var rowViewType: NSTableRowView.Type? { get }
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
}
