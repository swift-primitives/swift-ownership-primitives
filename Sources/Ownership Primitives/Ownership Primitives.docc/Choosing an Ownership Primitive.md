# Choosing an Ownership Primitive

@Metadata {
    @DisplayName("Choosing an Ownership Primitive")
    @TitleHeading("Ownership Primitives")
}

Pick the primitive whose contract matches your need — a lattice of 15 types, each holding a unique position along five axes.

## The Lattice

Every type in `swift-ownership-primitives` answers a specific combination of five questions. Find your row by asking the questions in order; each column narrows the answer space.

| Type                                                  | Lifetime         | Mutability  | Ownership multiplicity | Synchronization   | Value copyability |
|-------------------------------------------------------|------------------|-------------|------------------------|-------------------|-------------------|
| ``Ownership/Borrow``                                  | Scoped           | Read-only   | Exclusive (borrow)     | None              | `Copyable`        |
| ``Ownership/Inout``                                   | Scoped           | Mutable     | Exclusive (borrow)     | None              | `~Copyable` or `Copyable` |
| ``Ownership/Unique``                                  | Heap-owned       | Mutable     | Exclusive              | None              | `~Copyable` or `Copyable` |
| ``Ownership/Shared``                                  | Heap-shared (ARC)| Read-only   | Shared (ARC)           | None              | `Copyable`        |
| ``Ownership/Mutable``                                 | Heap-shared (ARC)| Mutable     | Shared (ARC)           | None (isolation required) | `Copyable` |
| ``Ownership/Mutable/Unchecked``                       | Heap-shared (ARC)| Mutable     | Shared (ARC)           | External (asserted) | `Copyable`      |
| ``Ownership/Slot``                                    | Heap-shared (ARC)| Mutable     | Shared (atomic)        | Atomic            | `~Copyable` or `Copyable` |
| ``Ownership/Latch``                                   | Heap-shared (ARC)| One-shot    | Shared (atomic)        | Atomic            | `~Copyable` or `Copyable` |
| ``Ownership/Indirect``                                | Heap-shared (CoW)| Mutable (CoW)| Shared until divergent | None              | `Copyable`        |
| ``Ownership/Transfer/Value/Outgoing``                 | In-transit       | One-shot    | Exclusive (post-take)  | Atomic            | `~Copyable` or `Copyable` |
| ``Ownership/Transfer/Value/Incoming``                 | In-transit       | One-shot    | Exclusive (post-consume)| Atomic           | `~Copyable` or `Copyable` |
| ``Ownership/Transfer/Retained/Outgoing``              | In-transit       | One-shot    | Exclusive (post-consume)| Atomic (ARC)     | `AnyObject`       |
| ``Ownership/Transfer/Retained/Incoming``              | In-transit       | One-shot    | Exclusive (post-consume)| Atomic           | `AnyObject`       |
| ``Ownership/Transfer/Erased/Outgoing``                | In-transit       | One-shot    | Exclusive (post-consume)| None (single-consumption contract) | Type-erased |
| ``Ownership/Transfer/Erased/Incoming``                | In-transit       | One-shot    | Exclusive (post-consume)| Atomic            | Type-erased       |

## The Unique Contract of Each Row

Each type is the answer to a question no other type in the lattice answers the same way.

### Scoped references

- ``Ownership/Borrow`` — *"I need a storable, lifetime-bounded, read-only reference to a `Copyable` value that exists elsewhere."* The compiler proves the reference does not outlive its source. Pre-SE-0519 `Borrow<Value>` shape.
- ``Ownership/Inout`` — *"...same, but I need to mutate through it."* Pre-SE-0519 `Inout<Value>` shape; works with `~Copyable` values that `Borrow` cannot express.

### Heap-owned, exclusive

- ``Ownership/Unique`` — *"I need heap placement for one value, with deterministic destruction and no shared-ownership cost."* Institute rendering of SE-0517 `UniqueBox`.

### Heap-shared, immutable or mutable

- ``Ownership/Shared`` — *"I need many readers to cheaply pass one large read-only value around, with ARC cleanup."*
- ``Ownership/Mutable`` — *"...same, but I need mutation, and I'll keep all access inside one isolation domain."* Deliberately **not** `Sendable`.
- ``Ownership/Mutable/Unchecked`` — *"...same, but my callers guarantee external synchronization and can cite the mechanism at review time."* Explicit `@unsafe @unchecked Sendable`.

### Heap-shared, atomic

- ``Ownership/Slot`` — *"I need a reusable atomic cell — publish, consume, publish again, indefinitely."* Cycles empty ↔ full.
- ``Ownership/Latch`` — *"I need a **one-shot** atomic cell — publish once, consume once, terminal."* Terminal after take.
- ``Ownership/Indirect`` — *"I need value semantics with a heap indirection and copy-on-write, so cheap shared copies only pay the copy cost when a holder actually diverges."*

### Cross-boundary transfer

Pick a **direction** (who creates the cell) × **kind** (what shape the payload has).

**Direction**

- *Outgoing* — producer already holds the value; wraps it at creation; hands a token across the boundary.
- *Incoming* — consumer allocates an empty slot first; producer fills it later through the Sendable token.

**Kind**

- ``Ownership/Transfer/Value`` \<V\> — any `~Copyable` / `Copyable` value. General-purpose.
- ``Ownership/Transfer/Retained`` \<T\> — `AnyObject` only. Uses `Unmanaged` for direct ARC manipulation; the outgoing direction allocates no box at all.
- ``Ownership/Transfer/Erased`` — type-erased payload. Producer and consumer agree on `T` out of band. Correct destruction is preserved on abandoned paths (``Ownership/Transfer/Erased/Outgoing/destroy(_:)``).

The six cells (2 directions × 3 kinds) cover the complete direction × kind matrix. If your transfer scenario does not fit a cell, the type family is missing a contract — please open an issue.

## Decision Flowchart

```
┌─ "I have a value elsewhere, need a scoped reference."
│    ├── Read-only? .......................... Ownership.Borrow
│    └── Mutable? ........................... Ownership.Inout
│
├─ "I want heap placement for one value."
│    ├── Single owner? ....................... Ownership.Unique
│    └── Shared?
│         ├── Immutable? ..................... Ownership.Shared
│         └── Mutable?
│              ├── Single isolation? ......... Ownership.Mutable
│              ├── External sync? ............ Ownership.Mutable.Unchecked
│              └── CoW value semantics? ...... Ownership.Indirect
│
├─ "I need an atomic shared cell."
│    ├── Reusable (cycles)? ................. Ownership.Slot
│    └── One-shot (terminal)? .............. Ownership.Latch
│
└─ "I need to transfer across a @Sendable boundary."
     ├── Direction?
     │    ├── Outgoing (producer→consumer).
     │    └── Incoming (consumer slot)
     └── Kind?
          ├── Value (any type) .............. Transfer.Value<V>.{Outgoing, Incoming}
          ├── Retained (AnyObject) .......... Transfer.Retained<T>.{Outgoing, Incoming}
          └── Erased (type-erased) .......... Transfer.Erased.{Outgoing, Incoming}
```

## Cross-Axis Relationships

Some pairs of primitives differ on exactly one axis — move between them by flipping that bit.

| Pair | Differs on | Motivation for the difference |
|------|-----------|-------------------------------|
| `Borrow` ↔ `Inout`                   | Mutability                    | Reader-vs-writer discipline for scoped references |
| `Shared` ↔ `Mutable`                 | Mutability                    | Shared owners wanting immutability vs. single-isolation mutation |
| `Mutable` ↔ `Mutable.Unchecked`      | Synchronization contract      | Isolation-bound vs. explicit `@unchecked Sendable` opt-in |
| `Slot` ↔ `Latch`                     | Lifecycle (reusable vs terminal) | Pool/channel vs. one-shot hand-off |
| `Unique` ↔ `Indirect`                | Copyability + CoW             | Exclusive `~Copyable` owner vs. value-semantic `Copyable` CoW cell |
| `Value.Outgoing` ↔ `Value.Incoming`  | Direction (who creates)       | Producer-side existing value vs. consumer-side empty slot |
| `Value.*` ↔ `Retained.*`             | Payload kind (value vs class) | Generic over `~Copyable` vs. `AnyObject` with ARC retain |
| `Retained.*` ↔ `Erased.*`            | Type visibility               | Direct AnyObject vs. type-erased box |

## See Also

- ``Ownership/Borrow`` · ``Ownership/Inout`` · ``Ownership/Unique``
- ``Ownership/Shared`` · ``Ownership/Mutable`` · ``Ownership/Mutable/Unchecked``
- ``Ownership/Slot`` · ``Ownership/Latch`` · ``Ownership/Indirect``
- ``Ownership/Transfer``
- <doc:Borrow-vs-Inout>
- <doc:Shared-vs-Mutable-vs-Unique>
- <doc:Slot-Move-vs-Store>
- <doc:Ownership-Transfer-Recipes>
