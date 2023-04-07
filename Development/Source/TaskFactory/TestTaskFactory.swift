import Foundation

/// Factory for using in tests.
/// It is helpful for waiting for guaranteed completion of all asynchronous tasks and performing asserts without expectations.
public final class TestTaskFactory {
    
    // MARK: - Private Properties
    
    private let lock = NSLock()
    private var tasks: [any ITask] = []

    private var firstTask: (any ITask)? {
        lock.withLock { tasks.first }
    }
    
    // MARK: - Initializers

    public init() {}
    
    // MARK: - Public Methods

    /// Wait until all created tasks will be completed.
    public func runUntilIdle() async throws {
        while let task = firstTask {
            _ = try await task.value
            _ = lock.withLock {
                tasks.removeFirst()
            }
        }
    }
}

// MARK: - ITaskFactory

extension TestTaskFactory: ITaskFactory {
    @discardableResult
    public func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> AnyTask<T, Error> {
        lock.withLock {
            let task = Task(priority: priority, operation: operation)
            tasks.append(task)
            return task.erased()
        }
    }
}
