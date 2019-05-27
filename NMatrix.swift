//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation



// Matrix type, with efficient creation and hi-perf slicing.
// Memory model is similar to Swift's UnsafeMutablePointer, ie, a matrix is a 'view' on mutable contents.
public struct NMatrix<Element: NValue> : NStorageAccessible {
	public typealias NativeIndex = (row: Int, column: Int)
	public typealias NativeIndexRange = NQuadraticIndexRange
	public typealias Storage = NStorage<Element>
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
	public typealias Access = Storage.QuadraticAccess
	
	private let storage: Storage
	// orthogonal - slices.rows does not account any column offset (which is entirely expressed through slices.column)
	// accessing memory requires both slices to be evaluated (and added).
	// Note: slice.position(_,_) can be used as storage[_] subscript. However, when using storage access (QuadraticAccess),
	// use its own slice position (access.slice.position) to address its .base pointer, as it removes offset
	private let slice: NResolvedQuadraticSlice
	
	public var rows: Int { return slice.row.rcount }
	public var columns: Int { return slice.column.rcount }
//	public var width: Int { return columns }
//	public var height: Int { return rows }
	public var size: NativeIndex { return (rows, columns) }
	public var indices: NQuadraticIndexRange { return NQuadraticIndexRange(rows: rows, columns: columns) }
	public var compact: Bool { return slice.compact }
	
	public init(storage s: Storage, slice sl: NResolvedQuadraticSlice) {
		storage = s
		slice = sl
	}
	public init(storage s: Storage, slices sl: (NResolvedSlice, NResolvedSlice)) {
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
		self.init(repeating: value, rows: size.0, columns: size.1)
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
	
	public func copy() -> NMatrix {
		let result = NMatrix(rows: rows, columns: columns)
		result.set(from: self)
		return result
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
	private func vector(row: Int) -> Vector {
		let rslice = NResolvedSlice(start: slice.position(row, 0), count: columns, step: slice.column.rstep)
		return Vector(storage: storage, slice: rslice)
	}
	public subscript(row row: Int) -> Vector {
		get { return vector(row: row) }
		nonmutating set { vector(row: row).set(from: newValue) }
	}
	
	private func vector(column: Int) -> Vector {
		let cslice = NResolvedSlice(start: slice.position(0, column), count: rows, step: slice.row.rstep)
		return Vector(storage: storage, slice: cslice)
	}
	public subscript(column col: Int) -> Vector {
		get { return vector(column: col) }
		nonmutating set { vector(column: col).set(from: newValue) }
	}
	// Get submatrix
	private func submatrix(_ rowSlice: NSliceExpression, _ colSlice: NSliceExpression) -> Matrix {
		let rslice = rowSlice.resolve(within: slice.row)
		let cslice = colSlice.resolve(within: slice.column)
		return Matrix(storage: storage, slices: (rslice, cslice))
	}
	public subscript(_ rowSlice: NSliceExpression, _ colSlice: NSliceExpression) -> Matrix {
		get { return submatrix(rowSlice, colSlice) }
		nonmutating set { submatrix(rowSlice, colSlice).set(from: newValue) }
	}
	
	// Access one element
	public subscript(row: Int, column: Int) -> Element {
		get { return storage[slice.position(row, column)] }
		nonmutating set { storage[slice.position(row, column)] = newValue }
	}
	public subscript(index: NativeIndex) -> Element {
		get { return self[index.0, index.1] }
		nonmutating set { self[index.0, index.1] = newValue }
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
				let selfindex = (indexes[index, 0], indexes[index, 1])
				assert(selfindex.0 >= 0 && selfindex.0 < self.rows)
				assert(selfindex.1 >= 0 && selfindex.1 < self.columns)
				result[index] = self[selfindex]
			}
			return result
		}
		nonmutating set {
			precondition(indexes.columns == 2)
			precondition(newValue.size == indexes.size.row)
			for index in indexes.indices.row {
				let selfindex = (indexes[index, 0], indexes[index, 1])
				assert(selfindex.0 >= 0 && selfindex.0 < self.rows)
				assert(selfindex.1 >= 0 && selfindex.1 < self.columns)
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
}

// TODO: These Vector / Matrix funcs are very similar. Could probably push that into NDimensionalType.
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

extension NMatrix: NDimensionalType {
	public var dimension: Int { return 2 }
	public var shape: [Int] { return [rows, columns] }
	
	public subscript(index: [Int]) -> Element {
		get { assert(index.count == dimension); return self[index[0], index[1]] }
		set { assert(index.count == dimension); self[index[0], index[1]] = newValue }
	}
}

extension NMatrix where Element == Bool {
	public var trueCount: Int {
		var c = 0
		for i in self.indices { c += self[i] ? 1 : 0 }
		return c
	}
	public static prefix func !(rhs: NMatrix) -> NMatrix { return rhs._deriving { for i in rhs.indices { $0[i] = !rhs[i] } } }
}
