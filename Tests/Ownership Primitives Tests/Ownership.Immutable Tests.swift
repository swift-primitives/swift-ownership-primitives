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

import Ownership_Primitives
import Testing

@Suite
struct `Ownership Immutable Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Immutable Tests`.Unit {
    @Test
    func `init(_:) stores the value`() {
        let immutable = Ownership.Immutable(42)
        #expect(immutable.value == 42)
    }

    @Test
    func `value is immutable — repeated reads return the same value`() {
        let immutable = Ownership.Immutable("hello")
        #expect(immutable.value == "hello")
        #expect(immutable.value == "hello")
    }

    @Test
    func `ARC sharing — multiple references see same identity`() {
        let immutable = Ownership.Immutable(7)
        let alias = immutable  // Immutable is a reference type; both point at same heap cell
        #expect(immutable === alias)
        #expect(alias.value == 7)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Immutable Tests`.`Edge Case` {
    @Test
    func `works with struct types`() {
        struct Point: Equatable, Sendable {
            var x: Int
            var y: Int
        }
        let immutable = Ownership.Immutable(Point(x: 3, y: 4))
        #expect(immutable.value == Point(x: 3, y: 4))
    }

    @Test
    func `works with class types`() {
        final class Node: Sendable {
            let id: Int
            init(_ id: Int) { self.id = id }
        }
        let immutable = Ownership.Immutable(Node(1))
        #expect(immutable.value.id == 1)
    }
}

// MARK: - Integration Tests

extension `Ownership Immutable Tests`.Integration {
    @Test
    func `Sendable — can pass across an async boundary`() async {
        let immutable = Ownership.Immutable(99)
        let captured = await Task.detached { () -> Int in
            immutable.value
        }.value
        #expect(captured == 99)
    }
}
