import AppKit

/// Offers a diffable interface for providing content for `NSOutlineView`.  It automatically performs insertions, deletions, and moves necessary to transition from one model-state snapshot to another.
/// This relies on a `DiffableDataSourceSnapshot`, which serves as a shadow data source, describing each node of the tree.
open class OutlineViewDiffableDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
  
  /// Shortcut for outline view objects.
  public typealias Item = DiffableDataSourceSnapshot.Item
  
  /// Tree with data.
  private var currentSnapshot: DiffableDataSourceSnapshot
  
  /// Associated outline view.
  private weak var outlineView: NSOutlineView?
  
  /// Re-targeting API for drag-n-drop.
  public struct ProposedDrop {
    /// Dropping type.
    public enum `Type` {
      case on, before, after
    }
    
    /// Dropping type.
    public var type: Type
    
    /// Target item.
    public var targetItem: Item
    
    /// Items being dragged.
    public var draggedItems: [Item]
    
    /// Proposed operation.
    public var operation: NSDragOperation
    
    /// Creates a new item drag-n-drop “proposal”.
    public init(type: Type, targetItem: Item, draggedItems: [Item], operation: NSDragOperation) {
      self.type = type
      self.targetItem = targetItem
      self.draggedItems = draggedItems
      self.operation = operation
    }
  }
  
  /// Callbacks for drag-n-drop.
  public typealias DraggingHandlers = (
    validateDrop: (_ sender: OutlineViewDiffableDataSource, _ drop: ProposedDrop) -> ProposedDrop?,
    acceptDrop: (_ sender: OutlineViewDiffableDataSource, _ drop: ProposedDrop) -> Bool
  )
  
  /// Assign non-nil value to enable drag-n-drop.
  public var draggingHandlers: DraggingHandlers?
  
  /// Creates a new data source as well as a delegate for the given outline view.
  /// - Parameter outlineView: Outline view without a data source and without a delegate.
  public init(outlineView: NSOutlineView) {
    self.currentSnapshot = .init()
    
    super.init()
    
    precondition(outlineView.dataSource == nil)
    precondition(outlineView.delegate == nil)
    outlineView.delegate = self
    self.outlineView = outlineView
    outlineView.registerForDraggedTypes(outlineView.registeredDraggedTypes + [.itemID])
  }
  
  deinit {
    self.outlineView?.dataSource = nil
    self.outlineView?.delegate = nil
  }
  
  // MARK: - NSOutlineViewDataSource
  
  /// Uses diffable snapshot.
  public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    let count = currentSnapshot.numberOfItems(in: item as? Item)
    return count
  }
  
  /// Uses diffable snapshot.
  public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    let childItem = currentSnapshot.childrenOfItem(item as? Item)[index]
    return childItem
  }
  
  /// Uses diffable snapshot.
  public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard let item = item as? OutlineViewItem else { return true }
    return item.isExpandable && currentSnapshot.childrenOfItem(item).count > 0
  }
  
  // MARK: Drag & Drop
  
  /// Enables dragging for items which return Pasteboard representation.
  public func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
    guard let item = item as? Item,
          let itemId = currentSnapshot.idForItem(item) else { return nil }
    
    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setString(itemId, forType: .itemID)
    return pasteboardItem
  }
  
  /// This override is necessary to disable special mouse down behavior in the outline view.
  public override func responds(to aSelector: Selector?) -> Bool {
    if draggingHandlers == nil && aSelector == #selector(outlineView(_:pasteboardWriterForItem:)) {
      return false
    } else {
      return super.responds(to: aSelector)
    }
  }
  
  /// Enables drag-n-drop validation.
  public func outlineView(
    _ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int
  ) -> NSDragOperation {
    
    // Calculate proposed change if allowed and take decision from the client handler
    guard let proposedDrop = proposedDrop(using: info, proposedItem: item, proposedChildIndex: index),
          let handlers = draggingHandlers, let drop = handlers.validateDrop(self, proposedDrop) else { return [] }
    switch drop.type {
        
        // Re-target drop on item
      case .on:
        if drop.operation.isEmpty == false {
          outlineView.setDropItem(drop.targetItem, dropChildIndex: NSOutlineViewDropOnItemIndex)
        }
        return drop.operation
        
        // Re-target drop before item
      case .before:
        if drop.operation.isEmpty == false, let childIndex = currentSnapshot.indexOfItem(drop.targetItem) {
          let parentItem = currentSnapshot.parentOfItem(drop.targetItem)
          outlineView.setDropItem(parentItem, dropChildIndex: childIndex)
        }
        return drop.operation
        
        // Re-target drop after item
      case .after:
        if drop.operation.isEmpty == false, let childIndex = currentSnapshot.indexOfItem(drop.targetItem) {
          let parentItem = currentSnapshot.parentOfItem(drop.targetItem)
          outlineView.setDropItem(parentItem, dropChildIndex: childIndex + 1)
        }
        return drop.operation
    }
  }
  
  /// Accepts drag-n-drop after validation.
  public func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
    guard let drop = proposedDrop(using: info, proposedItem: item, proposedChildIndex: index), let handlers = draggingHandlers else { return false }
    return handlers.acceptDrop(self, drop)
  }
  
  // MARK: - NSOutlineViewDelegate
  
  /// Enables special appearance for group items.
  public func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
    guard let item = item as? OutlineViewItem else { return false }
    return item.isGroup
  }
  
  /// Creates a cell view for the given item,
  public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let item = item as? OutlineViewItem else { return nil }
    
    let cellViewType = item.cellViewType(for: tableColumn)
    let cellViewTypeIdentifier = NSUserInterfaceItemIdentifier(NSStringFromClass(cellViewType))
    let cachedCellView = outlineView.makeView(withIdentifier: cellViewTypeIdentifier, owner: self)
    
    let cellView = cachedCellView as? NSTableCellView ?? {
      let newCellView = cellViewType.init()
      newCellView.identifier = cellViewTypeIdentifier
      return newCellView
    }()
    
    cellView.objectValue = item
    
    return cellView
  }
  
  /// Filters selectable items.
  public func outlineView(_ outlineView: NSOutlineView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
    proposedSelectionIndexes.filteredIndexSet {
      guard let item = outlineView.item(atRow: $0) as? OutlineViewItem else { return false }
      
      return item.isSelectable
    }
  }
  
  /// Creates a row view for the given item,
  public func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
    guard let item = item as? OutlineViewItem else { return nil }
    
    let rowViewType = item.rowViewType ?? NSTableRowView.self
    let rowViewTypeIdentifier = NSUserInterfaceItemIdentifier(NSStringFromClass(rowViewType))
    let cachedRowView = outlineView.makeView(withIdentifier: rowViewTypeIdentifier, owner: self)
    
    let rowView = cachedRowView as? NSTableRowView ?? {
      let newRowView = rowViewType.init()
      newRowView.identifier = rowViewTypeIdentifier
      return newRowView
    }()
    
    return rowView
  }
}

// MARK: - Public API

public extension OutlineViewDiffableDataSource {
  
  /// Returns current state of the data source.
  func snapshot() -> DiffableDataSourceSnapshot {
    assert(Thread.isMainThread, "Should be called on the main thread")
    
    return currentSnapshot
  }
  
  /// Performs a `reloadData`
  func reloadData() {
    // ensure data source is set
    outlineView?.dataSource = self
    outlineView?.reloadData()
  }
  
  /// Applies the given snapshot to this data source.
  /// - Parameter snapshot: Snapshot with new data.
  /// - Parameter animatingDifferences: Pass false to disable animations.
  /// - Parameter completionHandler: Called asynchronously in the main thread when the new snapshot is applied.
  func applySnapshot(_ snapshot: DiffableDataSourceSnapshot, animatingDifferences: Bool, completionHandler: (() -> Void)? = nil) {
    assert(Thread.isMainThread, "Should be called on the main thread")
    
    // Source and Destination
    let oldSnapshot = self.snapshot()
    let newSnapshot = snapshot
    
    // Update our final snapshot before we animate
    currentSnapshot = newSnapshot
    
    // Apply changes immediately if animation is disabled
    // When a data source is not set, reload the first time
    guard animatingDifferences, let _ = outlineView?.dataSource else {
      reloadData()
      completionHandler?()
      return
    }
    
    // Calculate changes
    let oldIndexedIds = oldSnapshot.indexedIds()
    let newIndexedIds = newSnapshot.indexedIds()
    
    let difference = newIndexedIds.changes(from: oldIndexedIds)
    
    // Some threshold - won't make sense to animate this many changes
    let changeThreshold = 300
    let totalChanges = difference.insertions.count + difference.removals.count
    
    guard totalChanges < changeThreshold else {
      reloadData()
      completionHandler?()
      return
    }
    
    let differenceWithMoves = difference.inferringMoves()
            
    // Animate with completion
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = animationDuration
      
      self.outlineView?.beginUpdates()
      
      // Collect a list of parent items that had their children added / removed. Outline view will not automatically
      // reload the parent item (and more importantly its expansion state). Once we're done, we'll walk over this
      // list and reload any node that's still there
      var parentItemsToReload = Set<DiffableDataSourceSnapshot.ItemID>()
      
      // Apply changes. Called from within `beginUpdates` and `endUpdates`
      differenceWithMoves.forEach { move in
        switch move {
            
          case .insert(_, let inserted, let previousOffset):
            if let previousOffset = previousOffset {
              // Move outline view item from old to new position
              // previousOffset here is the offset in our flattened list of indexed IDs
              let oldIndexedItemId = oldIndexedIds[previousOffset]
              
              let oldParentItem = oldIndexedItemId.parentId.flatMap(oldSnapshot.itemForId)
              let oldIndex = oldIndexedItemId.itemPath.last.unsafelyUnwrapped
              
              let newParentItem = inserted.parentId.flatMap(newSnapshot.itemForId)
              let newIndex = inserted.itemPath.last.unsafelyUnwrapped
              
              outlineView?.moveItem(at: oldIndex, inParent: oldParentItem, to: newIndex, inParent: newParentItem)
              
              if let oldParentItem = oldParentItem {
                parentItemsToReload.insert(oldParentItem.id)
              }
              if let newParentItem = newParentItem {
                parentItemsToReload.insert(newParentItem.id)
              }
            }
            else {
              // Insert outline view item
              let insertionIndex = IndexSet(integer: inserted.itemPath.last.unsafelyUnwrapped)
              let parentItem = inserted.parentId.flatMap(newSnapshot.itemForId)
              
              // Before inserting an item, reload the parent item to avoid glitches where the expansion arrow would
              // overlap the item
              outlineView?.reloadItem(parentItem, reloadChildren: false)
              outlineView?.insertItems(at: insertionIndex, inParent: parentItem, withAnimation: [.effectFade, .slideDown])
            }
            
          case .remove(_, let before, let associatedWith):
            // A non-nil associatedWith value is the offset of the complementary change.
            // A missing associatedWith value indicates this item was removed entirely
            if associatedWith == nil {
              // Delete outline view item from its parent
              let deletionIndex = IndexSet(integer: before.itemPath.last.unsafelyUnwrapped)
              let oldParentItem = before.parentId.flatMap(oldSnapshot.itemForId)
              
              outlineView?.removeItems(at: deletionIndex, inParent: oldParentItem, withAnimation: [.effectFade, .slideDown])
              
              if let oldParentItem = oldParentItem {
                parentItemsToReload.insert(oldParentItem.id)
              }
            }
            else {
              // the item moved since it's got a valid "index after". We handle moves in `.insert` so this can be
              // ignored
            }
        }
      }
      
      // Reload parents now
      parentItemsToReload.forEach { parentItemIDToReload in
        if let itemInNewSnapshot = newSnapshot.itemForId(parentItemIDToReload) {
          outlineView?.reloadItem(itemInNewSnapshot, reloadChildren: false)
        }
      }
            
      self.outlineView?.endUpdates()
    }, completionHandler: completionHandler)
  }
}

// MARK: - Private API

private extension OutlineViewDiffableDataSource {
  
  /// Calculates proposed drop for the given input.
  func proposedDrop(using info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> ProposedDrop? {
    guard let pasteboardItems = info.draggingPasteboard.pasteboardItems,
          pasteboardItems.isEmpty == false else { return nil }
    
    // Retrieve dragged items
    let draggedItems: [Item] = pasteboardItems.compactMap { pasteboardItem in
      guard let itemId = pasteboardItem.string(forType: .itemID) else {
        return nil
      }
      return currentSnapshot.itemForId(itemId)
    }
    guard draggedItems.count == pasteboardItems.count else { return nil }
    
    // Drop on the item
    let parentItem = item as? OutlineViewItem
    if index == NSOutlineViewDropOnItemIndex {
      return parentItem.map { .init(type: .on, targetItem: $0, draggedItems: draggedItems, operation: info.draggingSourceOperationMask) }
    }
    
    // Drop into the item
    let childItems = currentSnapshot.childrenOfItem(parentItem)
    guard childItems.isEmpty == false else { return nil }
    
    // Use “before” or “after” depending on index
    return index > 0
    ? .init(type: .after, targetItem: childItems[index - 1], draggedItems: draggedItems, operation: info.draggingSourceOperationMask)
    : .init(type: .before, targetItem: childItems[index], draggedItems: draggedItems, operation: info.draggingSourceOperationMask)
  }
}

private extension NSPasteboard.PasteboardType {
  
  /// Custom dragging type.
  static let itemID: NSPasteboard.PasteboardType = .init("OutlineViewDiffableDataSource.ItemID")
}

/// How much time should be spent for animation.
private var animationDuration: TimeInterval {
  let defaultDuration = 0.35
  guard let currentEvent = NSApplication.shared.currentEvent else { return defaultDuration }
  let flags = currentEvent.modifierFlags.intersection([.shift, .option, .control, .command])
  return defaultDuration * (flags == .shift ? 10 : 1)
}
