struct SampleVariationPicker {
    private var previous: Int?

    mutating func nextIndex<R: RandomNumberGenerator>(count: Int, using generator: inout R) -> Int? {
        guard count > 0 else {
            previous = nil
            return nil
        }
        let index: Int
        if count > 1, let previous, (0..<count).contains(previous) {
            let draw = Int.random(in: 0..<(count - 1), using: &generator)
            index = draw >= previous ? draw + 1 : draw
        } else {
            index = Int.random(in: 0..<count, using: &generator)
        }
        previous = index
        return index
    }
}
