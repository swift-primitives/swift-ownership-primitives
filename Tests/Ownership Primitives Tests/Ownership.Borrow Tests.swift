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
struct `Ownership Borrow Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Borrow Tests`.Unit {
    @Test
    func `init(borrowing:) yields the borrowed value`() {
        let source = 42
        func peek(_ value: borrowing Int) -> Int {
            let ref = Ownership.Borrow(borrowing: value)
            return ref.value
        }
        #expect(peek(source) == 42)
    }

    @Test
    func `init(_:) from typed pointer yields the value`() {
        var source = 99
        unsafe withUnsafePointer(to: &source) { pointer in
            let ref = Ownership.Borrow(pointer)
            #expect(ref.value == 99)
        }
    }

    @Test
    func `value accessor returns same value on multiple reads`() {
        let source = 7
        func readTwice(_ value: borrowing Int) -> (Int, Int) {
            let ref = Ownership.Borrow(borrowing: value)
            return (ref.value, ref.value)
        }
        let (a, b) = readTwice(source)
        #expect(a == 7)
        #expect(b == 7)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Borrow Tests`.`Edge Case` {
    @Test
    func `value accessor works with struct types`() {
        struct Point: Equatable { var x: Int; var y: Int }
        let source = Point(x: 3, y: 4)
        func readX(_ value: borrowing Point) -> Int {
            let ref = Ownership.Borrow(borrowing: value)
            return ref.value.x
        }
        #expect(readX(source) == 3)
    }

    @Test
    func `Borrow is Copyable — fork within lifetime scope`() {
        let source = 100
        func forkAndReadBoth(_ value: borrowing Int) -> (Int, Int) {
            let a = Ownership.Borrow(borrowing: value)
            let b = a      // Copyable — second copy of the same borrow
            return (a.value, b.value)
        }
        let (x, y) = forkAndReadBoth(source)
        #expect(x == 100)
        #expect(y == 100)
    }

    @Test
    func `value accessor handles reference-type payload`() {
        final class Box {
            var contents: Int
            init(_ contents: Int) { self.contents = contents }
        }
        let obj = Box(5)
        func readContents(_ value: borrowing Box) -> Int {
            let ref = Ownership.Borrow(borrowing: value)
            return ref.value.contents
        }
        #expect(readContents(obj) == 5)
    }
}

// MARK: - Integration Tests

extension `Ownership Borrow Tests`.Integration {
    @Test
    func `Optional<Ownership.Borrow<Value>> expresses peek-style API`() {
        let value = 33
        func maybePeek(_ present: Bool, _ source: borrowing Int) -> Int? {
            guard present else { return nil }
            let ref = Ownership.Borrow(borrowing: source)
            return ref.value
        }
        #expect(maybePeek(true, value) == 33)
        #expect(maybePeek(false, value) == nil)
    }

    @Test
    func `nested Borrow accessors compose`() {
        struct Wrapper { var inner: Int }
        let source = Wrapper(inner: 17)
        func readInner(_ wrapper: borrowing Wrapper) -> Int {
            let outer = Ownership.Borrow(borrowing: wrapper)
            return outer.value.inner
        }
        #expect(readInner(source) == 17)
    }
}
