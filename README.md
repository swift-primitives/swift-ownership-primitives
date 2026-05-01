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
    .package(url: "https://github.com/swift-primitives/swift-ownership-primitives.git", branch: "main")
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

`swift-ownership-primitives` follows SemVer pre-release semantics in 0.x.

| Surface | 0.1.x expectation |
|---|---|
| Public type names + initializer surface for the fifteen primitives | Stable within 0.1.x |
| `Ownership.Borrow.\`Protocol\`` capability-conformance contract | Stable within 0.1.x |
| Internal storage shapes / hoisted helper modules / fileprivate helper classes | Not part of the source-stability commitment |

Notes on possible interaction with SE-0519 are tracked in [`Research/stdlib-interaction-notes.md`](./Research/stdlib-interaction-notes.md).

---

## Related Packages

**Used By**:

- [swift-property-primitives](https://github.com/swift-primitives/swift-property-primitives) — stores `Tagged<Tag, Ownership.Inout<Base>>` / `Tagged<Tag, Ownership.Borrow<Base>>` as the canonical `Property.View` / `Property.View.Read` storage shape.
- [swift-buffer-primitives](https://github.com/swift-primitives/swift-buffer-primitives) — returns `Ownership.Borrow` / `Ownership.Inout` from ring, linear, and slab buffer accessors for typed, lifetime-bounded element references.

---

## License

Apache 2.0. See [LICENSE](LICENSE.md).
