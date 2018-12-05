//
//  CeedNumerics_tests_mac.swift
//  CeedNumerics-tests.mac
//
//  Created by Raphael Sebbe on 13/11/2018.
//  Copyright © 2018 Creaceed. All rights reserved.
//

import XCTest
import Foundation
@testable import CeedNumerics


func equals<E: NValue>(_ lhs: NVector<E>, _ rhs: NVector<E>) -> Bool where E: NumericsFloatingPoint {
	let tolerance: E = 0.00001
	return lhs.isEqual(to: rhs, tolerance: tolerance)
}

func equals<E: NValue>(_ lhs: NMatrix<E>, _ rhs: NMatrix<E>) -> Bool where E: NumericsFloatingPoint {
	let tolerance: E = 0.00001
	return lhs.isEqual(to: rhs, tolerance: tolerance)
}

class CeedNumerics_tests_mac: XCTestCase {
	override func setUp() {
		// Put setup code here. This method is called before the invocation of each test method in the class.

	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}
	
	func testLinearSolver() {
		let matA = NMatrixd([[1.0,2.0,3.0],
							 [1.0,-2.0,3.0],
							 [1.0,2.0,1.0]])
		let matB = NMatrixd([[1.0,2.0],
							 [1.0,-2.0],
							 [1.0,3.0]])
		
		let imatA = try! matA.inverted()

		// Test matrix inversion
		XCTAssert(equals(imatA,  NMatrixd([[-1.0, 0.5, 1.5],
										  [ 0.25, -0.25, -0.0],
										  [ 0.5 , -0.0, -0.5]])))

		// Test libear solver
		let (matX, _) = try! Numerics.solve(matA, matB)
		XCTAssert(equals(matX,  NMatrixd([[ 1.0 ,  1.5],
										 [-0.0 ,  1.0 ],
										 [-0.0 , -0.5]])))
		
		print("matC: \n\(matX)")
	}
	
	func testNumerics() {
		let mat = NMatrixd(rows: 3, columns: 4)
		let vec = NVectord(size: 5)
		vec[3] = 3.0
		mat[2, 1] = 27.0
		print("vec: \n\(vec)")
		print("mat: \n\(mat)")
		
		print("row: \n\(mat[row: 2])")
		print("column: \n\(mat[column: 1])")
//		print("column: \n\(mat[column: 5])")
		let slice = mat[NResolvedSlice(start: 2, count: 3, step: -1), NResolvedSlice.default(count: mat.columns)]
		print("slice: \n\(slice)")
		
		let newRow = NVectord(size: 4)
		newRow[1] = 31.0
		newRow[2] = 13.0
		
		mat[row: 1] = newRow
		print("mat (after set row): \n\(mat)")
		
		//mat[NResolvedSlice(start: 0, count: 2, step: 2), NResolvedSlice(start: 0, count: 2, step: 2)].set(1.5)
//		mat[0~4~2, 0~4~2].set(1.5)
		mat[0~~2, 0~~2].set(1.5)
		print("mat (after sliced set): \n\(mat)")
		mat[~~2, 1~~].set(3.0)
		print("mat (after sliced set): \n\(mat)")
		print("mat (transposed - compact): \n\(mat.transposed())")
		print("mat (transposed - non-compact): \n\(mat[1...2, 1...2].transposed())")
		let i=2
		mat[~i, (i-1)~].set(7.0)
		print("mat (after sliced set): \n\(mat)")
		
		let linv = Numerics.linspace(start: 0.0, stop: 10.0, count: 10)
		print("linspace: \n\(linv)")
	}
	
	func testAPIs() {
		let mat = NMatrixd([[1.0,2.0,3.0],
							[1.0,-2.0,3.0],
							[1.0,2.0,1.0],
							[-1.0,2.0,1.0]])
		let v3 = NVectord([1.0, 2.0, 3.0])
		let matv3res = NVectord([14.0, 6.0, 8.0, 6.0])
		let vec = NVectord([1.0, 2.0, 1.5, 80.0 , 0.8, 1.6, 1.7])
//		let ramp = NVectord([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
		
		let poly = NVectord([1.0, -1.0, 2.0])
		let xval = NVectord([-1.0, 0.0, 1.0, 2.0])
		let expected_polyval = NVectord([4.0, 1.0, 2.0, 7.0])
		
		let median3 = Numerics.median(input: vec, kernel: 3)
		let median3res = NVectord([1.0, 1.5, 2.0, 1.5, 1.6, 1.6, 1.7])
		
//		print("indices: ")
//		for i in mat.indices { print("\(i)") }
		
//		let padded = vec.padding(before: 5, after: 3)
		
//		print("median K=3: \n\(median3)")
//		print("median k=5: \n\(Numerics.median(input: vec, kernel: 5))")
//
//		print("pad \(padded)")
//
//		print("cumcum: \(Numerics.cumsum(ramp))")
//
//		print("mat * vec: \(mat * v3)")
//
//		print("poly eval: \(Numerics.polyval(poly, x: xval))")
		
		XCTAssert(equals(median3, median3res))
		XCTAssert(equals(mat * v3, matv3res))
		XCTAssert(equals(Numerics.polyval(poly, x: xval), expected_polyval))
	}
	
	func testMaskedAndIndexedAccess() {
		let v1: NVectord = Numerics.linspace(start: 0.0, stop: 50.0, count: 51)
		let ind = NVectori([5, 9, 10, 19])
		let mask = (v1 >= 21.0)
		
		let m1 = NMatrixd([[1.0,2.0,3.0],
							[1.0,-2.0,3.0],
							[1.0,2.0,1.0],
							[-1.0,2.0,1.0]])
		
		print(v1[ind])
		v1[ind] = NVectord([-1.0, -1.0, -1.0, -3.0])
		print(v1)
		
		print(v1 < 21.0)
		print(v1[mask])
		
		v1.set(1.1, mask: mask)
		print(v1)
		
		print(m1 >= 3.0)
		//let mmask = m1 >= 3.0
		print(m1[m1 >= 3.0])
		m1.set(72.0, mask: m1 >= 3.0)
		print(m1)
	}
	
	func testMisc() {
		let v1 = NVectord([1.0, 2.0, 3.0])
		let v2 = NVectord([4.0, 5.0, 6.0])
		
		// Test Vector.set()
		v1.set(from: v2)
		XCTAssert(equals(v1, v2))
		
		
	}
	
	func testBasicTensors() {
//		let tensorA = Tensord(dimensions: [3,3,2], repeatedValue: 1.0)
//		let slice = tensorA[1..<3, 1..<3, 0..<1]
////		let slice = tensorA[1..<3, 1..<3, 1..<2]
//
//		tensorA[1,1,1] = 27.0
//		print("tensor: \n\(tensorA)")
//		print("slice: \n\(slice)")
	}
	
//	func testPerformanceSliceLoop() {
//		// This is an example of a performance test case.
//		self.measure {
//			// Put the code you want to measure the time of here.
//			let indices = NResolvedQuadraticSlice(row: NResolvedSlice(start: 0, count: 1000, step: 1000),
//												  column: NResolvedSlice(start: 0, count: 1000, step: 1))
//			var sum = 0
//			for i in indices {
//				sum += i
//			}
//			print("sum= \(sum)")
//		}
//	}
//	func testPerformance1Loop() {
//		// This is an example of a performance test case.
//		self.measure {
//			// Put the code you want to measure the time of here.
//			let indices = NQuadraticIndexRange(rows: 1000, columns: 1000)
//			var sum = 0
//			for i in indices {
//				sum += i.0+i.1
//			}
//			print("sum= \(sum)")
//		}
//	}
//	func testPerformance2Loops() {
//		// This is an example of a performance test case.
//		self.measure {
//			// Put the code you want to measure the time of here.
//			var sum = 0
//			for i in 0..<1000 {
//				for j in 0..<1000 {
//					sum += i+j
//				}
//			}
//			print("sum= \(sum)")
//		}
//	}
}
