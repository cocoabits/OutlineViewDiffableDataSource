import Foundation
import os

/// The internal data source snapshot used by `OutlineViewDiffableDataSource`. Stores and represents the tree of nodes.
/// All operations are to be performed on a snapshot directly before being passed on `outlineDataSource.apply(...)`
///
/// As items of type `OutlineViewItem` are inserted / removed / moved etc, the snapshot manages and updates an internal map for performing lookups.
/// Each item is stored as a `DiffableDataSourceSnapshot.Node` to keep track of its parent / children. When an item is moved to a new parent,
/// the internal map is subsequently updated to reflect this.
public struct DiffableDataSourceSnapshot {

  /// Shortcut for outline view objects.
  public typealias Item = OutlineViewItem

  /// Shortcut for outline view object IDs.
  public typealias ItemID = String

  /// Represents a single node of the tree.
  private struct Node: Hashable {
    let itemID: ItemID
    
    /// Node parent's `itemID`
    var parentID: ItemID?

    /// `itemID`s of node's children
    var childrenIDs: [ItemID]
  }
  
  public enum NodePosition {
    case on
    case before
    case after
  }

  /// Maps items to their identifiers
  private var mapItemToID: [Item: ItemID] = [:]

  /// Maps identifiers to their items
  private var mapIDToItem: [ItemID: Item] = [:]

  /// Maps `itemID`s to `Node`
  private var mapIDToNode: [ItemID: Node] = [:]

  /// ItemIDs of root items
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
    mapIDToNode.count
  }

  /// Stored items sorted from top to bottom. Generated from `getSortedIndexedNodes()`.
  func sortedItems() -> [Item] {
    getSortedIndexedNodes().map(\.itemId).compactMap(getItemForID)
  }

  /// Returns true if the given item is in the snapshot.
  /// - Parameter item: The item to check.
  func containsItem(_ item: Item) -> Bool {
    getIDForItem(item) != nil
  }

  /// Returns the number of children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func numberOfItems(in parentItem: Item?) -> Int {
    guard let parentItem = parentItem else {
      return rootIds.count
    }
    
    guard let parentNode = getIDForItem(parentItem).flatMap(getNodeForID) else {
      #if DEBUG
      print("numberOfItems - Cannot find parent item \(String(describing: parentItem))")
      #endif
      return 0
    }
    return parentNode.childrenIDs.count
  }

  /// Returns children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func childrenOfItem(_ parentItem: Item?) -> [Item] {
    guard let parentItem = parentItem else {
      return rootIds.compactMap(getItemForID)
    }
    
    guard let parentNode = getIDForItem(parentItem).flatMap(getNodeForID) else {
#if DEBUG
      print("childrenOfItem - Cannot find parent item \(String(describing: parentItem))")
      #endif
      return []
    }
    return parentNode.childrenIDs.compactMap(getItemForID)
  }

  /// Returns parent for the given child item. Root items have `nil` as a parent.
  /// - Parameter childItem: Child item added to the snapshot before.
  func parentOfItem(_ childItem: Item) -> Item? {
    guard let childId = getIDForItem(childItem), let childNode = getNodeForID(childId) else {
#if DEBUG
      print("Cannot find item \(String(describing: childItem))")
      #endif
      return nil
    }
    return childNode.parentID.flatMap(getItemForID)
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
    guard let childId = getIDForItem(childItem), let childNode = getNodeForID(childId) else {
#if DEBUG
      print("Cannot find item \(String(describing: childItem))")
      #endif
      return nil
    }
    let children = getChildIDsForParentID(childNode.parentID)
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
  mutating func deleteItems(_ existingItems: [Item], withChildren: Bool = true) -> Bool {
    guard contains(existingItems) else { return false }

    var itemIdsToRemove = Set(existingItems.compactMap(getIDForItem))
    
    if withChildren {
      enumerateIndexedNodes { indexedNode in
        if let parentId = indexedNode.parentId, itemIdsToRemove.contains(parentId) {
          itemIdsToRemove.insert(indexedNode.itemId)
        }
      }
    }

    // Grab a copy before removing these
    let affectedParentIds = Set(itemIdsToRemove.map { getNodeForID($0)?.parentID })
    let itemsToRemove = itemIdsToRemove.compactMap(getItemForID)
    
    // Now remove all items that have deleted
    itemIdsToRemove.forEach { affectedId in
      mapIDToItem.removeValue(forKey: affectedId)
      mapIDToNode.removeValue(forKey: affectedId)
    }
    
    itemsToRemove.forEach { affectedItem in
      mapItemToID.removeValue(forKey: affectedItem)
    }
    idsPendingReload.subtract(itemIdsToRemove)
        
    affectedParentIds.forEach { affectedParentId in
      guard let affectedParentId = affectedParentId else {
        // remove root item
        rootIds.removeAll { itemIdsToRemove.contains($0) }
        return
      }
      
      // Now remove items from affected parents
      mapIDToNode[affectedParentId]?.childrenIDs.removeAll { itemIdsToRemove.contains($0) }
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
    
    let ids = items.compactMap(getIDForItem)
    idsPendingReload.formUnion(ids)
    return true
  }

  /// Returns all items marked for reloading and forgets them.
  mutating func flushReloadedItems() -> [Item] {
    guard idsPendingReload.isEmpty == false else { return [] }
    
    var result: [Item] = []
    enumerateIndexedNodes { indexedNode in
      let itemId = indexedNode.itemId
      guard idsPendingReload.contains(itemId), let item = getItemForID(itemId) else { return }
      result.append(item)
    }
    idsPendingReload.removeAll()
    return result
  }

  /// Returns `true` if the given item can be moved next to the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter targetItem: The target item added to the snapshot before.
  /// - Returns: Returns `false` if either the `item` or the `targetItem` do not exist in the snapshot
  func canMoveItem(_ item: Item, nextTo targetItem: Item) -> Bool {
    guard contains([item, targetItem]) else { return false }
    
    guard let itemId = getIDForItem(item),
          let targetItemId = getIDForItem(targetItem),
          itemId != targetItemId else {
#if DEBUG
      print("Cannot move items around themselves")
      #endif
      return false
    }
    
    let not = (!)
    return not(isItemAncestor(item, of: targetItem))
  }
  
  /// Returns `true` if the given item can be moved into the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter targetItem: The target item added to the snapshot before.
  /// - Returns: Returns `false` if either the `item` or the `targetItem` do not exist in the snapshot
  func canMoveItem(_ item: Item, into targetItem: Item) -> Bool {
    // Same checks performed
    return canMoveItem(item, nextTo: targetItem)
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
  
  /// Moves the given item into target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter afterItem: The target item to move into (i.e. target will become item's new parent)
  /// - Returns: False if the given item cannot be moved e.g. because it’s parent of the target item.
  @discardableResult
  mutating func moveItem(_ item: Item, into targetParent: Item) -> Bool  {
    moveItem(item, nextTo: targetParent, atPosition: .on)
  }

  /// Enumerates all items from top to bottom.
  /// - Parameter block: Callback for each item.
  /// - Parameter item: Enumerated item.
  /// - Parameter parentItem: Parent item if available.
  func enumerateItems(using block: (_ item: Item, _ parentItem: Item?) -> Void) {
    enumerateIndexedNodes { id in
      if let item = getItemForID(id.itemId) {
        block(item, id.parentId.flatMap(getItemForID))
      }
    }
  }
}

// MARK: - Internal API

extension DiffableDataSourceSnapshot {

  /// A fully indexed Node representation for sorting / diffing. Contains an `indexPath`.
  struct IndexedNode: Hashable {
    /// Item identifier.
    let itemId: ItemID

    /// Optional parent item identifier.
    let parentId: ItemID?

    /// Full path to the item.
    let indexPath: IndexPath

    /// Only IDs should be equal.
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.itemId == rhs.itemId && lhs.parentId == rhs.parentId
    }

    /// Only ID means as hash.
    func hash(into hasher: inout Hasher) {
      hasher.combine(itemId)
      hasher.combine(parentId)
    }
  }

  /// A linear sorted list, from top to bottom, of indexed nodes (i.e. nodes that include an `IndexPath`)
  func getSortedIndexedNodes() -> [IndexedNode] {
    var result: [IndexedNode] = []
    enumerateIndexedNodes { indexedNode in
      result.append(indexedNode)
    }
    return result
  }

  /// Returns an identifier of the stored item if available.
  /// - Parameter item: Stored item.
  func getIDForItem(_ item: Item) -> ItemID? {
    mapItemToID[item]
  }

  /// Returns a stored item for the given identifier if available.
  /// - Parameter id: Identifier of the item to return.
  public func getItemForID(_ id: ItemID) -> Item? {
    mapIDToItem[id]
  }


  /// Returns identifiers of children for the given parent identifier.
  /// - Parameter parentId: Pass nil to retrieve root item identifiers.
  func getChildIDsForParentID(_ parentId: ItemID?) -> [ItemID] {
    if let parentNode = parentId.flatMap(getNodeForID) {
      return parentNode.childrenIDs
    }
    return rootIds
  }
}

// MARK: - Private API

private extension DiffableDataSourceSnapshot {

  /// Returns a node for the given identifier if available.
  /// - Parameter id: Identifier of the node to return.
  private func getNodeForID(_ id: ItemID) -> Node? {
    mapIDToNode[id]
  }

  /// Returns `true` if this snapshot does not have any passed items.
  /// - Parameter items: Items not yet added to the snapshot.
  func validateItemsNotFound(_ items: [Item]) -> Bool {
    // Items must all be distinct
    guard Set(items).count == items.count else {
#if DEBUG
      print("Non-unique items cannot be added")
      #endif
      return false
    }
    
    let existingItems = items.map { $0.id }.compactMap(getItemForID)
    guard existingItems.isEmpty else {
      let ids = existingItems.map { $0.id }.joined(separator: ", ")
#if DEBUG
      print("Items with IDs “\(ids)” have already been added")
      #endif
      return false
    }
    return true
  }

  /// Returns `true` if this snapshot has got all passed items.
  /// - Parameter items: Items to validate
  func contains(_ items: [Item]) -> Bool {
    let missingItems = Set(items.map{ $0.id }).subtracting(mapItemToID.values)
    
    guard missingItems.isEmpty else {
      let strings = missingItems.map(String.init(describing:)).joined(separator: ", ")
#if DEBUG
      print("Items [\(strings)] have not been added")
      #endif
      return false
    }
    return true
  }

  /// Recursively goes through the whole tree and runs a callback with node.
  /// - Parameter block: Callback for every node in the tree.
  /// - Parameter indexedNode: Node representation for sorting / diffing
  func enumerateIndexedNodes(using block: (_ indexedNode: IndexedNode) -> Void) {
    func enumerateChildrenOf(_ parentId: ItemID?, parentPath: IndexPath) {
      getChildIDsForParentID(parentId).enumerated().forEach { offset, itemId in
        let itemPath = parentPath.appending(offset)
        let indexedNode = IndexedNode(itemId: itemId, parentId: parentId, indexPath: itemPath)
        
        block(indexedNode)
        
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
    var appendToParentId = parentItemToAppendTo.flatMap(getIDForItem)
    var appendToParentNode = appendToParentId.flatMap(getNodeForID)
    
    // Ignore if parent item (to append to) passed but not found
    if parentItemToAppendTo != nil && appendToParentNode == nil {
#if DEBUG
      print("insertItems - Cannot find parent item \(String(describing: parentItemToAppendTo))")
      #endif
      return false
    }
    
    // MARK: Inserting
    let targetItemId = targetItem.flatMap(getIDForItem)
    let targetItemNode = targetItemId.flatMap(getNodeForID)

    if targetItem != nil && targetItemNode == nil {
#if DEBUG
      print("Cannot find item \(String(describing: targetItem))")
      #endif
      return false
    }

    // If we're inserting next to an item, update the parent we need to use
    if let targetItemNode = targetItemNode {
      appendToParentId = targetItemNode.parentID
      appendToParentNode = appendToParentId.flatMap(getNodeForID)
    }
      
    
    // Shared logic
    // Update our maps
    let newIds = newItems.map { newItem -> ItemID in
      let newId = newItem.id
      mapIDToItem[newId] = newItem
      mapItemToID[newItem] = newId
      
      // Create a node
      mapIDToNode[newId] = .init(itemID: newId, parentID: appendToParentId, childrenIDs: [])
      
      return newId
    }
    
    // Inserting?
    if let targetItemId = targetItemId {
      
      // Inserting into a parent?
      if let parentId = appendToParentId, appendToParentNode != nil {
        let targetIndex = appendToParentNode!.childrenIDs.firstIndex(of: targetItemId) ?? .zero
        let insertionIndex = position == .before ? targetIndex : targetIndex + 1
        
        appendToParentNode!.childrenIDs.insert(contentsOf: newIds, at: insertionIndex)
        
        // Update the parent node map
        mapIDToNode[parentId] = appendToParentNode!
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
        appendToParentNode!.childrenIDs.append(contentsOf: newIds)
        
        // Update the parent node map
        mapIDToNode[parentId] = appendToParentNode!
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
    if position == .on && !canMoveItem(item, into: targetItem) {
      return false
    }
    else if !canMoveItem(item, nextTo: targetItem) {
      return false
    }

    // Remove item from old parent
    let movingItemId = getIDForItem(item).unsafelyUnwrapped
    var movingItemNode = getNodeForID(movingItemId).unsafelyUnwrapped
    if let oldParentId = movingItemNode.parentID {
      var oldParentNode = getNodeForID(oldParentId).unsafelyUnwrapped
      oldParentNode.childrenIDs.removeAll { $0 == movingItemId }
      mapIDToNode[oldParentId] = oldParentNode
    } else {
      rootIds.removeAll { $0 == movingItemId }
    }

    // Insert item into new parent
    let targetItemId = getIDForItem(targetItem).unsafelyUnwrapped
    let targetItemNode = getNodeForID(targetItemId).unsafelyUnwrapped
    
    // Use target as the new parent if moving into target, else use target's parent
    let newParentId = position == .on ? targetItemId : targetItemNode.parentID
    
    if let newParentId = newParentId {
      movingItemNode.parentID = newParentId
      
      var newParentNode = getNodeForID(newParentId).unsafelyUnwrapped
      let targetIndex = newParentNode.childrenIDs.firstIndex(of: targetItemId) ?? .zero
      let insertionIndex = position == .before || position == .on ? targetIndex : targetIndex + 1
      
      newParentNode.childrenIDs.insert(movingItemId, at: insertionIndex)
      mapIDToNode[newParentId] = newParentNode
    } else {
      movingItemNode.parentID = nil
      
      let targetIndex = rootIds.firstIndex(of: targetItemId).unsafelyUnwrapped
      let insertionIndex = position == .before ? targetIndex : targetIndex + 1
      rootIds.insert(movingItemId, at: insertionIndex)
    }
    mapIDToNode[movingItemId] = movingItemNode
    return true
  }
}
