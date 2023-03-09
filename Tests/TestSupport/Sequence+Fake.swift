extension Sequence {

    // MARK: - Type Methods

    static func fake(min: Int = 0,
                     max: Int = 5,
                     fakeInit: (Int) -> Element) -> [Self.Element] {
        let count = Int.fake(min: min, max: max)

        return (0..<count).map(fakeInit)
    }
}
