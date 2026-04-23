# Ownership Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Safe ownership references for `~Copyable` / `~Escapable` values — `Ownership.Borrow`, `Ownership.Inout`, `Ownership.Unique`, `Ownership.Slot`, and the `Ownership.Transfer.*` family — on production Swift 6.3.1.

---

## Key Features

- **Stdlib-parity borrows and inouts, today** — `Ownership.Borrow` and `Ownership.Inout` mirror SE-0519's `Borrow<T>` / `Inout<T>` (SwiftStdlib 6.4) with `@safe` conformance and `@inlinable` accessors. They work on 6.3.1 via `_read` / `nonmutating _modify` coroutines, so downstream code runs before `BorrowAndMutateAccessors` (SE-0507) ships in a stable toolchain.
- **Interior mutability through `nonmutating _modify`** — `Ownership.Inout.value` splits on copyability: `get` + `nonmutating _modify` for `Copyable` `Value`, `_read` + `nonmutating _modify` for `~Copyable`. Nested method-call mutations (`base.value.pop.front()`) route through the stored pointer, preserving CoW uniqueness; pure reads on `Copyable` `Value` escape the coroutine lifetime chain.
- **Heap-owned `~Copyable` cell** — `Ownership.Unique<Value>` exposes `withValue`, `withMutableValue`, `take`, `hasValue` over a `@safe` struct with deterministic `deinit`; replaces the manual `allocate` / `initialize(to:)` / track-initialized / `deinitialize` / `deallocate` pattern.
- **Cross-boundary transfer with exactly-once semantics** — `Ownership.Transfer.Cell`, `.Storage`, `.Retained`, and `.Box` move values across `@Sendable` boundaries; tokens are `Copyable` for closure capture, but only one `take` / `store` succeeds atomically.
- **`Optional<~Copyable>.take()`** — Consumes the wrapped value in place and leaves `nil`; stdlib has no equivalent on `~Copyable` `Wrapped`, so this is the canonical pattern for moving out of a `~Copyable` optional stored property.

---

## Quick Start

### Heap-owned `~Copyable` cell

```swift
import Ownership_Primitives

var request = Ownership.Unique(Request.get("/status"))   // Request is ~Copyable
request.withMutableValue { $0.timeout = .seconds(30) }
let owned = request.take()                               // request.hasValue == false
```

The hand-rolled equivalent for a `~Copyable` `Value`:

```swift
let storage = UnsafeMutablePointer<Request>.allocate(capacity: 1)
storage.initialize(to: .get("/status"))
var isInitialized = true
// ... every exit path must run:
if isInitialized { storage.deinitialize(count: 1) }
storage.deallocate()
```

`Ownership.Unique` folds allocation, initialization tracking, take/leak semantics, and `deinit` cleanup into one `@safe`, `~Copyable` struct.

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

The package is a **primary decomposition** per [MOD-015] — consumers depend on the specific variant they use, not the umbrella. Pick the narrow product(s):

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
        // Reusable atomic slot
        .product(name: "Ownership Slot Primitives", package: "swift-ownership-primitives"),
        // Cross-boundary transfer family
        .product(name: "Ownership Transfer Primitives", package: "swift-ownership-primitives"),
        .product(name: "Ownership Transfer Box Primitives", package: "swift-ownership-primitives"),
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
| `Ownership.Unique<Value>` | Heap-owned exclusive cell with `withValue` / `withMutableValue` / `take` — `~Copyable`, also available on `Copyable Value` |
| `Ownership.Shared<Value>` | ARC-shared immutable cell |
| `Ownership.Mutable<Value>` | ARC-shared mutable cell |
| `Ownership.Mutable.Unchecked<Value>` | `@unchecked Sendable` opt-in variant of `Mutable` |
| `Ownership.Slot<Value>` | Atomic heap slot with `store` / `take` / `move.in` / `move.out` — reusable, `@unchecked Sendable` |
| `Ownership.Transfer.Cell<Value>` | One-shot transfer: pass an existing value through `@Sendable` |
| `Ownership.Transfer.Storage<Value>` | One-shot transfer: create inside a closure, retrieve after |
| `Ownership.Transfer.Retained<Value>` | Zero-alloc one-shot transfer for `AnyObject` |
| `Ownership.Transfer.Box<Value>` | Type-erased boxed transfer |
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

## Related Packages

**Used By**:

- [swift-property-primitives](https://github.com/swift-primitives/swift-property-primitives) — stores `Tagged<Tag, Ownership.Inout<Base>>` / `Tagged<Tag, Ownership.Borrow<Base>>` as the canonical `Property.View` / `Property.View.Read` storage shape.
- [swift-buffer-primitives](https://github.com/swift-primitives/swift-buffer-primitives) — returns `Ownership.Borrow` / `Ownership.Inout` from ring, linear, and slab buffer accessors for typed, lifetime-bounded element references.

---

## License

Apache 2.0. See [LICENSE](LICENSE.md).
