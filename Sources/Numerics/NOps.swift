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
import Accelerate

// Padding
public enum PaddingMode {
	case edge
	// case zero
	// case mirror
}

/// Convolution
public enum ConvolutionDomain {
	case same // M
	case valid // M-K+1
	// case full // M+K-1
}

// MARK: - Generic Dimensional Type Ops
// (apply to Vector, Matrix, Tensor)
// Typically element-wise operations that can be implemented in terms to linearized access (any dimensions).
extension Numerics where Element: NAccelerateFloatingPoint {
	public static func subtract<DT: NDimensionalArray>(_ a: DT, _ b: DT, _ result: DT) where DT.Element == Element {
		precondition(a.size == b.size && a.size == result.size)
		
		withLinearizedAccesses(a, b, result) { aacc, bacc, racc in
			Element.mx_vsub(aacc.base, numericCast(aacc.stride), bacc.base, numericCast(bacc.stride), racc.base, numericCast(racc.stride), numericCast(racc.count))
		}
	}
	public static func add<DT: NDimensionalArray>(_ a: DT, _ b: DT, _ result: DT) where DT.Element == Element {
		precondition(a.shape == b.shape && a.shape == result.shape)
		withLinearizedAccesses(a, b, result) { aacc, bacc, racc in
			Element.mx_vadd(aacc.base, numericCast(aacc.stride), bacc.base, numericCast(bacc.stride), racc.base, numericCast(racc.stride), numericCast(racc.count))
		}
	}
	public static func add<DT: NDimensionalArray>(_ a: DT, _ b: DT.Element, _ result: DT) where DT.Element == Element {
		precondition(a.shape == result.shape)
		withLinearizedAccesses(a, result) { aacc, racc in
			Element.mx_vsadd(aacc.base, numericCast(aacc.stride), b, racc.base, numericCast(racc.stride), numericCast(racc.count))
		}
	}
	public static func multiplyElements<DT: NDimensionalArray>(_ a: DT, _ b: DT, _ result: DT) where DT.Element == Element {
		precondition(a.size == b.size && b.size == result.size)
		
		withLinearizedAccesses(a, b, result) { aacc, bacc, racc in
			Element.mx_vmul(aacc.base, numericCast(aacc.stride), bacc.base, numericCast(bacc.stride), racc.base, numericCast(racc.stride), numericCast(racc.count))
		}
	}
	public static func multiply<DT: NDimensionalArray>(_ a: Element, _ b: DT, _ result: DT) where DT.Element == Element {
		precondition(b.shape == result.shape)
		withLinearizedAccesses(b, result) { bacc, racc in
			Element.mx_vsmul(bacc.base, numericCast(bacc.stride), a, racc.base, numericCast(racc.stride), numericCast(racc.count))
		}
	}
	// Obvious swap
	public static func multiply<DT: NDimensionalArray>(_ a: DT, _ b: Element, _ result: DT) where DT.Element == Element { multiply(b, a, result) }
	
	public static func divideElements<DT: NDimensionalArray>(_ a: DT, _ b: DT, _ result: DT) where DT.Element == Element {
		precondition(a.shape == b.shape && a.shape == result.shape)
		withLinearizedAccesses(a, b, result) { aacc, bacc, racc in
			Element.mx_vdiv(aacc.base, numericCast(aacc.stride), bacc.base, numericCast(bacc.stride), racc.base, numericCast(racc.stride), numericCast(racc.count))
		}
//		withStorageAccess(a) { aacc in
//			withStorageAccess(b) { bacc in
//				withStorageAccess(result) { racc in
//					if aacc.compact && bacc.compact && racc.compact {
//						Element.mx_vdiv(aacc.base, 1, bacc.base, 1, racc.base, 1, numericCast(a.rows * a.columns))
//						//						print("\(aacc.base)")
//					} else {
//						fatalError("not implemented")
//					}
//				}
//			}
//		}
	}
	public static func divideElements<DT: NDimensionalArray>(_ a: DT, _ b: DT) -> DT where DT.Element == Element { return a._deriving { divideElements(a, b, $0) } }
	
	// a * as + b * bs
	public static func scaledAdd<DT: NDimensionalArray>(_ a: DT, _ asp: Element, _ b: DT, _ bs: Element, _ output: DT) where DT.Element == Element {
		precondition(a.size == b.size && a.size == output.size)
		
		withLinearizedAccesses(a, b, output) { aacc, bacc, oacc in
			// TODO: check negative stride is supported for input/output (doc only mentions kernel)
			Element.mx_vsmsma(aacc.base, numericCast(aacc.stride), asp, bacc.base, numericCast(bacc.stride), bs, oacc.base, numericCast(oacc.stride), numericCast(aacc.count))
		}
	}
	
	public static func lerp<DT: NDimensionalArray>(_ a: DT, _ b: DT, _ t: Element, _ result: DT) where DT.Element == Element {
		return scaledAdd(a, 1.0-t, b, t, result)
	}
	public static func lerp<DT: NDimensionalArray>(_ a: DT, _ b: DT, _ t: Element) -> DT where DT.Element == Element { return a._deriving { scaledAdd(a, 1.0-t, b, t, $0) } }
	
	public static func mean<DT: NDimensionalArray>(_ a: DT) -> DT.Element where DT.Element == Element {
		var mean: Element = 0.0
		var c = 0
		withLinearizedAccesses(a) { alin in
			// possibly invoked multiple types
			var lm: Element = 0.0
			Element.mx_meanv(alin.base, numericCast(alin.stride), C: &lm, numericCast(alin.count))
			mean += lm
			c += 1
		}
		return mean / Element(max(1,c))
	}
	public static func meanSquare<DT: NDimensionalArray>(_ a: DT) -> DT.Element where DT.Element == Element {
		var mean: Element = 0.0
		var c = 0
		withLinearizedAccesses(a) { alin in
			// possibly invoked multiple types
			var lm: Element = 0.0
			Element.mx_measqv(alin.base, numericCast(alin.stride), C: &lm, numericCast(alin.count))
			mean += lm
			c += 1
		}
		return mean / Element(max(1,c))
	}
	public static func minimum<DT: NDimensionalArray>(_ a: DT) -> DT.Element where DT.Element == Element {
		var m: Element = Element.infinity
		withLinearizedAccesses(a) { alin in
			// possibly invoked multiple types
			var lm: Element = 0.0
			Element.mx_minv(alin.base, numericCast(alin.stride), C: &lm, numericCast(alin.count))
			m = min(m, lm)
		}
		return m
	}
	public static func maximum<DT: NDimensionalArray>(_ a: DT) -> DT.Element where DT.Element == Element {
		var m: Element = -Element.infinity
		withLinearizedAccesses(a) { alin in
			// possibly invoked multiple types
			var lm: Element = 0.0
			Element.mx_maxv(alin.base, numericCast(alin.stride), C: &lm, numericCast(alin.count))
			m = max(m, lm)
		}
		return m
	}
	
	// Deriving new arrays
	public static func subtract<DT: NDimensionalArray>(_ a: DT, _ b: DT) -> DT where DT.Element == Element { return a._deriving { subtract(a, b, $0) } }
	
	public static func add<DT: NDimensionalArray>(_ a: DT, _ b: DT) -> DT where DT.Element == Element { return a._deriving { add(a, b, $0) } }
	
	public static func add<DT: NDimensionalArray>(_ a: DT, _ b: Element) -> DT where DT.Element == Element { return a._deriving { add(a, b, $0) } }
	
	public static func multiply<DT: NDimensionalArray>(_ a: Element, _ b: DT) -> DT where DT.Element == Element { return b._deriving { multiply(a, b, $0) } }
	public static func multiply<DT: NDimensionalArray>(_ a: DT, _ b: Element) -> DT where DT.Element == Element { return multiply(b, a) }
	public static func multiplyElements<DT: NDimensionalArray>(_ a: DT, _ b: DT) -> DT where DT.Element == Element { return a._deriving { multiplyElements(a, b, $0) } }
	
	// Operators must be implemented under the type itself
//	public static func +<DT: NDimensionalArray>(lhs: DT, rhs: Element) -> DT where DT.Element == Element { return Numerics.add(lhs, rhs) }
}

extension NDimensionalArray where Element: NAccelerateFloatingPoint {
	public static func zeros(size: NativeIndex) -> Self { return Self(repeating: 0.0, size: size) }
	public static func ones(size: NativeIndex) -> Self { return Self(repeating: 1.0, size: size) }
	
	public var mean: Element { return Numerics.mean(self) }
	public var meanSquare: Element { return Numerics.meanSquare(self) }
	public var maximum: Element { return Numerics.maximum(self) }
	public var minimum: Element { return Numerics.minimum(self) }
	
	public static func +(lhs: Self, rhs: Self) -> Self { return Numerics.add(lhs, rhs) }
	public static func -(lhs: Self, rhs: Self) -> Self { return Numerics.subtract(lhs, rhs) }
	public static func +(lhs: Self, rhs: Element) -> Self { return Numerics.add(lhs, rhs) }
	public static func +(lhs: Element, rhs: Self) -> Self { return Numerics.add(rhs, lhs) }
	public static func -(lhs: Self, rhs: Element) -> Self { return Numerics.add(lhs, -rhs) }
	
	public static func +=(lhs: Self, rhs: Element) { Numerics.add(lhs, rhs, lhs) }
	public static func -=(lhs: Self, rhs: Element) { Numerics.add(lhs, -rhs, lhs) }
	public static func +=(lhs: Self, rhs: Self) { Numerics.add(lhs, rhs, lhs) }
	public static func -=(lhs: Self, rhs: Self) { Numerics.subtract(lhs, rhs, lhs) }
	
	public static func *(lhs: Element, rhs: Self) -> Self { return Numerics.multiply(lhs, rhs) }
	public static func *(lhs: Self, rhs: Element) -> Self { return Numerics.multiply(lhs, rhs) }
	
	public static func *=(lhs: Self, rhs: Element) { Numerics.multiply(lhs, rhs, lhs) }
	public static func /(lhs: Self, rhs: Element) -> Self { return Numerics.multiply(lhs, 1.0/rhs) }
	
	// not here, different meaning for vector/matrices
	//public static func *(lhs: Self, rhs: Self) -> Self { return Numerics.multiply(lhs, rhs) }
	//public static func *=(lhs: Self, rhs: Self) { Numerics.multiply(lhs, rhs, lhs) }
}

extension Numerics where Element: NAdditiveNumeric {
	// debugging / testing
	public static func _setIndexRamp<DT: NDimensionalArray>(_ a: DT) where DT.Element == Element {
		var val: Element = .none
		for index in a.indices {
			a[index] = val
			val += .one
		}
	}
}
