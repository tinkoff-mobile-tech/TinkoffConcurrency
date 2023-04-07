import Foundation

extension NSLock {
    
    // MARK: - Methods
    
    public func withLock<T>(_ body: () throws -> T) rethrows -> T {
        defer { self.unlock() }
        self.lock()
        return try body()
    }
}
