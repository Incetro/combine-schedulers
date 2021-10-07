//
//  UIScheduler.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import Dispatch

// MARK: - UIScheduler

/// A scheduler that executes its work on the main queue as soon as possible.
///
/// This scheduler is inspired by the
/// [equivalent](https://github.com/ReactiveCocoa/ReactiveSwift/blob/58d92aa01081301549c48a4049e215210f650d07/Sources/Scheduler.swift#L92)
/// scheduler in the [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift) project.
///
/// If `UIScheduler.shared.schedule` is invoked from the main thread then the unit of work will be
/// performed immediately. This is in contrast to `DispatchQueue.main.schedule`, which will incur
/// a thread hop before executing since it uses `DispatchQueue.main.async` under the hood.
///
/// This scheduler can be useful for situations where you need work executed as quickly as
/// possible on the main thread, and for which a thread hop would be problematic, such as when
/// performing animations.
public struct UIScheduler: Scheduler {

    // MARK: - Aliases

    public typealias SchedulerOptions = Never
    public typealias TimeType = DispatchQueue.SchedulerTimeType

    // MARK: - Properties

    /// The shared instance of the UI scheduler
    ///
    /// You cannot create instances of the UI scheduler yourself.
    /// Use only the shared instance
    public static let shared = Self()

    /// This scheduler’s definition of the current moment in time
    public var now: TimeType {
        DispatchQueue.main.now
    }

    /// The minimum tolerance allowed by the scheduler
    public var minimumTolerance: TimeType.Stride {
        DispatchQueue.main.minimumTolerance
    }

    // MARK: - Initializers

    /// Default private initializer
    private init() {
        _ = setSpecific
    }

    // MARK: - Scheduler

    /// Performs the action at the next possible opportunity
    /// - Parameters:
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        options: SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) {
        if DispatchQueue.getSpecific(key: key) == value {
            action()
        } else {
            DispatchQueue.main.schedule(action)
        }
    }

    /// Performs the action at some time after the specified date
    /// - Parameters:
    ///   - date: the date after which the action should occur
    ///   - tolerance: the minimum tolerance allowed by the scheduler
    ///   - options: scheduler options
    ///   - action: target action
    public func schedule(
        after date: TimeType,
        tolerance: TimeType.Stride,
        options: SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) {
        DispatchQueue.main.schedule(
            after: date,
            tolerance: tolerance,
            options: nil,
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
        after date: TimeType,
        interval: TimeType.Stride,
        tolerance: TimeType.Stride,
        options: SchedulerOptions? = nil,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        DispatchQueue.main.schedule(
            after: date,
            interval: interval,
            tolerance: tolerance,
            options: nil,
            action
        )
    }
}

// MARK: - Helpers

private let key = DispatchSpecificKey<UInt8>()
private let value: UInt8 = 0
private var setSpecific: () = { DispatchQueue.main.setSpecific(key: key, value: value) }()
