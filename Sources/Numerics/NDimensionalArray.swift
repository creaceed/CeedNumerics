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

// TODO list for NDimensionalArray:
// - unify steps / strides concepts into strides + canonical steps / define compact form (H*W,W,1)
// - implement 'soft' transpose API using strides/counts swapping
// - implement transpose baking with copy API (or another specific one).

public protocol NDimensionalArray: NStorageAccessible, CustomStringConvertible {
	associatedtype NativeRange: Sequence where NativeRange.Element == Self.NativeIndex
	associatedtype NativeResolvedSlice: NDimensionalResolvedSlice where NativeResolvedSlice.NativeIndex == Self.NativeIndex
	associatedtype Mask: NDimensionalArray where Mask.Element == Bool, Mask.NativeIndex == Self.NativeIndex
	typealias Vector = NVector<Element>
	typealias Storage = NStorage<Element>
	
	var storage: Storage { get }
	var slice: NativeResolvedSlice { get } // addresses storage directly
	
	var shape: [Int] { get } // defined in extension below
	var rank: Int { get } // tensor meaning (not matrix rank)
	var size: NativeIndex { get }
	var indices: NativeRange { get }
	
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

// deprecated methods
extension NDimensionalArray {
	@available(*, deprecated, renamed: "rank")
	public var dimension: Int { return rank }
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
	public static var bytesPerElement: Int { return MemoryLayout<Element>.stride }
	public var bytesPerElement: Int { return Self.bytesPerElement }
	
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
		// invoked with [] to get the whole NDArray description
		// if array has [3,2,3] size, with dimi[ convention, we get this
		// 0[] -> 1[0] -> 2[0,0] -> 3[0,0,0] -> outputs a value
		//                       -> 3[0,0,1] -> outputs a value
		//                       -> 3[0,0,2] -> outputs a value
		
		
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
			if !last && dimi == shape.count - 1 { description += "\n" } // on each 'vector"
			if !last && dimi < shape.count - 1 { description += "\n\n" } // on higher dims
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

extension NDimensionalArray where Element: NAdditiveNumeric {
	public static func ramp(size: NativeIndex) -> Self {
		let res = Self(size: size)
		Numerics._setIndexRamp(res)
		return res
	}
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
