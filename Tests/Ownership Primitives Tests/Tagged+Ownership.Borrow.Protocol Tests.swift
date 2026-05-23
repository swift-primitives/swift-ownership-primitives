import Ownership_Primitives
import Tagged_Primitives
import Testing

// MARK: - Tagged+Ownership.Borrow.`Protocol` conformance

@Suite
struct `Tagged+Ownership.Borrow.Protocol Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

private enum Phantom {}

extension `Tagged+Ownership.Borrow.Protocol Tests`.Unit {
    @Test
    func `Tagged conforms to Ownership Borrow Protocol when Underlying does`() {
        // Compile-time assertion: Tagged<Tag, Resource> conforms when
        // Resource conforms. If this test compiles, the conformance holds.
        // Tagged.Borrowed == Underlying.Borrowed is established by the
        // typealias in Tagged+Ownership.Borrow.Protocol.swift and is
        // verified structurally by successful conformance checking here.
        struct Resource: ~Copyable, Ownership.Borrow.`Protocol` {
            // swift-linter:disable:next minimal type body
            typealias Borrowed = Ownership.Borrow<Self>
        }
        func _requireBorrowProtocol<T: Ownership.Borrow.`Protocol` & ~Copyable>(_: T.Type) {}
        _requireBorrowProtocol(Tagged<Phantom, Resource>.self)
        #expect(Bool(true))
    }
}
