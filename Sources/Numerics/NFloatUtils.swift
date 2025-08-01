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

extension NFloat16 {
	public static func asFloat16(_ value: Float) -> NFloat16 {
#if arch(arm64)
		return Float16(value)
		// for testing fallback  on Apple Silicon
		// return Float16(floatFromFloat16Bits(float16BitsFromFloat(value)))
#else
		return float16BitsFromFloat(value)
#endif
	}
}


func float16BitsFromFloat(_ value: Float) -> UInt16 {
	let f = value
	let bits = f.bitPattern

	let sign = UInt16((bits >> 16) & 0x8000) // top bit

	let exponent = Int(((bits >> 23) & 0xFF)) - 127 + 15
	var mantissa = UInt16((bits >> 13) & 0x03FF) // top 10 mantissa bits

	if exponent <= 0 {
		// Subnormal or zero
		if exponent < -10 {
			return sign // underflow to zero
		}
		// Subnormal — shift mantissa
		mantissa = UInt16((bits & 0x7FFFFF) | 0x800000) >> (1 - exponent)
		return sign | mantissa
	} else if exponent >= 0x1F {
		// Overflow to Inf or NaN
		if (bits & 0x7FFFFF) != 0 {
			return sign | 0x7FFF // NaN
		} else {
			return sign | 0x7C00 // Inf
		}
	}

	return sign | UInt16(exponent << 10) | mantissa
}

func floatFromFloat16Bits(_ bits: UInt16) -> Float {
	let sign = UInt32(bits & 0x8000) << 16
	var exponent = Int((bits >> 10) & 0x1F)
	let mantissa = UInt32(bits & 0x03FF)

	var fBits: UInt32

	if exponent == 0 {
		if mantissa == 0 {
			// Zero
			fBits = sign
		} else {
			// Subnormal
			exponent = -14
			var m = mantissa
			while (m & 0x0400) == 0 {
				m <<= 1
				exponent -= 1
			}
			m &= 0x3FF
			fBits = sign | UInt32((exponent + 127) << 23) | (m << 13)
		}
	} else if exponent == 0x1F {
		// Inf or NaN
		fBits = sign | 0x7F800000 | (mantissa << 13)
	} else {
		// Normalized
		exponent = exponent - 15 + 127
		fBits = sign | UInt32(exponent << 23) | (mantissa << 13)
	}

	return Float(bitPattern: fBits)
}
