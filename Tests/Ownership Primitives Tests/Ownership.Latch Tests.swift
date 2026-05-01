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
struct `Ownership Latch Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Latch Tests`.Unit {
    @Test
    func `init() creates an empty latch`() {
        let latch = Ownership.Latch<Int>()
        #expect(!latch.hasValue)
    }

    @Test
    func `init(_:) creates a full latch`() {
        let latch = Ownership.Latch<Int>(42)
        #expect(latch.hasValue)
    }

    @Test
    func `store(_:) publishes the value`() {
        let latch = Ownership.Latch<Int>()
        latch.store(42)
        #expect(latch.hasValue)
    }

    @Test
    func `take() returns the stored value and empties the latch`() {
        let latch = Ownership.Latch<Int>(17)
        let taken = latch.take()
        #expect(taken == 17)
        #expect(!latch.hasValue)
    }

    @Test
    func `takeIfPresent() returns nil on an empty latch`() {
        let latch = Ownership.Latch<Int>()
        #expect(latch.takeIfPresent() == nil)
    }

    @Test
    func `takeIfPresent() returns the stored value when full`() {
        let latch = Ownership.Latch<Int>(99)
        #expect(latch.takeIfPresent() == 99)
        #expect(!latch.hasValue)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Latch Tests`.`Edge Case` {
    @Test
    func `takeIfPresent() after take() returns nil`() {
        let latch = Ownership.Latch<Int>(3)
        #expect(latch.take() == 3)
        #expect(latch.takeIfPresent() == nil)
    }

    @Test
    func `store then take round-trips a struct Value`() {
        struct Payload: Equatable { var a: Int; var b: Int }
        let latch = Ownership.Latch<Payload>()
        latch.store(Payload(a: 1, b: 2))
        #expect(latch.take() == Payload(a: 1, b: 2))
    }

    @Test
    func `hasValue is false for a fresh empty latch`() {
        let latch = Ownership.Latch<String>()
        #expect(!latch.hasValue)
    }

    @Test
    func `hasValue is true only until take() consumes the value`() {
        let latch = Ownership.Latch<String>("payload")
        #expect(latch.hasValue)
        _ = latch.take()
        #expect(!latch.hasValue)
    }
}

// MARK: - Integration Tests

extension `Ownership Latch Tests`.Integration {
    @Test
    func `latch carries a class reference identity across take`() {
        final class Marker { let tag: Int; init(_ tag: Int) { self.tag = tag } }
        let original = Marker(7)
        let latch = Ownership.Latch<Marker>(original)
        let received = latch.take()
        #expect(received === original)
    }

    @Test
    func `latch works with ~Copyable Value`() {
        struct Handle: ~Copyable { let fd: Int32 }
        let latch = Ownership.Latch<Handle>()
        #expect(!latch.hasValue)
        latch.store(Handle(fd: 11))
        #expect(latch.hasValue)
        let handle = latch.take()
        #expect(handle.fd == 11)
        #expect(!latch.hasValue)
    }

    @Test
    func `shared latch delivers to a single consumer across captures`() {
        let latch = Ownership.Latch<Int>()
        // ARC sharing: multiple strong references, one store, one take.
        let alias = latch
        latch.store(123)
        #expect(alias.hasValue)
        #expect(alias.take() == 123)
        #expect(!latch.hasValue)
    }
}
