import Foundation
import Combine

class PublisherMock<Output, Failure: Error>: Publisher, Cancellable {

    // MARK: - Private Properties

    private let lock = NSLock()

    private(set) var subscribers: [AnySubscriber<Output, Failure>] = []
    private(set) var subscriptions: [SubscriptionMock] = []

    // MARK: - Properties

    var willSubscribe: ((AnySubscriber<Output, Failure>, SubscriptionMock) -> Void)?

    var didSubscribe: ((AnySubscriber<Output, Failure>, SubscriptionMock) -> Void)?

    var onDeinit: (() -> Void)?

    var invokedCancel: Bool = false

    var onCancel: (() -> Void)?

    // MARK: - Initializers

    required init() {
    }

    deinit {
        onDeinit?()
    }

    // MARK: - Publisher

    func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Output == Downstream.Input
    {
        let anySubscriber = AnySubscriber(subscriber)

        lock.access {
            self.subscribers.append(anySubscriber)
        }

        let subscription = SubscriptionMock()

        willSubscribe?(anySubscriber, subscription)

        lock.access {
            self.subscriptions.append(subscription)
        }

        subscriber.receive(subscription: subscription)

        didSubscribe?(anySubscriber, subscription)
    }

    // MARK: - Cancellable

    func cancel() {
        invokedCancel = true

        onCancel?()
    }
}
