# Ownership Transfer Recipes

@Metadata {
    @DisplayName("Ownership Transfer Recipes")
    @TitleHeading("Ownership Primitives")
}

The ``Ownership/Transfer`` namespace provides exactly-once value transfer across `@Sendable` boundaries. Pick a cell by the direction (Outgoing vs Incoming) and the payload kind (Value, Retained, Erased).

## Decision Matrix

| Starting state                            | Cell                                              | Shape                                                                                 |
|-------------------------------------------|---------------------------------------------------|---------------------------------------------------------------------------------------|
| Value exists; pass it to the other side   | ``Ownership/Transfer/Value/Outgoing``             | `Value<T>.Outgoing(value)` → `outgoing.token()` → `token.take()`                      |
| Create value inside; retrieve outside     | ``Ownership/Transfer/Value/Incoming``             | `Value<T>.Incoming()` → `incoming.token` → `token.store(value)` → `incoming.consume()` |
| Zero-alloc AnyObject; pass out            | ``Ownership/Transfer/Retained/Outgoing``          | `Retained<T>.Outgoing(object)` → `outgoing.consume()` (no box indirection)            |
| Consumer-side AnyObject slot; fill later  | ``Ownership/Transfer/Retained/Incoming``          | `Retained<T>.Incoming()` → `incoming.token.store(object)` → `incoming.consume()`       |
| Type-erased; pass through opaque boundary | ``Ownership/Transfer/Erased/Outgoing``            | `Erased.Outgoing.make(value)` → opaque pointer → `Erased.Outgoing.consume(ptr)`       |
| Type-erased consumer slot                 | ``Ownership/Transfer/Erased/Incoming``            | `Erased.Incoming()` → `incoming.token.store(ptr)` → `incoming.consume(T.self)`        |

All variants provide **exactly-once** semantics. Tokens are `Copyable` — they can be captured in escaping closures. At most one `take()` / `store()` / `consume()` succeeds; subsequent operations trap.

## Recipe 1: Pass an Existing Value Through `@Sendable`

```swift
import Ownership_Primitives

struct Work: ~Copyable, Sendable { let payload: Data }

let outgoing = Ownership.Transfer.Value<Work>.Outgoing(Work(payload: input))
let token = outgoing.token()           // Copyable — capture in @Sendable closure

Task.detached {
    let received = token.take()        // exactly-once
    process(received)
}
```

## Recipe 2: Create Inside, Retrieve Outside

```swift
import Ownership_Primitives

let incoming = Ownership.Transfer.Value<Work>.Incoming()
let storeToken = incoming.token

Task.detached {
    let work = Work(payload: try await fetch())
    storeToken.store(work)             // exactly-once — deposits the value
}

let received = incoming.consume()      // on the originating side
```

## Recipe 3: Zero-Allocation Class Transfer (Outgoing)

```swift
import Ownership_Primitives

final class Connection { /* ... */ }

let conn = Connection()
let outgoing = unsafe Ownership.Transfer.Retained<Connection>.Outgoing(conn)

Task.detached {
    let received = outgoing.consume()
    use(received)
}
```

## Recipe 4: Consumer-Side AnyObject Slot

```swift
import Ownership_Primitives

let incoming = Ownership.Transfer.Retained<Connection>.Incoming()
let token = incoming.token

Task.detached {
    let conn = await newConnection()
    token.store(conn)
}

let received = incoming.consume()
```

## Recipe 5: Type-Erased Outgoing

Use ``Ownership/Transfer/Erased/Outgoing`` when the boundary requires an opaque slot (e.g., a C API taking `void*`). `make(_:)` boxes; `consume(_:)` unboxes with the caller's known `T`; `destroy(_:)` releases without unboxing on abandoned paths.

## Recipe 6: Type-Erased Incoming

``Ownership/Transfer/Erased/Incoming`` mirrors the outgoing erased path: the consumer allocates an empty slot, the producer stores an opaque pointer through the Sendable token, and the consumer unboxes with `incoming.consume(T.self)`.

## Outgoing vs Incoming: Which Direction?

Both move values across a `@Sendable` boundary, but the direction of dataflow differs:

| Dataflow                              | Direction    |
|---------------------------------------|--------------|
| Originating side → producing side     | Outgoing (value is there, consumer takes) |
| Producing side → originating side     | Incoming (slot is there, producer stores) |

If both sides need to exchange values, pair one of each — an Outgoing for the outbound hand-off and an Incoming for the inbound reply.

## Transfer vs Slot vs Latch

- ``Ownership/Transfer/*`` — cross-boundary transfer with a separate Sendable Token layer; one-shot.
- ``Ownership/Slot`` — **reusable** atomic slot, cycles empty ↔ full indefinitely. Use for pools and long-lived channels.
- ``Ownership/Latch`` — one-shot atomic cell without the Token indirection; use when ARC sharing between producer and consumer is acceptable directly.

See <doc:Slot-Move-vs-Store>.

## See Also

- ``Ownership/Transfer``
- ``Ownership/Slot``
- ``Ownership/Latch``
