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
struct `Ownership Indirect Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Indirect Tests`.Unit {
    @Test
    func `init(_:) stores the value`() {
        let indirect = Ownership.Indirect<Int>(42)
        #expect(indirect.value == 42)
    }

    @Test
    func `value _modify mutates through exclusive access`() {
        var indirect = Ownership.Indirect<Int>(10)
        indirect.value += 1
        #expect(indirect.value == 11)
    }

    @Test
    func `clone() produces an independent cell`() {
        let original = Ownership.Indirect<Int>(7)
        var copy = original.clone()
        copy.value = 99
        #expect(original.value == 7)
        #expect(copy.value == 99)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Indirect Tests`.`Edge Case` {
    @Test
    func `shared cell CoW — mutation on copy leaves original untouched`() {
        var a = Ownership.Indirect<[Int]>([1, 2, 3])
        var b = a
        b.value.append(4)
        #expect(a.value == [1, 2, 3])
        #expect(b.value == [1, 2, 3, 4])
    }

    @Test
    func `cloning an unshared cell produces a distinct cell`() {
        let a = Ownership.Indirect<String>("payload")
        var b = a.clone()
        b.value = "mutated"
        #expect(a.value == "payload")
        #expect(b.value == "mutated")
    }

    @Test
    func `mutating through the original after sharing then diverging`() {
        var a = Ownership.Indirect<Int>(0)
        var b = a
        a.value = 5
        #expect(a.value == 5)
        #expect(b.value == 0)
        b.value = 9
        #expect(a.value == 5)
        #expect(b.value == 9)
    }
}

// MARK: - Integration Tests

extension `Ownership Indirect Tests`.Integration {
    @Test
    func `struct Value round-trips through CoW`() {
        struct Pair: Equatable { var a: Int; var b: Int }
        var x = Ownership.Indirect<Pair>(Pair(a: 1, b: 2))
        var y = x
        y.value.a = 99
        #expect(x.value == Pair(a: 1, b: 2))
        #expect(y.value == Pair(a: 99, b: 2))
    }

    @Test
    func `nested Indirect preserves value semantics at both levels`() {
        var outer = Ownership.Indirect<Ownership.Indirect<Int>>(Ownership.Indirect<Int>(1))
        var sibling = outer
        sibling.value.value = 42
        #expect(outer.value.value == 1)
        #expect(sibling.value.value == 42)
    }

    @Test
    func `clone() of a shared cell detaches without a prior _modify trigger`() {
        let a = Ownership.Indirect<Int>(8)
        let _ = a
        let b = a.clone()
        #expect(a.value == 8)
        #expect(b.value == 8)
    }
}
