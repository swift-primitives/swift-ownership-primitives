// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing
@testable import Ownership_Primitives

@Suite("Ownership.Unique")
struct OwnershipUniqueTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
}

// MARK: - Unit Tests

extension OwnershipUniqueTests.Unit {
    @Test
    func `init heap-allocates value`() {
        let unique = Ownership.Unique<Int>(42)
        #expect(unique.value == 42)
    }

    @Test
    func `value accessor reads via _read coroutine`() {
        let unique = Ownership.Unique<Int>(99)
        #expect(unique.value == 99)
    }

    @Test
    func `value accessor mutates via _modify coroutine`() {
        var unique = Ownership.Unique<Int>(10)
        unique.value += 5
        #expect(unique.value == 15)
    }

    @Test
    func `consume returns owned value and destroys cell`() {
        let unique = Ownership.Unique<Int>(123)
        let value = unique.consume()
        // `unique` no longer exists after consume — compile-time error
        // to reference it here, which IS the contract.
        #expect(value == 123)
    }

    @Test
    func `clone returns independent owner (Copyable)`() {
        let unique = Ownership.Unique<Int>(77)
        let duplicated = unique.clone()
        #expect(duplicated.consume() == 77)
        #expect(unique.value == 77)  // original still owns its value
    }

    @Test
    func `span provides read-only view with count 1`() {
        let unique = Ownership.Unique<Int>(42)
        let span = unique.span
        #expect(span.count == 1)
        #expect(span[0] == 42)
    }

    @Test
    func `mutableSpan provides mutable view with count 1`() {
        var unique = Ownership.Unique<Int>(10)
        var span = unique.mutableSpan
        #expect(span.count == 1)
        span[0] = 20
        #expect(unique.value == 20)
    }
}

// MARK: - Edge Case Tests

extension OwnershipUniqueTests.EdgeCase {
    @Test
    func `works with struct types`() {
        struct Point: Equatable {
            var x: Double
            var y: Double
        }

        var unique = Ownership.Unique<Point>(Point(x: 1.0, y: 2.0))
        #expect(unique.value.x == 1.0)
        #expect(unique.value.y == 2.0)

        unique.value.x = 3.0

        let point = unique.consume()
        #expect(point.x == 3.0)
        #expect(point.y == 2.0)
    }

    @Test
    func `works with class types`() {
        class Counter {
            var value: Int
            init(_ value: Int) { self.value = value }
        }

        let unique = Ownership.Unique<Counter>(Counter(10))
        #expect(unique.value.value == 10)
    }

    @Test
    func `works with optional types`() {
        var unique = Ownership.Unique<Int?>(42)
        #expect(unique.value == 42)

        unique.value = nil
        #expect(unique.value == nil)
    }

    @Test
    func `works with array types`() {
        var unique = Ownership.Unique<[Int]>([1, 2, 3])
        unique.value.append(4)
        #expect(unique.value == [1, 2, 3, 4])
    }

    // MARK: - ~Copyable Value regression

    @Test
    func `consume works with ~Copyable Value`() {
        struct Handle: ~Copyable { let fd: Int32 }
        let cell = Ownership.Unique(Handle(fd: 3))
        let taken = cell.consume()
        #expect(taken.fd == 3)
    }

    @Test
    func `value accessor works with ~Copyable Value via transitive borrow`() {
        struct Handle: ~Copyable { let fd: Int32 }
        let cell = Ownership.Unique(Handle(fd: 11))
        // transitive borrow — reads .fd through _read yield
        #expect(cell.value.fd == 11)
    }

    @Test
    func `value accessor mutates ~Copyable Value`() {
        struct MutableHandle: ~Copyable { var count: Int }
        var cell = Ownership.Unique(MutableHandle(count: 0))
        cell.value.count += 1
        let taken = cell.consume()
        #expect(taken.count == 1)
    }
}

// MARK: - Integration Tests

extension OwnershipUniqueTests.Integration {
    @Test
    func `deinit deallocates memory`() {
        // Verifies that scope-exit deinit runs without crashing.
        // Memory leak detection would require external tools.
        do {
            _ = Ownership.Unique<Int>(42)
            // Unique goes out of scope and should deallocate
        }
        #expect(true) // If we get here, deinit didn't crash
    }

    @Test
    func `multiple owners are independent`() {
        var unique1 = Ownership.Unique<Int>(100)
        let unique2 = Ownership.Unique<Int>(200)

        unique1.value += 1

        #expect(unique1.value == 101)
        #expect(unique2.value == 200)
    }

    @Test
    func `nested value reads via transitive borrow`() {
        let unique1 = Ownership.Unique<Int>(10)
        let unique2 = Ownership.Unique<Int>(20)

        let sum = unique1.value + unique2.value
        #expect(sum == 30)
    }
}

// MARK: - Performance Tests

extension OwnershipUniqueTests.Performance {
    @Test
    func `allocation and deallocation`() {
        // Warmup
        for _ in 0..<10 {
            for _ in 0..<1000 {
                let unique = Ownership.Unique<Int>(42)
                _ = unique.consume()
            }
        }

        // Measured
        for _ in 0..<100 {
            for _ in 0..<1000 {
                let unique = Ownership.Unique<Int>(42)
                _ = unique.consume()
            }
        }
    }

    @Test
    func `value read access`() {
        let unique = Ownership.Unique<Int>(42)

        // Warmup
        for _ in 0..<10 {
            for _ in 0..<10000 {
                _ = unique.value
            }
        }

        // Measured
        for _ in 0..<100 {
            for _ in 0..<10000 {
                _ = unique.value
            }
        }
    }

    @Test
    func `value mutate access`() {
        var unique = Ownership.Unique<Int>(0)

        // Warmup
        for _ in 0..<10 {
            for _ in 0..<10000 {
                unique.value += 1
            }
        }

        // Measured
        for _ in 0..<100 {
            for _ in 0..<10000 {
                unique.value += 1
            }
        }
    }
}
