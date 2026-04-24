import Testing
import Ownership_Primitives
import Tagged_Primitives

// MARK: - Tagged+Ownership.Borrow.`Protocol` conformance

@Suite("Tagged+Ownership.Borrow.Protocol")
struct TaggedOwnershipBorrowProtocolTests {
    @Suite struct Unit {}
}

private enum TestTag {}

extension TaggedOwnershipBorrowProtocolTests.Unit {
    @Test
    func `Tagged conforms to Ownership Borrow Protocol when RawValue does`() {
        // Compile-time assertion: Tagged<Tag, Resource> conforms when
        // Resource conforms. If this test compiles, the conformance holds.
        // Tagged.Borrowed == RawValue.Borrowed is established by the
        // typealias in Tagged+Ownership.Borrow.Protocol.swift and is
        // verified structurally by successful conformance checking here.
        struct Resource: ~Copyable, Ownership.Borrow.`Protocol` {
            typealias Borrowed = Ownership.Borrow<Resource>
        }
        func _requireBorrowProtocol<T: Ownership.Borrow.`Protocol` & ~Copyable>(_: T.Type) {}
        _requireBorrowProtocol(Tagged<TestTag, Resource>.self)
        #expect(Bool(true))
    }
}
