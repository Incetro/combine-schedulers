//
//  FailingScheduler.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Foundation
import XCTestInterfaceAdapter

// MARK: - FailingScheduler

/// A scheduler that causes the current XCTest test case to fail if it is used.
///
/// This scheduler can provide an additional layer of certainty that a tested code path does not
/// require the use of a scheduler.
///
/// As a view model becomes more complex, only some of its logic may require a scheduler. When
/// writing unit tests for any logic that does _not_ require a scheduler, one should provide a
/// failing scheduler, instead. This documents, directly in the test, that the feature does not
/// use a scheduler. If it did, or ever does in the future, the test will fail.
///
/// For example, the following view model has a couple responsibilities:
///
///     // MARK: - CurrencyViewModel
///
///     final class CurrencyViewModel: ObservableObject {
///
///         // MARK: - Properties
///
///         /// Current currency value
///         @Published var currency: Currency?
///
///         /// APIClient instance
///         let apiClient: APIClient
///
///         /// Current scheduler instance
///         let scheduler: AnySchedulerOf<DispatchQueue>
///
///         // MARK: - Initializers
///
///         /// Default initializer
///         /// - Parameters:
///         ///   - apiClient: APIClient instance
///         ///   - scheduler: Current scheduler instance
///         init(apiClient: APIClient, scheduler: AnySchedulerOf<DispatchQueue>) {
///             self.apiClient = apiClient
///             self.scheduler = scheduler
///         }
///
///         // MARK: - Useful
///
///         /// Process reload button event
///         func reloadButtonTapped() {
///             self.apiClient
///                 .fetchCurrency()
///                 .receive(on: self.scheduler)
///                 .assign(to: &self.$currency)
///         }
///
///         /// Process favorite button event
///         func favoriteButtonTapped() {
///             self.currency?.isFavorite.toggle()
///         }
///     }
///
///   * It lets the user tap a button to refresh some currency data
///   * It lets the user toggle if the currency is one of their favorites
///
/// The API client delivers the currency on a background queue, so the view model must receive it
/// on its main queue before mutating its state.
///
/// Tapping the reload button, however, involves no scheduling. This means that a test can be
/// written with a failing scheduler:
///
///     func testFavoriteButton() {
///
///         let viewModel = CurrencyViewModel(
///             apiClient: .mock,
///             mainQueue: .failing
///         )
///         viewModel.currency = .mock
///
///         viewModel.favoriteButtonTapped()
///         XCTAssert(viewModel.currency?.isFavorite == true)
///
///         viewModel.favoriteButtonTapped()
///         XCTAssert(viewModel.currency?.isFavorite == false)
///     }
///
/// With `.failing`, this test pretty strongly declares that favoriting an currency does not need
/// a scheduler to do the job, which means it is reasonable to assume that the feature is simple
/// and does not involve any asynchrony.
///
/// In the future, should favoriting an currency fire off an API request that involves a scheduler,
/// this test will begin to fail, which is a good thing! This will force us to address the
/// complexity that was introduced. Had we used any other scheduler, it would quietly receive this
/// additional work and the test would continue to pass.
public struct FailingScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where
    SchedulerTimeType: Strideable,
    SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
{

    // MARK: - Properties

    /// The minimum tolerance allowed by the scheduler
    public var minimumTolerance: SchedulerTimeType.Stride {
        XCTFail("""
        \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
        A failing scheduler was asked its minimum tolerance.
        """
        )
        return self._minimumTolerance
    }

    /// This scheduler’s definition of the current moment in time
    public var now: SchedulerTimeType {
        XCTFail("""
        \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
        A failing scheduler was asked the current time.
        """
        )
        return self._now
    }

    /// Auxilary prefix
    public let prefix: String

    /// The minimum tolerance allowed by the scheduler
    private let _minimumTolerance: SchedulerTimeType.Stride = .zero

    /// This scheduler’s definition of the current moment in time
    private let _now: SchedulerTimeType

    // MARK: - Initializers

    /// Creates a failing test scheduler with the given date
    ///
    /// - Parameters:
    ///   - prefix: A string that identifies this scheduler and will prefix all failure messages
    ///   - now: now: The current date of the failing scheduler
    public init(_ prefix: String = "", now: SchedulerTimeType) {
        self._now = now
        self.prefix = prefix
    }

    // MARK: - Scheduler

    /// Performs the action at the next possible opportunity (in original version)
    /// - Parameters:
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        options _: SchedulerOptions?,
        _ action: () -> Void
    ) {
        XCTFail("""
        \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
        A failing scheduler scheduled an action to run immediately.
        """
        )
    }

    /// Performs the action at some time after the specified date (in original version)
    /// - Parameters:
    ///   - date: the date after which the action should occur
    ///   - tolerance: the minimum tolerance allowed by the scheduler
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        after _: SchedulerTimeType,
        tolerance _: SchedulerTimeType.Stride,
        options _: SchedulerOptions?,
        _ action: () -> Void
    ) {
        XCTFail("""
        \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
        A failing scheduler scheduled an action to run later.
        """
        )
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
        after _: SchedulerTimeType,
        interval _: SchedulerTimeType.Stride,
        tolerance _: SchedulerTimeType.Stride,
        options _: SchedulerOptions?,
        _ action: () -> Void
    ) -> Cancellable {
        XCTFail(
            """
        \(self.prefix.isEmpty ? "" : "\(self.prefix) - ")\
        A failing scheduler scheduled an action to run on a timer.
        """
        )
        return AnyCancellable {}
    }
}

// MARK: - DispatchQueue

extension DispatchQueue {

    /// A failing scheduler that can substitute itself for a dispatch queue
    public static var failing: FailingSchedulerOf<DispatchQueue> {
        Self.failing("DispatchQueue")
    }

    /// A failing scheduler that can substitute itself for a dispatch queue
    ///
    /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
    ///   messages
    /// - Returns: A failing scheduler.
    public static func failing(_ prefix: String) -> FailingSchedulerOf<DispatchQueue> {
        // NB: `DispatchTime(uptimeNanoseconds: 0) == .now())`. Use `1` for consistency
        .init(prefix, now: .init(.init(uptimeNanoseconds: 1)))
    }
}

// MARK: - OperationQueue

extension OperationQueue {

    /// A failing scheduler that can substitute itself for an operation queue
    public static var failing: FailingSchedulerOf<OperationQueue> {
        Self.failing("OperationQueue")
    }

    /// A failing scheduler that can substitute itself for an operation queue
    ///
    /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
    ///   messages
    /// - Returns: A failing scheduler
    public static func failing(_ prefix: String) -> FailingSchedulerOf<OperationQueue> {
        .init(prefix, now: .init(.init(timeIntervalSince1970: 0)))
    }
}

// MARK: - RunLoop

extension RunLoop {

    /// A failing scheduler that can substitute itself for a run loop
    public static var failing: FailingSchedulerOf<RunLoop> {
        Self.failing("RunLoop")
    }

    /// A failing scheduler that can substitute itself for a run loop
    ///
    /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
    ///   messages
    /// - Returns: A failing scheduler
    public static func failing(_ prefix: String) -> FailingSchedulerOf<RunLoop> {
        .init(prefix, now: .init(.init(timeIntervalSince1970: 0)))
    }
}

// MARK: - Failing

extension AnyScheduler
where
    SchedulerTimeType == DispatchQueue.SchedulerTimeType,
    SchedulerOptions == DispatchQueue.SchedulerOptions
{
    /// A failing scheduler that can substitute itself for a dispatch queue
    public static var failing: Self {
        DispatchQueue.failing.eraseToAnyScheduler()
    }

    /// A failing scheduler that can substitute itself for a dispatch queue
    ///
    /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
    ///   messages
    /// - Returns: A failing scheduler
    public static func failing(_ prefix: String) -> Self {
        DispatchQueue.failing(prefix).eraseToAnyScheduler()
    }
}

extension AnyScheduler
where
    SchedulerTimeType == OperationQueue.SchedulerTimeType,
    SchedulerOptions == OperationQueue.SchedulerOptions
{
    /// A failing scheduler that can substitute itself for an operation queue
    public static var failing: Self {
        OperationQueue.failing.eraseToAnyScheduler()
    }

    /// A failing scheduler that can substitute itself for an operation queue
    ///
    /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
    ///   messages
    /// - Returns: A failing scheduler
    public static func failing(_ prefix: String) -> Self {
        OperationQueue.failing(prefix).eraseToAnyScheduler()
    }
}

extension AnyScheduler
where
    SchedulerTimeType == RunLoop.SchedulerTimeType,
    SchedulerOptions == RunLoop.SchedulerOptions
{
    /// A failing scheduler that can substitute itself for a run loop
    public static var failing: Self {
        RunLoop.failing.eraseToAnyScheduler()
    }

    /// A failing scheduler that can substitute itself for a run loop
    ///
    /// - Parameter prefix: A string that identifies this scheduler and will prefix all failure
    ///   messages
    /// - Returns: A failing scheduler
    public static func failing(_ prefix: String) -> Self {
        RunLoop.failing(prefix).eraseToAnyScheduler()
    }
}

// MARK: - FailingSchedulerOf

/// A convenience type to specify a `FailingScheduler` by the scheduler it wraps rather than by
/// the time type and options type
public typealias FailingSchedulerOf<Scheduler> = FailingScheduler<
    Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
> where Scheduler: Combine.Scheduler
