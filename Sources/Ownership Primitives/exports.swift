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

// Umbrella — re-exports every variant module so `import Ownership_Primitives`
// gives access to the full family. For narrower compile-time surface,
// consumers SHOULD depend on specific variant products per [MOD-015]
// primary decomposition.

@_exported public import Ownership_Namespace
@_exported public import Ownership_Primitives_Core
@_exported public import Ownership_Borrow_Primitives
@_exported public import Ownership_Inout_Primitives
@_exported public import Ownership_Unique_Primitives
@_exported public import Ownership_Shared_Primitives
@_exported public import Ownership_Mutable_Primitives
@_exported public import Ownership_Slot_Primitives
@_exported public import Ownership_Latch_Primitives
@_exported public import Ownership_Indirect_Primitives
@_exported public import Ownership_Transfer_Primitives
@_exported public import Ownership_Transfer_Erased_Primitives
@_exported public import Ownership_Primitives_Standard_Library_Integration
