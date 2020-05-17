import Foundation
import OutlineViewDiffableDataSource

extension DiffableDataSourceSnapshot {

  /// Appends items from the text view.
  mutating func fillItem(_ selectedItem: Item?, with string: String) {
    let lines = string.components(separatedBy: .newlines)
    for line in lines {
      let titles = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false }
      switch titles.count {
      case 1:
        let groupItem = GroupOutlineViewItem(id: titles[0], title: titles[0])
        let masterItem = MasterOutlineViewItem(title: titles[0])
        if containsItem(groupItem) == false, containsItem(masterItem) == false {
          if selectedItem == nil {
            appendItems([groupItem])
          } else {
            appendItems([masterItem], into: selectedItem)
          }
        }
      case 2:
        let parentGroupItem = GroupOutlineViewItem(id: titles[0], title: titles[0])
        let parentMasterItem = MasterOutlineViewItem(title: titles[0])
        var parentItem: NSObject?
        if containsItem(parentGroupItem) == false, containsItem(parentMasterItem) == false {
          if selectedItem == nil {
            appendItems([parentGroupItem])
            parentItem = parentGroupItem

          } else {
            appendItems([parentMasterItem], into: selectedItem)
            parentItem = parentMasterItem
          }
        } else if containsItem(parentGroupItem) {
          parentItem = parentGroupItem
        } else if containsItem(parentMasterItem) {
          parentItem = parentMasterItem
        }
        let childItem = MasterOutlineViewItem(title: titles[1])
        if containsItem(childItem) == false {
          appendItems([childItem], into: parentItem)
        }
      default:
        continue
      }
    }
  }
}
