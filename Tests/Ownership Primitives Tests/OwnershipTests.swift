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

@Suite("Ownership Primitives")
struct OwnershipPrimitivesTests {

    @Test
    func `Ownership.Unique basic operations`() {
        var unique = Ownership.Unique(42)
        #expect(unique.hasValue == true)

        let value = unique.take()
        #expect(value == 42)
        #expect(unique.hasValue == false)
    }

    @Test
    func `Ownership.Shared basic operations`() {
        let shared = Ownership.Shared(42)
        #expect(shared.value == 42)
    }

    @Test
    func `Ownership.Mutable basic operations`() {
        let mutable = Ownership.Mutable(42)
        #expect(mutable.value == 42)

        mutable.value = 100
        #expect(mutable.value == 100)
    }

    @Test
    func `Ownership.Slot basic operations`() {
        let slot = Ownership.Slot<Int>()
        #expect(slot.isEmpty == true)
        #expect(slot.isFull == false)

        switch slot.store(42) {
        case .stored:
            #expect(slot.isFull == true)
        case .occupied:
            Issue.record("Expected store to succeed")
        }

        if let value = slot.take() {
            #expect(value == 42)
        } else {
            Issue.record("Expected take to succeed")
        }

        #expect(slot.isEmpty == true)
    }
}
