import AppKit
import Combine
import SwiftUI
import OutlineViewDiffableDataSource

/// Tab view with editors for different types of selection.
final class DetailViewController: NSViewController {

  /// An editor for the empty outline view selection.
  private let emptyViewController: EmptyViewController

  /// An editor for the single outline view item.
  private let singleViewController: SingleViewController

  /// An editor for multiple outline view items.
  private let multiViewController: MultiViewController

  /// Used to switch between different items.
  private lazy var tabViewController: NSTabViewController = {
    let viewController = NSTabViewController()
    viewController.tabStyle = .unspecified
    viewController.transitionOptions = []
    viewController.tabViewItems = [emptyViewController, singleViewController, multiViewController]
      .map(NSTabViewItem.init(viewController:))
    return viewController
  }()

  /// The bottom checkbox which animates changes.
  private lazy var animationCheckbox: (button: NSButton, unbind: AnyCancellable) = {
    let checkbox = NSButton(checkboxWithTitle: "Animate Changes", target: nil, action: nil)
    checkbox.bind(.value, to: NSUserDefaultsController.shared, withKeyPath: "values.ShouldAnimate", options: nil)
    return (checkbox, .init { checkbox.unbind(.value) })
  }()

  /// Creates a new container for editing sidebar contents.
  init(snapshotBinding: Binding<DiffableDataSourceSnapshot>) {
    self.emptyViewController = .init(binding: snapshotBinding)
    self.singleViewController = .init(binding: snapshotBinding)
    self.multiViewController = .init(binding: snapshotBinding)

    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable, message: "IB is denied")
  required init?(coder: NSCoder) {
    fatalError()
  }
}

// MARK: -

extension DetailViewController {

  /// This is a container for the tab view.
  override func loadView() {

    let separator = NSBox()
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.boxType = .separator
    separator.heightAnchor.constraint(equalToConstant: 20).isActive = true

    let stackView = NSStackView()
    stackView.edgeInsets = .init(top: 20, left: 20, bottom: 20, right: 20)
    stackView.orientation = .vertical
    stackView.distribution = .fill
    stackView.addView(tabViewController.view, in: .center)
    stackView.addView(separator, in: .center)
    stackView.addView(animationCheckbox.button, in: .center)

    view = stackView
    addChild(tabViewController)
  }

  /// Switches to the correct tab depending on the current selection.
  override func viewDidLoad() {
    super.viewDidLoad()

    updateContents()
  }

  /// Switches to the correct tab depending on the current selection.
  override var representedObject: Any? {
    didSet {
      updateContents()
    }
  }
}

// MARK: - Private API

private extension DetailViewController {

  /// View controller represented by the selected tab.
  var selectedViewController: NSViewController? {
    get {
      tabViewController.tabViewItems[tabViewController.selectedTabViewItemIndex].viewController
    }
    set {
      let selectedIndex = tabViewController.tabViewItems.firstIndex { $0.viewController == newValue }
      tabViewController.selectedTabViewItemIndex = selectedIndex ?? 0
    }
  }

  /// Switches to the tab and assigns its represented object.
  func updateContents() {
    guard isViewLoaded else { return }

    guard let selection = representedObject as? [MasterOutlineViewItem], selection.isEmpty == false else {
      selectedViewController = emptyViewController
      return
    }
    if selection.count == 1 {
      singleViewController.representedObject = selection[0]
      selectedViewController = singleViewController
    } else {
      multiViewController.representedObject = selection
      selectedViewController = multiViewController
    }
  }
}
