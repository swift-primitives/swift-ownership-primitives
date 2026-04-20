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
        unique.withValue { value in
            #expect(value == 42)
        }
    }

    @Test
    func `hasValue returns true after init`() {
        let unique = Ownership.Unique<Int>(99)
        #expect(unique.hasValue == true)
    }

    @Test
    func `withValue provides borrowed access`() {
        let unique = Ownership.Unique<String>("Hello")
        unique.withValue { value in
            #expect(value == "Hello")
        }
    }

    @Test
    func `withMutableValue provides mutable access`() {
        var unique = Ownership.Unique<Int>(10)
        unique.withMutableValue { value in
            value += 5
        }
        unique.withValue { value in
            #expect(value == 15)
        }
    }

    @Test
    func `take returns owned value`() {
        var unique = Ownership.Unique<Int>(123)
        let value = unique.take()
        #expect(value == 123)
    }

    @Test
    func `hasValue returns false after take`() {
        var unique = Ownership.Unique<Int>(42)
        _ = unique.take()
        #expect(!unique.hasValue == true)
    }

    @Test
    func `duplicated returns new owner with copy (Copyable)`() {
        let unique = Ownership.Unique<Int>(77)
        var duplicated = unique.duplicated()
        #expect(duplicated.take() == 77)
        #expect(unique.hasValue == true) // Original still has value
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
        unique.withValue { point in
            #expect(point.x == 1.0)
            #expect(point.y == 2.0)
        }

        unique.withMutableValue { point in
            point.x = 3.0
        }

        let point = unique.take()
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
        unique.withValue { counter in
            #expect(counter.value == 10)
        }
    }

    @Test
    func `works with optional types`() {
        var unique = Ownership.Unique<Int?>(42)
        unique.withValue { value in
            #expect(value == 42)
        }

        unique.withMutableValue { value in
            value = nil
        }

        unique.withValue { value in
            #expect(value == nil)
        }
    }

    @Test
    func `works with array types`() {
        var unique = Ownership.Unique<[Int]>([1, 2, 3])
        unique.withMutableValue { array in
            array.append(4)
        }
        unique.withValue { array in
            #expect(array == [1, 2, 3, 4])
        }
    }

    @Test
    func `description shows state`() {
        var unique = Ownership.Unique<Int>(42)
        let descBefore = unique.description
        #expect(descBefore.contains("Unique"))
        #expect(!descBefore.contains("empty"))

        _ = unique.take()
        let descAfter = unique.description
        #expect(descAfter.contains("empty"))
    }
}

// MARK: - Integration Tests

extension OwnershipUniqueTests.Integration {
    @Test
    func `deinit deallocates memory`() {
        // This test verifies that deinit runs without crashing
        // Memory leak detection would require external tools
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

        unique1.withMutableValue { $0 += 1 }

        unique1.withValue { #expect($0 == 101) }
        unique2.withValue { #expect($0 == 200) }
    }

    @Test
    func `nested withValue calls`() {
        let unique1 = Ownership.Unique<Int>(10)
        let unique2 = Ownership.Unique<Int>(20)

        unique1.withValue { v1 in
            unique2.withValue { v2 in
                #expect(v1 + v2 == 30)
            }
        }
    }

    @Test
    func `throwing closure in withValue`() throws {
        struct TestError: Error {}

        let unique = Ownership.Unique<Int>(42)

        do {
            try unique.withValue { value in
                if value == 42 {
                    throw TestError()
                }
            }
            Issue.record("Should have thrown")
        } catch is TestError {
            // Expected
        }

        // Unique should still be valid after throw
        #expect(unique.hasValue == true)
    }

    @Test
    func `throwing closure in withMutableValue`() throws {
        struct TestError: Error {}

        var unique = Ownership.Unique<Int>(42)

        do {
            try unique.withMutableValue { value in
                value = 100
                throw TestError()
            }
        } catch is TestError {
            // Expected
        }

        // Value should have been mutated before throw
        unique.withValue { value in
            #expect(value == 100)
        }
    }
}

// MARK: - Performance Tests

extension OwnershipUniqueTests.Performance {
    @Test
    func `allocation and deallocation`() {
        // Warmup
        for _ in 0..<10 {
            for _ in 0..<1000 {
                var unique = Ownership.Unique<Int>(42)
                _ = unique.take()
            }
        }

        // Measured
        for _ in 0..<100 {
            for _ in 0..<1000 {
                var unique = Ownership.Unique<Int>(42)
                _ = unique.take()
            }
        }
    }

    @Test
    func `withValue access`() {
        let unique = Ownership.Unique<Int>(42)

        // Warmup
        for _ in 0..<10 {
            for _ in 0..<10000 {
                unique.withValue { _ = $0 }
            }
        }

        // Measured
        for _ in 0..<100 {
            for _ in 0..<10000 {
                unique.withValue { _ = $0 }
            }
        }
    }

    @Test
    func `withMutableValue access`() {
        var unique = Ownership.Unique<Int>(0)

        // Warmup
        for _ in 0..<10 {
            for _ in 0..<10000 {
                unique.withMutableValue { $0 += 1 }
            }
        }

        // Measured
        for _ in 0..<100 {
            for _ in 0..<10000 {
                unique.withMutableValue { $0 += 1 }
            }
        }
    }
}
