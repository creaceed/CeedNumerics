//
//  CeedNumerics
//
//  Created by Raphael Sebbe on 18/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

public protocol NDimensionalType: CustomStringConvertible {
	associatedtype Element: NValue
	var dimension: Int { get }
	var shape: [Int] { get } // size is dimension
	
	// we don't define as vararg arrays, we let that up to the actual type to opt-out from array use (performance).
	subscript(index: [Int]) -> Element { get set }
	
	// No gap between elements (useful for enabling Accelerate methods that have that requirement).
	// For a tensor of dimension 3:
	//		non compact dimension i implies that dimensions i+n are non compact as well.
	func isCompact(dimension: Int) -> Bool
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
//			var description = ""
//			let it = DimensionalIterator(shape: shape)
//			while let index = it.next() {
//				var comma: Bool = (index.last! != shape.last! - 1)
//				if index.last! == 0 {
//					for (_, ind) in index.enumerated() {
//						if ind == 0 { description += "[" }
//						else { description += " " }
//					}
//					comma = false
//				}
//
//				let value = self[index]
////				if index.last! == 0 {
////					var higherDimIndex = index
////					higherDimIndex.removeLast()
////					let indexString = higherDimIndex.map { "\($0)" }.joined(separator: ":") + ":x"
////					description += " \(indexString) - "
////				}
//				description += "\(value.logString)\(comma ? "," : "") "
//				if index.last! == shape.last!-1 {
//					for (idim, ind) in index.reversed().enumerated() {
//						let dim = dimension-1 - idim
//						if ind == shape[dim] - 1 { description += "]" }
//						else { description += " " }
//					}
//					description += "\n"
//					if index.count > 2 && index[index.count-2] == shape[index.count-2] - 1 {
//						description += "\n"
//					}
//				}
//			}
//			return description
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
