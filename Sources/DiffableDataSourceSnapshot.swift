import Foundation
import os

/// Container for the tree of items.
public struct DiffableDataSourceSnapshot {

  /// Shortcut for outline view objects.
  public typealias Item = NSObject

  /// Shortcut for outline view object IDs.
  typealias ItemID = UUID

  /// Used to store tree nodes for items.
  private struct Node: Hashable {

    /// Parent of the stored item.
    var parent: ItemID?

    /// Children of the stored item.
    var children: [ItemID]
  }

  /// Identifiers associated with items.
  private var idsForItems: [Item: ItemID] = [:]

  /// Items associated with identifiers.
  private var itemsForIds: [ItemID: Item] = [:]

  /// Tree nodes with stored items.
  private var nodesForIds: [ItemID: Node] = [:]

  /// Root nodes with stored items.
  private var rootIds: [ItemID] = []

  /// Used to remember reloaded items until flush.
  private var idsPendingReload: Set<ItemID> = []

  /// Creates an empty snapshot without any items.
  public init() {}
}

// MARK: - Public API

public extension DiffableDataSourceSnapshot {

  /// Total number of stored items.
  var numberOfItems: Int {
    nodesForIds.count
  }

  /// Stored items sorted from top to bottom.
  func sortedItems() -> [Item] {
    indexedIds().map(\.itemId).compactMap(itemForId)
  }

  /// Returns true if the given item is in the snapshot.
  /// - Parameter item: The item to check.
  func containsItem(_ item: Item) -> Bool {
    idForItem(item) != nil
  }

  /// Returns the number of children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func numberOfItems(in parentItem: Item?) -> Int {
    guard let parentItem = parentItem else { return rootIds.count }
    guard let parentNode = idForItem(parentItem).flatMap(nodeForId) else {
      os_log(.error, log: errors, "Cannot find parent item “%s”", String(describing: parentItem))
      return 0
    }
    return parentNode.children.count
  }

  /// Returns children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func childrenOfItem(_ parentItem: Item?) -> [Item] {
    guard let parentItem = parentItem else { return rootIds.compactMap(itemForId) }
    guard let parentNode = idForItem(parentItem).flatMap(nodeForId) else {
      os_log(.error, log: errors, "Cannot find parent item “%s”", String(describing: parentItem))
      return []
    }
    return parentNode.children.compactMap(itemForId)
  }

  /// Returns parent for the given child item. Root items have `nil` as a parent.
  /// - Parameter childItem: Child item added to the snapshot before.
  func parentOfItem(_ childItem: Item) -> Item? {
    guard let childId = idForItem(childItem), let childNode = nodeForId(childId) else {
      os_log(.error, log: errors, "Cannot find item “%s”", String(describing: childItem))
      return nil
    }
    return childNode.parent.flatMap(itemForId)
  }

  /// Returns index of the given child item in its parent, or `nil` if the given item is not in the snapshot.
  /// - Parameter childItem: Child item added to the snapshot before.
  func indexOfItem(_ childItem: Item) -> Int? {
    guard let childId = idForItem(childItem), let childNode = nodeForId(childId) else {
      os_log(.error, log: errors, "Cannot find item “%s”", String(describing: childItem))
      return nil
    }
    let children = childIdsOfItemWithId(childNode.parent)
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
      let newIds = newItems.map { newItem -> ItemID in
        let newId = ItemID()
        itemsForIds[newId] = newItem
        idsForItems[newItem] = newId
        nodesForIds[newId] = .init(parent: nil, children: [])
        return newId
      }
      rootIds.append(contentsOf: newIds)
      return true
    }
    guard let parentId = idForItem(parentItem), var parentNode = nodeForId(parentId) else {
      os_log(.error, log: errors, "Cannot find parent item “%s”", String(describing: parentItem))
      return false
    }
    let newIds = newItems.map { newItem -> ItemID in
      let newId = ItemID()
      itemsForIds[newId] = newItem
      idsForItems[newItem] = newId
      nodesForIds[newId] = .init(parent: parentId, children: [])
      return newId
    }
    parentNode.children.append(contentsOf: newIds)
    nodesForIds[parentId] = parentNode
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
    guard validateExistingItems(Set(existingItems)) else { return false }

    var affectedIds = Set(existingItems.compactMap(idForItem))
    enumerateItemIds { indexedId in
      guard let parentId = indexedId.parentId, affectedIds.contains(parentId) else { return }
      affectedIds.insert(indexedId.itemId)
    }

    let affectedParentIds = Set(affectedIds.map { nodeForId($0)?.parent })
    let affectedItems = affectedIds.compactMap(itemForId)
    affectedIds.forEach { affectedId in
      itemsForIds.removeValue(forKey: affectedId)
      nodesForIds.removeValue(forKey: affectedId)
    }
    affectedItems.forEach { affectedItem in
      idsForItems.removeValue(forKey: affectedItem)
    }
    idsPendingReload.subtract(affectedIds)
    affectedParentIds.forEach {
      guard let affectedParentId = $0 else {
        rootIds.removeAll { affectedIds.contains($0) }
        return
      }
      nodesForIds[affectedParentId]?.children.removeAll { affectedIds.contains($0) }
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
    guard validateExistingItems(Set(items)) else { return false }
    let ids = items.compactMap(idForItem)
    idsPendingReload.formUnion(ids)
    return true
  }

  /// Returns all items marked for reloading and forgets them.
  mutating func flushReloadedItems() -> [Item] {
    guard idsPendingReload.isEmpty == false else { return [] }
    var result: [Item] = []
    enumerateItemIds { indexedItemId in
      let itemId = indexedItemId.itemId
      guard idsPendingReload.contains(itemId), let item = itemForId(itemId) else { return }
      result.append(item)
    }
    idsPendingReload.removeAll()
    return result
  }

  /// Returns true if the given item can be moved next to the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter targetItem: The target item added to the snapshot before.
  func canMoveItem(_ item: Item, aroundItem targetItem: Item) -> Bool {
    guard validateExistingItems([item, targetItem]) else { return false }
    guard let itemId = idForItem(item), let targetItemId = idForItem(targetItem), itemId != targetItemId else {
      os_log(.error, log: errors, "Cannot move items around themselves")
      return false
    }
    let parentIds = sequence(first: targetItemId) { self.nodeForId($0)?.parent }
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
      if let item = itemForId(id.itemId) {
        block(item, id.parentId.flatMap(itemForId))
      }
    }
  }
}

// MARK: - Internal API

extension DiffableDataSourceSnapshot {

  /// Container for sorting.
  struct IndexedID: Hashable {

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
  func indexedIds() -> [IndexedID] {
    var result: [IndexedID] = []
    enumerateItemIds { indexedId in
      result.append(indexedId)
    }
    return result
  }

  /// Returns an identifier of the stored item if available.
  /// - Parameter item: Stored item.
  func idForItem(_ item: Item) -> ItemID? {
    idsForItems[item]
  }

  /// Returns a stored item for the given identifier if available.
  /// - Parameter id: Identifier of the item to return.
  func itemForId(_ id: ItemID) -> Item? {
    itemsForIds[id]
  }


  /// Returns identifiers of children for the given parent identifier.
  /// - Parameter parentId: Pass nil to retrieve root item identifiers.
  func childIdsOfItemWithId(_ parentId: ItemID?) -> [ItemID] {
    guard let parentNode = parentId.flatMap(nodeForId) else { return rootIds }
    return parentNode.children
  }
}

// MARK: - Private API

private extension DiffableDataSourceSnapshot {

  /// Returns a node for the given identifier if available.
  /// - Parameter id: Identifier of the node to return.
  private func nodeForId(_ id: ItemID) -> Node? {
    nodesForIds[id]
  }

  /// Returns true if this snapshot does not have any passed items.
  /// - Parameter newItems: New items not yet added to the snapshot.
  func validateNewItems(_ newItems: [Item]) -> Bool {
    guard Set(newItems).count == newItems.count else {
      os_log(.error, log: errors, "Repeating items cannot be added")
      return false
    }
    let existingIds = newItems.compactMap(idForItem)
    guard existingIds.isEmpty else {
      let ids = existingIds.map(\.uuidString).joined(separator: ", ")
      os_log(.error, log: errors, "Items with IDs “%s” have already been added", ids)
      return false
    }
    return true
  }

  /// Returns true if this snapshot has got all passed items.
  /// - Parameter existingItems: Items already added to the snapshot.
  func validateExistingItems(_ existingItems: Set<Item>) -> Bool {
    let missingItems = existingItems.subtracting(idsForItems.keys)
    guard missingItems.isEmpty else {
      let strings = missingItems.map(String.init(describing:)).joined(separator: ", ")
      os_log(.error, log: errors, "Items [%s] have not been added", strings)
      return false
    }
    return true
  }

  /// Recursively goes through the whole tree and runs a callback with node.
  /// - Parameter block: Callback for every node in the tree.
  /// - Parameter indexedId: Container for sorting.
  func enumerateItemIds(using block: (_ indexedId: IndexedID) -> Void) {
    func enumerateChildrenOf(_ parentId: ItemID?, parentPath: IndexPath) {
      childIdsOfItemWithId(parentId).enumerated().forEach { offset, itemId in
        let itemPath = parentPath.appending(offset)
        let indexedId = IndexedID(itemId: itemId, parentId: parentId, itemPath: itemPath)
        block(indexedId)
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
    guard let targetItemId = idForItem(targetItem), let targetNode = nodeForId(targetItemId) else {
      os_log(.error, log: errors, "Cannot find item “%s”", String(describing: targetItem))
      return false
    }
    guard let parentId = targetNode.parent else {
      let newIds = newItems.map { newItem -> ItemID in
        let newId = ItemID()
        itemsForIds[newId] = newItem
        idsForItems[newItem] = newId
        nodesForIds[newId] = .init(parent: nil, children: [])
        return newId
      }
      let targetIndex = rootIds.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      rootIds.insert(contentsOf: newIds, at: insertionIndex)
      return true
    }
    let newIds = newItems.map { newItem -> ItemID in
      let newId = ItemID()
      itemsForIds[newId] = newItem
      idsForItems[newItem] = newId
      nodesForIds[newId] = .init(parent: parentId, children: [])
      return newId
    }
    var parentNode = nodeForId(parentId).unsafelyUnwrapped
    let targetIndex = parentNode.children.firstIndex(of: targetItemId).unsafelyUnwrapped
    parentNode.children.insert(contentsOf: newIds, at: indexFrom(targetIndex))
    nodesForIds[parentId] = parentNode
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
    let itemId = idForItem(item).unsafelyUnwrapped
    var itemNode = nodeForId(itemId).unsafelyUnwrapped
    if let oldParentId = itemNode.parent {
      var oldParentNode = nodeForId(oldParentId).unsafelyUnwrapped
      oldParentNode.children.removeAll { $0 == itemId }
      nodesForIds[oldParentId] = oldParentNode
    } else {
      rootIds.removeAll { $0 == itemId }
    }

    // Insert item into new parent
    let targetItemId = idForItem(targetItem).unsafelyUnwrapped
    let targetItemNode = nodeForId(targetItemId).unsafelyUnwrapped
    if let newParentId = targetItemNode.parent {
      itemNode.parent = newParentId
      var newParentNode = nodeForId(newParentId).unsafelyUnwrapped
      let targetIndex = newParentNode.children.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      newParentNode.children.insert(itemId, at: insertionIndex)
      nodesForIds[newParentId] = newParentNode
    } else {
      itemNode.parent = nil
      let targetIndex = rootIds.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      rootIds.insert(itemId, at: insertionIndex)
    }
    nodesForIds[itemId] = itemNode
    return true
  }
}

/// Local handle for logging errors.
private let errors: OSLog = .init(subsystem: "OutlineViewDiffableDataSource", category: "DiffableDataSourceSnapshot")
