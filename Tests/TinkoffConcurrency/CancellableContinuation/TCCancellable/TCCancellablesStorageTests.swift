import XCTest

@testable import TinkoffConcurrency

final class CancellablesStorageTests: XCTestCase {

    // MARK: - Dependencies

    private var cancellablesStorage: TCCancellablesStorage!

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()

        cancellablesStorage = TCCancellablesStorage()
    }

    override func tearDown() {
        super.tearDown()

        cancellablesStorage = nil
    }

    // MARK: - Tests

    func test_cancellablesStorage_state() {
        // then
        XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.active)
    }

    func test_cancellablesStorage_add() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            // when
            let result = cancellablesStorage.add(cancellable)

            // then
            XCTAssertTrue(result)
        }

        XCTAssertFalse(cancellableDeinited)
    }

    func test_cancellablesStorage_add_whenStateIsCancelled() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            cancellablesStorage.cancel()

            // when
            let result = cancellablesStorage.add(cancellable)

            // then
            XCTAssertFalse(result)

            XCTAssertTrue(cancellable.invokedCancel)
        }

        XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.cancelled)

        XCTAssertTrue(cancellableDeinited)
    }

    func test_cancellablesStorage_add_whenStateIsDeactivated() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            _ = cancellablesStorage.deactivate()

            // when
            let result = cancellablesStorage.add(cancellable)

            // then
            XCTAssertFalse(result)

            XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.deactivated)

            XCTAssertFalse(cancellable.invokedCancel)
        }

        XCTAssertTrue(cancellableDeinited)
    }

    func test_cancellablesStorage_cancel() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            cancellablesStorage.add(cancellable)

            // when
            cancellablesStorage.cancel()

            // then
            XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.cancelled)

            XCTAssertEqual(cancellable.invokedCancelCount, 1)
        }

        XCTAssertTrue(cancellableDeinited)
    }

    func test_cancellablesStorage_cancel_whenStateIsCancelled() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            cancellablesStorage.add(cancellable)

            cancellablesStorage.cancel()

            // when
            cancellablesStorage.cancel()

            // then
            XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.cancelled)

            XCTAssertEqual(cancellable.invokedCancelCount, 1)
        }

        XCTAssertTrue(cancellableDeinited)
    }

    func test_cancellablesStorage_cancel_whenStateIsDeactivated() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            cancellablesStorage.add(cancellable)

            _ = cancellablesStorage.deactivate()

            // when
            cancellablesStorage.cancel()

            // then
            XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.deactivated)

            XCTAssertFalse(cancellable.invokedCancel)
        }

        XCTAssertTrue(cancellableDeinited)
    }

    func test_cancellablesStorage_deactivate() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            cancellablesStorage.add(cancellable)

            // when
            let result = cancellablesStorage.deactivate()

            // then
            XCTAssertTrue(result)

            XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.deactivated)

            XCTAssertFalse(cancellable.invokedCancel)
        }

        XCTAssertTrue(cancellableDeinited)
    }

    func test_cancellablesStorage_deactivate_whenStateIsCancelled() {
        // given
        var cancellableDeinited = false

        do {
            let cancellable = TCCancellableMock()

            cancellable.onDeinit = { cancellableDeinited = true }

            cancellablesStorage.add(cancellable)

            cancellablesStorage.cancel()

            // when
            let result = cancellablesStorage.deactivate()

            // then
            XCTAssertFalse(result)

            XCTAssertEqual(cancellablesStorage.state, TCCancellablesStorage.State.cancelled)

            XCTAssertEqual(cancellable.invokedCancelCount, 1)
        }

        XCTAssertTrue(cancellableDeinited)
    }
}
