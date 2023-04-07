import Foundation

/// Generic safe `@unchecked Sendable` for using with entities which can be tricky to make Sendable
public final class UncheckedSendable<T>: @unchecked Sendable {
    
    // MARK: - Public Properties
    
    public var value: T {
        lock.withLock { _value }
    }
    
    // MARK: - Private Properties
    
    private let lock = NSLock()
    private var _value: T
    
    // MARK: - Initializers

    public init(_ value: T) {
        self._value = value
    }
    
    // MARK: - Public Methods

    @discardableResult
    public func mutate<R>(_ body: (inout T) throws -> R) rethrows -> R {
        try lock.withLock {
            try body(&_value)
        }
    }
}
