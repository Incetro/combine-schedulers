//
//  AnyScheduler.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Foundation

// MARK: - AnyScheduler

/// A type-erasing wrapper for the `Scheduler` protocol, which can be useful for being generic over
/// many types of schedulers without needing to actually introduce a generic to your code.
///
/// This type is useful for times that you want to be able to customize the scheduler used in some
/// code from the outside, but you don't want to introduce a generic to make it customizable. For
/// example, suppose you have a view model `ObservableObject` that performs an API request when a
/// method is called:
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
///         // MARK: - Initializers
///
///         /// Default initializer
///         /// - Parameter apiClient: APIClient instance
///         init(apiClient: APIClient) {
///             self.apiClient = apiClient
///         }
///
///         // MARK: - Useful
///
///         /// Process reload button event
///         func reloadButtonTapped() {
///             self.apiClient
///                 .fetchCurrency()
///                 .receive(on: DispatchQueue.main)
///                 .assign(to: &self.$currency)
///         }
///     }
///
/// Notice that we are using `DispatchQueue.main` in the `reloadButtonTapped` method because the
/// `fetchCurrency` endpoint most likely delivers its output on a background thread (as is the case
/// with `URLSession`).
///
/// This code seems innocent enough, but the presence of `.receive(on: DispatchQueue.main)` makes
/// this code harder to test since you have to use `XCTest` expectations to explicitly wait a small
/// amount of time for the queue to execute. This can lead to flakiness in tests and make test
/// suites take longer to execute than necessary.
///
/// One way to fix this testing problem is to use an "immediate" scheduler instead of
/// `DispatchQueue.main`, which will cause `fetchCurrency` to deliver its output as soon as possible
/// with no thread hops. In order to allow for this we would need to inject a scheduler into our
/// view model so that we can control it from the outside:
///
///     // MARK: - CurrencyViewModel
///
///     final class CurrencyViewModel<S: Scheduler>: ObservableObject {
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
///         let scheduler: S
///
///         // MARK: - Initializers
///
///         /// Default initializer
///         /// - Parameters:
///         ///   - apiClient: APIClient instance
///         ///   - scheduler: Current scheduler instance
///         init(apiClient: APIClient, scheduler: S) {
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
///     }
///
/// Now we can initialize this view model in production by using `DispatchQueue.main` and we can
/// initialize it in tests using `DispatchQueue.immediate`. Sounds like a win!
///
/// However, introducing this generic to our view model is quite heavyweight as it is loudly
/// announcing to the outside world that this type uses a scheduler, and worse it will end up
/// infecting any code that touches this view model that also wants to be testable. For example,
/// any view that uses this view model will need to introduce a generic if it wants to also be able
/// to control the scheduler, which would be useful if we wanted to write snapshot tests.
///
/// Instead of introducing a generic to allow for substituting in different schedulers we can use
/// `AnyScheduler`. It allows us to be somewhat generic in the scheduler, but without actually
/// introducing a generic.
///
/// Instead of holding a generic scheduler in our view model we can say that we only want a
/// scheduler whose associated types match that of `DispatchQueue`:
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
///     }
///
/// Then, in production we can create a view model that uses a live `DispatchQueue`, but we just
/// have to first erase its type:
///
///     let viewModel = CurrencyViewModel(
///         apiClient: apiClient,
///         scheduler: DispatchQueue.main.eraseToAnyScheduler()
///     )
///
/// For common schedulers, like `DispatchQueue`, `OperationQueue`, and `RunLoop`, there is even a
/// static helper on `AnyScheduler` that further simplifies this:
///
///     let viewModel = CurrencyViewModel(
///         apiClient: apiClient,
///         scheduler: .main
///     )
///
/// And in tests we can use an immediate scheduler:
///
///     let viewModel = CurrencyViewModel(
///         apiClient: apiClient,
///         scheduler: .immediate
///     )
///
/// So, in general, `AnyScheduler` is great for allowing one to control what scheduler is used
/// in classes, functions, etc. without needing to introduce a generic, which can help simplify
/// the code and reduce implementation details from leaking out.
///
public struct AnyScheduler<SchedulerTimeType, SchedulerOptions>: Scheduler
where
    SchedulerTimeType: Strideable,
    SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
{

    // MARK: - Properties

    /// The minimum tolerance allowed by the scheduler
    private let _minimumTolerance: () -> SchedulerTimeType.Stride

    /// This scheduler’s definition of the current moment in time
    private let _now: () -> SchedulerTimeType

    /// /// Performs the action at some time after the specified date,
    /// at the specified frequency, optionally taking into account tolerance
    /// if possible
    private let _scheduleAfterIntervalToleranceOptionsAction:
        (
            SchedulerTimeType,
            SchedulerTimeType.Stride,
            SchedulerTimeType.Stride,
            SchedulerOptions?,
            @escaping () -> Void
        ) -> Cancellable

    /// Performs the action at some time after the specified date
    private let _scheduleAfterToleranceOptionsAction:
        (
            SchedulerTimeType,
            SchedulerTimeType.Stride,
            SchedulerOptions?,
            @escaping () -> Void
        ) -> Void

    /// Performs the action at the next possible opportunity
    private let _scheduleOptionsAction:
        (
            SchedulerOptions?,
            @escaping () -> Void
        ) -> Void

    /// The minimum tolerance allowed by the scheduler
    public var minimumTolerance: SchedulerTimeType.Stride { self._minimumTolerance() }

    /// This scheduler’s definition of the current moment in time
    public var now: SchedulerTimeType { self._now() }

    // MARK: - Initializers

    /// Creates a type-erasing scheduler to wrap the provided endpoints
    ///
    /// - Parameters:
    ///   - minimumTolerance: a closure that returns the scheduler's minimum tolerance
    ///   - now: a closure that returns the scheduler's current time
    ///   - scheduleImmediately: a closure that schedules a unit of work to be run as soon as possible
    ///   - delayed: a closure that schedules a unit of work to be run after a delay
    ///   - interval: a closure that schedules a unit of work to be performed on a repeating interval
    public init(
        minimumTolerance: @escaping () -> SchedulerTimeType.Stride,
        now: @escaping () -> SchedulerTimeType,
        scheduleImmediately: @escaping (
            SchedulerOptions?,
            @escaping () -> Void
        ) -> Void,
        delayed: @escaping (
            SchedulerTimeType, SchedulerTimeType.Stride, SchedulerOptions?, @escaping () -> Void
        ) -> Void,
        interval: @escaping (
            SchedulerTimeType, SchedulerTimeType.Stride, SchedulerTimeType.Stride, SchedulerOptions?,
            @escaping () -> Void
        ) -> Cancellable
    ) {
        self._minimumTolerance = minimumTolerance
        self._now = now
        self._scheduleOptionsAction = scheduleImmediately
        self._scheduleAfterToleranceOptionsAction = delayed
        self._scheduleAfterIntervalToleranceOptionsAction = interval
    }

    /// Creates a type-erasing scheduler to wrap the provided scheduler
    ///
    /// - Parameters:
    ///   - scheduler: a scheduler to wrap with a type-eraser
    public init<S>(_ scheduler: S)
    where
        S: Scheduler,
        S.SchedulerTimeType == SchedulerTimeType,
        S.SchedulerOptions == SchedulerOptions
    {
        self._now = { scheduler.now }
        self._minimumTolerance = { scheduler.minimumTolerance }
        self._scheduleAfterToleranceOptionsAction = scheduler.schedule
        self._scheduleAfterIntervalToleranceOptionsAction = scheduler.schedule
        self._scheduleOptionsAction = scheduler.schedule
    }

    // MARK: - Scheduler

    /// Performs the action at some time after the specified date
    /// - Parameters:
    ///   - date: the date after which the action should occur
    ///   - tolerance: the minimum tolerance allowed by the scheduler
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        after date: SchedulerTimeType,
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        self._scheduleAfterToleranceOptionsAction(
            date,
            tolerance,
            options,
            action
        )
    }

    /// Performs the action at some time after the specified date, at the
    /// specified frequency, taking into account tolerance if possible
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
        tolerance: SchedulerTimeType.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        self._scheduleAfterIntervalToleranceOptionsAction(
            date,
            interval,
            tolerance,
            options,
            action
        )
    }

    /// Performs the action at the next possible opportunity
    /// - Parameters:
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        self._scheduleOptionsAction(options, action)
    }
}

// MARK: - AnySchedulerOf

/// A convenience type to specify an `AnyScheduler`
/// by the scheduler it wraps rather than by the
/// time type and options type
public typealias AnySchedulerOf<Scheduler> = AnyScheduler<
    Scheduler.SchedulerTimeType, Scheduler.SchedulerOptions
> where Scheduler: Combine.Scheduler

// MARK: - Scheduler

extension Scheduler {

    /// Wraps current scheduler with a type eraser
    public func eraseToAnyScheduler() -> AnyScheduler<SchedulerTimeType, SchedulerOptions> {
        AnyScheduler(self)
    }
}

// MARK: - DispatchQueue

extension AnyScheduler
where
    SchedulerTimeType == DispatchQueue.SchedulerTimeType,
    SchedulerOptions == DispatchQueue.SchedulerOptions
{
    /// A type-erased main dispatch queue
    public static var main: Self {
        DispatchQueue.main.eraseToAnyScheduler()
    }
}

// MARK: - OperationQueue

extension AnyScheduler
where
    SchedulerTimeType == OperationQueue.SchedulerTimeType,
    SchedulerOptions == OperationQueue.SchedulerOptions
{
    /// A type-erased main operation queue
    public static var main: Self {
        OperationQueue.main.eraseToAnyScheduler()
    }
}

// MARK: - RunLoop

extension AnyScheduler
where
    SchedulerTimeType == RunLoop.SchedulerTimeType,
    SchedulerOptions == RunLoop.SchedulerOptions
{
    /// A type-erased main run loop
    public static var main: Self {
        RunLoop.main.eraseToAnyScheduler()
    }
}
