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
import Numerics_C

extension Numerics where Element == UInt16 {
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_left_u16(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_right_u16(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftLeft(a, by: bits, $0) }
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftRight(a, by: bits, $0) }
	}
}

extension NDimensionalArray where Element == UInt16 {
	public static func <<(lhs: Self, rhs: Int) -> Self { return Numerics.shiftLeft(lhs, by: rhs) }
	public static func >>(lhs: Self, rhs: Int) -> Self { return Numerics.shiftRight(lhs, by: rhs) }
	
	public static func <<=(lhs: Self, rhs: Int) { Numerics.shiftLeft(lhs, by: rhs, lhs) }
	public static func >>=(lhs: Self, rhs: Int) { Numerics.shiftRight(lhs, by: rhs, lhs) }
}

extension Numerics where Element == UInt8 {
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_left_u8(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_right_u8(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftLeft(a, by: bits, $0) }
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftRight(a, by: bits, $0) }
	}
}

extension NDimensionalArray where Element == UInt8 {
	public static func <<(lhs: Self, rhs: Int) -> Self { return Numerics.shiftLeft(lhs, by: rhs) }
	public static func >>(lhs: Self, rhs: Int) -> Self { return Numerics.shiftRight(lhs, by: rhs) }
	
	public static func <<=(lhs: Self, rhs: Int) { Numerics.shiftLeft(lhs, by: rhs, lhs) }
	public static func >>=(lhs: Self, rhs: Int) { Numerics.shiftRight(lhs, by: rhs, lhs) }
}

extension Numerics where Element == UInt32 {
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_left_u32(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_right_u32(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftLeft(a, by: bits, $0) }
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftRight(a, by: bits, $0) }
	}
}

extension NDimensionalArray where Element == UInt32 {
	public static func <<(lhs: Self, rhs: Int) -> Self { return Numerics.shiftLeft(lhs, by: rhs) }
	public static func >>(lhs: Self, rhs: Int) -> Self { return Numerics.shiftRight(lhs, by: rhs) }
	
	public static func <<=(lhs: Self, rhs: Int) { Numerics.shiftLeft(lhs, by: rhs, lhs) }
	public static func >>=(lhs: Self, rhs: Int) { Numerics.shiftRight(lhs, by: rhs, lhs) }
}

extension Numerics where Element == UInt64 {
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_left_u64(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int, _ result: DT) where DT.Element == Element {
		precondition(bits >= 0)
		precondition(a.size == result.size)
		
		withLinearizedAccesses(a, result) { aacc, racc in
			strided_shift_right_u64(
				numericCast(aacc.count),
				aacc.base,
				numericCast(aacc.stride),
				racc.base,
				numericCast(racc.stride),
				CInt(bits)
			)
		}
	}
	
	public static func shiftLeft<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftLeft(a, by: bits, $0) }
	}
	
	public static func shiftRight<DT: NDimensionalArray>(_ a: DT, by bits: Int) -> DT where DT.Element == Element {
		return a._deriving { shiftRight(a, by: bits, $0) }
	}
}

extension NDimensionalArray where Element == UInt64 {
	public static func <<(lhs: Self, rhs: Int) -> Self { return Numerics.shiftLeft(lhs, by: rhs) }
	public static func >>(lhs: Self, rhs: Int) -> Self { return Numerics.shiftRight(lhs, by: rhs) }
	
	public static func <<=(lhs: Self, rhs: Int) { Numerics.shiftLeft(lhs, by: rhs, lhs) }
	public static func >>=(lhs: Self, rhs: Int) { Numerics.shiftRight(lhs, by: rhs, lhs) }
}
