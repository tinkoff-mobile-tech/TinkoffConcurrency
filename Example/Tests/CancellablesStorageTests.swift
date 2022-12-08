import XCTest
@testable import TinkoffConcurrency

final class CancellablesStorageTests: XCTestCase {

    // MARK: - Dependencies

    private var cancellablesStorage: CancellablesStorage!

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()

        cancellablesStorage = CancellablesStorage()
    }

    override func tearDown() {
        super.tearDown()

        cancellablesStorage = nil
    }

    // MARK: - Tests

    func test_cancellablesStorage_state() {
        // then
        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.active)
    }

    func test_cancellablesStorage_add() {
        // given
        let cancellable = CancellableMock()

        // when
        let result = cancellablesStorage.add(cancellable)

        // then
        XCTAssertTrue(result)
    }

    func test_cancellablesStorage_add_whenStateIsCancelled() {
        // given
        let cancellable = CancellableMock()

        cancellablesStorage.cancel()

        // when
        let result = cancellablesStorage.add(cancellable)

        // then
        XCTAssertFalse(result)

        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.cancelled)

        XCTAssertTrue(cancellable.invokedCancel)
    }

    func test_cancellablesStorage_add_whenStateIsDeactivated() {
        // given
        let cancellable = CancellableMock()

        _ = cancellablesStorage.deactivate()

        // when
        let result = cancellablesStorage.add(cancellable)

        // then
        XCTAssertFalse(result)

        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.deactivated)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_cancellablesStorage_cancel() {
        // given
        let cancellable = CancellableMock()

        cancellablesStorage.add(cancellable)

        // when
        cancellablesStorage.cancel()

        // then
        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.cancelled)

        XCTAssertEqual(cancellable.invokedCancelCount, 1)
    }

    func test_cancellablesStorage_cancel_whenStateIsCancelled() {
        // given
        let cancellable = CancellableMock()

        cancellablesStorage.add(cancellable)

        cancellablesStorage.cancel()

        // when
        cancellablesStorage.cancel()

        // then
        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.cancelled)

        XCTAssertEqual(cancellable.invokedCancelCount, 1)
    }

    func test_cancellablesStorage_cancel_whenStateIsDeactivated() {
        // given
        let cancellable = CancellableMock()

        cancellablesStorage.add(cancellable)

        _ = cancellablesStorage.deactivate()

        // when
        cancellablesStorage.cancel()

        // then
        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.deactivated)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_cancellablesStorage_deactivate() {
        // given
        let cancellable = CancellableMock()

        cancellablesStorage.add(cancellable)

        // when
        let result = cancellablesStorage.deactivate()

        // then
        XCTAssertTrue(result)

        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.deactivated)

        XCTAssertFalse(cancellable.invokedCancel)
    }

    func test_cancellablesStorage_deactivate_whenStateIsCancelled() {
        // given
        let cancellable = CancellableMock()

        cancellablesStorage.add(cancellable)

        cancellablesStorage.cancel()

        // when
        let result = cancellablesStorage.deactivate()

        // then
        XCTAssertFalse(result)

        XCTAssertEqual(cancellablesStorage.state, CancellablesStorage.State.cancelled)

        XCTAssertEqual(cancellable.invokedCancelCount, 1)
    }
}
