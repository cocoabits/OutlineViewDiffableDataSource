import XCTest
import OutlineViewDiffableDataSource

final class DiffableDataSourceSnapshotTests: XCTestCase {

  class TestItem: OutlineViewItem {
    let id: String
    init(id: String) { self.id = id }
  }

  func testEmptyState() {

    // GIVEN: New snapshot
    let snapshot: DiffableDataSourceSnapshot<TestItem> = .init()

    // THEN: It is empty
    XCTAssertEqual(snapshot.numberOfItems, 0)
    XCTAssertTrue(snapshot.itemIdentifiers().isEmpty)
    XCTAssertEqual(snapshot.numberOfItems(in: nil), 0)
    XCTAssertTrue(snapshot.childrenOfItem(nil).isEmpty)
  }

  func testList() {

    // GIVEN: Some root items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")
    let c = TestItem(id: "c")

    // WHEN: They are added to snapshot
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))

    // THEN: Snapshot contains thes items
    XCTAssertEqual(snapshot.numberOfItems, 3)
    XCTAssertEqual(snapshot.itemIdentifiers(), ["a", "b", "c"])
    XCTAssertEqual(snapshot.childrenOfItem(nil), [a, b, c])

    // THEN: Number of items in root is 3
    XCTAssertEqual(snapshot.numberOfItems(in: nil), 3)

    // THEN: Any root item is empty
    XCTAssertEqual(snapshot.numberOfItems(in: a), 0)
  }

  func testTree() {

    // GIVEN: Some root items with leafs
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let b = TestItem(id: "b")
    let b1 = TestItem(id: "b1")

    // WHEN: They are added to snapshot
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b]))
    XCTAssertTrue(snapshot.appendItems([a1, a2], into: a))
    XCTAssertTrue(snapshot.appendItems([b1], into: b))

    // THEN: Total number is correct
    XCTAssertEqual(snapshot.numberOfItems, 5)
    XCTAssertEqual(snapshot.itemIdentifiers(), ["a", "a1", "a2", "b", "b1"])

    // THEN: Leaves are correct
    XCTAssertEqual(snapshot.numberOfItems(in: nil), 2)
    XCTAssertEqual(snapshot.numberOfItems(in: a), 2)
    XCTAssertEqual(snapshot.numberOfItems(in: b), 1)
    XCTAssertEqual(snapshot.childrenOfItem(a), [a1, a2])
    XCTAssertEqual(snapshot.indexOfItem(b), 1)
    XCTAssertEqual(snapshot.indexOfItem(a2), 1)

    // THEN: Parents are correct
    XCTAssertEqual(snapshot.parentOfItem(a1), a)
    XCTAssertNil(snapshot.parentOfItem(a))
  }

  func testNotFound() {

    // GIVEN: Some items
    let x = TestItem(id: "x")
    let y = TestItem(id: "y")

    // WHEN: Only one item is in the snapshot
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([x]))

    // THEN: The second item cannot be found
    XCTAssertEqual(snapshot.numberOfItems(in: y), 0)
    XCTAssertTrue(snapshot.childrenOfItem(y).isEmpty)
    XCTAssertNil(snapshot.parentOfItem(y))
    XCTAssertNil(snapshot.indexOfItem(y))
    XCTAssertNotNil(snapshot.itemWithIdentifier("x"))
    XCTAssertNil(snapshot.itemWithIdentifier("y"))
    XCTAssertTrue(snapshot.identifiersOfChildrenOfItemWithIdentifier("y").isEmpty)
  }

  func testAddingTwice() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")
    let c = TestItem(id: "c")

    // WHEN: They are added twice
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b]))
    XCTAssertFalse(snapshot.appendItems([c, c]))
    XCTAssertFalse(snapshot.appendItems([b, c]))

    // THEN: The second time is skipped
    XCTAssertEqual(snapshot.itemIdentifiers(), ["a", "b"])
  }

  func testAddingToNotFound() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")

    // WHEN: You try to use one the them as parent
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertFalse(snapshot.appendItems([b], into: a))

    // THEN: The change is ignored
    XCTAssertEqual(snapshot.numberOfItems, 0)
  }

  func testInsertions() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let a3 = TestItem(id: "a3")
    let b = TestItem(id: "b")
    let b1 = TestItem(id: "b1")
    let b2 = TestItem(id: "b2")
    let b3 = TestItem(id: "b3")
    let c = TestItem(id: "c")
    let d = TestItem(id: "d")
    let e = TestItem(id: "e")

    // WHEN: Insertions are performed
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, e]))
    XCTAssertTrue(snapshot.insertItems([b, c], afterItem: a))
    XCTAssertTrue(snapshot.insertItems([d], beforeItem: e))
    XCTAssertTrue(snapshot.appendItems([a1], into: a))
    XCTAssertTrue(snapshot.insertItems([a2, a3], afterItem: a1))
    XCTAssertTrue(snapshot.appendItems([b2], into: b))
    XCTAssertTrue(snapshot.insertItems([b1], beforeItem: b2))
    XCTAssertTrue(snapshot.insertItems([b3], afterItem: b2))

    // THEN: Tree is correct
    XCTAssertEqual(snapshot.itemIdentifiers(), ["a", "a1", "a2", "a3", "b", "b1", "b2", "b3", "c", "d", "e"])
    XCTAssertEqual(snapshot.childrenOfItem(a), [a1, a2, a3])
    XCTAssertEqual(snapshot.childrenOfItem(b), [b1, b2, b3])
  }

  func testInvalidInsertions() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")
    let c = TestItem(id: "c")
    let d = TestItem(id: "d")

    // WHEN: Invlid insertions are performed
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, c]))
    XCTAssertFalse(snapshot.insertItems([b, c], afterItem: d))
    XCTAssertFalse(snapshot.insertItems([d], afterItem:b))

    // THEN: The snapshot is not changed
    XCTAssertEqual(snapshot.childrenOfItem(nil), [a, c])
  }

  func testDeletions() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let a3 = TestItem(id: "a3")
    let b = TestItem(id: "b")
    let b1 = TestItem(id: "b1")
    let b2 = TestItem(id: "b2")
    let b3 = TestItem(id: "b3")
    let c = TestItem(id: "c")

    // WHEN: Insertions and deletions are performed
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.appendItems([a1, a2, a3], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, b2, b3], into: b))
    XCTAssertTrue(snapshot.deleteItems([a1, a2, b3, c]))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.childrenOfItem(a), [a3])
    XCTAssertEqual(snapshot.childrenOfItem(b), [b1, b2])
  }

  func testBranchDeletions() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")
    let c = TestItem(id: "c")
    let d = TestItem(id: "d")

    // WHEN: Items added as nested and deleted
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a]))
    XCTAssertTrue(snapshot.appendItems([b], into: a))
    XCTAssertTrue(snapshot.appendItems([c], into: b))
    XCTAssertTrue(snapshot.appendItems([d], into: c))
    XCTAssertTrue(snapshot.reloadItems([c, d]))
    XCTAssertTrue(snapshot.deleteItems([b]))
    XCTAssertFalse(snapshot.reloadItems([c, d]))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.itemIdentifiers(), ["a"])
    XCTAssertTrue(snapshot.flushReloadedItems().isEmpty)
  }

  func testDeletingFromNotFound() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")

    // WHEN: You try to delete non-added item
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a]))
    XCTAssertFalse(snapshot.deleteItems([b]))

    // THEN: The change is ignored
    XCTAssertEqual(snapshot.childrenOfItem(nil), [a])
  }

  func testAddingAfterDeleting() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let a3 = TestItem(id: "a3")
    let b = TestItem(id: "b")
    let b1 = TestItem(id: "b1")
    let b2 = TestItem(id: "b2")
    let c = TestItem(id: "c")

    // WHEN: Insertions, re-insertions after deletions are performed
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
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
    XCTAssertEqual(snapshot.childrenOfItem(nil), [a, b, c])
    XCTAssertEqual(snapshot.childrenOfItem(a), [a1, a2, a3])
    XCTAssertEqual(snapshot.childrenOfItem(b), [b1, b2])
  }

  func testDeletingAll() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let a3 = TestItem(id: "a3")
    let b = TestItem(id: "b")
    let b1 = TestItem(id: "b1")
    let b2 = TestItem(id: "b2")
    let c = TestItem(id: "c")

    // WHEN: All items deleted after insertions
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.appendItems([a1, a2, a3], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, b2], into: b))
    snapshot.deleteAllItems()

    // THEN: The snapshot is empty
    XCTAssertEqual(snapshot.numberOfItems, 0)
    XCTAssertTrue(snapshot.itemIdentifiers().isEmpty)
  }

  func testReloading() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let a3 = TestItem(id: "a3")
    let b = TestItem(id: "b")
    let b1 = TestItem(id: "b1")
    let b2 = TestItem(id: "b2")
    let c = TestItem(id: "c")

    // WHEN: Some items reloaded
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.appendItems([a1, a2, a3], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, b2], into: b))
    XCTAssertTrue(snapshot.reloadItems([a1, b2, c]))

    // THEN: Items are marked as reloaded
    XCTAssertEqual(snapshot.flushReloadedItems(), [a1, b2, c])
    XCTAssertTrue(snapshot.flushReloadedItems().isEmpty)
  }

  func testReloadingNotFound() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let a3 = TestItem(id: "a3")

    // WHEN: You reload not-added items
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a]))
    XCTAssertTrue(snapshot.appendItems([a1, a2], into: a))
    XCTAssertFalse(snapshot.reloadItems([a2, a3]))

    // THEN: The snapshot is not affected
    XCTAssertTrue(snapshot.flushReloadedItems().isEmpty)
  }

  func testReloadingThenDeleting() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")
    let c = TestItem(id: "c")

    // WHEN: You reload but then delete
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b, c]))
    XCTAssertTrue(snapshot.reloadItems([a, b]))
    XCTAssertTrue(snapshot.deleteItems([b, c]))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.flushReloadedItems(), [a])
  }

  func testMoving() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let a1 = TestItem(id: "a1")
    let a2 = TestItem(id: "a2")
    let a3 = TestItem(id: "a3")
    let b = TestItem(id: "b")
    let b1 = TestItem(id: "b1")
    let b2 = TestItem(id: "b2")
    let c = TestItem(id: "c")
    let d = TestItem(id: "d")

    // WHEN: You insert them
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([c, b, a]))
    XCTAssertTrue(snapshot.appendItems([a1, a3, b2], into: a))
    XCTAssertTrue(snapshot.appendItems([b1, a2], into: b))

    // THEN: Only some items can be moved
    XCTAssertFalse(snapshot.canMoveItem(b, aroundItem: b))
    XCTAssertFalse(snapshot.canMoveItem(c, aroundItem: d))
    XCTAssertFalse(snapshot.canMoveItem(d, aroundItem: c))
    XCTAssertFalse(snapshot.canMoveItem(b, aroundItem: a2))
    XCTAssertTrue(snapshot.canMoveItem(b1, aroundItem: a3))

    // WHEN: You move some items
    XCTAssertFalse(snapshot.moveItem(d, beforeItem: c))
    XCTAssertTrue(snapshot.moveItem(a, beforeItem: b))
    XCTAssertTrue(snapshot.moveItem(c, afterItem: b))
    XCTAssertTrue(snapshot.moveItem(b2, afterItem: b1))
    XCTAssertTrue(snapshot.moveItem(a2, beforeItem: a3))

    // THEN: The snapshot is correct
    XCTAssertEqual(snapshot.childrenOfItem(nil), [a, b, c])
    XCTAssertEqual(snapshot.childrenOfItem(a), [a1, a2, a3])
    XCTAssertEqual(snapshot.childrenOfItem(b), [b1, b2])
    XCTAssertTrue(snapshot.childrenOfItem(c).isEmpty)
  }

  func testMovingNonExisting() {

    // GIVEN: Some items
    let a = TestItem(id: "a")
    let b = TestItem(id: "b")
    let c = TestItem(id: "c")

    // WHEN: You move non-added items
    var snapshot: DiffableDataSourceSnapshot<TestItem> = .init()
    XCTAssertTrue(snapshot.appendItems([a, b]))
    XCTAssertFalse(snapshot.moveItem(a, afterItem: a))
    XCTAssertFalse(snapshot.moveItem(c, afterItem: a))
    XCTAssertFalse(snapshot.moveItem(b, afterItem: c))
    XCTAssertFalse(snapshot.moveItem(a, beforeItem: a))
    XCTAssertFalse(snapshot.moveItem(c, beforeItem: a))
    XCTAssertFalse(snapshot.moveItem(b, beforeItem: c))

    // THEN: The snapshot is not affected
    XCTAssertEqual(snapshot.childrenOfItem(nil), [a, b])
  }
}
