import Foundation
import os

/// Container for the tree of items.
public struct DiffableDataSourceSnapshot {

  /// Shortcut for outline view objects.
  public typealias Item = OutlineViewItem

  /// Shortcut for outline view object IDs.
  public typealias ItemID = String

  /// Represents a single node of the tree.
  private struct Node: Hashable {
    /// Node parent's `itemID`
    var parent: ItemID?

    /// `itemID`s of node's children
    var children: [ItemID]
  }
  
  public enum NodePosition {
    case before
    case after
  }

  /// Maps items to their identifiers
  private var idsForItems: [Item: ItemID] = [:]

  /// Maps identifiers to their items
  private var itemsForIds: [ItemID: Item] = [:]

  /// Maps `itemID`s to `Node`
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
      os_log(.error, log: errors, "numberOfItems - Cannot find parent item “%s”", String(describing: parentItem))
      return 0
    }
    return parentNode.children.count
  }

  /// Returns children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func childrenOfItem(_ parentItem: Item?) -> [Item] {
    guard let parentItem = parentItem else { return rootIds.compactMap(itemForId) }
    guard let parentNode = idForItem(parentItem).flatMap(nodeForId) else {
      os_log(.error, log: errors, "childrenOfItem - Cannot find parent item “%s”", String(describing: parentItem))
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
  
  
  /// Returns `true` if the given item is a child of a given item or its sub-items
  /// - Parameters:
  ///   - item: item to check
  ///   - anotherItem: another item
  func isItemDescendant(_ item: Item, of anotherItem: Item) -> Bool {
    if item == anotherItem { return true }
    
    let childrenOfOther = childrenOfItem(anotherItem)
    if childrenOfOther.contains(item) {
      return true
    }
    else {
      for childOfOther in childrenOfOther {
        return isItemDescendant(item, of: childOfOther)
      }
    }
    return false
  }
  
  /// Returns `true` if the given item is a parent or a grand parent of a given item
  /// - Parameters:
  ///   - item: item to check
  ///   - anotherItem: another item
  func isItemAncestor(_ item: Item, of anotherItem: Item) -> Bool {
    if item == anotherItem { return true }
    
    if let parentOfOther = parentOfItem(anotherItem) {
      if item == parentOfOther {
        return true
      }
      else {
        return isItemAncestor(item, of: parentOfOther)
      }
    }
    return false
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
    return insertItems(newItems, into: parentItem)
  }

  /// Inserts items before the given item.
  /// - Parameter newItems: The list of items to insert.
  /// - Parameter beforeItem: The target item below new items.
  /// - Returns: False if items cannot be inserted e.g. because the target item is not in the snapshot.
  @discardableResult
  mutating func insertItems(_ newItems: [Item], beforeItem: Item) -> Bool {
    insertItems(newItems, nextTo: beforeItem, atPosition: .before)
  }

  /// Inserts items after the given item.
  /// - Parameter newItems: The list of items to insert.
  /// - Parameter afterItem: The target item above new items.
  /// - Returns: False if items cannot be inserted e.g. because the target item is not in the snapshot.
  @discardableResult
  mutating func insertItems(_ newItems: [Item], afterItem: Item) -> Bool {
    insertItems(newItems, nextTo: afterItem, atPosition: .after)
  }

  /// Deletes given items and their children.
  /// - Parameter existingItems: Items added to the snapshot before.
  /// - Returns: False if items cannot be deleted e.g. because some of them are not in the snapshot.
  @discardableResult
  mutating func deleteItems(_ existingItems: [Item]) -> Bool {
    guard contains(existingItems) else { return false }

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
    guard contains(items) else { return false }
    
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
  func canMoveItem(_ item: Item, nextTo targetItem: Item) -> Bool {
    guard contains([item, targetItem]) else { return false }
    
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
    moveItem(item, nextTo: beforeItem, atPosition: .before)
  }

  /// Moves the given item below the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter afterItem: The target item above the moved item.
  /// - Returns: False if the given item cannot be moved e.g. because it’s parent of the target item.
  @discardableResult
  mutating func moveItem(_ item: Item, afterItem: Item) -> Bool  {
    moveItem(item, nextTo: afterItem, atPosition: .after)
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
  public func itemForId(_ id: ItemID) -> Item? {
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

  /// Returns `true` if this snapshot does not have any passed items.
  /// - Parameter items: Items not yet added to the snapshot.
  func validateItemsNotFound(_ items: [Item]) -> Bool {
    // Items must all be distinct
    guard Set(items).count == items.count else {
      os_log(.error, log: errors, "Non-unique items cannot be added")
      return false
    }
    
    let existingItems = items.map { $0.id }.compactMap(itemForId)
    guard existingItems.isEmpty else {
      let ids = existingItems.map { $0.id }.joined(separator: ", ")
      os_log(.error, log: errors, "Items with IDs “%s” have already been added", ids)
      return false
    }
    return true
  }

  /// Returns `true` if this snapshot has got all passed items.
  /// - Parameter items: Items to validate
  func contains(_ items: [Item]) -> Bool {
    let missingItems = Set(items.map{ $0.id }).subtracting(idsForItems.values)
    
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

  /// Inserts items next to a target item given a target position **OR** inserts (appends) items into a parent item.
  /// - Parameter newItems: The list of items to insert.
  /// - Parameter targetItem: The target item added to the snapshot before. If this is given, `parentItem` must be `nil`
  /// - Parameter position: Target position
  /// - Parameter parentItem: Append to a parent item. If this is given, `targetItem` should be `nil`.
  /// - Returns: False if items cannot be inserted e.g. because some of them are already in the snapshot.
  mutating func insertItems(_ newItems: [Item], nextTo targetItem: Item? = nil, atPosition position: NodePosition = .before, into parentItemToAppendTo: Item? = nil) -> Bool {
    guard validateItemsNotFound(newItems) else {
      return false
    }
    
    if targetItem != nil && parentItemToAppendTo != nil {
      fatalError("Cannot pass both a target item to insert next to, as well as a parent item to append to. Must used one of the two.")
    }
    
    // MARK: Appending
    // Find the parent node if adding to a parent
    var appendToParentId = parentItemToAppendTo != nil ? idForItem(parentItemToAppendTo!) : nil
    var appendToParentNode = appendToParentId != nil ? nodeForId(appendToParentId!) : nil
    
    // Ignore if parent item (to append to) passed but not found
    if parentItemToAppendTo != nil && appendToParentNode == nil {
      os_log(.error, log: errors, "insertItems - Cannot find parent item “%s”", String(describing: parentItemToAppendTo))
      return false
    }
    
    // MARK: Inserting
    let targetItemId = targetItem != nil ? idForItem(targetItem!) : nil
    let targetItemNode = targetItemId != nil ? nodeForId(targetItemId!) : nil

    if targetItem != nil && targetItemNode == nil {
      os_log(.error, log: errors, "Cannot find item “%s”", String(describing: targetItem))
      return false
    }

    // If we're inserting next to an item, update the parent we need to use
    if let targetItemNode = targetItemNode {
      appendToParentId = targetItemNode.parent
      appendToParentNode = appendToParentId != nil ? nodeForId(appendToParentId!) : nil
    }
      
    
    // Shared logic
    // Update our maps
    let newIds = newItems.map { newItem -> ItemID in
      let newId = newItem.id
      itemsForIds[newId] = newItem
      idsForItems[newItem] = newId
      
      // Create a node
      nodesForIds[newId] = .init(parent: appendToParentId, children: [])
      
      // Update expansion state
      if let appendToParentId = appendToParentId {
        itemForId(appendToParentId)?.isExpandable = true
      }
      
      return newId
    }
    
    // Inserting?
    if let targetItemId = targetItemId {
      
      // Inserting into a parent?
      if let parentId = appendToParentId, appendToParentNode != nil {
        let targetIndex = appendToParentNode!.children.firstIndex(of: targetItemId) ?? .zero
        let insertionIndex = position == .before ? targetIndex : targetIndex + 1
        
        appendToParentNode!.children.insert(contentsOf: newIds, at: insertionIndex)
        
        // Update the parent node map
        nodesForIds[parentId] = appendToParentNode!
      }
      else {
        let targetIndex = rootIds.firstIndex(of: targetItemId).unsafelyUnwrapped
        let insertionIndex = position == .before ? targetIndex : targetIndex + 1
        rootIds.insert(contentsOf: newIds, at: insertionIndex)
      }
    }
    else {
      // Apppend IDs
      if let parentId = appendToParentId, appendToParentNode != nil {
        appendToParentNode!.children.append(contentsOf: newIds)
        
        // Update the parent node map
        nodesForIds[parentId] = appendToParentNode!
      }
      else {
        // No parent, adding to the root
        rootIds.append(contentsOf: newIds)
      }
    }
    
    return true
  }

  /// Moves the given item next to the target item using a calculator for the insertion index.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter targetItem: The target item added to the snapshot before.
  /// - Parameter indexFrom: Calculator for the insertion index.
  /// - Parameter targetIndex: Current index of the target item.
  /// - Returns: False if the item cannot be moved e.g. because it’s a parent of the target item.
  mutating func moveItem(_ item: Item, nextTo targetItem: Item, atPosition position: NodePosition = .before) -> Bool {
    guard canMoveItem(item, nextTo: targetItem) else { return false }

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
      let insertionIndex = position == .before ? targetIndex : targetIndex + 1
      
      newParentNode.children.insert(itemId, at: insertionIndex)
      nodesForIds[newParentId] = newParentNode
      
      // Update expansion state
      itemForId(newParentId)?.isExpandable = true
    } else {
      itemNode.parent = nil
      
      let targetIndex = rootIds.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = position == .before ? targetIndex : targetIndex + 1
      rootIds.insert(itemId, at: insertionIndex)
    }
    nodesForIds[itemId] = itemNode
    return true
  }
}

/// Local handle for logging errors.
private let errors: OSLog = .init(subsystem: "OutlineViewDiffableDataSource", category: "DiffableDataSourceSnapshot")
