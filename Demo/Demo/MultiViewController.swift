import AppKit
import SwiftUI
import OutlineViewDiffableDataSource

/// Editor for the multiple selected items in the sidebar.
final class MultiViewController: NSViewController {

  /// Temporary label for the title.
  private lazy var label: NSTextField = .init(labelWithString: "Multi")

  /// Sidebar data source.
  private let snapshotBinding: Binding<DiffableDataSourceSnapshot<MasterItem>>

  /// Creates a new editor for a multiple sidebar items.
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

extension MultiViewController {

  /// Creates a vertical stack of controls.
  override func loadView() {
    let stackView = NSStackView()
    stackView.orientation = .vertical
    stackView.addView(label, in: .center)
    view = stackView
  }
}
