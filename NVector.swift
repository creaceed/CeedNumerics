//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

public class NVector<Element: NValue> {
	public typealias Storage = NStorage<Element>
	public typealias Vector = NVector<Element>
	
	private let storage: Storage
	private let slice: NResolvedSlice // addresses storage directly
	
	public var size: Int { return slice.rcount }
	public var indices: Range<Int> { return 0..<size }
	
	public var first: Element? { return size > 0 ? self[0] : nil }
	public var last: Element? { return size > 0 ? self[size-1] : nil }
	
	// MARK: - Init -
	public init(storage mem: Storage, slice sl: NResolvedSlice) {
		storage = mem
		//layout = l
		slice = sl
	}
	public convenience init(size: Int) {
		let storage = Storage(allocatedCount: size)
		self.init(storage: storage, slice: .default(count: size))
	}
	public convenience init(storage mem: Storage, count: Int) {
		let slice = NResolvedSlice(start: 0, count: count, step: 1)
		self.init(storage: mem, slice: slice)
	}
	public convenience init(_ elements: [Element]) {
		self.init(size: elements.count)
		
		storage.withUnsafeAccess { access in
			_ = UnsafeMutableBufferPointer(start: access.base, count: self.size).initialize(from: elements)
		}
	}
	public convenience init(repeating value: Element, count: Int) {
		self.init(size: count)
		
		storage.withUnsafeAccess { access in
			_ = UnsafeMutableBufferPointer(start: access.base, count: self.size).initialize(repeating: value)
		}
	}
	public convenience init(size: Int, generator: (_ index: Int) -> Element) {
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
	
	// quickie to allocate result with same size as self.
	internal func _deriving(_ prep: (Vector) -> ()) -> Vector {
		let result = Vector(size: self.size)
		prep(result)
		return result
	}
	
	// MARK: - Slicing -
	public subscript(_ s: NSliceExpression) -> Vector {
		get { return Vector(storage: storage, slice: s.resolve(within: slice)) }
		set { Vector(storage: storage, slice: s.resolve(within: slice)).set(from: newValue) }
	}
	// Access one element
	public subscript(index: Int) -> Element {
		get { return storage[slice.position(at: index)] }
		set { storage[slice.position(at: index)] = newValue }
	}
	
	// Use Numerics.with variants
	internal func _withStorageAccess<Result>(_ block: (_ access: Storage.LinearAccess) throws -> Result) rethrows -> Result {
		return try storage.withUnsafeAccess { saccess in
			let access = Storage.LinearAccess(base: saccess.base + slice.rstart, step: slice.rstep, count: slice.rcount)
			return try block(access)
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
}

extension NVector {
	public func set(from: Vector) {
		precondition(from.slice.rcount == slice.rcount)
		
		Numerics.withStorageStride(from, self) { pfrom, pself in
			pself.pointee = pfrom.pointee
		}
	}
}

extension NVector: NDimensionalType {
	public var dimension: Int { return 1 }
	public var shape: [Int] { return [size] }
	public subscript(index: [Int]) -> Element {
		get { assert(index.count == 1); return self[index[0]] }
		set { assert(index.count == 1); self[index[0]] = newValue }
	}
	public var isCompact: Bool { return isCompact(dimension: 0) }
	public func isCompact(dimension: Int) -> Bool {
		assert(dimension == 0)
		return slice.rstep == 1
	}
}

