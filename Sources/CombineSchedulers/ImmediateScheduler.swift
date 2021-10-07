//
//  ImmediateScheduler.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Foundation

/// A scheduler for performing synchronous actions.
///
/// You can only use this scheduler for immediate actions. If you attempt to schedule actions
/// after a specific date, this scheduler ignores the date and performs them immediately.
///
/// This scheduler is useful for writing tests against publishers that use asynchrony operators,
/// such as `receive(on:)`, `subscribe(on:)` and others, because it forces the publisher to emit
/// immediately rather than needing to wait for thread hops or delays using `XCTestExpectation`.
///
/// This scheduler is different from `TestScheduler` in that you cannot explicitly control how
/// time flows through your publisher, but rather you are instantly collapsing time into a single
/// point.
///
/// As a basic example, suppose you have a view model that loads some data after waiting for 10
/// seconds from when a button is tapped:
///
///    // MARK: - HomeViewModel
///
///    final class HomeViewModel: ObservableObject {
///
///        // MARK: - Properties
///
///        /// Current albums list
///        @Published var albums: [Album]?
///
///        /// APIClient instance
///        let apiClient: APIClient
///
///        // MARK: - Initializers
///
///        /// Default initializer
///        /// - Parameter apiClient: APIClient instance
///        init(apiClient: APIClient) {
///            self.apiClient = apiClient
///        }
///
///        /// Process reload button event
///        func reloadButtonTapped() {
///            Just(())
///                .delay(for: .seconds(10), scheduler: DispachQueue.main)
///                .flatMap { apiClient.fetchAlbums() }
///                .assign(to: &self.albums)
///        }
///    }
///
/// In order to test this code you would literally need to wait 10 seconds for the publisher to
/// emit:
///
///     func testViewModel() {
///         let viewModel = HomeViewModel(apiClient: .mock)
///         viewModel.reloadButtonTapped()
///         _ = XCTWaiter.wait(for: [XCTestExpectation()], timeout: 10)
///         XCTAssert(viewModel.albums, [Album(id: 42)])
///     }
///
/// Alternatively, we can explicitly pass a scheduler into the view model initializer so that it
/// can be controller from the outside:
///
///    // MARK: - HomeViewModel
///
///     final class HomeViewModel: ObservableObject {
///
///         // MARK: - Properties
///
///         /// Current albums list
///         @Published var albums: [Album]?
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
///         /// Process reload button event
///         func reloadButtonTapped() {
///             Just(())
///                 .delay(for: .seconds(10), scheduler: scheduler)
///                 .flatMap { apiClient.fetchAlbums() }
///                 .assign(to: &self.albums)
///         }
///     }
///
/// And then in tests use an immediate scheduler:
///
///     func testViewModel() {
///
///         let viewModel = HomeViewModel(
///             apiClient: .mock,
///             scheduler: .immediate
///         )
///
///         viewModel.reloadButtonTapped()
///
///         // No more waiting...
///
///         XCTAssert(viewModel.albums, [Album(id: 42)])
///     }
///
/// - Note: This scheduler can _not_ be used to test publishers with more complex timing logic,
///   like those that use `Debounce`, `Throttle`, or `Timer.Publisher`, and in fact
///   `ImmediateScheduler` will not schedule this work in a defined way. Use a `TestScheduler`
///   instead to capture your publisher's timing behavior.
///
public struct ImmediateScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where
    SchedulerTimeType: Strideable,
    SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
{

    // MARK: - Properties

    /// The minimum tolerance allowed by the scheduler
    public let minimumTolerance: SchedulerTimeType.Stride = .zero

    /// This scheduler’s definition of the current moment in time
    public let now: SchedulerTimeType

    // MARK: - Initializers

    /// Creates an immediate test scheduler with the given date.
    ///
    /// - Parameter now: The current date of the test scheduler.
    public init(now: SchedulerTimeType) {
        self.now = now
    }

    /// Performs the action immediately
    /// - Parameters:
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        options _: SchedulerOptions?,
        _ action: () -> Void
    ) {
        action()
    }

    /// Performs the action immediately
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
        action()
    }

    /// Performs the action immediately
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
        action()
        return AnyCancellable {}
    }
}

// MARK: - DispatchQueue

extension DispatchQueue {

    /// An immediate scheduler that can substitute itself for a dispatch queue
    public static var immediate: ImmediateSchedulerOf<DispatchQueue> {
        // NB: `DispatchTime(uptimeNanoseconds: 0) == .now())`. Use `1` for consistency
        .init(now: .init(.init(uptimeNanoseconds: 1)))
    }
}

// MARK: - OperationQueue

extension OperationQueue {

    /// An immediate scheduler that can substitute itself for an operation queue
    public static var immediate: ImmediateSchedulerOf<OperationQueue> {
        .init(now: .init(.init(timeIntervalSince1970: 0)))
    }
}

// MARK: - RunLoop

extension RunLoop {

    /// An immediate scheduler that can substitute itself for a run loop
    public static var immediate: ImmediateSchedulerOf<RunLoop> {
        .init(now: .init(.init(timeIntervalSince1970: 0)))
    }
}

extension AnyScheduler
where
    SchedulerTimeType == DispatchQueue.SchedulerTimeType,
    SchedulerOptions == DispatchQueue.SchedulerOptions
{
    /// An immediate scheduler that can substitute itself for a dispatch queue
    public static var immediate: Self {
        DispatchQueue.immediate.eraseToAnyScheduler()
    }
}

// MARK: - Immediate

extension AnyScheduler
where
    SchedulerTimeType == OperationQueue.SchedulerTimeType,
    SchedulerOptions == OperationQueue.SchedulerOptions
{
    /// An immediate scheduler that can substitute itself for an operation queue
    public static var immediate: Self {
        OperationQueue.immediate.eraseToAnyScheduler()
    }
}

extension AnyScheduler
where
    SchedulerTimeType == RunLoop.SchedulerTimeType,
    SchedulerOptions == RunLoop.SchedulerOptions
{
    /// An immediate scheduler that can substitute itself for a run loop
    public static var immediate: Self {
        RunLoop.immediate.eraseToAnyScheduler()
    }
}

/// A convenience type to specify an `ImmediateScheduler` by the scheduler it wraps rather than by
/// the time type and options type
public typealias ImmediateSchedulerOf<Scheduler> = ImmediateScheduler<
    Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
> where Scheduler: Combine.Scheduler
