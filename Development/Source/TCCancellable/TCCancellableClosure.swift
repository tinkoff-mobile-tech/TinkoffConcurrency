/// An object that captures a closure to execute upon cancellation.
public final class TCCancellableClosure: TCCancellable {

    // MARK: - Private Properties

    private let lock = NSLock()

    private let cancellationClosure: () -> Void

    private var _isCancelled = false

    // MARK: - Public Properties

    /// A value that indicates whether the cancellation was performed.
    ///
    /// After the value of this property becomes `true`, it remains `true` indefinitely.
    public var isCancelled: Bool {
        defer { lock.unlock() }

        lock.lock()

        return _isCancelled
    }

    // MARK: - Initializers

    /// Initializes an instance.
    /// - Parameters:
    ///   - cancellationClosure: The closure to execute upon cancellation.
    public init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    // MARK: - TCCancellable

    /// Executes the captured closure.
    ///
    /// Sets the value of the ``TCCancellableClosure/isCancelled`` property to `true`.
    ///
    /// Repeated calls of this method will be ignored.
    public func cancel() {
        lock.lock()

        guard !_isCancelled else {
            lock.unlock()

            return
        }

        _isCancelled = true

        lock.unlock()

        cancellationClosure()
    }
}
