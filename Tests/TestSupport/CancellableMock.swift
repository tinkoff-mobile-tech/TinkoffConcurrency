import TinkoffConcurrency

final class TCCancellableMock: TCCancellable {

    var invokedCancelCount = 0
    var invokedCancel: Bool {
        return invokedCancelCount > 0
    }

    func cancel() {
        invokedCancelCount += 1
    }
}
