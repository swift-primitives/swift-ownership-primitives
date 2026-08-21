public protocol __Ownership_Borrow_Protocol: ~Copyable, ~Escapable {
    associatedtype Borrowed: ~Copyable, ~Escapable = Ownership.Borrow<Self>
}
