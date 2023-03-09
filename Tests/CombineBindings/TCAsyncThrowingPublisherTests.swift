import XCTest
import Combine
import CombineSchedulers
import TinkoffConcurrency

final class TCAsyncThrowingPublisherTests: XCTestCase {

    // MARK: - Tests

    func test_tcAsyncThrowingPublisher_send() async {
        // given
        let input = Array<Int>.fake(min: 3) { $0 }

        let publisher = input.publisher

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let result = await XCTExecuteThrowsNoError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqual(input, result)
    }

    func test_tcAsyncThrowingPublisher_failure() async {
        // given
        let error = FakeErrors.default

        let publisher = Fail<Int, FakeErrors>(error: error)

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let resultError = await XCTExecuteThrowsError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqualErrors(error, resultError)
    }

    func test_tcAsyncThrowingPublisher_send_empty() async {
        // given
        let publisher = Empty<Int, Never>()

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let result = await XCTExecuteThrowsNoError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqual([], result)
    }

    func test_tcAsyncThrowingPublisher_send_whenCompletedBeforeSubscription() async {
        // given
        let publisher = PublisherMock<Int, Never>()

        publisher.willSubscribe = { subscriber, subscription in
            subscriber.receive(completion: .finished)
        }

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let result = await XCTExecuteThrowsNoError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqual([], result)
    }

    func test_tcAsyncThrowingPublisher_demand() async throws {
        // given
        let input = Array<Int>.fake(min: 3) { $0 }

        let publisher = PassthroughSubject<Int, Never>()

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        // then
        input.forEach { publisher.send($0) }
        publisher.send(completion: .finished)

        let result = await XCTExecuteThrowsNoError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        XCTAssertEqual([], result)
    }

    func test_tcAsyncThrowingPublisher_cancel() async throws {
        // given
        let readerStarted = expectation(description: "reader started")

        let testStarted = expectation(description: "test started")

        let publisher = PublisherMock<Int, Never>()

        publisher.willSubscribe = { subscriber, subscription in
            subscription.onRequest = { demand in
                XCTAssertEqual(demand.max, 1)

                DispatchQueue.global().async {
                    _ = XCTWaiter.wait(for: [testStarted], timeout: 1)

                    let additional = subscriber.receive(1)

                    XCTAssertEqual(additional, .none)
                }
            }
        }

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let task = Task {
            var iterator = sequence.makeAsyncIterator()

            readerStarted.fulfill()

            _ = try await iterator.next()

            XCTFail()
        }

        // then

        await XCTWaiter.waitAsync(for: [readerStarted], timeout: 1)

        task.cancel()

        testStarted.fulfill()

        await XCTExecuteCancels(try await task.value)

        XCTAssertEqual(publisher.subscriptions.count, 1)

        let publisherSubscription = publisher.subscriptions[0]

        XCTAssertEqual(publisherSubscription.history, [.requested(.max(1)), .cancelled])
    }

    func test_tcAsyncThrowingPublisher_empty() async {
        // given
        let publisher = Empty<Int, Never>()

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let result = await XCTExecuteThrowsNoError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqual([], result)
    }

    func test_tcAsyncThrowingPublisher_emptyDelayed() async {
        // given
        let publisher = PublisherMock<Int, Never>()

        publisher.willSubscribe = { subscriber, subscription in
            subscription.onRequest = { demand in
                subscriber.receive(completion: .finished)
            }
        }

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let result = await XCTExecuteThrowsNoError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqual([], result)
    }

    func test_tcAsyncThrowingPublisher_cancelEarly() async throws {
        // given
        let testStarted = expectation(description: "test started")

        let publisher = PublisherMock<Int, Never>()

        publisher.willSubscribe = { _, subscription in
            subscription.onRequest = { demand in
                XCTFail()
            }
        }

        // when
        let sequence = TCAsyncThrowingPublisher(publisher)

        let task = Task {
            await XCTWaiter.waitAsync(for: [testStarted], timeout: 1)

            for try await _ in sequence {
                XCTFail()
            }
        }

        // then
        task.cancel()

        testStarted.fulfill()

        await XCTExecuteCancels(try await task.value)

        XCTAssertEqual(publisher.subscriptions.count, 1)

        let publisherSubscription = publisher.subscriptions[0]

        XCTAssertEqual(publisherSubscription.history, [.cancelled])
    }

    func test_tcAsyncThrowingPublisher_cancelBeforeSubscribed() async throws {
        // given
        let testStarted = expectation(description: "test started")

        let readerStarted = expectation(description: "reader started")

        let publisher = PublisherMock<Int, Never>()

        let scheduler = DispatchQueue.test

        publisher.willSubscribe = { _, _ in
            XCTFail()
        }

        // when
        let sequence = TCAsyncThrowingPublisher(publisher.subscribe(on: scheduler.eraseToAnyScheduler()))

        let task = Task {
            var iterator = sequence.makeAsyncIterator()

            readerStarted.fulfill()

            await XCTWaiter.waitAsync(for: [testStarted], timeout: 1)

            _ = try await iterator.next()

            XCTFail()
        }

        // then
        await XCTWaiter.waitAsync(for: [readerStarted], timeout: 1)

        task.cancel()

        testStarted.fulfill()

        await XCTExecuteCancels(try await task.value)

        XCTAssertEqual(publisher.subscriptions.count, 0)
    }

    func test_tcAsyncThrowingPublisher_cancelBeforeSubscribedAfterConsume() async throws {
        // given
        let readerStarted = expectation(description: "reader started")

        let publisher = PublisherMock<Int, Never>()

        let scheduler = DispatchQueue.test

        publisher.willSubscribe = { _, subscription in
            subscription.onRequest = { demand in
                XCTFail()
            }
        }

        // when
        let sequence = TCAsyncThrowingPublisher(publisher.subscribe(on: scheduler.eraseToAnyScheduler()))

        let task = Task {
            var iterator = sequence.makeAsyncIterator()

            readerStarted.fulfill()

            _ = try await iterator.next()

            XCTFail()
        }

        // then
        await XCTWaiter.waitAsync(for: [readerStarted], timeout: 1)

        task.cancel()

        scheduler.run()

        await XCTExecuteCancels(try await task.value)
    }

    func test_tcAsyncThrowingPublisher_combineCompatibility() async throws {
        // given
        guard #available(iOS 15.0, *) else {
            return
        }

        let subscribeMock = { (subscriber: AnySubscriber<Int, Never>, subscription: SubscriptionMock) -> Void in
            subscription.onRequest = { demand in
                XCTAssertEqual(demand.max, 1)

                let additionalDemand = subscriber.receive(1)

                XCTAssertEqual(additionalDemand, .none)

                subscriber.receive(completion: .finished)
            }
        }

        let publisherTC = PublisherMock<Int, Never>()

        publisherTC.willSubscribe = subscribeMock

        let publisherCombine = PublisherMock<Int, Never>()

        publisherCombine.willSubscribe = subscribeMock

        let sequenceTC = TCAsyncThrowingPublisher(publisherTC)

        let sequenceCombine = publisherCombine.values

        let taskTC1 = Task {
            try await sequenceTC.reduce(into: []) { $0.append($1) }
        }

        let taskTC2 = Task {
            try await sequenceTC.reduce(into: []) { $0.append($1) }
        }

        let taskCombine1 = Task {
            await sequenceCombine.reduce(into: []) { $0.append($1) }
        }

        let taskCombine2 = Task {
            await sequenceCombine.reduce(into: []) { $0.append($1) }
        }

        // when
        let taskTC1Result = try await taskTC1.value
        let taskTC2Result = try await taskTC2.value
        let taskCombine1Result = await taskCombine1.value
        let _ = await taskCombine2.result

        // then
        XCTAssertEqual(taskTC1Result, taskTC2Result)
        XCTAssertEqual(taskTC1Result, taskCombine1Result)

        XCTAssertEqual(publisherTC.subscriptions.count, publisherCombine.subscriptions.count)

        for (subscriptionTC, subscriptionCombine) in zip(publisherTC.subscriptions, publisherCombine.subscriptions) {
            XCTAssertEqual(subscriptionTC.history, subscriptionCombine.history)
        }
    }

    func test_tcAsyncThrowingPublisher_lateSubscribe() async throws {
        // given
        let readerStarted = expectation(description: "reader started")

        let testStarted = expectation(description: "test started")

        let scheduler = DispatchQueue.test

        let publisher = PublisherMock<Int, Never>()

        publisher.willSubscribe = { subscriber, subscription in
            subscription.onRequest = { demand in
                let additionalDemand = subscriber.receive(1)

                XCTAssertEqual(additionalDemand, .none)

                subscriber.receive(completion: .finished)
            }
        }

        let sequenceTC = TCAsyncThrowingPublisher(publisher.subscribe(on: scheduler.eraseToAnyScheduler()))

        let task = Task {
            var iterator = sequenceTC.makeAsyncIterator()

            readerStarted.fulfill()

            await XCTWaiter.waitAsync(for: [testStarted], timeout: 1)

            _ = try await iterator.next()
        }

        // when
        await XCTWaiter.waitAsync(for: [readerStarted], timeout: 1)

        testStarted.fulfill()

        Task {
            await Task.megaYield()
            
            scheduler.run()
        }

        _ = await task.result

        // then
        XCTAssertEqual(publisher.subscriptions.count, 1)

        let publisherSubscription = publisher.subscriptions[0]

        XCTAssertEqual(publisherSubscription.history, [.requested(.max(1))])
    }

    func test_tcAsyncThrowingPublisher_whenReaderDrops() async throws {
        // given
        let publisher = PublisherMock<Int, Never>()

        let counter = Counter()

        publisher.willSubscribe = { subscriber, subscription in
            subscription.onRequest = { demand in
                let additionalDemand = subscriber.receive(counter.next())

                XCTAssertEqual(additionalDemand, .none)
            }
        }

        // when
        let result: [Int]

        // закрываем в блок `do`, чтобы паблишер удалился, отменяя при этом подписку
        do {
            let sequence = TCAsyncThrowingPublisher(publisher)

            result = await XCTExecuteThrowsNoError(
                try await sequence.prefix(3).reduce(into: []) { $0.append($1) }
            )!
        }

        // then
        XCTAssertEqual(result, [0, 1, 2])

        XCTAssertEqual(publisher.subscriptions.count, 1)

        let publisherSubscription = publisher.subscriptions[0]

        XCTAssertEqual(publisherSubscription.history, [
            .requested(.max(1)),
            .requested(.max(1)),
            .requested(.max(1)),
            .cancelled
        ])
    }

    func test_tcAsyncValues_send() async {
        // given
        let input = Array<Int>.fake(min: 3) { $0 }

        let publisher = input.publisher

        // when
        let sequence = publisher.asyncValues

        let result = await XCTExecuteThrowsNoError(
            await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqual(input, result)
    }

    func test_tcAsyncValues_throwing_send() async {
        // given
        let input = Array<Int>.fake(min: 3) { $0 }

        let publisher = input.publisher.setFailureType(to: FakeErrors.self)

        // when
        let sequence = publisher.asyncValues

        let result = await XCTExecuteThrowsNoError(
            try await sequence.reduce(into: []) { $0.append($1) }
        )!

        // then
        XCTAssertEqual(input, result)
    }
}

private class Counter: @unchecked Sendable {

    private var value: Int = 0
    private let lock = NSLock()

    func next() -> Int {
        lock.access {
            defer { value += 1 }

            return value
        }
    }
}
