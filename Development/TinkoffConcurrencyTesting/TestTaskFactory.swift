import Foundation
import TinkoffConcurrency

/// Factory for using in tests.
/// It is helpful for waiting for guaranteed completion of all asynchronous tasks and performing asserts without expectations.
public final class TCTestTaskFactory {
    
    // MARK: - Private Properties
    
    private let lock = NSLock()
    private var tasks: [any ITask] = []

    // MARK: - Initializers

    public init() {}
    
    // MARK: - Public Methods

    /// Wait until all created tasks will be completed.
    public func runUntilIdle() async {
        while let task = popTask() {
            await task.wait()
        }
    }

    // MARK: - Private Methods
    
    private func addTask(_ task: any ITask) {
        lock.lock()
        defer {
            lock.unlock()
        }

        tasks.append(task)
    }

    private func popTask() -> (any ITask)? {
        lock.lock()
        defer {
            lock.unlock()
        }

        return tasks.popLast()
    }
}

extension TCTestTaskFactory: ITCTaskFactory {
    
    // MARK: - ITCTaskFactory

    @discardableResult
    public func task<T: Sendable>(
        priority: TaskPriority?,
        @_inheritActorContext operation: @escaping @Sendable () async throws -> T
    ) -> Task<T, Error> {
        let task = Task(priority: priority, operation: operation)
        
        addTask(task)
        
        return task
    }
}
