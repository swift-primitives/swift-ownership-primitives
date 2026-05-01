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
struct `Ownership Mutable Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Mutable Tests`.Unit {
    @Test
    func `init(_:) stores the value`() {
        let mutable = Ownership.Mutable(42)
        #expect(mutable.value == 42)
    }

    @Test
    func `value accessor supports direct mutation`() {
        let mutable = Ownership.Mutable(0)
        mutable.value = 100
        #expect(mutable.value == 100)
    }

    @Test
    func `ARC sharing — mutations through one reference visible through another`() {
        let mutable = Ownership.Mutable(0)
        let alias = mutable
        alias.value = 50
        #expect(mutable.value == 50)
    }

    @Test
    func `value accessor supports read + transform`() {
        let mutable = Ownership.Mutable(7)
        let read = mutable.value + 1
        #expect(read == 8)
        #expect(mutable.value == 7)
    }

    @Test
    func `value accessor supports in-place mutation`() {
        let mutable = Ownership.Mutable(0)
        mutable.value = 99
        #expect(mutable.value == 99)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Mutable Tests`.`Edge Case` {
    @Test
    func `works with ~Copyable Value — transitive borrow read`() {
        struct Handle: ~Copyable { let fd: Int32 }
        let mutable = Ownership.Mutable(Handle(fd: 3))
        // transitive borrow through _read yield
        #expect(mutable.value.fd == 3)
    }

    @Test
    func `works with ~Copyable Value — in-place mutation via _modify`() {
        struct Counter: ~Copyable { var count: Int }
        let mutable = Ownership.Mutable(Counter(count: 0))
        mutable.value.count += 5
        #expect(mutable.value.count == 5)
    }
}

// MARK: - Integration Tests

extension `Ownership Mutable Tests`.Integration {
    @Test
    func `Unchecked opt-in wraps a Mutable and passes across Sendable`() async {
        let unchecked = Ownership.Mutable<Int>.Unchecked(0)
        unchecked.mutable.value = 42
        // The caller is asserting single-consumer access across the boundary.
        let read = await Task.detached { () -> Int in
            unchecked.mutable.value
        }.value
        #expect(read == 42)
    }
}
