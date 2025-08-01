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

public struct NGlobals {
	// introduced 'all', because tensor[~, 1, ~] syntax is rejected (multiple candidates for ~)
	public let all: NSlice = .all
	public let flip: NSlice = .init(start: nil, end: nil, step: -1)
	public let newaxis: NAxisOperator = .new
	
	public init() {}
}

// namespace for global constants.
let n = NGlobals()


// NFloat16 is Float16 for platforms that suport it, and UInt16 for other
// This allows simpler use at call site with a single type (NFloat16) for
// both platforms when only storage is needed (GPU send/receive, etc).
//
// NFloat16.asFloat16(_: Float) can provide values in array initializers like
// init(repeating: _) on both platforms from same code.

#if arch(arm64)
//@available(macOS 11.0, iOS 14.0, macCatalyst 14.0, *)
public typealias NFloat16 = Float16
#else
public typealias NFloat16 = NOpaqueFloat16
#endif

extension NGlobals {
	static func isFloat16Supported() -> Bool {
		return NFloat16.self != NOpaqueFloat16.self
	}
}

public typealias NVectorh = NTensor<NFloat16>
public typealias NVectorf = NVector<Float>
public typealias NVectord = NVector<Double>
public typealias NVectori = NVector<Int>
public typealias NVectorb = NVector<Bool>

public typealias NMatrixh = NTensor<NFloat16>
public typealias NMatrixf = NMatrix<Float>
public typealias NMatrixd = NMatrix<Double>
public typealias NMatrixi = NMatrix<Int>
public typealias NMatrixb = NMatrix<Bool>

public typealias NTensorh = NTensor<NFloat16>
public typealias NTensorf = NTensor<Float>
public typealias NTensord = NTensor<Double>
public typealias NTensori = NTensor<Int>
public typealias NTensorb = NTensor<Bool>
