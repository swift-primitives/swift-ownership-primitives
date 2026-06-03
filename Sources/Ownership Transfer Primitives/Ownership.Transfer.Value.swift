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
    /// Value-typed transfer namespace.
    ///
    /// Use ``Ownership/Transfer/Value/Outgoing`` when the producer already
    /// holds the value and wants to hand it across a `@Sendable` boundary.
    /// Use ``Ownership/Transfer/Value/Incoming`` when the consumer creates an
    /// empty slot for the producer to fill later.
    public enum Value<V: ~Copyable> {}
}
