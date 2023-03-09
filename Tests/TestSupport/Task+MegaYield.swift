extension Task where Success == Failure, Failure == Never {
    static func megaYield(count: Int = 10) async {
        for _ in 1...count {
            await Task<Void, Never>.detached(priority: .background) { await Task.yield() }.value
        }
    }
}
