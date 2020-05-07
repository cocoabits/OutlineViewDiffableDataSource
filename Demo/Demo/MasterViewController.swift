import AppKit
import SwiftUI
import OutlineViewDiffableDataSource

/// Sidebar contents.
final class MasterViewController: NSViewController {

  /// An outline view enclosed into the scroll view.
  private lazy var scrollableOutlineView: (scrollView: NSScrollView, outlineView: NSOutlineView) = {

    let outlineColumn = NSTableColumn()
    outlineColumn.resizingMask = .autoresizingMask
    outlineColumn.isEditable = false

    let outlineView = NSOutlineView()
    outlineView.headerView = nil
    outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
    outlineView.addTableColumn(outlineColumn)
    outlineView.outlineTableColumn = outlineColumn
    outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
    outlineView.focusRingType = .none
    outlineView.allowsMultipleSelection = true
    outlineView.usesAutomaticRowHeights = true
    outlineView.selectionHighlightStyle = .sourceList

    let scrollView = NSScrollView()
    scrollView.documentView = outlineView
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    return (scrollView, outlineView)
  }()

  /// Diffable data source similar to `NSCollectionViewDiffableDataSource`.
  private lazy var dataSource: OutlineViewDiffableDataSource<MasterItem> = .init(outlineView: scrollableOutlineView.outlineView)
}

// MARK: -

extension MasterViewController {

  /// Master is a container for the scroll view.
  override func loadView() {
    view = scrollableOutlineView.scrollView
  }
}

// MARK: - Internal API

extension MasterViewController {

  /// Read-write snapshot of the sidebar data.
  var snapshotBinding: Binding<DiffableDataSourceSnapshot<MasterItem>> {
    .init(get: { [dataSource] in
      dataSource.snapshot()
    }, set: { [dataSource] snapshot in
      let animate = UserDefaults.standard.bool(forKey: "ShouldAnimate")
      dataSource.applySnapshot(snapshot, animatingDifferences: animate)
    })
  }
}
