//
//  TestScheduler.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Foundation

// MARK: - TestScheduler

/// A scheduler whose current time and execution can be controlled in a deterministic manner.
///
/// This scheduler is useful for testing how the flow of time effects publishers that use
/// asynchronous operators, such as `debounce`, `throttle`, `delay`, `timeout`, `receive(on:)`,
/// `subscribe(on:)` and more.
///
/// For example, consider the following `race` operator that runs two futures in parallel, but
/// only emits the first one that completes:
///
///     func race<Output, Failure: Error>(
///         _ first: Future<Output, Failure>,
///         _ second: Future<Output, Failure>
///     ) -> AnyPublisher<Output, Failure> {
///         first
///             .merge(with: second)
///             .prefix(1)
///             .eraseToAnyPublisher()
///     }
///
/// Although this publisher is quite simple we may still want to write some tests for it.
///
/// To do this we can create a test scheduler and create two futures, one that emits after a
/// second and one that emits after two seconds:
///
///     let scheduler = DispatchQueue.test
///     let first = Future<Int, Never> { callback in
///         scheduler.schedule(after: scheduler.now.advanced(by: 1)) {
///             callback(.success(1))
///         }
///     }
///     let second = Future<Int, Never> { callback in
///         scheduler.schedule(after: scheduler.now.advanced(by: 2)) {
///             callback(.success(2))
///         }
///     }
///
/// And then we can race these futures and collect their emissions into an array:
///
///     var output: [Int] = []
///     let cancellable = race(first, second).sink { output.append($0) }
///
/// And then we can deterministically move time forward in the scheduler to see how the publisher
/// emits. We can start by moving time forward by one second:
///
///     scheduler.advance(by: 1)
///     XCTAssertEqual(output, [1])
///
/// This proves that we get the first emission from the publisher since one second of time has
/// passed. If we further advance by one more second we can prove that we do not get anymore
/// emissions:
///
///     scheduler.advance(by: 1)
///     XCTAssertEqual(output, [1])
///
/// This is a very simple example of how to control the flow of time with the test scheduler,
/// but this technique can be used to test any publisher that involves Combine's asynchronous
/// operations.
///
public final class TestScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where SchedulerTimeType: Strideable, SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {

    // MARK: - Properties

    /// Last sequence index
    private var lastSequence: UInt = 0

    /// The minimum tolerance allowed by the scheduler
    public let minimumTolerance: SchedulerTimeType.Stride = .zero

    /// This scheduler’s definition of the current moment in time
    public private(set) var now: SchedulerTimeType

    /// Scheduled actions
    private var scheduled: [
        (
            sequence: UInt,
            date: SchedulerTimeType,
            action: () -> Void
        )
    ] = []

    // MARK: - Initializers

    /// Creates a test scheduler with the given date.
    ///
    /// - Parameter now: The current date of the test scheduler.
    public init(now: SchedulerTimeType) {
        self.now = now
    }

    // MARK: - Useful

    /// Advances the scheduler by the given stride
    ///
    /// - Parameter stride: A stride. By default this argument is `.zero`, which does not advance the
    ///   scheduler's time but does cause the scheduler to execute any units of work that are waiting
    ///   to be performed for right now.
    public func advance(by stride: SchedulerTimeType.Stride = .zero) {
        let finalDate = now.advanced(by: stride)
        while now <= finalDate {
            scheduled.sort { ($0.date, $0.sequence) < ($1.date, $1.sequence) }
            guard
                let nextDate = scheduled.first?.date,
                finalDate >= nextDate
            else {
                now = finalDate
                return
            }
            now = nextDate
            while let (_, date, action) = scheduled.first, date == nextDate {
                scheduled.removeFirst()
                action()
            }
        }
    }

    // MARK: - Scheduler

    /// Runs the scheduler until it has no scheduled items left.
    ///
    /// This method is useful for proving exhaustively that your publisher eventually completes
    /// and does not run forever. For example, the following code will run an infinite loop forever
    /// because the timer never finishes:
    ///
    ///     let scheduler = DispatchQueue.test
    ///     Publishers.Timer(every: .seconds(1), scheduler: scheduler)
    ///         .autoconnect()
    ///         .sink { _ in print($0) }
    ///         .store(in: &cancellables)
    ///
    ///     // Will never complete
    ///     scheduler.run()
    ///
    /// If you wanted to make sure that this publisher eventually completes you would need to
    /// chain on another operator that completes it when a certain condition is met. This can be
    /// done in many ways, such as using `prefix`:
    ///
    ///     let scheduler = DispatchQueue.test
    ///     Publishers.Timer(every: .seconds(1), scheduler: scheduler)
    ///       .autoconnect()
    ///       .prefix(3)
    ///       .sink { _ in print($0) }
    ///       .store(in: &cancellables)

    ///     // Prints 3 times and completes
    ///     scheduler.run()
    ///
    public func run() {
        while let date = scheduled.first?.date {
            advance(by: now.distance(to: date))
        }
    }

    /// Performs the action at some time after the specified date, at the
    /// specified frequency, taking into account tolerance if possible (in original version)
    /// - Parameters:
    ///   - date: the date after which the action should occur
    ///   - interval: repeating interval
    ///   - tolerance: the minimum tolerance allowed by the scheduler
    ///   - options: scheduler options
    ///   - action: target action
    /// - Returns: result Cancellable instance
    public func schedule(
        after date: SchedulerTimeType,
        interval: SchedulerTimeType.Stride,
        tolerance _: SchedulerTimeType.Stride,
        options _: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) -> Cancellable {

        let sequence = nextSequence()

        func scheduleAction(for date: SchedulerTimeType) -> () -> Void {
            return { [weak self] in
                let nextDate = date.advanced(by: interval)
                self?.scheduled.append((sequence, nextDate, scheduleAction(for: nextDate)))
                action()
            }
        }

        scheduled.append((sequence, date, scheduleAction(for: date)))

        return AnyCancellable { [weak self] in
            self?.scheduled.removeAll(where: { $0.sequence == sequence })
        }
    }

    /// Performs the action at some time after the specified date (in original version)
    /// - Parameters:
    ///   - date: the date after which the action should occur
    ///   - tolerance: the minimum tolerance allowed by the scheduler
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        after date: SchedulerTimeType,
        tolerance _: SchedulerTimeType.Stride,
        options _: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        scheduled.append((self.nextSequence(), date, action))
    }

    /// Performs the action at the next possible opportunity (in original version)
    /// - Parameters:
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        options _: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        scheduled.append((nextSequence(), now, action))
    }

    // MARK: - Private

    private func nextSequence() -> UInt {
        lastSequence += 1
        return lastSequence
    }
}

// MARK: - DispatchQueue

extension DispatchQueue {

    /// A test scheduler of dispatch queues
    public static var test: TestSchedulerOf<DispatchQueue> {
        // NB: `DispatchTime(uptimeNanoseconds: 0) == .now())`. Use `1` for consistency
        .init(now: .init(.init(uptimeNanoseconds: 1)))
    }
}

// MARK: - OperationQueue

extension OperationQueue {

    /// A test scheduler of operation queues
    public static var test: TestSchedulerOf<OperationQueue> {
        .init(now: .init(.init(timeIntervalSince1970: 0)))
    }
}

// MARK: - RunLoop

extension RunLoop {

    /// A test scheduler of run loops
    public static var test: TestSchedulerOf<RunLoop> {
        .init(now: .init(.init(timeIntervalSince1970: 0)))
    }
}

// MARK: - TestSchedulerOf

/// A convenience type to specify a `TestScheduler` by the scheduler it wraps rather than by the
/// time type and options type
public typealias TestSchedulerOf<Scheduler> = TestScheduler<
    Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
> where Scheduler: Combine.Scheduler
