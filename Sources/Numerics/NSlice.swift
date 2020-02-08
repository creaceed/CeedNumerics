/*
Copyright (c) 2018-present Creaceed SPRL and other CeedNumerics contributors.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Creaceed SPRL nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL CREACEED SPRL BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation

// MARK: - Slice Expression
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

// MARK: - Slice
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

// MARK: - Slice Operators
precedencegroup SliceOperatorPrecedence {
	associativity: left
	lowerThan: AdditionPrecedence
}

// operator proposal: • › °
// not working: ·

infix operator ~ : SliceOperatorPrecedence
public func ~(lhs: Int, rhs: Int) -> NSlice {
	return NSlice(start: lhs, end: rhs, step: nil)
}
public func ~(lhs: NSlice, rhs: Int) -> NResolvedSlice {
	let res = NResolvedSlice(start: lhs.start!, end: lhs.end!, step: rhs)
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

// same as Swift's ... - see https://tonisuter.com/blog/2017/08/unbounded-ranges-swift-4/ for more
public enum NUnboundedSlice_ {
	public static postfix func ~ (_: NUnboundedSlice_) -> () {
//		fatalError("uncallable")
	}
}
public typealias NUnboundedSlice = (NUnboundedSlice_)->()
// not possible (Swift 5.1), too bad. That would allow to have simpler subscripting funcs in types.
//extension NUnboundedSlice : NSliceExpression {}

// MARK: - Resolved Slice
// N-Dimensional slice, abstraction is used to implement common  features in Matrix, Vector, etc.
public protocol NDimensionalResolvedSlice: Sequence {
	associatedtype NativeIndex
	
	static func `default`(size: NativeIndex) -> Self
	var rank: Int { get }
	var steps: [Int] { get }
	var shape: [Int] { get }
	
	func position(at index: NativeIndex) -> Int
}

// Slice expression can be resolved given the size of the container N:(0->N-1).
// expression <:> resolved to <0:N:1>
// expression <:> resolved to <0:N:1>
// expression <:3> resolved to <0:3:1>
public struct NResolvedSlice: NSliceExpression, NDimensionalResolvedSlice {
	public typealias NativeIndex = Int
	public let rstart: Int
	public let rcount: Int
	public let rstep: Int // non zero. Can be negative.
	public var rlast : Int { return rstart + (rcount - 1) * rstep }
	public var rend : Int { return rstart + rcount * rstep }
	
	public var rank: Int { return 1 }
	public var shape: [Int] { return [rcount] }
	public var steps: [Int] { return [rstep] }
	
	
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
	public init(start: Int, end: Int, step: Int) {
		// TODO: check for negative step
		self.init(start: start, count: (end-start+step-1)/step, step: step)
	}
	public static func `default`(size: Int) -> NResolvedSlice {
		return NResolvedSlice(start: 0, count: size, step: 1)
	}
	
	public func position(at index: Int) -> Int {
		assert(index >= 0 && index < rcount)
		return rstart + index * rstep
	}
	public func compose(within parent: NResolvedSlice) -> NResolvedSlice {
		return NResolvedSlice(start: parent.position(at: rstart), count: rcount, step: parent.rstep * rstep)
	}
}

// Represents N-D indexes and sizes
public protocol NDimensionalIndex: Equatable {
	var rank: Int { get } // not static because it cannot be inferred for generic indexes
	
	// when self represents a N-D size, this returns the total element count. E.g. 3x4 -> 12
	var asElementCount: Int { get }
	var asArray: [Int] { get }
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
extension Int: NDimensionalIndex {
	public var rank: Int { return 1 }
	// convert a 'size' index to an element count
	public var asElementCount: Int { return self }
	public var asArray: [Int] { return [self] }
}

// MARK: - Quadratic Index / Slice
public struct NQuadraticIndex: NDimensionalIndex {
	public var row, column: Int
	public init(_ r: Int, _ c: Int) {
		row = r
		column = c
	}
	public var tupleValue: (row: Int, column: Int) { return (row, column) }
	
	public var rank: Int { return 2 }
	public var asElementCount: Int { return row * column }
	public var asArray: [Int] { return [row, column] } 
}

public struct NResolvedQuadraticSlice: NDimensionalResolvedSlice {
	public typealias NativeIndex = NQuadraticIndex
	
	public let row, column: NResolvedSlice
	public var rank: Int { return 2 }
	public var shape: [Int] { return [row.rcount, column.rcount] }
	public var steps: [Int] { return [row.rstep, column.rstep] }
	
	// true if successive elements have no gap between them (including across dimensions)
	public var compact: Bool {
		// only positive steps are considered compact
		return row.rstep == column.rcount && column.rstep == 1
	}
	// true if successive element are regularly distributed (including across dimensions)
	public var coalesceable: Bool {
		// single step can be used to traverse all values
		return row.rstep == column.rcount * column.rstep
	}
	
	public init(row r: NResolvedSlice, column c: NResolvedSlice) {
		row = r
		column = c
	}
	// Row-major
	public static func `default`(size: NativeIndex) -> NResolvedQuadraticSlice {
		return NResolvedQuadraticSlice(row: NResolvedSlice(start: 0, count: size.row, step: size.column),
									   column: .default(size: size.column))
	}
	public static func `default`(rows: Int, columns: Int) -> NResolvedQuadraticSlice {
		return `default`(size: NQuadraticIndex(rows, columns))
	}
	// protocol one
	public func position(at index: NQuadraticIndex) -> Int {
		return row.position(at: index.row) + column.position(at: index.column)
	}
	// simpler one
	public func position(_ ar: Int, _ ac: Int) -> Int {
		return row.position(at: ar) + column.position(at: ac)
	}
}

// Sequence impl.
extension NResolvedQuadraticSlice {
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

public struct NQuadraticRange: Sequence {
	public var rows: Int { return row.count }
	public var columns: Int { return column.count }
	public let row: Range<Int>
	public let column: Range<Int>
	
	public init(row ar: Range<Int>, column ac: Range<Int>) {
		row = ar
		column = ac
	}
	
	public init(rows ar: Int, columns ac: Int) {
		self.init(row: 0..<ar, column: 0..<ac)
	}
	public func makeIterator() -> NQuadraticIterator {
		return NQuadraticIterator(start: (row.lowerBound, column.lowerBound), step: (1,1), end: (row.upperBound, column.upperBound))
	}
//	public func makeIterator() -> NQuadraticIteratorVariant {
//		return NQuadraticIteratorVariant(sequence: self)
//	}
}

public struct NQuadraticIterator: IteratorProtocol {
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
	
	public mutating func next() -> NQuadraticIndex? {
		guard !done else { return nil }
		
		let loc = NQuadraticIndex(current.row, current.column)
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
public struct NQuadraticIteratorVariant: IteratorProtocol {
	let sequence: NQuadraticRange
	var iterators: (Range<Int>.Iterator, Range<Int>.Iterator)
	var current: (Int, Int)
	var done: Bool
	//	var combined: Element

	init(sequence s: NQuadraticRange) {
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
extension NQuadraticRange: QuadraticSequence {
	public typealias Element = (Int, Int)
	public typealias LinearSequence = Range<Int>
	public typealias Iterator = QuadraticIterator<NQuadraticRange>
	public var sequences: (Range<Int>, Range<Int>) { return (row, column) }
	public static func combineDimensions(_ r: Int, _ c: Int) -> (Int, Int) {
		return (r,c)
	}
}
*/

// MARK: - Generic Index / Slice
//public struct NGenericIndex: NDimensionalIndex {
//	public var components: [Int] // last one has smallest memory stride [row, col] for matrix (row major)
//	public init(_ _values: [Int]) {
//		components = _values
//	}
//	public var dimension: Int { return components.count }
//	public var asElementCount: Int { return components.reduce(1) { $0 * $1 } }
//	public var asArray: [Int] { return components }
//}

public typealias NGenericIndex = [Int]

extension NGenericIndex: NDimensionalIndex {
	public var rank: Int { return count }
	public var asElementCount: Int { return reduce(Int(1)) { $0 * $1 } }
	public var asArray: [Int] { return self }
	
	public static func zero(rank: Int) -> NGenericIndex {
		precondition(rank > 0)
		return NGenericIndex(repeating: 0, count: rank)
	}
}

// can't use typealias NResolvedGenericSlice = [NResolvedSlice], because Sequence impl is meant to iterate on index, not slices.
public struct NResolvedGenericSlice: NDimensionalResolvedSlice {
	public typealias NativeIndex = [Int]

	public let components: [NResolvedSlice]
	public var rank: Int { return components.count }
	public var shape: [Int] { return components.map { $0.rcount } }
	public var steps: [Int] { return components.map { $0.rstep } }
	// true if successive elements have no gap between them (including across dimensions)
	public var compact: Bool {
		// only positive steps are considered compact
		var step = 1
		for slice in components.reversed() {
			if slice.rstep != step { return false }
			step *= slice.rcount
		}
		return true
		// matrix:
		// return row.rstep == column.rcount && column.rstep == 1
	}
	// true if successive element are regularly distributed (including across dimensions)
	public var coalesceable: Bool {
		// single step can be used to traverse all values
		var step = components.last!.rstep * components.last!.rcount
		for slice in components.prefix(upTo: components.endIndex-1).reversed() {
			if slice.rstep != step { return false }
			step *= slice.rcount
		}
		return true
		// matrix:
		// return row.rstep == column.rcount * column.rstep
	}

	public init(_ comps: [NResolvedSlice]) {
		precondition(comps.count > 0)
		components = comps
	}
	
	public static func `default`(size: NativeIndex) -> NResolvedGenericSlice {
		precondition(size.count > 0)
		precondition(size.startIndex == 0)
		var steps = [Int](repeating: 0, count: size.count)
		steps[steps.endIndex-1] = 1
		for i in stride(from: size.endIndex-2, through: size.startIndex, by: -1) {
			steps[i] = steps[i+1] * size[i+1]
		}
		
		let comps = zip(size, steps).map { NResolvedSlice(start: 0, count: $0.0, step: $0.1) }
		
		return NResolvedGenericSlice(comps)
		//return NResolvedQuadraticSlice(row: NResolvedSlice(start: 0, count: size.row, step: size.column),
//									   column: .default(size: size.column))
	}
	public func position(at index: NativeIndex) -> Int {
		return components.enumerated().reduce(0) { $0 + $1.1.position(at: index[$1.0]) }
		// matrix:
		// return row.position(at: index.row) + column.position(at: index.column)
	}
}

// Sequence impl.
extension NResolvedGenericSlice {
	public typealias Element = Int
	public typealias Iterator =  NGenericSliceIterator

	public func makeIterator() -> NGenericSliceIterator {
		return NGenericSliceIterator(slice: self)
	}
}

public struct NGenericSliceIterator: IteratorProtocol {
	private let start: [Int]
	private let step: [Int]
	private let end: [Int]
	// internal state
	private var current: [Int]
	private var done: Bool = false

	public init(slice: NResolvedGenericSlice) {
//		assert((slice.row.rend - slice.row.rstart) % slice.row.rstep == 0) // so that we can do exact comparison
//		assert((slice.column.rend - slice.column.rstart) % slice.column.rstep == 0)
//		assert(abs(slice.row.rstep) > 0)
//		assert(abs(slice.column.rstep) > 0)

		start = slice.components.map { $0.rstart }
		step = slice.components.map { $0.rstep }
		end = slice.components.map { $0.rend }
		current = start
		done = (start == end)
	}

	public mutating func next() -> Int? {
		guard !done else { return nil }

		// loc = sum()
		let loc = current.reduce(0) { $0+$1 }
		
		for dimi in stride(from: start.count-1, through: 0, by: -1) {
			current[dimi] += step[dimi]
			if current[dimi] == end[dimi] {
				// reset dimension, move to next dim
				current[dimi] = start[dimi]
				done = (dimi == 0)
			} else {
				break
			}
		}
		
		return loc
	}
}


public struct NGenericRange: Sequence {
	public var counts: [Int] { return ranges.map { $0.count } }
	public var rank: Int { return ranges.count }
	public let ranges: [Range<Int>] // { return counts.map { 0..<$0 } }
	
	public init(ranges _ranges: [Range<Int>]) {
		ranges = _ranges
	}
	public init(counts _counts: [Int]) {
		self.init(ranges: _counts.map { 0..<$0 } )
	}
	public func makeIterator() -> NGenericIterator {
		return NGenericIterator(start: ranges.map { $0.lowerBound },
									 step: [Int](repeating: 1, count: rank),
									 end: ranges.map { $0.upperBound })
	}
//	public func makeIterator() -> NQuadraticIteratorVariant {
//		return NQuadraticIteratorVariant(sequence: self)
//	}
}

public struct NGenericIterator: IteratorProtocol {
	private let start: [Int]
	private let step: [Int]
	private let end: [Int]
	// internal state
	private var current: [Int]
	private var done: Bool = false
	
	public init(start astart: [Int], step astep: [Int], end aend: [Int]) {
//		assert((aend.0 - astart.0) % astep.0 == 0)
//		assert((aend.1 - astart.1) % astep.1 == 0)
//		assert(abs(astep.0) > 0)
//		assert(abs(astep.1) > 0)
		
		start = astart
		step = astep
		end = aend
		current = astart
		done = (astart == aend)
	}
	
	public mutating func next() -> NGenericIndex? {
		guard !done else { return nil }
		
		let loc = current
		
		for dimi in stride(from: start.count-1, through: 0, by: -1) {
			current[dimi] += step[dimi]
			if current[dimi] == end[dimi] {
				// reset dimension, move to next dim
				current[dimi] = start[dimi]
				done = (dimi == 0)
			} else {
				break
			}
		}
		return loc
	}
}


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


