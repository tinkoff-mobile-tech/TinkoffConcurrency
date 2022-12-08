import XCTest
@testable import TinkoffConcurrency

final class CancellableTests: XCTestCase {

    // MARK: - Tests

    func test_сancellableClosure_isCancelled() {
        // when
        let cancellable = CancellableClosure { }

        // then
        XCTAssertFalse(cancellable.isCancelled)
    }

    func test_сancellableClosure_cancel() {
        // given
        var isCancellationClosureCalled = false

        let cancellationClosure: () -> Void = {
            isCancellationClosureCalled = true
        }

        let cancellable = CancellableClosure(cancellationClosure: cancellationClosure)

        // when
        cancellable.cancel()

        // then
        XCTAssertTrue(isCancellationClosureCalled)

        XCTAssertTrue(cancellable.isCancelled)
    }
}
