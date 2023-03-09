import Foundation
import Combine

final class SubscriptionMock: Subscription, CustomStringConvertible {

    // MARK: - Inner Types

    enum Event: Equatable, CustomStringConvertible {

        // MARK: - Cases

        case requested(Subscribers.Demand)

        case cancelled

        var description: String {
            switch self {
            case .requested(let demand):
                return ".requested(.\(demand))"
            case .cancelled:
                return ".cancelled"
            }
        }
    }

    // MARK: - Private Properties

    private var _history: [Event] = []
    private let lock = NSLock()

    // MARK: - Properties

    var history: [Event] {
        return lock.access { _history }
    }

    var onRequest: ((Subscribers.Demand) -> Void)?

    var onCancel: (() -> Void)?

    var onDeinit: (() -> Void)?

    var description: String { "SubscriptionMock" }

    // MARK: - Initializers

    init(onRequest: ((Subscribers.Demand) -> Void)? = nil,
         onCancel: (() -> Void)? = nil,
         onDeinit: (() -> Void)? = nil) {
        self.onRequest = onRequest
        self.onCancel = onCancel
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit?()
    }

    // MARK: - Subscription

    func request(_ demand: Subscribers.Demand) {
        lock.access { _history.append(.requested(demand)) }

        onRequest?(demand)
    }

    // MARK: - Cancellable

    func cancel() {
        lock.access {
            _history.append(.cancelled)
        }

        onCancel?()
    }
}

extension SubscriptionMock: Equatable {
    static func == (lhs: SubscriptionMock, rhs: SubscriptionMock) -> Bool {
        return lhs === rhs
    }
}
