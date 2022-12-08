import Foundation
import protocol Combine.Cancellable

/// A cancellables storage.
public final class CancellablesStorage: Cancellable {

    // MARK: - Nested Types

    public enum State {

        // MARK: - Cases

        /// cancellables are being collected
        case active

        /// Stored cancellables have been cancelled, new cancellables are cancelled at once
        case cancelled

        /// Stored cancellables have been discarded, new cancellables are discarded at once
        case deactivated
    }

    // MARK: - Private Properties

    private let lock = NSLock()

    private var cancellables: [Cancellable] = []

    private var _state = State.active

    // MARK: - Initializers

    public init() { }

    // MARK: - Cancellable

    /// Cancels all cancellables.
    ///
    /// All next invocations of ``deactivate()`` and ``cancel()`` are ignored.
    /// All cancellables that were added after this method is called are cancelled at once.
    public func cancel() {
        lock.lock()

        if _state != State.active {
            return lock.unlock()
        }

        _state = State.cancelled

        let cancellables = self.cancellables

        lock.unlock()

        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Public Methods

    /// A storage state.
    public var state: State {
        lock.lock()
        defer { lock.unlock() }

        return _state
    }

    /// Adds a cancellable.
    ///
    /// - Parameter cancellable: a cancellable to add
    /// - Returns: `true`, if cancellable was added to storage. `false` if it was not. cancellable will not be added if storage
    ///    is already cancelled or deactivated
    @discardableResult public func add(_ cancellable: Cancellable) -> Bool {
        lock.lock()

        switch _state {
        case .active:
            cancellables.append(cancellable)

            lock.unlock()

            return true

        case .cancelled:
            lock.unlock()

            cancellable.cancel()

            return false

        case .deactivated:
            lock.unlock()

            return false
        }
    }

    /// Discards all cancellables.
    ///
    /// All next invocations of ``deactivate()`` and ``cancel()`` are ignored.
    /// All cancellables that were added after this method is called are discarded at once.
    public func deactivate() -> Bool {
        lock.lock()

        if _state != State.active {
            lock.unlock()

            return false
        }

        _state = State.deactivated

        lock.unlock()

        return true
    }
}
