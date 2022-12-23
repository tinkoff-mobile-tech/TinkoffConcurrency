import XCTest
import protocol Combine.Cancellable

// MARK: - BFMCancellable

final class CancellableMock: Cancellable {

    // MARK: - cancel

    var invokedCancelCount = 0
    var invokedCancel: Bool {
        return invokedCancelCount > 0
    }

    func cancel() {
        invokedCancelCount += 1
    }
}
