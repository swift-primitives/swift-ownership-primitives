# Ownership Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Safe ownership references and cells for `~Copyable` / `~Escapable` / `Copyable` values — fifteen primitives spanning scoped references, heap-owned cells, atomic slots, and cross-boundary transfer — on production Swift 6.3.1.

---

## Key Features

- **Stdlib-parity borrows and inouts, today** — `Ownership.Borrow` and `Ownership.Inout` mirror SE-0519's `Borrow<T>` / `Inout<T>` (SwiftStdlib 6.4) with `@safe` conformance. They work on 6.3.1 via `_read` / `nonmutating _modify` coroutines so downstream code runs before `BorrowAndMutateAccessors` (SE-0507) ships in a stable toolchain.
- **SE-0517 `UniqueBox` parity** — `Ownership.Unique<Value>` mirrors `UniqueBox`: `init(_:)`, `consume()`, `clone()`, `var value { _read _modify }`, `span` / `mutableSpan`. The Institute rendering uses the `Nest.Name` form (`Ownership.Unique`) rather than the compound `UniqueBox`.
- **Copy-on-write value cell** — `Ownership.Indirect<Value>` wraps a `Copyable` value in heap storage with lazy CoW on `_modify`; parallels Swift's `indirect` keyword on recursive enum cases. Deferred physical copy until divergent mutation.
- **One-shot and reusable atomic cells** — `Ownership.Slot` cycles empty ↔ full for resource pools and channels; `Ownership.Latch` is terminal after take, for single-publication hand-off.
- **Cross-boundary transfer matrix** — `Transfer.Value<V>.{Outgoing, Incoming}`, `Transfer.Retained<T>.{Outgoing, Incoming}`, and `Transfer.Erased.{Outgoing, Incoming}` fill the two-axis matrix of direction × payload kind. Tokens are `Copyable` for closure capture; only one `take` / `store` / `consume` succeeds atomically.
- **`Optional<~Copyable>.take()`** — Consumes the wrapped value in place and leaves `nil`; stdlib has no equivalent on `~Copyable` `Wrapped`.

---

## Quick Start

### Heap-owned `~Copyable` cell

```swift
import Ownership_Primitives

var request = Ownership.Unique(Request.get("/status"))   // Request is ~Copyable
request.value.timeout = .seconds(30)                      // _modify coroutine
let owned = request.consume()                             // destroys the cell
```

The hand-rolled equivalent for a `~Copyable` `Value`:

```swift
let storage = UnsafeMutablePointer<Request>.allocate(capacity: 1)
storage.initialize(to: .get("/status"))
// every exit path must run:
storage.deinitialize(count: 1)
storage.deallocate()
```

`Ownership.Unique` folds allocation, lifetime tracking, and `deinit` cleanup into one `@safe`, `~Copyable` struct — matching the SE-0517 `UniqueBox<Value>` shape exactly.

### Scoped mutable reference with safe lifetime

```swift
import Ownership_Primitives

struct Editor<Base: ~Copyable>: ~Copyable, ~Escapable {
    private let ref: Ownership.Inout<Base>

    @_lifetime(&base)
    init(_ base: inout Base) {
        self.ref = Ownership.Inout(mutating: &base)
    }

    func apply(_ mutation: (inout Base) -> Void) {
        mutation(&ref.value)    // nonmutating _modify — routes through &base
    }
}
```

`Ownership.Inout` is storable as a `~Copyable, ~Escapable` field: you cannot store `inout Base` directly (inout can't be stored), and `UnsafeMutablePointer<Base>` carries no lifetime. `Ownership.Inout` is `@safe`, lifetime-bounded to `&base` at the init site, and preserves CoW on `base.value` mutations.

### Consuming an `Optional<~Copyable>`

```swift
import Ownership_Primitives

var slot: Handle? = acquire()                 // Handle is ~Copyable
guard let handle = slot.take() else { return }
// slot == nil; `handle` is consumed
```

`take()` is a mutating extension on `Optional where Wrapped: ~Copyable`. It `consume self`, reassigns `nil` to the storage, and returns the wrapped value — the stdlib does not provide this shape.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-ownership-primitives.git", from: "0.1.0")
]
```

The package uses a **primary decomposition** — consumers depend on the specific variant they use, not the umbrella. Pick the narrow product(s):

```swift
.target(
    name: "App",
    dependencies: [
        // Scoped references
        .product(name: "Ownership Borrow Primitives", package: "swift-ownership-primitives"),
        .product(name: "Ownership Inout Primitives", package: "swift-ownership-primitives"),
        // Heap-owned cells
        .product(name: "Ownership Unique Primitives", package: "swift-ownership-primitives"),
        .product(name: "Ownership Shared Primitives", package: "swift-ownership-primitives"),
        .product(name: "Ownership Mutable Primitives", package: "swift-ownership-primitives"),
        // Reusable atomic slot + one-shot latch
        .product(name: "Ownership Slot Primitives", package: "swift-ownership-primitives"),
        .product(name: "Ownership Latch Primitives", package: "swift-ownership-primitives"),
        // Heap CoW value cell
        .product(name: "Ownership Indirect Primitives", package: "swift-ownership-primitives"),
        // Cross-boundary transfer family (kind x direction matrix)
        .product(name: "Ownership Transfer Primitives", package: "swift-ownership-primitives"),
        .product(name: "Ownership Transfer Erased Primitives", package: "swift-ownership-primitives"),
        // Optional<~Copyable>.take()
        .product(name: "Ownership Primitives Standard Library Integration", package: "swift-ownership-primitives"),
    ]
)
```

The umbrella product `Ownership Primitives` is available for prototyping and tests — it re-exports every variant via `@_exported public import`. Release builds SHOULD depend on the narrow variants to minimize the consumer's compile-time surface.

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux / Windows toolchain).

---

## Adoption

Downstream packages store `Ownership.Inout<Base>` / `Ownership.Borrow<Base>` as the reference-shape for fluent-accessor primitives. Canonical shape from `swift-property-primitives`:

```swift
extension Property.View {
    internal var _storage: Tagged<Tag, Ownership.Inout<Base>>

    public var base: Ownership.Inout<Base> {
        @_lifetime(borrow self)
        _read { yield _storage.rawValue }
    }
}
```

A `Property.View` is `~Copyable, ~Escapable`, stores its mutable reference as `Ownership.Inout<Base>` (wrapped by `Tagged` for phantom-typed namespace discrimination), and yields it back through a `_read` coroutine. `swift-buffer-primitives` uses the same shape on ring / linear / slab accessors to return typed, lifetime-bounded references instead of raw `UnsafeMutablePointer`.

---

## Overview

| Type | Purpose |
|------|---------|
| `Ownership.Borrow<Value>` | Scoped read-only reference (`Copyable, ~Escapable`) |
| `Ownership.Inout<Value>` | Scoped mutable reference (`~Copyable, ~Escapable`) |
| `Ownership.Unique<Value>` | Heap-owned exclusive cell — SE-0517 `UniqueBox` parity (`consume()`, `clone()`, `value { _read _modify }`, `span` / `mutableSpan`) |
| `Ownership.Shared<Value>` | ARC-shared immutable cell |
| `Ownership.Mutable<Value>` | ARC-shared mutable cell (single-isolation) |
| `Ownership.Mutable.Unchecked<Value>` | `@unchecked Sendable` opt-in variant of `Mutable` |
| `Ownership.Slot<Value>` | Reusable atomic heap slot — cycles empty ↔ full |
| `Ownership.Latch<Value>` | One-shot atomic cell — terminal after `take()` |
| `Ownership.Indirect<Value>` | Heap-allocated copy-on-write value cell |
| `Ownership.Transfer.Value<V>.Outgoing` / `.Incoming` | One-shot generic transfer across `@Sendable` (direction × kind matrix) |
| `Ownership.Transfer.Retained<T>.Outgoing` / `.Incoming` | Zero-alloc-outgoing / single-latch-incoming `AnyObject` transfer |
| `Ownership.Transfer.Erased.Outgoing` / `.Incoming` | Type-erased boxed transfer |
| `Optional<Wrapped>.take()` | Consume and reset on `~Copyable` `Wrapped` (mutating extension) |

`Ownership.Borrow.`Protocol`` is the canonical borrow-capability protocol; conform via `extension MyType: Ownership.Borrow.`Protocol` {}` to participate without a bespoke accessor.

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 26 | Full support |
| Linux | Full support |
| Windows | Full support |
| iOS / tvOS / watchOS / visionOS | Supported |
| Swift Embedded | Supported |

---

## Stability

`swift-ownership-primitives` is **pre-1.0** and follows SemVer
pre-release semantics: minor-version bumps within `0.x` MAY introduce
source-breaking changes. The package will reach `1.0` when the
remaining items below are settled.

**Source-stability commitment for `0.x`**:

- The public initializer surface of `Ownership.Borrow`,
  `Ownership.Inout`, `Ownership.Unique`, `Ownership.Shared`,
  `Ownership.Mutable`, `Ownership.Slot`, `Ownership.Latch`, and
  `Ownership.Transfer.{Value, Retained, Erased}.{Outgoing, Incoming}`
  is intended to be source-stable through `1.0`.
- Internal storage shapes (`_pointer` / `_owner` / `_storage` fields,
  hoisted state-constant modules, fileprivate helper classes) are
  implementation details and free to change between `0.x` minors.
- The `Ownership.Borrow.\`Protocol\`` capability typealias and its
  hoisted `__Ownership_Borrow_Protocol` backing exist to work around
  SE-0404 (no nested protocols inside generic types). The
  capability-conformance contract — adopt `Ownership.Borrow.\`Protocol\``
  to gain a canonical borrow path — is source-stable.

**Migration to stdlib SE-0519 `Borrow<T>` / `Inout<T>`**:

When SE-0519 stabilises in stdlib, this package will:

1. Deprecate `Ownership.Borrow` / `Ownership.Inout` in favour of
   stdlib `Borrow<T>` / `Inout<T>`.
2. Provide a migration guide and a deprecation window of at least
   one minor version (`0.N` → `0.N+1`) before removal.
3. Retain the `Ownership.Borrow.\`Protocol\`` capability typealias
   as an alias to the stdlib equivalent (or its closest analog) for
   adopters who took the capability conformance.
4. Remove the heap-owning Copyable workaround in
   `Ownership.Borrow.init(borrowing:)`. Stdlib's register-pass
   miscompile fix means the workaround becomes unnecessary.

The owned-storage primitives (`Unique`, `Shared`, `Mutable`,
`Slot`, `Latch`) and the Transfer family are NOT covered by SE-0519
and are not expected to be deprecated as part of this transition.

**Known accepted-as-known constraints in 0.1.0**:

- `Ownership.Borrow.init(borrowing:)` for `Copyable Value` heap-allocates
  a class-owned copy. The cost is documented inline; the workaround
  is required by the pre-SE-0519 toolchain.
- `Ownership.Borrow.init(borrowing:)` for `~Copyable Value` is
  non-`@inlinable` to preserve the cross-module `@in_guaranteed`
  ABI; same-module consumers must use the `init(_ pointer:)`
  overload. Documented at the call site.

---

## Design choices

**Per-type vs relation-parametric shape**: an alternative shape was
considered — a single parametric `Ownership<Relation, Value>` type
discriminated by a phantom-tag relation (mirroring `Tagged<Tag, RawValue>`
and `Property<Tag, Base>`). The per-type shape was chosen for
**stdlib SE-0519 alignment**: the stdlib `Borrow<T>` and `Inout<T>`
types under SE-0519 are per-type, not relation-parametric. Adopting a
parametric shape now would force a deprecation refactor when SE-0519
stabilises. The per-type shape anticipates the language's eventual
direction; the cost is a slightly larger surface at 0.1.0.

---

## Related Packages

**Used By**:

- [swift-property-primitives](https://github.com/swift-primitives/swift-property-primitives) — stores `Tagged<Tag, Ownership.Inout<Base>>` / `Tagged<Tag, Ownership.Borrow<Base>>` as the canonical `Property.View` / `Property.View.Read` storage shape.
- [swift-buffer-primitives](https://github.com/swift-primitives/swift-buffer-primitives) — returns `Ownership.Borrow` / `Ownership.Inout` from ring, linear, and slab buffer accessors for typed, lifetime-bounded element references.

---

## License

Apache 2.0. See [LICENSE](LICENSE.md).
