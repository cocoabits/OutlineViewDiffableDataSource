/// Diffable requirement.
public protocol Diffable {

  /// A type representing the stable identity of the entity associated with `self`.
  associatedtype ID : Hashable

  /// The stable identity of the entity associated with `self`.
  var id: Self.ID { get }

  /// Return true to hide the expansion arrow.
  var isLeaf: Bool { get }
}

// MARK: -

public extension Diffable {

  /// Expand all by default.
  var isLeaf: Bool {
    false
  }
}
