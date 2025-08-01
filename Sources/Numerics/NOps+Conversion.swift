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

public struct NConversionOptions {
	public init() {}
}

//	public func set<DA_F16: NDimensionalArray>(from source: DA_F16, options: NConversionOptions = .init()) throws {
//		try Numerics.withStorageAccess(self, source) { dacc, sacc in
//			guard var svim = sacc.compactBufferAsVImage else { throw NError.invalidArgument }
//			guard var dvim = dacc.compactBufferAsVImage else { throw NError.invalidArgument }
//			guard svim.width == dvim.width else { throw NError.invalidArgument }
//
//			let err = vImageConvert_Planar16FtoPlanarF(&svim, &dvim, 0)
//			if err != kvImageNoError { throw NError.accelerateError(err: err) }
//		}
//	}
//}

extension Numerics {
	// MARK: - Type Conversions
	// Float16 related
	//extension NDimensionalArray where Element == Float {
	//	// source and destination must be compact / have the same number of elements
	public static func convert<DT1: NDimensionalArray, DT2: NDimensionalArray>(_ source: DT1, to result: DT2, options: NConversionOptions = .init()) where DT1.Element == Element {
		precondition(source.shape == result.shape)
		
		Numerics.withStorageAccess(source, result) { (sacc: DT1.Access, dacc: DT2.Access) in
			guard var svim = sacc.compactBufferAsVImage else { fatalError("not supported") }
			guard var dvim = dacc.compactBufferAsVImage else { fatalError("not supported") }
			guard svim.width == dvim.width else { fatalError("not supported") }
			
			let err: vImage_Error
			if (DT1.Element.self == NOpaqueFloat16.self || DT1.Element.self == NFloat16.self) && DT2.Element.self == Float.self {
				err = vImageConvert_Planar16FtoPlanarF(&svim, &dvim, 0)
			} else if DT1.Element.self == Float.self && (DT2.Element.self == NOpaqueFloat16.self || DT2.Element.self == NFloat16.self) {
				err = vImageConvert_PlanarFtoPlanar16F(&svim, &dvim, 0)
			} else {
				fatalError("not supported")
			}
			if err != kvImageNoError { fatalError("internal error") }
		}
	}
	// MARK: - Layout Conversions
	// source must have shape [X,... Z, 4], result [4, X, ... Z]
	// for now, they must be compact
	public static func deinterleave4(_ source: NTensor<Element>, _ result: NTensor<Element>) {
		precondition(source.rank == result.rank)
		precondition(source.shape.last! == 4)
		precondition(result.shape.first! == 4)
		precondition(source.shape.prefix(source.rank - 1) == result.shape.suffix(from: 1))
		precondition(source.compact && result.compact)
		
		try! Numerics.withStorageAccess(result, source) { racc, sacc in
//			guard var svim = sacc.compactBufferAsVImage else { throw NError.invalidArgument }
//			guard var dvim = racc.compactBufferAsVImage else { throw NError.invalidArgument }
//			guard svim.width == dvim.width else { throw NError.invalidArgument }
			
			guard let sbuf: UnsafeMutableBufferPointer<Element> = sacc.compactBuffer else { throw NError.invalidArgument }
			guard let dbuf: UnsafeMutableBufferPointer<Element> = racc.compactBuffer else { throw NError.invalidArgument }
			guard dbuf.count == sbuf.count else { throw NError.invalidArgument }
			
			let bpe = MemoryLayout<Element>.stride
			let h = 1, w = sbuf.count / 4 // because RGBA
			
			// Note: baseAddress is types as pointer to Element 
			var svim = vImage_Buffer(data: sbuf.baseAddress!, height: numericCast(h), width: numericCast(w), rowBytes: bpe * w * 4)
			var dvim_r = vImage_Buffer(data: dbuf.baseAddress! + (w * h * 0), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
			var dvim_g = vImage_Buffer(data: dbuf.baseAddress! + (w * h * 1), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
			var dvim_b = vImage_Buffer(data: dbuf.baseAddress! + (w * h * 2), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
			var dvim_a = vImage_Buffer(data: dbuf.baseAddress! + (w * h * 3), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
			
			switch bpe {
				case 2:
					vImageConvert_ARGB16UtoPlanar16U(&svim, &dvim_r, &dvim_g, &dvim_b, &dvim_a, 0)
				case 4:
					vImageConvert_ARGBFFFFtoPlanarF(&svim, &dvim_r, &dvim_g, &dvim_b, &dvim_a, 0)
				default:
					throw NError.notImplemented
			}

		}
		// withLinearizedAccesses(a, b, result) { aacc, bacc, racc in
		// 	Element.mx_vsub(aacc.base, aacc.stride, bacc.base, bacc.stride, racc.base, racc.stride, numericCast(racc.count))
		// }
	}
	public static func interleave4(_ source: NTensor<Element>, _ result: NTensor<Element>) {
			precondition(source.rank == result.rank)
			precondition(result.shape.last! == 4)
			precondition(source.shape.first! == 4)
			precondition(result.shape.prefix(result.rank - 1) == source.shape.suffix(from: 1))
			precondition(source.compact && result.compact)
			
			try! Numerics.withStorageAccess(result, source) { racc, sacc in
				guard let sbuf: UnsafeMutableBufferPointer<Element> = sacc.compactBuffer else { throw NError.invalidArgument }
				guard let dbuf: UnsafeMutableBufferPointer<Element> = racc.compactBuffer else { throw NError.invalidArgument }
				guard dbuf.count == sbuf.count else { throw NError.invalidArgument }
				
				let bpe = MemoryLayout<Element>.stride
				let h = 1, w = dbuf.count / 4 // because RGBA
				
				// Note: baseAddress is types as pointer to Element
				var dvim = vImage_Buffer(data: dbuf.baseAddress!, height: numericCast(h), width: numericCast(w), rowBytes: bpe * w * 4)
				var svim_r = vImage_Buffer(data: sbuf.baseAddress! + (w * h * 0), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
				var svim_g = vImage_Buffer(data: sbuf.baseAddress! + (w * h * 1), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
				var svim_b = vImage_Buffer(data: sbuf.baseAddress! + (w * h * 2), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
				var svim_a = vImage_Buffer(data: sbuf.baseAddress! + (w * h * 3), height: numericCast(h), width: numericCast(w), rowBytes: bpe * w)
				
				switch bpe {
					case 2:
						vImageConvert_Planar16UtoARGB16U(&svim_r, &svim_g, &svim_b, &svim_a, &dvim, 0)
					case 4:
						vImageConvert_PlanarFtoARGBFFFF(&svim_r, &svim_g, &svim_b, &svim_a, &dvim, 0)
					default:
						throw NError.notImplemented
				}

			}
			// withLinearizedAccesses(a, b, result) { aacc, bacc, racc in
			// 	Element.mx_vsub(aacc.base, aacc.stride, bacc.base, bacc.stride, racc.base, racc.stride, numericCast(racc.count))
			// }
		}
}

