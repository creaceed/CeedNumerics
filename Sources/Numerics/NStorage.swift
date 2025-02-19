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
	associatedtype Slice: NDimensionalResolvedSlice
	associatedtype StorageIndexSequence: Sequence where StorageIndexSequence.Element == Int
	typealias Storage = NStorage<Element>
	
	var compact: Bool { get }
	var coalescable: Bool { get }
	var base: UnsafeMutablePointer<Element> { get }// pointer to the first
	var slice: Slice { get }
	var indexes: StorageIndexSequence { get } // to traverse storage by indexing
	
	// we could have generic layout capability
//	var genericStrides: [Int]
//	var genericCounts: [Int]
	var compactBuffer: UnsafeMutableBufferPointer<Element>?  { get } // only avail if compact
	
	// traverse storage as successive linear segments (typically rows in a matrix).
	// If coalesce is false, traverses contents in row-major order.
	// If coaleasce is true, don't make any assumption on the shape of data: a coalesceable matrix will typically return a single segment with all rows, while a non-coalesceable matrix will return multiple segments.
	func linearized(coalesce: Bool) -> AnySequence<Storage.LinearAccess>
	//func linearized(coalesce: Bool, _ apply: (NStorage<Element>.LinearAccess) -> Void)
}

// Vector, Matrix types implement this
public protocol NStorageAccessible  {
	associatedtype Element
	associatedtype NativeIndex: NDimensionalIndex
	associatedtype Access: NDimensionalStorageAccess where Element == Access.Element
	
	var size: NativeIndex { get }
	
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
	private let allocated: Bool
	private let owner: AnyObject?
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
		allocated = true
		owner = nil
	}
	
	deinit {
		if allocated {
			pointer.deallocate()
		}
	}
	// owner is used as keep-alive for memory.
	public init(existingPointer: UnsafeMutablePointer<Element>, owner ow: AnyObject?, count c: Int) {
		count = c
		pointer = existingPointer
		allocated = false
		owner = ow
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

extension NStorage {
	
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
		public var coalescable: Bool { return true }
		public var compactBuffer: UnsafeMutableBufferPointer<Element>? {
			guard compact else { return nil }
			return UnsafeMutableBufferPointer(start: base, count: count)
		}
		
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
		
		// stride: storage distance (elements) between elements in successive row/column
		public let stride: (row: Int, column: Int)
		// count: number of rows / columns
		public let count: (row: Int, column: Int)
		// Note: QuadraticAccess's slice always starts at 0 (unlike Matrix's)
		public var slice: NResolvedQuadraticSlice { return NResolvedQuadraticSlice(row: NResolvedSlice(start: 0, count: count.row, step: stride.row), column: NResolvedSlice(start: 0, count: count.column, step: stride.column)) }
		
		public var indexes: NResolvedQuadraticSlice { return slice }
		
		// shortcut for APIs that need this
		public var rowBytes: Int { return stride.row * MemoryLayout<Element>.stride }
		
		public var compact: Bool { return slice.compact }
		public var coalescable: Bool { return slice.coalesceable }
		public var compactBuffer: UnsafeMutableBufferPointer<Element>? {
			guard compact else { return nil }
			return UnsafeMutableBufferPointer(start: base, count: count.row * count.column)
		}
		
		// points to the first element of row or columns
		public func base(row: Int) -> UnsafeMutablePointer<Element> { return base + row * stride.row }
		public func base(column: Int) -> UnsafeMutablePointer<Element> { return base + column * stride.column }
//		public var pointers: AnySequence<UnsafeMutablePointer<>>
		
		// Linear access for rows and columns (instead of specific API)
		public func row(_ at: Int) -> LinearAccess { return LinearAccess(base: base(row: at), stride: stride.column, count: count.column) }
		public func column(_ at: Int) -> LinearAccess { return LinearAccess(base: base(column: at), stride: stride.row, count: count.row) }
		public var rows: LazyMapCollection<Range<Int>, LinearAccess> { return (0..<count.row).lazy.map { self.row($0) } }
		public var columns: LazyMapCollection<Range<Int>, LinearAccess> { return (0..<count.column).lazy.map { self.column($0) } }
		
		
		
		public func linearized(coalesce: Bool) -> AnySequence<LinearAccess> {
			if coalescable && coalesce {
				let lin = LinearAccess(base: base, stride: stride.column, count: count.column * count.row)
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
	public struct GenericAccess: NDimensionalStorageAccess {
		// points to the first element within the slice (slice's start)
		public let base: UnsafeMutablePointer<Element>
		
		// navigate relatively to the first element.
		
		// stride: storage distance (elements) between elements in successive dimensions
		public let stride: [Int]
		// count: number of elements in each dimensions
		public let count: [Int]
		// Note: GenericAccess's slice always starts at 0 (unlike Tensor's)
		public var slice: NResolvedGenericSlice {
			let slices = zip(count, stride).map { NResolvedSlice(start: 0, count: $0.0, step: $0.1) }
			return NResolvedGenericSlice(slices)
		}
		public var indexes: NResolvedGenericSlice { return slice }
		
		public var compact: Bool { return slice.compact }
		public var coalescable: Bool { return slice.coalesceable }
		public var compactBuffer: UnsafeMutableBufferPointer<Element>? {
			guard compact else { return nil }
			return UnsafeMutableBufferPointer(start: base, count: count.reduce(1, *))
		}
		
		public func linearized(coalesce: Bool) -> AnySequence<LinearAccess> {
			if coalescable && coalesce {
				let lin = LinearAccess(base: base, stride: stride.last!, count: count.reduce(1) { $0*$1 })
				return AnySequence(CollectionOfOne(lin))
			} else {
				let higherdims = Array(count.prefix(upTo: count.count-1))
				let higherstrides = Array(stride.prefix(upTo: count.count-1))
				let range = NGenericRange(counts: higherdims)
				
				let lins = range.lazy.map { (higherindex: NGenericIndex)->LinearAccess in
					let baseoffset = zip(higherindex, higherstrides).reduce(0) { $0 + $1.0*$1.1 }
					return LinearAccess(base: self.base+baseoffset, stride: self.stride.last!, count: self.count.last!)
				}
				
				return AnySequence(lins)
			}
		}
		
		internal init(base b: UnsafeMutablePointer<Element>, stride s: [Int], count c: [Int]) {
			precondition(s.count == c.count)
			precondition(s.count > 0)
			
			base = b
			stride = s
			count = c
		}
	}
}

extension Numerics {
	// MARK: - Storage Access
	public static func withStorageAccess<T: NStorageAccessible, Result>(_ a: T, _ access: (T.Access) throws -> Result) rethrows -> Result where T.Element == Element {
		return try a._withStorageAccess { acc in
			return try access(acc)
		}
	}
	public static func withStorageAccess<T: NStorageAccessible, T2: NStorageAccessible, Result>(_ a: T, _ b: T2, _ access: (_ aa: T.Access, _ ba: T2.Access) throws -> Result) rethrows -> Result where T.Element == Element {
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
		precondition(a.size == b.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				let coalesce = aacc.compact && bacc.compact
				for (alin, blin) in zip(aacc.linearized(coalesce: coalesce), bacc.linearized(coalesce: coalesce)) {
					access(alin, blin)
				}
			}
		}
	}
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ access: (Storage.LinearAccess, Storage.LinearAccess, Storage.LinearAccess) -> Void) where T.Element == Element {
		precondition(a.size == b.size && a.size == c.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				c._withStorageAccess { cacc in
					let coalesce = aacc.compact && bacc.compact && cacc.compact
					for (alin, (blin, clin)) in zip(aacc.linearized(coalesce: coalesce), zip(bacc.linearized(coalesce: coalesce), cacc.linearized(coalesce: coalesce))) {
						access(alin, blin, clin)
					}
				}
			}
		}
	}
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ d: T, _ access: (Storage.LinearAccess, Storage.LinearAccess, Storage.LinearAccess, Storage.LinearAccess) -> Void) where T.Element == Element {
		precondition(a.size == b.size && a.size == c.size && a.size == d.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				c._withStorageAccess { cacc in
					d._withStorageAccess { dacc in
						let coalesce = aacc.compact && bacc.compact && cacc.compact && dacc.compact
						for (alin, (blin, (clin, dlin))) in zip(aacc.linearized(coalesce: coalesce), zip(bacc.linearized(coalesce: coalesce), zip(cacc.linearized(coalesce: coalesce), dacc.linearized(coalesce: coalesce)))) {
							access(alin, blin, clin, dlin)
						}
					}
				}
			}
		}
	}
	// MARK: - Storage/Value Stride
	
	
	// TODO: see direct approach + try access block. Can also try joint1x, joint2x, jointNx implementation (protocol), to avoid multi-iterator termination test overhead (same shape).
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
		precondition(a.size == b.size)
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
		precondition(a.size == b.size && b.size == c.size)
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
