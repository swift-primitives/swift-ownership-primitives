// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
import Ownership_Primitives

@Suite
struct `Optional Take Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Optional Take Tests`.Unit {
    @Test
    func `take() on Some returns the wrapped value and leaves nil`() {
        var slot: Int? = 42
        let taken = slot.take()
        #expect(taken == 42)
        #expect(slot == nil)
    }

    @Test
    func `take() on nil returns nil and leaves nil`() {
        var slot: Int? = nil
        let taken = slot.take()
        #expect(taken == nil)
        #expect(slot == nil)
    }

    @Test
    func `two successive takes — first returns value, second returns nil`() {
        var slot: Int? = 5
        #expect(slot.take() == 5)
        #expect(slot.take() == nil)
    }
}

// MARK: - Edge Case Tests

extension `Optional Take Tests`.`Edge Case` {
    @Test
    func `take() on Optional<~Copyable> moves the value out`() {
        struct Handle: ~Copyable {
            let id: Int
        }
        var slot: Handle? = Handle(id: 7)
        guard let handle = slot.take() else {
            Issue.record("Expected a Handle")
            return
        }
        #expect(handle.id == 7)
        // After take(): the slot is nil; cannot assert via equality because
        // Handle is ~Copyable — use the none-check shape that doesn't copy.
        if case .some = slot {
            Issue.record("Expected slot to be nil after take()")
        }
    }

    @Test
    func `take() works with struct Copyable Wrapped`() {
        struct Pair: Equatable { var a: Int; var b: Int }
        var slot: Pair? = Pair(a: 1, b: 2)
        #expect(slot.take() == Pair(a: 1, b: 2))
        #expect(slot == nil)
    }

    @Test
    func `take() works with class Wrapped`() {
        final class Box { let v: Int; init(_ v: Int) { self.v = v } }
        var slot: Box? = Box(9)
        let taken = slot.take()
        #expect(taken?.v == 9)
        #expect(slot == nil)
    }
}

// MARK: - Integration Tests

extension `Optional Take Tests`.Integration {
    @Test
    func `take() idiom — guard-let + early return`() {
        struct Resource: ~Copyable { let fd: Int32 }
        var slot: Resource? = Resource(fd: 3)

        func consume(_ slot: inout Resource?) -> Int32 {
            guard let resource = slot.take() else { return -1 }
            return resource.fd
        }

        #expect(consume(&slot) == 3)
        #expect(consume(&slot) == -1)   // second consume sees nil
    }

    @Test
    func `take() lets a ~Copyable stored property be consumed from within a method`() {
        struct Owner: ~Copyable {
            var resource: Resource?
            mutating func releaseResource() -> Resource? {
                return resource.take()
            }
        }
        struct Resource: ~Copyable { let id: Int }

        var owner = Owner(resource: Resource(id: 42))
        guard let resource = owner.releaseResource() else {
            Issue.record("Expected a Resource")
            return
        }
        #expect(resource.id == 42)
        // `owner.resource` is now nil; cannot equality-compare ~Copyable Optional.
        if case .some = owner.resource {
            Issue.record("Expected owner.resource to be nil after releaseResource")
        }
    }
}
