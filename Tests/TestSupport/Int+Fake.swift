extension Int {

    // MARK: - Type Methods

    static func fake(min: Int = Int.min, max: Int = Int.max) -> Int {
        Int.random(in: min...max)
    }
}
