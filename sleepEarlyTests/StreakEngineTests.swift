// sleepEarlyTests/StreakEngineTests.swift
import XCTest
@testable import sleepEarly

final class StreakEngineTests: XCTestCase {

    private func makeDate(daysAgo: Int, hour: Int, minute: Int = 0) -> Date {
        let base = Calendar.current.startOfDay(for: Date())
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: base)!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func record(daysAgo: Int, bedtimeHour: Int, bedtimeMinute: Int = 0) -> SleepRecord {
        let date = Calendar.current.startOfDay(for: makeDate(daysAgo: daysAgo, hour: 0))
        let bedtime = makeDate(daysAgo: daysAgo, hour: bedtimeHour, minute: bedtimeMinute)
        return SleepRecord(date: date, bedtime: bedtime, source: .manual)
    }

    func test_emptyRecords_streakIsZero() {
        let streak = StreakEngine.currentStreak(records: [], targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 0)
    }

    func test_sleptBeforeTarget_streakOne() {
        let records = [record(daysAgo: 1, bedtimeHour: 21, bedtimeMinute: 30)]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 1)
    }

    func test_sleptAfterTarget_streakZero() {
        let records = [record(daysAgo: 1, bedtimeHour: 23)]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 0)
    }

    func test_threeConsecutiveNights_streakThree() {
        let records = [
            record(daysAgo: 1, bedtimeHour: 21, bedtimeMinute: 50),
            record(daysAgo: 2, bedtimeHour: 21, bedtimeMinute: 45),
            record(daysAgo: 3, bedtimeHour: 21, bedtimeMinute: 30)
        ]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 3)
    }

    func test_gap_streakBreaks() {
        let records = [
            record(daysAgo: 1, bedtimeHour: 21),
            record(daysAgo: 3, bedtimeHour: 21)
        ]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 1)
    }

    func test_nilBedtime_doesNotCount() {
        let date = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        let records = [SleepRecord(date: date, bedtime: nil, source: .healthKit)]
        let streak = StreakEngine.currentStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(streak, 0)
    }

    func test_bestStreak_acrossHistory() {
        let records = [
            record(daysAgo: 1, bedtimeHour: 21),
            record(daysAgo: 2, bedtimeHour: 21),
            record(daysAgo: 4, bedtimeHour: 21),
            record(daysAgo: 5, bedtimeHour: 21),
            record(daysAgo: 6, bedtimeHour: 21)
        ]
        let best = StreakEngine.bestStreak(records: records, targetHour: 22, targetMinute: 0)
        XCTAssertEqual(best, 3)
    }
}
