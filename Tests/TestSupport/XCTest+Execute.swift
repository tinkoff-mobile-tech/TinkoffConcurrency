import XCTest

extension XCTest {

    // MARK: - Methods

    /// Executes expression and asserts that it does not throw. Returns expression result.
    ///
    /// Non-throwing ensures this method to return a value, so it's safe to force-unwrap that like so:
    /// ```
    /// let result = await XCTExecuteThrowsNoError(
    ///     try await requestService.execute()
    /// )!
    /// ```
    func XCTExecuteThrowsNoError<T>(_ expression: @autoclosure () async throws -> T,
                                    file: StaticString = #filePath,
                                    line: UInt = #line) async -> T! {
        do {
            return try await expression()
        } catch is CancellationError {
            XCTFail("Unexpected cancellation", file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)", file: file, line: line)
        }

        return nil
    }

    /// Executes expression and asserts that it throws. Returns an error being thrown.
    ///
    /// Throwing ensures this method to return an error, so it's safe to force-unwrap that like so:
    /// ```
    /// let error = await XCTExecuteThrowsError(
    ///     try await requestService.execute()
    /// )!
    /// ```
    func XCTExecuteThrowsError<T>(_ expression: @autoclosure () async throws -> T,
                                  file: StaticString = #filePath,
                                  line: UInt = #line) async -> Error! {
        do {
            _ = try await expression()

            XCTFail("Expression should throw", file: file, line: line)
        } catch is CancellationError {
            XCTFail("Unexpected cancellation", file: file, line: line)
        } catch {
            return error
        }

        return nil
    }

    /// Asserts that given expression cancels its execution
    ///
    /// ```
    /// await XCTExecuteCancels(
    ///     try await requestService.execute()
    /// )
    /// ```
    func XCTExecuteCancels<T>(_ expression: @autoclosure () async throws -> T,
                              file: StaticString = #filePath,
                              line: UInt = #line) async {
        do {
            _ = try await expression()

            XCTFail("Cancellation expected", file: file, line: line)
        } catch is CancellationError {

        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)", file: file, line: line)
        }
    }
}
