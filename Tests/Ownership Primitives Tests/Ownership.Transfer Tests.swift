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
    @Suite struct `Value Outgoing` {}
    @Suite struct `Value Incoming` {}
    @Suite struct `Retained Outgoing` {}
    @Suite struct `Retained Incoming` {}
    @Suite struct `Erased Outgoing` {}
    @Suite struct `Erased Incoming` {}
    @Suite struct Integration {}
}

// MARK: - Value.Outgoing

extension `Ownership Transfer Tests`.`Value Outgoing` {
    @Test
    func `token take() retrieves the stored value`() {
        let outgoing = Ownership.Transfer.Value<Int>.Outgoing(42)
        let token = outgoing.token()
        #expect(token.take() == 42)
    }

    @Test
    func `token is Copyable — can be captured by multiple closures`() {
        let outgoing = Ownership.Transfer.Value<Int>.Outgoing(10)
        let token = outgoing.token()
        let captureA: () -> Void = { _ = token }
        let captureB: () -> Void = { _ = token }
        captureA()
        captureB()
        #expect(token.take() == 10)
    }

    @Test
    func `works with struct Value`() {
        struct Payload: Equatable { var a: Int; var b: Int }
        let outgoing = Ownership.Transfer.Value<Payload>.Outgoing(Payload(a: 1, b: 2))
        let token = outgoing.token()
        #expect(token.take() == Payload(a: 1, b: 2))
    }
}

// MARK: - Value.Incoming

extension `Ownership Transfer Tests`.`Value Incoming` {
    @Test
    func `token.store(_) then consume() round-trips`() {
        let incoming = Ownership.Transfer.Value<Int>.Incoming()
        incoming.token.store(77)
        #expect(incoming.consume() == 77)
    }

    @Test
    func `token is Copyable`() {
        let incoming = Ownership.Transfer.Value<Int>.Incoming()
        let token = incoming.token
        let _: () -> Void = { _ = token }
        token.store(99)
        #expect(incoming.consume() == 99)
    }

    @Test
    func `consumeIfStored returns nil on an empty slot`() {
        let incoming = Ownership.Transfer.Value<Int>.Incoming()
        #expect(incoming.consumeIfStored() == nil)
    }

    @Test
    func `consumeIfStored returns the value when stored`() {
        let incoming = Ownership.Transfer.Value<Int>.Incoming()
        incoming.token.store(123)
        #expect(incoming.consumeIfStored() == 123)
    }
}

// MARK: - Retained.Outgoing

extension `Ownership Transfer Tests`.`Retained Outgoing` {
    @Test
    func `consume() returns the strong reference`() {
        final class Node {
            let id: Int
            init(_ id: Int) { self.id = id }
        }
        let node = Node(5)
        let outgoing = unsafe Ownership.Transfer.Retained<Node>.Outgoing(node)
        let taken = outgoing.consume()
        #expect(taken.id == 5)
    }

    @Test
    func `preserves class identity through transfer`() {
        final class Marker { let tag: Int; init(_ tag: Int) { self.tag = tag } }
        let marker = Marker(1)
        let outgoing = unsafe Ownership.Transfer.Retained<Marker>.Outgoing(marker)
        let received = outgoing.consume()
        #expect(received === marker)
    }
}

// MARK: - Retained.Incoming

extension `Ownership Transfer Tests`.`Retained Incoming` {
    @Test
    func `token.store then consume round-trips an object`() {
        final class Service {
            let id: Int
            init(_ id: Int) { self.id = id }
        }
        let incoming = Ownership.Transfer.Retained<Service>.Incoming()
        let token = incoming.token
        token.store(Service(42))
        let received = incoming.consume()
        #expect(received.id == 42)
    }

    @Test
    func `consumeIfStored returns nil on an empty slot`() {
        final class Service { init() {} }
        let incoming = Ownership.Transfer.Retained<Service>.Incoming()
        #expect(incoming.consumeIfStored() == nil)
    }

    @Test
    func `preserves class identity through the slot`() {
        final class Marker { let tag: Int; init(_ tag: Int) { self.tag = tag } }
        let marker = Marker(7)
        let incoming = Ownership.Transfer.Retained<Marker>.Incoming()
        incoming.token.store(marker)
        let received = incoming.consume()
        #expect(received === marker)
    }
}

// MARK: - Erased.Outgoing

extension `Ownership Transfer Tests`.`Erased Outgoing` {
    @Test
    func `make then consume round-trips a struct payload`() {
        struct Payload: Equatable { var a: Int; var b: Int }
        let raw = unsafe Ownership.Transfer.Erased.Outgoing.make(Payload(a: 3, b: 4))
        let payload: Payload = unsafe Ownership.Transfer.Erased.Outgoing.consume(raw)
        #expect(payload == Payload(a: 3, b: 4))
    }

    @Test
    func `destroy releases an unconsumed box without crashing`() {
        struct Payload { var a: Int; var b: String }
        let raw = unsafe Ownership.Transfer.Erased.Outgoing.make(Payload(a: 7, b: "payload"))
        unsafe Ownership.Transfer.Erased.Outgoing.destroy(raw)
    }
}

// MARK: - Erased.Incoming

extension `Ownership Transfer Tests`.`Erased Incoming` {
    @Test
    func `token.store then consume round-trips a boxed struct`() {
        struct Payload: Equatable { var a: Int; var b: Int }
        let incoming = Ownership.Transfer.Erased.Incoming()
        let token = incoming.token
        let raw = unsafe Ownership.Transfer.Erased.Outgoing.make(Payload(a: 1, b: 2))
        unsafe token.store(raw)
        let payload = unsafe incoming.consume(Payload.self)
        #expect(payload == Payload(a: 1, b: 2))
    }

    @Test
    func `consumeIfStored returns nil on an empty slot`() {
        let incoming = Ownership.Transfer.Erased.Incoming()
        let v: Int? = unsafe incoming.consumeIfStored(Int.self)
        #expect(v == nil)
    }
}

// MARK: - Integration

extension `Ownership Transfer Tests`.Integration {
    @Test
    func `Outgoing + Incoming together model a bidirectional channel`() {
        let request = Ownership.Transfer.Value<Int>.Outgoing(42)
        let reply = Ownership.Transfer.Value<Int>.Incoming()

        // Producer side — would typically run on a detached task.
        let requestToken = request.token()
        let replyToken = reply.token
        let received = requestToken.take()
        replyToken.store(received * 2)

        // Consumer side — retrieves the produced value.
        #expect(reply.consume() == 84)
    }

    @Test
    func `Retained.Incoming roundtrip preserves identity across threadless hand-off`() {
        final class Service { let id: Int ; init(_ id: Int) { self.id = id } }
        let incoming = Ownership.Transfer.Retained<Service>.Incoming()
        let producerToken = incoming.token
        let expected = Service(1)
        producerToken.store(expected)
        let got = incoming.consume()
        #expect(got === expected)
    }
}
