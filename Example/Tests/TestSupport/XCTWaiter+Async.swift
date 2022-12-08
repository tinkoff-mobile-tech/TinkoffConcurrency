import XCTest

extension XCTWaiter {

    // MARK: - Type Methods

    static func waitAsync(for expectations: [XCTestExpectation], timeout: TimeInterval) async {
        await withCheckedContinuation({ (continuation: CheckedContinuation<Void, Never>) -> Void in
            DispatchQueue.global().async {
                _ = XCTWaiter.wait(for: expectations, timeout: timeout)

                continuation.resume()
            }
        })
    }
}
