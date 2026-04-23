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
struct `Ownership Shared Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Shared Tests`.Unit {
    @Test
    func `init(_:) stores the value`() {
        let shared = Ownership.Shared(42)
        #expect(shared.value == 42)
    }

    @Test
    func `value is immutable — repeated reads return the same value`() {
        let shared = Ownership.Shared("hello")
        #expect(shared.value == "hello")
        #expect(shared.value == "hello")
    }

    @Test
    func `ARC sharing — multiple references see same identity`() {
        let shared = Ownership.Shared(7)
        let alias = shared  // Shared is a reference type; both point at same heap cell
        #expect(shared === alias)
        #expect(alias.value == 7)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Shared Tests`.`Edge Case` {
    @Test
    func `works with struct types`() {
        struct Point: Equatable, Sendable { var x: Int; var y: Int }
        let shared = Ownership.Shared(Point(x: 3, y: 4))
        #expect(shared.value == Point(x: 3, y: 4))
    }

    @Test
    func `works with class types`() {
        final class Node: Sendable { let id: Int; init(_ id: Int) { self.id = id } }
        let shared = Ownership.Shared(Node(1))
        #expect(shared.value.id == 1)
    }
}

// MARK: - Integration Tests

extension `Ownership Shared Tests`.Integration {
    @Test
    func `Sendable — can pass across an async boundary`() async {
        let shared = Ownership.Shared(99)
        let captured = await Task.detached { () -> Int in
            shared.value
        }.value
        #expect(captured == 99)
    }
}
