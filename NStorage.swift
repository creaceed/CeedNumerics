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
public class NStorage<Element: NValue> {
	private let pointer: UnsafeMutablePointer<Element>
	public let count: Int
	
	public var rawData: Data {
		return Data(bytes: UnsafeRawPointer(pointer), count: count * MemoryLayout<Element>.stride)
	}
	
	public struct Access {
		public var base: UnsafeMutablePointer<Element>
		public var count: Int
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
	
	public func withUnsafeAccess<Result>(_ block: (Access) throws -> Result) rethrows -> Result {
		let access = Access(base: pointer, count: count)
		return try block(access)
	}
}

public extension NStorage {
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

