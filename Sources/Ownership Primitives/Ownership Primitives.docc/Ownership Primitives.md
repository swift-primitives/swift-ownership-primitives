# ``Ownership_Primitives``

@Metadata {
    @DisplayName("Ownership Primitives")
    @TitleHeading("Swift Primitives")
    @PageColor(blue)
    @CallToAction(
        url: "doc:GettingStarted",
        purpose: link,
        label: "Start the Tutorial"
    )
}

Safe ownership references — `Borrow`, `Inout`, `Unique`, `Shared`, `Mutable`, `Slot`, `Latch`, `Indirect`, and the `Transfer.*` family — for `~Copyable` / `~Escapable` / `Copyable` values on production Swift 6.3.1.

## Overview

``Ownership`` is a namespace for types that carry an explicit ownership contract. `Borrow` and `Inout` are scoped references; `Unique` heap-owns an exclusive `~Copyable` cell; `Shared` and `Mutable` heap-share via ARC; `Slot` is a reusable atomic slot (cycles empty ↔ full); `Latch` is a one-shot atomic cell (terminal after take); `Indirect` is a heap-allocated copy-on-write value cell; the `Transfer.*` family transfers one-shot across `@Sendable` boundaries with Sendable tokens.

The package ships these as SE-0519-parallel primitives on toolchains where `BorrowAndMutateAccessors` (SE-0507) has not yet landed in stable form. Consumers use `Ownership.Inout` / `Ownership.Borrow` as storable, lifetime-bounded references — a shape that neither `inout` parameters (not storable) nor raw `Unsafe*Pointer` (no lifetime) supply.

## Narrow-Import Decomposition

`swift-ownership-primitives` is decomposed along the ownership-mode axis per `[MOD-015]` primary decomposition. Consumers import the specific variant they need, not the umbrella:

| Use case | Narrow import |
|----------|---------------|
| Scoped read-only reference | `import Ownership_Borrow_Primitives` |
| Scoped mutable reference | `import Ownership_Inout_Primitives` |
| Heap-owned exclusive cell | `import Ownership_Unique_Primitives` |
| ARC-shared immutable / mutable | `import Ownership_Shared_Primitives` / `Ownership_Mutable_Primitives` |
| Reusable atomic slot | `import Ownership_Slot_Primitives` |
| One-shot atomic cell | `import Ownership_Latch_Primitives` |
| Heap CoW value cell | `import Ownership_Indirect_Primitives` |
| Cross-boundary transfer | `import Ownership_Transfer_Primitives` |
| Type-erased boxed transfer | `import Ownership_Transfer_Box_Primitives` |
| `Optional<~Copyable>.take()` | `import Ownership_Primitives_Standard_Library_Integration` |

The umbrella `import Ownership_Primitives` is available for prototyping and tests — it `@_exported`-re-exports every variant. Release builds SHOULD use the narrow imports.

@Row {
    @Column {
        ### Start hands-on

        A seven-minute tutorial: wrap a `~Copyable` container in a safe mutable reference and read through a scoped borrow.

        <doc:GettingStarted>
    }
    @Column {
        ### Choose a reference

        Decide between ``Ownership/Borrow`` (read-only, `Copyable`) and ``Ownership/Inout`` (mutable, `~Copyable`) for scoped references.

        <doc:Borrow-vs-Inout>
    }
    @Column {
        ### Choose a cell

        Decide between ``Ownership/Unique``, ``Ownership/Shared``, and ``Ownership/Mutable`` for heap-owned storage.

        <doc:Shared-vs-Mutable-vs-Unique>
    }
}

## Topics

### Tutorials

- <doc:GettingStarted>

### Patterns

- <doc:Borrow-vs-Inout>
- <doc:Shared-vs-Mutable-vs-Unique>
- <doc:Ownership-Transfer-Recipes>
- <doc:Slot-Move-vs-Store>

### Scoped References

- ``Ownership/Borrow``
- ``Ownership/Inout``

### Heap-Owned Cells

- ``Ownership/Unique``
- ``Ownership/Shared``
- ``Ownership/Mutable``
- ``Ownership/Mutable/Unchecked``

### Reusable Atomic Slot

- ``Ownership/Slot``
- ``Ownership/Slot/Move``

### One-Shot Atomic Cell

- ``Ownership/Latch``

### Copy-on-Write Value Cell

- ``Ownership/Indirect``

### Cross-Boundary Transfer

- ``Ownership/Transfer``
- ``Ownership/Transfer/Box``
- ``Ownership/Transfer/Cell``
- ``Ownership/Transfer/Retained``
- ``Ownership/Transfer/Storage``

## Further reading

- [`Research/`](https://github.com/swift-primitives/swift-ownership-primitives/tree/main/Research) — design rationale for the ownership type family.
- [`Experiments/`](https://github.com/swift-primitives/swift-ownership-primitives/tree/main/Experiments) — empirical validation of each shipped primitive.
