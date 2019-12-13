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

// MARK: - Matrix Ops
extension Numerics where Element: NAccelerateFloatingPoint {
	public static func multiply(_ a: Matrix, _ b: Matrix, _ result: Matrix) {
		precondition(a.columns == b.rows)
		
		withStorageAccess(a) { aacc in
			withStorageAccess(b) { bacc in
				withStorageAccess(result) { racc in
					if aacc.compact && bacc.compact && racc.compact {
						
						assert(aacc.stride.column == 1); assert(aacc.stride.row == aacc.count.column)
						assert(bacc.stride.column == 1); assert(bacc.stride.row == bacc.count.column)
						assert(racc.stride.column == 1); assert(racc.stride.row == racc.count.column)
						
						Element.mx_gemm(order: CblasRowMajor, transA: CblasNoTrans, transB: CblasNoTrans, M: numericCast(a.rows), N: numericCast(b.columns), K: numericCast(a.columns), alpha: 1.0, A: aacc.base, lda: numericCast(aacc.stride.row), B: bacc.base, ldb: numericCast(bacc.stride.row), beta: 0.0, C: racc.base, ldc: numericCast(racc.stride.row))
					} else {
						fatalError("not implemented")
					}
				}
			}
		}
	}
	public static func multiply(_ a: Matrix, _ b: Matrix) -> Matrix {
		let result = Matrix(rows: a.rows, columns: b.columns)
		multiply(a, b, result)
		return result
	}
	
	public static func multiply(_ a: Matrix, _ b: Vector, _ result: Vector) {
		precondition(a.columns == b.size)
		
		withStorageAccess(a) { aacc in
			withStorageAccess(b, result) { bacc, racc in
				if aacc.compact && bacc.compact && racc.compact {
					assert(aacc.stride.column == 1); assert(aacc.stride.row == aacc.count.column)
					assert(bacc.stride == 1)
					assert(racc.stride == 1)
					
					Element.mx_gemm(order: CblasRowMajor, transA: CblasNoTrans, transB: CblasNoTrans, M: numericCast(a.rows), N: 1, K: numericCast(a.columns), alpha: 1.0, A: aacc.base, lda: numericCast(aacc.stride.row), B: bacc.base, ldb: numericCast(bacc.stride), beta: 0.0, C: racc.base, ldc: numericCast(racc.stride))
				} else {
					fatalError("not implemented")
				}
			}
		}
	}
	public static func multiply(_ a: Matrix, _ b: Vector) -> Vector {
		let result = Vector(size: a.rows)
		multiply(a, b, result)
		return result
	}
	
	public static func transpose(_ src: Matrix, _ output: Matrix) {
		assert(output.rows == src.columns)
		assert(output.columns == src.rows)
		
		withStorageAccess(src) { sacc in
			withStorageAccess(output) { oacc in
				if sacc.compact && oacc.compact {
					assert(sacc.stride.column == 1 && sacc.stride.row == sacc.count.column)
					assert(oacc.stride.column == 1 && oacc.stride.row == oacc.count.column)
					
					// rows columns of result (inverted).
					Element.mx_mtrans(sacc.base, 1, oacc.base, 1, numericCast(src.columns), numericCast(src.rows))
				} else {
					let sslice = sacc.slice, oslice = oacc.slice
					for i in 0..<sslice.row.rcount {
						for j in 0..<sslice.column.rcount {
							oacc.base[oslice.position(j,i)] = sacc.base[sslice.position(i,j)]
						}
					}
				}
			}
		}
	}
}

extension Numerics where Element == Float {
	// because of vImage, don't have double impl.
	public static func convolve(input: Matrix, kernel: Matrix, output: Matrix) {
		precondition(kernel.rows % 2 == 1 && kernel.columns % 2 == 1)
		precondition(kernel.compact)
		
		withStorageAccess(input, kernel, output) { iacc, kacc, oacc in
			if kacc.compact && iacc.stride.column == 1 && oacc.stride.column == 1 {
				var ivim = iacc.vImage
				var ovim = oacc.vImage

				vImageConvolve_PlanarF(&ivim, &ovim, nil, 0, 0, kacc.base, numericCast(kacc.count.row), numericCast(kacc.count.column), 0.0, vImage_Flags(kvImageBackgroundColorFill))
			} else {
				fatalError("not implemented")
			}
			
		}
	}
}


// MARK: - Matrix: Deriving new ones + operators
extension NMatrix where Element: NAccelerateFloatingPoint {
	public static func zeros(rows: Int, columns: Int) -> Self { return Self.zeros(size: NQuadraticIndex(rows, columns) ) }
	public static func ones(rows: Int, columns: Int) -> Self { return Self.ones(size: NQuadraticIndex(rows, columns) ) }
	
	public func transposed() -> Matrix {
		let result = Matrix(rows: columns, columns: rows)
		Numerics.transpose(self, result)
		return result
	}
	
	// Matrix specific (only)
	public static func *(lhs: Self, rhs: Self) -> Self { return Numerics.multiply(lhs, rhs) }
	public static func *(lhs: Self, rhs: Vector) -> Vector { return Numerics.multiply(lhs, rhs) }
	public static func /(lhs: Self, rhs: Self) -> Self { return Numerics.divideElements(lhs, rhs) }
	public static func /=(lhs: Self, rhs: Self) { Numerics.divideElements(lhs, rhs, lhs) }
}
