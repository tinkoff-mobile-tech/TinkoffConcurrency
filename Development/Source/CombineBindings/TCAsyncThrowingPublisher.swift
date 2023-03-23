import Foundation
import Combine

/// A publisher that exposes its elements as an asynchronous sequence.
///
/// `TCAsyncThrowingPublisher` conforms to [AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence),
/// which allows callers to receive values with the `for`-`await`-`in` syntax, rather than attaching a
/// [Subscriber](https://developer.apple.com/documentation/combine/subscriber).
///
///  It follows original  [AsyncThrowingPublisher](https://developer.apple.com/documentation/combine/asyncthrowingpublisher)
///  contract, but is accessible from earlier OS versions.
///
/// Use the ``asyncValues`` property of the [Publisher](https://developer.apple.com/documentation/combine/publisher)
/// protocol to wrap an existing publisher with an instance of this type.
public struct TCAsyncThrowingPublisher<P: Publisher>: AsyncSequence, @unchecked Sendable {

    // MARK: - Type Aliases

    /// The type of element produced by this asynchronous sequence.
    public typealias Element = P.Output

    /// The type of asynchronous iterator that produces elements of this
    /// asynchronous sequence.
    public typealias AsyncIterator = TCAsyncThrowingPublisher<P>.Iterator

    // MARK: - Inner Types

    /// The iterator that produces elements of the asynchronous publisher sequence.
    public struct Iterator: AsyncIteratorProtocol, Sendable {

        // MARK: - Type Aliases

        public typealias Element = P.Output

        // MARK: - Private Properties

        private let innerHandler: InnerClass<P>

        // MARK: - Initializers

        init(publisher: P) {
            innerHandler = InnerClass(publisher: publisher)
        }

        // MARK: - Methods

        /// Produces the next element in the prefix sequence.
        ///
        /// - Returns: The next published element, or nil if the publisher finishes normally.
        /// If the publisher terminates with an error, the call point receives the error as a `throw`.
        public mutating func next() async throws -> Element? {
            try await innerHandler.next()
        }
    }

    // MARK: - Private Properties

    private let publisher: P

    // MARK: - Initializers

    /// Creates a publisher that exposes elements received from an upstream publisher as a throwing asynchronous sequence.
    /// - Parameter publisher: An upstream publisher. The asynchronous publisher converts elements received from this publisher into an asynchronous sequence.
    public init(_ publisher: P) {
        self.publisher = publisher
    }

    // MARK: - Methods

    /// Creates the asynchronous iterator that produces elements of this asynchronous sequence.
    ///
    /// - Returns: An instance of the `AsyncIterator` type used to produce elements of the asynchronous sequence.
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(publisher: publisher)
    }
}

/// A publisher that exposes its elements as an asynchronous sequence.
///
/// `TCAsyncPublisher` conforms to [AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence),
/// which allows callers to receive values with the `for`-`await`-`in` syntax, rather than attaching a
/// [Subscriber](https://developer.apple.com/documentation/combine/subscriber).
///
///  It follows original  [AsyncPublisher](https://developer.apple.com/documentation/combine/asyncpublisher)
///  contract, but is accessible from earlier OS versions.
///  
/// Use the ``asyncValues`` property of the [Publisher](https://developer.apple.com/documentation/combine/publisher)
/// protocol to wrap an existing publisher with an instance of this type.
/// publisher with an instance of this type.
public struct TCAsyncPublisher<P: Publisher>: AsyncSequence, @unchecked Sendable where P.Failure == Never {

    // MARK: - Type Aliases

    /// The type of element produced by this asynchronous sequence.
    public typealias Element = P.Output

    /// The type of asynchronous iterator that produces elements of this
    /// asynchronous sequence.
    public typealias AsyncIterator = TCAsyncPublisher<P>.Iterator

    // MARK: - Inner Types

    /// The iterator that produces elements of the asynchronous publisher sequence.
    public struct Iterator: AsyncIteratorProtocol, Sendable {

        // MARK: - Type Aliases

        public typealias Element = P.Output

        // MARK: - Private Properties

        private let innerHandler: InnerClass<P>

        // MARK: - Initializers

        init(publisher: P) {
            innerHandler = InnerClass(publisher: publisher)
        }

        // MARK: - Methods

        /// Produces the next element in the prefix sequence.
        ///
        /// - Returns: The next published element, or nil if the publisher finishes normally.
        /// If the publisher terminates with an error, the call point receives the error as a `throw`.
        public mutating func next() async -> Element? {
            try? await innerHandler.next()
        }
    }

    // MARK: - Private Properties

    private let publisher: P

    // MARK: - Initializers

    /// Creates a publisher that exposes elements received from an upstream publisher as a throwing asynchronous sequence.
    /// - Parameter publisher: An upstream publisher. The asynchronous publisher converts elements received from this publisher into an asynchronous sequence.
    public init(_ publisher: P) {
        self.publisher = publisher
    }

    // MARK: - Methods

    /// Creates the asynchronous iterator that produces elements of this asynchronous sequence.
    ///
    /// - Returns: An instance of the `AsyncIterator` type used to produce elements of the asynchronous sequence.
    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(publisher: publisher)
    }
}

/// Iterator shared state. This is required to detect when async sequence is no longer used. In this case, `deinit` would be called and we can finish `innerSubscriber` .
/// `innerSubscriber` itself would be captured by subscription, and would not be released until subscribtion is finished.
fileprivate final class InnerClass<P: Publisher>: @unchecked Sendable {

    // MARK: - Private Properties

    let innerSubscriber: InnerSubscriber<P>

    // MARK: - Initializers

    init(publisher: P) {
        innerSubscriber = InnerSubscriber(publisher: publisher)
    }

    deinit {
        innerSubscriber.finish()
    }

    // MARK: - Methods

    func next() async throws -> P.Output? {
        try await innerSubscriber.next()
    }
}

fileprivate final class InnerSubscriber<P: Publisher>: Subscriber, @unchecked Sendable {

    // MARK: - Type Aliases

    public typealias Input = P.Output

    public typealias Failure = P.Failure

    private typealias CompletionClosure = (Result<Input?, Error>) -> Void

    // MARK: - Inner Types

    /// Subscriber state.
    private enum State {

        // MARK: - Cases

        /// The very start
        case idle

        /// Waiting for subscription, already having a request for value (iterator's `next` is already called, but subscription is still not there)
        case waitingForSubscription(having: CompletionClosure)

        /// Waiting for value request from Swift Concurrency, having subscription.
        case waitingForConsume(having: Subscription)

        /// Waiting for input from Combine, having request from Swift Concurrency.
        case waitingForInput(from: Subscription, to: CompletionClosure)

        /// Subscription is finished from Combine's side, but we must wait for request from Swift Concurrency,
        /// to gracefully shutdown everything.
        case finishing(with: Subscribers.Completion<Failure>)

        /// Cancelled from Swift Concurrency, but scheduled subscription can still come. In this case it must be cancelled at once.
        case canceled

        /// Cancelled from Combine
        case completed
    }

    /// Subscriber event.
    private enum Event {

        // MARK: - Cases

        /// Request for a value from Swift Concurrency, given a completion closure to call with a value or error
        case consume(CompletionClosure)

        /// Swift Concurrency Task cancelled
        case didReceiveCancel

        /// Combine Subscription is completed
        case didReceiveCompletion(Subscribers.Completion<Failure>)

        /// Got a value from Combine
        case didReceiveInput(Input)

        /// Got a subscription from Combine
        case didReceiveSubscription(Subscription)
    }

    /// Action description. Instead of doing stuff directly, we return descriptions which will be called when state lock is released.
    /// That makes logic more readable.
    private enum Action {

        // MARK: - Cases

        /// We have to send an input to given closure.
        case send(Input, to: CompletionClosure)

        /// Request a value from Combine.
        case request(Subscription)

        /// We have to finish Async Sequence (either gracefully, or by throwing an error)
        case finish(CompletionClosure, with: Subscribers.Completion<Failure>)

        /// We have to cancel Combine subscription.
        case cancel(Subscription)

        /// Do nothing.
        case none
    }

    // MARK: - Private Properties

    private var currentState: State = .idle

    private let lock = NSLock()

    // MARK: - Initializers

    init(publisher: P) {
        publisher.subscribe(self)
    }

    // MARK: - Methods

    func next() async throws -> Input? {
        // Use `withTaskCancellationHandler`, explicitly, to send cancellation event even if consume didn't return.
        // This is necessary to reliably cancel a Combine subscription when canceling task.
        try await withTaskCancellationHandler {
            try await withCheckedThrowingCancellableContinuation { completion in
                handle(event: .consume(completion))

                return nil
            }
        } onCancel: {
            handle(event: .didReceiveCancel)
        }
    }

    func finish() {
        handle(event: .didReceiveCancel)
    }

    func receive(subscription: Subscription) {
        handle(event: .didReceiveSubscription(subscription))
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        handle(event: .didReceiveInput(input))

        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        handle(event: .didReceiveCompletion(completion))
    }

    // MARK: - Private Methods

    // swiftlint:disable:next cyclomatic_complexity
    private func process(event: Event) -> Action {
        defer { lock.unlock() }
        lock.lock()

        switch currentState {
        case .idle:
            switch event {
            case let .consume(completionClosure):
                currentState = .waitingForSubscription(having: completionClosure)

            case let .didReceiveSubscription(subscription):
                currentState = .waitingForConsume(having: subscription)

            case .didReceiveCancel:
                currentState = .canceled

            case let .didReceiveCompletion(completion):
                currentState = .finishing(with: completion)

            default:
                break
            }

        case let .waitingForSubscription(having: completionClosure):
            switch event {
            case let .didReceiveSubscription(subscription):
                currentState = .waitingForInput(from: subscription, to: completionClosure)
                return .request(subscription)

            case .didReceiveCancel:
                currentState = .canceled

            case let .didReceiveCompletion(completion):
                currentState = .completed
                return .finish(completionClosure, with: completion)

            default:
                break
            }

        case let .waitingForInput(from: subscription, to: completionClosure):
            switch event {
            case let .didReceiveInput(input):
                currentState = .waitingForConsume(having: subscription)
                return .send(input, to: completionClosure)

            case let .didReceiveCompletion(completion):
                currentState = .completed
                return .finish(completionClosure, with: completion)

            case .didReceiveCancel:
                currentState = .canceled
                return .cancel(subscription)

            default:
                break
            }

        case let .waitingForConsume(having: subscription):
            switch event {
            case let .consume(completionClosure):
                currentState = .waitingForInput(from: subscription, to: completionClosure)
                return .request(subscription)

            case let .didReceiveCompletion(completion):
                currentState = .finishing(with: completion)

            case .didReceiveCancel:
                currentState = .canceled
                return .cancel(subscription)

            default:
                break
            }

        case let .finishing(with: completion):
            switch event {
            case let .consume(completionClosure):
                currentState = .completed
                return .finish(completionClosure, with: completion)

            case .didReceiveCancel:
                currentState = .canceled

            default:
                break
            }

        case .canceled:
            switch event {
            case let .didReceiveSubscription(subscription):
                return .cancel(subscription)

            default:
                break
            }

        case .completed:
            break
        }

        return .none
    }

    private func handle(event: Event) {
        let action = process(event: event)

        switch action {
        case let .send(element, to: completionClosure):
            completionClosure(.success(element))

        case let .request(subscription):
            subscription.request(.max(1))

        case let .finish(completionClosure, with: completion):
            switch completion {
            case .finished:
                completionClosure(.success(nil))

            case let .failure(error):
                completionClosure(.failure(error))
            }

        case let .cancel(subscription):
            subscription.cancel()

        case .none:
            break
        }
    }
}

extension Publisher {

    // MARK: - Methods

    /// The elements produced by the publisher, as an asynchronous sequence.
    ///
    /// This property provides an ``TCAsyncThrowingPublisher``, which allows you to use the Swift `async`-`await` syntax to receive the publisher's elements.
    /// Because ``TCAsyncThrowingPublisher`` conforms to [AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence),
    /// you iterate over its elements with a `for`-`await`-`in` loop, rather than attaching a subscriber.
    ///
    /// It follows Apple's [Publisher.values](https://developer.apple.com/documentation/combine/publisher/values-1dm9r) contract, but is
    /// available on earlier OS versions.
    ///
    /// The following example shows how to use the `asyncValues` property to receive elements asynchronously.
    /// The example adapts a code snippet from the [tryFilter(_:)](https://developer.apple.com/documentation/combine/publisher/tryFilter(_:))
    /// operator's documentation, which filters a sequence to only emit even integers and terminate with an error on a `0`. This example replaces the
    /// [Subscribers.Sink](https://developer.apple.com/documentation/combine/subscribers/sink)
    /// subscriber with a `for`-`await`-`in` loop that iterates over the ``TCAsyncThrowingPublisher``
    /// provided by the `asyncValues` property.
    ///
    ///     let numbers: [Int] = [1, 2, 3, 4, 0, 5]
    ///     let filterPublisher = numbers.publisher
    ///         .tryFilter{
    ///             if $0 == 0 {
    ///                 throw ZeroError()
    ///             } else {
    ///                 return $0 % 2 == 0
    ///             }
    ///         }
    ///
    ///     do {
    ///         for try await number in filterPublisher.asyncValues {
    ///             print ("\(number)", terminator: " ")
    ///         }
    ///     } catch {
    ///         print ("\(error)")
    ///     }
    ///
    public var asyncValues: TCAsyncThrowingPublisher<Self> {
        TCAsyncThrowingPublisher(self)
    }
}

extension Publisher where Self.Failure == Never {

    // MARK: - Methods

    /// The elements produced by the publisher, as an asynchronous sequence.
    ///
    /// This property provides an ``TCAsyncPublisher``, which allows you to use the Swift `async`-`await` syntax to receive the publisher's elements.
    /// Because ``TCAsyncPublisher`` conforms to [AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence),
    /// you iterate over its elements with a `for`-`await`-`in` loop, rather than attaching a subscriber.
    ///
    /// It follows Apple's [Publisher.values](https://developer.apple.com/documentation/combine/publisher/values-v7nz) contract, but is
    /// available on earlier OS versions.
    ///
    /// The following example shows how to use the `asyncValues` property to receive elements asynchronously.
    /// The example adapts a code snippet from the [filter(_:)](https://developer.apple.com/documentation/combine/publisher/filter(_:)) operator's documentation,
    /// which filters a sequence to only emit even integers. This example replaces the
    /// [Subscribers.Sink](https://developer.apple.com/documentation/combine/subscribers/sink)
    /// subscriber with a `for`-`await`-`in` loop that iterates over the ``TCAsyncPublisher``
    /// provided by the `asyncValues` property.
    ///
    ///     let numbers: [Int] = [1, 2, 3, 4, 5]
    ///     let filtered = numbers.publisher
    ///         .filter { $0 % 2 == 0 }
    ///
    ///     for await number in filtered.asyncValues
    ///     {
    ///         print("\(number)", terminator: " ")
    ///     }
    ///
    public var asyncValues: TCAsyncPublisher<Self> {
        TCAsyncPublisher(self)
    }
}
