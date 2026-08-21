@usableFromInline
enum __OwnershipLatchState {}

extension __OwnershipLatchState {
    @usableFromInline static let empty: Int = 0
    @usableFromInline static let initializing: Int = 1
    @usableFromInline static let full: Int = 2
    @usableFromInline static let taken: Int = 3
}
