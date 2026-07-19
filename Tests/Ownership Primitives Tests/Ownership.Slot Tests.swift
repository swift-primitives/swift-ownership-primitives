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
struct `Ownership Slot Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite struct Concurrency {}
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
    func `store(_:) on empty slot returns nil`() {
        let slot = Ownership.Slot<Int>()
        #expect(slot.store(42) == nil)
        #expect(slot.isFull)
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
    func `store(_:) on full slot bounces the value back`() {
        let slot = Ownership.Slot<Int>(1)
        if let returned = slot.store(2) {
            #expect(returned == 2)
            // Originally stored 1 is still there
            #expect(slot.take() == 1)
        } else {
            Issue.record("Expected bounce-back on a full slot")
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
            #expect(slot.store(value) == nil)
            #expect(slot.take() == value)
        }
    }
}

// MARK: - Integration Tests

extension `Ownership Slot Tests`.Integration {
    @Test
    func `works with struct Value types`() {
        struct Pair: Equatable {
            var a: Int
            var b: Int
        }
        let slot = Ownership.Slot<Pair>()
        slot.move.in(Pair(a: 1, b: 2))
        #expect(slot.take() == Pair(a: 1, b: 2))
    }

    @Test
    func `works with class Value types`() {
        // Ad hoc box fixture is structural: this package owns the
        // Reference/Owned wrappers the rule recommends, so using them
        // here would be circular (testing wrappers using the wrappers).
        // swift-linter:disable:next ad hoc box class
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
        (1...100).forEach { i in
            slot.move.in(i)
            total += slot.move.out
        }
        #expect(total == 100 * 101 / 2)
    }

    @Test
    func `isEmpty / isFull work with ~Copyable Value`() {
        struct Handle: ~Copyable { let fd: Int32 }
        let slot = Ownership.Slot<Handle>()
        let empty = slot.isEmpty
        let full = slot.isFull
        #expect(empty)
        #expect(!full)
        slot.move.in(Handle(fd: 11))
        let emptyAfterStore = slot.isEmpty
        let fullAfterStore = slot.isFull
        #expect(!emptyAfterStore)
        #expect(fullAfterStore)
        _ = slot.take()
    }
}

// MARK: - Concurrency Tests
//
// Regression coverage for F-001 (fable-448): take() used to publish State.empty
// via CAS full -> empty BEFORE vacating storage, leaving a window in which a
// concurrent store() could observe the slot as empty and call
// _storage.initialize(to:) while take()'s own _storage.move() was still
// reading the same memory — an unsynchronized concurrent read/write of the
// same storage cell. take() is now symmetric with store(): it reserves via
// CAS full -> draining, vacates storage, and only then publishes empty.

extension `Ownership Slot Tests`.Concurrency {
    @Test
    func `concurrent single-producer single-consumer store take never loses or duplicates a value`() async {
        let slot = Ownership.Slot<Int>()
        let iterations = 200_000

        let consumed = await withTaskGroup(of: [Int].self) { group in
            group.addTask {
                var next = 1
                var produced = 0
                while produced < iterations {
                    if slot.store(next) == nil {
                        next += 1
                        produced += 1
                    }
                }
                return []
            }
            group.addTask {
                var taken: [Int] = []
                taken.reserveCapacity(iterations)
                while taken.count < iterations {
                    if let value = slot.take() {
                        taken.append(value)
                    }
                }
                return taken
            }
            var result: [Int] = []
            for await partial in group where !partial.isEmpty {
                result = partial
            }
            return result
        }

        // Pre-fix, the take()/store() race could hand the consumer the
        // producer's next value early (and then again on the following take
        // once the producer's real publish lands) — duplicates and gaps in
        // the observed sequence. Post-fix, the SPSC hand-off is exact.
        #expect(consumed.count == iterations)
        #expect(consumed == Array(1...iterations))
    }
}

