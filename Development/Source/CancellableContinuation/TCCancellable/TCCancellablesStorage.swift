import Foundation

/// A storage of cancellable operations.
public final class TCCancellablesStorage: TCCancellable, @unchecked Sendable {

    // MARK: - Nested Types

    /// An enumeration of the storage's states.
    public enum State {

        // MARK: - Cases

        /// An active state that is initial.
        ///
        /// In this state, a cancellable operation can be added using ``TCCancellablesStorage/add(_:)`` method.
        ///
        /// Calls of methods ``TCCancellablesStorage/cancel()`` and
        /// ``TCCancellablesStorage/deactivate()`` will have effect.
        case active

        /// A cancelled state indicating that all added cancellable operations were cancelled.
        ///
        /// In this state, not only a cancellable operation can **not** be added using
        /// ``TCCancellablesStorage/add(_:)`` method, but it also will be **cancelled**.
        ///
        /// Calls of methods ``TCCancellablesStorage/cancel()`` and
        /// ``TCCancellablesStorage/deactivate()`` are ignored.
        case cancelled

        /// A deactivated state indicating that all added cancellable operations were discarded.
        ///
        /// In this state, a cancellable operation can **not** be added using
        /// ``TCCancellablesStorage/add(_:)`` method and will be **ignored**.
        ///
        /// Calls of methods ``TCCancellablesStorage/cancel()`` and
        /// ``TCCancellablesStorage/deactivate()`` are ignored.
        case deactivated
    }

    // MARK: - Private Properties

    private let lock = NSLock()

    private var cancellables: [TCCancellable] = []

    private var _state = State.active

    // MARK: - Public Properties

    /// A state of the storage.
    public var state: State {
        defer { lock.unlock() }

        lock.lock()

        return _state
    }

    // MARK: - Initializers

    /// Initializes an instance.
    public init() { }

    // MARK: - TCCancellable

    /// Cancels all added cancellable operations.
    ///
    /// Repeated calls of this method will be ignored.
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

    /// Adds a cancellable operation.
    ///
    /// If the storage is in the ``TCCancellablesStorage/State-swift.enum/cancelled``
    /// state, cancellable operation will **not** be added and will be **cancelled**.
    ///
    /// If the storage is in the ``TCCancellablesStorage/State-swift.enum/deactivated``
    /// state, cancellable operation will **not** be added and will be **ignored**.
    ///
    /// - Parameters:
    ///   - cancellable: The cancellable operation to add.
    /// - Returns: `true` if the cancellable operation was added; otherwise returns `false`.
    @discardableResult public func add(_ cancellable: TCCancellable) -> Bool {
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

    /// Discards all added cancellable operations.
    ///
    /// Repeated calls of this method will be ignored.
    ///
    /// - Returns: `true` if the storage was in the ``TCCancellablesStorage/State-swift.enum/active``
    /// state before the method was called; otherwise returns `false`.
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

extension ITask {
    @discardableResult public func store(in storage: TCCancellablesStorage) -> Bool {
        storage.add(self)
    }
}
