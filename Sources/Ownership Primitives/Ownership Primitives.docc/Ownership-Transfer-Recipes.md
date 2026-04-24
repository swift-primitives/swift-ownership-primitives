# Ownership Transfer Recipes

@Metadata {
    @DisplayName("Ownership Transfer Recipes")
    @TitleHeading("Ownership Primitives")
}

The ``Ownership/Transfer`` namespace provides exactly-once value transfer across `@Sendable` boundaries. Pick a variant by whether the value exists before the boundary (`.Cell`), is created inside (`.Storage`), is a class instance (`.Retained`), or needs type erasure (`.Box`).

## Decision Matrix

| Starting state | Transfer type | Shape |
|----------------|---------------|-------|
| Value exists; pass it to the other side | ``Ownership/Transfer/Cell`` | `Cell(value)` → `cell.token()` → `token.take()` |
| Create value inside a closure; retrieve on the originating side | ``Ownership/Transfer/Storage`` | `Storage<T>()` → `storage.token` → `token.store(value)` → `storage.consume()` |
| Zero-allocation transfer for `AnyObject` | ``Ownership/Transfer/Retained`` | `Retained(object)` → `retained.consume()` (no heap indirection) |
| Type-erased transfer through an opaque boundary | ``Ownership/Transfer/Box`` | For interop scenarios needing an erased slot |

All variants provide **exactly-once** semantics. Tokens are `Copyable` — they can be captured in escaping closures. At most one `take()` / `store()` succeeds; subsequent operations trap or return the value back.

## Recipe 1: Pass an Existing Value Through `@Sendable`

```swift
import Ownership_Primitives

struct Work: ~Copyable, Sendable {
    let payload: Data
}

let cell = Ownership.Transfer.Cell(Work(payload: input))
let token = cell.token()   // Copyable — capture in @Sendable closure

Task.detached {
    let received = token.take()   // exactly-once
    process(received)
}
```

`Cell` pre-allocates storage and pre-populates it with the value. The token is a lightweight handle that can cross boundaries. Only one `take()` succeeds.

## Recipe 2: Create Inside, Retrieve Outside

```swift
import Ownership_Primitives

let storage = Ownership.Transfer.Storage<Work>()
let storeToken = storage.token

Task.detached {
    let work = Work(payload: try await fetch())
    storeToken.store(work)    // exactly-once — deposits the value
}

let received = storage.consume()   // on the originating side
```

`Storage` is the inverse direction of `Cell`: the caller pre-allocates empty storage, ships the `store`-capable token to the producer, and retrieves the produced value afterwards. Use when the value is expensive or asynchronous to construct and shouldn't block the originating side.

## Recipe 3: Zero-Allocation Class Transfer

```swift
import Ownership_Primitives

final class Connection { /* ... */ }

let conn = Connection()
let retained = Ownership.Transfer.Retained(conn)

Task.detached {
    let received = retained.consume()
    use(received)
}
```

`Retained` uses `Unmanaged` retain counts to transfer `AnyObject` types without any heap indirection. For class-typed values, prefer `Retained` over `Cell` — it avoids the extra allocation.

## Recipe 4: Type Erasure for Opaque Boundaries

Use ``Ownership/Transfer/Box`` when the boundary requires a type-erased slot (e.g., a C API taking `void*`). `Box` provides opaque-pointer transfer with the same exactly-once contract; on the other side, `take()` restores the typed value.

## Cell vs Storage: Which Direction?

Both move values across a `@Sendable` boundary, but the direction of dataflow differs:

| Dataflow | Type |
|----------|------|
| Originating side → producing side | ``Ownership/Transfer/Cell`` (value is there, consumer takes) |
| Producing side → originating side | ``Ownership/Transfer/Storage`` (slot is there, producer stores) |

If both sides need to exchange values, use one of each — a `Cell` for the outgoing direction and a `Storage` for the incoming direction.

## Transfer vs Slot

``Ownership/Transfer/*`` is **one-shot** — once taken, the slot is done. ``Ownership/Slot`` is **reusable** — it cycles between empty and full indefinitely. Use `Slot` for pools, long-lived channels, or any pattern where the same storage is reused. See <doc:Slot-Move-vs-Store>.

## See Also

- ``Ownership/Transfer``
- ``Ownership/Transfer/Cell``
- ``Ownership/Transfer/Storage``
- ``Ownership/Transfer/Retained``
- ``Ownership/Transfer/Box``
- <doc:Slot-Move-vs-Store>
