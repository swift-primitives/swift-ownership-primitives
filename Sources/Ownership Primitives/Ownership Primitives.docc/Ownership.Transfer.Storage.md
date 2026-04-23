# ``Ownership_Primitives/Ownership/Transfer/Storage``

@Metadata {
    @DisplayName("Ownership.Transfer.Storage")
    @TitleHeading("Ownership Primitives")
}

Create a value inside a `@Sendable` closure and retrieve it on the originating side.

## Overview

`Transfer.Storage<T>` is the inverse of ``Ownership/Transfer/Cell``. The caller allocates empty storage; ships the `store`-capable token to the producer; retrieves the produced value afterwards via `storage.take()`.

Use `Storage` when the value is expensive or asynchronous to construct and shouldn't block the originating side.

## Example

```swift
import Ownership_Primitives

let storage = Ownership.Transfer.Storage<Work>()
let storeToken = storage.token

Task.detached {
    let produced = try await expensivelyCompute()
    storeToken.store(produced)      // exactly-once
}

let received = storage.take()        // on the originating side
```

## Rationale

The token is `Copyable` but carries atomic exactly-once enforcement on `store`: a second `store` call would trap (double-produce). The `take` on the originating side also enforces exactly-once — after a successful retrieval, subsequent `take`s trap (double-consume).

`Storage` pairs with ``Ownership/Transfer/Cell`` for the outgoing direction. If both sides need to exchange values, use one of each.

## See Also

- ``Ownership/Transfer``
- ``Ownership/Transfer/Cell``
- <doc:Ownership-Transfer-Recipes>
