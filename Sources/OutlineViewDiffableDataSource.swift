import AppKit

/// Offers a diffable interface for providing content for `NSOutlineView`.  It automatically performs insertions, deletions, and moves necessary to transition from one model-state snapshot to another.
open class OutlineViewDiffableDataSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

  /// Shortcut for outline view objects.
  public typealias Item = DiffableDataSourceSnapshot.Item

  /// Tree with data.
  private var diffableSnapshot: DiffableDataSourceSnapshot

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
    self.diffableSnapshot = .init()

    super.init()

    precondition(outlineView.dataSource == nil)
    precondition(outlineView.delegate == nil)
    outlineView.dataSource = self
    outlineView.delegate = self
    outlineView.usesAutomaticRowHeights = true
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
    diffableSnapshot.numberOfItems(in: item as? Item)
  }

  /// Uses diffable snapshot.
  public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    diffableSnapshot.childrenOfItem(item as? Item)[index]
  }

  /// Uses diffable snapshot.
  public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    guard let item = item as? OutlineViewItem else { return true }
    return item.isExpandable
  }

  /// Enables dragging for items which return Pasteboard representation.
  public func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
    guard let item = item as? Item, let itemId = diffableSnapshot.idForItem(item) else { return nil }
    return NSPasteboardItem(pasteboardPropertyList: itemId.uuidString, ofType: .itemID)
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
      if drop.operation.isEmpty == false, let childIndex = diffableSnapshot.indexOfItem(drop.targetItem) {
        let parentItem = diffableSnapshot.parentOfItem(drop.targetItem)
        outlineView.setDropItem(parentItem, dropChildIndex: childIndex)
      }
      return drop.operation

    // Re-target drop after item
    case .after:
      if drop.operation.isEmpty == false, let childIndex = diffableSnapshot.indexOfItem(drop.targetItem) {
        let parentItem = diffableSnapshot.parentOfItem(drop.targetItem)
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

  /// Returns current state of the data source. This property is thread-safe.
  func snapshot() -> DiffableDataSourceSnapshot {
    if Thread.isMainThread {
      return diffableSnapshot
    } else {
      return DispatchQueue.main.sync { diffableSnapshot }
    }
  }

  /// Applies the given snapshot to this data source in background.
  /// - Parameter snapshot: Snapshot with new data.
  /// - Parameter animatingDifferences: Pass false to disable animations.
  /// - Parameter completionHandler: Called asynchronously in the main thread when the new snapshot is applied.
  func applySnapshot(_ snapshot: DiffableDataSourceSnapshot, animatingDifferences: Bool, completionHandler: (() -> Void)? = nil) {

    // Source and Destination
    let oldSnapshot = self.snapshot()
    let newSnapshot = snapshot

    // Apply changes immediately if animation is disabled
    guard animatingDifferences else {
      func apply() {
        diffableSnapshot = newSnapshot
        outlineView?.reloadData()
        completionHandler?()
      }
      if Thread.isMainThread {
        apply()
      } else {
        DispatchQueue.main.async(execute: apply)
      }
      return
    }

    // Calculate changes
    let oldIndexedIds = oldSnapshot.indexedIds()
    let newIndexedIds = newSnapshot.indexedIds()
    let difference = newIndexedIds.difference(from: oldIndexedIds)
    let differenceWithMoves = difference.inferringMoves()

    // Apply changes changes
    func apply() {
      differenceWithMoves.forEach {
        switch $0 {

        case .insert(_, let inserted, let indexBefore):
          if let indexBefore = indexBefore {
            // Move outline view item
            let oldIndexedItemId = oldIndexedIds[indexBefore]
            let oldParent = oldIndexedItemId.parentId.flatMap(oldSnapshot.itemForId)
            let oldIndex = oldIndexedItemId.itemPath.last.unsafelyUnwrapped
            let newParent = inserted.parentId.flatMap(newSnapshot.itemForId)
            let newIndex = inserted.itemPath.last.unsafelyUnwrapped
            outlineView?.moveItem(at: oldIndex, inParent: oldParent, to: newIndex, inParent: newParent)

          } else {
            // Insert outline view item
            let insertionIndexes = IndexSet(integer: inserted.itemPath.last.unsafelyUnwrapped)
            let parentItem = inserted.parentId.flatMap(newSnapshot.itemForId)
            outlineView?.insertItems(at: insertionIndexes, inParent: parentItem, withAnimation: [.effectFade, .slideDown])
          }

        case .remove(_, let before, let indexAfter):
          if indexAfter == nil {
            // Delete outline view item
            let deletionIndexes = IndexSet(integer: before.itemPath.last.unsafelyUnwrapped)
            let oldParentItem = before.parentId.flatMap(oldSnapshot.itemForId)
            outlineView?.removeItems(at: deletionIndexes, inParent: oldParentItem, withAnimation: [.effectFade, .slideDown])
          }
        }
      }
    }

    // Animate with completion
    func applyWithAnimation() {
      NSAnimationContext.runAnimationGroup({ context in
        context.duration = animationDuration
        self.outlineView?.beginUpdates()
        self.diffableSnapshot = newSnapshot
        apply()
        self.outlineView?.endUpdates()
      }, completionHandler: completionHandler)
    }
    if Thread.isMainThread {
      applyWithAnimation()
    } else {
      DispatchQueue.main.sync(execute: applyWithAnimation)
    }
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
      guard let propertyList = pasteboardItem.propertyList(forType: .itemID) as? String,
        let itemId = DiffableDataSourceSnapshot.ItemID(uuidString: propertyList) else { return nil }
      return diffableSnapshot.itemForId(itemId)
    }
    guard draggedItems.count == pasteboardItems.count else { return nil }

    // Drop on the item
    let parentItem = item as? NSObject
    if index == NSOutlineViewDropOnItemIndex {
      return parentItem.map { .init(type: .on, targetItem: $0, draggedItems: draggedItems, operation: info.draggingSourceOperationMask) }
    }

    // Drop into the item
    let childItems = diffableSnapshot.childrenOfItem(parentItem)
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
