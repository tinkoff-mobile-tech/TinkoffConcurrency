import Foundation

extension NSLock {

    // MARK: - Methods

    public func access<T>(_ executionBlock: () throws -> T) rethrows -> T {
        defer { unlock() }

        lock()

        return try executionBlock()
    }
}
