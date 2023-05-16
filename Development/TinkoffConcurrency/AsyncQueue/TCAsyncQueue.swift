public final actor TCAsyncQueue {
    
    // MARK: - Dependencies

    private let taskFactory: ITCTaskFactory
    
    // MARK: - Private Properties

    private var lastEnqueuedTask: ITask?
    
    // MARK: - Initializers

    public init(taskFactory: ITCTaskFactory) {
        self.taskFactory = taskFactory
    }
    
    // MARK: - Methods
    
    @discardableResult
    public func enqueue<T>(operation: @escaping @Sendable () async -> T) -> Task<T, Never> {
        let lastEnqueuedTask = lastEnqueuedTask
        
        let task = taskFactory.task {
            await lastEnqueuedTask?.wait()
            
            return await operation()
        }
        
        self.lastEnqueuedTask = task
        
        return task
    }
    
    @discardableResult
    public func enqueue<T>(operation: @escaping @Sendable () async throws -> T) -> Task<T, Error> {
        let lastEnqueuedTask = lastEnqueuedTask
        
        let task = taskFactory.task {
            await lastEnqueuedTask?.wait()
            
            return try await operation()
        }
        
        self.lastEnqueuedTask = task
        
        return task
    }
}
