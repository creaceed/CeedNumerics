//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

public struct NMatrixLayout {
	public let offset: Int	// gives element 0 (with identity slice)
	public let stride: (row: Int, column: Int) // across (row, column), typically (N, 1)
	
	public static func `default`(columns: Int) -> NMatrixLayout {
		return NMatrixLayout(offset: 0, stride: (columns, 1))
	}
	public func location(row rpos: Int, column cpos: Int) -> Int {
		return offset + stride.row * rpos + stride.column * cpos
	}
	
	public func layout(row: Int) -> NVectorLayout {
		return NVectorLayout(offset: offset + row * stride.row, stride: stride.column)
	}
	public func layout(column: Int) -> NVectorLayout {
		return NVectorLayout(offset: offset + column * stride.column, stride: stride.row)
	}
}

public class NMatrix<Element: NValue> {
	public typealias Storage = NStorage<Element>
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
	
	private let storage: Storage
	private let layout: NMatrixLayout
	private let slices: (rows: NResolvedSlice, columns: NResolvedSlice)
	
	public var rawData : Data { return storage.rawData	}
	
	public var rows: Int { return slices.rows.rcount }
	public var columns: Int { return slices.columns.rcount }
	
	public init(storage s: Storage, layout l: NMatrixLayout, slices sl: (NResolvedSlice, NResolvedSlice)) {
		storage = s
		layout = l
		slices = sl
	}
	
	public convenience init(repeating value: Element = .none, rows: Int, columns: Int) {
		let storage = Storage(allocatedCount: rows * columns, value: value)
		self.init(storage: storage, layout: .default(columns: columns), slices: (.default(count: rows),
																				 .default(count: columns)))
	}
	
	public convenience init(_ values: [[Element]]) {
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
	
	// quickie to allocate result with same size as self.
	internal func _deriving(_ prep: (Matrix) -> ()) -> Matrix {
		let result = Matrix(rows: rows, columns: columns)
		prep(result)
		return result
	}
	
	public func set(from: Matrix) {
		var it = NStorage<Element>.QuadraticIterator(layout: from.layout, slices: from.slices)
		var rit = NStorage<Element>.QuadraticIterator(layout: layout, slices: slices)
		
		// could be faster
		while let pos = it.next(), let rpos = rit.next() {
			storage[rpos] = from.storage[pos]
		}
	}
	
	// Get row/column as vector
	private func vector(row: Int) -> Vector {
		return Vector(storage: storage, layout: layout.layout(row: row), slice: slices.columns)
	}
	public subscript(row row: Int) -> Vector {
		get { return vector(row: row) }
		// TODO: improve that to avoid vector allocation. Could use something like an "iterator struct"
		set { vector(row: row).set(from: newValue) }
	}
	
	private func vector(column: Int) -> Vector {
		return Vector(storage: storage, layout: layout.layout(column: column), slice: slices.rows)
	}
	public subscript(column col: Int) -> Vector {
		get { return vector(column: col) }
		set { vector(column: col).set(from: newValue) }
	}
	// Get submatrix
//	public subscript<S: NSliceExpression>(_ rowSlice: S, _ colSlice: S) -> Matrix {
//		let rslice = rowSlice.resolve(within: slices.rows)
//		let cslice = colSlice.resolve(within: slices.columns)
//		
//		return Matrix(storage: storage, layout: layout, slices: (rslice, cslice))
//	}
	
	public subscript(_ rowSlice: NSliceExpression, _ colSlice: NSliceExpression) -> Matrix {
		let rslice = rowSlice.resolve(within: slices.rows)
		let cslice = colSlice.resolve(within: slices.columns)
		print(rowSlice)
		
		return Matrix(storage: storage, layout: layout, slices: (rslice, cslice))
	}
	
	internal func _storageIterator() -> NStorage<Element>.QuadraticIterator {
		let it = NStorage<Element>.QuadraticIterator(layout: layout, slices: slices)
		return it
	}
	
	private func _storageLocation(row: Int, columns: Int) -> Int {
		let r = slices.rows.position(at: row)
		let c = slices.columns.position(at: columns)
		let loc = layout.location(row: r, column: c)
		return loc
	}
	// Access one element
	public subscript(row: Int, column: Int) -> Element {
		get {
			return storage[_storageLocation(row: row, columns: column)]
		}
		set {
			storage[_storageLocation(row: row, columns: column)] = newValue
		}
	}
	
	// Access
	public func set(_ value: Element) {
		var it = _storageIterator()
		while let pos = it.next() {
			storage[pos] = value
		}
	}
	
	// Storage access
	public typealias QuadraticStorageAccess = (base: UnsafeMutablePointer<Element>, stride: (row: Int, column: Int), count: (row: Int, column: Int))
	public func withStorageAccess<Result>(_ block: (_ access: QuadraticStorageAccess) throws -> Result) rethrows -> Result {
		return try storage.withUnsafeAccess { saccess in
			let base = saccess.base + _storageLocation(row: 0, columns: 0)
			let access: QuadraticStorageAccess = (base, (slices.rows.rstep * layout.stride.row, slices.columns.rstep * layout.stride.column), (slices.rows.rcount, slices.columns.rcount))
			return try block(access)
		}
	}
}

extension NMatrix where Element: SignedNumeric, Element.Magnitude == Element {
	public func isEqual(to rhs: NMatrix, tolerance: Element) -> Bool {
		precondition(rhs.shape == shape)
		
		var lit = self._storageIterator()
		var rit = rhs._storageIterator()
		
		// TODO: could be faster
		while let pos = lit.next(), let rpos = rit.next() {
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
		case 0: return abs(layout.stride.column * slices.columns.rstep) == 1
		case 1: return isCompact(dimension: 0) && abs(layout.stride.row * slices.rows.rstep) == columns
		default:
			assert(false)
			return false
		}
	}
}
