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
struct `Ownership Inout Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Inout Tests`.Unit {
    @Test
    func `init(mutating:) writes reach the source`() {
        var source = 0
        func write100(_ value: inout Int) {
            let ref = Ownership.Inout(mutating: &value)
            ref.value = 100
        }
        write100(&source)
        #expect(source == 100)
    }

    @Test
    func `init(_:) from typed pointer writes through`() {
        var source = 0
        unsafe withUnsafeMutablePointer(to: &source) { pointer in
            let ref = unsafe Ownership.Inout(pointer)
            ref.value = 200
        }
        #expect(source == 200)
    }

    @Test
    func `value get returns current source value (Copyable Value)`() {
        var source = 42
        func read(_ value: inout Int) -> Int {
            let ref = Ownership.Inout(mutating: &value)
            return ref.value
        }
        #expect(read(&source) == 42)
    }

    @Test
    func `nonmutating _modify preserves interior mutability`() {
        var source = 10
        func addOne(_ value: inout Int) {
            let ref = Ownership.Inout(mutating: &value)
            // `ref` is `let`-bound but `.value` has `nonmutating _modify`
            // per [IMPL-071] — mutation goes through the pointee.
            ref.value += 1
        }
        addOne(&source)
        #expect(source == 11)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Inout Tests`.`Edge Case` {
    @Test
    func `V12 — Copyable Value uses get + _modify (pure read works)`() {
        struct Counter { var count: Int }
        var source = Counter(count: 5)
        func incrementViaRead(_ value: inout Counter) {
            let ref = Ownership.Inout(mutating: &value)
            // Pure read through `get` — returns a copy, no compound lifetime.
            let current = ref.value.count
            ref.value = Counter(count: current + 1)
        }
        incrementViaRead(&source)
        #expect(source.count == 6)
    }

    @Test
    func `V12 — ~Copyable Value uses _read + _modify`() {
        struct Payload: ~Copyable { var value: Int }
        var source = Payload(value: 5)
        func bump(_ value: inout Payload) {
            let ref = Ownership.Inout(mutating: &value)
            // `_read` path yields the payload; mutation routes through `_modify`.
            let snapshot = ref.value.value
            ref.value = Payload(value: snapshot + 2)
        }
        bump(&source)
        #expect(source.value == 7)
    }

    @Test
    func `V12 — nested method-call mutation writes back (CoW preserving)`() {
        struct Holder {
            var values: [Int] = []
            mutating func append(_ x: Int) { values.append(x) }
        }
        var source = Holder()
        func appendTwo(_ value: inout Holder) {
            let ref = Ownership.Inout(mutating: &value)
            // Nested method-call on a mutating method. A get + set split
            // would silently discard; _modify routes through the pointer.
            ref.value.append(1)
            ref.value.append(2)
        }
        appendTwo(&source)
        #expect(source.values == [1, 2])
    }

    @Test
    func `reference-type payload mutates in place`() {
        final class Counter {
            var count: Int
            init(_ count: Int) { self.count = count }
        }
        var source = Counter(0)
        func writeFive(_ value: inout Counter) {
            let ref = Ownership.Inout(mutating: &value)
            ref.value.count = 5
        }
        writeFive(&source)
        #expect(source.count == 5)
    }
}

// MARK: - Integration Tests

extension `Ownership Inout Tests`.Integration {
    @Test
    func `round-trip — source value survives a write-then-read`() {
        var source = 0
        func writeThenRead(_ value: inout Int) -> Int {
            let ref = Ownership.Inout(mutating: &value)
            ref.value = 77
            return ref.value
        }
        #expect(writeThenRead(&source) == 77)
        #expect(source == 77)
    }

    @Test
    func `multiple writes through Inout accumulate on the source`() {
        var source = 0
        func incrementThreeTimes(_ value: inout Int) {
            let ref = Ownership.Inout(mutating: &value)
            ref.value += 1
            ref.value += 1
            ref.value += 1
        }
        incrementThreeTimes(&source)
        #expect(source == 3)
    }
}
