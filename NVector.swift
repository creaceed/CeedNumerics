//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

// Vector type, with efficient creation and hi-perf slicing.
// Memory model is similar to Swift's UnsafeMutablePointer, ie, a vector is a 'view' on mutable contents.
public struct NVector<Element: NValue> : NStorageAccessible, NDimensionalArray {
	public typealias Mask = NVectorb
	public typealias NativeResolvedSlice = NResolvedSlice
	public typealias NativeIndex = NativeResolvedSlice.NativeIndex // Int
	public typealias NativeIndexRange = Range<Int>
	public typealias Storage = NStorage<Element>
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
	public typealias Access = Storage.LinearAccess
	
	private let storage: Storage
	private let slice: NResolvedSlice // addresses storage directly
	
	public var dimension: Int { return 1 }
	public var size: Int { return slice.rcount }
	public var indices: Range<Int> { return 0..<size }
	public var compact: Bool { return slice.rstep == 1 } // only positive steps are considered compact
	public var coalesceable: Bool { return true } // vectors are always coalesceable because coalesce(vec)==vec
	
	public var first: Element? { return size > 0 ? self[0] : nil }
	public var last: Element? { return size > 0 ? self[size-1] : nil }
	
	// MARK: - Init -
	// NDArray init
	public init(storage mem: Storage, slice sl: NResolvedSlice) {
		storage = mem
		slice = sl
	}
	public init(repeating value: Element = .none, size: Int) {
		let storage = Storage(allocatedCount: size)
		self.init(storage: storage, slice: .default(size: size))
		
		storage.withUnsafeAccess { access in
			_ = UnsafeMutableBufferPointer(start: access.base, count: self.size).initialize(repeating: value)
		}
	}
	
	// Custom init
	public init(_ values: [Element]) {
		self.init(size: values.count)
		storage.withUnsafeAccess { access in
			_ = UnsafeMutableBufferPointer(start: access.base, count: self.size).initialize(from: values)
		}
	}
	
	public func asMatrix() -> NMatrix<Element> {
		let colslice = slice
		let rowslice = NResolvedSlice(start: 0, count: 1, step: colslice.rstep * colslice.rcount)
		let matrix = NMatrix<Element>(storage: storage, slices: (row: rowslice, column: colslice))
		
		return matrix
	}
	
	// MARK: - Slicing -
	// NDarray: Access one element
	public subscript(index: [Int]) -> Element {
		get { assert(index.count == 1); return self[index[0]] }
		nonmutating set { assert(index.count == 1); self[index[0]] = newValue }
	}
	public subscript(index: Int) -> Element {
		get { return storage[slice.position(at: index)] }
		nonmutating set { storage[slice.position(at: index)] = newValue }
	}
	// Specific (slicing)s
	public subscript(_ s: NSliceExpression) -> Vector {
		get { return Vector(storage: storage, slice: s.resolve(within: slice)) }
		nonmutating set { Vector(storage: storage, slice: s.resolve(within: slice)).set(from: newValue) }
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

