//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation



// Matrix type, with efficient creation and hi-perf slicing.
// Memory model is similar to Swift's UnsafeMutablePointer, ie, a matrix is a 'view' on mutable contents.
public struct NMatrix<Element: NValue> : NStorageAccessible, NDimensionalArray {
	public typealias Mask = NMatrixb
	public typealias Element = Element
	public typealias NativeResolvedSlice = NResolvedQuadraticSlice
	public typealias NativeIndex = NativeResolvedSlice.NativeIndex // NQuadraticIndex
	public typealias NativeIndexRange = NQuadraticIndexRange
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
	public typealias Storage = NStorage<Element>
	public typealias Access = Storage.QuadraticAccess
	
	private let storage: Storage
	// orthogonal - slices.rows does not account any column offset (which is entirely expressed through slices.column)
	// accessing memory requires both slices to be evaluated (and added).
	// Note: slice.position(_,_) can be used as storage[_] subscript. However, when using storage access (QuadraticAccess),
	// use its own slice position (access.slice.position) to address its .base pointer, as it removes offset
	private let slice: NResolvedQuadraticSlice
	
	// Conformance to NDArray
	public var dimension: Int { return 2 }
	public var shape: [Int] { return [rows, columns] }
	
	public var rows: Int { return slice.row.rcount }
	public var columns: Int { return slice.column.rcount }
//	public var width: Int { return columns }
//	public var height: Int { return rows }
	public var size: NativeIndex { return NQuadraticIndex(rows, columns) }
	public var indices: NQuadraticIndexRange { return NQuadraticIndexRange(rows: rows, columns: columns) }
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
	
	// Copy that is compact & coalescable, and with distinct storage from original
	public func copy() -> Matrix {
		let result = Matrix(rows: rows, columns: columns)
		result.set(from: self)
		return result
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
	public subscript(row rindex: Int) -> Vector {
		get { return row(at: rindex) }
		nonmutating set { row(at: rindex).set(from: newValue) }
	}
	
	private func column(at index: Int) -> Vector {
		let cslice = NResolvedSlice(start: slice.position(0, index), count: rows, step: slice.row.rstep)
		return Vector(storage: storage, slice: cslice)
	}
	public subscript(column col: Int) -> Vector {
		get { return column(at: col) }
		nonmutating set { column(at: col).set(from: newValue) }
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
	
	// Entry point. Use Numerics.with variants as API
	public func _withStorageAccess<Result>(_ block: (_ access: Storage.QuadraticAccess) throws -> Result) rethrows -> Result {
		return try storage.withUnsafeAccess { saccess in
			let base = saccess.base + slice.position(0, 0)
			let access = Storage.QuadraticAccess(base: base, stride: (slice.row.rstep, slice.column.rstep), count: (slice.row.rcount, slice.column.rcount))
			return try block(access)
		}
	}
	
	public subscript(index: [Int]) -> Element {
		get { assert(index.count == dimension); return self[index[0], index[1]] }
		nonmutating set { assert(index.count == dimension); self[index[0], index[1]] = newValue }
	}
}

// TODO: These Vector / Matrix funcs are very similar. Could probably push that into NDimensionalArray.
extension NMatrix {
	// Access
	// Note: set API does not expose data range as NMatrix slicing is used for that
	public func set(from: Matrix) {
		for (pos, rpos) in zip(slice, from.slice) {
			storage[pos] = from.storage[rpos]
		}
	}
	public func set(_ value: Element) {
		for pos in slice {
			storage[pos] = value
		}
	}
	public func set(_ value: Element, mask: NMatrixb) {
		precondition(mask.size == size)
		for i in self.indices {
			if mask[i] { self[i] = value }
		}
	}
	public func set(from rowMajorValues: [Element]) {
		precondition(rowMajorValues.count == rows * columns)
		for (pos, rpos) in zip(slice, rowMajorValues.indices) {
			storage[pos] = rowMajorValues[rpos]
		}
	}
}

extension NMatrix where Element: SignedNumeric, Element.Magnitude == Element {
	public func isEqual(to rhs: NMatrix, tolerance: Element) -> Bool {
		precondition(rhs.shape == shape)
		
		// TODO: could be faster (storage)
		for (pos, rpos) in zip(slice, rhs.slice) {
			if abs(storage[rpos] - rhs.storage[pos]) > tolerance { return false }
		}
		
		return true
	}
	private static func _compare(lhs: Matrix, rhs: Matrix, _ op: (Element, Element) -> Bool) -> NMatrixb {
		precondition(lhs.size == rhs.size)
		let res = NMatrixb(size: lhs.size)
		for i in res.indices { res[i] = op(lhs[i], rhs[i]) }
		return res
	}
	private static func _compare(lhs: Matrix, rhs: Element, _ op: (Element, Element) -> Bool) -> NMatrixb {
		let res = NMatrixb(size: lhs.size)
		for i in res.indices { res[i] = op(lhs[i], rhs) }
		return res
	}
	public static func <(lhs: Matrix, rhs: Matrix) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, <) }
	public static func >(lhs: Matrix, rhs: Matrix) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, >) }
	public static func <=(lhs: Matrix, rhs: Matrix) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, <=) }
	public static func >=(lhs: Matrix, rhs: Matrix) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, >=) }
	// cannot do that
//	public static func ==(lhs: Matrix, rhs: Matrix) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, >=) }
	
	public static func <(lhs: Matrix, rhs: Element) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, <) }
	public static func >(lhs: Matrix, rhs: Element) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, >) }
	public static func <=(lhs: Matrix, rhs: Element) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, <=) }
	public static func >=(lhs: Matrix, rhs: Element) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, >=) }
	public static func ==(lhs: Matrix, rhs: Element) -> NMatrixb { return _compare(lhs: lhs, rhs: rhs, ==) }
}
