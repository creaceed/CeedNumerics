//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 18/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

public protocol NDimensionalArray: NStorageAccessible, CustomStringConvertible {
	associatedtype NativeIndexRange: Sequence where NativeIndexRange.Element == Self.NativeIndex
	associatedtype NativeResolvedSlice: NDimensionalResolvedSlice where NativeResolvedSlice.NativeIndex == Self.NativeIndex
	associatedtype Mask: NDimensionalArray where Mask.Element == Bool, Mask.NativeIndex == Self.NativeIndex
	typealias Vector = NVector<Element>
	typealias Storage = NStorage<Element>
	
	var shape: [Int] { get } // defined in extension below
	var dimension: Int { get }
	var size: NativeIndex { get }
	var indices: NativeIndexRange { get }
	
	var compact: Bool { get }
	var coalesceable: Bool { get }
	
	// More general API (not implemented)
//	func compact(in dimensions: ClosedRange<Int>)
//	func coalescable(in dimensions: ClosedRange<Int>)
	
	init(repeating value: Element, size: NativeIndex)
	init(storage: Storage, slice: NativeResolvedSlice)
	
	// we don't define as vararg arrays, we let that up to the actual type to opt-out from array use (performance).
	// TODO: nextstep - genericize this
	subscript(index: [Int]) -> Element { get nonmutating set }
	subscript(index: NativeIndex) -> Element { get nonmutating set }
	
//	internal func deriving() -> Self
}

// Some common API
extension NDimensionalArray {
	public var shape: [Int] { return size.asArray }
	
	public init(size: NativeIndex) {
		self.init(repeating: .none, size: size)
	}
	public init(generator: (_ index: NativeIndex) -> Element, size: NativeIndex) {
		self.init(size: size)
		for i in indices {
			self[i] = generator(i)
		}
	}
	public init(values: [Element], size: NativeIndex) {
		precondition(values.count == size.asElementCount)
		self.init(size: size)
		set(from: values)
	}
	
	// Copy that is compact & coalescable, and with distinct storage from original
	public func copy() -> Self {
		let result = Self(size: size)
		result.set(from: self)
		return result
	}
	// Note: set API does not expose data range as slicing (SliceExpression) is used for that
	public func set(from: Self) {
		precondition(from.size == self.size)
		Numerics.withAddresses(from, self) { pfrom, pself in
			pself.pointee = pfrom.pointee
		}
	}
	public func set(_ value: Element) {
		for i in self.indices {
			self[i] = value
		}
	}
	public func set(_ value: Element, mask: Mask) {
		precondition(mask.size == size)
		for i in self.indices {
			if mask[i] { self[i] = value }
		}
	}
	public func set(from rowMajorValues: [Element]) {
		precondition(rowMajorValues.count == size.asElementCount)
		for (pos, rpos) in zip(indices, rowMajorValues.indices) {
			self[pos] = rowMajorValues[rpos]
		}
	}
	
	public subscript(mask: Mask) -> Vector {
		get {
			precondition(mask.size == size)
			let c = mask.trueCount
			let result = Vector(size: c)
			var i=0
			for index in mask.indices {
				guard mask[index] == true else { continue }
				result[i] = self[index]
				i += 1
			}
			return result
		}
		nonmutating set {
			precondition(mask.size == size)
			let c = mask.trueCount
			precondition(c == newValue.size)
			var i=0
			for index in mask.indices {
				guard mask[index] == true else { continue }
				self[index] = newValue[i]
				i += 1
			}
		}
	}
}


extension NDimensionalArray {
	// quickie to allocate result with same size as self.
	internal func _deriving(_ prep: (Self) -> ()) -> Self {
		let result = Self(repeating: .none, size: self.size)
		prep(result)
		return result
	}
	
	private func recursiveDescription(index: [Int]) -> String {
		var description = ""
		let dimi = index.count
		var first: Bool = false, last = false
		
		if index.count > 0 {
			first = (index.last! == 0)
			last = (index.last! == shape[index.count-1]-1)
			
		}
		
		if index.count > 0 {
			if first { description += "[" }
			if !first { description += " " }
		}
		
		if dimi == shape.count {
			description += "\(self[index])"
		} else {
			for i in 0..<shape[dimi] {
				description += recursiveDescription(index: index + [i])
			}
		}
		
		if index.count > 0 {
			if !last { description += "," }
			if !last && dimi == shape.count - 1 { description += "\n" }
			if last { description += "]" }
		}
		
		return description
	}
	
	public var description: String {
		get {
			let shapeDescr = shape.map {"\($0)"}.joined(separator: "×")
			return "(\(shapeDescr))" + recursiveDescription(index: [])
		}
	}
}

// Bool Arrays
extension NDimensionalArray where Element == Bool {
	internal var trueCount: Int {
		var c = 0
		for i in self.indices { c += self[i] ? 1 : 0 }
		return c
	}
	public static prefix func !(rhs: Self) -> Self { return rhs._deriving { for i in rhs.indices { $0[i] = !rhs[i] } } }
	
}
// MARK: - Comparison with tolerance (SignedNumeric Arrays)
extension NDimensionalArray where Element: SignedNumeric, Element.Magnitude == Element {
	public func isEqual(to rhs: Self, tolerance: Element) -> Bool {
		precondition(rhs.shape == shape)

		// TODO: could be faster with stoppable value enumeration
		for (pos, rpos) in zip(indices, rhs.indices) {
			if abs(rhs[pos] - rhs[rpos]) > tolerance { return false }
		}
		return true
	}
}

extension NDimensionalArray where Element: Comparable {
	private static func _compare(lhs: Self, rhs: Self, _ op: (Element, Element) -> Bool) -> Self.Mask {
		precondition(lhs.size == rhs.size)
		let res = Mask(size: lhs.size)
		for i in res.indices { res[i] = op(lhs[i], rhs[i]) }
		return res
	}
	private static func _compare(lhs: Self, rhs: Element, _ op: (Element, Element) -> Bool) -> Mask {
		let res = Mask(size: lhs.size)
		for i in res.indices { res[i] = op(lhs[i], rhs) }
		return res
	}
	public static func <(lhs: Self, rhs: Self) -> Mask { return _compare(lhs: lhs, rhs: rhs, <) }
	public static func >(lhs: Self, rhs: Self) -> Mask { return _compare(lhs: lhs, rhs: rhs, >) }
	public static func <=(lhs: Self, rhs: Self) -> Mask { return _compare(lhs: lhs, rhs: rhs, <=) }
	public static func >=(lhs: Self, rhs: Self) -> Mask { return _compare(lhs: lhs, rhs: rhs, >=) }
	// cannot do that
//	public static func ==(lhs: Matrix, rhs: Matrix) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, >=) }

	public static func <(lhs: Self, rhs: Element) -> Mask { return _compare(lhs: lhs, rhs: rhs, <) }
	public static func >(lhs: Self, rhs: Element) -> Mask { return _compare(lhs: lhs, rhs: rhs, >) }
	public static func <=(lhs: Self, rhs: Element) -> Mask { return _compare(lhs: lhs, rhs: rhs, <=) }
	public static func >=(lhs: Self, rhs: Element) -> Mask { return _compare(lhs: lhs, rhs: rhs, >=) }
	public static func ==(lhs: Self, rhs: Element) -> Mask { return _compare(lhs: lhs, rhs: rhs, ==) }
}


// Randomisation
extension NDimensionalArray {
	public mutating func randomize(min: Element, max: Element, seed: Int = 0) {
		var generator = NSeededRandomNumberGenerator(seed: seed)
		for index in self.indices {
			self[index] = Element.random(min: min, max: max, using: &generator)
		}
	}
}
