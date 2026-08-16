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

/// Regression fixture for the `-O` stale-load defect on `Ownership.Inout`.
///
/// When `Ownership.Inout(mutating:)` was only `@inlinable`, an optimised
/// caller hoisted loads of the source out of a loop that mutated the source
/// through an accessor-backed view, so a `while !x.isEmpty { x.pop.front() }`
/// drain never observed the pops (swift-buffer-ring-primitives
/// `Buffer.Ring.Builder.buildPartialBlock`, hosted run 31905986762). The
/// initializer is now `@_transparent`, and every wrapper initializer that
/// forwards `inout` to it must be `@_transparent` too — `Pop`/`Push` below
/// model that contract. Removing either attribute makes the builder tests
/// fail at `-O` (`trips == 16`) while debug passes.
///
/// The loops are bounded so a regression fails instead of hanging.
@Suite
struct `Ownership Inout Drain Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Fixture

extension `Ownership Inout Drain Tests` {
    struct Header {
        var head: Int = 0
        var count: Int = 0
    }

    /// A minimal heap-backed ring, shaped like `Buffer.Ring`.
    struct Ring<E: ~Copyable>: ~Copyable {
        var header: Header = .init()
        /// Loop trips recorded by the last builder drain (diagnostic only).
        var trips: Int = 0
        let capacity: Int
        let storage: UnsafeMutablePointer<E>

        init(capacity: Int) {
            self.capacity = capacity
            self.storage = unsafe .allocate(capacity: capacity)
        }

        deinit {
            var index = header.head
            for _ in 0..<header.count {
                unsafe (storage + index).deinitialize(count: 1)
                index = (index + 1) % capacity
            }
            unsafe storage.deallocate()
        }
    }

    /// An `Ownership.Inout`-backed mutable view, shaped like
    /// `Property.Inout.Typed`.
    struct Pop<E: ~Copyable>: ~Copyable, ~Escapable {
        let base: Ownership.Inout<Ring<E>>

        @_transparent
        @_lifetime(&ring)
        init(_ ring: inout Ring<E>) {
            base = Ownership.Inout(mutating: &ring)
        }
    }

    struct Push<E: ~Copyable>: ~Copyable, ~Escapable {
        let base: Ownership.Inout<Ring<E>>

        @_transparent
        @_lifetime(&ring)
        init(_ ring: inout Ring<E>) {
            base = Ownership.Inout(mutating: &ring)
        }
    }

    @resultBuilder
    enum Builder<E: ~Copyable> {}
}

extension `Ownership Inout Drain Tests`.Ring where E: ~Copyable {
    typealias Fixture = `Ownership Inout Drain Tests`

    var count: Int { header.count }
    var isEmpty: Bool { count == 0 }

    mutating func pushBack(_ element: consuming E) {
        precondition(header.count < capacity)
        let slot = (header.head + header.count) % capacity
        unsafe (storage + slot).initialize(to: element)
        header.count += 1
    }

    mutating func popFront() -> E? {
        guard header.count > 0 else { return nil }
        let element = unsafe (storage + header.head).move()
        header.head = (header.head + 1) % capacity
        header.count -= 1
        return element
    }

    var pop: Fixture.Pop<E> {
        mutating _read { yield Fixture.Pop(&self) }
        mutating _modify {
            var view = Fixture.Pop(&self)
            yield &view
        }
    }

    var push: Fixture.Push<E> {
        mutating _read { yield Fixture.Push(&self) }
        mutating _modify {
            var view = Fixture.Push(&self)
            yield &view
        }
    }

    static func build(@Fixture.Builder<E> _ build: () -> Fixture.Ring<E>) -> Fixture.Ring<E> {
        build()
    }
}

extension `Ownership Inout Drain Tests`.Pop where E: ~Copyable {
    mutating func front() -> E? {
        base.value.popFront()
    }
}

extension `Ownership Inout Drain Tests`.Push where E: ~Copyable {
    mutating func back(_ element: consuming E) {
        base.value.pushBack(element)
    }
}

extension `Ownership Inout Drain Tests`.Builder where E: ~Copyable {
    typealias Ring = `Ownership Inout Drain Tests`.Ring<E>

    static func buildExpression(_ expression: consuming E) -> Ring {
        var result = Ring(capacity: 64)
        result.push.back(expression)
        return result
    }

    static func buildPartialBlock(first: consuming Ring) -> Ring {
        first
    }

    /// The swift-buffer-ring-primitives drain shape: a condition loop that
    /// re-reads `rest` while popping through the view.
    static func buildPartialBlock(accumulated: consuming Ring, next: consuming Ring) -> Ring {
        var result = consume accumulated
        var rest = consume next
        var guardCount = 0
        while !rest.isEmpty, guardCount < 16 {
            guardCount += 1
            if let element = rest.pop.front() { result.push.back(element) }
        }
        result.trips = guardCount
        return result
    }
}

// MARK: - Unit Tests

extension `Ownership Inout Drain Tests`.Unit {
    typealias Ring = `Ownership Inout Drain Tests`.Ring

    @Test
    func `while-not-empty drain through an Inout-backed view terminates`() {
        var ring = Ring<Int>(capacity: 8)
        ring.push.back(1)
        ring.push.back(2)
        ring.push.back(3)
        var popped: [Int] = []
        var guardCount = 0
        while !ring.isEmpty, guardCount < 16 {
            guardCount += 1
            if let element = ring.pop.front() { popped.append(element) }
        }
        #expect(popped == [1, 2, 3])
        #expect(guardCount == 3)
        let empty = ring.isEmpty
        #expect(empty)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Inout Drain Tests`.`Edge Case` {
    typealias Ring = `Ownership Inout Drain Tests`.Ring

    @Test
    func `drain across a non-inlined boundary terminates`() {
        var ring = Ring<Int>(capacity: 4)
        ring.push.back(10)
        ring.push.back(20)
        let popped = Self.drain(&ring)
        #expect(popped == [10, 20])
        let empty = ring.isEmpty
        #expect(empty)
    }

    @inline(never)
    static func drain(_ ring: inout Ring<Int>) -> [Int] {
        var popped: [Int] = []
        var guardCount = 0
        while !ring.isEmpty, guardCount < 16 {
            guardCount += 1
            if let element = ring.pop.front() { popped.append(element) }
        }
        return popped
    }
}

// MARK: - Integration Tests

extension `Ownership Inout Drain Tests`.Integration {
    typealias Ring = `Ownership Inout Drain Tests`.Ring

    @Test
    func `builder drain terminates (Copyable element)`() {
        let ring = Ring<Int>.build {
            1
            2
        }
        let count = ring.count
        let trips = ring.trips
        #expect(count == 2)
        #expect(trips == 1)
    }

    @Test
    func `builder drain terminates (~Copyable element)`() {
        struct Token: ~Copyable {
            let id: Int
        }
        let ring = Ring<Token>.build {
            Token(id: 1)
            Token(id: 2)
            Token(id: 3)
        }
        let count = ring.count
        let trips = ring.trips
        #expect(count == 3)
        #expect(trips == 1)
    }
}
