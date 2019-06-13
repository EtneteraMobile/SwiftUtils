/**

 Utilities that simplify work with GCD in Swift.

 Created by Jan Čislinský on 25/08/16.
 Copyright © 2016 Etnetera, a.s. All rights reserved.

 */

import Foundation

// swiftlint:disable identifier_name force_unwrapping
/**
 Debouncing will bunch a series of sequential calls to a function into a single
 call to that function. It ensures that one notification is made for an event
 that fires multiple times.
 */
public class Debounce: NSObject {

    // MARK: - Variables

    private static var mappings = [String: DispatchSourceTimer]()

    // MARK: - Actions

    /// | ... delay timer
    ///
    /// e ... event
    ///
    /// f ... debounced event
    ///
    /// ```
    ///           |delay|
    /// e e e e e e
    /// - - - - - - - - f
    /// ```
    public static func run(_ identifier: String, delay: TimeInterval, action: @escaping () -> Void) {
        let runningSource = mappings[identifier]

        // Cancels previously running source
        if let s = runningSource {
            s.cancel()
        }
        let newSource = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: .main)
        newSource.schedule(deadline: .now() + delay)
        newSource.setEventHandler {
            action()
            newSource.cancel()
            self.mappings[identifier] = nil
        }
        newSource.resume()

        self.mappings[identifier] = newSource
    }

    public static func cancel(_ identifier: String) {
        let runningSource = mappings[identifier]

        // Cancels previously running source
        if let s = runningSource {
            s.cancel()
        }

        self.mappings[identifier] = nil
    }

    /// | ... delay timer
    ///
    /// e ... event
    ///
    /// f ... debounced event
    ///
    /// ```
    /// |     |
    /// e e e e e e
    /// f - - f
    /// ```
    @objc(runReversedWithId:delay:now:action:)
    static public func runReversed(_ identifier: String, delay: TimeInterval, now: Bool = false, action: () -> Void) {
        // Returns if source is running
        if now == false && mappings[identifier] != nil {
            return
        }
        // Cancel current running when now == true
        else if now == true, let running = mappings[identifier] {
            running.cancel()
            mappings[identifier] = nil
        }

        let newSource = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: .main)
        self.mappings[identifier] = newSource
        action()
        newSource.schedule(deadline: .now() + delay)
        newSource.setEventHandler {
            newSource.cancel()
            self.mappings[identifier] = nil
        }
        newSource.resume()
    }
}

public struct Throttle {
    // MARK: - Variables

    private static var workItems = [String: DispatchWorkItem]()
    private static var lastFires = [String: TimeInterval]()

    // MARK: - Actions

    /// | ... delay timer
    ///
    /// e ... event
    ///
    /// t ... throttled event
    ///
    /// ```
    /// |       |       |
    /// e e e e e e
    /// f - - - f - - - f
    /// ```
    public static func run(_ identifier: String, delay: TimeInterval, queue: DispatchQueue = .main, action: @escaping () -> Void) {
        // stop previous, because I've newer data which will be called immediately or in a proper delay
        workItems[identifier]?.cancel()

        workItems[identifier] = DispatchWorkItem {
            action()
            lastFires[identifier] = Date().timeIntervalSinceReferenceDate
            workItems[identifier] = nil
        }
        let sinceReference = Date().timeIntervalSinceReferenceDate
        let lastFire = lastFires[identifier] ?? 0
        let elapsedSinceLastFire = sinceReference - lastFire

        if elapsedSinceLastFire > delay {
            if queue == .main, Thread.isMainThread {
                workItems[identifier]!.perform()
            } else {
                queue.async(execute: workItems[identifier]!)
            }
        } else {
            queue.asyncAfter(deadline: .now() + (delay - elapsedSinceLastFire), execute: workItems[identifier]!)
        }
    }
}

/**
 Composite of `dispatch_semaphore_t` that creates human readable interface for
 semaphore.
 */
public struct Semaphore {

    // MARK: - Variables

    let semaphore: DispatchSemaphore

    // MARK: - Initialization

    public init(value: Int = 0) {
        semaphore = DispatchSemaphore(value: value)
    }

    // MARK: - Actions

    /**
     Blocks the thread until the semaphore is free and returns true
     or until the timeout passes and returns false

     - parameter nanosecondTimeout: Timeout for semaphore

     - returns: false = timeout triggered
     */
    public func wait(_ nanosecondTimeout: Int64) -> Bool {
        return semaphore.wait(timeout: .now() + Double(nanosecondTimeout) / Double(NSEC_PER_SEC)) == .success
    }

    /**
     Blocks the thread until the semaphore is free.
     */
    public func wait() {
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
    }

    /**
     Alerts the semaphore that it is no longer being held by the current thread
     and returns a boolean indicating whether another thread was woken

     - returns: true = another thread was woken
     */
    @discardableResult public func signal() -> Bool {
        return semaphore.signal() != 0
    }
}

/**

 Dispatches given closure according chained modificators.

 - note: Available modificators: async, sync, barrierAsync, main, background, queue(q), after(t).
 - note: Default values: Main queue, synchronized, without delay.

 */
public class Dispatcher {
    public typealias NiladicClosure = () -> Void
    public typealias RunAfterCancel = () -> Void

    // MARK: - Enums

    public enum DispatcherMethod {
        case sync, async, barrierAsync
    }

    public enum Queue {
        case main, background, specific
    }

    // MARK: - Variables

    fileprivate var closure: NiladicClosure?
    fileprivate var dispatchMethod: DispatcherMethod = .sync
    fileprivate var queueType: Queue = .main
    fileprivate var specificQueue: DispatchQueue?
    fileprivate var delayTime: TimeInterval?
    private var cancelled: Bool = false
    private var runAfterCancel: RunAfterCancel?

    // MARK: - Initialization

    public init(_ closure: NiladicClosure? = nil) {
        self.closure = closure
    }

    // MARK: - Modificators

    /** Submits a block to a dispatch queue for synchronous execution. Unlike
     dispatch_async, this function does not return until the block has finished.
     Calling this function and targeting the current queue results in deadlock.
     */
    public var sync: Dispatcher {
        dispatchMethod = .sync
        return self
    }

    /** Calls to this function always return immediately after the block has
     been submitted and never wait for the block to be invoked. The target queue
     determines whether the block is invoked serially or concurrently with
     respect to other blocks submitted to that same queue. Independent serial
     queues are processed concurrently with respect to each other.
     */
    public var async: Dispatcher {
        dispatchMethod = .async
        return self
    }

    /**
     Calls to this function always return immediately after the block has been
     submitted and never wait for the block to be invoked. When the barrier
     block reaches the front of a private concurrent queue, it is not executed
     immediately. Instead, the queue waits until its currently executing blocks
     finish executing. At that point, the barrier block executes by itself.
     Any blocks submitted after the barrier block are not executed until the
     barrier block completes.

     - warning: The queue you specify should be a concurrent queue that you
     create yourself using the dispatch_queue_create function. If the queue
     you pass to this function is a serial queue or one of the global
     concurrent queues, this function behaves like the dispatch_async function.
     */
    public var barrierAsync: Dispatcher {
        dispatchMethod = .barrierAsync
        return self
    }

    /**
     On `run()` closure will be dispatched on main queue.

     - returns: Dispatcher for chaining with next modificator.
     */
    public var main: Dispatcher {
        queueType = .main
        return self
    }

    /**
     On `run()` closure will be dispatched on background global queue.

     - returns: Dispatcher for chaining with next modificator.
     */
    public var background: Dispatcher {
        queueType = .background
        return self
    }

    /**
     On `run()` closure will be dispatched on given queue.

     - parameter queue: Queue where closure will be run.

     - returns: Dispatcher for chaining with next modificator.
     */
    public func queue(_ queue: DispatchQueue!) -> Dispatcher {
        specificQueue = queue
        queueType = .specific
        return self
    }

    /**
     Dispatcheres closure after given delay.

     - parameter delay: Delay for dispatch_after.

     - returns: Dispatcher for chaining with next modificator.
     */
    public func after(_ delay: TimeInterval?) -> Dispatcher {
        delayTime = delay
        return self
    }

    // MARK: - Actions

    /**
     Dispatcheres closure according called modificators.

     - parameter closure: Closure that will be dispatched.

     - returns: Queue where closure is dispatched.
     */
    // swiftlint:disable:next cyclomatic_complexity
    @discardableResult public func run(_ closure: NiladicClosure? = nil) -> RunAfterCancel? {

        // Prequirements
        if let c = closure {
            self.closure = c
        } else if self.closure == nil {
            print("Closure is missing")
            return nil
        }

        // Selects run queue according queueType
        var queue: DispatchQueue?
        switch queueType {
        case .main:
            queue = DispatchQueue.main
        case .background:
            queue = DispatchQueue.global()
        case .specific:
            queue = specificQueue
        }

        // Prepares run with/without delay
        let run = {
            if let d = self.delayTime, d > 0.0 {
                self.dispatchWithDelay(d, (self.dispatchMethod == .sync), (queue ?? DispatchQueue.main), self.closure!)
            } else {
                self.closure!()
            }
        }

        // If closure will be dispatched after, runs from current queue
        if let d = delayTime, d > 0.0 {
            run()
        }
            // Dispatcher is useless run on current queue
        else if queueType == .main && Thread.isMainThread {
            run()
        }
            // Dispatches closure async/sync/…
        else if let q = queue {
            switch dispatchMethod {
            case .sync:
                q.sync(execute: run)
            case .async:
                q.async(execute: run)
            case .barrierAsync:
                q.async(flags: .barrier, execute: run)
            }
        }

        if let d = self.delayTime, d > 0.0 {
            let cancel: RunAfterCancel = { [weak self] in
                self?.cancelled = true
            }
            return cancel
        } else {
            return nil
        }
    }

    // MARK: - Helpers

    fileprivate func dispatchWithDelay(_ delay: Double, _ waitForFinish: Bool, _ queue: DispatchQueue, _ closure: @escaping NiladicClosure) {

        let semaphore: Semaphore? = (waitForFinish ? Semaphore() : nil)

        let run = {
            if self.cancelled == false {
                closure()
            }
            if let s = semaphore {
                _ = s.signal()
            }
        }

        queue.asyncAfter(deadline: .now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: run)

        if let s = semaphore { s.wait() }
    }
}
