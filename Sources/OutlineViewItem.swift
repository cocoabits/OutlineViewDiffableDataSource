import AppKit

/// Outline view cannot work with structs, identifiers are necessary for diffing and diagnostics, hashing is necessary for supporting drag-n-drop and expand-collapse.
open class OutlineViewItem: NSObject {

  /// Unique identifier for diffing.
  public let id: String
  
  /// Used to allow or deny selection for this item. Any item can be selected by default.
  open var isSelectable = true

  /// Used to show or hide the expansion arrow. Any node with a child is expandable by default. Setting this to `false` will disable expansion irrespectively.
  open var isExpandable = true

  /// Can be used for root items with ‘Show’ and ‘Hide’ buttons. Not a group item by default.
  open var isGroup: Bool { false }
  
  public init(id: String) {
    self.id = id
    
    super.init()
  }

  /// Called to create a cell view of the custom type. Returns an empty cell view by default.
  /// - Parameter tableColumn: Optional column that the view will be inserted into.
  open func cellViewType(for tableColumn: NSTableColumn?) -> NSTableCellView.Type {
    NSTableCellView.self
  }

  /// Called to create a row view of the custom type. Use a standard row view type by default.
  open var rowViewType: NSTableRowView.Type? { nil }
  
  open override var hash: Int { id.hash }
  
  open override func isEqual(_ object: Any?) -> Bool {
    guard let otherItem = object as? OutlineViewItem else { return false }
    return otherItem.id == id
  }  
}

open class GroupOutlineViewItem: OutlineViewItem {
  /// Show as Group.
  public override var isGroup: Bool { true }
  
  /// Deny selection.
  open override var isSelectable: Bool {
    get { false }
    set { }
  }
}
