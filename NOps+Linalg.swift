//
//  LinearSolver.swift
//  CeedBase
//
//  Created by Raphael Sebbe on 12/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation
import Accelerate

public enum LinearAlgError : Error {
	case lapackIllegalArgument(function: String, index: Int)
	case lapackZeroFactor(index: Int)
	case lapackSingularMatrix
}



public protocol LinearSolverFloatingPoint: AccelerateFloatingPoint {
	static func mx_gels(_ __trans: UnsafeMutablePointer<Int8>!, _ __m: UnsafeMutablePointer<__CLPK_integer>!, _ __n: UnsafeMutablePointer<__CLPK_integer>!, _ __nrhs: UnsafeMutablePointer<__CLPK_integer>!, _ __a: MutablePointerType!, _ __lda: UnsafeMutablePointer<__CLPK_integer>!, _ __b: MutablePointerType!, _ __ldb: UnsafeMutablePointer<__CLPK_integer>!, _ __work: MutablePointerType, _ __lwork: UnsafeMutablePointer<__CLPK_integer>!, _ __info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32
	
	// Adding labels in Swift, easier to use.
	
	// LU factorization
	static func mx_getrf(m: UnsafeMutablePointer<__CLPK_integer>!, n: UnsafeMutablePointer<__CLPK_integer>!, a: MutablePointerType, lda: UnsafeMutablePointer<__CLPK_integer>!, ipiv: UnsafeMutablePointer<__CLPK_integer>!, info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32
	
	// Inversion from LU
	static func mx_getri(n: UnsafeMutablePointer<__CLPK_integer>!, a: MutablePointerType, lda: UnsafeMutablePointer<__CLPK_integer>!, ipiv: UnsafeMutablePointer<__CLPK_integer>!, work: MutablePointerType, lwork: UnsafeMutablePointer<__CLPK_integer>!, info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32
}

extension Float : LinearSolverFloatingPoint {
	public static func mx_gels(_ __trans: UnsafeMutablePointer<Int8>!, _ __m: UnsafeMutablePointer<__CLPK_integer>!, _ __n: UnsafeMutablePointer<__CLPK_integer>!, _ __nrhs: UnsafeMutablePointer<__CLPK_integer>!, _ __a: MutablePointerType!, _ __lda: UnsafeMutablePointer<__CLPK_integer>!, _ __b: MutablePointerType!, _ __ldb: UnsafeMutablePointer<__CLPK_integer>!, _ __work: MutablePointerType, _ __lwork: UnsafeMutablePointer<__CLPK_integer>!, _ __info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32 {
		
		return sgels_(__trans, __m, __n, __nrhs, __a, __lda, __b, __ldb, __work, __lwork, __info)
	}
	public static func mx_getrf(m: UnsafeMutablePointer<__CLPK_integer>!, n: UnsafeMutablePointer<__CLPK_integer>!, a: MutablePointerType, lda: UnsafeMutablePointer<__CLPK_integer>!, ipiv: UnsafeMutablePointer<__CLPK_integer>!, info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32 {
		return sgetrf_(m, n, a, lda, ipiv, info)
	}
	public static func mx_getri(n: UnsafeMutablePointer<__CLPK_integer>!, a: MutablePointerType, lda: UnsafeMutablePointer<__CLPK_integer>!, ipiv: UnsafeMutablePointer<__CLPK_integer>!, work: MutablePointerType, lwork: UnsafeMutablePointer<__CLPK_integer>!, info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32 {
		return sgetri_(n, a, lda, ipiv, work, lwork, info)
	}
}

extension Double : LinearSolverFloatingPoint {
	public static func mx_gels(_ __trans: UnsafeMutablePointer<Int8>!, _ __m: UnsafeMutablePointer<__CLPK_integer>!, _ __n: UnsafeMutablePointer<__CLPK_integer>!, _ __nrhs: UnsafeMutablePointer<__CLPK_integer>!, _ __a: MutablePointerType!, _ __lda: UnsafeMutablePointer<__CLPK_integer>!, _ __b: MutablePointerType!, _ __ldb: UnsafeMutablePointer<__CLPK_integer>!, _ __work: MutablePointerType, _ __lwork: UnsafeMutablePointer<__CLPK_integer>!, _ __info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32 {
		return dgels_(__trans, __m, __n, __nrhs, __a, __lda, __b, __ldb, __work, __lwork, __info)
	}
	public static func mx_getrf(m: UnsafeMutablePointer<__CLPK_integer>!, n: UnsafeMutablePointer<__CLPK_integer>!, a: MutablePointerType, lda: UnsafeMutablePointer<__CLPK_integer>!, ipiv: UnsafeMutablePointer<__CLPK_integer>!, info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32 {
		return dgetrf_(m, n, a, lda, ipiv, info)
	}
	public static func mx_getri(n: UnsafeMutablePointer<__CLPK_integer>!, a: MutablePointerType, lda: UnsafeMutablePointer<__CLPK_integer>!, ipiv: UnsafeMutablePointer<__CLPK_integer>!, work: MutablePointerType, lwork: UnsafeMutablePointer<__CLPK_integer>!, info: UnsafeMutablePointer<__CLPK_integer>!) -> Int32 {
		return dgetri_(n, a, lda, ipiv, work, lwork, info)
	}
}

extension Numerics where Element : LinearSolverFloatingPoint {
	// Solves Ax=b, with tA = T(A), tB = T(b), tX = T(x)
	// Warning: optimized internal LAPACK-baszed implementation, it will overwrite tA/tB contents + has some specific
	// constraints on tB's size (read below).
	//
	// Note that DGELS/SGELS require that its RHS parameters has row capacity (LDB) >= max(BM,AN). This method has
	// the same requirement (assert), because it works in-place (no preprocessing, for maximum speed) and does not transform
	// inputs. Data in B should only be set until BM though.
	//
	static private func _inplaceSolveTransposed(tA: Matrix, tB: Matrix) throws -> (overdetermined: Bool, tX: Matrix) {
		// note: they are transposed: tA.columns = A.rows, tB.columns = B.rows
		// we do this because LAPACK expects column-major matrices, but ours are row-major.
//		let a = tA, b = tB
//		assert(a.columns == b.columns) // = n
		precondition(tA.isCompact) // no stride
		precondition(tB.isCompact)
		
		assert(tB.columns >= max(tA.rows, tA.columns)) // contraint of DGELS method
		
		var trans : Int8 = Int8(String(Character("N")).utf8.first!)
		var m = __CLPK_integer(tA.columns)
		var n = __CLPK_integer(tA.rows)
		var nrhs = __CLPK_integer(tB.rows) // number of vectors to solve
		var lda = m, ldb = __CLPK_integer(tB.columns), lwork = __CLPK_integer(0)
		
		var status : __CLPK_integer = 0
		var wquery : Element = 0.0
		
		lwork = -1
		_ = Element.mx_gels(&trans, &m, &n, &nrhs, nil, &lda, nil, &ldb, &wquery, &lwork, &status)
		
		lwork = __CLPK_integer(wquery.doubleValue)
		
		if (status > 0) {
			//logError("Could not solve system (optimum size). Status is: \(status)");
			throw LinearAlgError.lapackIllegalArgument(function: "gels (query)", index: numericCast(status))
		} else if(status < 0) {
			throw LinearAlgError.lapackZeroFactor(index: numericCast(-status))
		}
		
		var workspace = [Element](repeating: .none, count: Int(lwork))
		
		tA.withStorageAccess { aacc in
			tB.withStorageAccess { bacc in
				_ = Element.mx_gels(&trans, &m, &n, &nrhs, aacc.base, &lda, bacc.base, &ldb, &workspace, &lwork, &status)
			}
		}
		
		if (status > 0) {
			//logError("Could not solve system (optimum size). Status is: \(status)");
			throw LinearAlgError.lapackIllegalArgument(function: "gels", index: numericCast(status))
		} else if(status < 0) {
			throw LinearAlgError.lapackZeroFactor(index: numericCast(-status))
		}
		
		let overdetermined = (m > n)
		let tX = tB[0..<Int(nrhs), 0..<Int(n)]
		
		return (overdetermined, tX)
	}
	
	
	// Solves Ax = b (requires internal transpose, b/c LAPACK is column-major)
	//
	// squareError is only returned for over determined systems (m>n)
	//
	public static func solve(_ A: Matrix, _ b: Matrix) throws -> (solution: Matrix, squareError: Matrix?) {
		let a = A
		let tA = a.transposed()
		let m = a.rows
		let n = a.columns
		let nrhs = b.columns
		
		let tB = Matrix(rows: b.columns, columns: max(tA.rows, tA.columns)) // warn: possibly larger than B
		Numerics.transpose(b, tB[NSlice.all, 0..<b.rows])
		
		let res = try _inplaceSolveTransposed(tA: tA, tB: tB)
		
		var squareError : Matrix?
		if res.overdetermined {
			let sqerr = Matrix(rows: 1, columns: Int(nrhs))
			
			for j in 0..<nrhs {
				for i in n..<m {
					let val = tB[j,i]
					sqerr[0,j] += val*val
				}
			}
			
			squareError = sqerr
		}
		
		let solution = res.tX.transposed()
		
		return (solution: solution, squareError: squareError)
	}
	
	public static func invert(_ input: Matrix, _ output: Matrix) throws {
		precondition(input.shape == output.shape)
		precondition(input.rows == input.columns)
		precondition(input.rows > 1)
		precondition(input.isCompact && output.isCompact)
		
		// output is used as I/O, -> get values from input
		output.set(from: input)
		
		let N = input.rows
		
		var info: __CLPK_integer = 0
		let nc = __CLPK_integer(N)
		var ipiv = [__CLPK_integer](repeating: 0, count: N*N)
		var lwork = __CLPK_integer(N*N)
		var work = [Element](repeating: 0.0, count: Int(lwork))

		try output.withStorageAccess { oacc in
			var n1 = nc, n2 = nc, n3 = nc
			// this does the invert in column major (transposed). Since T(X-1) = (TX)-1, that's just fine ;-)
			_ = Element.mx_getrf(m: &n1, n: &n2, a: oacc.base, lda: &n3, ipiv: &ipiv, info: &info)
			guard info == 0 else { throw info>0 ? LinearAlgError.lapackSingularMatrix : LinearAlgError.lapackIllegalArgument(function: "getrf", index: numericCast(-info))}
			_ = Element.mx_getri(n: &n1, a: oacc.base, lda: &n2, ipiv: &ipiv, work: &work, lwork: &lwork, info: &info)
			guard info == 0 else { throw info>0 ? LinearAlgError.lapackSingularMatrix : LinearAlgError.lapackIllegalArgument(function: "getri", index: numericCast(-info))}
		}
	}
}

// MARK: - Matrix: Deriving new ones + operators
extension NMatrix where Element: LinearSolverFloatingPoint {
	public func inverted() throws -> Matrix {
		let result = Matrix(rows: columns, columns: rows)
		try Numerics.invert(self, result)
		return result
	}
}
