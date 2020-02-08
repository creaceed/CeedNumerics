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



// Matrix type, with efficient creation and hi-perf slicing.
// Memory model is similar to Swift's UnsafeMutablePointer, ie, a matrix is a 'view' on mutable contents.
public struct NMatrix<Element: NValue> : NStorageAccessible, NDimensionalArray {
	public typealias Mask = NMatrixb
	public typealias Element = Element
	public typealias NativeResolvedSlice = NResolvedQuadraticSlice
	public typealias NativeIndex = NativeResolvedSlice.NativeIndex // NQuadraticIndex
	public typealias NativeRange = NQuadraticRange
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
	public typealias Storage = NStorage<Element>
	public typealias Access = Storage.QuadraticAccess
	
	public let storage: Storage
	// orthogonal - slices.rows does not account any column offset (which is entirely expressed through slices.column)
	// accessing memory requires both slices to be evaluated (and added).
	// Note: slice.position(_,_) can be used as storage[_] subscript. However, when using storage access (QuadraticAccess),
	// use its own slice position (access.slice.position) to address its .base pointer, as it removes offset
	public let slice: NResolvedQuadraticSlice
	
	// Conformance to NDArray
	public var rank: Int { return 2 } // tensor meaning (not a matrix's rank)
	public var rows: Int { return slice.row.rcount }
	public var columns: Int { return slice.column.rcount }
//	public var width: Int { return columns }
//	public var height: Int { return rows }
	public var size: NativeIndex { return NQuadraticIndex(rows, columns) }
	public var indices: NQuadraticRange { return NQuadraticRange(rows: rows, columns: columns) }
	public var compact: Bool { return slice.compact }
	public var coalesceable: Bool { return slice.coalesceable }
	
	public init(storage s: Storage, slice sl: NResolvedQuadraticSlice) {
		storage = s
		slice = sl
	}
	public init(storage s: Storage, slices sl: (row: NResolvedSlice, column: NResolvedSlice)) {
		self.init(storage: s, slice: NResolvedQuadraticSlice(row: sl.0, column: sl.1))
	}
	public init(compactData: Data, rows: Int, columns: Int) {
		precondition(compactData.count == rows * columns * MemoryLayout<Element>.stride)
		
		self.init(rows: rows, columns: columns)
		_setFromCompactData(compactData)
	}
	
	public init(repeating value: Element = .none, rows: Int, columns: Int) {
		let storage = Storage(allocatedCount: rows * columns, value: value)
		self.init(storage: storage, slice: .default(rows: rows, columns: columns))
	}
	public init(repeating value: Element = .none, size: NativeIndex) {
		self.init(repeating: value, rows: size.row, columns: size.column)
	}
	
	public init(_ values: [[Element]]) {
		precondition(values.count > 0)
		let rows = values.count, cols = values[0].count
		for element in values {	precondition(element.count == cols) }
		
		
		self.init(rows: rows, columns: cols)
		
		for (i, row) in values.enumerated() {
			for (j, val) in row.enumerated() {
				self[i, j] = val
			}
		}
	}
	// init from row-major values (values.count = rows x columns)
	public init(_ values: [Element], rows: Int, columns: Int) {
		precondition(values.count == rows * columns)
		self.init(rows: rows, columns: columns)
		self.set(from: values)
	}
	
	// Flatten returns a copy (compact & coalescable, distinct storage) that is reshaped to a single row 
	public func flatten() -> Matrix {
		let res = copy().reshaping(rows: 1, columns: -1)
		return res
	}
	public func asVector() -> Vector {
		precondition(coalesceable, "Matrix must be coalesceable to be reinterpreted as vector")
		let vecslice = NResolvedSlice(start: slice.row.rstart + slice.column.rstart,
									  count: slice.row.rcount * slice.column.rcount,
									  step: slice.column.rstep)
		let vector = Vector(storage: storage, slice: vecslice)
		return vector
	}
	
	public func reshaping(rows: Int, columns: Int) -> Matrix {
		return reshaping(to: NQuadraticIndex(rows, columns))
	}
	
	public func reshaping(to size: NativeIndex) -> Matrix {
		let rsize: NativeIndex
		let n = self.size.row * self.size.column
		
		// we could refine that
		precondition(coalesceable, "matrix should be coalesceable for reshaping. Copy it first if it is not.")
		
		switch size.tupleValue {
		case (-1, -1): preconditionFailure("bad size argument")
		case (-1, let c) where n % c == 0:
			rsize = NQuadraticIndex(n / c, c)
		case (let r, -1)  where n % r == 0:
			rsize = NQuadraticIndex(r, n / r)
		case (let r, let c)  where r * c == n:
			rsize = NQuadraticIndex(r, c)
		default: preconditionFailure("bad size argument")
		}
		
		let cslice = NResolvedSlice(start: slice.column.rstart, count: rsize.column, step: slice.column.rstep)
		let rslice = NResolvedSlice(start: slice.row.rstart, count: rsize.row, step: slice.column.rstep * rsize.column)
		
		return Matrix(storage: storage, slices: (row: rslice, column: cslice))
	}
	
	public var rawData : Data { return storage.rawData	}
	public var compactData : Data { // row major, no empty room between elements
		var data = Data(count: rows * columns * MemoryLayout<Element>.stride)
		
		Numerics.withStorageAccess(self) { aacc in
			data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
				let tpointer = pointer.bindMemory(to: Element.self).baseAddress!
				let memslice = NResolvedQuadraticSlice.default(rows: rows, columns: columns)
				for (pos, mpos) in zip(aacc.slice, memslice) {
					tpointer[mpos] = aacc.base[pos]
				}
			}
		}
		return data
	}
	private func _setFromCompactData(_ data: Data) {
		precondition(data.count == rows * columns * MemoryLayout<Element>.stride)
		
		Numerics.withStorageAccess(self) { aacc in
			data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
				let tpointer = pointer.bindMemory(to: Element.self).baseAddress!
				let memslice = NResolvedQuadraticSlice.default(rows: rows, columns: columns)
				for (pos, mpos) in zip(aacc.slice, memslice) {
					aacc.base[pos] = tpointer[mpos]
				}
			}
		}
	}
	
	// Get row/column as vector
	private func row(at index: Int) -> Vector {
		let rslice = NResolvedSlice(start: slice.position(index, 0), count: columns, step: slice.column.rstep)
		return Vector(storage: storage, slice: rslice)
	}
	
	private func column(at index: Int) -> Vector {
		let cslice = NResolvedSlice(start: slice.position(0, index), count: rows, step: slice.row.rstep)
		return Vector(storage: storage, slice: cslice)
	}
	// MARK: - Subscripts
	
	// Get subvector
	public subscript(row rindex: Int) -> Vector {
		get { return row(at: rindex) }
		nonmutating set { row(at: rindex).set(from: newValue) }
	}
	public subscript(column col: Int) -> Vector {
		get { return column(at: col) }
		nonmutating set { column(at: col).set(from: newValue) }
	}
	public subscript(rindex: Int, colSlice: NSliceExpression) -> Vector {
		get { return row(at: rindex)[colSlice] }
		nonmutating set { row(at: rindex)[colSlice].set(from: newValue) }
	}
	public subscript(rowSlice: NSliceExpression, col: Int) -> Vector {
		get { return column(at: col)[rowSlice] }
		nonmutating set { column(at: col)[rowSlice].set(from: newValue) }
	}
	// Get submatrix
	private func submatrix(_ rowSlice: NSliceExpression, _ colSlice: NSliceExpression) -> NMatrix<Element> {
		let rslice = rowSlice.resolve(within: slice.row)
		let cslice = colSlice.resolve(within: slice.column)
		return NMatrix<Element>(storage: storage, slices: (rslice, cslice))
	}
	public subscript(_ rowSlice: NSliceExpression, _ colSlice: NSliceExpression) -> Matrix {
		get { return submatrix(rowSlice, colSlice) }
		nonmutating set { submatrix(rowSlice, colSlice).set(from: newValue) }
	}
	public subscript(_ slice: (row: NSliceExpression, col: NSliceExpression)) -> Matrix {
		get { return submatrix(slice.row, slice.col) }
		nonmutating set { submatrix(slice.row, slice.col).set(from: newValue) }
	}
	
	// Unbounded slicing (matrix/vector)
	public subscript(_ unbounded: NUnboundedSlice, _ colSlice: NSliceExpression) -> Matrix {
		get { return self[NSlice.all, colSlice] }
		nonmutating set { self[NSlice.all, colSlice] = newValue }
	}
	public subscript(_ rowSlice: NSliceExpression, _ unbounded: NUnboundedSlice) -> Matrix {
		get { return self[rowSlice, NSlice.all] }
		nonmutating set { self[rowSlice, NSlice.all] = newValue }
	}
	// Unbounded slicing (vector)
	public subscript(_ unbounded: NUnboundedSlice, _ col: Int) -> Vector {
		get { return self[NSlice.all, col] }
		nonmutating set { self[NSlice.all, col] = newValue }
	}
	public subscript(_ row: Int, _ unbounded: NUnboundedSlice) -> Vector {
		get { return self[row, NSlice.all] }
		nonmutating set { self[row, NSlice.all] = newValue }
	}
	
	// Access one element
	public subscript(row: Int, column: Int) -> Element {
		get { return storage[slice.position(row, column)] }
		nonmutating set { storage[slice.position(row, column)] = newValue }
	}
	public subscript(index: NativeIndex) -> Element {
		get { return self[index.row, index.column] }
		nonmutating set { self[index.row, index.column] = newValue }
	}
	// Masked access
	public subscript(mask: NMatrixb) -> Vector {
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
	public subscript(indexes: NMatrixi) -> Vector {
		get {
			precondition(indexes.columns == 2)
			let result = Vector(size: indexes.size.row)
			for index in indexes.indices.row {
				let selfindex = NQuadraticIndex(indexes[index, 0], indexes[index, 1])
				assert(selfindex.row >= 0 && selfindex.row < self.rows)
				assert(selfindex.column >= 0 && selfindex.column < self.columns)
				result[index] = self[selfindex]
			}
			return result
		}
		nonmutating set {
			precondition(indexes.columns == 2)
			precondition(newValue.size == indexes.size.row)
			for index in indexes.indices.row {
				let selfindex = NQuadraticIndex(indexes[index, 0], indexes[index, 1])
				assert(selfindex.row >= 0 && selfindex.row < self.rows)
				assert(selfindex.column >= 0 && selfindex.column < self.columns)
				self[selfindex] = newValue[index]
			}

		}
	}
	
	public subscript(index: [Int]) -> Element {
		get { assert(index.count == rank); return self[index[0], index[1]] }
		nonmutating set { assert(index.count == rank); self[index[0], index[1]] = newValue }
	}
	// MARK: - Storage Access
	// Entry point. Use Numerics.with variants as API
	public func _withStorageAccess<Result>(_ block: (_ access: Storage.QuadraticAccess) throws -> Result) rethrows -> Result {
		return try storage.withUnsafeAccess { saccess in
			let base = saccess.base + slice.position(0, 0)
			let access = Storage.QuadraticAccess(base: base, stride: (slice.row.rstep, slice.column.rstep), count: (slice.row.rcount, slice.column.rcount))
			return try block(access)
		}
	}
	
}
