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

extension Numerics {
	// MARK: - Storage Access
	public static func withStorageAccess<T: NStorageAccessible, Result>(_ a: T, _ access: (T.Access) throws -> Result) rethrows -> Result where T.Element == Element {
		return try a._withStorageAccess { acc in
			return try access(acc)
		}
	}
	public static func withStorageAccess<T: NStorageAccessible, T2: NStorageAccessible, Result>(_ a: T, _ b: T2, _ access: (_ aa: T.Access, _ ba: T2.Access) throws -> Result) rethrows -> Result where T.Element == Element {
		return try a._withStorageAccess { acc in
			return try b._withStorageAccess { bacc in
				return try access(acc, bacc)
			}
		}
	}
	public static func withStorageAccess<T: NStorageAccessible, Result>(_ a: T, _ b: T, _ c: T, _ access: (_ aa: T.Access, _ ba: T.Access, _ ca: T.Access) throws -> Result) rethrows -> Result where T.Element == Element {
		return try a._withStorageAccess { aacc in
			return try b._withStorageAccess { bacc in
				return try c._withStorageAccess { cacc in
					return try access(aacc, bacc, cacc)
				}
			}
		}
	}
	
	// Any dimensional type is converted into sequences of linear accesses (with possible coalescing, ie, all rows as a single linear space, if container is compact)
	// Makes sense for Accelerate processing
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ access: (Storage.LinearAccess) -> Void) where T.Element == Element {
		a._withStorageAccess { aacc in
			for alin in aacc.linearized(coalesce: true) {
				access(alin)
			}
		}
	}
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ b: T, _ access: (Storage.LinearAccess, Storage.LinearAccess) -> Void) where T.Element == Element {
		precondition(a.size == b.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				let coalesce = aacc.compact && bacc.compact
				for (alin, blin) in zip(aacc.linearized(coalesce: coalesce), bacc.linearized(coalesce: coalesce)) {
					access(alin, blin)
				}
			}
		}
	}
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ access: (Storage.LinearAccess, Storage.LinearAccess, Storage.LinearAccess) -> Void) where T.Element == Element {
		precondition(a.size == b.size && a.size == c.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				c._withStorageAccess { cacc in
					let coalesce = aacc.compact && bacc.compact && cacc.compact
					for (alin, (blin, clin)) in zip(aacc.linearized(coalesce: coalesce), zip(bacc.linearized(coalesce: coalesce), cacc.linearized(coalesce: coalesce))) {
						access(alin, blin, clin)
					}
				}
			}
		}
	}
	public static func withLinearizedAccesses<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ d: T, _ access: (Storage.LinearAccess, Storage.LinearAccess, Storage.LinearAccess, Storage.LinearAccess) -> Void) where T.Element == Element {
		precondition(a.size == b.size && a.size == c.size && a.size == d.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				c._withStorageAccess { cacc in
					d._withStorageAccess { dacc in
						let coalesce = aacc.compact && bacc.compact && cacc.compact && dacc.compact
						for (alin, (blin, (clin, dlin))) in zip(aacc.linearized(coalesce: coalesce), zip(bacc.linearized(coalesce: coalesce), zip(cacc.linearized(coalesce: coalesce), dacc.linearized(coalesce: coalesce)))) {
							access(alin, blin, clin, dlin)
						}
					}
				}
			}
		}
	}
	// MARK: - Storage/Value Stride
	
	
	// TODO: see direct approach + try access block. Can also try joint1x, joint2x, jointNx implementation (protocol), to avoid multi-iterator termination test overhead (same shape).
	internal static func withAddresses<T: NStorageAccessible>(_ a: T, _ block: (_ pointer: UnsafeMutablePointer<Element>) -> Void) where T.Element == Element {
		a._withStorageAccess { aacc in
			// single arg -> we can always (try to) coalesce
			for alin in aacc.linearized(coalesce: true) {
				for p in alin.pointers {
					block(p)
				}
			}
		}
	}
	public static func withValues<T: NStorageAccessible>(_ a: T, _ block: (_ value: Element) -> Void) where T.Element == Element { return withAddresses(a) { block($0.pointee) } }
	
	public static func withAddresses<T: NStorageAccessible>(_ a: T, _ b: T, _ block: (_ pa: UnsafeMutablePointer<Element>, _ pb: UnsafeMutablePointer<Element>) -> Void) where T.Element == Element {
		precondition(a.size == b.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				// 2 arg -> (try to) coalesce only if both are compact
				let coalesce = aacc.compact && bacc.compact
				for (alin, blin) in zip(aacc.linearized(coalesce: coalesce), bacc.linearized(coalesce: coalesce)) {
					for (pa, pb) in zip(alin.pointers, blin.pointers) {
						block(pa, pb)
					}
				}
			}
		}
	}
	public static func withValues<T: NStorageAccessible>(_ a: T, _ b: T, _ block: (_ pa: Element, _ pb: Element)->Void) where T.Element == Element { return withAddresses(a, b) { block($0.pointee, $1.pointee) } }
	
	public static func withAddresses<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ block: (_ pa: UnsafeMutablePointer<Element>, _ pb: UnsafeMutablePointer<Element>, _ pc: UnsafeMutablePointer<Element>) -> Void) where T.Element == Element {
		precondition(a.size == b.size && b.size == c.size)
		a._withStorageAccess { aacc in
			b._withStorageAccess { bacc in
				c._withStorageAccess { cacc in
					// 2 arg -> (try to) coalesce only if both are compact
					let coalesce = aacc.compact && bacc.compact && cacc.compact
					for (alin, (blin, clin)) in zip(aacc.linearized(coalesce: coalesce), zip(bacc.linearized(coalesce: coalesce), cacc.linearized(coalesce: coalesce))) {
						for (pa, (pb, pc)) in zip(alin.pointers, zip(blin.pointers, clin.pointers)) {
							block(pa, pb, pc)
						}
					}
				}
			}
		}
	}
	public static func withValues<T: NStorageAccessible>(_ a: T, _ b: T, _ c: T, _ block: (_ pa: Element, _ pb: Element, _ pc: Element)->Void) where T.Element == Element { return withAddresses(a, b, c) { block($0.pointee, $1.pointee, $2.pointee) } }
}
