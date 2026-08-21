@usableFromInline
enum __OwnershipSlotState {}

extension __OwnershipSlotState {
    @usableFromInline static let empty: UInt8 = 0
    @usableFromInline static let initializing: UInt8 = 1
    @usableFromInline static let full: UInt8 = 2
    @usableFromInline static let draining: UInt8 = 3
}
