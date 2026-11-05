import Foundation
import Testing
@testable import iWeGain

@MainActor
struct AsyncStreamCombineTests {

    @Test func combineLatestWaitsForBothThenFollowsEither() async {
        let (a, aInput) = AsyncStream<Int>.makeStream()
        let (b, bInput) = AsyncStream<String>.makeStream()
        var combined = combineLatest(a, b).makeAsyncIterator()

        aInput.yield(1)
        bInput.yield("x")
        let first = await combined.next()
        #expect(first?.0 == 1 && first?.1 == "x")
        aInput.yield(2)
        let second = await combined.next()
        #expect(second?.0 == 2 && second?.1 == "x")
        aInput.finish()
        bInput.finish()
        #expect(await combined.next() == nil)
    }

    @Test func removeDuplicatesSkipsRepeats() async {
        let (source, input) = AsyncStream<Int>.makeStream()
        [1, 1, 2, 2, 1].forEach { input.yield($0) }
        input.finish()
        var values: [Int] = []
        for await value in source.removeDuplicates() { values.append(value) }
        #expect(values == [1, 2, 1])
    }

    @Test func flatMapLatestFollowsTheNewestInnerStream() async {
        let (outer, outerInput) = AsyncStream<String>.makeStream()
        var stream = outer.flatMapLatest { name in AsyncStream { $0.yield("\(name)!"); $0.finish() } }.makeAsyncIterator()
        outerInput.yield("a")
        #expect(await stream.next() == "a!")
        outerInput.yield("b")
        #expect(await stream.next() == "b!")
    }
}
