import Foundation

extension NSRecursiveLock {

    // MARK: - Methods

    @discardableResult
    public func access<T>(_ executionBlock: () -> T) -> T {
        defer { unlock() }

        lock()

        return executionBlock()
    }
}
