/// A protocol indicating that an operation supports cancellation.
public protocol TCCancellable {

    // MARK: - Methods

    /// Cancels the operation.
    ///
    /// Repeated calls of this method will be ignored.
    func cancel()
}
