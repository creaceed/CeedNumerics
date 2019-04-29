//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 18/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

public protocol NDimensionalType: CustomStringConvertible {
	associatedtype Element: NValue
	associatedtype NativeIndex
	associatedtype NativeIndexRange: Sequence where NativeIndexRange.Element == NativeIndex
	var dimension: Int { get }
	var shape: [Int] { get } // size is dimension
	
	// we don't define as vararg arrays, we let that up to the actual type to opt-out from array use (performance).
	subscript(index: [Int]) -> Element { get set }
	subscript(index: NativeIndex) -> Element { get set }
	var indices: NativeIndexRange { get }
}

extension NDimensionalType {
	private func recursiveDescription(index: [Int]) -> String {
		var description = ""
		let dimi = index.count
		var first: Bool = false, last = false
		
		if index.count > 0 {
			first = (index.last! == 0)
			last = (index.last! == shape[index.count-1]-1)
			
		}
		
		if index.count > 0 {
			if first { description += "[" }
			if !first { description += " " }
		}
		
		if dimi == shape.count {
			description += "\(self[index])"
		} else {
			for i in 0..<shape[dimi] {
				description += recursiveDescription(index: index + [i])
			}
		}
		
		if index.count > 0 {
			if !last { description += "," }
			if !last && dimi == shape.count - 1 { description += "\n" }
			if last { description += "]" }
		}
		
		return description
	}
	
	public var description: String {
		get {
			let shapeDescr = shape.map {"\($0)"}.joined(separator: "×")
			return "(\(shapeDescr))" + recursiveDescription(index: [])
		}
	}
}


public class DimensionalIterator: IteratorProtocol {
	private var shape: [Int]
	private var presentIndex: [Int]
	private var first = true
	private var dimension: Int { return shape.count }
	
	public init(shape: [Int]) {
		assert(shape.count > 0)
		assert(shape.allSatisfy { $0 > 0 })
		
		self.shape = shape
		self.presentIndex = [Int](repeating: 0, count: shape.count)
	}
	
	public func next() -> [Int]? {
		if presentIndex.isEmpty {
			return nil
		}
		if first {
			first = false
			return presentIndex
		}
		if !_incrementIndex(presentIndex.count - 1) {
			return nil
		}
		return presentIndex
	}
	
	private func _incrementIndex(_ dim: Int) -> Bool {
		if dim < 0 || dimension <= dim {
			return false
		}
		
		if presentIndex[dim] < shape[dim] - 1 {
			presentIndex[dim] += 1
		} else {
			if !_incrementIndex(dim - 1) {
				return false
			}
			presentIndex[dim] = 0
		}
		
		return true
	}
}

extension NDimensionalType {
	public mutating func randomize(min: Element, max: Element, seed: Int = 0) {
		var generator = NSeededRandomNumberGenerator(seed: seed)
		for index in self.indices {
			self[index] = Element.random(min: min, max: max, using: &generator)
		}
	}
}
