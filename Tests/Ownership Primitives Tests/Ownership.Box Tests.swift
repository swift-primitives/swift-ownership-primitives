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

// Note: `isUnique` (mutating get) and `ensureUnique()` (mutating) are bound to locals before
// `#expect(...)` — the macro evaluates its argument through an immutable closure capture, which
// cannot call mutating members (and cannot capture a `~Copyable` `Box` at all).

@Suite
struct `Ownership Box Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite struct `Move Only` {}
}

// MARK: - Unit Tests

extension `Ownership Box Tests`.Unit {
    @Test
    func `init(_:) stores the value`() {
        let box = Ownership.Box<Int>(42)
        #expect(box.value == 42)
    }

    @Test
    func `value _modify mutates through exclusive access`() {
        var box = Ownership.Box<Int>(10)
        box.value += 1
        #expect(box.value == 11)
    }

    @Test
    func `clone() produces an independent cell`() {
        let original = Ownership.Box<Int>(7)
        var copy = original.clone()
        copy.value = 99
        #expect(original.value == 7)
        #expect(copy.value == 99)
    }

    @Test
    func `isUnique is true for an unshared cell`() {
        var box = Ownership.Box<Int>(1)
        let unique = box.isUnique
        #expect(unique)
    }

    @Test
    func `sharing makes the cell non-unique until mutation restores it`() {
        var a = Ownership.Box<[Int]>([1, 2, 3])
        var b = a
        let sharedA = a.isUnique
        #expect(!sharedA)               // shared backing
        b.value.append(4)              // copy-on-write restores b's uniqueness
        let uniqueA = a.isUnique
        let uniqueB = b.isUnique
        #expect(uniqueA)
        #expect(uniqueB)
    }
}

// MARK: - Edge Case Tests (copy-on-write value semantics)

extension `Ownership Box Tests`.`Edge Case` {
    @Test
    func `shared cell CoW — mutation on copy leaves original untouched`() {
        let a = Ownership.Box<[Int]>([1, 2, 3])
        var b = a
        b.value.append(4)
        #expect(a.value == [1, 2, 3])
        #expect(b.value == [1, 2, 3, 4])
    }

    @Test
    func `cloning an unshared cell produces a distinct cell`() {
        let a = Ownership.Box<String>("payload")
        var b = a.clone()
        b.value = "mutated"
        #expect(a.value == "payload")
        #expect(b.value == "mutated")
    }

    @Test
    func `mutating through the original after sharing then diverging`() {
        var a = Ownership.Box<Int>(0)
        var b = a
        a.value = 5
        #expect(a.value == 5)
        #expect(b.value == 0)
        b.value = 9
        #expect(a.value == 5)
        #expect(b.value == 9)
    }

    @Test
    func `backing identity diverges on copy-on-write`() {
        let a = Ownership.Box<[Int]>([1])
        let identityA = a.identity
        var b = a
        #expect(b.identity == identityA)   // share the backing
        b.value.append(2)                  // copy-on-write
        #expect(b.identity != identityA)   // b diverged onto a fresh backing
        #expect(a.identity == identityA)   // a kept the original backing
    }
}

// MARK: - Integration Tests

extension `Ownership Box Tests`.Integration {
    @Test
    func `struct Value round-trips through CoW`() {
        struct Pair: Equatable {
            var a: Int
            var b: Int
        }
        let x = Ownership.Box<Pair>(Pair(a: 1, b: 2))
        var y = x
        y.value.a = 99
        #expect(x.value == Pair(a: 1, b: 2))
        #expect(y.value == Pair(a: 99, b: 2))
    }

    @Test
    func `nested Box preserves value semantics at both levels`() {
        let outer = Ownership.Box<Ownership.Box<Int>>(Ownership.Box<Int>(1))
        var sibling = outer
        sibling.value.value = 42
        #expect(outer.value.value == 1)
        #expect(sibling.value.value == 42)
    }

    @Test
    func `clone() of a shared cell detaches without a prior mutation`() {
        let a = Ownership.Box<Int>(8)
        let _ = a
        let b = a.clone()
        #expect(a.value == 8)
        #expect(b.value == 8)
    }

    @Test
    func `explicit clone witness drives copy-on-write through the gate`() {
        final class Cell { var n: Int; init(_ n: Int) { self.n = n } }
        // A reference-typed payload whose clone witness deep-copies the cell.
        let a = Ownership.Box<Cell>(
            Cell(1),
            drain: { _ in },
            clone: { Cell($0.n) }
        )
        var b = a
        b.ensureUnique()                   // gate → deep copy via the witness
        b.value.n = 99
        #expect(a.value.n == 1)
        #expect(b.value.n == 99)
    }

    @Test
    func `unguarded mutates in place after the gate`() {
        var a = Ownership.Box<[Int]>([1, 2])
        let copied = a.ensureUnique()      // already unique — no copy made
        #expect(!copied)
        a.unguarded.append(3)             // unchecked lane
        #expect(a.value == [1, 2, 3])
    }
}

// MARK: - Move Only Tests (drain-box teardown over a ~Copyable payload)

extension `Ownership Box Tests`.`Move Only` {
    final class Recorder {
        var destroyed = 0
    }

    struct Token: ~Copyable {
        let recorder: Recorder
        init(_ recorder: Recorder) { self.recorder = recorder }
        deinit { recorder.destroyed += 1 }
    }

    @Test
    func `a ~Copyable payload is statically unique and tears down exactly once`() {
        let recorder = Recorder()
        do {
            // No clone strategy — a move-only payload whose cell can never be shared.
            var box = Ownership.Box<Token>(Token(recorder), drain: { _ in }, clone: nil)
            let unique = box.isUnique       // move-only ⟹ always unique
            #expect(unique)
            #expect(recorder.destroyed == 0)
        }
        #expect(recorder.destroyed == 1)   // the cell's deinit tore the payload down exactly once
    }

    @Test
    func `a ~Copyable payload survives a consuming move into the cell`() {
        let recorder = Recorder()
        let token = Token(recorder)
        do {
            let box = Ownership.Box<Token>(token, drain: { _ in }, clone: nil)
            _ = box
            #expect(recorder.destroyed == 0)
        }
        #expect(recorder.destroyed == 1)
    }
}
