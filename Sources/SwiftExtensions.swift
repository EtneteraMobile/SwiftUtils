/**

 Created by Jan Čislinský on 25/08/16.
 Copyright © 2016 Etnetera, a.s. All rights reserved.

 */

import Foundation

public extension String {
    fileprivate var ns: NSString {
        return self as NSString
    }
    var pathExtension: String {
        return ns.pathExtension
    }
    var lastPathComponent: String {
        return ns.lastPathComponent
    }
}

// MARK: - Associated objects

import ObjectiveC

public extension NSObjectProtocol {
    func setAssociated<T>(value: T, associativeKey: UnsafeRawPointer, policy: objc_AssociationPolicy = .OBJC_ASSOCIATION_RETAIN_NONATOMIC) {
        objc_setAssociatedObject(self, associativeKey, value, policy)
    }

    func getAssociated<T>(associativeKey: UnsafeRawPointer) -> T? {
        let value = objc_getAssociatedObject(self, associativeKey)
        return value as? T
    }
}

// MARK: - Random

public extension Double {
    public static func random(_ lower: Double = 0, _ upper: Double = 1) -> Double {
        return Double(arc4random()) / Double(UINT32_MAX) * (upper - lower) + lower
    }
}

public extension Int {
    public static func random(_ lower: Int = 0, _ upper: Int = 1) -> Int {
        return Int(Double.random(Double(lower), Double(upper + 1)))
    }
}

public extension String {
    public static func random(_ length: Int) -> String {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789"
        let count = UInt32(alphabet.count)
        return stride(from: 0, to: length, by: 1).map { _ -> String in
            let idx = Int(arc4random() % count)
            print(idx)
            return String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: idx)])
        }.joined()
    }
}

// MARK: - Custom operators

infix operator >!<

/**
 Checks class names of parameters and returns `true` if class names are equal.

 - parameter object1: First object
 - parameter object2: Second object

 - returns: true = objects have same class; otherwise false
 */
public func >!< (object1: AnyObject!, object2: AnyObject!) -> Bool {
    return (object_getClassName(object1) == object_getClassName(object2))
}

// Optionals and String Interpolation (https://oleb.net/blog/2016/12/optionals-string-interpolation/?utm_campaign=This%2BWeek%2Bin%2BSwift&utm_medium=email&utm_source=This_Week_in_Swift_114)

infix operator ???
public func ??? <T>(optional: T?, defaultValue: @autoclosure () -> String) -> String {
    switch optional {
    case let value?: return String(describing: value)
    case nil: return defaultValue()
    }
}

// MARK: - Collection view

public extension Collection {
    /// Returns the element at the specified index if it is within bounds,
    /// otherwise nil.
    ///
    /// - Parameter index: Index of element
    ///
    /// - Returns: Element at given index or nil
    ///
    /// - SeeAlso: [Source](http://stackoverflow.com/a/30593673)
    ///
    /// - Author: Jan Cislinsky
    /// - Since: 01/2017
    subscript (et_safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }

    /// Returns element where `predicate` returns `true` for the corresponding
    /// value, or `nil` if such value is not found.
    ///
    ///     let names = [ "John", "David", "Charlie" ]
    ///     let david = names[et_indexOf: { $0 == "David" }]
    ///     print(david)
    ///     // Prints "David"
    ///
    /// - Parameter predicate: Predicate that will match returned element
    ///
    /// - Returns: Element that match given predicate
    ///
    /// - Author: Jan Cislinsky
    /// - Since: 02/2017
    subscript (et_indexOf predicate: (Self.Iterator.Element) -> Bool) -> Iterator.Element? {
        guard let idx = self.index(where: predicate) else {
            return nil
        }
        guard let element = self[et_safe: idx] else {
            return nil
        }
        return element
    }

    /// Divides collection into subsequences according given condition.
    ///
    /// - Parameter divide: If returns `true`, origin sequence will be
    /// divided between elements that are given into divide closure.
    ///
    /// - Returns: SubSequences created by divide condition.
    ///
    /// - Author: Jan Cislinsky
    /// - Since: 07/2017
    public func chunks(separatedBy condition: (_ lhs: Self.Iterator.Element, _ rhs: Self.Iterator.Element) -> Bool) -> [[Iterator.Element]] {
        return reduce([]) { accum, current in
            var accum = accum
            if var lastChunk = accum.last, let lastElem = lastChunk.last, condition(lastElem, current) == false {
                lastChunk.append(current)
                accum.removeLast()
                accum.append(lastChunk)
            } else {
                accum.append([current])
            }
            return accum
        }
    }
}

/// Returns hash value calculated from String that is builded from given args.
/// Arguments are converted to `String`  (according given typeFormat;
/// default is `%d`) and joined with separator ' '.
///
/// Result is time efficient and compiler can resolve it in reasonable time.
/// 
/// In comparison to DJB2 algorithm this is at least 2x times faster.
public func hashed(args: CVarArg..., typeFormat: String = "%d") -> Int {
    return hashed(array: args, typeFormat: typeFormat)
}

/// Returns hash value calculated from String that is builded from given args.
/// Arguments are converted to `String`  (according given typeFormat;
/// default is `%d`) and joined with separator ' '.
///
/// Result is time efficient and compiler can resolve it in reasonable time.
///
/// In comparison to DJB2 algorithm this is at least 2x times faster.
public func hashed(array: [CVarArg]?, typeFormat f: String = "%d") -> Int { // swiftlint:disable:this identifier_name cyclomatic_complexity
    guard let array = array else {
        return 0
    }
    switch array.count {
    case 1:     return String(format: "\(f)", arguments: array).hashValue
    case 2:     return String(format: "\(f) \(f)", arguments: array).hashValue
    case 3:     return String(format: "\(f) \(f) \(f)", arguments: array).hashValue
    case 4:     return String(format: "\(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 5:     return String(format: "\(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 6:     return String(format: "\(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 7:     return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 8:     return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 9:     return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 10:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 11:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 12:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 13:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 14:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 15:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 16:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 17:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 18:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 19:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    case 20:    return String(format: "\(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f) \(f)", arguments: array).hashValue
    default:    return array.map({ String(describing: $0) }).joined(separator: " ").hashValue
    }
}

// MARK: - Custom operators

public func + <T>(left: [T], right: T) -> [T] {
    return left + [right]
}

public func + <T>(left: T, right: [T]) -> [T] {
    return [left] + right
}

public func + <T>(left: [T], right: T?) -> [T] {
    guard let right = right else {
        return left
    }
    return left + right
}

public func + <T>(left: T?, right: [T]) -> [T] {
    guard let left = left else {
        return right
    }
    return [left] + right
}

public func + <T>(left: [T]?, right: T) -> [T] {
    guard let left = left else {
        return [right]
    }
    return left + right
}

public func + <T>(left: T, right: [T]?) -> [T] {
    guard let right = right else {
        return [left]
    }
    return [left] + right
}

public func + <T>(left: [T]?, right: T?) -> [T] {
    guard let right = right else {
        return left ?? []
    }
    guard let left = left else {
        return [right]
    }
    return left + right
}

public func + <T>(left: T?, right: [T]?) -> [T] {
    guard let left = left else {
        return right ?? []
    }
    guard let right = right else {
        return [left]
    }
    return left + right
}

public func + <T>(left: [T]?, right: [T]?) -> [T] {
    guard let right = right else {
        return left ?? []
    }
    guard let left = left else {
        return right
    }
    return left + right
}

public func + <T>(left: [T]?, right: [T]) -> [T] {
    guard let left = left else {
        return right
    }
    return left + right
}

public func += <T> (left: inout [T], right: T) {
    left.append(right)
}

public func += <T> (left: inout [T], right: T?) {
    if let right = right {
        left += right
    }
}

public func += <T> (left: inout [T], right: [T]) {
    left.append(contentsOf: right)
}

public func += <T> (left: inout [T], right: [T]?) {
    if let right = right {
        left += right
    }
}

precedencegroup HigherThanMultiplicationLeftPrecedence { associativity: left
    higherThan: MultiplicationPrecedence
}

infix operator -->: HigherThanMultiplicationLeftPrecedence
/// Function composition
public func --> <T1, T2, T3> (left: @escaping (T1) -> T2, right: @escaping (T2) -> T3) -> (T1) -> T3 {
    return { (t1: T1) -> T3 in right(left(t1)) }
}

infix operator |>: HigherThanMultiplicationLeftPrecedence
/// Function chaining
public func |> <T, U>(value: T, function: ((T) -> U)) -> U {
    return function(value)
}

// swiftlint:disable identifier_name
public func curryOne<A, R>(_ f: @escaping (A) -> R) -> (A) -> () -> R {
    return { a in { f(a) } }
}

public func curry<A, B, R>(_ f: @escaping (A, B) -> R) -> (A) -> (B) -> R {
    return { a in { b in f(a, b) } }
}

public func curry<A, B, C, R>(_ f: @escaping (A, B, C) -> R) -> (A) -> (B) -> (C) -> R {
    return { a in { b in { c in f(a, b, c) } } }
}

public func curryFirst<A, B, C, R>(_ f: @escaping (A, B, C) -> R) -> (A) -> (B, C) -> R {
    return { a in { b, c in f(a, b, c) } }
}
// swiftlint:enable identifier_name

public func onMainThread<ReturnValue>(_ action: @escaping () -> ReturnValue) -> ReturnValue {
    if Thread.isMainThread {
        return action()
    } else {
        return DispatchQueue.main.sync {
            action()
        }
    }
}

extension Dictionary {
    public func mapPairs<OutKey: Hashable, OutValue>(_ transform: (Element) throws -> (OutKey, OutValue)) rethrows -> [OutKey: OutValue] {
        var dict: [OutKey: OutValue] = [:]
        try map(transform).forEach { key, value in
            dict[key] = value
        }
        return dict
    }
}
