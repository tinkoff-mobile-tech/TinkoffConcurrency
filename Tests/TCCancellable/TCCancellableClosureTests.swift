import XCTest

@testable import TinkoffConcurrency

final class CancellableTests: XCTestCase {

    // MARK: - Tests

    func test_cancellableClosure_isCancelled() {
        // when
        let cancellable = TCCancellableClosure { }

        // then
        XCTAssertFalse(cancellable.isCancelled)
    }

    func test_сancellableClosure_cancel() {
        // given
        var isCancellationClosureCalled = false

        let cancellationClosure: () -> Void = {
            isCancellationClosureCalled = true
        }

        let cancellable = TCCancellableClosure(cancellationClosure: cancellationClosure)

        // when
        cancellable.cancel()

        // then
        XCTAssertTrue(isCancellationClosureCalled)

        XCTAssertTrue(cancellable.isCancelled)
    }
}
