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

// Linear/Quadratic Storage Access implements this. It allows the traversal of non-linear spaces as a succession
// of linear segments. Useful for instance if you want to add 1.0 to each element of a matrix.
public protocol NDimensionalStorageAccess {
	associatedtype Element: NValue
	typealias Storage = NStorage<Element>
	
	var compact: Bool { get }
	// traverse storage as successive linear segments (typically rows in a matrix).
	// If coalesce is false, traverses contents in row-major order.
	// If coaleasce is true, don't make any assumption on the shape of data, as a 'compact' matrix might return a single segment with all rows.
	func linearized(coalesce: Bool) -> AnySequence<Storage.LinearAccess>
	//func linearized(coalesce: Bool, _ apply: (NStorage<Element>.LinearAccess) -> Void)
}

// Vector, Matrix types implement this
public protocol NStorageAccessible: NDimensionalType  {
	associatedtype Access: NDimensionalStorageAccess where Element == Access.Element
	
	
	func _withStorageAccess<Result>(_ block: (_ access: Access) throws -> Result) rethrows -> Result
	//func linearized() -> LazySequence
}

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
		// zero allowed (we need empty types)
		precondition(allocatedCount >= 0)
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
	
	public struct LinearAccess: NDimensionalStorageAccess {
		// base points to the first element within the slice (slice's start)
		public let base: UnsafeMutablePointer<Element>
		public let stride: Int
		public let count: Int
		// Note: LinearAccess's slice always starts at 0 (unlike Matrix's)
		public var slice: NResolvedSlice { return NResolvedSlice(start: 0, count: count, step: stride) }
		
		public var end: Int { return count * stride }
		public var last: Int { return (count-1) * stride }
		
		public var compact: Bool { return stride == 1 }
		public var indexes: StrideTo<Int> { return Swift.stride(from: 0, to: end, by: stride) }
		public var pointers: StrideTo<UnsafeMutablePointer<Element>> { return Swift.stride(from: base, to: base+end, by: stride) }
		
		internal init(base b: UnsafeMutablePointer<Element>, stride s: Int, count c: Int) {
			base = b
			stride = s
			count = c
		}
		
		public func linearized(coalesce: Bool) -> AnySequence<LinearAccess> {
			return AnySequence(CollectionOfOne(self))
		}
	}
	
	// non-final API (thinking)
	public struct QuadraticAccess: NDimensionalStorageAccess {
		// points to the first element within the slice (slice's start)
		public let base: UnsafeMutablePointer<Element>
		
		// navigate relatively to the first element.
		public let stride: (row: Int, column: Int)
		public let count: (row: Int, column: Int)
		// Note: QuadraticAccess's slice always starts at 0 (unlike Matrix's)
		public var slice: NResolvedQuadraticSlice { return NResolvedQuadraticSlice(row: NResolvedSlice(start: 0, count: count.row, step: stride.row), column: NResolvedSlice(start: 0, count: count.column, step: stride.column)) }
		
		public var compact: Bool { return stride.column == 1 && stride.row == count.column }
		// points to the first element of row or columns
		public func base(row: Int) -> UnsafeMutablePointer<Element> { return base + row * stride.row }
		public func base(column: Int) -> UnsafeMutablePointer<Element> { return base + column * stride.column }
//		public var pointers: AnySequence<UnsafeMutablePointer<>>
		
		// Linear access for rows and columns (instead of specific API)
		public func row(_ at: Int) -> LinearAccess { return LinearAccess(base: base(row: at), stride: stride.column, count: count.column) }
		public func column(_ at: Int) -> LinearAccess { return LinearAccess(base: base(column: at), stride: stride.row, count: count.row) }
		
		public func linearized(coalesce: Bool) -> AnySequence<LinearAccess> {
			if compact && coalesce {
				let lin = LinearAccess(base: base, stride: 1, count: count.column * count.row)
				return AnySequence(CollectionOfOne(lin))
			} else {
				let lins = (0..<count.row).lazy.map { self.row($0) }
				return AnySequence(lins)
			}
		}
		
		internal init(base b: UnsafeMutablePointer<Element>, stride s: (row: Int, column: Int), count c: (row: Int, column: Int)) {
			base = b
			stride = s
			count = c
		}
	}
}

public extension Numerics {
	// MARK: - Storage Access
	public static func withStorageAccess<T: NStorageAccessible, Result>(_ a: T, _ access: (T.Access) throws -> Result) rethrows -> Result where T.Element == Element {
		return try a._withStorageAccess { acc in
			return try access(acc)
		}
	}
	public static func withStorageAccess<T: NStorageAccessible, Result>(_ a: T, _ b: T, _ access: (_ aa: T.Access, _ ba: T.Access) throws -> Result) rethrows -> Result where T.Element == Element {
		return try a._withStorageAccess { acc in
			return try b._withStorageAccess { bacc in
				return try access(acc, bacc)
			}
		}
	}
	public static func withStorageAccess<T: NStorageAccessible, Result>(_ a: T, _ b: T, _ c: T, _ access: (_ aa: T.Access, _ ba: T.Access, _ ca: T.Access) throws -> Result) rethrows -> Result where T.Element == Element {
		return try a._withStorageAccess { aacc in
			return try b._withStorageAccess { bacc in
				return try c._withStorageAccess { cacc in
					return try access(aacc, bacc, cacc)
				}
			}
		}
	}
	
	// Any dimensional type is converted into sequences of linear accesses (with possible coalescing, ie, all rows as a single linear space, if container is compact)
	// Makes sense for Accelerate processing
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ access: (Storage.LinearAccess) -> Void) where T.Element == Element {
		a._withStorageAccess { aacc in
			for alin in aacc.linearized(coalesce: true) {
				access(alin)
			}
		}
	}
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ b: T, _ access: (Storage.LinearAccess, Storage.LinearAccess) -> Void) where T.Element == Element {
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				let coalesce = aacc.compact && bacc.compact
				for (alin, blin) in zip(aacc.linearized(coalesce: coalesce), bacc.linearized(coalesce: coalesce)) {
					access(alin, blin)
				}
			}
		}
	}
	// MARK: - Storage/Value Stride
	internal static func withAddresses<T: NStorageAccessible>(_ a: T, _ block: (_ pointer: UnsafeMutablePointer<Element>) -> Void) where T.Element == Element {
		a._withStorageAccess { aacc in
			// single arg -> we can always (try to) coalesce
			for alin in aacc.linearized(coalesce: true) {
				for p in alin.pointers {
					block(p)
				}
			}
		}
	}
	public static func withValues<T: NStorageAccessible>(_ a: T, _ block: (_ value: Element) -> Void) where T.Element == Element { return withAddresses(a) { block($0.pointee) } }
	
	public static func withAddresses<T: NStorageAccessible>(_ a: T, _ b: T, _ block: (_ pa: UnsafeMutablePointer<Element>, _ pb: UnsafeMutablePointer<Element>) -> Void) where T.Element == Element {
		precondition(a.shape == b.shape)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				// 2 arg -> (try to) coalesce only if both are compact
				let coalesce = aacc.compact && bacc.compact
				for (alin, blin) in zip(aacc.linearized(coalesce: coalesce), bacc.linearized(coalesce: coalesce)) {
					for (pa, pb) in zip(alin.pointers, blin.pointers) {
						block(pa, pb)
					}
				}
			}
		}
	}
	public static func withValues<T: NStorageAccessible>(_ a: T, _ b: T, _ block: (_ pa: Element, _ pb: Element)->Void) where T.Element == Element { return withAddresses(a, b) { block($0.pointee, $1.pointee) } }
	
	public static func withAddresses<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ block: (_ pa: UnsafeMutablePointer<Element>, _ pb: UnsafeMutablePointer<Element>, _ pc: UnsafeMutablePointer<Element>) -> Void) where T.Element == Element {
		precondition(a.shape == b.shape && b.shape == c.shape)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				c._withStorageAccess { cacc in
					// 2 arg -> (try to) coalesce only if both are compact
					let coalesce = aacc.compact && bacc.compact && cacc.compact
					for (alin, (blin, clin)) in zip(aacc.linearized(coalesce: coalesce), zip(bacc.linearized(coalesce: coalesce), cacc.linearized(coalesce: coalesce))) {
						for (pa, (pb, pc)) in zip(alin.pointers, zip(blin.pointers, clin.pointers)) {
							block(pa, pb, pc)
						}
					}
				}
			}
		}
	}
	public static func withValues<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ block: (_ pa: Element, _ pb: Element, _ pc: Element)->Void) where T.Element == Element { return withAddresses(a, b, c) { block($0.pointee, $1.pointee, $2.pointee) } }
}
