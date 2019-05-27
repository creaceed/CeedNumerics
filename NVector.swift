//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

// Vector type, with efficient creation and hi-perf slicing.
// Memory model is similar to Swift's UnsafeMutablePointer, ie, a vector is a 'view' on mutable contents.
public struct NVector<Element: NValue> : NStorageAccessible {
	public typealias NativeIndex = Int
	public typealias NativeIndexRange = Range<Int>
	public typealias Storage = NStorage<Element>
	public typealias Vector = NVector<Element>
	public typealias Access = Storage.LinearAccess
	
	private let storage: Storage
	private let slice: NResolvedSlice // addresses storage directly
	
	public var size: Int { return slice.rcount }
	public var indices: Range<Int> { return 0..<size }
	public var compact: Bool { return slice.rstep == 1 } // only positive steps are considered compact
	
	public var first: Element? { return size > 0 ? self[0] : nil }
	public var last: Element? { return size > 0 ? self[size-1] : nil }
	
	// MARK: - Init -
	public init(storage mem: Storage, slice sl: NResolvedSlice) {
		storage = mem
		//layout = l
		slice = sl
	}
//	public init(size: Int) {
//		let storage = Storage(allocatedCount: size)
//		self.init(storage: storage, slice: .default(count: size))
//	}
	public init(storage mem: Storage, count: Int) {
		let slice = NResolvedSlice(start: 0, count: count, step: 1)
		self.init(storage: mem, slice: slice)
	}
	public init(_ values: [Element]) {
		self.init(size: values.count)
		storage.withUnsafeAccess { access in
			_ = UnsafeMutableBufferPointer(start: access.base, count: self.size).initialize(from: values)
		}
	}
	public init(repeating value: Element = .none, size: Int) {
		let storage = Storage(allocatedCount: size)
		self.init(storage: storage, slice: .default(count: size))
		
		storage.withUnsafeAccess { access in
			_ = UnsafeMutableBufferPointer(start: access.base, count: self.size).initialize(repeating: value)
		}
	}
	public init(size: Int, generator: (_ index: Int) -> Element) {
		self.init(size: size)
		for i in 0..<size {
			self[i] = generator(i)
		}
	}
	
	public func copy() -> Vector {
		let result = Vector(size: size)
		result.set(from: self)
		return result
	}
	
	// MARK: - Slicing -
	public subscript(_ s: NSliceExpression) -> Vector {
		get { return Vector(storage: storage, slice: s.resolve(within: slice)) }
		nonmutating set { Vector(storage: storage, slice: s.resolve(within: slice)).set(from: newValue) }
	}
	// Access one element
	public subscript(index: Int) -> Element {
		get { return storage[slice.position(at: index)] }
		nonmutating set { storage[slice.position(at: index)] = newValue }
	}
	// Masked access (Vector<Bool>)
	public subscript(mask: NVectorb) -> Vector {
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
	// Indexed access (Vector<Int>)
	public subscript(indexes: NVectori) -> Vector {
		get {
			let result = Vector(size: indexes.size)
			for index in indexes.indices {
				let selfindex = indexes[index]
				assert(selfindex >= 0 && selfindex < self.size )
				result[index] = self[selfindex]
			}
			return result
		}
		nonmutating set {
			precondition(newValue.size == indexes.size)
			for index in indexes.indices {
				let selfindex = indexes[index]
				assert(selfindex >= 0 && selfindex < self.size )
				self[selfindex] = newValue[index]
			}
		}
	}
	
	
	// Use Numerics.with variants as API
	public func _withStorageAccess<Result>(_ block: (_ access: Storage.LinearAccess) throws -> Result) rethrows -> Result {
		return try storage.withUnsafeAccess { saccess in
			let access = Storage.LinearAccess(base: saccess.base + slice.rstart, stride: slice.rstep, count: slice.rcount)
			return try block(access)
		}
	}
}

extension NVector {
	public func set(from: Vector) {
		precondition(from.slice.rcount == slice.rcount)
		Numerics.withAddresses(from, self) { pfrom, pself in
			pself.pointee = pfrom.pointee
		}
	}
	public func set(from: [Element]) {
		precondition(from.count == size)
		for (i, j) in zip(self.indices, 0..<from.count) {
			self[i] = from[j]
		}
	}
	public func set(_ value: Element) {
		for i in self.indices {
			self[i] = value
		}
	}
	public func set(_ value: Element, mask: NVectorb) {
		precondition(mask.size == size)
		for i in self.indices {
			if mask[i] { self[i] = value }
		}
	}
}

extension NVector where Element: SignedNumeric, Element.Magnitude == Element {
	public func isEqual(to rhs: NVector, tolerance: Element) -> Bool {
		// Brute force. Would be better with iterator
		precondition(rhs.size == size)
		
		for i in 0..<size {
			if abs(self[i] - rhs[i]) > tolerance { return false }
		}
		return true
	}
	private static func _compare(lhs: Vector, rhs: Vector, _ op: (Element, Element) -> Bool) -> NVectorb {
		precondition(lhs.size == rhs.size)
		let res = NVectorb(size: lhs.size)
		for i in res.indices { res[i] = op(lhs[i], rhs[i]) }
		return res
	}
	private static func _compare(lhs: Vector, rhs: Element, _ op: (Element, Element) -> Bool) -> NVectorb {
		let res = NVectorb(size: lhs.size)
		for i in res.indices { res[i] = op(lhs[i], rhs) }
		return res
	}
	public static func <(lhs: Vector, rhs: Vector) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, <) }
	public static func >(lhs: Vector, rhs: Vector) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, >) }
	public static func <=(lhs: Vector, rhs: Vector) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, <=) }
	public static func >=(lhs: Vector, rhs: Vector) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, >=) }
	//public static func .==(lhs: Vector, rhs: Vector) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, ==) }
	
	public static func <(lhs: Vector, rhs: Element) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, <) }
	public static func >(lhs: Vector, rhs: Element) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, >) }
	public static func <=(lhs: Vector, rhs: Element) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, <=) }
	public static func >=(lhs: Vector, rhs: Element) -> NVectorb { return _compare(lhs: lhs, rhs: rhs, >=) }
}

extension NVector: NDimensionalType {
	public var dimension: Int { return 1 }
	public var shape: [Int] { return [size] }
	public subscript(index: [Int]) -> Element {
		get { assert(index.count == 1); return self[index[0]] }
		set { assert(index.count == 1); self[index[0]] = newValue }
	}
//	public var isCompact: Bool { return isCompact(dimension: 0) }
//	public func isCompact(dimension: Int) -> Bool {
//		assert(dimension == 0)
//		return slice.rstep == 1
//	}
}

extension NVector where Element == Bool {
	public var trueCount: Int {
		var c = 0
		for i in self.indices { c += self[i] ? 1 : 0 }
		return c
	}
	public static prefix func !(rhs: NVector) -> NVector { return rhs._deriving { for i in rhs.indices { $0[i] = !rhs[i] } } }
}
