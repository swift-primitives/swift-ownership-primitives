# ``Ownership_Primitives/Ownership/Transfer/Retained``

@Metadata {
    @DisplayName("Ownership.Transfer.Retained")
    @TitleHeading("Ownership Primitives")
}

Zero-allocation cross-boundary transfer for `AnyObject` types.

## Overview

`Transfer.Retained<T: AnyObject>` uses `Unmanaged` retain counts to hold the reference across a `@Sendable` boundary, avoiding the heap indirection that ``Ownership/Transfer/Cell`` would introduce for class-typed values.

The type is `~Copyable` (exactly-once), `@unsafe @unchecked Sendable`, and traps on double-take. On the receiving side, `take()` restores the strongly-held reference.

## Example

```swift
import Ownership_Primitives

final class Connection { /* ... */ }

let conn = Connection()
let retained = Ownership.Transfer.Retained(conn)

Task.detached {
    let received = retained.take()
    use(received)
}
```

## Rationale

For class types, `Cell` would box the reference inside additional heap storage — a needless indirection when the underlying representation is already a retain-counted pointer. `Retained` passes the `Unmanaged` directly and reclaims the strong reference on `take()`.

Use `Retained` when transferring classes across `@Sendable` boundaries; use ``Ownership/Transfer/Cell`` for struct / enum / `~Copyable` values.

## See Also

- ``Ownership/Transfer``
- ``Ownership/Transfer/Cell``
- <doc:Ownership-Transfer-Recipes>
