import Testing
@testable import iWeGain

struct LogSetTests {
    private let base = LogSetUi(setNumber: 1, exerciseName: "Bench Press", weightLabel: "Weight, kg", weight: "57.5", reps: "8", weightHint: nil, repsHint: nil)

    private func typing(_ keys: String, into field: LogSetField, from start: LogSetUi? = nil) -> LogSetUi {
        keys.reduce((start ?? base).reduce(.onFieldTap(field), weightStep: 0.25)) { $0.reduce(.onKey($1), weightStep: 0.25) }
    }

    @Test func theFirstKeyAfterFocusingReplacesTheValue() {
        #expect(typing("62", into: .weight).weight == "62")
        #expect(typing("12", into: .reps).reps == "12")
    }

    @Test func weightTakesOneDotAndTwoDecimals() {
        #expect(typing(".5", into: .weight).weight == "0.5")
        #expect(typing("1.2.55", into: .weight).weight == "1.25")
        #expect(typing("0", into: .weight).reduce(.onKey("7"), weightStep: 0.25).weight == "7")
        #expect(typing("1234567", into: .weight).weight == "123456")
    }

    @Test func repsIgnoreLeadingZerosDotsAndAFourthDigit() {
        #expect(typing("0.5", into: .reps).reps == "5")
        #expect(typing("1234", into: .reps).reps == "123")
    }

    @Test func steppersClampAndBackspaceDeletes() {
        #expect(base.reduce(.onWeightIncrease, weightStep: 0.25).weight == "57.75")
        var zero = base
        zero.weight = "0"
        zero.reps = "1"
        #expect(zero.reduce(.onWeightDecrease, weightStep: 0.25).weight == "0")
        #expect(zero.reduce(.onRepsDecrease, weightStep: 0.25).reps == "1")
        let empty = typing("", into: .reps).reduce(.onBackspace, weightStep: 0.25)
        #expect(empty.reps == "")
        #expect(!empty.canSave)
    }
}
