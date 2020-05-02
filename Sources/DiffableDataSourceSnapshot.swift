import Foundation
import os

/// Container for the tree of items.
public struct DiffableDataSourceSnapshot<Item: Diffable> {

  /// Used to store tree nodes for items.
  private struct Node: Hashable {

    /// Parent of the stored item.
    var parent: Item.ID?

    /// Children of the stored item.
    var children: [Item.ID]
  }

  /// Stored items.
  private var items: [Item.ID: Item] = [:]

  /// Tree nodes with stored items.
  private var nodes: [Item.ID: Node] = [:]

  /// Root nodes with stored items.
  private var rootChildren: [Item.ID] = []

  /// Used to remember reloaded items until flush.
  private var pendingReload: Set<Item.ID> = []

  /// Creates an empty snapshot without any items.
  public init() {}
}

// MARK: - Public API

public extension DiffableDataSourceSnapshot {

  /// Total number of stored items.
  var numberOfItems: Int {
    items.count
  }

  /// Identifiers of stored items sorted from top to bottom.
  func itemIdentifiers() -> [Item.ID] {
    indexedItemIdentifiers().map(\.itemIdentifier)
  }

  /// Returns a stored item for the given identifier if available.
  /// - Parameter identifier: Identifier of the item to return.
  func itemWithIdentifier(_ identifier: Item.ID) -> Item? {
    items[identifier]
  }

  /// Returns identifiers of children for the given parent identifier.
  /// - Parameter parentIdentifier: Pass nil to retrieve root item identifiers.
  func identifiersOfChildrenOfItemWithIdentifier(_ parentIdentifier: Item.ID?) -> [Item.ID] {
    guard let parentIdentifier = parentIdentifier else { return rootChildren }
    guard let parentNode = nodes[parentIdentifier] else {
      os_log(.error, log: errors, "Cannot find parent item with ID “%s”", String(describing: parentIdentifier))
      return []
    }
    return parentNode.children
  }

  /// Returns the number of children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func numberOfItems(in parentItem: Item?) -> Int {
    guard let parentItem = parentItem else { return rootChildren.count }
    guard let parentNode = nodes[parentItem.id] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: parentItem.id))
      return NSNotFound
    }
    return parentNode.children.count
  }

  /// Returns children for the given parent item.
  /// - Parameter parentItem: Pass nil to retrieve the number of root items.
  func childrenOfItem(_ parentItem: Item?) -> [Item] {
    guard let parentItem = parentItem else { return rootChildren.compactMap { items[$0] } }
    guard let parentNode = nodes[parentItem.id] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: parentItem.id))
      return []
    }
    return parentNode.children.compactMap { items[$0] }
  }

  /// Returns parent for the given child item. Root items have `nil` as a parent.
  /// - Parameter childItem: Child item added to the snapshot before.
  func parentOfItem(_ childItem: Item) -> Item? {
    guard let childNode = nodes[childItem.id] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: childItem.id))
      return nil
    }
    guard let parentIdentifier = childNode.parent else { return nil }
    return items[parentIdentifier]
  }

  /// Returns index of the given child item in its parent.
  /// - Parameter childItem: Child item added to the snapshot before.
  /// - Returns: `NSNotFound` if the given item is not in the snapshot.
  func indexOfItem(_ childItem: Item) -> Int {
    let childIdentifier = childItem.id
    guard let childNode = nodes[childIdentifier] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: childItem.id))
      return NSNotFound
    }
    let parentIdentifier = childNode.parent
    let children = identifiersOfChildrenOfItemWithIdentifier(parentIdentifier)
    return children.firstIndex(of: childIdentifier).unsafelyUnwrapped
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
        items[newItem.id] = newItem
        nodes[newItem.id] = .init(parent: nil, children: [])
      }
      rootChildren.append(contentsOf: newItems.map(\.id))
      return true
    }
    let parentIdentifier = parentItem.id
    guard var parentNode = nodes[parentIdentifier] else {
      os_log(.error, log: errors, "Cannot find parent item with ID “%s”", String(describing: parentIdentifier))
      return false
    }
    newItems.forEach { newItem in
      items[newItem.id] = newItem
      nodes[newItem.id] = .init(parent: parentIdentifier, children: [])
    }
    parentNode.children.append(contentsOf: newItems.map(\.id))
    nodes[parentIdentifier] = parentNode
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
    let existingIdentifiers = Set(existingItems.map(\.id))
    guard validateExistingIdentifiers(existingIdentifiers) else { return false }

    var affectedIdentifiers = existingIdentifiers
    enumerateItemIdentifiers { indexedItemIdentifier in
      guard let parentIdentifier = indexedItemIdentifier.parentIdentifier else { return }
      guard affectedIdentifiers.contains(parentIdentifier) else { return }
      affectedIdentifiers.insert(indexedItemIdentifier.itemIdentifier)
    }

    let parentIdentifiers = affectedIdentifiers.map { nodes[$0]?.parent }
    affectedIdentifiers.forEach {
      items.removeValue(forKey: $0)
      nodes.removeValue(forKey: $0)
    }
    pendingReload.subtract(affectedIdentifiers)
    parentIdentifiers.forEach {
      guard let parentIdentifier = $0 else {
        rootChildren.removeAll { affectedIdentifiers.contains($0) }
        return
      }
      nodes[parentIdentifier]?.children.removeAll { affectedIdentifiers.contains($0) }
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
    let identifiers = Set(items.map(\.id))
    guard validateExistingIdentifiers(identifiers) else { return false }
    pendingReload.formUnion(identifiers)
    return true
  }

  /// Returns all items marked for reloading and forgets them.
  mutating func flushReloadedItems() -> [Item] {
    guard pendingReload.isEmpty == false else { return [] }
    var result: [Item] = []
    enumerateItemIdentifiers { indexedItemIdentifier in
      let identifier = indexedItemIdentifier.itemIdentifier
      guard pendingReload.contains(identifier) else { return }
      result.append(items[identifier].unsafelyUnwrapped)
    }
    pendingReload.removeAll()
    return result
  }

  /// Returns true if the given item can be moved next to the target item.
  /// - Parameter item: Item added to the snapshot before.
  /// - Parameter targetItem: The target item added to the snapshot before.
  func canMoveItem(_ item: Item, aroundItem targetItem: Item) -> Bool {
    guard item.id != targetItem.id else {
      os_log(.error, log: errors, "Cannot move item with IDs “%s” around itself", String(describing: item.id))
      return false
    }
    guard validateExistingIdentifiers([item.id, targetItem.id]) else { return false }
    let parentIdentifiers = sequence(first: targetItem.id) { self.nodes[$0]?.parent }
    return parentIdentifiers.allSatisfy { $0 != item.id }
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
}

// MARK: - Internal API

extension DiffableDataSourceSnapshot {

  /// Container for sorting.
  struct IndexedItemIdentifier: Hashable {

    /// Item identifier.
    let itemIdentifier: Item.ID

    /// Optional parent item identifier.
    let parentIdentifier: Item.ID?

    /// Full path to the item.
    let itemPath: IndexPath

    /// Only IDs should be equal.
    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.itemIdentifier == rhs.itemIdentifier
    }

    /// Only ID means as hash.
    func hash(into hasher: inout Hasher) {
      hasher.combine(itemIdentifier)
    }
  }

  /// Identifiers of stored items sorted from top to bottom.
  func indexedItemIdentifiers() -> [IndexedItemIdentifier] {
    var result: [IndexedItemIdentifier] = []
    enumerateItemIdentifiers { indexedItemIdentifier in
      result.append(indexedItemIdentifier)
    }
    return result
  }
}

// MARK: - Private API

private extension DiffableDataSourceSnapshot {

  /// Returns true if this snapshot does not have any passed items.
  /// - Parameter newItems: New items not yet added to the snapshot.
  func validateNewItems(_ newItems: [Item]) -> Bool {
    let newIdentifiers = Set(newItems.map(\.id))
    guard newIdentifiers.count == newItems.count else {
      os_log(.error, log: errors, "Items with duplicate IDs cannot be added")
      return false
    }
    let existingIdentifiers = newIdentifiers.intersection(items.keys)
    guard existingIdentifiers.isEmpty else {
      let identifiers = existingIdentifiers.map(String.init(describing:)).joined(separator: ", ")
      os_log(.error, log: errors, "Items with IDs “%s” have already been added", identifiers)
      return false
    }
    return true
  }

  /// Returns true if this snapshot has got all passed items.
  /// - Parameter existingIdentifiers: Items already added to the snapshot.
  func validateExistingIdentifiers(_ existingIdentifiers: Set<Item.ID>) -> Bool {
    let missingIdentifiers = existingIdentifiers.subtracting(items.keys)
    guard missingIdentifiers.isEmpty else {
      let identifiers = missingIdentifiers.map(String.init(describing:)).joined(separator: ", ")
      os_log(.error, log: errors, "Items with IDs “%s” have not been added", identifiers)
      return false
    }
    return true
  }

  /// Recursively goes through the whole tree and runs a callback with node.
  /// - Parameter block: Callback for every node in the tree.
  /// - Parameter itemIdentifier: Identifier of the item.
  /// - Parameter parentIdentifier: Optional identifier of the parent item.
  /// - Parameter itemPath: Item index path for sorting.
  func enumerateItemIdentifiers(using block: (_ indexedItemIdentifier: IndexedItemIdentifier) -> Void) {
    func enumerateChildrenOf(_ parentIdentifier: Item.ID?, parentPath: IndexPath) {
      identifiersOfChildrenOfItemWithIdentifier(parentIdentifier).enumerated().forEach { offset, itemIdentifier in
        let itemPath = parentPath.appending(offset)
        block(.init(itemIdentifier: itemIdentifier, parentIdentifier: parentIdentifier, itemPath: itemPath))
        enumerateChildrenOf(itemIdentifier, parentPath: itemPath)
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
    guard let targetNode = nodes[targetItem.id] else {
      os_log(.error, log: errors, "Cannot find item with ID “%s”", String(describing: targetItem.id))
      return false
    }
    guard let parentIdentifier = targetNode.parent else {
      newItems.forEach { newItem in
        items[newItem.id] = newItem
        nodes[newItem.id] = .init(parent: nil, children: [])
      }
      let targetIndex = rootChildren.firstIndex(of: targetItem.id).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      rootChildren.insert(contentsOf: newItems.map(\.id), at: insertionIndex)
      return true
    }
    newItems.forEach { newItem in
      items[newItem.id] = newItem
      nodes[newItem.id] = .init(parent: parentIdentifier, children: [])
    }
    var parentNode = nodes[parentIdentifier].unsafelyUnwrapped
    let targetIndex = parentNode.children.firstIndex(of: targetItem.id).unsafelyUnwrapped
    parentNode.children.insert(contentsOf: newItems.map(\.id), at: indexFrom(targetIndex))
    nodes[parentIdentifier] = parentNode
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
    let itemIdentifier = item.id
    var itemNode = nodes[itemIdentifier].unsafelyUnwrapped
    if let oldParentIdentifier = itemNode.parent {
      var oldParentNode = nodes[oldParentIdentifier].unsafelyUnwrapped
      oldParentNode.children.removeAll { $0 == itemIdentifier }
      nodes[oldParentIdentifier] = oldParentNode
    } else {
      rootChildren.removeAll { $0 == itemIdentifier }
    }

    // Insert item into new parent
    let targetItemNode = nodes[targetItem.id].unsafelyUnwrapped
    if let newParentIdentifier = targetItemNode.parent {
      itemNode.parent = newParentIdentifier
      var newParentNode = nodes[newParentIdentifier].unsafelyUnwrapped
      let targetIndex = newParentNode.children.firstIndex(of: targetItem.id).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      newParentNode.children.insert(itemIdentifier, at: insertionIndex)
      nodes[newParentIdentifier] = newParentNode
    } else {
      itemNode.parent = nil
      let targetIndex = rootChildren.firstIndex(of: targetItem.id).unsafelyUnwrapped
      let insertionIndex = indexFrom(targetIndex)
      rootChildren.insert(itemIdentifier, at: insertionIndex)
    }
    nodes[itemIdentifier] = itemNode
    return true
  }
}

/// Local handle for logging errors.
private let errors: OSLog = .init(subsystem: "OutlineViewDiffableDataSource", category: "DiffableDataSourceSnapshot")
