import AppKit

/// Offers a diffable interface for providing content for `NSOutlineView`.  It automatically performs insertions, deletions, and moves necessary to transition from one model-state snapshot to another.
public class OutlineViewDiffableDataSource<Item: OutlineViewItem>: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {

  /// Tree with data.
  private var diffableSnapshot: DiffableDataSourceSnapshot<Item>

  /// Associated outline view.
  private weak var outlineView: NSOutlineView?

  /// Re-targeting API for drag-n-drop.
  public enum ProposedDrop<Item> {
    case denied
    case onItem(Item, NSDragOperation)
    case beforeItem(Item, NSDragOperation)
    case afterItem(Item, NSDragOperation)
  }

  /// Used for drag-n-drop validation, default implementation returns `.denied` by default which means “cannot drop”.
  public var canDropHandler: (_ draggedItems: [Item], _ proposedDrop: ProposedDrop<Item>) -> ProposedDrop<Item> = { _, _ in .denied }

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
    guard let item = item as? Item else { return true }
    return item.isExpandable
  }

  /// Uses diffable snapshot.
  public func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
    guard let identifier = object as? Item.ID else { return nil }
    return diffableSnapshot.itemWithIdentifier(identifier)
  }

  /// Uses diffable snapshot.
  public func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
    guard let item = item as? Item else { return nil }
    return item.id
  }

  /// Enables dragging for items which return Pasteboard representation.
  public func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
    guard let item = item as? Item, let propertyList = item.idPropertyList else { return nil }
    return NSPasteboardItem(pasteboardPropertyList: propertyList, ofType: .itemID)
  }

  /// This override is necessary to disable special mouse down behavior in the outline view.
  public override func responds(to aSelector: Selector?) -> Bool {
    if Item.allowsDragging == false && aSelector == #selector(outlineView(_:pasteboardWriterForItem:)) {
      return false
    } else {
      return super.responds(to: aSelector)
    }
  }

  /// Enables drag-n-drop validation.
  public func outlineView(
    _ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int
  ) -> NSDragOperation {

    // Retrieve dragged items
    guard let pasteboardItems = info.draggingPasteboard.pasteboardItems,
      pasteboardItems.isEmpty == false else { return [] }
    let draggedItems: [Item] = pasteboardItems.compactMap { pasteboardItem in
      guard let propertyList = pasteboardItem.propertyList(forType: .itemID),
        let id = Item.idFromPropertyList(propertyList),
        let item = diffableSnapshot.itemWithIdentifier(id) else { return nil }
      return item
    }
    guard draggedItems.count == pasteboardItems.count else { return [] }

    // Prepare proposed drop operation
    let proposedDrop: ProposedDrop<Item> = {

      // Drop on the item
      let parentItem = item as? Item
      if index == NSOutlineViewDropOnItemIndex {
        return parentItem.map { .onItem($0, .every) } ?? .denied
      }

      // Drop into the item
      let childItems = diffableSnapshot.childrenOfItem(parentItem)
      guard childItems.isEmpty == false else { return .denied }

      // Use “before” or “after” depending on index
      return index == 0 ? .beforeItem(childItems[0], .every) : .afterItem(childItems[index - 1], .every)
    }()

    // Pass decision to the client handler
    switch canDropHandler(draggedItems, proposedDrop) {

    // Re-target drop on item
    case let .onItem(targetItem, operation):
      if operation.isEmpty == false {
        outlineView.setDropItem(targetItem, dropChildIndex: NSOutlineViewDropOnItemIndex)
      }
      return operation

    // Re-target drop before item
    case let .beforeItem(item, operation):
      if operation.isEmpty == false, let childIndex = diffableSnapshot.indexOfItem(item) {
        let parentItem = diffableSnapshot.parentOfItem(item)
        outlineView.setDropItem(parentItem, dropChildIndex: childIndex)
      }
      return operation

    // Re-target drop after item
    case let .afterItem(item, operation):
      if operation.isEmpty == false, let childIndex = diffableSnapshot.indexOfItem(item) {
        let parentItem = diffableSnapshot.parentOfItem(item)
        outlineView.setDropItem(parentItem, dropChildIndex: childIndex + 1)
      }
      return operation

    // Dropping is denied
    case .denied:
      return []
    }
  }

  // MARK: - NSOutlineViewDelegate

  /// Creates a cell view for the given item,
  public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let item = item as? Item else { return nil }
    let cellViewType = item.cellViewType(for: tableColumn) ?? CustomTableCellView.self
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
      guard let item = outlineView.item(atRow: $0) as? Item else { return false }
      return item.isSelectable
    }
  }

  /// Creates a row view for the given item,
  public func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
    guard let item = item as? Item else { return nil }
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
  func snapshot() -> DiffableDataSourceSnapshot<Item> {
    diffableSnapshot
  }

  /// Applies the given snapshot to this data source in background.
  /// - Parameter snapshot: Snapshot with new data.
  /// - Parameter animatingDifferences: Pass false to disable animations.
  /// - Parameter completionHandler: Called asynchronously in the main thread when the new snapshot is applied.
  func applySnapshot(_ snapshot: DiffableDataSourceSnapshot<Item>, animatingDifferences: Bool, completionHandler: (() -> Void)? = nil) {

    // Source and Destination
    let oldSnapshot = diffableSnapshot
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
    let oldIndexedItemIdentifiers = oldSnapshot.indexedItemIdentifiers()
    let newIndexedItemIdentifiers = newSnapshot.indexedItemIdentifiers()
    let difference = newIndexedItemIdentifiers.difference(from: oldIndexedItemIdentifiers)
    let differenceWithMoves = difference.inferringMoves()

    // Apply changes changes
    func apply() {
      guard let outlineView = outlineView else { return }
      differenceWithMoves.forEach {
        switch $0 {

        case .insert(_, let inserted, let indexBefore):
          if let indexBefore = indexBefore {
            // Move outline view item
            let oldIndexedItemIdentifier = oldIndexedItemIdentifiers[indexBefore]
            let oldParent = oldIndexedItemIdentifier.parentIdentifier.flatMap(oldSnapshot.itemWithIdentifier(_:))
            let oldIndex = oldIndexedItemIdentifier.itemPath.last.unsafelyUnwrapped
            let newParent = inserted.parentIdentifier.flatMap(newSnapshot.itemWithIdentifier(_:))
            let newIndex = inserted.itemPath.last.unsafelyUnwrapped
            outlineView.moveItem(at: oldIndex, inParent: oldParent, to: newIndex, inParent: newParent)

          } else {
            // Insert outline view item
            let insertionIndexes = IndexSet(integer: inserted.itemPath.last.unsafelyUnwrapped)
            let parentItem = inserted.parentIdentifier.flatMap(newSnapshot.itemWithIdentifier(_:))
            outlineView.insertItems(at: insertionIndexes, inParent: parentItem, withAnimation: [.effectFade, .slideDown])
          }

        case .remove(_, let before, let indexAfter):
          if indexAfter == nil {
            // Delete outline view item
            let deletionIndexes = IndexSet(integer: before.itemPath.last.unsafelyUnwrapped)
            let oldParentItem = before.parentIdentifier.flatMap(oldSnapshot.itemWithIdentifier(_:))
            outlineView.removeItems(at: deletionIndexes, inParent: oldParentItem, withAnimation: [.effectFade, .slideDown])
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
      DispatchQueue.main.async(execute: applyWithAnimation)
    }
  }
}

// MARK: - Private API

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
