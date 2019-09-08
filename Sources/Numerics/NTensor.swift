//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation


// Tensor with arbitrary dimension

public struct NTensor<Element: NValue> : NStorageAccessible, NDimensionalArray {
	public typealias Mask = NTensor<Bool>
	public typealias Element = Element
	public typealias NativeResolvedSlice = NResolvedGenericSlice
	public typealias NativeIndex = NResolvedGenericSlice.NativeIndex // NGenericIndex = [Int]
	public typealias NativeIndexRange = NGenericIndexRange
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
	public typealias Storage = NStorage<Element>
	public typealias Access = Storage.GenericAccess
	
	private let storage: Storage
	private let slice: NResolvedGenericSlice
	
	// Conformance to NDArray
	public var dimension: Int { return slice.dimension }
	public var size: NativeIndex { return slice.components.map { $0.rcount } }
	public var indices: NGenericIndexRange { return NGenericIndexRange(counts: size) }
	public var compact: Bool { return slice.compact }
	public var coalesceable: Bool { return slice.coalesceable }
	
	public init(storage s: Storage, slice sl: NResolvedGenericSlice) {
		storage = s
		slice = sl
	}
	public init(repeating value: Element = .none, size: NativeIndex) {
		let storage = Storage(allocatedCount: size.asElementCount, value: value)
		self.init(storage: storage, slice: .default(size: size))
	}
	
	// MARK: - Subscript
	public subscript(index: [Int]) -> Element {
		get { return storage[slice.position(at: index)] }
		nonmutating set { storage[slice.position(at: index)] = newValue }
	}
	
	// MARK: - Storage Access
	// Entry point. Use Numerics.with variants as API
	public func _withStorageAccess<Result>(_ block: (_ access: Access) throws -> Result) rethrows -> Result {
		return try storage.withUnsafeAccess { saccess in
			let base = saccess.base + slice.position(at: NGenericIndex.zero(dimension:dimension))
			let access = Storage.GenericAccess(base: base, stride: slice.components.map { $0.rstep }, count: slice.components.map { $0.rcount })
			return try block(access)
		}
	}
}
