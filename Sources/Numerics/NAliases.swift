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

public typealias NVectorh = NTensor<NOpaqueFloat16>
public typealias NVectorf = NVector<Float>
public typealias NVectord = NVector<Double>
public typealias NVectori = NVector<Int>
public typealias NVectorb = NVector<Bool>

public typealias NMatrixh = NTensor<NOpaqueFloat16>
public typealias NMatrixf = NMatrix<Float>
public typealias NMatrixd = NMatrix<Double>
public typealias NMatrixi = NMatrix<Int>
public typealias NMatrixb = NMatrix<Bool>

public typealias NTensorh = NTensor<NOpaqueFloat16>
public typealias NTensorf = NTensor<Float>
public typealias NTensord = NTensor<Double>
public typealias NTensori = NTensor<Int>
public typealias NTensorb = NTensor<Bool>
