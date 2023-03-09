import Foundation
import Combine

/// A publisher that exposes its elements as an asynchronous sequence.
///
/// `TCAsyncThrowingPublisher` conforms to [AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence),
/// which allows callers to receive values with the `for`-`await`-`in` syntax, rather than attaching a ``Subscriber``.
///
///  It follows original  [AsyncThrowingPublisher](https://developer.apple.com/documentation/combine/asyncthrowingpublisher) contract, but is accessible from earlier OS versions.
///
/// Use the ``Combine/Publisher/asyncValues`` property of the ``/Combine/Publisher`` protocol to wrap an existing publisher with an instance of this type.
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
/// `TCAsyncPublisher` conforms to <doc://com.apple.documentation/documentation/Swift/AsyncSequence>,
/// which allows callers to receive values with the `for`-`await`-`in` syntax, rather than attaching a ``Combine/Subscriber``.
///
/// Use the ``Combine/Publisher/values-1dm9r`` property of the ``Combine/Publisher`` protocol to wrap an existing
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

/// Разделённое состояние для итератора. Этот класс-прокладка необходим для того, чтобы отслеживать завершение использования
/// асинхронной последовательности, и завершать соответствующую подписку. `innerSubscriber` будет захвачен подпиской, и не освободится, пока
/// не будет завершена подписка.
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

    /// Состояние подписчика.
    private enum State {

        // MARK: - Cases

        /// самое начало
        case idle

        /// Сжидаем подписку, уже имея запрос на значение (next у итератора уже вызвали, а подписки ещё нет)
        case waitingForSubscription(having: CompletionClosure)

        /// Ожидаем запроса со стороны Swift Concurrency, уже имея подписку.
        case waitingForConsume(having: Subscription)

        /// Ожидаем значение со стороны Combine, имея запрос со стороны Swift Concurrency.
        case waitingForInput(from: Subscription, to: CompletionClosure)

        /// Подписка завершилась со стороны Combine, но нужно дождаться запроса со стороны Swift Concurrency,
        /// чтобы завершить последовательность.
        case finishing(with: Subscribers.Completion<Failure>)

        /// Отменено со стороны Swift Concurrency, но может прийти зашедуленная подписка, которую надо будет отменить.
        case canceled

        /// Завершено со стороны Combine
        case completed
    }

    /// Событие для подписчика.
    private enum Event {

        // MARK: - Cases

        /// Запрос значения со стороны Swift Concurrency
        case consume(CompletionClosure)

        /// Отмена со стороны Swift Concurrency
        case didReceiveCancel

        /// Завершение со стороны Combine
        case didReceiveCompletion(Subscribers.Completion<Failure>)

        /// Получено значение со стороны Combine
        case didReceiveInput(Input)

        /// Получена подписка со стороны Combine
        case didReceiveSubscription(Subscription)
    }

    /// Описание действия.
    private enum Action {

        // MARK: - Cases

        /// Необходимо отправить значение в замыкание завершения.
        case send(Input, to: CompletionClosure)

        /// Необходимо запросить значение со стороны Combine.
        case request(Subscription)

        /// Необходимо завершить последовательность Swift Concurrency (закончить, либо выбросить исключение).
        case finish(CompletionClosure, with: Subscribers.Completion<Failure>)

        /// Необходимо отменить подписку Combine.
        case cancel(Subscription)

        /// Ничего не делать.
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
        // явно используем `withTaskCancellationHandler`, чтобы не терять события отмены задач,
        // даже если consume не успела выполниться. Это необходимо, чтобы надёжно отменять подписку при отмене.
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
    /// subscriber with a `for`-`await`-`in` loop that iterates over the ``TCAsyncThrowingPublisher``
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
