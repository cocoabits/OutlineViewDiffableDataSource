import OutlineViewDiffableDataSource

extension DiffableDataSourceSnapshot {

  /// Appends items from the text view.
  mutating func fillItem(_ selectedItem: Item?, with string: String) {
    let lines = string.components(separatedBy: .newlines)
    for line in lines {
      let titles = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false }
      switch titles.count {
      case 1:
        let groupItem: AnyObject = selectedItem == nil ? GroupOutlineViewItem(id: titles[0], title: titles[0]) : MasterItem(title: titles[0])
        if containsItem(groupItem) == false {
          appendItems([groupItem], into: selectedItem)
        }
      case 2:
        let parentItem: AnyObject = selectedItem == nil ? GroupOutlineViewItem(id: titles[0], title: titles[0]) : MasterItem(title: titles[0])
        if containsItem(parentItem) == false {
          appendItems([parentItem], into: selectedItem)
        }
        let childItem = MasterItem(title: titles[1])
        if containsItem(childItem) == false {
          appendItems([childItem], into: parentItem)
        }
      default:
        continue
      }
    }
  }
}
