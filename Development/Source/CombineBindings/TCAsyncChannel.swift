import Foundation
import Combine

// swiftlint:disable file_length
/// ``TCAsyncChannel`` errors
public enum TCAsyncChannelErrors: Error {

    // MARK: - Cases

    /// ``TCAsyncChannel/send(_:)`` or ``TCAsyncChannel/send(completion:)`` is called while ``TCAsyncChannel/send(_:)`` is still in progress.
    ///
    /// New values or completion must be sent only when previous ``TCAsyncChannel/send(_:)`` has been `await`'ed.
    case concurrentAccess

    /// ``TCAsyncChannel/send(_:)`` or ``TCAsyncChannel/send(completion:)`` has been called from finished sequence.
    case outputToFinished
}

/// A channel for sending values from Swift Concurrency task to Combine with backpressure
///
/// The `TCAsyncChannel` class is intended to send values that can be consumed by Combine
/// respecting Combine's backpressure mechanism. In contrast to [PassthroughSubject](https://developer.apple.com/documentation/combine/passthroughsubject),
/// which would drop values if there's no downstream demand,
/// `TCAsyncChannel`.``TCAsyncChannel/send(_:)`` will await only when there's at least one subscriber, and all subscribers can receive next value.
///
/// See <doc:CombineBindings> article for details.
///
/// The usage example below illustrates how to synchronize data reads and writes using ``TCAsyncChannel``.
/// 
/// ```swift
/// let channel = TCAsyncChannel<String, Error>()
///
/// Task {
///     while let value = getValue() {
///         try await channel.send(value)
///     }
///
///     try channel.send(completion: .finished)
/// }
///
/// for await value in channel.asyncValues {
///     await useValue(value)
/// }
/// ```

public final class TCAsyncChannel<Output, Failure: Error>: Publisher {

    // MARK: - Private Type Aliases

    fileprivate typealias Conduit = AsyncSubscription<Output, Failure>

    private typealias Continuation = CheckedContinuation<Void, Error>
    private typealias Completion = Subscribers.Completion<Failure>

    // MARK: - Private Types

    private enum State {

        // MARK: - Cases

        /// Initial state
        case idle

        /// Value received, waiting for Combine request.
        case pending(Continuation, Output)

        /// Value is being sent.
        ///
        /// We have to wait until value is sent to all receivers to avoid race conditions. When everything is sent,
        /// we can wait for request for a new value.
        case sending(Continuation)

        /// Value is sent to Combine, waiting for request for a new value.
        ///
        /// We can send a new value only when all subscriptions have a request.
        case waitForBackpressure(Continuation)

        /// Publisher is finished with a given Completion.
        case finished(Completion)

        /// Publisher is cancelled.
        case cancelled
    }

    private enum Event {

        // MARK: - Cases

        /// Check if a value can be sent.
        case checkDemand

        /// Send value, hold continuation to resume when send is complete and all subscriptions are ready to receive a new value.
        case send(Continuation, Output)

        /// Value is sent to all subscriptions.
        case sendComplete

        /// Sending task cancelled.
        case cancel

        /// Publisher is finished.
        case finish(Completion)
    }

    private enum Action {

        // MARK: - Cases

        /// Repeat checking if new value could be sent.
        case recheckDemand

        /// Resume saved continuation.
        case resume(Continuation)

        /// Resume continuation with an exception with given error.
        case fail(Continuation, Error)

        /// Throw exception synchronously.
        case throwError(Error)

        /// Send value to all given subscriptions.
        case send(Output, Set<Conduit>)

        /// Complete given subscriptions.
        case finish(Completion, Set<Conduit>)
    }

    // MARK: - Private Properties

    private let lock = NSRecursiveLock()

    private var subscriptions = Set<Conduit>()

    private var state = State.idle

    // MARK: - Initializers

    public init() {}

    // MARK: - Public Methods

    /// Send value respecting Combine backpressure.
    /// - Parameters:
    ///   - value: A value to send.
    /// - Throws: An error of type ``TCAsyncChannelErrors``.
    public func send(_ value: Output) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                try? handle(event: .send(continuation, value))
            }
        } onCancel: {
            try? handle(event: .cancel)
        }
    }

    /// Send completion.
    ///
    /// Completion is synchronous, no more ``send(_:)`` or ``send(completion:)`` allowed from now on.
    /// - Parameters:
    ///   - completion: A completion (success / failure).
    /// - Throws: An error of type ``TCAsyncChannelErrors``.
    public func send(completion: Subscribers.Completion<Failure>) throws {
        try handle(event: .finish(completion))
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        // it's safe to perform a check like that, because `.finished` and `.cancelled` states are terminal
        let state = lock.access { self.state }

        switch state {
        case let .finished(.failure(error)):
            subscriber.receive(completion: .failure(error))

        case .finished, .cancelled:
            subscriber.receive(completion: .finished)
            return

        default:
            break
        }

        let conduit = AsyncSubscription(subscriber: subscriber, channel: self)

        lock.access {
            subscriptions.insert(conduit)
        }

        subscriber.receive(subscription: conduit)
    }

    // MARK: - Private Methods

    fileprivate func requestValue() {
        try? handle(event: .checkDemand)
    }

    fileprivate func subscriptionCancelled() {
        lock.access {
            subscriptions = subscriptions.filter({ !$0.isClosed })
        }

        try? handle(event: .checkDemand)
    }

    private var haveDemand: Bool {
        // don't guard `subscriptions`, because `haveDemand` is called only from already guarded `process(event:)`
        !subscriptions.isEmpty && subscriptions.allSatisfy { $0.haveDemand }
    }

    private func finishAction(with completion: Completion) -> Action {
        defer { subscriptions.removeAll() }

        // Provide a list of subscriptions to finish to make operation atomic.
        return .finish(completion, subscriptions)
    }

    private func handle(event: Event) throws {
        let actions = process(event: event)

        for action in actions {
            switch action {
            case .recheckDemand:
                try handle(event: .checkDemand)

            case let .fail(continuation, error):
                continuation.resume(throwing: error)

            case let .send(output, subscriptions):
                for subscription in subscriptions {
                    subscription.send(input: output)
                }
                try handle(event: .sendComplete)

            case let .resume(continuation):
                continuation.resume()

            case let .finish(completion, subscriptions):
                for subscription in subscriptions {
                    subscription.send(completion: completion)
                }

            case let .throwError(error):
                throw error
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func process(event: Event) -> [Action] {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .idle:
            switch event {
            case .checkDemand, .sendComplete:
                break

            case let .send(continuation, output):
                state = .pending(continuation, output)

                return [.recheckDemand]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished)]

            case let .finish(completion):
                state = .finished(completion)

                return [finishAction(with: completion)]
            }

        case let .pending(continuation, output):
            switch event {
            case .checkDemand:
                if haveDemand {
                    state = .sending(continuation)

                    // capture subscriptions here to avoid race conditions while sending. For example,
                    // a new subscription could be added in this moment, and we must wait for demand
                    // until we can send anything there
                    return [.send(output, subscriptions)]
                }

            case .sendComplete:
                break

            case let .send(newContinuation, _):
                return [.fail(newContinuation, TCAsyncChannelErrors.concurrentAccess)]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished), .fail(continuation, CancellationError())]

            case .finish:
                return [.throwError(TCAsyncChannelErrors.concurrentAccess)]
            }

        case let .sending(continuation):
            switch event {
            case .checkDemand:
                break

            case .sendComplete:
                if haveDemand {
                    state = .idle

                    return [.resume(continuation)]
                } else {
                    state = .waitForBackpressure(continuation)
                }

            case let .send(newContinuation, _):
                return [.fail(newContinuation, TCAsyncChannelErrors.concurrentAccess)]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished), .fail(continuation, CancellationError())]

            case .finish:
                return [.throwError(TCAsyncChannelErrors.concurrentAccess)]
            }

        case let .waitForBackpressure(continuation):
            switch event {
            case .checkDemand:
                if haveDemand {
                    state = .idle
                    return [.resume(continuation)]
                }

            case .sendComplete:
                break

            case let .send(newContinuation, _):
                return [.fail(newContinuation, TCAsyncChannelErrors.concurrentAccess)]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished), .fail(continuation, CancellationError())]

            case .finish:
                return [.throwError(TCAsyncChannelErrors.concurrentAccess)]
            }

        case .cancelled:
            switch event {
            case .checkDemand, .sendComplete, .cancel, .finish:
                return [finishAction(with: .finished)]

            case let .send(continuation, _):
                return [.fail(continuation, CancellationError())]
            }

        case let .finished(completion):
            switch event {
            case .checkDemand, .sendComplete, .cancel:
                return [finishAction(with: completion)]

            case let .send(continuation, _):
                return [finishAction(with: completion), .fail(continuation, TCAsyncChannelErrors.outputToFinished)]

            case .finish:
                return [finishAction(with: completion), .throwError(TCAsyncChannelErrors.outputToFinished)]
            }
        }

        return []
    }
}

private class AsyncSubscription<Output, Failure: Error>: Subscription, Hashable {

    // MARK: - Inner Types

    private enum State {

        // MARK: - Cases

        /// Initial state
        case idle

        /// We have a demand for values
        case haveDemand(Subscribers.Demand)

        /// Finished
        case finished
    }

    private enum Event {

        // MARK: - Cases

        /// Got a request to send a value
        case send(Output)

        /// Got a request to finish subscription
        case finish(Subscribers.Completion<Failure>)

        /// Subscription is ready to receive values
        case receive(Subscribers.Demand)

        /// Subscription has been cancelled
        case cancel
    }

    private enum Action {

        // MARK: - Cases

        /// Request a value from channel
        case requestValue

        /// Send value downstream
        case sendValue(Output)

        /// Send completion downstream
        case sendCompletion(Subscribers.Completion<Failure>)

        /// Notify channel that subscription has been cancelled
        case notifyCancelled
    }

    // MARK: - Private Properties

    /// Send value to the subscriber. Closure erases subscriber type.
    private let sendValue: (Output) -> Subscribers.Demand

    /// Send completion to the subscriber. Closure erases subscriber type.
    private let sendCompletion: (Subscribers.Completion<Failure>) -> Void

    /// Channel we belong to.
    private weak var channel: TCAsyncChannel<Output, Failure>?

    /// Current state.
    private var state = State.idle

    /// A lock for the current state.
    private let lock = NSLock()

    // MARK: - Properties

    var haveDemand: Bool {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .haveDemand:
            return true

        case .idle, .finished:
            return false
        }
    }

    var isClosed: Bool {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .haveDemand, .idle:
            return false

        case .finished:
            return true
        }
    }

    // MARK: - Initializers

    init<S>(subscriber: S, channel: TCAsyncChannel<Output, Failure>) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.sendValue = { subscriber.receive($0) }
        self.sendCompletion = { subscriber.receive(completion: $0) }
        self.channel = channel
    }

    // MARK: - Methods

    func send(input: Output) {
        handle(event: .send(input))
    }

    func send(completion: Subscribers.Completion<Failure>) {
        handle(event: .finish(completion))
    }

    // MARK: - Subscription

    func request(_ demand: Subscribers.Demand) {
        handle(event: .receive(demand))
    }

    func cancel() {
        handle(event: .cancel)
    }

    // MARK: - Hashable

    static func == (lhs: AsyncSubscription<Output, Failure>, rhs: AsyncSubscription<Output, Failure>) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    // MARK: - Private Methods

    private func handle(event: Event) {
        let actions = process(event: event)

        for action in actions {
            switch action {
            case .requestValue:
                channel?.requestValue()

            case let .sendValue(output):
                let demand = sendValue(output)

                if demand != .none {
                    handle(event: .receive(demand))
                }

            case .notifyCancelled:
                channel?.subscriptionCancelled()

            case let .sendCompletion(completion):
                sendCompletion(completion)
            }
        }
    }

    private func process(event: Event) -> [Action] {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .idle:
            switch event {
            case .send:
                break

            case let .receive(demand):
                state = .haveDemand(demand)

                return [.requestValue]

            case .cancel:
                state = .finished

                return [.notifyCancelled]

            case let .finish(completion):
                state = .finished

                return [.sendCompletion(completion), .notifyCancelled]
            }

        case let .haveDemand(demand):
            switch event {
            case let .send(output):
                let newDemand = demand - .max(1)

                if newDemand == .none {
                    state = .idle

                    return [.sendValue(output)]
                } else {
                    state = .haveDemand(newDemand)

                    return [.sendValue(output), .requestValue]
                }

            case let .receive(newDemand):
                state = .haveDemand(demand + newDemand)

            case .cancel:
                state = .finished

                return [.notifyCancelled]

            case let .finish(completion):
                state = .finished

                return [.sendCompletion(completion), .notifyCancelled]
            }

        case .finished:
            return [.notifyCancelled]
        }

        return []
    }
}

private extension NSRecursiveLock {

    // MARK: - Methods

    @discardableResult
    func access<T>(_ executionBlock: () -> T) -> T {
        defer { unlock() }

        lock()

        return executionBlock()
    }
}
