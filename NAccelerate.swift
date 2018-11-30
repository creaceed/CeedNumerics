//
//  NGenericAccelerate.swift
//  CeedBase
//
//  Created by Raphael Sebbe on 22/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import Foundation
import Accelerate

// Accelerate functions perform best with stride of 1. This function can be used (special mode) to determine when it is not the case.
private func _performanceCheckStride(_ strides: vDSP_Stride...) {
	
}

public protocol NumericsFloatingPoint: FloatingPoint, ExpressibleByFloatLiteral, CustomStringConvertible {
	var doubleValue: Double { get }
}

extension Double: NumericsFloatingPoint {
	public var doubleValue: Double { return self }
}
extension Float: NumericsFloatingPoint {
	public var doubleValue: Double { return Double(self) }
}


// This protocol allows to define generic variants of Accelerate functions (BLAS, vDSP, etc.). This enables easier
// implementation of features across Float and Double (single code)
public protocol AccelerateFloatingPoint: NValue, NumericsFloatingPoint {
	typealias PointerType = UnsafePointer<Self>
	typealias MutablePointerType = UnsafeMutablePointer<Self>
	typealias Element = Self
	
	// vDSP
	// convolve
	static func mx_conv(_ __A: PointerType, _ __IA: vDSP_Stride, _ __F: PointerType, _ __IF: vDSP_Stride, _ __C: MutablePointerType, _ __IC: vDSP_Stride, _ __N: vDSP_Length, _ __P: vDSP_Length)
	
	// E(i) = A(i)*b + C(i)*d
	static func mx_vsmsma(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: PointerType, _ IC: vDSP_Stride, _ D: Element, _ E: MutablePointerType, _ IE: vDSP_Stride, _ N: vDSP_Length)
	
	// C(i) = a + b*i
	static func mx_vramp(_ A: Element, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	
	// C(0) = 0, C(i) = A(i) + C(i-1) // yeah, strange API, A(0) not used
	static func mx_vrsum(_ A: PointerType, _ IA: vDSP_Stride, _ S: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	
	// Matrix transpose
	static func mx_mtrans(_ A: PointerType, _ IA: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ M: vDSP_Length, _ N: vDSP_Length)
	
	// Polynomial C(i) = Σp A(p)*B(i)^(P-p)
	static func mx_vpoly(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length, _ P: vDSP_Length)
	
	// mul/div/add/sub, element wise and scalar
	static func mx_vdiv(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	static func mx_vmul(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	static func mx_vsdiv(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	static func mx_vsmul(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	
	static func mx_vsadd(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	static func mx_vadd(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	static func mx_vsub(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length)
	
	// Reduction & min/max
	static func mx_measqv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length)
	static func mx_meanv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length)
	static func mx_minv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length)
	static func mx_maxv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length)
	
	// CBLAS
	static func mx_gemm(order: CBLAS_ORDER, transA: CBLAS_TRANSPOSE, transB: CBLAS_TRANSPOSE, M: Int32, N: Int32, K: Int32, alpha: Element, A: PointerType, lda: Int32, B: PointerType, ldb: Int32, beta: Element, C: MutablePointerType, ldc: Int32)
}

extension Double: AccelerateFloatingPoint {
	public static func mx_conv(_ __A: PointerType, _ __IA: vDSP_Stride, _ __F: PointerType, _ __IF: vDSP_Stride, _ __C: MutablePointerType, _ __IC: vDSP_Stride, _ __N: vDSP_Length, _ __P: vDSP_Length) {
		_performanceCheckStride(__IA, __IF, __IC)
		vDSP_convD(__A, __IA, __F, __IF, __C, __IC, __N, __P)
	}
	public static func mx_vsmsma(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: PointerType, _ IC: vDSP_Stride, _ D: Element, _ E: MutablePointerType, _ IE: vDSP_Stride, _ N: vDSP_Length) {
		var b=B, d=D
		_performanceCheckStride(IA, IC, IE)
		vDSP_vsmsmaD(A, IA, &b, C, IC, &d, E, IE, N)
	}
	public static func mx_vramp(_ A: Element, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var a=A, b=B
		_performanceCheckStride(IC)
		vDSP_vrampD(&a, &b, C, IC, N)
	}
	public static func mx_vpoly(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length, _ P: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vpolyD(A, IA, B, IB, C, IC, N, P)
	}
	public static func mx_vdiv(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vdivD(B, IB, A, IA, C, IC, N)
	}
	public static func mx_vmul(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vmulD(A, IA, B, IB, C, IC, N)
	}
	public static func mx_vsdiv(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var b=B
		_performanceCheckStride(IA, IC)
		vDSP_vsdivD(A, IA, &b, C, IC, N)
	}
	public static func mx_vsmul(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var b=B
		_performanceCheckStride(IA, IC)
		vDSP_vsmulD(A, IA, &b, C, IC, N)
	}
	public static func mx_vrsum(_ A: PointerType, _ IA: vDSP_Stride, _ S: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IC)
		var s=S
		vDSP_vrsumD(A, IA, &s, C, IC, N)
	}
	public static func mx_mtrans(_ A: PointerType, _ IA: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ M: vDSP_Length, _ N: vDSP_Length) {
		vDSP_mtransD(A, IA, C, IC, M, N)
	}
	public static func mx_vsadd(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var b=B
		_performanceCheckStride(IA, IC)
		vDSP_vsaddD(A, IA, &b, C, IC, N)
	}
	public static func mx_vadd(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vaddD(A, IA, B, IB, C, IC, N)
	}
	public static func mx_vsub(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vsubD(B, IB, A, IA, C, IC, N)
	}
	public static func mx_meanv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_meanvD(A, IA, &C, N)
	}
	public static func mx_measqv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_measqvD(A, IA, &C, N)
	}
	public static func mx_minv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_minvD(A, IA, &C, N)
	}
	public static func mx_maxv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_maxvD(A, IA, &C, N)
	}
	// CBLAS
	public static func mx_gemm(order: CBLAS_ORDER, transA: CBLAS_TRANSPOSE, transB: CBLAS_TRANSPOSE, M: Int32, N: Int32, K: Int32, alpha: Element, A: PointerType, lda: Int32, B: PointerType, ldb: Int32, beta: Element, C: MutablePointerType, ldc: Int32) {
		cblas_dgemm(order, transA, transB, M, N, K, alpha, A, lda, B, ldb, beta, C, ldc)
	}
}
extension Float: AccelerateFloatingPoint {
	public static func mx_conv(_ __A: PointerType, _ __IA: vDSP_Stride, _ __F: PointerType, _ __IF: vDSP_Stride, _ __C: MutablePointerType, _ __IC: vDSP_Stride, _ __N: vDSP_Length, _ __P: vDSP_Length) {
		_performanceCheckStride(__IA, __IF, __IC)
		vDSP_conv(__A, __IA, __F, __IF, __C, __IC, __N, __P)
	}
	public static func mx_vsmsma(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: PointerType, _ IC: vDSP_Stride, _ D: Element, _ E: MutablePointerType, _ IE: vDSP_Stride, _ N: vDSP_Length) {
		var b=B, d=D
		_performanceCheckStride(IA, IC, IE)
		vDSP_vsmsma(A, IA, &b, C, IC, &d, E, IE, N)
	}
	public static func mx_vramp(_ A: Element, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var a=A, b=B
		_performanceCheckStride(IC)
		vDSP_vramp(&a, &b, C, IC, N)
	}
	public static func mx_vpoly(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length, _ P: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vpoly(A, IA, B, IB, C, IC, N, P)
	}
	public static func mx_vdiv(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vdiv(B, IB, A, IA, C, IC, N)
	}
	public static func mx_vmul(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vmul(A, IA, B, IB, C, IC, N)
	}
	public static func mx_vsdiv(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var b=B
		_performanceCheckStride(IA, IC)
		vDSP_vsdiv(A, IA, &b, C, IC, N)
	}
	public static func mx_vsmul(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var b=B
		_performanceCheckStride(IA, IC)
		vDSP_vsmul(A, IA, &b, C, IC, N)
	}
	public static func mx_vrsum(_ A: PointerType, _ IA: vDSP_Stride, _ S: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IC)
		var s=S
		vDSP_vrsum(A, IA, &s, C, IC, N)
	}
	public static func mx_mtrans(_ A: PointerType, _ IA: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ M: vDSP_Length, _ N: vDSP_Length) {
		vDSP_mtrans(A, IA, C, IC, M, N)
	}
	public static func mx_vsadd(_ A: PointerType, _ IA: vDSP_Stride, _ B: Element, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		var b=B
		_performanceCheckStride(IA, IC)
		vDSP_vsadd(A, IA, &b, C, IC, N)
	}
	public static func mx_vadd(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vadd(A, IA, B, IB, C, IC, N)
	}
	public static func mx_vsub(_ A: PointerType, _ IA: vDSP_Stride, _ B: PointerType, _ IB: vDSP_Stride, _ C: MutablePointerType, _ IC: vDSP_Stride, _ N: vDSP_Length) {
		_performanceCheckStride(IA, IB, IC)
		vDSP_vsub(B, IB, A, IA, C, IC, N)
	}
	public static func mx_meanv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_meanv(A, IA, &C, N)
	}
	public static func mx_measqv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_measqv(A, IA, &C, N)
	}
	public static func mx_minv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_minv(A, IA, &C, N)
	}
	public static func mx_maxv(_ A: PointerType, _ IA: vDSP_Stride, C: inout Element, _ N: vDSP_Length) {
		_performanceCheckStride(IA)
		vDSP_maxv(A, IA, &C, N)
	}
	// CBLAS
	public static func mx_gemm(order: CBLAS_ORDER, transA: CBLAS_TRANSPOSE, transB: CBLAS_TRANSPOSE, M: Int32, N: Int32, K: Int32, alpha: Element, A: PointerType, lda: Int32, B: PointerType, ldb: Int32, beta: Element, C: MutablePointerType, ldc: Int32) {
		cblas_sgemm(order, transA, transB, M, N, K, alpha, A, lda, B, ldb, beta, C, ldc)
	}
}
