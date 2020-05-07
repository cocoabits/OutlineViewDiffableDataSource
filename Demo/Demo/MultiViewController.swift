import AppKit
import SwiftUI
import OutlineViewDiffableDataSource

/// Editor for the multiple selected items in the sidebar.
final class MultiViewController: NSViewController {

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
    stackView.addView(NSButton(title: "Remove Selected Items", target: self, action: #selector(removeSelectedItems(_:))), in: .center)
    stackView.setHuggingPriority(.fittingSizeCompression, for: .horizontal)
    view = stackView
  }
}

// MARK: - Actions

private extension MultiViewController {

  /// Removes selected items.
  @IBAction func removeSelectedItems(_ sender: Any?) {
    guard let selectedItems = representedObject as? [MasterItem] else { return }
    var snapshot = snapshotBinding.wrappedValue
    snapshot.deleteItems(selectedItems)
    snapshotBinding.wrappedValue = snapshot
  }
}
