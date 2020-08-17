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

import XCTest
import Foundation
@testable import Numerics

let _tol: Double = 0.00001


func equals<E: NFloatingPoint>(_ lhs: E, _ rhs: E) -> Bool {
	let tolerance: E = E(_tol)
	return abs(rhs - lhs) <= tolerance
}

func equals<DT: NDimensionalArray>(_ lhs: DT, _ rhs: DT) -> Bool where DT.Element: NFloatingPoint {
	let tolerance: DT.Element = DT.Element(_tol)
	return lhs.isEqual(to: rhs, tolerance: tolerance)
}

func timed(_ label: String, block: ()->()) {
	let date = Date()
	block()
	print(label, -date.timeIntervalSinceNow)
}

//
//func equals<E: NValue>(_ lhs: NVector<E>, _ rhs: NVector<E>) -> Bool where E: NFloatingPoint {
//	let tolerance: E = E(_tol)
//	return lhs.isEqual(to: rhs, tolerance: tolerance)
//}
//
//func equals<E: NValue>(_ lhs: NMatrix<E>, _ rhs: NMatrix<E>) -> Bool where E: NFloatingPoint {
//	let tolerance: E = E(_tol)
//	return lhs.isEqual(to: rhs, tolerance: tolerance)
//}

func printHeader(_ header: String) {
	print("\n\n\n*** \(header) ***")
}

class CeedNumerics_tests_mac: XCTestCase {
	override func setUp() {
		// Put setup code here. This method is called before the invocation of each test method in the class.

	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
	}
	
	func testLinearSolver() {
		printHeader("Solver")
		
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
		printHeader("Numerics")
		
		let mat = NMatrixd(rows: 3, columns: 4)
		let vec = NVectord(size: 5)
		vec[3] = 3.0
		mat[2, 1] = 27.0
		print("vec: \n\(vec)")
		print("mat: \n\(mat)")
		
		print("row: \n\(mat[row: 2])")
		print("column: \n\(mat[column: 1])")
//		print("column: \n\(mat[column: 5])")
		let slice = mat[2 ~~ -1, ~]
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
		print("mat (unbounded read): \n\(mat[~, 0~~])")
		mat[~, 0~~] = 2.0*mat
		print("mat (unbounded write): \n\(mat[~, 0~~])")
		print("mat (unbounded 1st col): \n\(mat[~, 0])")
		let i=2
		mat[~i, (i-1)~].set(7.0)
		print("mat (after sliced set): \n\(mat)")
		print("mat (negative index): \n\(mat[-1, -1])")
		print("mat (negative index row): \n\(mat[-1, ~])")
		print("mat (negative index column): \n\(mat[~, -2])")

		
		let linv : NVectord = .linspace(start: 0.0, stop: 10.0, count: 10)
		print("linspace: \(linv)")
		print("neg index: \(linv[-1])")
		print("neg index slice: \(linv[-5 ~ -1])")
	}
	
	func testOps() {
		let tensor = NTensord.ramp(size: [3,3,3])
		let matrix = NMatrixd.ramp(size: NQuadraticIndex(3,3))
		let vector = NVectord.ramp(size: 3)

		let tmean = Numerics.mean(tensor)
		let mmean = Numerics.mean(matrix)
		let vmean = Numerics.mean(vector)
		
		print("tensor: \(tensor)")
		print("tensor negative index: \(tensor[-1,-1,-1])")
		print("tensor negative slice: \(tensor[(-1)~~ , NSlice.all, NSlice.all])")

		print("tensor: \(tensor)\nmean: \(tmean)")
		print("matrix: \(matrix)\nmean: \(mmean)")//" \((0..<9).reduce(0.0) {$0 + Double($1*$1)}/9.0)")
		print("vector: \(vector)\nmean: \(vmean)")
		
		XCTAssert(equals(tmean, 13.0))
		XCTAssert(equals(mmean, 4.0))
		XCTAssert(equals(vmean, 1.0))
		
		let tmean2 = Numerics.meanSquare(tensor)
		let mmean2 = Numerics.meanSquare(matrix)
		let vmean2 = Numerics.meanSquare(vector)
		
		print("tensor mean 2: \(tmean2)")
		print("matrix mean 2: \(mmean2)")
		print("vector mean 2: \(vmean2)")
//
		XCTAssert(equals(tmean2, 229.666666))
		XCTAssert(equals(mmean2, 22.666666))
		XCTAssert(equals(vmean2, 1.666666))
		
		let (tmin, tmax) = (Numerics.minimum(tensor), Numerics.maximum(tensor))
		let (mmin, mmax) = (Numerics.minimum(matrix), Numerics.maximum(matrix))
		let (vmin, vmax) = (Numerics.minimum(vector), Numerics.maximum(vector))
		
		print("tensor min/max: \(tmin) \(tmax)")
		print("matrix min/max: \(mmin) \(mmax)")
		print("vector min/max: \(vmin) \(vmax)")
		
		XCTAssert(equals(tmin, 0.0) && equals(tmax, 26.0))
		XCTAssert(equals(mmin, 0.0) && equals(mmax, 8.0))
		XCTAssert(equals(vmin, 0.0) && equals(vmax, 2.0))
	}
	
	func testDimensionality() {
		printHeader("Dimensionality")
		
		let vec = NVectord.range(stop: 12.0)
		XCTAssert(Numerics.mean(vec) - 5.5 < _tol)
		print("Vec: \(vec)")
		
		let rowmat = vec.asMatrix()
		print("Row Mat: \(rowmat)")
		let fcop = rowmat.flatten()
		
		let mat = rowmat.reshaping(rows: 3, columns: 4)
		print("Mat: \(mat)")
		mat[1,3] = 36.0
		print("Vec: \(vec)")
		
		let mat2 = rowmat.reshaping(rows: 2, columns: -1)
		print("Mat: \(mat2)")
		print("Flattened earlier copy: \(fcop)")
	}
	
	func testAPIs() {
		printHeader("API")
		
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
		
		let smat = mat[0~4, 0~3~2].transposed()
		
		XCTAssert(equals(smat, NMatrixd( [[1.0,1.0,1.0,-1.0],
										  [3.0,3.0,1.0,1.0]])
		))
		
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
		printHeader("Masked & Indexed")
		
		let v1: NVectord = .linspace(start: 0.0, stop: 50.0, count: 51)
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
		printHeader("Misc")
		let v1 = NVectorf([1.0, 2.0, 3.0])
		let v2 = NVectorf([4.0, 5.0, 6.0])
		
		// Test Vector.set()
		v1.set(from: v2)
		
		print("v1: \(v1.description)")
		print("v2: \(v2.description)")
		
		XCTAssert(equals(v1, v2))
		
		
	}
	
	func testBasicTensors() {
//		let tensor1 = NTensord(repeating: 1.0, size: [3,3,4])
//		let tensor2 = NTensord(repeating: 0.2, size: [3,3,4])
//		let tensor3 = Numerics.subtract(tensor1, tensor2)
		
		//let tensor1 = NTensord(repeating: 1.0, size: [3,3,4,3])
		let tensor1 = NTensord.ramp(size: [3,3,4,3])
		let tensor2 = NTensord(repeating: 0.2, size: [3,3,4,3])
		let tensor3 = Numerics.subtract(tensor1, tensor2)
		
		print("tensor: \n\(tensor3)")
		
//		print("matrix: \n\(NMatrixd.ramp(size: NQuadraticIndex(4,5)))")
//		let tensorA = Tensord(dimensions: [3,3,2], repeatedValue: 1.0)
//		let slice = tensorA[1..<3, 1..<3, 0..<1]
////		let slice = tensorA[1..<3, 1..<3, 1..<2]
//
//		tensorA[1,1,1] = 27.0
//		print("tensor: \n\(tensorA)")
//		print("slice: \n\(slice)")
	}

	func testTensorSlicing() {
//		let tensor = NTensord.ramp(size: [3,2,4,3])
//		let stensor1 = tensor[0, 0~, all, all]
//		let sval: Double = tensor[1,1,1,1]

		let tensor = NTensord.ramp(size: [2,2,2])
		let stensor1 = tensor[n.all, 1, n.all]
		let stensor2 = tensor.insertingNewAxis(at: 0).insertingNewAxis(at: 3)
		let stensor3 = tensor[n.all, 1, n.newaxis, n.all, n.newaxis]
		let sval: Double = tensor[1,1,1]


		print("tensor: \(tensor)")
		print("sub tensor: \(stensor1)")
		print("new axis tensor: \(stensor2)")

		print("new axis tensor subscript: \(stensor3)")

		print("s1: \(stensor1.shape)")
		print("val: \(sval)")
	}
	
	func testIteratorSpeed() {
		let t1 = NTensorf.ramp(size: [10,100,100])
		let t2 = NTensorf(repeating: 0.0, size: t1.size)
			
		timed("c_sp") { t2._set(from: t1, variant: .cStrided) }
		timed("c_nosp") { t2._set(from: t1, variant: .cStridedNoSpecific) }
		timed("sw_mc") { t2._set(from: t1, variant: .swiftPointer) }
		timed("sw_nomc") { t2._set(from: t1, variant: .swiftPointerNoMemCopy) }
		timed("sw_ind") { t2._set(from: t1, variant: .swiftIndicesTraversal) }
		timed("sw_stt") { t2._set(from: t1, variant: .swiftStorageTraversal) }
		timed("sw_dir") { t2._set(from: t1, variant: .swiftDirect) }
		
		timed("sw_const1") { t2._set(from: t1, variant: .swiftConstant1) }
		timed("sw_const2") { t2._set(from: t1, variant: .swiftConstant2) }
		
		print(t2[0, 0, 2])
		
//		timed {
//			let t1 = NMatrixd.ramp(size: NQuadraticIndex(1000, 1000))
//		}
		
//		let t2 = NTensord.ramp(size: [100,100,100])
		
		
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
//	func testPerformanceXLoop() {
//		// This is an example of a performance test case.
//		self.measure {
//			// Put the code you want to measure the time of here.
//			let indices = XQuadraticIndexRange(rows: 1000, columns: 1000)
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
