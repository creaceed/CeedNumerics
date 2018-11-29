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
	
	func testBasicTensors() {
//		let tensorA = Tensord(dimensions: [3,3,2], repeatedValue: 1.0)
//		let slice = tensorA[1..<3, 1..<3, 0..<1]
////		let slice = tensorA[1..<3, 1..<3, 1..<2]
//
//		tensorA[1,1,1] = 27.0
//		print("tensor: \n\(tensorA)")
//		print("slice: \n\(slice)")
	}
	
	func testPerformanceExample() {
		// This is an example of a performance test case.
		self.measure {
			// Put the code you want to measure the time of here.
		}
	}
	
}
