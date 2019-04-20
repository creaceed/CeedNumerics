//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

// Note: layout is defined once with the original container.
//
// With same dimensionality slicing:
//		sliced container are always supposed to have the same layout
//		as their parent: although layout's stride and slice's step can compete, the goal is to define layout once, then do all
//		slicing operations using slices.
// With descreasing dimensionality slicing (matrix -> array):
//		offset embeds memory offset from other othogonal directions. Getting column '3' array from a matrix will have offset set to 3, stride set to R.
public struct NVectorLayout {
	public let offset: Int	// gives element 0 (with identity slice)
	public let stride: Int // between successive elements
	
	public static let `default` = NVectorLayout(offset: 0, stride: 1)
	
	public func location(for position: Int) -> Int {
		return offset + stride * position
	}
}
public class NVector<Element: NValue> {
	public typealias Storage = NStorage<Element>
	public typealias Vector = NVector<Element>
	
	private let storage: Storage
	private let layout: NVectorLayout
	private let slice: NResolvedSlice
	
	public var size: Int { return slice.rcount }
	
	public var first: Element? { return size > 0 ? self[0] : nil }
	public var last: Element? { return size > 0 ? self[size-1] : nil }
	
	// MARK: - Init -
	public init(storage mem: Storage, layout l: NVectorLayout = .default, slice sl: NResolvedSlice) {
		storage = mem
		layout = l
		slice = sl
	}
	public convenience init(size: Int) {
		let storage = Storage(allocatedCount: size)
		self.init(storage: storage, layout: .default, slice: .default(count: size))
	}
	public convenience init(storage mem: Storage, layout l: NVectorLayout = .default, count: Int) {
		let slice = NResolvedSlice(start: 0, count: count, step: 1)
		self.init(storage: mem, layout: l, slice: slice)
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
		get { return Vector(storage: storage, layout: layout, slice: s.resolve(within: slice)) }
		set { Vector(storage: storage, layout: layout, slice: s.resolve(within: slice)).set(from: newValue) }
	}
	
	typealias LinearStorageIterator = (start: Int, end: Int, stride: Int, count: Int)
	private static func _storageIterator(layout: NVectorLayout, slice: NResolvedSlice) -> LinearStorageIterator {
		let pos = slice.position(at: 0)
		let start = layout.location(for: pos)
		let stride = slice.rstep * layout.stride
		
		return (start, start + slice.rcount * stride, stride, slice.rcount)
	}
	private func _storageIterator() -> LinearStorageIterator {
		return Vector._storageIterator(layout: layout, slice: slice)
	}
	
	private func _storageLocation(index: Int) -> Int {
		let pos = slice.position(at: index)
		let loc = layout.location(for: pos)
		return loc
	}
	// Access one element
	public subscript(index: Int) -> Element {
		get { return storage[_storageLocation(index: index)] }
		set { storage[_storageLocation(index: index)] = newValue }
	}
	
	// MARK: - Storage Access -
	public typealias LinearStorageAccess = (base: UnsafeMutablePointer<Element>, stride: Int, count: Int)
	public func withStorageAccess<Result>(_ block: (_ access: LinearStorageAccess) throws -> Result) rethrows -> Result {
		let it = _storageIterator()
		
		return try storage.withUnsafeAccess { saccess in
			let access: LinearStorageAccess = (saccess.base + it.start, it.stride, it.count)
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
		
		from.storage.withUnsafeAccess { faccess in
			storage.withUnsafeAccess { taccess in
				
				let fit = Vector._storageIterator(layout: from.layout, slice: from.slice)
				let tit = Vector._storageIterator(layout: layout, slice: slice)
				
				var fi = fit.start
				var ti = tit.start
				
				for _ in 0..<slice.rcount {
					taccess.base[ti] = faccess.base[fi]
					
					fi += fit.stride
					ti += tit.stride
				}
			}
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
	public func isCompact(dimension: Int) -> Bool {
		assert(dimension == 0)
		return abs(layout.stride * slice.rstep) == 1
	}
}

