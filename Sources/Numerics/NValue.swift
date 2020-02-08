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

// MARK: - Number Types
// using BinaryFloatingPoint instead of FloatingPoint, which provides broader built-in capabilities.
public protocol NFloatingPoint: BinaryFloatingPoint, CustomStringConvertible where Self.RawSignificand : FixedWidthInteger {
	
}

// note: we may sometimes need this "where Self.RawSignificand : FixedWidthInteger"
extension NFloatingPoint {
	public var roundedIntValue: Int {
		return Int(self.rounded())
	}
	public var doubleValue: Double {
		return Double(self)
	}
	public var floatValue: Float {
		return Float(self)
	}
}

// int or floats
public protocol NAdditiveNumeric: SignedNumeric {
	static var zero: Self { get }
	static var one: Self { get }
}


// MARK: - NValue
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

// We provide a single implementation for Float and Double (possibly more)
extension NFloatingPoint /*where Self.RawSignificand : FixedWidthInteger*/ {
	public var descriptionValueString : String { return String(format: "%6.3f", self.doubleValue) }
	public static var none: Self { return 0.0 }
	public static var one: Self { return 1.0 }
	public static func random<G: RandomNumberGenerator>(min: Self, max: Self, using generator: inout G) -> Self {
		return Self.random(in: min...max, using: &generator)
	}
}

extension Double: NValue, NAdditiveNumeric {}
extension Float: NValue, NAdditiveNumeric {}

extension Int: NValue, NAdditiveNumeric {
	public var descriptionValueString : String { return String(format: "%6d", self) }
	public static var none: Int { return 0 }
	public static var one: Int { return 1 }
	public static func random<G: RandomNumberGenerator>(min: Int, max: Int, using generator: inout G) -> Int {
		return Int.random(in: min...max, using: &generator)
	}
}
extension UInt16: NValue, NAdditiveNumeric {
	public var descriptionValueString : String { return String(format: "%6d", self) }
	public static var none: Self { return 0 }
	public static var one: Self { return 1 }
	public static func random<G: RandomNumberGenerator>(min: Self, max: Self, using generator: inout G) -> Self {
		return Self.random(in: min...max, using: &generator)
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

// Float16 can't be directly accessed, and they are modeled as UInt16 (CPU-side)
public typealias NOpaqueFloat16 = UInt16
