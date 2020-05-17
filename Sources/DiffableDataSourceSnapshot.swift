import Foundation
import os

/// Container for the tree of items.
public struct DiffableDataSourceSnapshot {

  /// Shortcut for outline view objects.
  public typealias Item = NSObject

  /// Shortcut for outline view object IDs.
  typealias ItemID = ObjectIdentifier

  /// Used to store tree nodes for items.
  private struct Node: Hashable {

    /// Parent of the stored item.
    var parent: ItemID?

    /// Children of the stored item.
    var children: [ItemID]
  }

  /// Stored items.
  private var items: [ItemID: Item] = [:]

  /// Tree nodes with stored items.
  private var nodes: [ItemID: Node] = [:]

  /// Root nodes with stored items.
  private var rootChildren: [ItemID] = []

  /// Used to remember reloaded items until flush.
  private var pendingReload: Set<ItemID> = []

  /// Creates an empty snapshot without any items.
  public init() {}
}

// MARK: - Public API

public extension DiffableDataSourceSnapshot {

  /// Total number of stored items.
  var numberOfItems: Int {
    items.count
  }

  /// Stored items sorted from top to bottom.
  func sortedItems() -> [Item] {
    indexedItemIds().map(\.itemId).compactMap(itemWithId)
  }

  /// Returns true if the given item is in the snapshot.
  /// - Parameter item: The item to check.
  func containsItem(_ item: Item) -> Bool {
    let itemId = ItemID(item)
    return items.keys.contains(itemId)
  }

  /// Returns the number of children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func numberOfItems(in parentItem: Item?) -> Int {
    guard let parentItem = parentItem else { return rootChildren.count }
    let parentId = ItemID(parentItem)
    guard let parentNode = nodes[parentId] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: parentId))
      return 0
    }
    return parentNode.children.count
  }

  /// Returns children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func childrenOfItem(_ parentItem: Item?) -> [Item] {
    guard let parentItem = parentItem else { return rootChildren.compactMap { items[$0] } }
    let parentId = ItemID(parentItem)
    guard let parentNode = nodes[parentId] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: parentId))
      return []
    }
    return parentNode.children.compactMap { items[$0] }
  }

  /// Returns parent for the given child item. Root items have `nil` as a parent.
  /// - Parameter childItem: Child item added to the snapshot before.
  func parentOfItem(_ childItem: Item) -> Item? {
    let childId = ItemID(childItem)
    guard let childNode = nodes[childId] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: childId))
      return nil
    }
    guard let parentId = childNode.parent else { return nil }
    return items[parentId]
  }

  /// Returns index of the given child item in its parent, or `nil` if the given item is not in the snapshot.
  /// - Parameter childItem: Child item added to the snapshot before.
  func indexOfItem(_ childItem: Item) -> Int? {
    let childId = ItemID(childItem)
    guard let childNode = nodes[childId] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: childId))
      return nil
    }
    let parentId = childNode.parent
    let children = idsOfChildrenOfItemWithId(parentId)
    return children.firstIndex(of: childId)
  }

  /// Appends items to the end of the given parent.
  /// - Parameter newItems: The list of items to append.
  /// - Parameter parentItem: Optional parent item, pass `nil` to append root items.
  /// - Returns: False if items cannot be added e.g. because the parent is not in the snapshot.
  @discardableResult
  mutating func appendItems(_ newItems: [Item], into parentItem: Item? = nil) -> Bool {
    guard validateNewItems(newItems) else { return false }
    guard let parentItem = parentItem else {
      newItems.forEach { newItem in
        let newItemId = ItemID(newItem)
        items[newItemId] = newItem
        nodes[newItemId] = .init(parent: nil, children: [])
      }
      rootChildren.append(contentsOf: newItems.map(ItemID.init(_:)))
      return true
    }
    let parentId = ItemID(parentItem)
    guard var parentNode = nodes[parentId] else {
      os_log(.error, log: errors, "Cannot find parent item with ID “%s”", String(describing: parentId))
      return false
    }
    newItems.forEach { newItem in
      let newItemId = ItemID(newItem)
      items[newItemId] = newItem
      nodes[newItemId] = .init(parent: parentId, children: [])
    }
    parentNode.children.append(contentsOf: newItems.map(ItemID.init(_:)))
    nodes[parentId] = parentNode
    return true
  }

  /// Inserts items before the given item.
  /// - Parameter newItems: The list of items to insert.
  /// - Parameter beforeItem: The target item below new items.
  /// - Returns: False if items cannot be inserted e.g. because the target item is not in the snapshot.
  @discardableResult
  mutating func insertItems(_ newItems: [Item], beforeItem: Item) -> Bool {
    insertItems(newItems, aroundItem: beforeItem) { $0 }
  }

  /// Inserts items after the given item.
  /// - Parameter newItems: The list of items to insert.
  /// - Parameter afterItem: The target item above new items.
  /// - Returns: False if items cannot be inserted e.g. because the target item is not in the snapshot.
  @discardableResult
  mutating func insertItems(_ newItems: [Item], afterItem: Item) -> Bool {
    insertItems(newItems, aroundItem: afterItem) { $0 + 1 }
  }

  /// Deletes given items and their children.
  /// - Parameter existingItems: Items added to the snapshot before.
  /// - Returns: False if items cannot be deleted e.g. because some of them are not in the snapshot.
  @discardableResult
  mutating func deleteItems(_ existingItems: [Item]) -> Bool {
    let existingIds = Set(existingItems.map(ItemID.init(_:)))
    guard validateExistingIds(existingIds) else { return false }

    var affectedIds = existingIds
    enumerateItemIds { indexedItemId in
      guard let parentId = indexedItemId.parentId else { return }
      guard affectedIds.contains(parentId) else { return }
      affectedIds.insert(indexedItemId.itemId)
    }

    let parentIds = affectedIds.map { nodes[$0]?.parent }
    affectedIds.forEach {
      items.removeValue(forKey: $0)
      nodes.removeValue(forKey: $0)
    }
    pendingReload.subtract(affectedIds)
    parentIds.forEach {
      guard let parentId = $0 else {
        rootChildren.removeAll { affectedIds.contains($0) }
        return
      }
      nodes[parentId]?.children.removeAll { affectedIds.contains($0) }
    }
    return true
  }

  /// Deletes all items and their children.
  mutating func deleteAllItems() {
    self = .init()
  }

  /// Used to mark passed items as reloaded.
  /// - Parameter items: Items added to the snapshot before.
  /// - Returns: False if items cannot be reloaded e.g. because some of them are not in the snapshot.
  @discardableResult
  mutating func reloadItems(_ items: [Item]) -> Bool {
    let ids = Set(items.map(ItemID.init(_:)))
    guard validateExistingIds(ids) else { return false }
    pendingReload.formUnion(ids)
    return true
  }

  /// Returns all items marked for reloading and forgets them.
  mutating func flushReloadedItems() -> [Item] {
    guard pendingReload.isEmpty == false else { return [] }
    var result: [Item] = []
    enumerateItemIds { indexedItemId in
      let itemId = indexedItemId.itemId
      guard pendingReload.contains(itemId) else { return }
      result.append(items[itemId].unsafelyUnwrapped)
    }
    pendingReload.removeAll()
    return result
  }

  /// Returns true if the given item can be moved next to the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter targetItem: The target item added to the snapshot before.
  func canMoveItem(_ item: Item, aroundItem targetItem: Item) -> Bool {
    let itemId = ItemID(item)
    let targetItemId = ItemID(targetItem)
    guard itemId != targetItemId else {
      os_log(.error, log: errors, "Cannot move item with IDs “%s” around itself", String(describing: itemId))
      return false
    }
    guard validateExistingIds([itemId, targetItemId]) else { return false }
    let parentIds = sequence(first: targetItemId) { self.nodes[$0]?.parent }
    return parentIds.allSatisfy { $0 != itemId }
  }

  /// Moves the given item above the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter beforeItem: The target item below the moved item.
  /// - Returns: False if the given item cannot be moved e.g. because it’s parent of the target item.
  @discardableResult
  mutating func moveItem(_ item: Item, beforeItem: Item) -> Bool {
    moveItem(item, aroundItem: beforeItem) { $0 }
  }

  /// Moves the given item below the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter afterItem: The target item above the moved item.
  /// - Returns: False if the given item cannot be moved e.g. because it’s parent of the target item.
  @discardableResult
  mutating func moveItem(_ item: Item, afterItem: Item) -> Bool  {
    moveItem(item, aroundItem: afterItem) { $0 + 1 }
  }

  /// Enumerates all items from top to bottom.
  /// - Parameter block: Callback for each item.
  /// - Parameter item: Enumerated item.
  /// - Parameter parentItem: Parent item if available.
  func enumerateItems(using block: (_ item: Item, _ parentItem: Item?) -> Void) {
    enumerateItemIds { id in
      if let item = itemWithId(id.itemId) {
        block(item, id.parentId.flatMap(itemWithId))
      }
    }
  }
}

// MARK: - Internal API

extension DiffableDataSourceSnapshot {

  /// Container for sorting.
  struct IndexedItemID: Hashable {

    /// Item identifier.
    let itemId: ItemID

    /// Optional parent item identifier.
    let parentId: ItemID?

    /// Full path to the item.
    let itemPath: IndexPath

    /// Only IDs should be equal.
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.itemId == rhs.itemId
    }

    /// Only ID means as hash.
    func hash(into hasher: inout Hasher) {
      hasher.combine(itemId)
    }
  }

  /// Identifiers of stored items sorted from top to bottom.
  func indexedItemIds() -> [IndexedItemID] {
    var result: [IndexedItemID] = []
    enumerateItemIds { indexedItemId in
      result.append(indexedItemId)
    }
    return result
  }

  /// Returns a stored item for the given identifier if available.
  /// - Parameter id: Identifier of the item to return.
  func itemWithId(_ id: ItemID) -> Item? {
    items[id]
  }

  /// Returns identifiers of children for the given parent identifier.
  /// - Parameter parentId: Pass nil to retrieve root item identifiers.
  func idsOfChildrenOfItemWithId(_ parentId: ItemID?) -> [ItemID] {
    guard let parentNode = parentId.flatMap({ nodes[$0] }) else { return rootChildren }
    return parentNode.children
  }
}

// MARK: - Private API

private extension DiffableDataSourceSnapshot {

  /// Returns true if this snapshot does not have any passed items.
  /// - Parameter newItems: New items not yet added to the snapshot.
  func validateNewItems(_ newItems: [Item]) -> Bool {
    let newIds = Set(newItems.map(ItemID.init(_:)))
    guard newIds.count == newItems.count else {
      os_log(.error, log: errors, "Items with duplicate IDs cannot be added")
      return false
    }
    let existingIds = newIds.intersection(items.keys)
    guard existingIds.isEmpty else {
      let ids = existingIds.map(String.init(describing:)).joined(separator: ", ")
      os_log(.error, log: errors, "Items with IDs “%s” have already been added", ids)
      return false
    }
    return true
  }

  /// Returns true if this snapshot has got all passed items.
  /// - Parameter existingIs: Items already added to the snapshot.
  func validateExistingIds(_ existingIs: Set<ItemID>) -> Bool {
    let missingIds = existingIs.subtracting(items.keys)
    guard missingIds.isEmpty else {
      let ids = missingIds.map(String.init(describing:)).joined(separator: ", ")
      os_log(.error, log: errors, "Items with IDs “%s” have not been added", ids)
      return false
    }
    return true
  }

  /// Recursively goes through the whole tree and runs a callback with node.
  /// - Parameter block: Callback for every node in the tree.
  func enumerateItemIds(using block: (_ indexedItemId: IndexedItemID) -> Void) {
    func enumerateChildrenOf(_ parentId: ItemID?, parentPath: IndexPath) {
      idsOfChildrenOfItemWithId(parentId).enumerated().forEach { offset, itemId in
        let itemPath = parentPath.appending(offset)
        block(.init(itemId: itemId, parentId: parentId, itemPath: itemPath))
        enumerateChildrenOf(itemId, parentPath: itemPath)
      }
    }
    enumerateChildrenOf(nil, parentPath: .init())
  }

  /// Inserts items next to the target item using a calculator for the insertion index.
  /// - Parameter newItems: The list of items to insert.
  /// - Parameter targetItem: The target item added to the snapshot before.
  /// - Parameter indexFrom: Calculator for the insertion index.
  /// - Parameter targetIndex: Current index of the target item.
  /// - Returns: False if items cannot be inserted e.g. because some of them are already in the snapshot.
  mutating func insertItems(_ newItems: [Item], aroundItem targetItem: Item, using indexFrom: (_ targetIndex: Int) -> Int) -> Bool {
    guard validateNewItems(newItems) else { return false }
    let targetItemId = ItemID(targetItem)
    guard let targetNode = nodes[targetItemId] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: targetItemId))
      return false
    }
    guard let parentId = targetNode.parent else {
      newItems.forEach { newItem in
        let newItemId = ItemID(newItem)
        items[newItemId] = newItem
        nodes[newItemId] = .init(parent: nil, children: [])
      }
      let targetIndex = rootChildren.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      rootChildren.insert(contentsOf: newItems.map(ItemID.init(_:)), at: insertionIndex)
      return true
    }
    newItems.forEach { newItem in
      let newItemId = ItemID(newItem)
      items[newItemId] = newItem
      nodes[newItemId] = .init(parent: parentId, children: [])
    }
    var parentNode = nodes[parentId].unsafelyUnwrapped
    let targetIndex = parentNode.children.firstIndex(of: targetItemId).unsafelyUnwrapped
    parentNode.children.insert(contentsOf: newItems.map(ItemID.init(_:)), at: indexFrom(targetIndex))
    nodes[parentId] = parentNode
    return true
  }

  /// Moves the given item next to the target item using a calculator for the insertion index.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter targetItem: The target item added to the snapshot before.
  /// - Parameter indexFrom: Calculator for the insertion index.
  /// - Parameter targetIndex: Current index of the target item.
  /// - Returns: False if the item cannot be moved e.g. because it’s a parent of the target item.
  mutating func moveItem(_ item: Item, aroundItem targetItem: Item, using indexFrom: (_ targetIndex: Int) -> Int) -> Bool {
    guard canMoveItem(item, aroundItem: targetItem) else { return false }

    // Remove item from old parent
    let itemId = ItemID(item)
    var itemNode = nodes[itemId].unsafelyUnwrapped
    if let oldParentId = itemNode.parent {
      var oldParentNode = nodes[oldParentId].unsafelyUnwrapped
      oldParentNode.children.removeAll { $0 == itemId }
      nodes[oldParentId] = oldParentNode
    } else {
      rootChildren.removeAll { $0 == itemId }
    }

    // Insert item into new parent
    let targetItemId = ItemID(targetItem)
    let targetItemNode = nodes[targetItemId].unsafelyUnwrapped
    if let newParentId = targetItemNode.parent {
      itemNode.parent = newParentId
      var newParentNode = nodes[newParentId].unsafelyUnwrapped
      let targetIndex = newParentNode.children.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      newParentNode.children.insert(itemId, at: insertionIndex)
      nodes[newParentId] = newParentNode
    } else {
      itemNode.parent = nil
      let targetIndex = rootChildren.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      rootChildren.insert(itemId, at: insertionIndex)
    }
    nodes[itemId] = itemNode
    return true
  }
}

/// Local handle for logging errors.
private let errors: OSLog = .init(subsystem: "OutlineViewDiffableDataSource", category: "DiffableDataSourceSnapshot")
