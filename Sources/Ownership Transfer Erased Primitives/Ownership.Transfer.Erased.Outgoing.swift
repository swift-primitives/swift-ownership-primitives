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

// MARK: - Erased.Outgoing

extension Ownership.Transfer.Erased {
    /// Outgoing type-erased transfer — producer boxes an arbitrary value
    /// into a single contiguous allocation whose header carries enough
    /// information to destruct the payload without knowing `T` at the
    /// consumer site.
    ///
    /// The payload's concrete type is agreed between producer and consumer
    /// out of band. Correct destruction is preserved even on abandoned
    /// paths — if neither `consume(_:)` nor any reader reaches the unboxing
    /// call, `destroy()` still releases the payload without type info.
    ///
    /// ## Memory Layout
    /// A single allocation contains `[Header][padding][Payload]`, where the
    /// payload offset satisfies the payload's alignment requirement.
    ///
    /// ## Ownership Rules
    /// **Invariant:** exactly one party allocates, exactly one party
    /// deallocates.
    ///
    /// - **Allocation:** `init(_:)` allocates the unified block.
    /// - **Deallocation:** `consume(_:)` or `destroy()` deallocates.
    ///
    /// **Never call both `consume(_:)` and `destroy()` on the same value.**
    public enum Outgoing {}
}

// MARK: - Boxing

extension Ownership.Transfer.Erased.Outgoing {
    /// Allocate and initialize a boxed value.
    ///
    /// Returns an opaque pointer to the header. Use `consume(_:)` to unbox,
    /// or `destroy(_:)` to free without unboxing.
    ///
    /// The header and payload share a single contiguous allocation; the
    /// payload is placed at an aligned offset after the header.
    @unsafe
    public static func make<T>(
        _ value: T
    ) -> UnsafeMutableRawPointer {
        let headerSize = MemoryLayout<Header>.size
        let headerAlignment = MemoryLayout<Header>.alignment
        let payloadSize = MemoryLayout<T>.size
        let payloadAlignment = MemoryLayout<T>.alignment

        // Align payload offset properly
        let payloadOffset = (headerSize + payloadAlignment - 1) & ~(payloadAlignment - 1)
        let totalSize = payloadOffset + payloadSize
        let alignment = max(headerAlignment, payloadAlignment)

        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: totalSize,
            alignment: alignment
        )

        // Store header at start (includes payloadOffset for destroy)
        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        unsafe headerPtr.initialize(
            to: Header(
                payloadOffset: payloadOffset,
                destroyPayload: { base, offset in
                    unsafe (base + offset).assumingMemoryBound(to: T.self)
                        .deinitialize(count: 1)
                }
            )
        )

        // Store payload at aligned offset
        let payloadPtr = unsafe (ptr + payloadOffset).assumingMemoryBound(to: T.self)
        unsafe payloadPtr.initialize(to: value)

        return unsafe ptr
    }

    /// Unbox and deallocate a value.
    ///
    /// Moves the value out of the box and deallocates all memory. The caller
    /// must provide the correct `T` type that the box was created with.
    @unsafe
    public static func consume<T>(
        _ ptr: UnsafeMutableRawPointer
    ) -> T {
        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        let header = unsafe headerPtr.move()  // releases closure
        let payloadPtr = unsafe (ptr + header.payloadOffset).assumingMemoryBound(to: T.self)
        let result = unsafe payloadPtr.move()
        unsafe ptr.deallocate()
        return result
    }
}

// MARK: - Type-Erased Destruction

extension Ownership.Transfer.Erased.Outgoing {
    /// Destroy a boxed value without reading it.
    ///
    /// Correctly deinitializes the payload (running the original destructor
    /// captured by `make(_:)`) and deallocates all memory. Safe to call
    /// without knowing the payload type.
    ///
    /// - Important: Uses `move()` on the header before deallocate to
    ///   properly release the closure and balance the initialization from
    ///   `make(_:)`.
    @unsafe
    public static func destroy(_ ptr: UnsafeMutableRawPointer) {
        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        let header = unsafe headerPtr.move()  // releases closure
        unsafe header.destroyPayload(ptr, header.payloadOffset)
        unsafe ptr.deallocate()
    }
}
