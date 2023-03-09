import Foundation

extension NSLock {

    // MARK: - Methods

    public func access<T>(_ executionBlock: () -> T) -> T {
        defer { unlock() }

        lock()

        return executionBlock()
    }
}
