import Testing
@testable import WAClear

// MARK: - Double.mmss

@Suite("Double.mmss clock formatting")
struct MmssFormattingTests {

    @Test("0 s → 0:00")
    func zero() { #expect(0.0.mmss == "0:00") }

    @Test("30 s → 0:30")
    func thirtySeconds() { #expect(30.0.mmss == "0:30") }

    @Test("60 s → 1:00")
    func sixtySeconds() { #expect(60.0.mmss == "1:00") }

    @Test("90 s → 1:30")
    func ninetySeconds() { #expect(90.0.mmss == "1:30") }

    @Test("120 s → 2:00")
    func twoMinutes() { #expect(120.0.mmss == "2:00") }

    @Test("65 s → 1:05 (zero-pads seconds)")
    func zeroPaddedSeconds() { #expect(65.0.mmss == "1:05") }

    @Test("599 s → 9:59")
    func nineMinFiftyNine() { #expect(599.0.mmss == "9:59") }

    @Test("600 s → 10:00")
    func tenMinutes() { #expect(600.0.mmss == "10:00") }

    @Test("Negative value clamps to 0:00")
    func negative() { #expect((-5.0).mmss == "0:00") }

    @Test("Fractional seconds truncated (1.9 → 0:01)")
    func fractional() { #expect(1.9.mmss == "0:01") }
}

// MARK: - Double.formattedDuration

@Suite("Double.formattedDuration")
struct FormattedDurationTests {

    @Test("0 s → \"0s\"")
    func zero() { #expect(0.0.formattedDuration == "0s") }

    @Test("30 s → \"30s\"")
    func thirtySeconds() { #expect(30.0.formattedDuration == "30s") }

    @Test("59 s → \"59s\"")
    func fiftyNineSeconds() { #expect(59.0.formattedDuration == "59s") }

    @Test("60 s → \"1m\"")
    func oneMinute() { #expect(60.0.formattedDuration == "1m") }

    @Test("90 s → \"1m 30s\"")
    func oneMinuteThirtySeconds() { #expect(90.0.formattedDuration == "1m 30s") }

    @Test("120 s → \"2m\"")
    func twoMinutes() { #expect(120.0.formattedDuration == "2m") }

    @Test("125 s → \"2m 5s\"")
    func twoMinutesFiveSeconds() { #expect(125.0.formattedDuration == "2m 5s") }

    @Test("600 s → \"10m\"")
    func tenMinutes() { #expect(600.0.formattedDuration == "10m") }
}
