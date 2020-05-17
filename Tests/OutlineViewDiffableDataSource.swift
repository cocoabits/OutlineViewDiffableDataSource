import XCTest
import OutlineViewDiffableDataSource

final class OutlineViewDiffableDataSourceTests: XCTestCase {

  private class OutlineItem: NSObject, OutlineViewItem {
    let title: String
    init(title: String) { self.title = title }
    override var hash: Int { title.hash }
    override func isEqual(_ object: Any?) -> Bool {
      guard let outlintItem = object as? OutlineItem else { return false }
      return outlintItem.title == title
    }
  }

  private lazy var outlineView: NSOutlineView = {
    let firstColumn = NSTableColumn()
    let outlineView = NSOutlineView()
    outlineView.addTableColumn(firstColumn)
    outlineView.outlineTableColumn = firstColumn
    return outlineView
  }()

  func testEmptyOutlineView() {

    // GIVEN: Empty data source
    let dataSource: OutlineViewDiffableDataSource = .init(outlineView: outlineView)
    XCTAssertTrue(outlineView.dataSource === dataSource)

    // WHEN: Outline view is loaded
    outlineView.layoutSubtreeIfNeeded()

    // THEN: Outline view is empty
    XCTAssertEqual(outlineView.numberOfRows, 0)
  }

  func testRootItems() {

    // GIVEN: Some items
    let a = OutlineItem(title: "a")
    let b = OutlineItem(title: "b")
    let c = OutlineItem(title: "c")

    // WHEN: They are added to the snapshot
    let dataSource: OutlineViewDiffableDataSource = .init(outlineView: outlineView)
    var snapshot = dataSource.snapshot()
    snapshot.appendItems([a, b, c])
    dataSource.applySnapshot(snapshot, animatingDifferences: false)

    // THEN: They appear in the outline view
    XCTAssertEqual(outlineView.numberOfRows, 3)
  }

  func testAnimatedInsertionsAndDeletions() {

    // GIVEN: Some items
    let a = OutlineItem(title: "a")
    let a1 = OutlineItem(title: "a1")
    let a2 = OutlineItem(title: "a2")
    let a3 = OutlineItem(title: "a3")
    let b = OutlineItem(title: "b")
    let b1 = OutlineItem(title: "b1")
    let b2 = OutlineItem(title: "b2")

    // GIVEN: Some items in the outline view
    let dataSource: OutlineViewDiffableDataSource = .init(outlineView: outlineView)
    var initialSnapshot = dataSource.snapshot()
    initialSnapshot.appendItems([a, b])
    initialSnapshot.appendItems([a1], into: a)
    initialSnapshot.appendItems([b2], into: b)
    dataSource.applySnapshot(initialSnapshot, animatingDifferences: false)

    // WHEN: Items are inserted with animation
    var finalSnapshot = dataSource.snapshot()
    finalSnapshot.insertItems([a2, a3], afterItem: a1)
    finalSnapshot.insertItems([b1], beforeItem: b2)
    finalSnapshot.deleteItems([a1, b2])

    // Wait while animation is completed
    let e = expectation(description: "Animation")
    dataSource.applySnapshot(finalSnapshot, animatingDifferences: true) {
      e.fulfill()
    }
    waitForExpectations(timeout: 0.5, handler: nil)

    // THEN: Outline view is updated
    outlineView.expandItem(nil, expandChildren: true)
    let expandedItems = (0 ..< outlineView.numberOfRows)
      .map(outlineView.item(atRow:)).compactMap { $0 as? OutlineItem }
    XCTAssertEqual(expandedItems.map(\.title), [a, a2, a3, b, b1].map(\.title))
  }

  func testAnimatedMoves() {

    // GIVEN: Some items
    let a = OutlineItem(title: "a")
    let a1 = OutlineItem(title: "a1")
    let a2 = OutlineItem(title: "a2")
    let a3 = OutlineItem(title: "a3")
    let b = OutlineItem(title: "b")
    let b1 = OutlineItem(title: "b1")
    let b2 = OutlineItem(title: "b2")

    // GIVEN: Thes items in the outline view
    let dataSource: OutlineViewDiffableDataSource = .init(outlineView: outlineView)
    var initialSnapshot = dataSource.snapshot()
    initialSnapshot.appendItems([a, b])
    initialSnapshot.appendItems([a1, b2, a3], into: a)
    initialSnapshot.appendItems([b1, a2], into: b)
    dataSource.applySnapshot(initialSnapshot, animatingDifferences: false)

    // WHEN: Items are moved
    var finalSnapshot = dataSource.snapshot()
    finalSnapshot.moveItem(a2, beforeItem: b2)
    finalSnapshot.moveItem(b2, afterItem: b1)

    // Wait while animation is completed
    let e = expectation(description: "Animation")
    dataSource.applySnapshot(finalSnapshot, animatingDifferences: true) {
      e.fulfill()
    }
    waitForExpectations(timeout: 0.5, handler: nil)

    // THEN: Outline view is updated
    outlineView.expandItem(nil, expandChildren: true)
    let expandedItems = (0 ..< outlineView.numberOfRows)
      .map(outlineView.item(atRow:)).compactMap { $0 as? OutlineItem }
    XCTAssertEqual(expandedItems.map(\.title), [a, a1, a2, a3, b, b1, b2].map(\.title))
  }
}
