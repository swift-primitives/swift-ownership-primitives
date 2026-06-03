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

extension Ownership.Indirect where Value: Copyable {
    /// Heap storage class.
    ///
    /// CoW replaces `_storage` when not uniquely referenced rather
    /// than mutating in place through a shared reference.
    @usableFromInline
    final class Storage {
        @usableFromInline
        var value: Value

        @usableFromInline
        init(_ value: consuming Value) {
            self.value = value
        }
    }
}
