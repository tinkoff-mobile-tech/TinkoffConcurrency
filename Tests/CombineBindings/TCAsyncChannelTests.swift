import XCTest
import Combine
import TinkoffConcurrency

final class TCAsyncChannelTests: XCTestCase {

    // MARK: - Tests

    func test_tcAsyncChannel_send() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        var result1 = [Int]()
        var completion1: Subscribers.Completion<Never>?

        var result2 = [Int]()
        var completion2: Subscribers.Completion<Never>?

        var cancellables = Set<AnyCancellable>()

        channel.sink {
            completion1 = $0
        } receiveValue: {
            result1.append($0)
        }.store(in: &cancellables)

        channel.sink {
            completion2 = $0
        } receiveValue: {
            result2.append($0)
        }.store(in: &cancellables)

        // when
        await XCTExecuteThrowsNoError(try await channel.send(0))
        await XCTExecuteThrowsNoError(try await channel.send(1))
        await XCTExecuteThrowsNoError(try await channel.send(2))

        XCTAssertNoThrow(try channel.send(completion: .finished))

        // then
        XCTAssertEqual(result1, [0, 1, 2])
        XCTAssertEqual(completion1, .finished)

        XCTAssertEqual(result2, [0, 1, 2])
        XCTAssertEqual(completion2, .finished)
    }

    func test_tcAsyncChannel_send_withBackpressure() async throws {
        // given
        guard #available(iOS 15.0, *) else {
            throw XCTSkip("iOS 15 required")
        }

        let channel = TCAsyncChannel<Int, Never>()

        async let task1 = channel.asyncValues.reduce(into: [], { $0.append($1) })
        async let task2 = channel.values.reduce(into: [], { $0.append($1) })

        // when

        // Дадим подзадачам стартовать
        await Task.megaYield()

        await XCTExecuteThrowsNoError(try await channel.send(0))
        await XCTExecuteThrowsNoError(try await channel.send(1))
        await XCTExecuteThrowsNoError(try await channel.send(2))

        XCTAssertNoThrow(try channel.send(completion: .finished))

        // then
        let result1 = await task1

        XCTAssertEqual(result1, [0, 1, 2])

        let result2 = await task2

        XCTAssertEqual(result2, [0, 1, 2])
    }

    func test_tcAsyncChannel_send_whenOneSubscriberIsNotImmediatelyReady() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        var result1 = [Int]()
        var completion1: Subscribers.Completion<Never>?

        var result2 = [Int]()
        var completion2: Subscribers.Completion<Never>?

        var secondSubscription: Subscription?

        let subscriber1 = AnySubscriber<Int, Never> { subscription in
            subscription.request(.max(1))
        } receiveValue: {
            result1.append($0)
            return .max(1)
        } receiveCompletion: {
            completion1 = $0
        }

        let subscriber2 = AnySubscriber<Int, Never> { subscription in
            secondSubscription = subscription
        } receiveValue: {
            result2.append($0)
            return .max(1)
        } receiveCompletion: {
            completion2 = $0
        }

        channel.subscribe(subscriber1)
        channel.subscribe(subscriber2)

        // when
        async let first: () = channel.send(0)

        secondSubscription?.request(.max(1))

        try await first

        await XCTExecuteThrowsNoError(try await channel.send(1))

        XCTAssertNoThrow(try channel.send(completion: .finished))

        // then
        XCTAssertEqual(result1, [0, 1])
        XCTAssertEqual(completion1, .finished)

        XCTAssertEqual(result2, [0, 1])
        XCTAssertEqual(completion2, .finished)
    }

    func test_tcAsyncChannel_send_whenAccessedConcurrently() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        var result1 = [Int]()
        var completion1: Subscribers.Completion<Never>?

        var result2 = [Int]()
        var completion2: Subscribers.Completion<Never>?

        var secondSubscription: Subscription?

        let subscriber1 = AnySubscriber<Int, Never> { subscription in
            subscription.request(.max(1))
        } receiveValue: {
            result1.append($0)
            return .max(1)
        } receiveCompletion: {
            completion1 = $0
        }

        let subscriber2 = AnySubscriber<Int, Never> { subscription in
            secondSubscription = subscription
        } receiveValue: {
            result2.append($0)
            return .max(1)
        } receiveCompletion: {
            completion2 = $0
        }

        channel.subscribe(subscriber1)
        channel.subscribe(subscriber2)

        // when
        async let first: () = channel.send(0)

        // хак, пока не подъедут инструменты для работы с шедулерами.
        // Тут нам нужно, чтобы верхняя строчка начала выполняться.
        await Task.megaYield()

        let sendError = await XCTExecuteThrowsError(try await channel.send(1))

        let completionError = try { XCTExecuteThrowsError(try channel.send(completion: .finished)) }()

        // then
        XCTAssertEqualErrors(sendError, TCAsyncChannelErrors.concurrentAccess)

        XCTAssertEqualErrors(completionError, TCAsyncChannelErrors.concurrentAccess)

        // Дальше проверим, что штатная работа не была нарушена
        secondSubscription?.request(.max(1))

        try await first

        await XCTExecuteThrowsNoError(try await channel.send(1))

        XCTAssertNoThrow(try channel.send(completion: .finished))

        XCTAssertEqual(result1, [0, 1])
        XCTAssertEqual(completion1, .finished)

        XCTAssertEqual(result2, [0, 1])
        XCTAssertEqual(completion2, .finished)
    }

    func test_tcAsyncChannel_send_whenHungSubscriberIsCancelled() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        var result1 = [Int]()
        var completion1: Subscribers.Completion<Never>?

        var result2 = [Int]()
        var completion2: Subscribers.Completion<Never>?

        let subscriber1 = AnySubscriber<Int, Never> { subscription in
            subscription.request(.max(1))
        } receiveValue: {
            result1.append($0)
            return .max(1)
        } receiveCompletion: {
            completion1 = $0
        }

        var secondSubscription: Subscription?

        let subscriber2 = AnySubscriber<Int, Never> { subscription in
            secondSubscription = subscription
        } receiveValue: {
            result2.append($0)
            return .max(1)
        } receiveCompletion: {
            completion2 = $0
        }

        channel.subscribe(subscriber1)
        channel.subscribe(subscriber2)

        // when
        async let first: () = channel.send(0)

        secondSubscription?.cancel()

        try await first

        await XCTExecuteThrowsNoError(try await channel.send(1))

        XCTAssertNoThrow(try channel.send(completion: .finished))

        // then
        XCTAssertEqual(result1, [0, 1])
        XCTAssertEqual(completion1, .finished)

        XCTAssertEqual(result2, [])
        XCTAssertNil(completion2)
    }

    func test_tcAsyncChannel_send_whenNoSubscribers() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        var result = [Int]()

        let subscriber = AnySubscriber<Int, Never> { subscription in
            subscription.request(.max(1))
        } receiveValue: {
            result.append($0)
            return .max(1)
        } receiveCompletion: { _ in
            XCTFail()
        }

        // when
        async let sendResult: () = channel.send(1)

        await Task.megaYield()

        channel.subscribe(subscriber)

        try await sendResult

        // then
        XCTAssertEqual(result, [1])
    }

    func test_tcAsyncChannel_send_whenSubjectHasAlreadyFinished() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        // when
        XCTAssertNoThrow(try channel.send(completion: .finished))

        // then
        let sendError = await XCTExecuteThrowsError(try await channel.send(Int.fake()))

        XCTAssertEqualErrors(sendError, TCAsyncChannelErrors.outputToFinished)

        let completionError = try { self.XCTExecuteThrowsError(try channel.send(completion: .finished)) }()

        XCTAssertEqualErrors(completionError, TCAsyncChannelErrors.outputToFinished)
    }

    func test_tcAsyncChannel_send_whenUnsubscribedWithoutDemand() async throws {
        // given
        let value = Int.fake()

        let channel = TCAsyncChannel<Int, Never>()

        var subscription: Subscription?

        let subscriber = AnySubscriber<Int, Never> {
            subscription = $0
        } receiveValue: { _ in
            XCTFail()
            return .none
        } receiveCompletion: { _ in
            XCTFail()
        }

        let subscriber2 = SubscriberMock<Int, Never>()

        // when
        channel.subscribe(subscriber)

        async let result: () = channel.send(value)

        await Task.megaYield()

        subscription?.cancel()

        channel.subscribe(subscriber2)

        try await result

        XCTAssertNoThrow(try channel.send(completion: .finished))

        // then
        XCTAssertEqual(subscriber2.receivedValues, [value])
        XCTAssertEqual(subscriber2.receivedCompletion, .finished)
    }

    func test_tcAsyncChannel_send_cancel() async {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        let taskStarted = expectation(description: "taskStarted")

        let testStarted = expectation(description: "testStarted")

        var result = [Int]()
        var completion: Subscribers.Completion<Never>?

        var cancellables = Set<AnyCancellable>()

        channel.sink {
            completion = $0
        } receiveValue: {
            result.append($0)
        }.store(in: &cancellables)

        // when
        let task = Task {
            await XCTExecuteThrowsNoError(try await channel.send(0))

            taskStarted.fulfill()

            await XCTWaiter.waitAsync(for: [testStarted], timeout: 1)

            await XCTExecuteCancels(try await channel.send(1))
        }

        await XCTWaiter.waitAsync(for: [taskStarted], timeout: 1)

        task.cancel()

        testStarted.fulfill()

        _ = await task.result

        // then
        XCTAssertEqual(result, [0])
        XCTAssertEqual(completion, .finished)
    }

    func test_tcAsyncChannel_send_cancel_whenOneSubscriberIsNotImmediatelyReady() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        let taskStarted = expectation(description: "taskStarted")

        let testStarted = expectation(description: "testStarted")

        var result1 = [Int]()
        var completion1: Subscribers.Completion<Never>?

        var result2 = [Int]()
        var completion2: Subscribers.Completion<Never>?

        let subscriber1 = AnySubscriber<Int, Never> { subscription in
            subscription.request(.max(1))
        } receiveValue: {
            result1.append($0)
            return .max(1)
        } receiveCompletion: {
            completion1 = $0
        }

        let subscriber2 = AnySubscriber<Int, Never> { _ in
        } receiveValue: {
            result2.append($0)
            return .max(1)
        } receiveCompletion: {
            completion2 = $0
        }

        channel.subscribe(subscriber1)
        channel.subscribe(subscriber2)

        // when
        let task = Task {
            async let first: () = channel.send(0)

            await Task.megaYield()

            taskStarted.fulfill()

            await XCTWaiter.waitAsync(for: [testStarted], timeout: 1)

            do {
                // Capturing 'async let' variables is not supported
                try await first
            } catch is CancellationError {

            } catch {
                XCTFail("Unexpected error: \(error.localizedDescription)")
            }
        }

        await XCTWaiter.waitAsync(for: [taskStarted], timeout: 1)

        task.cancel()

        testStarted.fulfill()

        _ = await task.result

        // then
        XCTAssertEqual(result1, [])
        XCTAssertEqual(completion1, .finished)

        XCTAssertEqual(result2, [])
        XCTAssertEqual(completion2, .finished)
    }

    func test_tcAsyncChannel_subscribe_whenChannelIsFinished() async throws {
        // given
        let channel = TCAsyncChannel<Int, Never>()

        let subscriber = SubscriberMock<Int, Never>()

        // when
        XCTAssertNoThrow(try channel.send(completion: .finished))

        channel.subscribe(subscriber)

        // then
        XCTAssertEqual(subscriber.receivedValues, [])
        XCTAssertEqual(subscriber.receivedCompletion, .finished)
    }

    func test_tcAsyncChannel_subscribe_whenChannelIsFailed() async throws {
        // given
        let channel = TCAsyncChannel<Int, FakeErrors>()

        let subscriber = SubscriberMock<Int, FakeErrors>()

        // when
        XCTAssertNoThrow(try channel.send(completion: .failure(FakeErrors.default)))

        channel.subscribe(subscriber)

        // then
        XCTAssertEqual(subscriber.receivedValues, [])
        XCTAssertEqual(subscriber.receivedCompletion, .failure(FakeErrors.default))
    }
}
