# ``Ownership_Primitives/Ownership/Transfer``

@Metadata {
    @DisplayName("Ownership.Transfer")
    @TitleHeading("Ownership Primitives")
}

Namespace for cross-boundary ownership transfer primitives with exactly-once semantics.

## Overview

`Ownership.Transfer` is a namespace (caseless `enum`) that organises its primitives along two axes:

| Kind (payload shape)             | Outgoing (producer→consumer)                                  | Incoming (consumer slot)                                      |
|----------------------------------|---------------------------------------------------------------|---------------------------------------------------------------|
| ``Ownership/Transfer/Value`` \<V\> | ``Ownership/Transfer/Value/Outgoing``                         | ``Ownership/Transfer/Value/Incoming``                         |
| ``Ownership/Transfer/Retained`` \<T\> | ``Ownership/Transfer/Retained/Outgoing``                      | ``Ownership/Transfer/Retained/Incoming``                      |
| ``Ownership/Transfer/Erased``    | ``Ownership/Transfer/Erased/Outgoing``                        | ``Ownership/Transfer/Erased/Incoming``                        |

- **Direction**: *Outgoing* — producer creates the cell already holding the value and hands it across; *Incoming* — consumer allocates an empty slot first, producer fills it later through a Sendable token.
- **Kind** (payload shape):
  - ``Ownership/Transfer/Value`` \<V\> — any `~Copyable` / `Copyable` value type.
  - ``Ownership/Transfer/Retained`` \<T\> — `AnyObject`; direct ARC manipulation via `Unmanaged`, no box allocation on the outgoing path.
  - ``Ownership/Transfer/Erased`` — type-erased payload; producer and consumer agree on `T` out of band. Correct destruction is preserved on abandoned paths.

Tokens for each variant are `Copyable` (captureable in `@Sendable` escaping closures), but only one `take` / `store` / `consume` operation succeeds — subsequent calls trap deterministically. Thread safety comes from atomic CAS enforcement; types are `@unchecked Sendable` where applicable.

## When to Use

Use `Transfer.*` when ownership must cross a `@Sendable` boundary exactly once. For reusable slots (cycle empty ↔ full), use ``Ownership/Slot``. For one-shot hand-off without the Token indirection, use ``Ownership/Latch``.

See <doc:Ownership-Transfer-Recipes> for the full recipe catalog.

## Topics

### Kind: Value

- ``Ownership/Transfer/Value``
- ``Ownership/Transfer/Value/Outgoing``
- ``Ownership/Transfer/Value/Incoming``

### Kind: Retained (AnyObject)

- ``Ownership/Transfer/Retained``
- ``Ownership/Transfer/Retained/Outgoing``
- ``Ownership/Transfer/Retained/Incoming``

### Kind: Erased

- ``Ownership/Transfer/Erased``
- ``Ownership/Transfer/Erased/Outgoing``
- ``Ownership/Transfer/Erased/Incoming``

## See Also

- ``Ownership/Slot``
- ``Ownership/Latch``
- ``Ownership/Unique``
- <doc:Ownership-Transfer-Recipes>
