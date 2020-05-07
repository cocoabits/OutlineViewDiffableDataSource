import AppKit
import SwiftUI
import OutlineViewDiffableDataSource

/// Editor for the single selected item in the sidebar.
final class SingleViewController: NSViewController {

  /// Temporary label for the title.
  private lazy var label: NSTextField = .init(labelWithString: "Single")

  /// Sidebar data source.
  private let snapshotBinding: Binding<DiffableDataSourceSnapshot<MasterItem>>

  /// Creates a new editor for a single sidebar item.
  init(binding: Binding<DiffableDataSourceSnapshot<MasterItem>>) {
    self.snapshotBinding = binding

    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable, message: "IB is denied")
  required init?(coder: NSCoder) {
    fatalError()
  }
}

// MARK: -

extension SingleViewController {

  /// Creates a vertical stack of controls.
  override func loadView() {
    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.addView(label, in: .center)
    view = stackView
  }
}
