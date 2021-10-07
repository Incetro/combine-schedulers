//
//  SwiftUI.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Combine
import SwiftUI

// MARK: - Scheduler

extension Scheduler {

    /// Specifies an animation to perform when an action is scheduled. This can be useful for times
    /// that you cannot easily wrap state mutations in a `withAnimation` block.
    ///
    /// For example, if you load some asynchronous data in an `ObservableObject` and then
    /// pipe its output into a `@Published` field, you may be tempted to use the `.assign(to:)`
    /// operator:
    ///
    ///     // MARK: - ViewModel
    ///
    ///     final class ViewModel: ObservableObject {
    ///
    ///         // MARK: - Properties
    ///
    ///         /// Some articles
    ///         @Published var articles: [Article] = []
    ///
    ///         // MARK: - Initializers
    ///
    ///         /// Default initializer
    ///         init() {
    ///             apiClient
    ///                 .loadArticles()
    ///                 .receive(on: DispatchQueue.main)
    ///                 .assign(to: &self.$articles)
    ///         }
    ///     }
    ///
    /// However, this prevents you from wrapping the `articles` mutation in `withAnimation` since
    /// that is hidden from you in the `.assign(to:)` operator. In this situation you can simply
    /// use the `.animation` operator on `Scheduler` to transform `DispatchQueue.main` into a
    /// scheduler that performs its work inside `withAnimation`:
    ///
    ///     // MARK: - ViewModel
    ///
    ///     final class ViewModel: ObservableObject {
    ///
    ///         // MARK: - Properties
    ///
    ///         /// Some articles
    ///         @Published var articles: [Article] = []
    ///
    ///         // MARK: - Initializers
    ///
    ///         /// Default initializer
    ///         init() {
    ///             apiClient
    ///                 .loadArticles()
    ///                 .receive(on: DispatchQueue.main.animation())
    ///                 .assign(to: &self.$articles)
    ///         }
    ///     }
    ///
    /// Another common use case is when you have a Combine publisher made up of many publishers
    /// that have been merged or concatenated. You may want to animate the outputs of each of
    /// those publishers differently:
    ///
    ///     class ViewModel: ObservableObject {
    ///       @Published var articles: [Article] = []
    ///
    ///       init() {
    ///         cachedArticles()
    ///           // Don't animate cached articles when they load
    ///           .receive(on: DispatchQueue.main.animation(nil))
    ///           .append(
    ///             apiClient.loadArticles()
    ///               // Animate the fresh articles when they load
    ///               .receive(on: DispatchQueue.main.animation())
    ///           )
    ///       }
    ///     }
    ///
    ///     // MARK: - ViewModel
    ///
    ///     final class ViewModel: ObservableObject {
    ///
    ///         // MARK: - Properties
    ///
    ///         /// Some articles
    ///         @Published var articles: [Article] = []
    ///
    ///         // MARK: - Initializers
    ///
    ///         /// Default initializer
    ///         init() {
    ///             cachedArticles()
    ///             // Don't animate cached articles when they load
    ///             .receive(on: DispatchQueue.main.animation(nil))
    ///             .append(
    ///                 apiClient
    ///                     .loadArticles()
    ///                     // Animate the fresh articles when they load
    ///                     .receive(on: DispatchQueue.main.animation())
    ///         }
    ///     }
    ///
    /// - Parameter animation: an animation to be performed
    /// - Returns: a scheduler that performs an animation when a scheduled action is run
    public func animation(_ animation: Animation? = .default) -> AnySchedulerOf<Self> {
        AnyScheduler(
            minimumTolerance: { minimumTolerance },
            now: { now },
            scheduleImmediately: { options, action in
                schedule(options: options) {
                    withAnimation(animation, action)
                }
            },
            delayed: { date, tolerance, options, action in
                schedule(after: date, tolerance: tolerance, options: options) {
                    withAnimation(animation, action)
                }
            },
            interval: { date, interval, tolerance, options, action in
                schedule(after: date, interval: interval, tolerance: tolerance, options: options) {
                    withAnimation(animation, action)
                }
            }
        )
    }

    /// Wraps scheduled actions in a transaction
    ///
    /// - Parameter transaction: a transaction
    /// - Returns: a scheduler that wraps scheduled actions in a transaction
    public func transaction(_ transaction: Transaction) -> AnySchedulerOf<Self> {
        AnyScheduler(
            minimumTolerance: { minimumTolerance },
            now: { now },
            scheduleImmediately: { options, action in
                schedule(options: options) {
                    withTransaction(transaction, action)
                }
            },
            delayed: { date, tolerance, options, action in
                schedule(after: date, tolerance: tolerance, options: options) {
                    withTransaction(transaction, action)
                }
            },
            interval: { date, interval, tolerance, options, action in
                schedule(after: date, interval: interval, tolerance: tolerance, options: options) {
                    withTransaction(transaction, action)
                }
            }
        )
    }
}
