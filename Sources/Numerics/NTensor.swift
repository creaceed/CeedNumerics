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
