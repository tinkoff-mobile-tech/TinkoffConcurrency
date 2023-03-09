import Foundation
import Combine

final class SubscriberMock<Input, Failure: Error>: Subscriber, Cancellable {

    // MARK: - Private Properties

    private let lock = NSLock()

    private var subscription: Subscription?

    // MARK: - Properties

    private(set) var receivedValues = [Input]()

    private(set) var receivedCompletion: Subscribers.Completion<Failure>?

    // MARK: - Initializers

    deinit {
        cancel()
    }

    // MARK: - Subscriber

    func receive(subscription: Subscription) {
        precondition(self.subscription == nil)

        lock.access { self.subscription = subscription }

        subscription.request(Subscribers.Demand.max(1))
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        lock.access { receivedValues.append(input) }

        return Subscribers.Demand.max(1)
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        lock.access { receivedCompletion = completion }
    }

    // MARK: - Cancellable

    func cancel() {
        subscription?.cancel()
    }
}
