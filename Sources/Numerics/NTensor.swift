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

// can also be passed as tensor subscript arguments (in addition to slice, index, etc.)
// see Globals to access it as n.newaxis
enum NAxisOperator {
	case new
	// case filler // not implemented. Avoids specifying all axes in subscript: a[1~3, filler, 2]
}

// used internally when parsing subscript args
private enum AxisTask {
	case slice(value: NResolvedSlice)
	case index(value: Int)
	case insert(at: Int)
}

// Tensor with arbitrary dimension
public struct NTensor<Element: NValue> : NStorageAccessible, NDimensionalArray {
	public typealias Mask = NTensor<Bool>
	public typealias Element = Element
	public typealias NativeResolvedSlice = NResolvedGenericSlice
	public typealias NativeIndex = NResolvedGenericSlice.NativeIndex // NGenericIndex = [Int]
	public typealias NativeRange = NGenericRange
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
	public typealias Storage = NStorage<Element>
	public typealias Access = Storage.GenericAccess
	public typealias Axis = Int // identifies each tensor dimension (there are rank axes)

	public let storage: Storage
	public let slice: NResolvedGenericSlice
	
	// Conformance to NDArray
	public var rank: Int { return slice.rank }
	public var size: NativeIndex { return slice.components.map { $0.rcount } }
	public var indices: NGenericRange { return NGenericRange(counts: size) }
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
	
	// 'at' is expressed in the receiver axis range
	public func insertingNewAxis(at: Int) -> Self {
		precondition(at >= 0 && at <= rank)
		
		let newSlice: NResolvedSlice
		if at < rank {
			let next: NResolvedSlice = self.slice.components[at]
			newSlice = NResolvedSlice(start: 0, count: 1, step: next.rcount * next.rstep)
		} else {
			let previous: NResolvedSlice = self.slice.components[rank-1]
			newSlice = NResolvedSlice(start: 0, count: 1, step: previous.rstep)
		}
		
		var slices: [NResolvedSlice] = self.slice.components
		slices.insert(newSlice, at: at)
		
		return Self(storage: storage, slice: NResolvedGenericSlice(slices))
	}
	public func insertingNewAxes(at: [Int]) -> Self {
		// reverse order to avoid coping with insertion offsets
		let indexes = at.sorted().reversed()
		var tensor = self
		for i in indexes {
			tensor = tensor.insertingNewAxis(at: i)
		}
		return tensor
	}
	
	// MARK: - Index resolution
	private func _resolvedIndex(_ index: NIndex, axis: Axis) -> Int {
		return resolveIndex(index, size: slice.components[axis].rcount)
	}
	private func _resolvedIndex(_ index: [NIndex]) -> [Int] {
		precondition(index.count == rank)
		let resolved = zip(0..<rank, index).map { _resolvedIndex($0.1, axis: $0.0) }
		return resolved
	}

	// MARK: - Subscript
	public subscript(index: [NIndex]) -> Element {
		get { return storage[slice.position(at: _resolvedIndex(index))] }
		nonmutating set { storage[slice.position(at: _resolvedIndex(index))] = newValue }
	}
	public subscript(_ indexes: NIndex...) -> Element {
		get { return self[indexes] }
		nonmutating set { self[indexes] = newValue }
	}
	
	// Get subtensor
// 	private func subtensor(_ dimSlices: [NSliceExpression]) -> Self {
// 		// note: at this time we only support NSliceExpression, and arg count sould be equal to
// 		// receiver rank. But, both constraints can later be removed with Any... to provide
// 		// more flexible tensor subscripting (at the cost of performances, but that's OK)
		
// 		precondition(dimSlices.count == rank)
		
// 		let resolvedSlices: [NResolvedSlice] = zip(dimSlices, slice.components).map { $0.0.resolve(within: $0.1) }
// 		let s = NResolvedGenericSlice(resolvedSlices)
		
// 		return Self(storage: storage, slice: s)
// //		return NMatrix<Element>(storage: storage, slices: (rslice, cslice))
// 	}

	// Note: a rawOp can be one of these:
	// - NSliceExpression
	// - ~ (= NSlice.all)
	// - NIndex (will collapse axis)
	// - AxisOperation.insert (will insert axis)
	private func subtensor(_ rawOps: [Any]) -> Self {
		// could change if we support axis filler (...) and/or newaxis API.
		// precondition(rawOps.count == rank)
		
		// construct the axis operation array
		var inaxis = 0, outaxis = 0
		let ops: [AxisTask] = rawOps.map { rop in
			switch rop {
				case let index as Int: 
					let op: AxisTask = .index(value: _resolvedIndex(index, axis: inaxis))
					inaxis += 1
					outaxis += 0
					return op
				case is NUnboundedSlice: 
					let op: AxisTask = .slice(value: NSlice.all.resolve(within: self.slice.components[inaxis]))
					inaxis += 1
					outaxis += 1
					return op
				case let slice as NSliceExpression: 
					let op: AxisTask = .slice(value: slice.resolve(within: self.slice.components[inaxis]))
					inaxis += 1
					outaxis += 1
					return op
				case .new as NAxisOperator: 
					let op: AxisTask = .insert(at: outaxis)
					inaxis += 0
					outaxis += 0
					return op
				default:
					fatalError("not supported")
			}
		}
		precondition(inaxis == rank)

		// let slices: [NResolvedSlice] = ops.enumerated().map { axis, op in
		// 	switch op {
		// 		case .index(let value): return NSlice(start: value, end: value+1, step: nil).resolve(size: self.slice.components[axis].rcount)
		// 		case .slice(let value): return value
		// 	}
		// }

		var slices: [NResolvedSlice] = []
		var offset: Int = 0
		for (axis,op) in ops.enumerated() {
			switch op {
				case .index(let value):
					// removing a slice & correspondingly increasing offset
					offset += self.slice.components[axis].position(at: value)
				case .slice(let value): 
					slices.append(value)
				case .insert: break
			}
		}
		// it must exist, otherwise we should be in the [Int...] subscript
		// a fully indexed tensor is not a tensor anymore, it's a value (= 0-rank tensor).
		slices[0] = NResolvedSlice(start: slices[0].rstart + offset, count: slices[0].rcount, step: slices[0].rstep)

		// create tensor (with possibly 1-sized axes)
		var tensor = Self(storage: storage, slice: NResolvedGenericSlice(slices))
		
		// insert new axes if any
		tensor = tensor.insertingNewAxes(at: ops.compactMap { 
			if case let AxisTask.insert(at) = $0 { 
				return at
			}
			else { return nil } 
		})

		return tensor
	}
	public subscript(_ dimSlices: Any...) -> Self {
		get { return subtensor(dimSlices) }
		nonmutating set { subtensor(dimSlices).set(from: newValue) }
	}
	
	// MARK: - Storage Access
	// Entry point. Use Numerics.with variants as API
	public func _withStorageAccess<Result>(_ block: (_ access: Access) throws -> Result) rethrows -> Result {
		return try storage.withUnsafeAccess { saccess in
			let base = saccess.base + slice.position(at: NGenericIndex.zero(rank:rank))
			let access = Storage.GenericAccess(base: base, stride: slice.components.map { $0.rstep }, count: slice.components.map { $0.rcount })
			return try block(access)
		}
	}
}
