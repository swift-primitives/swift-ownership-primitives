// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Ownership.Transfer.Erased.Outgoing {
    // WORKAROUND: `destroyPayload` is a heap-allocating closure instead of a
    //             `@convention(thin)` function pointer.
    // WHY: A closure returning `@convention(thin) (Ptr, Int) -> Void` whose
    //      body captures a generic `T` (to call `.deinitialize(count: 1)`)
    //      fails to compile with
    //        `INTERNAL ERROR: feature not implemented: nontrivial thin
    //         function reference`
    //      on Apple Swift 6.3.1.
    // WHEN TO REMOVE: when a toolchain accepts generic-capturing thin
    //                 function references.
    // TRACKING: swift-institute/Experiments/unsafe-bitcast-generic-thin-function-pointer/
    //           (STILL PRESENT on 6.3.1, verified 2026-04-23).
    // SAFETY: Encapsulates unsafe internals behind a safe API; see
    // SAFETY: [MEM-SAFE-024] for the absorber-pattern taxonomy.
    /// Header for the erased box with inline payload.
    ///
    /// `package` (not `fileprivate`): the single-type-per-file convention
    /// [API-IMPL-005] moved this out of `Ownership.Transfer.Erased.Outgoing.swift`,
    /// so `fileprivate` would hide it from the boxing/destruction extensions that
    /// still need it. `package` (rather than `internal`) keeps it off the
    /// module's consumer-observable surface — it carries no public API of its
    /// own — and stays exempt from [API-NAME-002]'s compound-identifier check
    /// per that rule's `package`-scope carve-out.
    @safe
    package struct Header {
        /// Function to destroy the payload given base pointer and offset.
        package let destroyPayload: (UnsafeMutableRawPointer, Int) -> Void

        /// Offset from base pointer to payload (for alignment).
        package let payloadOffset: Int

        package init(
            payloadOffset: Int,
            destroyPayload: @escaping (UnsafeMutableRawPointer, Int) -> Void
        ) {
            self.payloadOffset = payloadOffset
            unsafe (self.destroyPayload = destroyPayload)
        }
    }
}
