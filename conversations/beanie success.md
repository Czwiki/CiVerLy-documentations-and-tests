date: 2026-07-10T 13:00:00Z
participants:
- You: Henry
- Assistant: Kilo AI, Kimi 2.6 via Neuralwatt
topic: "Implementation of the beanie cipher"

User:
Please implement the beanie cipher according to the specifications of a cipher implementation in  @documentation/README.md .A python reference implementation is available @documentation/beanie.py (and in C @documentation/beanie.c, and @documentation/testcases.c  just for completeness) together with a part of the published paper @documentation/Beanie.md  and figures from the latter @documentation/Screenshot 2026-06-24 at 11.47.24.png @documentation/Screenshot 2026-06-24 at 11.47.59.png . Sage is installed via nix.

... (reading the information)

Let me understand the BEANIE cipher from the reference implementations:

From beanie.py and beanie.c:

BEANIE is a 32-bit block cipher
It uses 4-bit S-boxes
State is organized as 2 columns of 16 bits each (8 nibbles total)
Round function:
AddRoundKey (XOR with round key)
S-box (applied to all 8 nibbles)
ShiftRows (shift32)
MixColumns (mix_columns) - applied to each 16-bit column
For the last round: ARK -> SBox -> Shift -> ARK (no MixColumns)
Number of rounds variable, testcases use 5 rounds
S-box: (0, 4, 2, 11, 10, 12, 9, 8, 5, 15, 13, 3, 7, 1, 6, 14)

Shift32:

def _shift32(state: int) -> int:
    shifted = state & 0xF0F0F0F0
    shifted |= (state & 0x0F0F0000) >> 16
    shifted |= (state & 0x00000F0F) << 16
    return shifted & 0xFFFFFFFF
Let me understand this shift. If the state is viewed as nibbles:

Row 0: n0  n1  n2  n3
Row 1: n4  n5  n6  n7
Row 2: n8  n9  n10 n11  
Row 3: n12 n13 n14 n15
Wait, looking at Figure 3 in the image:

Xi is a 2x4 matrix? No, let me look more carefully.
Xi has indices: 0,1,2,3 on left and 4,5,6,7 on right. That's 8 nibbles.
The state is 32 bits = 8 nibbles.
Actually looking at Figure 3:

Xi:
0 4
1 5
2 6
3 7
This is a 4x2 matrix (4 rows, 2 columns).

After XOR with Ki, goes through SC (substitution), then:

Zi:
0 4
1 5
2 6
3 7
Then shift rows (the <<<1 notation):

Wi:
0 4
5 1
2 6
7 3
So row 1 gets shifted left by 1: 1,5 -> 5,1 Row 3 gets shifted left by 1: 3,7 -> 7,3

Then MixColumns with matrix:

(2  1  1  9)
(1  4  f  1)
(d  9  4  1)
(1  d  1  2)
Wait, that's a 4x4 matrix, but we only have 2 columns...

Looking more carefully at Figure 3:

Xi has 8 cells arranged in 4 rows × 2 columns
Each cell contains a nibble
After S-box, we get Zi which is the same shape
Then shift rows: row 0 stays, row 1 shifts by 1, row 2 stays, row 3 shifts by 1
Then MixColumns: but a 4x4 matrix...
Actually, looking at the matrix in Figure 3, it says:

(2  1  1  9)
(1  4  f  1)
(d  9  4  1)
(1  d  1  2)
This appears to be applied to each column independently. Each column has 4 nibbles, so the 4x4 matrix multiplies a column of 4 nibbles. Since there are 2 columns, it's applied twice.

This is exactly like AES MixColumns but over GF(2^4) instead of GF(2^8).

The shift32 function in C/Python confirms this:

static inline uint32_t shift(uint32_t state) { 
    uint32_t state_shifted = state & 0xf0f0f0f0;
    state_shifted |= ((state & 0x0f0f0000) >> 16);
    state_shifted |= ((state & 0x00000f0f) << 16);
    return state_shifted;
}
If we view the state as:

n0 n4  (bytes: n0 at bits 28-31, n4 at bits 24-27...)
n1 n5
n2 n6
n3 n7
Wait, let me think about bit ordering. The C code uses a union:

typedef union {
    uint32_t state;
    uint16_t column[2];
} state_t;
So column[0] is the lower 16 bits and column[1] is the upper 16 bits? Actually on little-endian, column[0] might be lower... but the code says "weird indecies to due endianess of union", meaning they had to swap.

In key_expansion:

round_keys[0].state = key->column_double[1];
round_keys[1].state = key->column_double[0];
round_keys[2].state = key->column_double[3];
round_keys[3].state = key->column_double[2];
So column_double[1] maps to the first round key. This suggests the state mapping is a bit tricky due to endianness.

For the Python reference, _sbox32 operates on columns:

for column_index in range(2):
    column = (state >> (16 * column_index)) & 0xFFFF
So column 0 is bits 0-15, column 1 is bits 16-31.

For MixColumns:

for column_index in range(2):
    column = (state >> (16 * column_index)) & 0xFFFF
    c0 = (column >> 12) & 0xF
    c1 = (column >> 8) & 0xF
    c2 = (column >> 4) & 0xF
    c3 = column & 0xF
So within a column, c0 is the highest nibble (bits 12-15), c3 is the lowest (bits 0-3).

For the shift:

def _shift32(state: int) -> int:
    shifted = state & 0xF0F0F0F0
    shifted |= (state & 0x0F0F0000) >> 16
    shifted |= (state & 0x00000F0F) << 16
    return shifted & 0xFFFFFFFF
Let's think of the state as 8 nibbles. If we write nibble i at position (4*i) bits:

nibble 0 (bits 0-3): c3 of column 0
nibble 1 (bits 4-7): c2 of column 0
nibble 2 (bits 8-11): c1 of column 0
nibble 3 (bits 12-15): c0 of column 0
nibble 4 (bits 16-19): c3 of column 1
etc.
Wait, that's reversed from what the Python code shows. Let me re-read:

c0 = (column >> 12) & 0xF
c1 = (column >> 8) & 0xF
c2 = (column >> 4) & 0xF
c3 = column & 0xF
So c0 is the top nibble of the column. For a 16-bit column:

bits 12-15: c0
bits 8-11: c1
bits 4-7: c2
bits 0-3: c3
So the state viewed as nibbles from MSB to LSB:

bits 28-31: column[1].c0
bits 24-27: column[1].c1
bits 20-23: column[1].c2
bits 16-19: column[1].c3
bits 12-15: column[0].c0
bits 8-11: column[0].c1
bits 4-7: column[0].c2
bits 0-3: column[0].c3
The shift function:

shifted = state & 0xF0F0F0F0
This keeps nibbles at positions 4,5,6,7 (i.e., bits 4-7, 12-15, 20-23, 28-31) - these are c2, c0 of col 0 and c2, c0 of col 1.

Then:

shifted |= (state & 0x0F0F0000) >> 16
This takes nibbles at positions 4,5 (bits 16-19 and 24-27, i.e., c3, c1 of col 1) and moves them to positions 0,1 (bits 0-3 and 8-11, i.e., c3, c1 of col 0).

Then:

shifted |= (state & 0x00000F0F) << 16
This takes nibbles at positions 0,1 (bits 0-3 and 8-11, i.e., c3, c1 of col 0) and moves them to positions 4,5 (bits 16-19 and 24-27, i.e., c3, c1 of col 1).

So effectively, within each column, the odd-indexed rows (1 and 3) are swapping between columns. Actually, looking at it as rows:

Let me think of it as a 4x2 matrix where entry (r,c) is nibble at row r, column c:

Row 0: c0 of col 0, c0 of col 1
Row 1: c1 of col 0, c1 of col 1
Row 2: c2 of col 0, c2 of col 1
Row 3: c3 of col 0, c3 of col 1
Wait, that's not right either based on bit positions.

Let's look at Figure 3 again:

Xi column 0: 0, 1, 2, 3 (top to bottom)
Xi column 1: 4, 5, 6, 7 (top to bottom)
After shift (<<<1):

Zi:
0  4
1  5  -> row 1 shifted left by 1: 5, 1
2  6
3  7  -> row 3 shifted left by 1: 7, 3
So Wi becomes:

0  4
5  1
2  6
7  3
This is a 4x2 state. Row 0 stays, row 1 shifts left by 1, row 2 stays, row 3 shifts left by 1.

So the ShiftRows operates on rows, where row i consists of the i-th nibble from each column.

If column 0 has nibbles (from top to bottom): n0, n1, n2, n3 And column 1 has nibbles: n4, n5, n6, n7

Then the state matrix is:

n0  n4
n1  n5
n2  n6
n3  n7
ShiftRows:

Row 0: n0, n4 (unchanged)
Row 1: n5, n1 (shifted)
Row 2: n2, n6 (unchanged)
Row 3: n7, n3 (shifted)
So this is a left rotation by row index for each row.

In terms of the 32-bit integer view, what are the bit positions?

From the C code, state_t is a union of uint32_t state and uint16_t column[2].

In little-endian systems, column[0] is bits 0-15 and column[1] is bits 16-31.

Within column[0] (bits 0-15):

bits 12-15: top nibble (row 0, col 0)
bits 8-11: next nibble (row 1, col 0)
bits 4-7: next nibble (row 2, col 0)
bits 0-3: bottom nibble (row 3, col 0)
Within column[1] (bits 16-31):

bits 28-31: top nibble (row 0, col 1)
bits 24-27: next nibble (row 1, col 1)
bits 20-23: next nibble (row 2, col 1)
bits 16-19: bottom nibble (row 3, col 1)
So the mapping from nibble index to bit position in the 32-bit word:

nibble 0 (row 0, col 0): bits 12-15
nibble 1 (row 1, col 0): bits 8-11
nibble 2 (row 2, col 0): bits 4-7
nibble 3 (row 3, col 0): bits 0-3
nibble 4 (row 0, col 1): bits 28-31
nibble 5 (row 1, col 1): bits 24-27
nibble 6 (row 2, col 1): bits 20-23
nibble 7 (row 3, col 1): bits 16-19
ShiftRows:

n0 stays at bits 12-15
n1 (bits 8-11) <-> n5 (bits 24-27)
n2 stays at bits 4-7
n3 (bits 0-3) <-> n7 (bits 16-19)
So the mask operations:

state & 0xF0F0F0F0 keeps bits 4-7, 12-15, 20-23, 28-31 (nibbles 0, 2, 4, 6) - rows 0 and 2
(state & 0x0F0F0000) >> 16 takes bits 16-19, 24-27 (nibbles 7, 5) and shifts to bits 0-3, 8-11 (nibbles 3, 1)
(state & 0x00000F0F) << 16 takes bits 0-3, 8-11 (nibbles 3, 1) and shifts to bits 16-19, 24-27 (nibbles 7, 5)
This confirms the interpretation. Good.

Now for CiVerLy implementation:

The cipher is 32-bit with 8 nibbles of 4 bits each. This fits well with WordSBoxCipher since it's word-based with 4-bit words.

Wait, actually, looking at the figures and the operations (MixColumns, ShiftRows), it has an AES-like structure. But the state is only 2 columns × 4 rows, not 4×4 like AES. The AESlike class uses "rectangular-state ciphers with AES-style column layout" - would it work for a 2-column state?

Looking at the README: "AES-like ciphers require MixColumn-like layers to operate per column." But AESlike expects a rectangular state matrix. Let me check aes.py to see how it works.

Actually, for BEANIE, since it has only 2 columns and 4 rows, and uses a MixColumn-like operation, maybe AESlike could work if it supports arbitrary dimensions. But looking at the existing implementations, AESlike might be designed for 4×4 states.

Let me read aes.py and also check the AESlike class documentation.

Let me understand the AESlike constraints better:

if not sub_cipher.input_length == self.rows * self.wordsize:
    # Input length should be rows * wordsize
For BEANIE, the state is 4 rows × 2 columns, with 4-bit words. So rows=4, cols=2, wordsize=4. Each MixColumn operates on a column of 4 words = 16 bits. So self.rows * self.wordsize = 16, which matches.

Also:

minimum = min([e[1][1] for e in edges])
maximum = max([e[1][1] for e in edges]) - minimum
if not (
    (maximum - minimum == self.rows - 1) and
    (minimum % self.rows == 0)
):
For a column-aligned MixColumn on a 4×2 state with column-wise indexing: Column 0: indices 0, 1, 2, 3 Column 1: indices 4, 5, 6, 7

For column 0: minimum=0, maximum=3, maximum-minimum=3 = rows-1, minimum%rows=0. ✓ For column 1: minimum=4, maximum=7, maximum-minimum=3 = rows-1, minimum%rows=0. ✓

This works! So AESlike can handle a 4×2 state.

Now, let me also understand the indexing. AESlike uses column-wise indexing:

+---+----+
| 0 |  4 |
+---+----+
| 1 |  5 |
+---+----+
| 2 |  6 |
+---+----+
| 3 |  7 |
+---+----+
For BEANIE in the C/Python reference, the state is:

0  4
1  5
2  6
3  7
So the indexing matches AESlike perfectly! Column 0 has indices 0,1,2,3 and column 1 has indices 4,5,6,7.

Now for the MixColumn matrix. In BEANIE, the matrix shown in Figure 3 is:

(2  1  1  9)
(1  4  f  1)
(d  9  4  1)
(1  d  1  2)
This operates over GF(2^4) with the field defined by a specific polynomial. Looking at the C code:

static inline uint8_t xtime(uint8_t x)
{
  return (0xf) & ((x<<1) ^ (((x>>3) & 1) * 0x3));
}
The polynomial is x^4 + x + 1 (since 0x3 = 0b0011 means we XOR with x + 1 when there's a carry from bit 3). Actually, let's verify:

x^4 = x + 1 in this field (since the reduction polynomial is x^4 + x + 1)
When x >> 3 is 1 (meaning the MSB is set), we need to reduce x^4 term
x^4 = x + 1, so we XOR with 0x3 (which represents x + 1 or 0b0011)
Yes, the field is GF(2^4) with irreducible polynomial x^4 + x + 1 (0x13 in binary, but represented as 0x3 in nibble form for the reduction).

Now I need to create the binary matrix for LinearLayer_CVL. Each entry in the matrix is a 4×4 binary matrix representing multiplication by the GF(2^4) element.

Multiplication by 1: identity matrix Multiplication by 2: xtime Multiplication by 9 = 0b1001 = x^3 + 1 Multiplication by f = 0b1111 = x^3 + x^2 + x + 1 Multiplication by d = 0b1101 = x^3 + x^2 + 1

Let me compute these binary matrices.

For xtime (multiplication by x = 2): Input bits [b3, b2, b1, b0] (where b3 is MSB). Output = x * (b3x^3 + b2x^2 + b1x + b0) = b3x^4 + b2x^3 + b1x^2 + b0x = b3(x+1) + b2x^3 + b1x^2 + b0x = b2x^3 + b1x^2 + b0x + b3x + b3 = b2x^3 + b1*x^2 + (b0+b3)*x + b3

So:

out3 = b2
out2 = b1
out1 = b0 ⊕ b3
out0 = b3
Matrix for xtime (multiplication by 2):

[0 1 0 0]  (out3 = in2)
[0 0 1 0]  (out2 = in1)
[0 0 0 1]  (out1 = in0)
[1 0 0 0]  (out0 = in3, but wait out0 = b3, so need to check)
Wait, let me be careful about bit ordering. In the C code, a nibble value is:

bit 3 (MSB): coefficient of x^3
bit 2: coefficient of x^2
bit 1: coefficient of x^1
bit 0 (LSB): coefficient of 1
So out = x * in:

If in has bit 3 set (coefficient of x^3), then x * x^3 = x^4 = x + 1 (mod x^4 + x + 1), contributing to bit 1 and bit 0.
x * x^2 = x^3, contributing to bit 3
x * x^1 = x^2, contributing to bit 2
x * 1 = x, contributing to bit 1
So:

out3 = in2 (from x^3 term)
out2 = in1 (from x^2 term)
out1 = in0 ⊕ in3 (from x term: x * 1 gives x, and x^4 gives x)
out0 = in3 (from x^4 giving constant 1)
So the matrix mapping [in0, in1, in2, in3] to [out0, out1, out2, out3]: Wait, in the C code, x is a uint8_t. x << 1 shifts LSB to left.

Actually, for binary matrix representation, we typically think of column vectors. Let's think of input as [in0, in1, in2, in3]^T where in0 is bit 0, etc.

Then: out0 = in3 out1 = in0 + in3 out2 = in1 out3 = in2

Matrix:

[0 0 0 1]
[1 0 0 1]
[0 1 0 0]
[0 0 1 0]
This maps [in0, in1, in2, in3] -> [out0, out1, out2, out3].

Wait, looking at aes.py, their mul2 matrix is:

mul2 = matrix(GF(2), [[0, 1, 0, 0, 0, 0, 0, 0],
                      [0, 0, 1, 0, 0, 0, 0, 0],
                      [0, 0, 0, 1, 0, 0, 0, 0],
                      [1, 0, 0, 0, 1, 0, 0, 0],
                      [1, 0, 0, 0, 0, 1, 0, 0],
                      [0, 0, 0, 0, 0, 0, 1, 0],
                      [1, 0, 0, 0, 0, 0, 0, 1],
                      [1, 0, 0, 0, 0, 0, 0, 0]])
For AES (GF(2^8) with polynomial x^8 + x^4 + x^3 + x + 1), the xtime operation is: out = x * in. If MSB (bit 7) is set, reduce by XORing with 0x1b.

This matrix maps [in0, in1, in2, in3, in4, in5, in6, in7] -> [out0, ..., out7]. out0 = in7 (from the reduction constant 0x1b = 0b00011011, bit 0 is 1) Wait, looking at row 0: [0,1,0,0,0,0,0,0] means out0 = in1. That's strange.

Actually, looking at AES spec, the standard representation uses big-endian bytes where bit 7 is the MSB. But the matrix in aes.py might use a different bit ordering.

Wait, aes.py constructs:

mul2 = matrix(GF(2), [[0, 1, 0, 0, 0, 0, 0, 0],
                      ...
This would mean out0 = in1. That's not standard AES xtime. Let me check if they use bit-reversed ordering.

Actually, in AES, the standard polynomial is m(x) = x^8 + x^4 + x^3 + x + 1. xtime(a) = (a << 1) mod m(x). If a_7 = 0: b = a << 1, so b_i = a_{i-1} for i=1..7, b_0 = 0. If a_7 = 1: b = (a << 1) ⊕ 0x1b, so b_0 = 1, b_1 = 1, b_3 = 1, and b_i = a_{i-1} for others.

Standard form: [a0, a1, a2, a3, a4, a5, a6, a7] where a7 is MSB. Then: b0 = a7 * 1 (from reduction) b1 = a0 ⊕ a7 * 1 b2 = a1 b3 = a2 ⊕ a7 * 1 b4 = a3 ⊕ a7 * 1 b5 = a4 b6 = a5 b7 = a6

Wait, 0x1b = 00011011, so bits 0, 1, 3, 4 are set.

Actually, looking at the matrix in aes.py, row 0 is [0,1,0,0,0,0,0,0], which means b0 = a1. This is definitely using a different bit convention.

Let me not get bogged down in this. Instead, let me just test the matrix by applying it to the BEANIE reference vectors. If the test vectors match, the matrix is correct.

But first, let me understand the LinearLayer_CVL bit ordering. In aes.py, they build mul2 matrix and then compose it with block_matrix. And the test vectors for AES pass.

Actually, let me think about this differently. The LinearLayer_CVL applies a binary matrix to a bit vector. The ordering of bits matters. For AESlike, the state is indexed by word index (0 to 7 for BEANIE). Each word has wordsize bits.

For LinearLayer_CVL in AESlike, the input is rows * wordsize bits, which corresponds to one column. The question is: how are these bits ordered?

Looking at skinny.py:

for j in range(4):
    node = mixcolumns.add_subcipher(
        mc, [(mixcolumns.IN, (i+4*j, i)) for i in range(4)]
    )
    mixcolumns.add_output([(node, (i, i+4*j)) for i in range(4)])
For SKINNY with s=4, the MixColumn operates on a column of 4 words (16 bits). The edges map word indices 4*j + i to i for the linear layer input, and output maps i to 4*j + i.

This means the linear layer input receives words in order: first word of column, second word, etc. But what about bit ordering within each word?

For LinearLayer_CVL, if the input is a bit vector of length 16, and we have 4 words of 4 bits each, the bits are likely ordered as: bits 0-3: word 0 (index 0) bits 4-7: word 1 (index 1) bits 8-11: word 2 (index 2) bits 12-15: word 3 (index 3)

But within each word, bit 0 is the LSB and bit 3 is the MSB.

Actually, let me test this by directly creating the BEANIE cipher and running the test vectors. If something is wrong, I'll fix it.

For the GF(2^4) multiplication matrices, I need to define them correctly for the bit ordering used by LinearLayer_CVL.

Let me think about what LinearLayer_CVL does. It takes a binary matrix M and computes output = M * input, where input is a column vector of bits.

If input bits are [b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15] corresponding to:

word 0: b0,b1,b2,b3 (where b0 is bit 0 of the word, b3 is bit 3)
word 1: b4,b5,b6,b7
word 2: b8,b9,b10,b11
word 3: b12,b13,b14,b15
And the MixColumn operation is: out[i] = sum_j M_{i,j} * in[j]

where in[j] is word j.

In BEANIE: out0 = 2in0 + 1in1 + 1in2 + 9in3 out1 = 1in0 + 4in1 + fin2 + 1in3 out2 = din0 + 9in1 + 4in2 + 1in3 out3 = 1in0 + din1 + 1in2 + 2in3

Each multiplication is over GF(2^4).

Let me compute the binary matrix for multiplication by each coefficient.

For a 4-bit value [b0, b1, b2, b3] representing b0 + b1x + b2x^2 + b3*x^3: Multiplication by 1 = x^0: identity

[1 0 0 0]
[0 1 0 0]
[0 0 1 0]
[0 0 0 1]
Multiplication by 2 = x: x * (b0 + b1x + b2x^2 + b3x^3) = b0x + b1x^2 + b2x^3 + b3x^4 = b0x + b1x^2 + b2x^3 + b3*(x+1) = b3 + (b0+b3)x + b1x^2 + b2*x^3

So: out0 = b3 out1 = b0 + b3 out2 = b1 out3 = b2

Matrix (mapping [b0,b1,b2,b3] to [out0,out1,out2,out3]):

[0 0 0 1]
[1 0 0 1]
[0 1 0 0]
[0 0 1 0]
Multiplication by 4 = x^2: x^2 * (b0 + b1x + b2x^2 + b3x^3) = b0x^2 + b1x^3 + b2x^4 + b3x^5 = b0x^2 + b1x^3 + b2(x+1) + b3*(x^2+x) = b2 + (b2+b3)*x + (b0+b3)x^2 + b1x^3

So: out0 = b2 out1 = b2 + b3 out2 = b0 + b3 out3 = b1

Matrix:

[0 0 1 0]
[0 0 1 1]
[1 0 0 1]
[0 1 0 0]
Multiplication by 8 = x^3: x^3 * (...) = b0x^3 + b1x^4 + b2x^5 + b3x^6 = b0x^3 + b1(x+1) + b2*(x^2+x) + b3*(x^3+x^2) = b1 + (b1+b2)*x + (b2+b3)*x^2 + (b0+b3)*x^3

So: out0 = b1 out1 = b1 + b2 out2 = b2 + b3 out3 = b0 + b3

Matrix:

[0 1 0 0]
[0 1 1 0]
[0 0 1 1]
[1 0 0 1]
Multiplication by 9 = x^3 + 1: = mul8 + mul1 Matrix = matrix for 8 + identity

[1 1 0 0]
[0 1 1 0]
[0 0 1 1]
[1 0 0 0]
Wait, mul8 matrix is:

[0 1 0 0]
[0 1 1 0]
[0 0 1 1]
[1 0 0 1]
Plus identity:

[1 1 0 0]
[0 0 1 0]  -- wait, no. Let me add element-wise over GF(2).
Actually, adding identity: Row 0: [0+1, 1+0, 0+0, 0+0] = [1, 1, 0, 0] Row 1: [0+0, 1+1, 1+0, 0+0] = [0, 0, 1, 0] Row 2: [0+0, 0+0, 1+1, 1+0] = [0, 0, 0, 1] Row 3: [1+0, 0+0, 0+0, 1+1] = [1, 0, 0, 0]

Hmm wait, I made a mistake. The matrix rows represent output bits in terms of input bits.

For mul8: out0 = b1 out1 = b1 + b2 out2 = b2 + b3 out3 = b0 + b3

So the matrix is:

[0 1 0 0]   (out0)
[0 1 1 0]   (out1)
[0 0 1 1]   (out2)
[1 0 0 1]   (out3)
Adding identity matrix:

[1 0 0 0]   (out0 += b0)
[0 1 0 0]   (out1 += b1)
[0 0 1 0]   (out2 += b2)
[0 0 0 1]   (out3 += b3)
Result for mul9 = mul8 + identity:

[1 1 0 0]   (out0 = b0 + b1)
[0 0 1 0]   (out1 = b1 + b2 + b1 = b2) -- wait, b1 + b1 = 0
[0 0 0 1]   (out2 = b2 + b3 + b2 = b3)
[1 0 0 0]   (out3 = b0 + b3 + b3 = b0)
Hmm, that gives: out0 = b0 + b1 out1 = b2 out2 = b3 out3 = b0

Let me verify by direct computation: 9 * v = (x^3 + 1) * v = x^3*v + v

x^3 * (b0 + b1x + b2x^2 + b3x^3) = b0x^3 + b1x^4 + b2x^5 + b3x^6 = b0x^3 + b1*(x+1) + b2*(x^2+x) + b3*(x^3+x^2) = b1 + (b1+b2)*x + (b2+b3)*x^2 + (b0+b3)*x^3

Adding v = b0 + b1x + b2x^2 + b3*x^3: out = b1+b0 + (b1+b2+b1)x + (b2+b3+b2)x^2 + (b0+b3+b3)x^3 = (b0+b1) + b2x + b3x^2 + b0x^3

So: out0 = b0 + b1 out1 = b2 out2 = b3 out3 = b0

Matrix:

[1 1 0 0]
[0 0 1 0]
[0 0 0 1]
[1 0 0 0]
Multiplication by f = 15 = x^3 + x^2 + x + 1: f * v = x^3v + x^2v + xv + v We have: mul1 = v mul2 = xv = b3 + (b0+b3)x + b1x^2 + b2x^3 mul4 = x^2v = b2 + (b2+b3)x + (b0+b3)x^2 + b1x^3 mul8 = x^3v = b1 + (b1+b2)*x + (b2+b3)*x^2 + (b0+b3)*x^3

mulf = mul8 + mul4 + mul2 + mul1

out0 = b1 + b2 + b3 + b0 out1 = (b1+b2) + (b2+b3) + (b0+b3) + b1 = b1+b2+b2+b3+b0+b3+b1 = b0 out2 = (b2+b3) + (b0+b3) + b1 + b2 = b2+b3+b0+b3+b1+b2 = b0 + b1 out3 = (b0+b3) + b1 + b2 + b3 = b0+b3+b1+b2+b3 = b0 + b1 + b2

So: out0 = b0 + b1 + b2 + b3 out1 = b0 out2 = b0 + b1 out3 = b0 + b1 + b2

Matrix:

[1 1 1 1]
[1 0 0 0]
[1 1 0 0]
[1 1 1 0]
Multiplication by d = 13 = x^3 + x^2 + 1: muld = mul8 + mul4 + mul1

out0 = b1 + b2 + b0 out1 = (b1+b2) + (b2+b3) + b1 = b3 out2 = (b2+b3) + (b0+b3) + b2 = b0 out3 = (b0+b3) + b1 + b3 = b0 + b1

Matrix:

[1 1 1 0]
[0 0 0 1]
[1 0 0 0]
[1 1 0 0]
Wait, let me recheck: out0 = b0 + b1 + b2 out1 = b3 out2 = b0 out3 = b0 + b1

Matrix:

[1 1 1 0]
[0 0 0 1]
[1 0 0 0]
[1 1 0 0]
Now, to verify these, let me write a quick test script.

But first, let me also think about the ShiftRows permutation in terms of AESlike word indices.

The state in AESlike with rows=4, cols=2:

+---+---+
| 0 | 4 |
+---+---+
| 1 | 5 |
+---+---+
| 2 | 6 |
+---+---+
| 3 | 7 |
+---+---+
ShiftRows in BEANIE:

Row 0: [0, 4] -> [0, 4] (unchanged)
Row 1: [1, 5] -> [5, 1] (rotated left by 1)
Row 2: [2, 6] -> [2, 6] (unchanged)
Row 3: [3, 7] -> [7, 3] (rotated left by 1)
So the permutation on word indices is: 0->0, 1->5, 2->2, 3->7, 4->4, 5->1, 6->6, 7->3

This is exactly what the C code does. The shift32 function in Python gives the same result.

Now, for the PermuteLayer_CVL, I need to specify a permutation on either bits or words. Since we're in a word-based cipher, we can use word_coarseness=4 to make it operate on words. But wait, AESlike inherits from WordSBoxCipher, and the PermuteLayer_CVL with word_coarseness acts on words.

Looking at aes.py:

tpt = [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3]
shiftrow = PermuteLayer_CVL(tpt, word_coarseness=8, name="ShiftRows")
Wait, in aes.py they use word_coarseness=8 but the permutation values seem to be word indices (0-15 for a 16-word state), not bit indices. So word_coarseness=8 means each word is 8 bits, and the permutation operates on 8-bit words.

For BEANIE, word_coarseness=4 and the permutation would be: [0, 5, 2, 7, 4, 1, 6, 3]

Wait, let me verify. PermuteLayer_CVL creates a permutation. The input is a list where perm[i] means input bit/word i goes to output position perm[i].

Actually, looking at the aes.py permutation: [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3] In AES, ShiftRows rotates rows. Row 0 stays, row 1 shifts left by 1, row 2 by 2, row 3 by 3. With word indices: Row 0: 0, 1, 2, 3 -> 0, 1, 2, 3 Row 1: 4, 5, 6, 7 -> 5, 6, 7, 4 (shift left by 1) Row 2: 8, 9, 10, 11 -> 10, 11, 8, 9 (shift left by 2) Row 3: 12, 13, 14, 15 -> 15, 12, 13, 14 (shift left by 3)

So input 0 goes to output 0, input 1 goes to output 1, etc. input 4 goes to output 5, input 5 to 6, input 6 to 7, input 7 to 4.

The permutation list in PermuteLayer_CVL is: perm[i] = destination of input i. So for AES: perm = [0, 1, 2, 3, 5, 6, 7, 4, 10, 11, 8, 9, 15, 12, 13, 14]

Wait, but in aes.py they have [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3]. Let me check:

input 0 -> output 0 ✓
input 1 -> output 13? That doesn't match.
Hmm, looking at aes.py more carefully, they call .inv() on the PermuteLayer_CVL in skinny.py but not in aes.py. Let me check what the permutation actually does.

Actually wait, aes.py doesn't call .inv(). Let me trace through what the permutation [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3] does.

If perm[i] is the output position of input i:

input 0 -> output 0
input 1 -> output 13
input 2 -> output 10
input 3 -> output 7
input 4 -> output 4
This maps AES indices. In AES column-wise indexing: Row 0: 0, 4, 8, 12 Row 1: 1, 5, 9, 13 Row 2: 2, 6, 10, 14 Row 3: 3, 7, 11, 15

Standard AES ShiftRows (from the spec):

Row 0: no shift -> 0, 4, 8, 12
Row 1: shift left by 1 -> 5, 9, 13, 1
Row 2: shift left by 2 -> 10, 14, 2, 6
Row 3: shift left by 3 -> 15, 3, 7, 11
So the permutation (input -> output) would be: 0->0, 4->4, 8->8, 12->12 1->5, 5->9, 9->13, 13->1 2->10, 6->14, 10->2, 14->6 3->15, 7->3, 11->7, 15->11

So perm = [0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12, 1, 6, 11]

But aes.py has [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3]. These are inverses of each other!

Yes! perm = [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3] means: If output j = input i where perm[i] = j... no wait.

Actually, looking at the PermuteLayer_CVL code, when we pass a permutation list, it might be that perm[i] represents where input i should go. But in aes.py, the values [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3] are the inverse of the standard AES ShiftRows. This is because CiVerLy might use a different convention, or it might be that AES in the reference software uses row-major indexing instead of column-major.

Wait, looking back at the README: "AESlike uses column-wise indexing of the state (AES convention). If the reference cipher uses row-wise indexing (common in some designs), you must transpose before and after ShiftRows-like steps."

So aes.py knows about this and uses the correct permutation. Let me verify: If perm[1] = 13, that means input word 1 goes to output position 13. In AES column-wise, word 1 is row 1, col 0. After ShiftRows, it moves to row 1, col 1, which is word 5. So why 13?

Ah, I think the issue is that CiVerLy's PermuteLayer_CVL might use bit-level permutations, and with word_coarseness=8, the permutation maps bit positions. But since they pass word indices...

Actually, let me look at how PermuteLayer_CVL and word_coarseness work. I should read the component code.

Actually, looking at skinny.py:

shiftrows = PermuteLayer_CVL(perm=[
    0, 1, 2, 3, 7, 4, 5, 6, 10, 11, 8, 9, 13, 14, 15, 12
], word_coarseness=s, name="ShiftRows").inv()
And for SKINNY, standard ShiftRows (from spec) is: Row 0: no shift Row 1: shift left by 1 Row 2: shift left by 2 Row 3: shift left by 3

In SKINNY column-wise indexing: Row 0: 0, 1, 2, 3 (actually wait, SKINNY is 4×4 too)

Wait, SKINNY uses a 4×4 matrix. Let me check the standard SKINNY ShiftRows: From the SKINNY paper, the ShiftRows is defined on the cell array:

[ 0,  1,  2,  3]
[ 7,  4,  5,  6]
[10, 11,  8,  9]
[13, 14, 15, 12]
Wait, that's the state AFTER ShiftRows! In the SKINNY paper, cells are indexed row-wise (0,1,2,3 in first row; 4,5,6,7 in second, etc.) but AESlike uses column-wise.

Actually, looking at skinny.py, the permutation [0, 1, 2, 3, 7, 4, 5, 6, 10, 11, 8, 9, 13, 14, 15, 12] with .inv().

Let me figure out what this permutation does: input 0 -> 0, 1->1, 2->2, 3->3 input 4 -> 7, 5->4, 6->5

... (choosing the right components)

From component.py, PermuteLayer_CVL works as follows:

arr[perm[i]][i] = identity_matrix(word_coarseness)
So perm[i] is the OUTPUT position for input i. This means the permutation maps input i to output perm[i].

For AES ShiftRows in aes.py:

tpt = [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3]
This means:

input 0 -> output 0
input 1 -> output 13
input 2 -> output 10
input 3 -> output 7 ...
In AES column-wise indexing (AES convention):

Word 0 is row 0, col 0
Word 1 is row 1, col 0
Word 4 is row 0, col 1
Word 5 is row 1, col 1
etc.
Standard AES ShiftRows:

Row 0: no shift (words 0, 4, 8, 12 stay)
Row 1: shift left by 1 (words 1, 5, 9, 13 -> 5, 9, 13, 1)
Row 2: shift left by 2 (words 2, 6, 10, 14 -> 10, 14, 2, 6)
Row 3: shift left by 3 (words 3, 7, 11, 15 -> 15, 3, 7, 11)
So the mapping should be: 0->0, 4->4, 8->8, 12->12 1->5, 5->9, 9->13, 13->1 2->10, 6->14, 10->2, 14->6 3->15, 7->3, 11->7, 15->11

But aes.py has: 1->13, 2->10, 3->7, 4->4, 5->1, 6->14, 7->11, 8->8, 9->5, 10->2, 11->15, 12->12, 13->9, 14->6, 15->3

This is NOT the standard AES ShiftRows. It looks like the AES implementation in aes.py might be using a different convention or the permutation represents the inverse of what's typically called "ShiftRows", and the actual operation combines several steps.

Actually, I notice that aes.py doesn't use a transpose before/after ShiftRows. And they test against known AES vectors. So whatever permutation they use, it gives the correct AES result.

Let me check what [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3] actually does for AES.

If we think of row-major indexing instead: Row 0: 0, 1, 2, 3 Row 1: 4, 5, 6, 7 Row 2: 8, 9, 10, 11 Row 3: 12, 13, 14, 15

Standard AES ShiftRows on row-major: Row 0: 0, 1, 2, 3 -> 0, 1, 2, 3 Row 1: 4, 5, 6, 7 -> 5, 6, 7, 4 Row 2: 8, 9, 10, 11 -> 10, 11, 8, 9 Row 3: 12, 13, 14, 15 -> 15, 12, 13, 14

Mapping: 0->0, 1->1, 2->2, 3->3, 4->5, 5->6, 6->7, 7->4, 8->10, 9->11, 10->8, 11->9, 12->15, 13->12, 14->13, 15->14

But the given permutation is [0, 13, 10, 7, 4, 1, 14, 11, 8, 5, 2, 15, 12, 9, 6, 3].

Wait, that's the INVERSE of the row-major ShiftRows! If row-major ShiftRows maps 4->5, then inverse maps 5->4. The inverse of row-major ShiftRows: 0->0, 1->1, 2->2, 3->3 5->4, 6->5, 7->6, 4->7 10->8, 11->9, 8->10, 9->11 15->12, 12->13, 13->14, 14->15

So the inverse permutation is: [0, 1, 2, 3, 7, 4, 5, 6, 10, 11, 8, 9, 13, 14, 15, 12]

Still not matching. Hmm.

Actually, maybe aes.py is using the "ShiftRows" permutation that operates on the AES state but with the specific AES cell ordering. Let me look at AES test vectors.

Actually, I'll just trust that the aes.py permutation is correct for their implementation. The important thing for me is to match the BEANIE reference vectors.

For BEANIE, the state is:

0  4
1  5
2  6
3  7
And ShiftRows in BEANIE: Row 0: [0, 4] -> [0, 4] Row 1: [1, 5] -> [5, 1] Row 2: [2, 6] -> [2, 6] Row 3: [3, 7] -> [7, 3]

So the mapping (input -> output) is: 0->0, 4->4 1->5, 5->1 2->2, 6->6 3->7, 7->3

Permutation: [0, 5, 2, 7, 4, 1, 6, 3]

This is what I'll use for the PermuteLayer_CVL. If this doesn't match the reference vectors, I'll debug and fix.

Now, let's also think about the MixColumns. For BEANIE, the MixColumns matrix is:

[2, 1, 1, 9]
[1, 4, f, 1]
[d, 9, 4, 1]
[1, d, 1, 2]
In AESlike, the LinearLayer_CVL is applied per column. For BEANIE with 4 rows and 2 columns, each column has 4 words. The LinearLayer_CVL should have input length rows * wordsize = 4 * 4 = 16 bits.

The binary matrix for the MixColumn is a 16×16 block matrix where each 4×4 block is the binary matrix of multiplication by the corresponding coefficient.

Using my earlier calculations:

mul1 (×1): identity
mul2 (×2): [[0,0,0,1],[1,0,0,1],[0,1,0,0],[0,0,1,0]]
mul4 (×4): [[0,0,1,0],[0,0,1,1],[1,0,0,1],[0,1,0,0]]
mul9 (×9): [[1,1,0,0],[0,0,1,0],[0,0,0,1],[1,0,0,0]]
muld (×d): [[1,1,1,0],[0,0,0,1],[1,0,0,0],[1,1,0,0]]
mulf (×f): [[1,1,1,1],[1,0,0,0],[1,1,0,0],[1,1,1,0]]
The block matrix is:

[[mul2, mul1, mul1, mul9],
 [mul1, mul4, mulf, mul1],
 [muld, mul9, mul4, mul1],
 [mul1, muld, mul1, mul2]]
Wait, but this depends on bit ordering. If LinearLayer_CVL uses a different bit ordering than what I assumed, the test vectors won't match.

Let me write a quick test to verify. I'll create a Python script that tests my understanding.

Actually, let me first calculate what matrix aes.py uses for mul2 in AES and see if I can deduce their bit ordering. In aes.py:

mul2 = matrix(GF(2), [[0, 1, 0, 0, 0, 0, 0, 0],
                      [0, 0, 1, 0, 0, 0, 0, 0],
                      [0, 0, 0, 1, 0, 0, 0, 0],
                      [1, 0, 0, 0, 1, 0, 0, 0],
                      [1, 0, 0, 0, 0, 1, 0, 0],
                      [0, 0, 0, 0, 0, 0, 1, 0],
                      [1, 0, 0, 0, 0, 0, 0, 1],
                      [1, 0, 0, 0, 0, 0, 0, 0]])
For AES, xtime with polynomial x^8 + x^4 + x^3 + x + 1: If the bit vector is [a0, a1, a2, a3, a4, a5, a6, a7] (where a0 is LSB, a7 is MSB):

xtime(a) = (a << 1) if a7 == 0 else (a << 1) ^ 0x1b

out0 = a7 * 1 (from 0x1b bit 0) out1 = a0 + a7 * 1 (from 0x1b bit 1) out2 = a1 out3 = a2 + a7 * 1 (from 0x1b bit 3) out4 = a3 + a7 * 1 (from 0x1b bit 4) out5 = a4 out6 = a5 out7 = a6

Wait, 0x1b = 00011011, bits 0,1,3,4 are set.

So: out0 = a7 out1 = a0 + a7 out2 = a1 out3 = a2 + a7 out4 = a3 + a7 out5 = a4 out6 = a5 out7 = a6

Matrix (rows are output bits, columns are input bits):

[0 0 0 0 0 0 0 1]  (out0)
[1 0 0 0 0 0 0 1]  (out1)
[0 1 0 0 0 0 0 0]  (out2)
[0 0 1 0 0 0 0 1]  (out3)
[0 0 0 1 0 0 0 1]  (out4)
[0 0 0 0 1 0 0 0]  (out5)
[0 0 0 0 0 1 0 0]  (out6)
[0 0 0 0 0 0 1 0]  (out7)
But the aes.py matrix is:

[0 1 0 0 0 0 0 0]  (out0)
[0 0 1 0 0 0 0 0]  (out1)
[0 0 0 1 0 0 0 0]  (out2)
[1 0 0 0 1 0 0 0]  (out3)
[1 0 0 0 0 1 0 0]  (out4)
[0 0 0 0 0 0 1 0]  (out5)
[1 0 0 0 0 0 0 1]  (out6)
[1 0 0 0 0 0 0 0]  (out7)
This gives: out0 = a1 out1 = a2 out2 = a3 out3 = a0 + a4 out4 = a0 + a5 out5 = a6 out6 = a0 + a7 out7 = a0

This doesn't look like standard xtime at all with [a0..a7] as bits. But what if aes.py uses a REVERSED bit ordering, where a0 is MSB and a7 is LSB?

If [a0, a1, ..., a7] where a0 is bit 7 (MSB), a1 is bit 6, ..., a7 is bit 0 (LSB):

xtime(a) = (a << 1) if MSB == 0 else (a << 1) ^ 0x1b

In terms of bit 7..0: out7 = a0 if no reduction, else a0 ^ 1 out6 = a7 out5 = a6 out4 = a5 out3 = a4 ^ 1 if reduction out2 = a3 ^ 1 if reduction out1 = a2 out0 = a1 ^ 1 if reduction

Hmm, this is getting messy with the bit ordering.

Actually, I just realized: aes.py in CiVerLy works and passes the AES test vectors. So whatever bit convention they use, I just need to follow the same pattern for BEANIE.

The simplest approach: instead of trying to figure out the bit ordering manually, let me write a small script to determine the correct LinearLayer_CVL matrix by using the reference implementation and comparing outputs for each basis vector.

Actually, wait. I notice that in the BEANIE reference implementation in beanie.py, the _mix_columns function computes:

mixed = (
    ((_multiply(c0, 0x2) ^ _multiply(c1, 0x1) ^ _multiply(c2, 0x1) ^ _multiply(c3, 0x9)) << 12)
    | ((_multiply(c0, 0x1) ^ _multiply(c1, 0x4) ^ _multiply(c2, 0xF) ^ _multiply(c3, 0x1)) << 8)
    | ((_multiply(c0, 0xD) ^ _multiply(c1, 0x9) ^ _multiply(c2, 0x4) ^ _multiply(c3, 0x1)) << 4)
    | ((_multiply(c0, 0x1) ^ _multiply(c1, 0xD) ^ _multiply(c2, 0x1) ^ _multiply(c3, 0x2)) << 0)
)
Where within a column:

c0 is the nibble at bits 12-15 (MSB nibble)
c1 is at bits 8-11
c2 is at bits 4-7
c3 is at bits 0-3 (LSB nibble)
And the output is:

out0 at bits 12-15
out1 at bits 8-11
out2 at bits 4-7
out3 at bits 0-3
For LinearLayer_CVL in AESlike, when we map a column of 4 words to the linear layer, the edges are:

[(node_shiftrow, (i + 4*j, i)) for i in range(4)]
for column j.

This maps word 4*j + i to position i in the linear layer input.

So for column 0 (j=0):

word 0 -> position 0
word 1 -> position 1
word 2 -> position 2
word 3 -> position 3
For LinearLayer_CVL, the input bit vector of length 16 is:

bits 0-3: word at position 0 = word 0
bits 4-7: word at position 1 = word 1
bits 8-11: word at position 2 = word 2
bits 12-15: word at position 3 = word 3
And within each word, bit 0 is LSB, bit 3 is MSB.

So bit 12-15 of the linear layer input contains the MSB nibble of the column (c0), bits 8-11 contain c1, bits 4-7 contain c2, bits 0-3 contain c3.

But the linear layer matrix operates on [b0, b1, b2, b3, b4, ...] where b0 is bit 0, b15 is bit 15.

For word 0 (c3 in the BEANIE notation, since it's at bits 0-3): This is mapped to linear layer input bits 0-3.

For word 1 (c2, bits 4-7): Mapped to input bits 4-7.

For word 2 (c1, bits 8-11): Mapped to input bits 8-11.

For word 3 (c0, bits 12-15): Mapped to input bits 12-15.

So the linear layer input is:

bits 0-3: c3 (word 0 in BEANIE column)
bits 4-7: c2 (word 1)
bits 8-11: c1 (word 2)
bits 12-15: c0 (word 3)
Wait, I need to double check. In BEANIE:

c0 = (state.column[i] >> 12) & 0xf;
c1 = (state.column[i] >> 8)  & 0xf;
c2 = (state.column[i] >> 4)  & 0xf;
c3 = (state.column[i] >> 0)  & 0xf;
So c0 is the top nibble (bits 12-15), c3 is the bottom nibble (bits 0-3). In the column, c0 is the first element (row 0), c1 is row 1, c2 is row 2, c3 is row 3.

In AESlike column-wise indexing for 4 rows, 2 cols: Column 0 indices: 0, 1, 2, 3 Where index 0 = row 0, index 1 = row 1, index 2 = row 2, index 3 = row 3.

So:

index 0 = c0
index 1 = c1
index 2 = c2
index 3 = c3
For the linear layer input mapping:

edges = [(node_shiftrow, (i + 4*j, i)) for i in range(4)]
Word i + 4*j maps to linear layer input position i. Linear layer input bits: word at position i occupies bits 4*i to 4*i+3.

So:

position 0 (bits 0-3): word 0 = c3? Wait no.
I think I was getting confused. Let me re-examine what word 0 contains in BEANIE.

In BEANIE, the 32-bit state is viewed as two 16-bit columns. column[0] = bits 0-15 column[1] = bits 16-31

Within column[0] (bits 0-15):

bits 12-15: top nibble = row 0, col 0 = state element 0
bits 8-11: second nibble = row 1, col 0 = state element 1
bits 4-7: third nibble = row 2, col 0 = state element 2
bits 0-3: bottom nibble = row 3, col 0 = state element 3
In AESlike column-wise indexing:

element 0 is at index 0
element 1 is at index 1
element 2 is at index 2
element 3 is at index 3
For the linear layer, when we map with edges (i + 4*j, i):

word index 0 (element 0, c0) -> linear layer position 0 -> linear layer bits 0-3
word index 1 (element 1, c1) -> linear layer position 1 -> linear layer bits 4-7
word index 2 (element 2, c2) -> linear layer position 2 -> linear layer bits 8-11
word index 3 (element 3, c3) -> linear layer position 3 -> linear layer bits 12-15
But wait, element 0 (row 0, col 0) corresponds to c0, which in the 16-bit column is at bits 12-15, i.e., the MSB nibble. When AESlike maps word index 0 to linear layer position 0, does it map the entire word (all 4 bits) preserving the bit order?

In a word-based cipher, the word at index i consists of bits wordsize*i to wordsize*(i+1)-1 of the overall state. So:

word 0 = state bits 0-3
word 1 = state bits 4-7
word 2 = state bits 8-11
word 3 = state bits 12-15
word 4 = state bits 16-19
etc.
Wait, but in BEANIE's C union, column[0] is the lower 16 bits. And within that:

column[0] >> 12 is c0
column[0] >> 8 is c1
column[0] >> 4 is c2
column[0] >> 0 is c3
So if the overall 32-bit state is stored as a uint32_t, then:

bits 0-3 = c3
bits 4-7 = c2
bits 8-11 = c1
bits 12-15 = c0
bits 16-19 = c3 of column 1
bits 20-23 = c2 of column 1
bits 24-27 = c1 of column 1
bits 28-31 = c0 of column 1
Hmm, this is interesting. In the 32-bit integer representation:

state bits 0-3 = row 3, col 0
state bits 4-7 = row 2, col 0
state bits 8-11 = row 1, col 0
state bits 12-15 = row 0, col 0
state bits 16-19 = row 3, col 1
state bits 20-23 = row 2, col 1
state bits 24-27 = row 1, col 1
state bits 28-31 = row 0, col 1
So in AESlike word indices:

word 0 = bits 0-3 = row 3, col 0
word 1 = bits 4-7 = row 2, col 0
word 2 = bits 8-11 = row 1, col 0
word 3 = bits 12-15 = row 0, col 0
word 4 = bits 16-19 = row 3, col 1
word 5 = bits 20-23 = row 2, col 1
word 6 = bits 24-27 = row 1, col 1
word 7 = bits 28-31 = row 0, col 1
So the AESlike word index to BEANIE row mapping is:

word 0 -> row 3
word 1 -> row 2
word 2 -> row 1
word 3 -> row 0
word 4 -> row 3, col 1
etc.
This is reversed! Because in the 16-bit column, c0 (row 0) is at the top (bits 12-15), but AESlike word indices go from LSB to MSB.

If that's the case, then when AESlike maps word i to linear layer position i:

position 0 = word 0 = c3 (row 3)
position 1 = word 1 = c2 (row 2)
position 2 = word 2 = c1 (row 1)
position 3 = word 3 = c0 (row 0)
So the linear layer input is in REVERSE row order compared to what BEANIE expects!

This means the MixColumn matrix needs to be permuted accordingly.

Alternatively, I could use WordSBoxCipher instead of AESlike and handle everything manually. That might actually be simpler because I don't have to worry about the AESlike column alignment and indexing.

Let me reconsider whether WordSBoxCipher is a better fit.

For WordSBoxCipher:

Word size = 4 bits
Total words = 8
It supports SBox_CVL, LinearLayer_CVL, PermuteLayer_CVL, RoundkeyXOR_CVL.
For a WordSBoxCipher, edges are word-index based (not bit-index based). So:

word indices 0-7
each word is 4 bits
The difference from AESlike is that AESlike enforces certain alignment rules for LinearLayer_CVL (LinearLayer must be rows * wordsize bits and aligned to columns). In WordSBoxCipher, you can use LinearLayer_CVL on the full state or any subset.

Actually, WordSBoxCipher might be simpler for BEANIE. Let me check if WordSBoxCipher supports PermuteLayer_CVL with word_coarseness=4.

Looking at present.py, they use WordSBoxCipher(4, 16, 16) and PermuteLayer_CVL with default word_coarseness=1 (bit-level permutation). But they could also use word_coarseness=4.

Wait, in present.py:

permutation = PermuteLayer_CVL([
    0, 16, 32, 48, 1, 17, 33, 49, ...
], name="Permutation")
This is a bit-level permutation on 64 bits. PRESENT's permutation operates on bits, not words.

For BEANIE, the ShiftRows operates on words (nibbles), so we should use word_coarseness=4.

For the MixColumns, since it operates on each column independently, we could either:

Build two LinearLayer_CVL instances (one for each column) as 16-bit layers
Build a single 32-bit LinearLayer_CVL that is block-diagonal with two 16×16 blocks
Actually, with WordSBoxCipher, LinearLayer_CVL must operate on bits, not words. So a 32-bit LinearLayer_CVL for the full state.

Let me look at how WordSBoxCipher handles LinearLayer_CVL:

Wait, I should check if WordSBoxCipher has any restrictions on LinearLayer_CVL. Let me grep for this.

Actually, WordSBoxCipher inherits from SBoxCipher. And SBoxCipher rejects ModAdd_CVL and AND_CVL, but should accept LinearLayer_CVL.

If I use WordSBoxCipher instead of AESlike, I lose the wordwise MILP modeling for the linear layer specifically designed for AES-like MixColumns. But the README says WordSBoxCipher supports MILP (bitwise and wordwise).

Hmm, but for WordSBoxCipher, wordwise MILP only tracks word activity, not the actual linear layer transitions. The branch-number-based modeling for linear layers requires AESlike to know about column structure.

Actually, let me re-read the README:

WordSBoxCipher: word-based + S-boxes; supports SAT and MILP (bitwise and wordwise).
AESlike: rectangular state, word-based S-boxes, and column-wise MixColumn-style linear layers; supports SAT and MILP (bitwise and wordwise).
For BEANIE, since it DOES have a MixColumn-style linear layer operating on columns, AESlike would give better modeling support (especially branch number based wordwise modeling). So AESlike is the right choice if possible.

Now, the challenge is to get the bit ordering right for AESlike. Let me just test it.

If AESlike word 0 = bits 0-3 of the state, and in BEANIE's uint32_t representation, bits 0-3 = c3 (row 3, col 0), then:

For the linear layer operating on a column, the input is 16 bits corresponding to words 0,1,2,3 (in that order):

bits 0-3: word 0 = c3
bits 4-7: word 1 = c2
bits 8-11: word 2 = c1
bits 12-15: word 3 = c0
So the linear layer input order is [c3, c2, c1, c0] instead of [c0, c1, c2, c3].

BEANIE's MixColumn computes: out0 = 2c0 + 1c1 + 1c2 + 9c3 out1 = 1c0 + 4c1 + fc2 + 1c3 out2 = dc0 + 9c1 + 4c2 + 1c3 out3 = 1c0 + dc1 + 1c2 + 2c3

where out0 goes to row 0 (c0 position), out1 to row 1, out2 to row 2, out3 to row 3.

But in AESlike output, the linear layer outputs bits 0-3 to word 0 (row 3 position), bits 4-7 to word 1 (row 2), etc.

Actually wait. The linear layer output in AESlike maps position i to word i in the same column. So:

output position 0 -> word 0 (row 3 in BEANIE)
output position 1 -> word 1 (row 2)
output position 2 -> word 2 (row 1)
output position 3 -> word 3 (row 0)
So if we want the linear layer to correctly compute BEANIE's MixColumns, we need:

output position 0 (word 0, row 3) = BEANIE out3 = 1c0 + dc1 + 1c2 + 2c3
output position 1 (word 1, row 2) = BEANIE out2 = dc0 + 9c1 + 4c2 + 1c3
output position 2 (word 2, row 1) = BEANIE out1 = 1c0 + 4c1 + fc2 + 1c3
output position 3 (word 3, row 0) = BEANIE out0 = 2c0 + 1c1 + 1c2 + 9c3
And the inputs are:

input position 0 = word 0 = c3
input position 1 = word 1 = c2
input position 2 = word 2 = c1
input position 3 = word 3 = c0
So the linear layer matrix M (4×4 block matrix, each block is 4×4) should satisfy: M * [c3, c2, c1, c0]^T = [out3, out2, out1, out0]^T

Where each element is a 4-bit vector and multiplication is over GF(2^4).

In block form: M = [[M_{0,0}, M_{0,1}, M_{0,2}, M_{0,3}], [M_{1,0}, M_{1,1}, M_{1,2}, M_{1,3}], [M_{2,0}, M_{2,1}, M_{2,2}, M_{2,3}], [M_{3,0}, M_{3,1}, M_{3,2}, M_{3,3}]]

Where M_{i,j} is the 4×4 binary matrix for multiplication by the coefficient that maps input word j to output word i.

So:

M_{0,0} (input pos 0 = c3 to output pos 0 = out3): coefficient for c3 in out3 = 2 -> mul2
M_{0,1} (input pos 1 = c2 to output pos 0 = out3): coefficient for c2 in out3 = 1 -> mul1
M_{0,2} (input pos 2 = c1 to output pos 0 = out3): coefficient for c1 in out3 = d -> muld
M_{0,3} (input pos 3 = c0 to output pos 0 = out3): coefficient for c0 in out3 = 1 -> mul1
Wait, let me re-read the BEANIE MixColumn: out3 = 1c0 + dc1 + 1c2 + 2c3

So:

out3 coefficient for c3 = 2
out3 coefficient for c2 = 1
out3 coefficient for c1 = d
out3 coefficient for c0 = 1
Since input position 0 = c3, input position 1 = c2, input position 2 = c1, input position 3 = c0:

M_{0,0} = mul2 (c3 -> out3)
M_{0,1} = mul1 (c2 -> out3)
M_{0,2} = muld (c1 -> out3)
M_{0,3} = mul1 (c0 -> out3)
For out2: out2 = dc0 + 9c1 + 4c2 + 1c3

Output position 1 = out2:

M_{1,0} = mul1 (c3 -> out2)
M_{1,1} = mul4 (c2 -> out2)
M_{1,2} = mul9 (c1 -> out2)
M_{1,3} = muld (c0 -> out2)
For out1: out1 = 1c0 + 4c1 + fc2 + 1c3

Output position 2 = out1:

M_{2,0} = mul1 (c3 -> out1)
M_{2,1} = mulf (c2 -> out1)
M_{2,2} = mul4 (c1 -> out1)
M_{2,3} = mul1 (c0 -> out1)
For out0: out0 = 2c0 + 1c1 + 1c2 + 9c3

Output position 3 = out0:

M_{3,0} = mul9 (c3 -> out0)
M_{3,1} = mul1 (c

... (implementation)

S-Box and ShiftRows match, but MixColumns doesn't. The issue is likely in how AESlike handles the column mapping or bit ordering.

Let me debug the MixColumn more carefully. In aes.py, the MixColumn is applied like this:

for j in range(4):  # MixColumn is added 4 times in parallel
    edges = [(node_shiftrow, (i + 4*j, i)) for i in range(4)]
    node_mixcolumn = aes_round.add_subcipher(mixcolumn, edges)
    edges = [(node_mixcolumn, (i, i + 4*j)) for i in range(4)]
    aes_round.add_output(edges)
In my test:

for j in range(2):
    col_edges_in = [(node, (i + 4*j, i)) for i in range(4)]
    node_mix = beanie_round.add_subcipher(mixcolumn, col_edges_in)
    col_edges_out = [(node_mix, (i, i + 4*j)) for i in range(4)]
    beanie_round.add_output(col_edges_out)
The issue might be in how AESlike.add_subcipher handles the LinearLayer_CVL and validates the alignment.

Let me look at AESlike.add_subcipher again:

minimum = min([e[1][1] for e in edges])
maximum = max([e[1][1] for e in edges]) - minimum
if not (
    (maximum - minimum == self.rows - 1) and
    (minimum % self.rows == 0)
):
    e = "Only properly aligned MixColumn allowed!"
    raise AssertionError(e)
Wait, the validation checks e[1][1] which is the destination index. For my edges (node, (i + 4*j, i)), e[1][1] = i. So minimum=0, maximum=3, rows=4, maximum-minimum = 3 == rows-1, and minimum % rows = 0. This should pass.

But maybe the issue is that AESlike.add_subcipher calls super().add_subcipher which is WordSBoxCipher.add_subcipher. And WordSBoxCipher might be expanding the edges in a specific way.

Actually, let me think more carefully. In my test, I have beanie_round = AESlike(4, 4, 2, name="BEANIE-round"). The output of shiftrows is node. I'm applying MixColumn to the output of shiftrows by mapping word i + 4*j to linear layer input position i.

The problem is: AESlike expects that LinearLayer_CVL operates on a full column. But the validation only checks alignment. What's happening at the bit level?

Let me check if WordSBoxCipher (parent of AESlike) does any bit-level expansion.

Wait, looking at the output mismatch:

For state 0x12345678:
Ref mix: 0x103a4fea
CVL mix: 0x92e45ade
Let me compute what CVL is producing. Maybe the columns are swapped.

0x103a4fea in columns:

col0 (bits 0-15): 0x4fea
col1 (bits 16-31): 0x103a
0x92e45ade:

col0: 0x5ade
col1: 0x92e4
Hmm, not a simple swap.

Let me check the result by directly testing the LinearLayer_CVL component.

So the direct LinearLayer_CVL produces 0x92e45ade, which matches the CVL AESlike result. But the reference is 0x103a4fea.

This means the issue is in how the matrix maps to the bit vector. Let me analyze:

For col0 = 0xc28a:

In BEANIE reference: c0 = 0xc, c1 = 0x2, c2 = 0x8, c3 = 0xa
The mix produces col0 result = 0x4fea
CVL produces col0 result = 0x5ade

So the matrix is producing a different result. Let me trace through.

In BEANIE reference: c0 = 0xC = 1100_2 = x^3 + x^2 c1 = 0x2 = 0010_2 = x c2 = 0x8 = 1000_2 = x^3 c3 = 0xA = 1010_2 = x^3 + x

out0 = 2c0 + 1c1 + 1c2 + 9c3 = 2*(x^3+x^2) + x + x^3 + (x^3+1)*(x^3+x)

Wait, 9 = x^3 + 1. (x^3+1)*(x^3+x) = x^6 + x^4 + x^3 + x x^6 = x^3 + x^2 (since x^4 = x+1, x^5 = x^2+x, x^6 = x^3+x^2) x^4 = x+1 So x^6 + x^4 + x^3 + x = (x^3+x^2) + (x+1) + x^3 + x = x^2 + 1 = 0x5

2*(x^3+x^2) = x^4 + x^3 = (x+1) + x^3 = x^3 + x + 1 = 0xB x = 0x2 x^3 = 0x8

out0 = 0xB + 0x2 + 0x8 + 0x5 = 0xB ⊕ 0x2 ⊕ 0x8 ⊕ 0x5 = 1011 ⊕ 0010 ⊕ 1000 ⊕ 0101 = 0100 = 0x4

out1 = 1c0 + 4c1 + fc2 + 1c3 = (x^3+x^2) + x^2*(x) + (x^3+x^2+x+1)*x^3 + (x^3+x) = x^3+x^2 + x^3 + (x^6+x^5+x^4+x^3) + x^3+x = x^3+x^2 + x^3 + (x^3+x^2+x+1+x^2+x+x+1+x^3) + x^3+x Hmm this is getting messy.

Actually, the reference output for col0 is 0x4fea, so out0 = 0x4, out1 = 0xf, out2 = 0xe, out3 = 0xa.

For CVL, the result is 0x5ade:

word 0 (bits 0-3) = 0xe
word 1 (bits 4-7) = 0xd
word 2 (bits 8-11) = 0xa
word 3 (bits 12-15) = 0x5
Wait, in my earlier test script, I computed: result_word0 = bits 0-3 of the linear layer output result_word1 = bits 4-7 result_word2 = bits 8-11 result_word3 = bits 12-15

And the combined AESlike result was (result_word3 << 12) | (result_word2 << 8) | (result_word1 << 4) | result_word0.

But in CVL with WordSBoxCipher or AESlike, when the linear layer outputs to word positions, the bits might be mapped differently.

Actually, let me re-examine my test script. In test_beanie_full.py, for the CVL MixColumns debug:

mix_only = AESlike(4, 4, 2, name="MixOnly")
for j in range(2):
    col_edges_in = [(mix_only.IN, (i + 4*j, i)) for i in range(4)]
    n_mix = mix_only.add_subcipher(mixcolumn, col_edges_in)
    col_edges_out = [(n_mix, (i, i + 4*j)) for i in range(4)]
    mix_only.add_output(col_edges_out)
mix_out = vec_to_int(mix_only(int_to_vec(ref_after_shift, 32)))
In this setup, the linear layer input receives words from the AESlike state. The state in AESlike is bit-addressable, but in WordSBoxCipher, the edges use word indices.

When WordSBoxCipher.add_subcipher is called with LinearLayer_CVL, it probably expands word indices to bit indices. Let me check how WordSBoxCipher.add_subcipher works.

... (reasoning about functionality of built-in components and functions)

... (code corrections)

Let me run this debug script to understand the bit ordering.

cd /Users/Uni/Documents/GitHub/CiVerLy-forked-new && sage test_index_debug.py
Test state: 0x12345678
Output: 0x12345678
Vector indices 0-7: [0, 0, 0, 1, 0, 0, 1, 0]
Vector indices 24-31: [0, 1, 1, 1, 1, 0, 0, 0]
SBox output: 0x42bac985
Reference SBox: 0x42bac985
The SBox output matches the reference! So the SBox layer is correctly wired.

The identity cipher also returns the same value, which confirms the basic wiring.

Now I need to understand why the MixColumn is wrong. The issue is specifically with the LinearLayer_CVL bit ordering.

Let me look at the output of test_beanie_full.py again. For the MixColumns debug, the reference result was 0x103a4fea, but CVL gave 0x92e45ade.

Wait, earlier I ran test_beanie_full.py and the SBox + ShiftRows matched, but MixColumns didn't. And test_mix_debug.py showed that the LinearLayer_CVL directly applied to int_to_vec(col0, 16) gives 0x5ade for col0, while the reference is 0x4fea.

But in test_beanie_full.py, the full round (including MixColumns) gave 0x92e45ade, and the mix-only debug gave 0x92e45ade as well. Comparing:

Reference: 0x103a4fea
col0 = 0x4fea
col1 = 0x103a
CVL: 0x92e45ade
col0 = 0x5ade
col1 = 0x92e4
So the issue is that each column individually is wrong.

I know that int_to_vec(col0, 16) produces [bit15, bit14, ..., bit0]. And LinearLayer_CVL.eval does matrix * vector. So int_to_vec gives MSB-first, but I think the cipher wiring gives LSB-first to the linear layer.

Let me test this hypothesis by reversing the input to LinearLayer_CVL in my debug script and seeing if the output matches.

Actually, looking at test_index_debug.py, when we apply int_to_vec(state, 32) to the cipher, the SBox result matched. That means the SBox component correctly handles the bit ordering.

But the SBox operates on 4-bit words. SBox_CVL.eval probably does:

Take 4 input bits
Compose them into a nibble
Apply the SBox
Decompose into 4 output bits
If the SBox matched, then SBox_CVL is using the same bit ordering as int_to_vec. Let me check SBox_CVL.eval.


Aha! vec_to_int does:

for i in input_vec:
    output_num <<= 1
    output_num += ZZ(i)
So it treats input_vec[0] as the MSB! And int_to_vec returns [MSB, ..., LSB].

So int_to_vec and vec_to_int are consistent: vec_to_int(int_to_vec(x, n)) == x.

Now, for SBox_CVL.eval:

return int_to_vec(self.__S(vec_to_int(x)), self.__S.output_size())
It converts the input vector x to an integer (treating x[0] as MSB), applies the SBox, and converts back.

For LinearLayer_CVL.eval:

return self.binary_matrix * x
It directly multiplies the matrix with x, treating x[0] as the first element (which corresponds to the first row/column of the matrix).

So for LinearLayer_CVL, x[0] is indeed the MSB of the input.

But here's the key: when WordBasedCipher expands edges, it maps:

(a, (x*wordsize + o, y*wordsize + o))
For x=0, o=0: state index 0 -> linear layer input index 0. State index 0 corresponds to v[0] which is the MSB of the state (bit 31 of the integer).

So LinearLayer_CVL input element 0 = state bit 31 (MSB). And LinearLayer_CVL input element 15 = state bit 16.

For column 0 of BEANIE (AESlike words 0,1,2,3 = state bits 0-15), the WordBasedCipher expansion maps:

State bit 0 -> some linear layer input index... NO.
Wait, let me trace carefully. In test_beanie_full.py, for the mix_only cipher:

for j in range(2):
    col_edges_in = [(mix_only.IN, (i + 4*j, i)) for i in range(4)]
    n_mix = mix_only.add_subcipher(mixcolumn, col_edges_in)
For j=0, edges = [(IN, (0, 0)), (IN, (1, 1)), (IN, (2, 2)), (IN, (3, 3))]. Expanded: For word 0 (x=0):

(IN, (0, 0)), (IN, (1, 1)), (IN, (2, 2)), (IN, (3, 3))
For word 1 (x=1):

(IN, (4, 4)), (IN, (5, 5)), (IN, (6, 6)), (IN, (7, 7))
For word 2 (x=2):

(IN, (8, 8)), ...
For word 3 (x=3):

(IN, (12, 12)), ...
So linear layer input index 0 = state index 0 = v[0] = state bit 31. linear layer input index 1 = state index 1 = v[1] = state bit 30. ... linear layer input index 15 = state index 15 = v[15] = state bit 16.

So the linear layer receives state bits 31..16, which is the upper half (column 1 in BEANIE's 32-bit view).

And for j=1, edges = [(IN, (4, 0)), (IN, (5, 1)), ...]: For word 4 (x=4):

(IN, (16, 0)), (IN, (17, 1)), ...
So linear layer input index 0 = state index 16 = v[16] = state bit 15. linear layer input index 15 = state index 31 = v[31] = state bit 0.

So this receives state bits 15..0, which is the lower half (column 0 in BEANIE).

So the mapping is swapped! Column j=0 in AESlike maps to BEANIE column 1, and column j=1 maps to BEANIE column 0.

Wait, but in BEANIE, the 32-bit state is:

bits 0-15 = column 0
bits 16-31 = column 1
So j=0 (AESlike words 0-3) maps to state bits 0-15 in the cipher, but because of int_to_vec reversal, v[0..15] = state bits 31..16.

Wait, I'm mixing up what "state index" means. In the cipher graph, the input state vector is v = int_to_vec(state, 32). The cipher's bit indices are the indices into this vector v.

So bit 0 of the cipher = v[0] = state integer bit 31. Bit 1 = v[1] = state integer bit 30. ... Bit 31 = v[31] = state integer bit 0.

In WordBasedCipher.add_subcipher, (a, (src_index, dst_index)) means v[src_index] goes to component input dst_index.

So for j=0:

dst 0 = v[0] = state bit 31
dst 1 = v[1] = state bit 30
...
dst 15 = v[15] = state bit 16
For j=1:

dst 0 = v[16] = state bit 15
dst 1 = v[17] = state bit 14
...
dst 15 = v[31] = state bit 0
BEANIE's column 0 = state bits 0..15. BEANIE's column 1 = state bits 16..31.

So j=0 maps to BEANIE column 1 (but reversed bit order! Bits 31..16). j=1 maps to BEANIE column 0 (but reversed bit order! Bits 15..0).

Wait, within each column, the bit order is also reversed! j=0 gets bit 31, 30, ..., 16, while BEANIE column 1 is normally bit 16, 17, ..., 31.

But since the linear layer is symmetric under full bit reversal (if we also reverse the output), maybe this is handled by the matrix being symmetric... No, it's not.

Actually, for a 16-bit block, if we reverse all 16 bits, and also reverse the output bits, the overall transformation might be different from the original unless the matrix has special symmetry.

Let me think about this differently. The issue is that:

int_to_vec produces MSB-first vectors.
WordBasedCipher maps word w to vector indices w*wordsize to w*wordsize + wordsize - 1.
For AESlike with column-wise indexing, word 0 is row 0, column 0.
But int_to_vec puts the MSB at index 0, which for a 32-bit state is bit 31 (row 0, column 1).
So AESlike word 0 maps to the MSB word of the state, which is row 0, column 1 in BEANIE.

This means the AESlike indexing is effectively reversed from the integer bit ordering!

In other words: AESlike word 0 (index 0) = integer bit 31-28 = row 0, col 1 (c0 of column 1) AESlike word 1 (index 1) = integer bit 27-24 = row 1, col 1 (c1 of column 1) AESlike word 2 (index 2) = integer bit 23-20 = row 2, col 1 (c2 of column 1) AESlike word 3 (index 3) = integer bit 19-16 = row 3, col 1 (c3 of column 1) AESlike word 4 (index 4) = integer bit 15-12 = row 0, col 0 (c0 of column 0) AESlike word 5 (index 5) = integer bit 11-8 = row 1, col 0 (c1 of column 0) AESlike word 6 (index 6) = integer bit 7-4 = row 2, col 0 (c2 of column 0) AESlike word 7 (index 7) = integer bit 3-0 = row 3, col 0 (c3 of column 0)

So AESlike column 0 (words 0,1,2,3) = BEANIE column 1. AESlike column 1 (words 4,5,6,7) = BEANIE column 0.

Wait, this is exactly what I found earlier, but I also need to consider that within each word, the bit order is MSB-to-LSB in int_to_vec, while the WordBasedCipher expansion maps bit o of word w to vector index w*4 + o.

So for AESlike word 0:

bit 0 = integer bit 31 (MSB of the word)
bit 1 = integer bit 30
bit 2 = integer bit 29
bit 3 = integer bit 28 (LSB of the word? No, 28 is still in the upper nibble)
Actually, for int_to_vec(state, 32): v[0] = bit 31 v[1] = bit 30 v[2] = bit 29 v[3] = bit 28 ... v[28] = bit 3 v[29] = bit 2 v[30] = bit 1 v[31] = bit 0

For AESlike word 0, the bits are v[0], v[1], v[2], v[3] = bits 31, 30, 29, 28. In BEANIE reference, c0 = bits 12-15 for column 0, but for AESlike word 0, the bits are 28-31 which is c0 of column 1.

And within AESlike word 0, the bit order is [bit31, bit30, bit29, bit28] (MSB to LSB). But WordBasedCipher expansion maps:

word 0 bit 0 -> v[0] = bit31
word 0 bit 1 -> v[1] = bit30
word 0 bit 2 -> v[2] = bit29
word 0 bit 3 -> v[3] = bit28
For SBox_CVL.eval, it does vec_to_int(x) then applies SBox. vec_to_int treats x[0] as MSB. So SBox input = vec_to_int([bit31, bit30, bit29, bit28]) = 0x? The MSB is bit31.

In BEANIE reference, c0 of column 1 = bits 28-31 = [bit28, bit29, bit30, bit31] in LSB-first, or [bit31, bit30, bit29, bit28] in MSB-first = the value (bit31<<3)|(bit30<<2)|(bit29<<1)|bit28.

So SBox_CVL receives the correct nibble value for c0 of column 1. And since SBoxes don't depend on internal bit ordering beyond forming the correct integer, it works.

Now for LinearLayer_CVL, it does matrix * x, treating x[0] as the first component. So x[0] = v[0] = bit31. This means the matrix operates with MSB-first bit ordering.

My matrix construction was based on LSB-first bit ordering within each word, because I thought the linear layer would see bits in the same order as my manual calculation. But it actually sees MSB-first!

So to fix the matrix, I need to:

Account for the MSB-first bit ordering within each word.
Account for the fact that AESlike column 0 maps to BEANIE column 1 and vice versa.
Actually, let me step back. Since the test vectors showed that SBox works, and the issue is only with the linear layer, let me just construct the matrix based on how LinearLayer_CVL interprets the input.

LinearLayer_CVL.eval receives a vector x where x[i] corresponds to the i-th element of the vector. The matrix multiplication output y[i] = row i of matrix dot x.

For the expanded edges in WordBasedCipher, x[i] = v[k] for some state index k. For j=0 column in my earlier code (AESlike words 0-3): x[0] = v[0] = state bit 31 x[1] = v[1] = state bit 30 ... x[15] = v[15] = state bit 16

For j=1 (AESlike words 4-7): x[0] = v[16] = state bit 15 x[1] = v[17] = state bit 14 ... x[15] = v[31] = state bit 0

So for j=1 (which corresponds to AESlike column 1 = BEANIE column 0): x = [bit15, bit14, ..., bit0].

This means the linear layer receives the 16 bits of BEANIE column 0 in MSB-first order!

Similarly, for j=0 (AESlike column 0 = BEANIE column 1): x = [bit31, bit30, ..., bit16] = BEANIE column 1 in MSB-first order.

So the linear layer always receives each column in MSB-first bit order.

Now, in my matrix, I constructed it assuming LSB-first order. For MSB-first order, I need to reverse both the input and output bit order.

The permutation matrix P that reverses 16 bits: P[i, j] = 1 if j = 15 - i.

If M is my LSB-first matrix, then for MSB-first inputs, the correct matrix is P * M * P.

Let me verify: if x_msb = [b15, b14, ..., b0] and x_lsb = [b0, b1, ..., b15], then x_msb = P * x_lsb.

P * M * P * x_msb = P * M * P * (P * x_lsb) = P * M * x_lsb.

And P * M * x_lsb = [y15, y14, ..., y0] where [y0, ..., y15] = M * x_lsb.

So P * M * P gives the correct output in MSB-first format.

So I should use correct_matrix = P * mix_matrix * P where P reverses the 16 bits.

But wait, within my matrix construction, I also need to handle the fact that the AESlike column-to-BEANIE column mapping is swapped.

Actually no - the matrix itself operates on a 16-bit column. Which AESlike column maps to which BEANIE column doesn't matter for the matrix; it only matters for the wiring. The wiring (edges) connects AESlike words to the linear layer input. Since both AESlike words and the linear layer input use the same int_to_vec bit ordering, the matrix just needs to be correct for that bit ordering.

So the issue is purely that my matrix was constructed for LSB-first but LinearLayer_CVL operates in MSB-first (because int_to_vec is MSB-first and the wiring preserves the vector indices).

Let me test this by updating the matrix in my test script.

Actually, there's another way to think about it. In the BEANIE reference, the column is stored as a 16-bit integer where:

bits 12-15 = c0
bits 8-11 = c1
bits 4-7 = c2
bits 0-3 = c3
In MSB-first vector form (what int_to_vec produces for a 16-bit value):

index 0 = bit 15 = c0 bit 3 (LSB of c0)
index 1 = bit 14 = c0 bit 2
index 2 = bit 13 = c0 bit 1
index 3 = bit 12 = c0 bit 0 (MSB of c0)
index 4 = bit 11 = c1 bit 3
...
index 15 = bit 0 = c3 bit 0
So even within each nibble, the bits are reversed in the vector!

Ah! This is another level of complexity. int_to_vec for a 16-bit value doesn't just reverse the word order; it also reverses the bit order within each word!

For c0 = bits 12-15, in int_to_vec they appear at indices 3, 2, 1, 0 (with bit 15 at index 0, bit 12 at index 3). So within c0, the bit order is [c0_3, c0_2, c0_1, c0_0] where c0_0 is the LSB and c0_3 is the MSB.

But my matrix operates on individual bits. And within each 4-bit block, I assumed the order [b0, b1, b2, b3] where b0 is the LSB. But in int_to_vec it's [b3, b2, b1, b0] for each nibble when viewed in the overall 16-bit vector.

So the full permutation from my assumed ordering to int_to_vec ordering: My assumed: [c3_0, c3_1, c3_2, c3_3, c2_0, c2_1, c2_2, c2_3, c1_0, c1_1, c1_2, c1_3, c0_0, c0_1, c0_2, c0_3] int_to_vec: [c0_3, c0_2, c0_1, c0_0, c1_3, c1_2, c1_1, c1_0, c2_3, c2_2, c2_1, c2_0, c3_3, c3_2, c3_1, c3_0]

Wait, that's not quite right either. Let me work it out: For a 16-bit value with c0 at bits 12-15, c1 at 8-11, c2 at 4-7, c3 at 0-3: int_to_vec = [bit15, bit14, bit13, bit12, bit11, bit10, bit9, bit8, bit7, bit6, bit5, bit4, bit3, bit2, bit1, bit0] = [c0_3, c0_2, c0_1, c0_0, c1_3, c1_2, c1_1, c1_0, c2_3, c2_2, c2_1, c2_0, c3_3, c3_2, c3_1, c3_0]

My assumed order was: [c3_0, c3_1, c3_2, c3_3, c2_0, c2_1, c2_2, c2_3, c1_0, c1_1, c1_2, c1_3, c0_0, c0_1, c0_2, c0_3]

These are completely different! The int_to_vec order has:

Words in reverse order (c0 first, then c1, c2, c3)
Within each word, bits in reverse order (MSB first)
So the permutation P from my assumed order to int_to_vec order is: P([c3_0..c3_3, c2_0..c2_3, c1_0..c1_3, c0_0..c0_3]) = [c0_3..c0_0, c1_3..1_0, c2_3..c2_0, c3_3..c3_0]

This is a combination of word reversal and bit reversal within each word.

So the correct matrix for int_to_vec is P * M * P where P implements this combined permutation.

Actually, P is simply the bit reversal of the entire 16 bits! Let me check:

If we reverse all 16 bits of my assumed order: [c0_3, c0_2, c0_1, c0_0, c1_3, c1_2, c1_1, c1_0, c2_3, c2_2, c2_1, c2_0, c3_3, c3_2, c3_1, c3_0]

Yes! That's exactly the int_to_vec order!

So P is just the 16-bit reversal permutation. And the correct matrix is P * M * P.

Let me compute this and test.

The matrix works when applied via int_to_vec. Now I need to verify it works correctly inside the AESlike cipher structure. Let me write a test that embeds it into the full round and see if the SBox + ShiftRows + MixColumn work together.

Wait, earlier in test_beanie_full.py, the MixColumns test failed because I used mix_matrix_lsb. Now I should update it to use mix_matrix_msb.

But I also need to check whether the AESlike wiring itself preserves the correct bit order. In test_beanie_full.py, SBox and ShiftRows worked because they preserve the bit ordering through the word indices. But MixColumns uses a LinearLayer_CVL which expects the vector in int_to_vec order.

Since WordBasedCipher maps word w's bits w*wordsize + o to v[w*wordsize + o], and the linear layer receives v[indices] directly for matrix multiplication, and v is in int_to_vec order (MSB first globally), the wiring should be correct with mix_matrix_msb.

But wait, there's the AESlike column alignment issue. In my earlier test, I used:

for j in range(2):
    col_edges_in = [(node, (i + 4*j, i)) for i in range(4)]
    node_mix = beanie_round.add_subcipher(mixcolumn, col_edges_in)
    col_edges_out = [(node_mix, (i, i + 4*j)) for i in range(4)]
    beanie_round.add_output(col_edges_out)
Because of int_to_vec reversal, this maps:

j=0: AESlike words 0-3 (column 0) -> state bits 31..16 (BEANIE column 1)
j=1: AESlike words 4-7 (column 1) -> state bits 15..0 (BEANIE column 0)
So if I swap j=0 and j=1 in the output wiring, or simply swap the column mapping, it should work.

Actually, looking at aes.py:

for j in range(4):  # MixColumn is added 4 times in parallel
    edges = [(node_shiftrow, (i + 4*j, i)) for i in range(4)]
    node_mixcolumn = aes_round.add_subcipher(mixcolumn, edges)
    edges = [(node_mixcolumn, (i, i + 4*j)) for i in range(4)]
    aes_round.add_output(edges)
In AES, they also use (i + 4*j, i) for input and (i, i + 4*j) for output. And AES works.

For BEANIE, I should use the same pattern. Let me test the full round with mix_matrix_msb in test_beanie_full.py and see if it works. But I should be careful: the matrix doesn't depend on which AESlike column it operates on. If j=0 maps to BEANIE column 1 and j=1 maps to BEANIE column 0, that's just the way the state is laid out in int_to_vec. The matrix just needs to correctly transform the 16 bits it receives.

Let me update the test and verify.

The round function works correctly now! The traceback is just from my incomplete full encryption test. Let me clean up the test files and now focus on writing the actual beanie.py implementation.

Now I need to implement the full BEANIE cipher class. Let me think about the structure:

Full cipher constructor with R rounds
Round keys as a parameter
The round function: AddRoundKey -> SBox -> ShiftRows -> MixColumn
Last round: AddRoundKey -> SBox -> ShiftRows -> AddRoundKey (no MixColumn)
Tests/doctests with known test vectors from beanie.py
Wait, looking at the BEANIE reference in beanie.py:

def enc(state: int, round_keys: list[int] | tuple[int, ...], rounds: int) -> int:
    if rounds == 0:
        return state & 0xFFFFFFFF
    for round_index in range(rounds - 1):
        state ^= round_keys[round_index]
        state = _sbox32(state)
        state = _shift32(state)
        state = _mix_columns(state)
    state ^= round_keys[rounds - 1]
    state = _sbox32(state)
    state = _shift32(state)
    state ^= round_keys[rounds]
    return state & 0xFFFFFFFF
So there are rounds full rounds (with MixColumn) and a final partial round (SBox + ShiftRows + final key addition).

In testcases.c:

uint8_t NUMBER_OF_ROUNDS = 5;
state_t k[NUMBER_OF_ROUNDS+1];
...
c = enc(m, k, NUMBER_OF_ROUNDS);
For 5 rounds of encryption:

Rounds 0 to 3: ARK -> SBox -> ShiftRows -> MixColumns
Round 4 (last): ARK -> SBox -> ShiftRows -> ARK (final key)
Total round keys used: k[0] through k[5], which is NUMBER_OF_ROUNDS + 1 = 6 keys.

For the key schedule:

void key_expansion(state_t* round_keys, state_tk_t* key, uint8_t nr_keys)
In testcases.c:

key_expansion(k, &t, NUMBER_OF_ROUNDS+1);
And in beanie.py:

def key_expansion(key: tuple[int, int], nr_keys: int) -> list[int]:
Wait, the C key_expansion takes 10 keys, but in Python key_expansion the signature is different. Let me check beanie.py:

def key_expansion(key: tuple[int, int], nr_keys: int) -> list[int]:
And in the test:

round_keys = key_expansion(tweak, 10)
assert round_keys[0] == 0x01234567
...
assert round_keys[9] == 0x77777777
So key_expansion generates nr_keys round keys from a 128-bit key tuple. The first 4 are the 4 words of the key, and the remaining are XOR combinations.

But for the CiVerLy implementation, we probably just need to pass round keys directly, similar to how PRESENT does it.

Let me also check what test vectors are available. In testcases.c, with R=5 and all-zero key/tweak:

state_t k[NUMBER_OF_ROUNDS+1];
state_tk_t key = {.state = {0x0000000000000000, 0x0000000000000000}};
state_tk_t t = {.state = {0x0000000000000000, 0x0000000000000000}};

tweak_key_schedule(key, &t, NUMBER_OF_ROUNDS_TKS);
key_expansion(k, &t, NUMBER_OF_ROUNDS+1);
Then enc(m, k, 5) where m.state = 0x00000000.

I need to replicate this in the Python implementation to get test vectors. Let me look at the Python reference beanie.py for the tweak-key schedule and key expansion:

def tweak_key_schedule(key: tuple[int, int], tweak: tuple[int, int], rounds: int) -> tuple[int, int]:
    ...
    return tweak_left & 0xFFFFFFFFFFFFFFFF, tweak_right & 0xFFFFFFFFFFFFFFFF

def key_expansion(key: tuple[int, int], nr_keys: int) -> list[int]:
    ...
    return round_keys
Wait, tweak_key_schedule actually modifies tweak in the C code by passing a pointer. In Python, it returns the new tweak.

But for the CiVerLy cipher class, do I need to implement the key schedule? The README says: "Decide whether the key schedule is modeled explicitly. If you only need fixed-round testing or do not analyze related-key behavior, use constants in RoundkeyXOR_CVL and pass rks to the constructor."

For BEANIE, I'll provide an optional rks parameter with round keys, similar to PRESENT. This is the simplest approach.

For test vectors, I can compute them using the Python reference or just test the round function.

Actually, let me compute some test vectors myself. For 5 rounds with all-zero key and tweak:

tweak_key_schedule((0,0), (0,0), 5) returns (0,0) because XOR with 0 and all operations starting from 0 give 0. Wait, the SBox in the TKS might not map 0 to 0. Let me check: SBOX[0] = 0, so yes, 0 maps to 0. And the other operations also preserve 0.
key_expansion((0,0), 6) for NUMBER_OF_ROUNDS+1 = 6: Round keys = [0, 0, 0, 0, 0, 0] because all key words are 0.
So encryption of 0x00000000 with 5 rounds and all-zero keys: Let me compute this using the reference.

... (creating own test vectors)

Python might be python3. Let me check.

cd /Users/Uni/Documents/GitHub/CiVerLy-forked-new && python3 test_vectors.py
All tests passed!
Test 1: enc(0x00000000, rks=zeros, R=5) = 0x0
Test 2: enc(0x12345678, rks=zeros, R=5) = 0x27a35219
Test 3: enc(0x12345678, rks=zeros, R=1) = 0x49b5c28a
  After ARK0: 0x12345678
  After SBox: 0x42bac985
  After Shift: 0x49b5c28a
  After MixCol: 0x103a4fea
Test 4: enc(0x00000000, rks=nonzero, R=5) = 0xf05a49f1
Test 5: dec(enc(0x0xabcdef01)) = 0x0xabcdef01 (match: True)
The test vectors are:

Test 1: enc(0x00000000, zeros, R=5) = 0x0
Test 2: enc(0x12345678, zeros, R=5) = 0x27a35219
Test 3: enc(0x12345678, zeros, R=1) = 0x49b5c28a
Test 4: enc(0x00000000, nonzero keys, R=5) = 0xf05a49f1
Test 5: dec(enc(0xABCDEF01)) = 0xABCDEF01
Wait, test 3 shows enc(0x12345678, zeros, R=1) = 0x49b5c28a, but in my single round test earlier, the result after MixColumn was 0x103a4fea. Why is the test result 0x49b5c28a?

Looking at test 3 trace: After ARK0: 0x12345678 After SBox: 0x42bac985 After Shift: 0x49b5c28a After MixCol: 0x103a4fea Test 3: enc(0x12345678, rks=zeros, R=1) = 0x49b5c28a

Ah! For R=1:

state ^= round_keys[rounds - 1]  # = round_keys[0]
state = _sbox32(state)
state = _shift32(state)
state ^= round_keys[rounds]  # = round_keys[1]
So for 1 round: ARK -> SBox -> Shift -> ARK (final). No MixColumn!

And in the reference: state = 0x12345678 After ARK0 = 0x12345678 After SBox = 0x42BAC985 After Shift = 0x49B5C28A After ARK1 = 0x49B5C28A (since round_keys[1] = 0)

That matches.

So the round structure is:

Full rounds (0 to R-2): ARK -> SBox -> ShiftRows -> MixColumns
Last round (R-1): ARK -> SBox -> ShiftRows -> ARK
Total round keys: R+1.

Now I need to implement the cipher class in CiVerLy. Let me review the PRESENT implementation pattern and adapt it for BEANIE.

For BEANIE:

Block size: 32 bits
Word size: 4 bits
Number of words: 8
State layout: 4 rows × 2 columns (AESlike)
S-box: 4-bit SBox
ShiftRows: word permutation
MixColumns: linear layer per column
Key addition: RoundkeyXOR_CVL
The class name should be BEANIE_CVL in a file beanie.py under src/civerly/cipher_implementations/.

For round keys, I'll accept rks as a list of integers, defaulting to 0.

I also need to think about how to set the round key constants when building the cipher. In PRESENT, they do:

present_round.nodes[node_rk].const = rks[r]
But if we reuse the same round_fn object multiple times, modifying it for each round might affect all instances because all rounds share the same sub-cipher object.

Wait, let me re-examine how PRESENT handles this:

node_rk = present_round.add_subcipher(
    key_add, [(present_round.IN, (i, i)) for i in range(16)]
)
# ...
for r in range(R):
    present_round.nodes[node_rk].const = rks[r]
    cipher_node = present_cipher.add_subcipher(
        present_round, [(cipher_node, (i, i)) for i in range(16)]
    )
Wait, does this actually work? Setting present_round.nodes[node_rk].const = rks[r] before each add_subcipher call... If present_round is reused, then setting the const on node_rk would change it for ALL previous instantiations too, wouldn't it?

Hmm, maybe present_round is cloned when added, or maybe the const is resolved at add_subcipher time. Let me check how add_subcipher handles round constants.

Actually, in skinny.py, they set constants on specific nodes inside reused round sub-ciphers:

skinny_round.nodes[node_round_const].nodes[node_xorconst].const = current_constant
skinny_round.nodes[node_round_tweakey].nodes[node_atk1].const = final_tweakeys[r]
node_cipher = skinny_cipher.add_subcipher(skinny_round, [...])
This suggests that the round sub-cipher is mutable and the same object is reused. However, it might be that the add_subcipher method clones the sub-cipher before adding it, so changes after add_subcipher don't affect previous instances.

Let me verify this by looking at Cipher.add_subcipher.

At line 633:

self.__nodes.append(deepcopy(sub_cipher))
So add_subcipher does a deepcopy of the sub-cipher before adding it! This means each instance in the cipher graph is independent. Setting the const on present_round.nodes[node_rk] before adding would set it on the template object, and then deepcopy would copy the new const value for each instantiation.

So the pattern in present.py DOES work:

for r in range(R):
    present_round.nodes[node_rk].const = rks[r]
    cipher_node = present_cipher.add_subcipher(
        present_round, [(cipher_node, (i, i)) for i in range(16)]
    )
Because present_round is deep-copied each time add_subcipher is called, and the const is set just before the copy.

For BEANIE, I can use the same pattern.

Now let me design the actual implementation:

class BEANIE_CVL:
    def __init__(self, R=5, rks=None, name=None):
        if name is None:
            name = "BEANIE"
        if rks is None:
            rks = [0] * (R + 1)
        
        cipher = AESlike(4, 4, 2, name=name)
        
        # SBox layer
        sbox = SBox_CVL(SBox(SBOX), name="SBox")
        sboxlayer = AESlike(4, 4, 2, name="SBoxLayer")
        for i in range(8):
            node = sboxlayer.add_subcipher(sbox, [(sboxlayer.IN, (i, 0))])
            sboxlayer.add_output([(node, (0, i))])
        
        # ShiftRows
        shiftrows = PermuteLayer_CVL([0, 5, 2, 7, 4, 1, 6, 3], word_coarseness=4, name="ShiftRows")
        
        # MixColumns
        mixcolumn = LinearLayer_CVL(mix_matrix, branch_number_differential=5, branch_number_linear=5, name="MixColumn")
        
        # Build full round
        beanie_round = AESlike(4, 4, 2, name="BEANIE-round")
        node_s = beanie_round.add_subcipher(sboxlayer, [(beanie_round.IN, (i, i)) for i in range(8)])
        node_p = beanie_round.add_subcipher(shiftrows, [(node_s, (i, i)) for i in range(8)])
        for j in range(2):
            node_mix = beanie_round.add_subcipher(mixcolumn, [(node_p, (i + 4*j, i)) for i in range(4)])
            beanie_round.add_output([(node_mix, (i, i + 4*j)) for i in range(4)])
        
        # Build last round (no MixColumn)
        beanie_last_round = AESlike(4, 4, 2, name="BEANIE-last-round")
        node_s = beanie_last_round.add_subcipher(sboxlayer, [(beanie_last_round.IN, (i, i)) for i in range(8)])
        node_p = beanie_last_round.add_subcipher(shiftrows, [(node_s, (i, i)) for i in range(8)])
        beanie_last_round.add_output([(node_p, (i, i)) for i in range(8)])
        
        # Key addition components
        key_add_full = RoundkeyXOR_CVL(32, const=0, name="KeyAdd")
        key_add_final = RoundkeyXOR_CVL(32, const=0, name="KeyAdd")
        
        node = cipher.IN
        for r in range(R - 1):
            beanie_round.nodes[node_s].nodes[...]  # Wait, I need to set the round key on a top-level KeyAdd, not inside the round.
Hmm, I think it's cleaner to put the key addition either before or after the round, as a separate component at the cipher level, rather than inside the round sub-cipher.

Looking at PRESENT:

key_add = RoundkeyXOR_CVL(64, 0x0, name="KeyAdd")

present_round = WordSBoxCipher(4, 16, 16, name="present_round")
node_rk = present_round.add_subcipher(
    key_add, [(present_round.IN, (i, i)) for i in range(16)]
)
node = present_round.add_subcipher(
    sboxlayer, [(node_rk, (i, i)) for i in range(16)]
)
...
present_round.add_output([(node, (i, i)) for i in range(16)])
PRESENT puts the key add INSIDE the round as the first operation. This is fine.

For BEANIE, I can do the same:

beanie_round = AESlike(4, 4, 2, name="BEANIE-round")
node_rk = beanie_round.add_subcipher(
    key_add, [(beanie_round.IN, (i, i)) for i in range(8)]
)
node_s = beanie_round.add_subcipher(sboxlayer, [(node_rk, (i, i)) for i in range(8)])
node_p = beanie_round.add_subcipher(shiftrows, [(node_s, (i, i)) for i in range(8)])
for j in range(2):
    node_mix = beanie_round.add_subcipher(mixcolumn, [(node_p, (i + 4*j, i)) for i in range(4)])
    beanie_round.add_output([(node_mix, (i, i + 4*j)) for i in range(4)])
For the last round:

beanie_last_round = AESlike(4, 4, 2, name="BEANIE-last-round")
node_rk = beanie_last_round.add_subcipher(
    key_add_final, [(beanie_last_round.IN, (i, i)) for i in range(8)]
)
node_s = beanie_last_round.add_subcipher(sboxlayer, [(node_rk, (i, i)) for i in range(8)])
node_p = beanie_last_round.add_subcipher(shiftrows, [(node_s, (i, i)) for i in range(8)])
beanie_last_round.add_output([(node_p, (i, i)) for i in range(8)])
Then at the cipher level:

node = cipher.IN
for r in range(R - 1):
    beanie_round.nodes[node_rk].const = rks[r]
    node = cipher.add_subcipher(beanie_round, [(node, (i, i)) for i in range(8)])

beanie_last_round.nodes[node_rk].const = rks[R - 1]
node = cipher.add_subcipher(beanie_last_round, [(node, (i, i)) for i in range(8)])

key_add_final.const = rks[R]
node = cipher.add_subcipher(key_add_final, [(node, (i, i)) for i in range(8)])
cipher.add_output([(node, (i, i)) for i in range(8)])
Wait, for the last round, the key addition is already inside beanie_last_round as node_rk. And then there's the final key addition. So:

For rounds 0 to R-2:

KeyAdd(rks[r]) -> SBox -> ShiftRows -> MixColumns
For round R-1:

KeyAdd(rks[R-1]) -> SBox -> ShiftRows
Then final:

KeyAdd(rks[R])
That matches the BEANIE specification.

But wait, in PRESENT, the final key addition uses the same key_add object as the full round:

key_add.const = rks[R]
cipher_node = cipher.add_subcipher(key_add, [(cipher_node, (i, i)) for i in range(16)])
For BEANIE, I can use a separate RoundkeyXOR_CVL for the final key addition.

Actually, there's a subtle issue. In my beanie_last_round, I have a key_add_final component. When I set beanie_last_round.nodes[node_rk].const = rks[R-1], this modifies the original key_add_final object. Then when I do cipher.add_subcipher(beanie_last_round, ...), it deep-copies beanie_last_round including its modified key_add_final.

Then I set key_add_final.const = rks[R] and add it again at the cipher level. Since it's a separate deep copy at the cipher level, that's fine.

But wait, beanie_last_round.nodes[node_rk] refers to node_rk inside beanie_last_round. If deepcopy is used when adding to cipher, the cipher.nodes[last_node] will be a copy. But modifying beanie_last_round.nodes[node_rk].const before adding modifies the template, and the copy will have that value.

So the pattern should work.

Let me test this by writing a test script first.

... (administrative stuff)

The BEANIE cipher has been implemented in src/civerly/cipher_implementations/beanie.py. Key details:

Base class: AESlike (4 rows × 2 columns, 4-bit words) for full wordwise/bitwise modeling support.
Round function: AddRoundKey → SBox → ShiftRows → MixColumns.
Final round: AddRoundKey → SBox → ShiftRows → AddRoundKey (no MixColumn).
S-box: 4-bit S-box (0, 4, 2, 11, 10, 12, 9, 8, 5, 15, 13, 3, 7, 1, 6, 14).
ShiftRows: word permutation [0, 5, 2, 7, 4, 1, 6, 3].
MixColumns: GF(2⁴) MDS matrix with primitive polynomial x⁴ + x + 1, encoded as a 16×16 binary LinearLayer_CVL with branch number 5.
Constructor: BEANIE_CVL(R=5, rks=None, name=None) accepts round keys as a list of R+1 32-bit integers.
Test vectors verified against the Python reference in documentation/beanie.py:
enc(0x12345678, zeros, R=5) = 0x27a35219
enc(0x00000000, nonzero_keys, R=5) = 0xf05a49f1
enc(0xabcdef01, nonzero_keys, R=5) = 0x8dd221be
Doctests include encryption tests, MILP wordwise/bitwise modeling, and SAT modeling with Unnamed Component checks. All 26 doctests pass.

------------
first commit
------------

User:
Please include the test vectors from @documentation/Screenshot 2026-07-10 at 14.32.38.png  into the doctests for @src/civerly/cipher_implementations/beanie.py

The user wants me to add the official test vectors from the paper into the doctests of beanie.py.

From the screenshot: Test vector 1:

Key: 0000000000000000 / 0000000000000000 (128-bit key)
Tweak: 0000000000000000 / 0000000000000000 (128-bit tweak)
Round Keys: beedff0f, f8a29afc, 9369ab08, 7391f5d3, 464f65f3, e0f85edb
Plaintext: 00000000
Ciphertext: da46f4d3
Test vector 2:

Key: bd9c9afe2626f233 / 706ac764af470a53
Tweak: 2518c65012c8cdfb / 84064a42a281c3aa
Round Keys: 93061e07, 87607a4d, d7d11b34, b1769b2e, 1466644a, 66a7801a
Plaintext: 1841938a
Ciphertext: 092c2fea
Wait, these are from the paper's test vectors table. But the key and tweak produce the round keys through the tweak-key schedule. The current CiVerLy implementation just takes round keys directly. So I should add these as tests with the precomputed round keys.

Let me verify these by running them through the reference implementation first.

Actually, I should also check if the current CIVERLy implementation produces the same results with these round keys. Let me write a quick test.

... (comparing the vecors against the civerly implementation)

Added the two official test vectors from the paper (Table 15) to the BEANIE_CVL doctests:

Test vector 1: round keys beedff0f, f8a29afc, ..., e0f85edb, plaintext 0x00000000 → ciphertext 0xda46f4d3
Test vector 2: round keys 93061e07, 87607a4d, ..., 66a7801a, plaintext 0x1841938a → ciphertext 0x092c2fea

---------
second commit
---------
