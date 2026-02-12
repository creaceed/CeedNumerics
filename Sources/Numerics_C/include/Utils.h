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

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

// Setter
extern void strided_set_float(long rank, long const *shape, size_t bpe, float *dest, size_t const *dstrides, float const *src, size_t const *sstrides);
extern void strided_set_gen(long rank, long const *shape, size_t bpe, void *dest, size_t const *dstrides, void const *src, size_t const *sstrides);

// In-place flipping
extern void flip_gen(long rank, long const *shape, size_t bpe, void *dest, size_t const *dstrides, const bool *axes);

// UInt16 bit shifts (strided)
extern void strided_shift_left_u16(long count, uint16_t const *src, long sstride, uint16_t *dest, long dstride, int bits);
extern void strided_shift_right_u16(long count, uint16_t const *src, long sstride, uint16_t *dest, long dstride, int bits);
extern void strided_shift_left_u8(long count, uint8_t const *src, long sstride, uint8_t *dest, long dstride, int bits);
extern void strided_shift_right_u8(long count, uint8_t const *src, long sstride, uint8_t *dest, long dstride, int bits);
extern void strided_shift_left_u32(long count, uint32_t const *src, long sstride, uint32_t *dest, long dstride, int bits);
extern void strided_shift_right_u32(long count, uint32_t const *src, long sstride, uint32_t *dest, long dstride, int bits);
extern void strided_shift_left_u64(long count, uint64_t const *src, long sstride, uint64_t *dest, long dstride, int bits);
extern void strided_shift_right_u64(long count, uint64_t const *src, long sstride, uint64_t *dest, long dstride, int bits);
