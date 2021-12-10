//
//  Lock.swift
//  verse
//
//  Created by incetro on 01/01/2021.
//  Copyright © 2021 Incetro Inc. All rights reserved.
//

import Darwin

// MARK: - Aliases

@available(macOS 10.12, iOS 10, tvOS 10, watchOS 3, *)
typealias Lock = os_unfair_lock_t

// MARK: - Lock

@available(macOS 10.12, iOS 10, tvOS 10, watchOS 3, *)
extension UnsafeMutablePointer where Pointee == os_unfair_lock_s {

    /// Lock initializer
    init() {
        let l = UnsafeMutablePointer.allocate(capacity: 1)
        l.initialize(to: os_unfair_lock())
        self = l
    }

    /// Cleanup our lock
    func cleanupLock() {
        deinitialize(count: 1)
        deallocate()
    }

    /// Locking method
    func lock() {
        os_unfair_lock_lock(self)
    }

    /// Try-locking method
    func tryLock() -> Bool {
        let result = os_unfair_lock_trylock(self)
        return result
    }

    /// Unlocking method
    func unlock() {
        os_unfair_lock_unlock(self)
    }
}
