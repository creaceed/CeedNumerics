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

// MARK: - Vector Ops
extension Numerics where Element: NAccelerateFloatingPoint {
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
			Element.mx_conv(iaccess.base, numericCast(iaccess.stride), kaccess.base, numericCast(kaccess.stride), oaccess.base, numericCast(oaccess.stride), numericCast(oaccess.count), numericCast(kaccess.count))
		}
	}
	
	public static func pad(input: Vector, before: Int, after: Int, mode: PaddingMode = .edge, output: Vector) {
		precondition(before >= 0)
		precondition(after >= 0)
		precondition(input.size > 0) // for edge mode
		
		let afterstart = before+input.size
		
		output[before ..< afterstart] = input
		output[0 ..< before] = NVector(repeating: input.first!, size: before)
		output[afterstart ..< output.size] = NVector(repeating: input.last!, size: after)
	}
	
	public static func cumsum(_ a: Vector) -> Vector {
		precondition(a.size > 0)
		let result = a.copy()
		
		// because of vDSP implementation
		if a.size > 1 {
			result[1] = result[0] + result[1]
		}
		
		withStorageAccess(result) { racc in
			// in-place. OK?
			Element.mx_vrsum(racc.base, numericCast(racc.stride), 1.0, racc.base, numericCast(racc.stride), numericCast(racc.count))
		}
		result[0] = a[0]
		return result
	}
}

// MARK: - Vector: Deriving new ones + operators
extension NVector where Element: NAccelerateFloatingPoint {
	public static func zeros(count: Int) -> Self { return Self.zeros(size: count) }
	public static func ones(count: Int) -> Self { return Self.ones(size: count) }
	/// Creation of vectors
	// note: stop is included
	public static func linspace(start: Element, stop: Element, count: Int, output: Vector) {
		precondition(count == output.size)
		precondition(count >= 2)
		
		Numerics.withStorageAccess(output) { oaccess in
			Element.mx_vramp(start, (stop-start)/Element(count-1), oaccess.base, numericCast(oaccess.stride), numericCast(oaccess.count))
		}
	}
	public static func linspace(start: Element, stop: Element, count: Int) -> Vector {
		precondition(count >= 2)
		let output = Vector(size: count)
		linspace(start: start, stop: stop, count: count, output: output)
		return output
	}
	
	// note: stop is not included
	public static func range(start: Element = 0.0, stop: Element, step: Element = 1.0) -> Vector {
		precondition((stop - start) * step > 0.0)
		precondition(step != 0.0)
		
		// predictable count
		let count: Int = ceil((stop - start) / step).roundedIntValue
		
		return linspace(start: start, stop: start + Element(count-1)*step, count: count)
	}
	
	
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
	
	// Specific to Vector (only)
	public static func *(lhs: Self, rhs: Self) -> Self { return Numerics.multiplyElements(lhs, rhs) }
	public static func *=(lhs: Self, rhs: Self) { Numerics.multiplyElements(lhs, rhs, lhs) }
	public static func /(lhs: Self, rhs: Self) -> Self { return Numerics.divideElements(lhs, rhs) }
	public static func /=(lhs: Self, rhs: Self) { Numerics.divideElements(lhs, rhs, lhs) }
}
