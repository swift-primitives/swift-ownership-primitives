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
struct `Ownership Transfer Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

// MARK: - Unit Tests

extension `Ownership Transfer Tests`.Unit {
    @Test
    func `Cell token take() retrieves the stored value`() {
        let cell = Ownership.Transfer.Cell(42)
        let token = cell.token()
        #expect(token.take() == 42)
    }

    @Test
    func `Storage.token.store(_) then storage.consume() round-trips`() {
        let storage = Ownership.Transfer.Storage<Int>()
        storage.token.store(77)
        #expect(storage.consume() == 77)
    }

    @Test
    func `Retained consume() returns the strong reference`() {
        final class Node {
            let id: Int
            init(_ id: Int) { self.id = id }
        }
        let node = Node(5)
        let retained = Ownership.Transfer.Retained(node)
        let taken = retained.consume()
        #expect(taken.id == 5)
    }
}

// MARK: - Edge Case Tests

extension `Ownership Transfer Tests`.`Edge Case` {
    @Test
    func `Cell token is Copyable — can be captured by multiple closures`() {
        let cell = Ownership.Transfer.Cell(10)
        let token = cell.token()
        let captureA: () -> Void = { _ = token }
        let captureB: () -> Void = { _ = token }
        captureA()
        captureB()
        #expect(token.take() == 10)
    }

    @Test
    func `Storage token is Copyable`() {
        let storage = Ownership.Transfer.Storage<Int>()
        let token = storage.token
        let _: () -> Void = { _ = token }
        token.store(99)
        #expect(storage.consume() == 99)
    }

    @Test
    func `Cell works with struct Value`() {
        struct Payload: Equatable { var a: Int; var b: Int }
        let cell = Ownership.Transfer.Cell(Payload(a: 1, b: 2))
        let token = cell.token()
        #expect(token.take() == Payload(a: 1, b: 2))
    }
}

// MARK: - Integration Tests

extension `Ownership Transfer Tests`.Integration {
    @Test
    func `Cell + Storage together model a bidirectional channel`() {
        let request = Ownership.Transfer.Cell(42)
        let reply = Ownership.Transfer.Storage<Int>()

        // Producer side — would typically run on a detached task.
        let requestToken = request.token()
        let replyToken = reply.token
        let received = requestToken.take()
        replyToken.store(received * 2)

        // Consumer side — retrieves the produced value.
        #expect(reply.consume() == 84)
    }

    @Test
    func `Retained preserves class identity through transfer`() {
        final class Marker { let tag: Int; init(_ tag: Int) { self.tag = tag } }
        let marker = Marker(1)
        let retained = Ownership.Transfer.Retained(marker)
        let received = retained.consume()
        #expect(received === marker)
    }
}
