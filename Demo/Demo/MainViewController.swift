import AppKit
import Combine
import SwiftUI
import OutlineViewDiffableDataSource

/// Master-detail view controller with a sidebar and editor.
final class MainViewController: NSViewController {

  /// Master view controller with an outline view.
  private lazy var masterViewController: MasterViewController = .init()

  /// Detail view controller with tab views for current selection.
  private lazy var detailViewController: DetailViewController =
    .init(snapshotBinding: masterViewController.snapshotBinding)

  /// Storage for cancellables.
  var subscriptions: Set<AnyCancellable> = []

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
    view.frame.size = NSMakeSize(640, 480)

    masterViewController.selectionPublisher.sink { [detailViewController] in
      detailViewController.representedObject = $0
    }
    .store(in: &subscriptions)
  }

  /// Setup auto-save configuration when the view is laid out.
  override func viewWillAppear() {
    super.viewWillAppear()

    splitViewController.splitView.autosaveName = "MasterDetail"
  }
}
