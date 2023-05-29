import TinkoffConcurrency

final class TCCancellableMock: TCCancellable {
    
    var onDeinit: (() -> Void)?

    var invokedCancelCount = 0
    var invokedCancel: Bool {
        return invokedCancelCount > 0
    }

    func cancel() {
        invokedCancelCount += 1
    }
    
    deinit {
        onDeinit?()
    }
}
