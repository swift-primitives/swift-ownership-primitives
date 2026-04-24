# Shared vs Mutable vs Unique

@Metadata {
    @DisplayName("Shared vs Mutable vs Unique")
    @TitleHeading("Ownership Primitives")
}

Pick a heap-owned cell by two questions: *do I need exclusive ownership or shared ownership?* and *do I need mutation or read-only access?*

## Decision Matrix

| Need | Type | Sendability |
|------|------|-------------|
| Exclusive owner, deterministic cleanup | ``Ownership/Unique`` | `Sendable` when `Value: Sendable` |
| Shared owner, immutable payload | ``Ownership/Shared`` | `Sendable` when `Value: Sendable` |
| Shared owner, mutable payload | ``Ownership/Mutable`` | **Not `Sendable`** |
| Shared owner, mutable payload, explicit `@unchecked Sendable` opt-in | ``Ownership/Mutable/Unchecked`` | `@unsafe @unchecked Sendable` |

All four are heap-allocated. Unique carries a single owner through deinit cleanup (SE-0517 `UniqueBox` semantic); Shared and Mutable carry ARC-based multi-owner semantics through their `final class` backing.

## When to Use ``Ownership/Unique``

`Unique` is the default when you want the SE-0517 `UniqueBox<T>` shape: one value on the heap, one owner, automatic deallocation. The type is `~Copyable` — the compiler prevents accidental duplication and the resulting double-free risk. Ownership transfers by move; `consume()` destroys the cell and yields the value.

Use `Unique` when:

- You need heap storage for a `~Copyable` `Value` (e.g., a resource handle that can't be trivially copied).
- You want deterministic cleanup at `deinit` without ARC overhead.
- You intend to move the value out later via `consume()`.
- You're transferring ownership into `Transfer.Cell` / `Transfer.Storage` once (see <doc:Ownership-Transfer-Recipes>).

## When to Use ``Ownership/Shared``

`Shared` is an ARC-retained reference to an immutable value on the heap. The `final class` backing permits multiple owners; the payload is read-only. Because the value cannot change after construction, `Shared<Value>` is safely `Sendable` when `Value: Sendable`.

Use `Shared` when:

- You want to cheaply pass a large `~Copyable` value across many owners.
- The value is conceptually immutable after construction (configuration, parsed document, static catalogue).
- You need `Sendable` without special synchronization.

## When to Use ``Ownership/Mutable`` / ``Ownership/Mutable/Unchecked``

`Mutable` is ARC-retained and mutation-capable. Because mutation on a shared reference is racy by default, `Mutable` is deliberately **not** `Sendable`. For single-isolation-domain code, this is the right shape: multiple references, all confined to one actor or one synchronization context.

For cross-isolation cases where you've proven (at the call site) that synchronization is external — a lock, an actor, an atomic — use `Mutable.Unchecked`. It is `@unsafe @unchecked Sendable`: the compiler trusts you, and `grep` finds every escape.

Use `Mutable` (plain) when:

- Multiple references to one mutable value within one actor or synchronization scope.
- No cross-actor transfer.

Use `Mutable.Unchecked` when:

- External synchronization is established and callers can point to the mechanism in review.
- Plain `Mutable` would force unwanted isolation boundaries.

## Unique vs Transfer Family

`Unique` holds its value for the lifetime of the owner; `Transfer.*` holds a value *in transit* across a `@Sendable` boundary. If you need to move a `~Copyable` `Value` from one thread / task to another, wrap it in a `Transfer.Cell` or `Transfer.Storage` — not a `Unique` — and `take()` on the other side. See <doc:Ownership-Transfer-Recipes>.

## See Also

- ``Ownership/Unique``
- ``Ownership/Shared``
- ``Ownership/Mutable``
- ``Ownership/Mutable/Unchecked``
- <doc:Ownership-Transfer-Recipes>
