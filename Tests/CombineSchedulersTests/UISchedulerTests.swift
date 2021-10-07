import Combine
import CombineSchedulers
import XCTest

// MARK: - UISchedulerTests

final class UISchedulerTests: XCTestCase {

    // MARK: - Tests

    func testVoidsThreadHop() {
        var worked = false
        UIScheduler.shared.schedule { worked = true }
        XCTAssert(worked)
    }

    func testRunsOnMain() {

        let queue = DispatchQueue.init(label: "queue")
        let exp = expectation(description: "wait")

        var worked = false
        queue.async {
            XCTAssert(!Thread.isMainThread)
            UIScheduler.shared.schedule {
                XCTAssert(Thread.isMainThread)
                worked = true
                exp.fulfill()
            }
            XCTAssertFalse(worked)
        }

        wait(for: [exp], timeout: 1)
        XCTAssertTrue(worked)
    }
}
