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
	public var indices: NQuadraticIndexRange { return NQuadraticIndexRange(rows: rows, columns: columns) }
	
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
	
	public func copy() -> NMatrix {
		let result = NMatrix(rows: rows, columns: columns)
		result.set(from: self)
		return result
	}
	
	public var rawData : Data { return storage.rawData	}
	public var compactData : Data { // row major, no empty room between elements
		var data = Data(count: rows * columns * MemoryLayout<Element>.stride)
		
		Numerics.withStorageAccess(self) { aacc in
			data.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<Element>) in
				let memslice = NResolvedQuadraticSlice.default(rows: rows, columns: columns)
				for (pos, mpos) in zip(aacc.slice, memslice) {
					pointer[mpos] = aacc.base[pos]
				}
			}
		}
		return data
	}
	private func _setFromCompactData(_ data: Data) {
		precondition(data.count == rows * columns * MemoryLayout<Element>.stride)
		
		Numerics.withStorageAccess(self) { aacc in
			data.withUnsafeBytes { (pointer: UnsafePointer<Element>) in
				let memslice = NResolvedQuadraticSlice.default(rows: rows, columns: columns)
				for (pos, mpos) in zip(aacc.slice, memslice) {
					aacc.base[pos] = pointer[mpos]
				}
			}
		}
	}
	
	// quickie to allocate result with same size as self.
	internal func _deriving(_ prep: (Matrix) -> ()) -> Matrix {
		let result = Matrix(rows: rows, columns: columns)
		prep(result)
		return result
	}
	
	public func set(from: Matrix) {
		// TODO: could be faster (storage)
		for (pos, rpos) in zip(slice, from.slice) {
			storage[pos] = from.storage[rpos]
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
	
	// Access
	public func set(_ value: Element) {
		for pos in slice {
			storage[pos] = value
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

extension NMatrix where Element: SignedNumeric, Element.Magnitude == Element {
	public func isEqual(to rhs: NMatrix, tolerance: Element) -> Bool {
		precondition(rhs.shape == shape)
		
		// TODO: could be faster (storage)
		for (pos, rpos) in zip(slice, rhs.slice) {
			if abs(storage[rpos] - rhs.storage[pos]) > tolerance { return false }
		}
		
		return true
	}
}

extension NMatrix: NDimensionalType {
	public var dimension: Int { return 2 }
	public var shape: [Int] { return [rows, columns] }
	public var isCompact: Bool { return isCompact(dimension: 1) }
	
	public subscript(index: [Int]) -> Element {
		get { assert(index.count == dimension); return self[index[0], index[1]] }
		set { assert(index.count == dimension); self[index[0], index[1]] = newValue }
	}
	public func isCompact(dimension: Int) -> Bool {
		assert(dimension == 0 || dimension == 1)
		switch dimension {
		case 0: return abs(slice.column.rstep) == 1
		case 1: return isCompact(dimension: 0) && abs(slice.row.rstep) == columns
		default:
			assert(false)
			return false
		}
	}
}
