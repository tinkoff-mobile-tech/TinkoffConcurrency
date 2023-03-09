import XCTest

extension XCTWaiter {

    // MARK: - Type Methods

    static func waitAsync(for expectations: [XCTestExpectation], timeout: TimeInterval) async {
        await withCheckedContinuation({ (continuation: CheckedContinuation<Void, Never>) -> Void in
            DispatchQueue.global().async {
                let result = XCTWaiter.wait(for: expectations, timeout: timeout)

                XCTAssertEqual(result, .completed)

                continuation.resume()
            }
        })
    }
}
