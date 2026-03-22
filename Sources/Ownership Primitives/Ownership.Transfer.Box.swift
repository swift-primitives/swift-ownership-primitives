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

extension Ownership.Transfer {
    /// Type-erased boxing for ownership transfer.
    ///
    /// ## Design
    /// Each box is a single allocation containing:
    /// - Header at the start (destroy function + payload offset)
    /// - Payload at aligned offset after header
    ///
    /// This enables:
    /// - Single allocation per box (reduced from 2)
    /// - Correct destruction without knowing `T` or `E` (for abandonment paths)
    /// - Type-safe unboxing when the caller knows `T` and `E`
    /// - No leaks in cancel-wait-but-drain paths
    ///
    /// ## Memory Layout
    /// ```
    /// [Header (at offset 0)] [padding] [Payload (at aligned offset)]
    /// ```
    /// The payload offset is computed to satisfy the payload type's alignment.
    ///
    /// ## Ownership Rules
    /// **Invariant:** Exactly one party allocates, exactly one party frees.
    ///
    /// - **Allocation:** `make()` or `makeValue()` allocates the unified block
    /// - **Deallocation:** Either `take()`/`takeValue()` or `destroy()` deallocates
    ///
    /// **Never call both `take*()` and `destroy()` on the same pointer.**
    ///
    public enum Box {}
}

// MARK: - Header

extension Ownership.Transfer.Box {
    /// Header for type-erased box with inline payload.
    ///
    /// ## Memory Layout
    /// The entire box is a single allocation:
    /// ```
    /// [Header at offset 0] [padding] [Payload at payloadOffset]
    /// ```
    ///
    /// The `payloadOffset` is computed to satisfy the payload type's alignment
    /// requirements. The destroy function takes the base pointer and offset
    /// to locate and deinitialize the payload.
    ///
    /// ## Why Closure (Future: Replace with Thin Function Pointer)
    /// The closure captures `T` and `E` type information needed for proper
    /// deinitialization. Ideally we'd use `@convention(thin)` function pointers
    /// with `unsafeBitCast` to erase the generic signature, eliminating the
    /// closure allocation. However:
    /// - Swift 6.2.3 crashes when `unsafeBitCast`ing generic thin function pointers
    /// - Static witness-per-specialization patterns are blocked by Swift restrictions
    ///
    /// Revisit when the compiler bug is fixed.
    @safe
    fileprivate struct Header {
        /// Function to destroy the payload given base pointer and offset.
        /// Captures type information (T, E) for proper deinitialization.
        let destroyPayload: (UnsafeMutableRawPointer, Int) -> Void

        /// Offset from base pointer to payload (for alignment).
        let payloadOffset: Int
    }
}

// MARK: - Pointer

extension Ownership.Transfer.Box {
    /// Sendable capability wrapper for boxed pointers.
    ///
    /// This is the only `@unchecked Sendable` in the box internals.
    /// It represents a capability to consume or destroy a box, and
    /// concentrates the unsafe sendability at the boundary.
    @safe
    public struct Pointer: @unchecked Sendable {
        public let raw: UnsafeMutableRawPointer
        @unsafe
        public init(_ raw: UnsafeMutableRawPointer) { unsafe (self.raw = raw) }
    }
}

// MARK: - Boxing

extension Ownership.Transfer.Box {
    /// Allocate and initialize a boxed value.
    ///
    /// Returns a pointer to the erased header. Use `take<T>` to unbox
    /// or `destroy` to free without unboxing.
    ///
    /// ## Single Allocation
    /// The header and payload are stored in a single contiguous allocation.
    /// The payload is placed at an aligned offset after the header.
    @unsafe
    public static func make<T: Sendable>(
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
                destroyPayload: { base, offset in
                    unsafe (base + offset).assumingMemoryBound(to: T.self)
                        .deinitialize(count: 1)
                },
                payloadOffset: payloadOffset
            )
        )

        // Store payload at aligned offset
        let payloadPtr = unsafe (ptr + payloadOffset).assumingMemoryBound(to: T.self)
        unsafe payloadPtr.initialize(to: value)

        return unsafe ptr
    }

    /// Unbox and deallocate a value.
    ///
    /// Moves the value out of the box and deallocates all memory.
    /// Caller must provide the correct T type.
    @unsafe
    public static func take<T: Sendable>(
        _ ptr: UnsafeMutableRawPointer
    ) -> T {
        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        let header = unsafe headerPtr.move()  // releases closure
        let payloadPtr = unsafe (ptr + header.payloadOffset).assumingMemoryBound(to: T.self)
        let result = unsafe payloadPtr.move()
        // Single deallocation for entire box
        unsafe ptr.deallocate()
        return result
    }
}

// MARK: - Type-Erased Destruction

extension Ownership.Transfer.Box {
    /// Destroy a boxed value without reading it.
    ///
    /// Correctly deinitializes the payload (running destructors for T and E)
    /// and deallocates all memory. Safe to call without knowing T or E.
    ///
    /// - Important: Uses `move()` on Header before deallocate to properly
    ///   release the closure and balance the initialization from `make()`.
    @unsafe
    public static func destroy(_ ptr: UnsafeMutableRawPointer) {
        let headerPtr = unsafe ptr.assumingMemoryBound(to: Header.self)
        let header = unsafe headerPtr.move()  // releases closure
        unsafe header.destroyPayload(ptr, header.payloadOffset)
        // Single deallocation for entire box
        unsafe ptr.deallocate()
    }
}
