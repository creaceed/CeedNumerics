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
public extension NSliceExpression {
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
		return local.flatten(within: parent)
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
		return rstart + index * rstep
	}
	public func flatten(within parent: NResolvedSlice) -> NResolvedSlice {
		return NResolvedSlice(start: parent.position(at: rstart), count: rcount, step: parent.rstep * rstep)
	}
	
	
	
}

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
