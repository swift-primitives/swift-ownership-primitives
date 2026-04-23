# ``Ownership_Primitives/Ownership/Transfer/Cell``

@Metadata {
    @DisplayName("Ownership.Transfer.Cell")
    @TitleHeading("Ownership Primitives")
}

Pass an existing value through a `@Sendable` boundary with exactly-once take semantics.

## Overview

`Transfer.Cell<T>` pre-allocates storage and pre-populates it with a value at construction. It emits a `Copyable` token that can be captured in `@Sendable` closures; on the other side of the boundary, `token.take()` retrieves the value. Exactly one `take()` succeeds — subsequent calls trap deterministically.

Use `Cell` when the value already exists on the originating side and must be handed to code running in a different isolation domain.

## Example

```swift
import Ownership_Primitives

struct Work: ~Copyable, Sendable {
    let payload: Data
}

let cell = Ownership.Transfer.Cell(Work(payload: input))
let token = cell.token()

Task.detached {
    let received = token.take()   // exactly-once
    process(received)
}
```

## Rationale

Token is `Copyable` because escaping `@Sendable` closures require captured values to be `Copyable`. The exactly-once guarantee is enforced atomically at `take()`: the first caller to CAS-win the ownership bit receives the value; subsequent callers trap.

`Cell` pairs with ``Ownership/Transfer/Storage`` for the reverse direction (create inside, retrieve outside). For class types, ``Ownership/Transfer/Retained`` avoids the heap indirection `Cell` requires.

## See Also

- ``Ownership/Transfer``
- ``Ownership/Transfer/Storage``
- ``Ownership/Transfer/Retained``
- <doc:Ownership-Transfer-Recipes>
