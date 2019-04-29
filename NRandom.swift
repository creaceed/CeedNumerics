//
//  NRandom.swift
//  CeedNumerics
//
//  Created by Raphael Sebbe on 28/04/2019.
//  Copyright © 2019 Creaceed. All rights reserved.
//

import Foundation

// Public API

// Public API
public struct NSeededRandomNumberGenerator: RandomNumberGenerator {
	private var _generator: MersenneTwister
	
	public init(seed: Int = 0) {
		_generator = MersenneTwister(seed: numericCast(seed))
		_ = _generator.next() // it appears to fire twice the same value initially
	}
	
	public mutating func next() -> UInt64 {
		return _generator.next()
	}
}


// Mersenne Twister implementation from https://github.com/mattgallagher/CwlUtils
internal protocol _RandomGenerator: RandomNumberGenerator {
	mutating func randomize(buffer: UnsafeMutableRawBufferPointer)
}

extension _RandomGenerator {
	public mutating func randomize<Value>(value: inout Value) {
		withUnsafeMutablePointer(to: &value) { ptr in
			self.randomize(buffer: UnsafeMutableRawBufferPointer(start: ptr, count: MemoryLayout<Value>.size))
		}
	}
}

internal struct DevRandom: _RandomGenerator {
	class FileDescriptor {
		let value: CInt
		init() {
			value = open("/dev/urandom", O_RDONLY)
			precondition(value >= 0)
		}
		deinit {
			close(value)
		}
	}
	
	let fd: FileDescriptor
	public init() {
		fd = FileDescriptor()
	}
	
	public mutating func randomize(buffer: UnsafeMutableRawBufferPointer) {
		let result = read(fd.value, buffer.baseAddress, buffer.count)
		precondition(result == buffer.count)
	}
	
	public mutating func next() -> UInt64 {
		var bits: UInt64 = 0
		withUnsafeMutablePointer(to: &bits) { ptr in
			self.randomize(buffer: UnsafeMutableRawBufferPointer(start: ptr, count: MemoryLayout<UInt64>.size))
		}
		return bits
	}
}

internal struct MersenneTwister: RandomNumberGenerator {
	// 312 words of storage is 13 x 6 x 4
	private typealias StateType = (
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64,
		UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64
	)
	
	private var state_internal: StateType = (
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	)
	private var index: Int
	private static let stateCount: Int = 312
	
	public init() {
		var dr = DevRandom()
		dr.randomize(value: &state_internal)
		index = MersenneTwister.stateCount
	}
	
	public init(seed: UInt64) {
		index = MersenneTwister.stateCount
		withUnsafeMutablePointer(to: &state_internal) { $0.withMemoryRebound(to: UInt64.self, capacity: MersenneTwister.stateCount) { state in
			state[0] = seed
			for i in 1..<MersenneTwister.stateCount {
				state[i] = 6364136223846793005 &* (state[i &- 1] ^ (state[i &- 1] >> 62)) &+ UInt64(i)
			}
			} }
	}
	
	public mutating func next() -> UInt64 {
		if index == MersenneTwister.stateCount {
			withUnsafeMutablePointer(to: &state_internal) { $0.withMemoryRebound(to: UInt64.self, capacity: MersenneTwister.stateCount) { state in
				let n = MersenneTwister.stateCount
				let m = n / 2
				let a: UInt64 = 0xB5026F5AA96619E9
				let lowerMask: UInt64 = (1 << 31) - 1
				let upperMask: UInt64 = ~lowerMask
				var (i, j, stateM) = (0, m, state[m])
				repeat {
					let x1 = (state[i] & upperMask) | (state[i &+ 1] & lowerMask)
					state[i] = state[i &+ m] ^ (x1 >> 1) ^ ((state[i &+ 1] & 1) &* a)
					let x2 = (state[j] & upperMask) | (state[j &+ 1] & lowerMask)
					state[j] = state[j &- m] ^ (x2 >> 1) ^ ((state[j &+ 1] & 1) &* a)
					(i, j) = (i &+ 1, j &+ 1)
				} while i != m &- 1
				
				let x3 = (state[m &- 1] & upperMask) | (stateM & lowerMask)
				state[m &- 1] = state[n &- 1] ^ (x3 >> 1) ^ ((stateM & 1) &* a)
				let x4 = (state[n &- 1] & upperMask) | (state[0] & lowerMask)
				state[n &- 1] = state[m &- 1] ^ (x4 >> 1) ^ ((state[0] & 1) &* a)
				} }
			
			index = 0
		}
		
		var result = withUnsafePointer(to: &state_internal) { $0.withMemoryRebound(to: UInt64.self, capacity: MersenneTwister.stateCount) { ptr in
			return ptr[index]
			} }
		index = index &+ 1
		
		result ^= (result >> 29) & 0x5555555555555555
		result ^= (result << 17) & 0x71D67FFFEDA60000
		result ^= (result << 37) & 0xFFF7EEE000000000
		result ^= result >> 43
		
		return result
	}
}
