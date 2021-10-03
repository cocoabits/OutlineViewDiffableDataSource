import XCTest
import OutlineViewDiffableDataSource

private class SnapshotItem: OutlineViewItem {}

extension Collection where Element == OutlineViewItem {
  func snapshotItemIds() -> [String] {
    compactMap { $0 as? SnapshotItem }.map(\.id)
  }
}

final class DiffableDataSourceSnapshotTests: XCTestCase {

  func testEqualItems() {

    // GIVEN: Equal items
    let a1 = SnapshotItem(id: "a")
    let a2 = SnapshotItem(id: "a")

    // THEN: Equality works
    XCTAssertEqual(a1, a1)
    XCTAssertEqual(a1, a2)
    XCTAssertEqual(a2, a1)
    XCTAssertEqual(a2, a2)

    // GIVEN: Non-equal item
    let b = SnapshotItem(id: "b")

    // THEN: Equality does not work
    XCTAssertNotEqual(a1, b)
    XCTAssertNotEqual(a2, b)
  }

  func testContainment() {

    // GIVEN: Equal items
    let a1 = SnapshotItem(id: "a")
    let a2 = SnapshotItem(id: "a")

    // WHEN: They are added to snapshot
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertFalse(snapshot.appendItems([a1, a2]))
    XCTAssertTrue(snapshot.appendItems([a1]))
    XCTAssertFalse(snapshot.appendItems([a2]))

    // THEN: Only one item is added for real
    XCTAssertEqual(snapshot.numberOfItems, 1)

    // THEN: Another is counted as added
    XCTAssertTrue(snapshot.containsItem(a2))
  }

  func testEmptyState() {

    // GIVEN: New snapshot
    let snapshot: DiffableDataSourceSnapshot = .init()

    // THEN: It is empty
    XCTAssertEqual(snapshot.numberOfItems, 0)
    XCTAssertTrue(snapshot.sortedItems().isEmpty)
    XCTAssertEqual(snapshot.numberOfItems(in: nil), 0)
    XCTAssertTrue(snapshot.childrenOfItem(nil).isEmpty)
  }

  func testList() {

    // GIVEN: Some root items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")
    let c = SnapshotItem(id: "c")

    // WHEN: They are added to snapshot
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))

    // THEN: Snapshot contains thes items
    XCTAssertEqual(snapshot.numberOfItems, 3)
    XCTAssertEqual(snapshot.sortedItems().snapshotItemIds(), ["a", "b", "c"])
    XCTAssertEqual(snapshot.childrenOfItem(nil).compactMap { $0 as? SnapshotItem }, [a, b, c])

    // THEN: Number of items in root is 3
    XCTAssertEqual(snapshot.numberOfItems(in: nil), 3)

    // THEN: Any root item is empty
    XCTAssertEqual(snapshot.numberOfItems(in: a), 0)
  }

  func testTree() {

    // GIVEN: Some root items with leafs
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")

    // WHEN: They are added to snapshot
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b]))
    XCTAssertTrue(snapshot.appendItems([a1, a2], into: a))
    XCTAssertTrue(snapshot.appendItems([b1], into: b))

    // THEN: Total number is correct
    XCTAssertEqual(snapshot.numberOfItems, 5)
    XCTAssertEqual(snapshot.sortedItems().snapshotItemIds(), ["a", "a1", "a2", "b", "b1"])

    // THEN: Leaves are correct
    XCTAssertEqual(snapshot.numberOfItems(in: nil), 2)
    XCTAssertEqual(snapshot.numberOfItems(in: a), 2)
    XCTAssertEqual(snapshot.numberOfItems(in: b), 1)
    XCTAssertEqual(snapshot.childrenOfItem(a).compactMap { $0 as? SnapshotItem }, [a1, a2])
    XCTAssertEqual(snapshot.indexOfItem(b), 1)
    XCTAssertEqual(snapshot.indexOfItem(a2), 1)

    // THEN: Parents are correct
    XCTAssertEqual(snapshot.parentOfItem(a1) as? SnapshotItem, a)
    XCTAssertNil(snapshot.parentOfItem(a))
  }

  func testNotFound() {

    // GIVEN: Some items
    let x = SnapshotItem(id: "x")
    let y = SnapshotItem(id: "y")

    // WHEN: Only one item is in the snapshot
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([x]))

    // THEN: The second item cannot be found
    XCTAssertEqual(snapshot.numberOfItems(in: y), 0)
    XCTAssertTrue(snapshot.childrenOfItem(y).isEmpty)
    XCTAssertNil(snapshot.parentOfItem(y))
    XCTAssertNil(snapshot.indexOfItem(y))
    XCTAssertTrue(snapshot.containsItem(x))
    XCTAssertFalse(snapshot.containsItem(y))
    XCTAssertTrue(snapshot.childrenOfItem(y).isEmpty)
  }

  func testAddingTwice() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")
    let c = SnapshotItem(id: "c")

    // WHEN: They are added twice
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b]))
    XCTAssertFalse(snapshot.appendItems([c, c]))
    XCTAssertFalse(snapshot.appendItems([b, c]))

    // THEN: The second time is skipped
    XCTAssertEqual(snapshot.sortedItems().snapshotItemIds(), ["a", "b"])
  }

  func testAddingToNotFound() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")

    // WHEN: You try to use one of the them as parent
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertFalse(snapshot.appendItems([b], into: a))

    // THEN: The change is ignored
    XCTAssertEqual(snapshot.numberOfItems, 0)
  }

  func testInsertions() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a3 = SnapshotItem(id: "a3")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")
    let b2 = SnapshotItem(id: "b2")
    let b3 = SnapshotItem(id: "b3")
    let c = SnapshotItem(id: "c")
    let d = SnapshotItem(id: "d")
    let e = SnapshotItem(id: "e")

    // WHEN: Insertions are performed
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, e]))
    XCTAssertTrue(snapshot.insertItems([b, c], afterItem: a))
    XCTAssertTrue(snapshot.insertItems([d], beforeItem: e))
    XCTAssertTrue(snapshot.appendItems([a1], into: a))
    XCTAssertTrue(snapshot.insertItems([a2, a3], afterItem: a1))
    XCTAssertTrue(snapshot.appendItems([b2], into: b))
    XCTAssertTrue(snapshot.insertItems([b1], beforeItem: b2))
    XCTAssertTrue(snapshot.insertItems([b3], afterItem: b2))

    // THEN: Tree is correct
    XCTAssertEqual(snapshot.sortedItems().snapshotItemIds(), ["a", "a1", "a2", "a3", "b", "b1", "b2", "b3", "c", "d", "e"])
    XCTAssertEqual(snapshot.childrenOfItem(a).compactMap { $0 as? SnapshotItem }, [a1, a2, a3])
    XCTAssertEqual(snapshot.childrenOfItem(b).compactMap { $0 as? SnapshotItem }, [b1, b2, b3])
  }

  func testInvalidInsertions() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")
    let c = SnapshotItem(id: "c")
    let d = SnapshotItem(id: "d")

    // WHEN: Invlid insertions are performed
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, c]))
    XCTAssertFalse(snapshot.insertItems([b, c], afterItem: d))
    XCTAssertFalse(snapshot.insertItems([d], afterItem:b))

    // THEN: The snapshot is not changed
    XCTAssertEqual(snapshot.childrenOfItem(nil).compactMap { $0 as? SnapshotItem }, [a, c])
  }

  func testDeletions() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a3 = SnapshotItem(id: "a3")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")
    let b2 = SnapshotItem(id: "b2")
    let b3 = SnapshotItem(id: "b3")
    let c = SnapshotItem(id: "c")

    // WHEN: Insertions and deletions are performed
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.appendItems([a1, a2, a3], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, b2, b3], into: b))
    XCTAssertTrue(snapshot.deleteItems([a1, a2, b3, c]))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.childrenOfItem(a).compactMap { $0 as? SnapshotItem }, [a3])
    XCTAssertEqual(snapshot.childrenOfItem(b).compactMap { $0 as? SnapshotItem }, [b1, b2])
  }

  func testBranchDeletions() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")
    let c = SnapshotItem(id: "c")
    let d = SnapshotItem(id: "d")

    // WHEN: Items added as nested and deleted
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a]))
    XCTAssertTrue(snapshot.appendItems([b], into: a))
    XCTAssertTrue(snapshot.appendItems([c], into: b))
    XCTAssertTrue(snapshot.appendItems([d], into: c))
    XCTAssertTrue(snapshot.reloadItems([c, d]))
    XCTAssertTrue(snapshot.deleteItems([b]))
    XCTAssertFalse(snapshot.reloadItems([c, d]))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.sortedItems().snapshotItemIds(), ["a"])
    XCTAssertTrue(snapshot.flushReloadedItems().isEmpty)
  }

  func testDeletingFromNotFound() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")

    // WHEN: You try to delete non-added item
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a]))
    XCTAssertFalse(snapshot.deleteItems([b]))

    // THEN: The change is ignored
    XCTAssertEqual(snapshot.childrenOfItem(nil).compactMap { $0 as? SnapshotItem }, [a])
  }

  func testAddingAfterDeleting() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a3 = SnapshotItem(id: "a3")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")
    let b2 = SnapshotItem(id: "b2")
    let c = SnapshotItem(id: "c")

    // WHEN: Insertions, re-insertions after deletions are performed
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.appendItems([a1, a2, a3], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, b2], into: b))
    XCTAssertTrue(snapshot.deleteItems([a1, a3, b]))
    XCTAssertFalse(snapshot.deleteItems([a1]))
    XCTAssertTrue(snapshot.insertItems([b], beforeItem: c))
    XCTAssertTrue(snapshot.appendItems([b1, b2], into: b))
    XCTAssertTrue(snapshot.insertItems([a1], beforeItem: a2))
    XCTAssertTrue(snapshot.insertItems([a3], afterItem: a2))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.childrenOfItem(nil).compactMap { $0 as? SnapshotItem }, [a, b, c])
    XCTAssertEqual(snapshot.childrenOfItem(a).compactMap { $0 as? SnapshotItem }, [a1, a2, a3])
    XCTAssertEqual(snapshot.childrenOfItem(b).compactMap { $0 as? SnapshotItem }, [b1, b2])
  }

  func testDeletingAll() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a3 = SnapshotItem(id: "a3")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")
    let b2 = SnapshotItem(id: "b2")
    let c = SnapshotItem(id: "c")

    // WHEN: All items deleted after insertions
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.appendItems([a1, a2, a3], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, b2], into: b))
    snapshot.deleteAllItems()

    // THEN: The snapshot is empty
    XCTAssertEqual(snapshot.numberOfItems, 0)
    XCTAssertTrue(snapshot.sortedItems().isEmpty)
  }

  func testReloading() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a3 = SnapshotItem(id: "a3")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")
    let b2 = SnapshotItem(id: "b2")
    let c = SnapshotItem(id: "c")

    // WHEN: Some items reloaded
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.appendItems([a1, a2, a3], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, b2], into: b))
    XCTAssertTrue(snapshot.reloadItems([a1, b2, c]))

    // THEN: Items are marked as reloaded
    XCTAssertEqual(snapshot.flushReloadedItems().compactMap { $0 as? SnapshotItem }, [a1, b2, c])
    XCTAssertTrue(snapshot.flushReloadedItems().isEmpty)
  }

  func testReloadingNotFound() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a3 = SnapshotItem(id: "a3")

    // WHEN: You reload not-added items
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a]))
    XCTAssertTrue(snapshot.appendItems([a1, a2], into: a))
    XCTAssertFalse(snapshot.reloadItems([a2, a3]))

    // THEN: The snapshot is not affected
    XCTAssertTrue(snapshot.flushReloadedItems().isEmpty)
  }

  func testReloadingThenDeleting() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")
    let c = SnapshotItem(id: "c")

    // WHEN: You reload but then delete
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.reloadItems([a, b]))
    XCTAssertTrue(snapshot.deleteItems([b, c]))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.flushReloadedItems().compactMap { $0 as? SnapshotItem }, [a])
  }

  func testMoving() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a3 = SnapshotItem(id: "a3")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")
    let b2 = SnapshotItem(id: "b2")
    let c = SnapshotItem(id: "c")
    let d = SnapshotItem(id: "d")

    // WHEN: You insert them
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([c, b, a]))
    XCTAssertTrue(snapshot.appendItems([a1, a3, b2], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, a2], into: b))

    // THEN: Only some items can be moved
    XCTAssertFalse(snapshot.canMoveItem(b, nextTo: b))
    XCTAssertFalse(snapshot.canMoveItem(c, nextTo: d))
    XCTAssertFalse(snapshot.canMoveItem(d, nextTo: c))
    XCTAssertFalse(snapshot.canMoveItem(b, nextTo: a2))
    XCTAssertTrue(snapshot.canMoveItem(b1, nextTo: a3))

    // WHEN: You move some items
    XCTAssertFalse(snapshot.moveItem(d, beforeItem: c))
    XCTAssertTrue(snapshot.moveItem(a, beforeItem: b))
    XCTAssertTrue(snapshot.moveItem(c, afterItem: b))
    XCTAssertTrue(snapshot.moveItem(b2, afterItem: b1))
    XCTAssertTrue(snapshot.moveItem(a2, beforeItem: a3))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.childrenOfItem(nil).compactMap { $0 as? SnapshotItem }, [a, b, c])
    XCTAssertEqual(snapshot.childrenOfItem(a).compactMap { $0 as? SnapshotItem }, [a1, a2, a3])
    XCTAssertEqual(snapshot.childrenOfItem(b).compactMap { $0 as? SnapshotItem }, [b1, b2])
    XCTAssertTrue(snapshot.childrenOfItem(c).isEmpty)
  }
  
  func testMovingWithChildren() {
    
    // GIVEN: Some items
    let cars = SnapshotItem(id: "Cars")
    let models = SnapshotItem(id: "Models")
    let camry = SnapshotItem(id: "Toyota Camry")
    let mycars = SnapshotItem(id: "My Cars")
    let honda = SnapshotItem(id: "Honda")
    
    // WHEN: You insert them
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([cars, mycars]))
    XCTAssertTrue(snapshot.appendItems([models], into: cars))
    XCTAssertTrue(snapshot.appendItems([camry], into: models))
    XCTAssertTrue(snapshot.appendItems([honda], into: mycars))
    
    // WHEN: You move some items
    XCTAssertTrue(snapshot.moveItem(models, beforeItem: honda))
    
    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.childrenOfItem(nil).compactMap { $0 as? SnapshotItem }, [cars, mycars])
    XCTAssertTrue(snapshot.childrenOfItem(cars).isEmpty)
    XCTAssertEqual(snapshot.childrenOfItem(mycars).compactMap { $0 as? SnapshotItem }, [models, honda])
    XCTAssertEqual(snapshot.childrenOfItem(models).compactMap { $0 as? SnapshotItem }, [camry])
  }

  func testMovingNonExisting() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let b = SnapshotItem(id: "b")
    let c = SnapshotItem(id: "c")

    // WHEN: You move non-added items
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b]))
    XCTAssertFalse(snapshot.moveItem(a, afterItem: a))
    XCTAssertFalse(snapshot.moveItem(c, afterItem: a))
    XCTAssertFalse(snapshot.moveItem(b, afterItem: c))
    XCTAssertFalse(snapshot.moveItem(a, beforeItem: a))
    XCTAssertFalse(snapshot.moveItem(c, beforeItem: a))
    XCTAssertFalse(snapshot.moveItem(b, beforeItem: c))

    // THEN: The snapshot is not affected
    XCTAssertEqual(snapshot.childrenOfItem(nil).compactMap { $0 as? SnapshotItem }, [a, b])
  }

  func testEnumeration() {

    // GIVEN: Some items
    let a = SnapshotItem(id: "a")
    let a1 = SnapshotItem(id: "a1")
    let a2 = SnapshotItem(id: "a2")
    let a21 = SnapshotItem(id: "a21")
    let a22 = SnapshotItem(id: "a22")
    let b = SnapshotItem(id: "b")
    let b1 = SnapshotItem(id: "b1")
    let b2 = SnapshotItem(id: "b2")

    // WHEN: You insert them
    var snapshot: DiffableDataSourceSnapshot = .init()
    XCTAssertTrue(snapshot.appendItems([a, b]))
    XCTAssertTrue(snapshot.appendItems([a1, a2], into: a))
    XCTAssertTrue(snapshot.appendItems([a21, a22], into: a2))
    XCTAssertTrue(snapshot.appendItems([b1, b2], into: b))

    // THEN: Items enumerated from top to bottom
    var lines: [String] = []
    snapshot.enumerateItems { item, parent in
      let itemId = (item as? SnapshotItem)?.id
      let parentId = (parent as? SnapshotItem)?.id
      lines.append([parentId, itemId].compactMap { $0 }.joined(separator: " / "))
    }
    XCTAssertEqual(lines.joined(separator: "\n"), """
      a
      a / a1
      a / a2
      a2 / a21
      a2 / a22
      b
      b / b1
      b / b2
      """)
  }
}
