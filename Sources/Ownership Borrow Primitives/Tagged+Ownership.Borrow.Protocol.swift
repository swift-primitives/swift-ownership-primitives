public import Tagged_Primitives

extension Tagged: Ownership.Borrow.`Protocol`
where Underlying: Ownership.Borrow.`Protocol` & ~Copyable, Tag: ~Copyable & ~Escapable {

    public typealias Borrowed = Underlying.Borrowed
}
