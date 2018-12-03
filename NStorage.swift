//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 17/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

/*public protocol NStorage {
	associatedtype Element
	subscript(index: Int) -> Element { get }
	var count: Int { get }
}

public protocol NMutableStorage: NStorage {
	subscript(index: Int) -> Element { get set }
}
*/


// The goal of NStorage is to be the base type for all memory allocations of other types.
// We want to enable external (even ephemeral) memory access. To enable interaction with
// memory allocated elsewhere (Metal textures backing for instance, etc.)
//
// Tried to use protocol, but we still need a concrete type to declare (class) array/matrix/tensor
// So, using class.
//
// The most important limitation of NStorage memory model is that it is only accessed through integral
// multiple of the size of Element. No packed storage, or non-integral row stride (Matrix).
// Coping with such mamory layout is technically possible, but would make the code more complex, and possibly
// less efficient (packing/unpacking abstractions).
//
public class NStorage<Element: NValue> {
	private let pointer: UnsafeMutablePointer<Element>
	public let count: Int
	
	public var rawData: Data {
		return Data(bytes: UnsafeRawPointer(pointer), count: count * MemoryLayout<Element>.stride)
	}
	
	public init(allocatedCount: Int, value: Element = .none) {
		precondition(allocatedCount > 0)
		pointer = UnsafeMutablePointer.allocate(capacity: allocatedCount)
		pointer.initialize(repeating: value, count: allocatedCount)
		count = allocatedCount
	}
	
	deinit {
		pointer.deallocate()
	}
	public init(externalReference: UnsafeMutablePointer<Element>, count c: Int) {
		count = c
		pointer = externalReference
	}
	
	public subscript(index: Int) -> Element {
		get {
			return withUnsafeAccess { return $0.base[index] }
		}
		set {
			withUnsafeAccess { $0.base[index] = newValue }
		}
	}
	
	public func withUnsafeAccess<Result>(_ block: (RawAccess) throws -> Result) rethrows -> Result {
		let access = RawAccess(base: pointer, count: count)
		return try block(access)
	}
}

public extension NStorage {
	
	// MARK: - Storage Access -
	public struct RawAccess {
		public let base: UnsafeMutablePointer<Element>
		public let count: Int
	}
	
	public struct LinearAccess {
		// base points to the first element within the slice (slice's start)
		public let base: UnsafeMutablePointer<Element>
		public let stride: Int
		public let count: Int
		
		public var end: Int { return count * stride }
		public var last: Int { return (count-1) * stride }
		
		public var compact: Bool { return stride == 1 }
		public var indexes: StrideTo<Int> { return Swift.stride(from: 0, to: end, by: stride) }
		public var pointers: StrideTo<UnsafeMutablePointer<Element>> { return Swift.stride(from: base, to: base+end, by: stride) }
		
		public init(base b: UnsafeMutablePointer<Element>, step s: Int, count c: Int) {
			base = b
			stride = s
			count = c
		}
	}
	
	// non-final API (thinking)
	public struct QuadraticAccess {
		// points to the first element within the slice (slice's start)
		public let base: UnsafeMutablePointer<Element>
		
		// navigate relatively to the first element.
		public let step: (row: Int, column: Int)
		public let count: (row: Int, column: Int)
		
		// points to the first element of row or columns
		public func base(row: Int) -> UnsafeMutablePointer<Element> { return base + row * step.row }
		public func base(column: Int) -> UnsafeMutablePointer<Element> { return base + column * step.column }
		
		// relative to base
		public func stride(row: Int) -> StrideTo<Int> { return Swift.stride(from: row * step.row, to: row * step.row + step.column * count.column, by: step.column) }
		public func stride(column: Int) -> StrideTo<Int> { return Swift.stride(from: column * step.column, to: column * step.column + step.row * count.row, by: step.row) }
		
		public func test() {
			
			
			
		}
		//		let slices: (row: NResolvedSlice, column: NResolvedSlice)
		//		func base(row: Int) -> UnsafeMutablePointer<Element> { return base }
		//		func base(column: Int) -> UnsafeMutablePointer<Element> { return base }
		//		func row(_ row: Int) -> LinearStorageAccess2 { return LinearStorageAccess2(base: base, slice: slices.row)}
	}
	
	
	
	public struct QuadraticIterator: IteratorProtocol {
		public typealias Element = Int
		private let layout: NMatrixLayout
		private let slices: (rows: NResolvedSlice, columns: NResolvedSlice)
		
		// internal state
		private var index: (row: Int, column: Int)
		private var done: Bool = false
		
		public init(layout l: NMatrixLayout, slices s: (rows: NResolvedSlice, columns: NResolvedSlice)) {
			layout = l
			slices = s
			index = (0,0)
			done = (slices.rows.rcount == 0 && slices.columns.rcount == 0)
		}
		
		public mutating func next() -> Int? {
			guard !done else { return nil }
			
			// TODO: perf-wise, could do it only with 2 additions.
			let loc = layout.location(row: slices.0.position(at: index.0), column: slices.1.position(at: index.1))
			index.0 += 1
			if index.0 == slices.rows.rcount {
				index.0 = 0
				index.1 += 1
				if index.1 == slices.columns.rcount {
					done = true
				}
			}
			
			return loc
		}
	}
}

public extension Numerics {
	// MARK: - Storage Access
	public static func withStorageAccess<Result>(_ a: Vector, _ access: (Storage.LinearAccess) throws -> Result) rethrows -> Result {
		return try a._withStorageAccess { acc in
			return try access(acc)
		}
	}
	public static func withStorageAccess<Result>(_ a: Vector, _ b: Vector, _ access: (_ aa: Storage.LinearAccess, _ ba: Storage.LinearAccess) throws -> Result) rethrows -> Result {
		return try a._withStorageAccess { acc in
			return try b._withStorageAccess { bacc in
				return try access(acc, bacc)
			}
		}
	}
	public static func withStorageAccess<Result>(_ a: Vector, _ b: Vector, _ c: Vector, _ access: (_ aa: Storage.LinearAccess, _ ba: Storage.LinearAccess, _ ca: Storage.LinearAccess) throws -> Result) rethrows -> Result {
		return try a._withStorageAccess { aacc in
			return try b._withStorageAccess { bacc in
				return try c._withStorageAccess { cacc in
					return try access(aacc, bacc, cacc)
				}
			}
		}
	}
	// MARK: - Storage/Value Stride
	
	public static func withStorageStride(_ a: Vector, _ block: (_ pointer: UnsafeMutablePointer<Element>) -> Void) {
		a._withStorageAccess { access in
			for p in access.pointers {
				block(p)
			}
		}
	}
	public static func withValueStride(_ a: Vector, _ block: (_ value: Element) -> Void) { return withStorageStride(a) { block($0.pointee) } }
	public static func withStorageStride(_ a: Vector, _ b: Vector, _ block: (_ pa: UnsafeMutablePointer<Element>, _ pb: UnsafeMutablePointer<Element>) -> Void) {
		precondition(a.size == b.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				for (pa, pb) in zip(aacc.pointers, bacc.pointers) {
					block(pa, pb)
				}
			}
		}
	}
	public static func withValueStride(_ a: Vector, _ b: Vector, _ block: (_ pa: Element, _ pb: Element)->Void) { return withStorageStride(a, b) { block($0.pointee, $1.pointee) } }
	public static func withStorageStride(_ a: Vector, _ b: Vector, _ c: Vector, _ block: (_ pa: UnsafeMutablePointer<Element>, _ pb: UnsafeMutablePointer<Element>, _ pc: UnsafeMutablePointer<Element>) -> Void) {
		precondition(a.size == b.size && b.size == c.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				c._withStorageAccess { cacc in
					for (pa, (pb, pc)) in zip(aacc.pointers, zip(bacc.pointers, cacc.pointers)) {
						block(pa, pb, pc)
					}
				}
			}
		}
	}
}
