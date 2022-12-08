import Foundation
@_exported import protocol Combine.Cancellable

/// Отменяемая операция модуля "Приведи Друга".
public final class CancellableClosure: Cancellable {

    // MARK: - Private Properties

    private let lock = NSLock()

    /// Замыкание, которое будет запущено при отмене.
    private let cancellationClosure: () -> Void

    /// Признак отмены.
    private var _isCancelled = false

    // MARK: - Initializers

    /// Инициализирует экземпляр отменяемой операции.
    /// - Parameters:
    ///   - cancellationClosure: Замыкание, которое будет запущено при отмене.
    public init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    // MARK: - Cancellable

    /// Признак отмены.
    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }

        return _isCancelled
    }

    /// Отменяет операцию.
    ///
    /// Повторный вызов игнорируется.
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
