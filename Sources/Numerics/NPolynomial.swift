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

// Polynomials of degree N are represented as a vector of size N+1 (0-power to higher powers)
// P(x) = A + B*x + C*x2 + D*x3 -> degree 3, vector of size 4 with these values: [A, B, C, D]
// Note: somehow diverging from NumPy, which sometimes reverses coefficient orders, sometimes not. We pick one.
// Rationale here: lower powers are generally the most significant (around 0 at least, think Taylor
// series), so have them first.

extension Numerics where Element: NLinearSolverFloatingPoint {
	public static func polyval(_ poly: Vector, x: Vector, result: Vector) {
		precondition(x.size == result.size)
		precondition(poly.size > 0)
		
		withStorageAccess(poly, x, result) { pacc, xacc, racc in
			// Note: reverse iteration for poly (vDSP convention)
			Element.mx_vpoly(pacc.base+pacc.last, -pacc.stride, xacc.base, xacc.stride, racc.base, racc.stride, numericCast(xacc.count), numericCast(poly.size-1))
		}
	}
	public static func polyval(_ poly: Vector, x: Element) -> Element {
		var res: Element = 0.0
		var xp: Element = 1.0
		
		withValues(poly) { p in
			res += p * xp
			xp *= x
		}
		
		return res
	}
	public static func polyval(_ poly: Vector, x: Vector) -> Vector { return x._deriving { polyval(poly, x: x, result: $0) } }
	
	// Fitting a polynomial of given degree
	public static func polyfit(x: Vector, y: Vector, degree: Int) throws -> Vector {
		precondition(degree > 0)
		let dx = x.copy()
		let X = Numerics.zeros(rows: x.size, columns: degree+1)
		
		X[column: 0] = Numerics.ones(count: X.rows)
		for d in 1..<degree+1 {
			X[column: d] = dx
			dx *= x
		}
		let Xt: Matrix = X.transposed()
		
		let M = try (Xt * X).inverted() * Xt
		let poly = M * y
		
		return poly
	}
}

