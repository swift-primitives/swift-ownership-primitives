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
struct `Ownership Slot Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Slot Tests`.Unit {
    @Test
    func `init() creates an empty slot`() {
        let slot = Ownership.Slot<Int>()
        #expect(slot.isEmpty)
        #expect(!slot.isFull)
    }

    @Test
    func `init(_:) creates a full slot`() {
        let slot = Ownership.Slot<Int>(42)
        #expect(slot.isFull)
        #expect(!slot.isEmpty)
    }

    @Test
    func `store(_:) on empty slot returns .stored`() {
        let slot = Ownership.Slot<Int>()
        switch slot.store(42) {
        case .stored:
            #expect(slot.isFull)
        case .occupied:
            Issue.record("Expected .stored on an empty slot")
        }
    }

    @Test
    func `take() on full slot returns the stored value`() {
        let slot = Ownership.Slot<Int>(17)
        let taken = slot.take()
        #expect(taken == 17)
        #expect(slot.isEmpty)
    }

    @Test
    func `take() on empty slot returns nil`() {
        let slot = Ownership.Slot<Int>()
        #expect(slot.take() == nil)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Slot Tests`.`Edge Case` {
    @Test
    func `store(_:) on full slot returns .occupied with value back`() {
        let slot = Ownership.Slot<Int>(1)
        switch slot.store(2) {
        case .stored:
            Issue.record("Expected .occupied on a full slot")
        case .occupied(let returned):
            #expect(returned == 2)
            // Originally stored 1 is still there
            #expect(slot.take() == 1)
        }
    }

    @Test
    func `move.in(_) then move.out round-trips`() {
        let slot = Ownership.Slot<Int>()
        slot.move.in(99)
        #expect(slot.isFull)
        let taken = slot.move.out
        #expect(taken == 99)
        #expect(slot.isEmpty)
    }

    @Test
    func `store then take cycle leaves slot reusable`() {
        let slot = Ownership.Slot<Int>()
        for value in [1, 2, 3, 4] {
            switch slot.store(value) {
            case .stored: break
            case .occupied: Issue.record("Expected reusable empty state")
            }
            #expect(slot.take() == value)
        }
    }
}

// MARK: - Integration Tests

extension `Ownership Slot Tests`.Integration {
    @Test
    func `works with struct Value types`() {
        struct Pair: Equatable { var a: Int; var b: Int }
        let slot = Ownership.Slot<Pair>()
        slot.move.in(Pair(a: 1, b: 2))
        #expect(slot.take() == Pair(a: 1, b: 2))
    }

    @Test
    func `works with class Value types`() {
        final class Box {
            let id: Int
            init(_ id: Int) { self.id = id }
        }
        let slot = Ownership.Slot<Box>()
        slot.move.in(Box(7))
        let taken = slot.take()
        #expect(taken?.id == 7)
    }

    @Test
    func `slot is reusable across many store/take cycles`() {
        let slot = Ownership.Slot<Int>()
        var total = 0
        for i in 1...100 {
            slot.move.in(i)
            total += slot.move.out
        }
        #expect(total == 100 * 101 / 2)
    }
}
