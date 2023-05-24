import TinkoffConcurrency

class RetainingCancellable: TCCancellable {
    
    // MARK: - Private Properties

    private let completion: (Result<Void, Error>) -> Void
    private let onDeinit: () -> Void
 
    // MARK: - Initializers

    init(completion: @escaping (Result<Void, Error>) -> Void, onDeinit: @escaping () -> Void) {
        self.completion = completion
        self.onDeinit = onDeinit
    }
    
    deinit {
        onDeinit()
    }

    // MARK: - TCCancellable

    func cancel() {
        completion(.failure(CancellationError()))
    }
}

class RetainingCancellableProcessor {
    
    // MARK: - Methods

    func performJob(shouldFinish: Bool, completion: @escaping (Result<Void, Error>) -> Void, onDeinit: @escaping () -> Void) -> TCCancellable {
        if shouldFinish {
            completion(.success(()))
        }

        return RetainingCancellable(completion: completion, onDeinit: onDeinit)
    }
}
