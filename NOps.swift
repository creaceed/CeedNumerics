//
//  File.swift
//  CeedBase
//
//  Created by Raphael Sebbe on 22/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

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

// MARK: - Vector Ops
extension Numerics where Element: AccelerateFloatingPoint {
	/// Creation of vectors
	public static func zeros(count: Int) -> Vector { return Vector(repeating: 0.0, count: count) }
	public static func ones(count: Int) -> Vector { return NVector(repeating: 1.0, count: count) }
	public static func linspace(start: Element, stop: Element, count: Int, output: Vector) {
		precondition(count == output.size)
		precondition(count >= 2)
		
		withStorageAccess(output) { oaccess in
			Element.mx_vramp(start, stop/Element(count-1), oaccess.base, numericCast(oaccess.stride), numericCast(oaccess.count))
		}
	}
	public static func linspace(start: Element, stop: Element, count: Int) -> Vector {
		precondition(count >= 2)
		let output = Vector(size: count)
		linspace(start: start, stop: stop, count: count, output: output)
		return output
	}
	
	// Median (brute force)
	public static func median(input: Vector, kernel K: Int) -> Vector {
		precondition(K % 2 == 1 && K > 0)
		let output = Vector(size: input.size)
		guard input.size > 0 else { return output }
		
		let HK = K / 2
		var window = [Element](repeating: Element.none, count: K)// NVector(size: kernel)
		let auginput = Vector(size: 2*HK + input.size)
		let N = input.size
		
		// Prepare augmented input (TODO: could have different conditions here)
		for i in 0..<HK {
			auginput[i] = input[0]
			auginput[HK+N+i] = input[N-1]
		}
		for i in 0..<N {
			auginput[i+HK] = input[i]
		}
		//		print("aug: \(auginput)")
		
		// Main loop
		for i in 0..<N {
			let ai = HK + i
			// fill window
			for j in 0..<K {
				window[j] = auginput[ai-HK+j]
			}
			window.sort()
			output[i] = window[HK]
		}
		
		return output
	}
	
	// .valid domain only (no allocation), because that's what natively supported in Accelerate
	public static func convolve(input: Vector, kernel: Vector, output: Vector) {
		let M = input.size
		let K = kernel.size
		let O = output.size
		
		precondition(K > 0)
		precondition(M >= kernel.size)
		precondition(O == M - K + 1)
		
		withStorageAccess(input, kernel, output) { iaccess, kaccess, oaccess in
			// TODO: check negative stride is supported for input/output (doc only mentions kernel)
			Element.mx_conv(iaccess.base, iaccess.stride, kaccess.base, kaccess.stride, oaccess.base, oaccess.stride, numericCast(oaccess.count), numericCast(kaccess.count))
		}
	}
	
	public static func pad(input: Vector, before: Int, after: Int, mode: PaddingMode = .edge, output: Vector) {
		precondition(before >= 0)
		precondition(after >= 0)
		precondition(input.size > 0) // for edge mode
		
		let afterstart = before+input.size
		
		output[before ..< afterstart] = input
		output[0 ..< before] = NVector(repeating: input.first!, count: before)
		output[afterstart ..< output.size] = NVector(repeating: input.last!, count: after)
	}
	
	// Arithmetic
	public static func scaledAdd(_ a: Vector, _ asp: Element, _ b: Vector, _ bs: Element, _ output: Vector) {
		precondition(a.size == b.size && a.size == output.size)
		
		withStorageAccess(a, b, output) { aacc, bacc, oacc in
			// TODO: check negative stride is supported for input/output (doc only mentions kernel)
			Element.mx_vsmsma(aacc.base, aacc.stride, asp, bacc.base, bacc.stride, bs, oacc.base, oacc.stride, numericCast(aacc.count))
		}
	}
	
	public static func lerp(_ a: Vector, _ b: Vector, _ t: Element, _ result: Vector) {
		return scaledAdd(a, 1.0-t, b, t, result)
	}
	public static func lerp(_ a: Vector, _ b: Vector, _ t: Element) -> Vector { return a._deriving { scaledAdd(a, 1.0-t, b, t, $0) } }
	
	public static func multiply(_ a: Element, _ b: Vector, _ result: Vector) {
		precondition(b.shape == result.shape)
		withStorageAccess(b, result) { bacc, racc in
			Element.mx_vsmul(bacc.base, bacc.stride, a, racc.base, racc.stride, numericCast(racc.count))
		}
	}
	public static func multiply(_ a: Element, _ b: Vector) -> Vector { return b._deriving { multiply(a, b, $0) } }
	// Obvious swaps
	public static func multiply(_ a: Vector, _ b: Element, _ result: Vector) { multiply(b, a, result) }
	public static func multiply(_ a: Vector, _ b: Element) -> Vector { return multiply(b, a) }
	
	public static func multiply(_ a: Vector, _ b: Vector, _ result: Vector) {
		precondition(a.size == b.size && b.size == result.size)
		
		withStorageAccess(a, b, result) { aacc, bacc, racc in
			Element.mx_vmul(aacc.base, aacc.stride, bacc.base, bacc.stride, racc.base, racc.stride, numericCast(racc.count))
		}
	}
	public static func multiply(_ a: Vector, _ b: Vector) -> Vector { return a._deriving { multiply(a, b, $0) } }
	
	public static func subtract(_ a: Vector, _ b: Vector, _ result: Vector) {
		precondition(a.shape == b.shape && a.shape == result.shape)
		withStorageAccess(a, b, result) { aacc, bacc, racc in
			Element.mx_vsub(aacc.base, aacc.stride, bacc.base, bacc.stride, racc.base, racc.stride, numericCast(racc.count))
		}
	}
	public static func subtract(_ a: Vector, _ b: Vector) -> Vector { return a._deriving { subtract(a, b, $0) } }
	public static func add(_ a: Vector, _ b: Vector, _ result: Vector) {
		precondition(a.shape == b.shape && a.shape == result.shape)
		withStorageAccess(a, b, result) { aacc, bacc, racc in
			Element.mx_vadd(aacc.base, aacc.stride, bacc.base, bacc.stride, racc.base, racc.stride, numericCast(racc.count))
		}
	}
	public static func add(_ a: Vector, _ b: Vector) -> Vector { return a._deriving { add(a, b, $0) } }
	public static func add(_ a: Vector, _ b: Element, _ result: Vector) {
		precondition(a.shape == result.shape)
		withStorageAccess(a, result) { aacc, racc in
			Element.mx_vsadd(aacc.base, aacc.stride, b, racc.base, racc.stride, numericCast(racc.count))
		}
	}
	public static func add(_ a: Vector, _ b: Element) -> Vector { return a._deriving { add(a, b, $0) } }
	
	public static func cumsum(_ a: Vector) -> Vector {
		precondition(a.size > 0)
		let result = a.copy()
		
		// because of vDSP implementation
		if a.size > 1 {
			result[1] = result[0] + result[1]
		}
		
		withStorageAccess(result) { racc in
			// in-place. OK?
			Element.mx_vrsum(racc.base, racc.stride, 1.0, racc.base, racc.stride, numericCast(racc.count))
		}
		result[0] = a[0]
		return result
	}
	public static func mean(_ a: Vector) -> Element {
		return withStorageAccess(a) { aacc in
			var val: Element = .none
			Element.mx_meanv(aacc.base, aacc.stride, C: &val, numericCast(aacc.count))
			return val
		}
	}
	public static func meanSquare(_ a: Vector) -> Element {
		return withStorageAccess(a) { aacc in
			var val: Element = .none
			Element.mx_measqv(aacc.base, aacc.stride, C: &val, numericCast(aacc.count))
			return val
		}
	}
	public static func maximum(_ a: Vector) -> Element {
		return withStorageAccess(a) { aacc in
			var val = -Element.infinity
			Element.mx_maxv(aacc.base, aacc.stride, C: &val, numericCast(aacc.count))
			return val
		}
	}
	public static func minimum(_ a: Vector) -> Element {
		return withStorageAccess(a) { aacc in
			var val = -Element.infinity
			Element.mx_minv(aacc.base, aacc.stride, C: &val, numericCast(aacc.count))
			return val
		}
	}
}

// MARK: - Vector: Deriving new ones + operators
extension NVector where Element: AccelerateFloatingPoint {
	public var mean: Element { return Numerics.mean(self) }
	public var meanSquare: Element { return Numerics.meanSquare(self) }
	public var maximum: Element { return Numerics.maximum(self) }
	public var minimum: Element { return Numerics.minimum(self) }
	
	public func padding(before: Int, after: Int, mode: PaddingMode = .edge) -> Vector {
		precondition(before >= 0)
		precondition(after >= 0)
		precondition(self.size > 0) // for edge mode
		
		let output = NVector(size: self.size + before + after)
		
		num.pad(input: self, before: before, after: after, mode: mode, output: output)
		
		return output
	}
	public func convolving(kernel: Vector, domain: ConvolutionDomain = .same, padding: PaddingMode = .edge) -> Vector {
		precondition(self.size >= kernel.size)
		
		let M = self.size
		let K = kernel.size
		let output: Vector, vinput: Vector
		
		switch domain {
		case .same:
			let bk = K/2, ek = K-1-bk
			vinput = self.padding(before: bk, after: ek)
			output = NVector(size: M)
		case .valid:
			vinput = self
			output = NVector(size: M - K + 1)
		}
		
		num.convolve(input: vinput, kernel: kernel, output: output)
		return output
	}
	
	// Operators here too. Scoped + types are easier to write.
	public static func +(lhs: Vector, rhs: Element) -> Vector { return Numerics.add(lhs, rhs) }
	public static func -(lhs: Vector, rhs: Element) -> Vector { return Numerics.add(lhs, -rhs) }
	public static func *(lhs: Element, rhs: Vector) -> Vector { return Numerics.multiply(lhs, rhs) }
	public static func *(lhs: Vector, rhs: Element) -> Vector { return Numerics.multiply(lhs, rhs) }
	public static func *(lhs: Vector, rhs: Vector) -> Vector { return Numerics.multiply(lhs, rhs) }
	
	public static func -(lhs: Vector, rhs: Vector) -> Vector { return Numerics.subtract(lhs, rhs) }
	public static func +(lhs: Vector, rhs: Vector) -> Vector { return Numerics.add(lhs, rhs) }
	
	public static func +=(lhs: Vector, rhs: Element) { Numerics.add(lhs, rhs, lhs) }
	public static func -=(lhs: Vector, rhs: Element) { Numerics.add(lhs, -rhs, lhs) }
	public static func +=(lhs: Vector, rhs: Vector) { Numerics.add(lhs, rhs, lhs) }
	public static func *=(lhs: Vector, rhs: Element) { Numerics.multiply(lhs, rhs, lhs) }
	public static func *=(lhs: Vector, rhs: Vector) { Numerics.multiply(lhs, rhs, lhs) }
}


// MARK: - Matrix Ops
extension Numerics where Element: AccelerateFloatingPoint {
	public static func zeros(rows: Int, columns: Int) -> Matrix { return Matrix(repeating: 0.0, rows: rows, columns: columns) }
	public static func ones(rows: Int, columns: Int) -> Matrix { return Matrix(repeating: 1.0, rows: rows, columns: columns) }
	
	public static func multiply(_ a: Matrix, _ b: Element, _ result: Matrix) {
		precondition(a.shape == result.shape)
		
		a.withStorageAccess { aacc in
			result.withStorageAccess { racc in
				if a.isCompact && result.isCompact {
					assert(aacc.stride.column == 1); assert(aacc.stride.row == aacc.count.column)
					assert(racc.stride.column == 1); assert(racc.stride.row == racc.count.column)
					
					Element.mx_vsmul(aacc.base, 1, b, racc.base, 1, numericCast(aacc.count.row * aacc.count.column))
					
				} else {
					var lit = a._storageIterator()
					var rit = result._storageIterator()
					
					while let pos = lit.next(), let rpos = rit.next() {
						racc.base[rpos] = aacc.base[pos] * b
					}
				}
			}
		}
	}
	// swap + deriving
	public static func multiply(_ a: Element, _ b: Matrix, _ result: Matrix) { multiply(b, a, result) }
	public static func multiply(_ a: Matrix, _ b: Element) -> Matrix { return a._deriving { multiply(a, b, $0) } }
	public static func multiply(_ a: Element, _ b: Matrix) -> Matrix { return multiply(b, a) }
	
	
	public static func multiply(_ a: Matrix, _ b: Matrix, _ result: Matrix) {
		precondition(a.columns == b.rows)
		
		if a.isCompact && b.isCompact && result.isCompact {
			a.withStorageAccess { aacc in
				b.withStorageAccess { bacc in
					result.withStorageAccess { racc in
						assert(aacc.stride.column == 1); assert(aacc.stride.row == aacc.count.column)
						assert(bacc.stride.column == 1); assert(bacc.stride.row == bacc.count.column)
						assert(racc.stride.column == 1); assert(racc.stride.row == racc.count.column)
						
						Element.mx_gemm(order: CblasRowMajor, transA: CblasNoTrans, transB: CblasNoTrans, M: numericCast(a.rows), N: numericCast(b.columns), K: numericCast(a.columns), alpha: 1.0, A: aacc.base, lda: numericCast(aacc.stride.row), B: bacc.base, ldb: numericCast(bacc.stride.row), beta: 0.0, C: racc.base, ldc: numericCast(racc.stride.row))
					}
				}
			}
		} else {
			fatalError("not implemented")
		}
	}
	public static func multiply(_ a: Matrix, _ b: Matrix) -> Matrix {
		let result = Matrix(rows: a.rows, columns: b.columns)
		multiply(a, b, result)
		return result
	}
	
	public static func multiply(_ a: Matrix, _ b: Vector, _ result: Vector) {
		precondition(a.columns == b.size)
		
		if a.isCompact && b.isCompact && result.isCompact {
			a.withStorageAccess { aacc in
				withStorageAccess(b, result) { bacc, racc in
					assert(aacc.stride.column == 1); assert(aacc.stride.row == aacc.count.column)
					assert(bacc.stride == 1)
					assert(racc.stride == 1)
					
					Element.mx_gemm(order: CblasRowMajor, transA: CblasNoTrans, transB: CblasNoTrans, M: numericCast(a.rows), N: 1, K: numericCast(a.columns), alpha: 1.0, A: aacc.base, lda: numericCast(aacc.stride.row), B: bacc.base, ldb: numericCast(bacc.stride), beta: 0.0, C: racc.base, ldc: numericCast(racc.stride))
				}
			}
		} else {
			fatalError("not implemented")
		}
	}
	public static func multiply(_ a: Matrix, _ b: Vector) -> Vector {
		let result = Vector(size: a.rows)
		multiply(a, b, result)
		return result
	}
	
	public static func divide(_ a: Matrix, _ b: Matrix, _ result: Matrix) {
		precondition(a.shape == b.shape && a.shape == result.shape)
		
		if a.isCompact && b.isCompact && result.isCompact {
			a.withStorageAccess { aacc in
				b.withStorageAccess { bacc in
					result.withStorageAccess { racc in
						Element.mx_vdiv(aacc.base, 1, bacc.base, 1, racc.base, 1, numericCast(a.rows * a.columns))
//						print("\(aacc.base)")
					}
				}
			}
		} else {
			fatalError("not implemented")
		}
	}
	public static func divide(_ a: Matrix, _ b: Matrix) -> Matrix { return a._deriving { divide(a, b, $0) } }
	
	
	public static func transpose(_ src: Matrix, _ output: Matrix) {
		assert(output.rows == src.columns)
		assert(output.columns == src.rows)
		
		if src.isCompact && output.isCompact {
			src.withStorageAccess { sacc in
				output.withStorageAccess { oacc in
					assert(sacc.stride.column == 1 && sacc.stride.row == sacc.count.column)
					assert(oacc.stride.column == 1 && oacc.stride.row == oacc.count.column)
					
					// rows columns of result (inverted).
					Element.mx_mtrans(sacc.base, 1, oacc.base, 1, numericCast(src.columns), numericCast(src.rows))
				}
			}
		} else {
			// TODO: could use faster iterator approach
			for i in 0..<src.rows {
				for j in 0..<src.columns {
					output[j, i] = src[i, j]
				}
			}
		}
	}
	public static func mean(_ a: Matrix) -> Element {
		return a.withStorageAccess { aacc in
			if a.isCompact {
				var val: Element = .none
				Element.mx_meanv(aacc.base, 1, C: &val, numericCast(aacc.count.row * aacc.count.column))
				return val
			}
			else {
				var m: Element = 0.0
				for i in 0..<aacc.count.row {
					var lm: Element = 0.0
					Element.mx_meanv(aacc.base + i*aacc.stride.row, aacc.stride.column, C: &lm, numericCast(aacc.count.column))
					m += lm
				}
				m /= Element(aacc.count.row)
				return m
			}
		}
	}
	public static func meanSquare(_ a: Matrix) -> Element {
		return a.withStorageAccess { aacc in
			if a.isCompact {
				var val: Element = .none
				Element.mx_measqv(aacc.base, 1, C: &val, numericCast(aacc.count.row * aacc.count.column))
				return val
			}
			else {
				var m: Element = 0.0
				for i in 0..<aacc.count.row {
					var lm: Element = 0.0
					Element.mx_measqv(aacc.base + i*aacc.stride.row, aacc.stride.column, C: &lm, numericCast(aacc.count.column))
					m += lm
				}
				m /= Element(aacc.count.row)
				return m
			}
		}
	}
	public static func minimum(_ a: Matrix) -> Element {
		return a.withStorageAccess { aacc in
			if a.isCompact {
				var val: Element = Element.infinity
				Element.mx_minv(aacc.base, 1, C: &val, numericCast(aacc.count.row * aacc.count.column))
				return val
			}
			else {
				var m: Element = Element.infinity
				for i in 0..<aacc.count.row {
					var lm: Element = Element.infinity
					Element.mx_minv(aacc.base + i*aacc.stride.row, aacc.stride.column, C: &lm, numericCast(aacc.count.column))
					m = min(m, lm)
				}
				return m
			}
		}
	}
	public static func maximum(_ a: Matrix) -> Element {
		return a.withStorageAccess { aacc in
			if a.isCompact {
				var val: Element = -Element.infinity
				Element.mx_maxv(aacc.base, 1, C: &val, numericCast(aacc.count.row * aacc.count.column))
				return val
			}
			else {
				var m: Element = -Element.infinity
				for i in 0..<aacc.count.row {
					var lm: Element = -Element.infinity
					Element.mx_maxv(aacc.base + i*aacc.stride.row, aacc.stride.column, C: &lm, numericCast(aacc.count.column))
					m = max(m, lm)
				}
				return m
			}
		}
	}
}


// MARK: - Matrix: Deriving new ones + operators
extension NMatrix where Element: AccelerateFloatingPoint {
	public var mean: Element { return Numerics.mean(self) }
	public var meanSquare: Element { return Numerics.meanSquare(self) }
	public var maximum: Element { return Numerics.maximum(self) }
	public var minimum: Element { return Numerics.minimum(self) }
	
	
	public func transposed() -> Matrix {
		let result = Matrix(rows: columns, columns: rows)
		Numerics.transpose(self, result)
		return result
	}
	
	// Matrix/Vector
	public static func *(lhs: Matrix, rhs: Matrix) -> Matrix { return Numerics.multiply(lhs, rhs) }
	public static func *(lhs: Matrix, rhs: Vector) -> Vector { return Numerics.multiply(lhs, rhs) }
	// Matrix/Element
	public static func /(lhs: Matrix, rhs: Element) -> Matrix { return Numerics.multiply(lhs, 1.0/rhs) }
	public static func *(lhs: Matrix, rhs: Element) -> Matrix { return Numerics.multiply(lhs, rhs) }
	public static func *(lhs: Element, rhs: Matrix) -> Matrix { return Numerics.multiply(lhs, rhs) }
	
	public static func *=(lhs: Matrix, rhs: Element) { Numerics.multiply(lhs, rhs, lhs) }
	public static func /=(lhs: Matrix, rhs: Matrix) { Numerics.divide(lhs, rhs, lhs) }
}
