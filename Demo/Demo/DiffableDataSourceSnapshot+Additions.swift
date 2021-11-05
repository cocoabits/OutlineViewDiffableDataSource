import Foundation
import OutlineViewDiffableDataSource

extension DiffableDataSourceSnapshot {
  
  /// Appends items from the text view.
  mutating func fillItem(_ selectedItem: Item?, with string: String) {
    let lines = string.components(separatedBy: .newlines)
    
    for line in lines {
      // Each line should have a "parent (/ child)?". Since this is a free-form text field, we need to find
      // existing items in the side bar
      let titles = line.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false }
      
      guard !titles.isEmpty else { continue }
      
      // Use title as the unique ID in this case
      let rootItem = getItemForID(titles[0]) ?? MasterGroupOutlineViewItem(id: titles[0], title: titles[0])
      let sideBarItem = getItemForID(titles[0]) ?? MasterOutlineViewItem(id: titles[0], title: titles[0])
      
      let foundRootItem = containsItem(rootItem)
      let foundSidebarItem = containsItem(sideBarItem)
      
      switch titles.count {
        case 1:
          // No child specified
          if foundRootItem == false, foundSidebarItem == false {
            if let selectedItem = selectedItem {
              appendItems([sideBarItem], into: selectedItem)
            }
            else {
              appendItems([rootItem], into: nil)
            }
          }
        case 2:
          let childItemToAdd = MasterOutlineViewItem(id: titles[1], title: titles[1])
          
          if containsItem(childItemToAdd) == false {
            // Parent / Child specified. Find
            var parentItemToUse: OutlineViewItem?
            
            if foundRootItem == false, foundSidebarItem == false {
              if selectedItem == nil {
                appendItems([rootItem])
                parentItemToUse = rootItem
                
              } else {
                appendItems([sideBarItem], into: selectedItem)
                parentItemToUse = sideBarItem
              }
            } else if foundRootItem {
              parentItemToUse = rootItem
            } else if foundSidebarItem {
              parentItemToUse = sideBarItem
            }
            
            appendItems([childItemToAdd], into: parentItemToUse)
          }
        default:
          continue
      }
    }
  }
}
