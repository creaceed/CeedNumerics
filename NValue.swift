//
//  File.swift
//  CeedBase
//
//  Created by Raphael Sebbe on 18/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation

// Using a struct as namespace for global methods. We could have specific methods under their type, ie:
// NVector.convolve(v1, v2)
// But there are 2 problems with that approach:
// - some methods operate on multiple types (matric vector product)
// - there are multiple entry points, which makes it hard to guess when typing code (have to type NMatrix. then not
// seeing the right method, do it again with NVector.)
//
// Having all global (static) methods under a single moniker makes it easier.
//
// Note 1: that the ones deriving new values (ie: v1.convolving(v2)) are instance method on their respective type.
// Note 2: that namespace struct can be typealiased (just like with numpy: Numerics.convolve() -> nu.convolve() )
public struct Numerics<Element: NValue> {
	public typealias Storage = NStorage<Element>
	public typealias Vector = NVector<Element>
	public typealias Matrix = NMatrix<Element>
}

// Shorter form
public typealias num = Numerics

// Base value type for dimensional types (vector, matrix). Note that the goal is that these include Bool, Int.
// Not just floating point types, even though that FP types get many additional features (signal processing related, accelerate, etc).
public protocol NValue {
	var descriptionValueString: String { get }
	static var none: Self { get }
	// using min/max syntax so that we can use same syntax with Bool
	static func random<G: RandomNumberGenerator>(min: Self, max: Self, using generator: inout G) -> Self
}

extension NValue {
	static func random(min: Self, max: Self) -> Self {
		var gen = SystemRandomNumberGenerator()
		return random(min: min, max: max, using: &gen)
	}
}

extension Double: NValue {
	public var descriptionValueString : String { return String(format: "%6.3f", self) }
	public static var none: Double { return 0.0 }
	public static func random<G: RandomNumberGenerator>(min: Double, max: Double, using generator: inout G) -> Double {
		return Double.random(in: min...max, using: &generator)
	}
}
extension Float: NValue {
	public var descriptionValueString : String { return String(format: "%6.3f", self) }
	public static var none: Float { return 0.0 }
	public static func random<G: RandomNumberGenerator>(min: Float, max: Float, using generator: inout G) -> Float {
		return Float.random(in: min...max, using: &generator)
	}
}
extension Int: NValue {
	public var descriptionValueString : String { return String(format: "%6d", self) }
	public static var none: Int { return 0 }
	public static func random<G: RandomNumberGenerator>(min: Int, max: Int, using generator: inout G) -> Int {
		return Int.random(in: min...max, using: &generator)
	}
}
extension Bool: NValue {
	public var descriptionValueString: String { return "\(self)" }
	public static var none: Bool { return false }
	public static func random<G: RandomNumberGenerator>(min: Bool, max: Bool, using generator: inout G) -> Bool {
		if min == max { return min }
		return Bool.random(using: &generator)
	}
}
