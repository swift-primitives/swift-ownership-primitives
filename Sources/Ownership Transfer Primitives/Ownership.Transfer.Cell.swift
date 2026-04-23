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
    /// Heap cell for passing a ~Copyable value through an escaping boundary.
    ///
    /// Use Cell when you have an existing value and need to pass it through
    /// an escaping `@Sendable` closure.
    ///
    /// ## Ownership Model
    /// - `init(_:)` moves the value into ARC-managed storage
    /// - `token()` produces a Sendable token and consumes the cell
    /// - `token.take()` consumes the value (exactly once, enforced atomically)
    ///
    /// ## Usage
    /// ```swift
    /// let cell = Ownership.Transfer.Cell(myValue)
    /// let token = cell.token()
    /// spawnThread {
    ///     let value = token.take()
    ///     // use value
    /// }
    /// ```
    public struct Cell<T: ~Copyable>: ~Copyable {
        @usableFromInline
        let _box: _Box<T>

        /// Creates a cell containing the given value.
        ///
        /// - Parameter value: The value to store (ownership transferred).
        public init(_ value: consuming T) {
            _box = _Box(value)
        }
    }
}

// MARK: - Token

extension Ownership.Transfer.Cell where T: ~Copyable {
    /// Token representing ownership of a value in a Cell.
    ///
    /// ## Safety
    /// - `Sendable`: Can cross thread boundaries safely
    /// - `Copyable`: Can be captured in escaping closures (required for lane/thread use)
    /// - ARC-managed: Strong reference to box, no retain-count hazards
    /// - Atomic one-shot: `take()` enforced atomically, second call traps
    ///
    /// ## Thread Safety
    /// Multiple copies of a token may exist (it's Copyable), but only one
    /// `take()` call will succeed. Additional calls trap deterministically.
    ///
    /// ## Invariants
    /// - `take()` must be called exactly once across all copies
    /// - Calling `take()` twice (on any copy) traps with a clear error message
    public struct Token: Sendable {
        /// Strong reference to the box. ARC manages lifetime.
        @usableFromInline
        let _box: Ownership.Transfer._Box<T>

        @usableFromInline
        init(_ box: Ownership.Transfer._Box<T>) {
            self._box = box
        }
    }
}

// MARK: - Token Take

extension Ownership.Transfer.Cell.Token where T: ~Copyable {
    /// Atomically takes the stored value.
    ///
    /// - Returns: The stored value.
    /// - Precondition: Must be called exactly once across all token copies.
    ///   Second call traps with a clear error message.
    public func take() -> T {
        _box.take()
    }
}

// MARK: - Cell Operations

extension Ownership.Transfer.Cell where T: ~Copyable {
    /// Produces a Sendable token and consumes the cell.
    ///
    /// After calling this method, the cell cannot be used again.
    /// The token represents exclusive ownership of the stored value
    /// and must be consumed by calling `take()` exactly once.
    ///
    /// - Returns: A Sendable token.
    public consuming func token() -> Token {
        Token(_box)
    }
}
