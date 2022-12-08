import XCTest

extension XCTest {

    // MARK: - Methods

    /// Asserts that two given errors are equal.
    /// - Parameters:
    ///   - error1: Error being asserted.
    ///   - error2: Expected error.
    ///   - message: Message in case of failure.
    func XCTAssertEqualErrors(_ error1: NSError?,
                              _ error2: NSError,
                              _ message: String = "",
                              file: StaticString = #filePath,
                              line: UInt = #line) {
        XCTAssertEqual(error1?.domain, error2.domain, message, file: file, line: line)
        XCTAssertEqual(error1?.code, error2.code, message, file: file, line: line)
    }

    /// Asserts that two given errors are equal.
    /// - Parameters:
    ///   - error1: Error being asserted.
    ///   - error2: Expected error.
    ///   - message: Message in case of failure.
    func XCTAssertEqualErrors(_ error1: Error?,
                              _ error2: Error,
                              _ message: String = "",
                              file: StaticString = #filePath,
                              line: UInt = #line) {
        let error1 = error1 as? NSError
        let error2 = error2 as NSError

        XCTAssertEqualErrors(error1, error2, message, file: file, line: line)
    }
}
