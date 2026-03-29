// sleepEarlyTests/NotificationSchedulerTests.swift
import XCTest
@testable import sleepEarly

final class NotificationSchedulerTests: XCTestCase {

    func test_buildNotifications_returnsSevenRequests() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        XCTAssertEqual(requests.count, 7)
    }

    func test_buildNotifications_identifiersAreUnique() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        let ids = Set(requests.map { $0.identifier })
        XCTAssertEqual(ids.count, 7)
    }

    func test_buildNotifications_lastNotifIsAtTarget() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        let last = requests.last!
        let trigger = last.trigger as! UNCalendarNotificationTrigger
        let components = trigger.dateComponents
        XCTAssertEqual(components.hour, 22)
        XCTAssertEqual(components.minute, 0)
    }

    func test_buildNotifications_firstNotifIsThirtyMinBefore() {
        let requests = NotificationScheduler.buildRequests(targetHour: 22, targetMinute: 0)
        let first = requests.first!
        let trigger = first.trigger as! UNCalendarNotificationTrigger
        let components = trigger.dateComponents
        XCTAssertEqual(components.hour, 21)
        XCTAssertEqual(components.minute, 30)
    }

    func test_buildNotifications_customTarget() {
        let requests = NotificationScheduler.buildRequests(targetHour: 23, targetMinute: 30)
        let first = requests.first!
        let trigger = first.trigger as! UNCalendarNotificationTrigger
        let components = trigger.dateComponents
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 0)
    }
}
