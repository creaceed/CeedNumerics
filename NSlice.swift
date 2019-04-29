//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 16/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

// Unresolved one (needs shape to resolve). In NumPy,
// <start:end:step> (end is excluded)
// <2:> -> means <2 to end>.
// <:> -> means <all>.
// <:3> -> means <start to 3>.
// <3:0:-1> -> means <3,2,1>.
// <3::-1> -> means <3,2,1,0>.
// <0:6:2> -> means <0,2,4>.
// start, end, step can all be negative.
//
// Serves as base type for subscript slicing.
// Meant to be adopted by range types, possibly others.
public protocol NSliceExpression {
	var start: Int? { get }
	var end: Int? { get }
	var step: Int? { get }
}
extension NSliceExpression {
//	static var all: NSlice { return NSlice.all }
	public func resolve(size: Int) -> NResolvedSlice {
		precondition(size > 0)
		// not implemented
		let step = self.step ?? 1
		precondition(step != 0)
		let start, end, count: Int
		let sign: Int
		
		if step > 0 {
			sign = 1
			start = self.start ?? 0
			end = self.end ?? size
			assert(end > start)
		} else {
			sign = -1
			start = self.start ?? size-1
			end = self.end ?? 0
			assert(start > end)
		}
		count = (end-sign-start)/step+1
		
		assert(start >= 0 && start < size)
		assert(count > 0)
		let last = start + (count-1)*step
		assert(last >= 0 && last < size)
		
		// start / start+(count-1*step) should be in [0, size[
		return NResolvedSlice(start: start, count: count, step: step)
	}
	//
	public func resolve(within parent: NResolvedSlice) -> NResolvedSlice {
		let local = resolve(size: parent.rcount)
		return local.compose(within: parent)
	}
}

// Concrete slice expression that can be created with all args
public struct NSlice : NSliceExpression {
	public let start: Int?
	public let end: Int?
	public let step: Int?
	
	public static let all: NSlice = NSlice(start: nil, end: nil, step: 1)
	
	public init(start: Int?, end: Int?, step: Int?) {
		self.start = start
		self.end = end
		self.step = step
	}
	public init(_ single: Int) {
		self.init(start: single, end: single+1, step: 1)
	}
	
	
}

precedencegroup SliceOperatorPrecedence {
	associativity: left
	lowerThan: AdditionPrecedence
}

infix operator ~ : SliceOperatorPrecedence
public func ~(lhs: Int, rhs: Int) -> NSlice {
	return NSlice(start: lhs, end: rhs, step: nil)
}
public func ~(lhs: NSlice, rhs: Int) -> NSlice {
	let res = NSlice(start: lhs.start, end: lhs.end, step: rhs)
	return res
}
prefix operator ~
public prefix func ~(rhs: Int) -> NSlice {
	return NSlice(start: nil, end: rhs, step: nil)
}
postfix operator ~
public postfix func ~(a: Int) -> NSlice {
	return NSlice(start: a, end: nil, step: nil)
}
infix operator ~~ : SliceOperatorPrecedence
public func ~~(lhs: Int, rhs: Int) -> NSlice {
	return NSlice(start: lhs, end: nil, step: rhs)
}
prefix operator ~~
public prefix func ~~(a: Int) -> NSlice {
	return NSlice(start: nil, end: nil, step: a)
}
postfix operator ~~
public postfix func ~~(a: Int) -> NSlice {
	return NSlice(start: a, end: nil, step: nil)
}

//postfix operator °
//public postfix func °(lhs: NSlice) -> NSlice {
//	return NSlice(start: lhs.start, end: lhs.end, step: nil)
//}

// Slice expression can be resolved given the size of the container N:(0->N-1).
// expression <:> resolved to <0:N:1>
// expression <:> resolved to <0:N:1>
// expression <:3> resolved to <0:3:1>
public struct NResolvedSlice: NSliceExpression {
	public let rstart: Int
	public let rcount: Int
	public let rstep: Int // non zero. Can be negative.
	public var rlast : Int { return rstart + (rcount - 1) * rstep }
	public var rend : Int { return rstart + rcount * rstep }
	
	public var start: Int? { return rstart }
	public var end: Int? { return rend }
	public var step: Int? { return rstep }
	
	// can call stride.enumerated() if need source indexes
	public var stride: StrideTo<Int> { return Swift.stride(from: rstart, to: rend, by: rstep) }
	
	public init(start: Int, count: Int, step: Int) {
		rstart = start
		rcount = count
		rstep = step
	}
	public static func `default`(count: Int) -> NResolvedSlice {
		return NResolvedSlice(start: 0, count: count, step: 1)
	}
	
	public func position(at index: Int) -> Int {
		assert(index >= 0 && index < rcount)
		return rstart + index * rstep
	}
	public func compose(within parent: NResolvedSlice) -> NResolvedSlice {
		return NResolvedSlice(start: parent.position(at: rstart), count: rcount, step: parent.rstep * rstep)
	}
}

extension NResolvedSlice: Sequence {
	public typealias Element = Int
	public typealias Iterator = StrideTo<Int>.Iterator
	// BidirectionalCollection
//	public typealias Index = Int
//	public typealias Element = Int
//
//	public func index(before i: Int) -> Int { return i - 1 }
//	public func index(after i: Int) -> Int { return i + 1 }
//	public var startIndex: Int { return 0 }
//	public var endIndex: Int { return rcount }
//	public subscript(position: Int) -> Int { return self.position(at: position) }
	public func makeIterator() -> StrideTo<Int>.Iterator {
		return Swift.stride(from: rstart, to: rend, by: rstep).makeIterator()
	}
}

public struct NResolvedQuadraticSlice {
	public let row, column: NResolvedSlice
	public var compact: Bool {
		// only positive steps are considered compact
		return row.rstep == column.rcount && column.rstep == 1
	}
	
	public init(row r: NResolvedSlice, column c: NResolvedSlice) {
		row = r
		column = c
	}
	// Row-major
	public static func `default`(rows: Int, columns: Int) -> NResolvedQuadraticSlice {
		return NResolvedQuadraticSlice(row: NResolvedSlice(start: 0, count: rows, step: columns),
									   column: .default(count: columns))
	}
	public func position(_ ar: Int, _ ac: Int) -> Int {
		return row.position(at: ar) + column.position(at: ac)
	}
}

extension NResolvedQuadraticSlice: Sequence {
	public typealias Element = Int
	public typealias Iterator =  NQuadraticSliceIterator

	public func makeIterator() -> NQuadraticSliceIterator {
		return NQuadraticSliceIterator(slice: self)
	}
}

public struct NQuadraticSliceIterator: IteratorProtocol {
	private let start: (row: Int, column: Int)
	private let step: (row: Int, column: Int)
	private let end: (row: Int, column: Int)
	// internal state
	private var current: (row: Int, column: Int)
	private var done: Bool = false

	public init(slice: NResolvedQuadraticSlice) {
		assert((slice.row.rend - slice.row.rstart) % slice.row.rstep == 0) // so that we can do exact comparison
		assert((slice.column.rend - slice.column.rstart) % slice.column.rstep == 0)
		assert(abs(slice.row.rstep) > 0)
		assert(abs(slice.column.rstep) > 0)

		start = (slice.row.rstart, slice.column.rstart)
		step = (slice.row.rstep, slice.column.rstep)
		end = (slice.row.rend, slice.column.rend)
		current = start
		done = (start == end)
	}

	public mutating func next() -> Int? {
		guard !done else { return nil }

		let loc = (current.row, current.column)
		current.column += step.column
		if current.column == end.column {
			current.column = start.column
			current.row += step.row
			done = (current.row == end.row)
		}
		return loc.0 + loc.1
	}
}

public struct NQuadraticIndexRange: Sequence {
	public let rows, columns: Int
	public var row: Range<Int> { return 0..<rows }
	public var column: Range<Int> { return 0..<columns }
	
	public init(rows ar: Int, columns ac: Int) {
		rows = ar
		columns = ac
	}
	public func makeIterator() -> NQuadraticIndexIterator {
		return NQuadraticIndexIterator(start: (0,0), step: (1,1), end: (rows, columns))
	}
//	public func makeIterator() -> NQuadraticIndexIteratorVariant {
//		return NQuadraticIndexIteratorVariant(sequence: self)
//	}
}

public struct NQuadraticIndexIterator: IteratorProtocol {
	private let start: (row: Int, column: Int)
	private let step: (row: Int, column: Int)
	private let end: (row: Int, column: Int)
	// internal state
	private var current: (row: Int, column: Int)
	private var done: Bool = false
	
	public init(start astart: (Int, Int), step astep: (Int, Int), end aend: (Int, Int)) {
		assert((aend.0 - astart.0) % astep.0 == 0)
		assert((aend.1 - astart.1) % astep.1 == 0)
		assert(abs(astep.0) > 0)
		assert(abs(astep.1) > 0)
		
		start = astart
		step = astep
		end = aend
		current = astart
		done = (astart == aend)
	}
	
	public mutating func next() -> (row: Int, column: Int)? {
		guard !done else { return nil }
		
		let loc = (current.row, current.column)
		current.column += step.column
		if current.column == end.column {
			current.column = start.column
			current.row += step.row
			done = (current.row == end.row)
		}
		return loc
	}
}

// Variant to test generic implementation on known type (same code, but it's faster)
/*
public struct NQuadraticIndexIteratorVariant: IteratorProtocol {
	let sequence: NQuadraticIndexRange
	var iterators: (Range<Int>.Iterator, Range<Int>.Iterator)
	var current: (Int, Int)
	var done: Bool
	//	var combined: Element

	init(sequence s: NQuadraticIndexRange) {
		sequence = s
		iterators = (sequence.row.makeIterator(), sequence.column.makeIterator())

		if let i0 = iterators.0.next(), let i1 = iterators.1.next() {
			done = false
			current.0 = i0
			current.1 = i1
		} else {
			done = true
			current.0 = 0
			current.1 = 0
		}
	}

	public mutating func next() -> (Int,Int)? {
		guard !done else { return nil }

		let loc = (current.0, current.1)

		if let i1 = iterators.1.next() {
			current.1 = i1
		} else {
			if let i0 = iterators.0.next() {
				current.0 = i0
				iterators.1 = sequence.column.makeIterator()
				current.1 = iterators.1.next()!
			} else {
				done = true
			}
		}

		return loc
	}
}
*/

// Quadratic Sequence Generic Protocol + iteration implementation as an extension.
// (Slower)
/*
public protocol QuadraticSequence: Sequence {
	associatedtype LinearSequence: Sequence

	var sequences: (LinearSequence, LinearSequence) { get }
	static func combineDimensions(_: LinearSequence.Element, _: LinearSequence.Element) -> Element
	// this is to avoid using optional in iterator (but this value is not used)
	static func _defaultLinearSequenceElement() -> LinearSequence.Element
}
public struct QuadraticIterator<Sequence: QuadraticSequence>: IteratorProtocol {
	let sequence: Sequence
	var iterators: (Sequence.LinearSequence.Iterator, Sequence.LinearSequence.Iterator)
	var current: (Sequence.LinearSequence.Element, Sequence.LinearSequence.Element)
	var done: Bool

	init(sequence s: Sequence) {
		sequence = s
		iterators = (sequence.sequences.0.makeIterator(), sequence.sequences.1.makeIterator())

		if let i0 = iterators.0.next(), let i1 = iterators.1.next() {
			done = false
			current.0 = i0
			current.1 = i1
		} else {
			done = true
			current.0 = Sequence._defaultLinearSequenceElement()
			current.1 = Sequence._defaultLinearSequenceElement()
		}
	}

	public mutating func next() -> Sequence.Element? {
		guard !done else { return nil }

		let loc = Sequence.combineDimensions(current.0, current.1)

		if let i1 = iterators.1.next() {
			current.1 = i1
		} else {
			if let i0 = iterators.0.next() {
				current.0 = i0
				iterators.1 = sequence.sequences.1.makeIterator()
				current.1 = iterators.1.next()!
			} else {
				done = true
			}
		}

		return loc
	}
}
extension QuadraticSequence {
	public func makeIterator() -> QuadraticIterator<Self> {
		return QuadraticIterator(sequence: self)
	}
}
extension QuadraticSequence where Self.LinearSequence.Element == Int {
	public static func _defaultLinearSequenceElement() -> Int { return 0 }
}
extension NResolvedQuadraticSlice: QuadraticSequence {
	public typealias Element = Int
	public typealias LinearSequence = NResolvedSlice
	public typealias Iterator = QuadraticIterator<NResolvedQuadraticSlice>
	public var sequences: (NResolvedSlice, NResolvedSlice) { return (row, column) }
	public static func combineDimensions(_ r: Int, _ c: Int) -> Int {
		return r+c
	}
}
extension NQuadraticIndexRange: QuadraticSequence {
	public typealias Element = (Int, Int)
	public typealias LinearSequence = Range<Int>
	public typealias Iterator = QuadraticIterator<NQuadraticIndexRange>
	public var sequences: (Range<Int>, Range<Int>) { return (row, column) }
	public static func combineDimensions(_ r: Int, _ c: Int) -> (Int, Int) {
		return (r,c)
	}
}
*/
// MARK: - Augmenting other types
extension CountableRange: NSliceExpression where Bound == Int {
	public var step: Int? { return 1 }
	public var start: Int? { return lowerBound }
	public var end: Int? { return upperBound }
}

extension ClosedRange: NSliceExpression where Bound == Int {
	public var step: Int? { return 1 }
	public var start: Int? { return lowerBound }
	public var end: Int? { return upperBound+1 }
}


