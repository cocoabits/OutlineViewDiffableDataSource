import AppKit
import SwiftUI
import OutlineViewDiffableDataSource

/// Master-detail view controller with a sidebar and editor.
final class MainViewController: NSViewController {

  /// Master view controller with an outline view.
  private lazy var masterViewController: MasterViewController = .init()

  /// Detail view controller with tab views for current selection.
  private lazy var detailViewController: DetailViewController = .init(snapshotBinding: masterViewController.snapshotBinding)

  /// Master-detail split view.
  private lazy var splitViewController: NSSplitViewController = {
    let masterItem = NSSplitViewItem(sidebarWithViewController: masterViewController)
    masterItem.minimumThickness = 220
    masterItem.canCollapse = false
    let viewController = NSSplitViewController()
    viewController.splitViewItems = [masterItem, .init(contentListWithViewController: detailViewController)]
    return viewController
  }()
}

// MARK: -

extension MainViewController {

  /// This is a container for the master-detail interface.
  override func loadView() {
    view = splitViewController.view
    addChild(splitViewController)
  }

  /// Configures selection handling.
  override func viewDidLoad() {
    super.viewDidLoad()

    title = ProcessInfo.processInfo.processName
  }

  override func viewWillAppear() {
    super.viewWillAppear()

    splitViewController.splitView.autosaveName = "MasterDetail"
  }
}
