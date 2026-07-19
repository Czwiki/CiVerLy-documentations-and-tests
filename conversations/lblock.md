date: 2026-07-19T 19:30:00Z
participants:
- You: Henry
- Assistant: Kilo AI, Kimi 2.6 via Neuralwatt
topic: "Implementation of the twine cipher"

User:
Please implement the lblock cipher according to the specifications of a cipher implementation in  @documentation/README.md . A java reference implementation is available @documentation/LBlock.java together with a part of the published paper @documentation/lblock.md  and figures from the latter @documentation/round function.png , @documentation/feistel network.png , @documentation/s-box constants.png . Test vectors can be found at @documentation/test vectors.png  . Sage is installed via nix. If you need further information, please come forward.

The user wants me to implement the LBlock cipher in Python for the CiVerLy framework, following the specifications in the documentation. Let me analyze what I need:

LBlock is a 64-bit block cipher with 80-bit key, 32 rounds
It's a variant Feistel network
Round function F consists of XOR with round key, S-box layer (8 parallel 4-bit S-boxes), and permutation P
The Feistel structure: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)
Need to follow README.md patterns for CiVerLy cipher implementation
Need test vectors to verify correctness
Let me first explore the codebase to understand the existing implementations and structure.

... (planning and reading files)

Now I have enough information to understand how to implement LBlock in CiVerLy. Let me summarize the LBlock specification:

Block size: 64-bit
Key size: 80-bit
Rounds: 32 rounds
Structure: Variant Feistel network
Plaintext: M = X1 || X0 (each 32 bits)
For i = 2, 3, ..., 33:
Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)
Ciphertext: C = X32 || X33
Round function F:
F(X, Ki) = P(S(X XOR Ki))
S: 8 parallel 4-bit S-boxes (s0 through s7)
P: Permutation of 8 4-bit words
According to the spec:

U7 = Z6, U6 = Z4, U5 = Z7, U4 = Z5
U3 = Z2, U2 = Z0, U1 = Z3, U0 = Z1
And the figure shows s7, s6, s5, s4, s3, s2, s1, s0 from left to right. Wait, let me look at the figure again. The figure shows X going into XOR with Ki, then the output goes to s7, s6, s5, s4, s3, s2, s1, s0 from left to right.

Actually, looking at the figure 2, the S-boxes are ordered s7, s6, s5, s4, s3, s2, s1, s0 from left to right. And the text says: Z7 = s7(Y7), Z6 = s6(Y6), ..., Z0 = s0(Y0)

So the leftmost nibble (bits 28-31) goes to s7, and the rightmost nibble (bits 0-3) goes to s0.

For the permutation P: U7 = Z6, U6 = Z4, U5 = Z7, U4 = Z5 U3 = Z2, U2 = Z0, U1 = Z3, U0 = Z1

Let's map this as a permutation on 32 bits. The 32 bits are divided into 8 words of 4 bits each:

Word 7 (bits 28-31) -> U7 = Z6 (word 6, bits 24-27)
Word 6 (bits 24-27) -> U6 = Z4 (word 4, bits 16-19)
Word 5 (bits 20-23) -> U5 = Z7 (word 7, bits 28-31)
Word 4 (bits 16-19) -> U4 = Z5 (word 5, bits 20-23)
Word 3 (bits 12-15) -> U3 = Z2 (word 2, bits 8-11)
Word 2 (bits 8-11) -> U2 = Z0 (word 0, bits 0-3)
Word 1 (bits 4-7) -> U1 = Z3 (word 3, bits 12-15)
Word 0 (bits 0-3) -> U0 = Z1 (word 1, bits 4-7)
Wait, I need to be more careful. In the spec: Z = Z7 || Z6 || Z5 || Z4 || Z3 || Z2 || Z1 || Z0 U = U7 || U6 || U5 || U4 || U3 || U2 || U1 || U0

So Z7 is the most significant 4 bits (bits 28-31), Z0 is the least significant 4 bits (bits 0-3). In terms of words: Z[i] corresponds to bits 4i to 4i+3 (if we index from 0 at the right). Wait, actually in the software it's usually bit 0 = MSB or bit 0 = LSB?

Looking at int_to_vec: it converts to binary vector with ZZ(input_num).digits(2, padto=size)[::-1]. In Sage, ZZ(5).digits(2) gives [1, 0, 1] (LSB first). Then [::-1] gives [1, 0, 1]... wait, let me check. Actually digits(2) returns digits from least significant to most significant. So for 5, it returns [1, 0, 1]. Then [::-1] reverses it to [1, 0, 1]... hmm wait that's the same. Let me think again.

For ZZ(6).digits(2) = [0, 1, 1]. [::-1] = [1, 1, 0]. So int_to_vec(6, 3) = [1, 1, 0]. vec_to_int([1, 1, 0]) = (1<<2) + (1<<1) + 0 = 6.

So bit 0 in the vector is the MSB! int_to_vec(0x1234, 16) = (0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0). That's 0001 0010 0011 0100, which is indeed 0x1234 with MSB first.

So bit index 0 is the MSB. For a 32-bit value, bit 0 is the MSB (bit 31 in traditional notation), and bit 31 is the LSB (bit 0 in traditional notation).

Now, in LBlock: Words are 4 bits each. Let's say word j consists of bits 4j to 4j+3 in the vector.

Word 0: bits 0-3 (MSB nibble)
Word 1: bits 4-7
...
Word 7: bits 28-31 (LSB nibble)
Wait, but in the spec, Z7 is the most significant word. So if the 32-bit value is Z = Z7 || Z6 || ... || Z0, and we store it as an integer, Z7 is bits 28-31 of the integer (when MSB is on the left).

In int_to_vec, bit 0 is the MSB. So:

Vector bits 0-3 correspond to Z7 (MSB nibble)
Vector bits 4-7 correspond to Z6
Vector bits 8-11 correspond to Z5
Vector bits 12-15 correspond to Z4
Vector bits 16-19 correspond to Z3
Vector bits 20-23 correspond to Z2
Vector bits 24-27 correspond to Z1
Vector bits 28-31 correspond to Z0 (LSB nibble)
Hmm, that seems reversed from the spec. Let me think more carefully.

If Z = Z7 || Z6 || ... || Z0 as a 32-bit integer, then in big-endian:

Bits 31-28 = Z7
Bits 27-24 = Z6
...
Bits 3-0 = Z0
But int_to_vec produces a vector where index 0 is the MSB (bit 31). So:

Vector index 0 = bit 31 = Z7[3] (MSB of Z7)
...
Vector index 3 = bit 28 = Z7[0] (LSB of Z7)
Vector index 4 = bit 27 = Z6[3]
...
Vector index 28 = bit 3 = Z0[3]
Vector index 31 = bit 0 = Z0[0]
So vector bits 0-3 correspond to Z7, bits 4-7 to Z6, bits 8-11 to Z5, etc. Actually wait, in int_to_vec the vector indices map to MSB-first. For int_to_vec(0xABCD, 16): 0xABCD = 1010 1011 1100 1101. The vector is (1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1).

So index 0 = first bit = 1 (MSB of 0xA). Index 3 = last bit of 0xA = 0. Index 4 = first bit of 0xB = 1.

For LBlock, if Z = Z7 || Z6 || ... || Z0, and Z7 is the MSB nibble:

Vector indices 0-3 = Z7
Vector indices 4-7 = Z6
Vector indices 8-11 = Z5
Vector indices 12-15 = Z4
Vector indices 16-19 = Z3
Vector indices 20-23 = Z2
Vector indices 24-27 = Z1
Vector indices 28-31 = Z0
Now the permutation P: U7 = Z6 -> U7 gets the value of Z6, which was at vector indices 4-7 U6 = Z4 -> U6 gets Z4, which was at vector indices 12-15 U5 = Z7 -> U5 gets Z7, which was at vector indices 0-3 U4 = Z5 -> U4 gets Z5, which was at vector indices 8-11 U3 = Z2 -> U3 gets Z2, which was at vector indices 20-23 U2 = Z0 -> U2 gets Z0, which was at vector indices 28-31 U1 = Z3 -> U1 gets Z3, which was at vector indices 16-19 U0 = Z1 -> U0 gets Z1, which was at vector indices 24-27

Wait, but is there also a permutation on the bit level within each word? The spec says "P is defined as a permutation of eight 4-bit words". So it's a word-level permutation, not a bit-level permutation. Within each 4-bit word, the bits stay in the same order.

So to create the bit-level permutation for PermuteLayer_CVL, we need: For each word position, map the 4 bits from the source word to the destination word.

Destination word 7 (indices 0-3) <- Source word 6 (indices 4-7): dest 0 <- source 4 dest 1 <- source 5 dest 2 <- source 6 dest 3 <- source 7

Destination word 6 (indices 4-7) <- Source word 4 (indices 12-15): dest 4 <- source 12 dest 5 <- source 13 dest 6 <- source 14 dest 7 <- source 15

Destination word 5 (indices 8-11) <- Source word 7 (indices 0-3): dest 8 <- source 0 dest 9 <- source 1 dest 10 <- source 2 dest 11 <- source 3

Destination word 4 (indices 12-15) <- Source word 5 (indices 8-11): dest 12 <- source 8 dest 13 <- source 9 dest 14 <- source 10 dest 15 <- source 11

Destination word 3 (indices 16-19) <- Source word 2 (indices 20-23): dest 16 <- source 20 dest 17 <- source 21 dest 18 <- source 22 dest 19 <- source 23

Destination word 2 (indices 20-23) <- Source word 0 (indices 28-31): dest 20 <- source 28 dest 21 <- source 29 dest 22 <- source 30 dest 23 <- source 31

Destination word 1 (indices 24-27) <- Source word 3 (indices 16-19): dest 24 <- source 16 dest 25 <- source 17 dest 26 <- source 18 dest 27 <- source 19

Destination word 0 (indices 28-31) <- Source word 1 (indices 24-27): dest 28 <- source 24 dest 29 <- source 25 dest 30 <- source 26 dest 31 <- source 27

Let me construct this permutation list: perm = [ 4, 5, 6, 7, # U7 <- Z6 (word 6) 12, 13, 14, 15, # U6 <- Z4 (word 4) 0, 1, 2, 3, # U5 <- Z7 (word 7) 8, 9, 10, 11, # U4 <- Z5 (word 5) 20, 21, 22, 23, # U3 <- Z2 (word 2) 28, 29, 30, 31, # U2 <- Z0 (word 0) 16, 17, 18, 19, # U1 <- Z3 (word 3) 24, 25, 26, 27 # U0 <- Z1 (word 1) ]

Wait, I need to double check. Let me re-read the spec.

Spec: U7 = Z6, U6 = Z4, U5 = Z7, U4 = Z5, U3 = Z2, U2 = Z0, U1 = Z3, U0 = Z1.

In the vector representation:

Word 7 (indices 0-3) contains Z7
Word 6 (indices 4-7) contains Z6
Word 5 (indices 8-11) contains Z5
Word 4 (indices 12-15) contains Z4
Word 3 (indices 16-19) contains Z3
Word 2 (indices 20-23) contains Z2
Word 1 (indices 24-27) contains Z1
Word 0 (indices 28-31) contains Z0
So:

New word 7 (indices 0-3) = old Z6 = old word 6 (indices 4-7)
New word 6 (indices 4-7) = old Z4 = old word 4 (indices 12-15)
New word 5 (indices 8-11) = old Z7 = old word 7 (indices 0-3)
New word 4 (indices 12-15) = old Z5 = old word 5 (indices 8-11)
New word 3 (indices 16-19) = old Z2 = old word 2 (indices 20-23)
New word 2 (indices 20-23) = old Z0 = old word 0 (indices 28-31)
New word 1 (indices 24-27) = old Z3 = old word 3 (indices 16-19)
New word 0 (indices 28-31) = old Z1 = old word 1 (indices 24-27)
Permutation array for PermuteLayer_CVL (dest index -> source index): [4, 5, 6, 7, 12, 13, 14, 15, 0, 1, 2, 3, 8, 9, 10, 11, 20, 21, 22, 23, 28, 29, 30, 31, 16, 17, 18, 19, 24, 25, 26, 27]

Let's verify with a simple example. If Z = 0x76543210 (as 8 nibbles), then: Z7=7, Z6=6, Z5=5, Z4=4, Z3=3, Z2=2, Z1=1, Z0=0 U7=Z6=6, U6=Z4=4, U5=Z7=7, U4=Z5=5, U3=Z2=2, U2=Z0=0, U1=Z3=3, U0=Z1=1 U = 0x6475_2031

Wait, U7||U6||U5||U4||U3||U2||U1||U0 = 6||4||7||5||2||0||3||1 = 0x64752031.

In the vector: Z = 0x76543210 int_to_vec(0x76543210, 32): Binary: 0111 0110 0101 0100 0011 0010 0001 0000 Vector: (0,1,1,1, 0,1,1,0, 0,1,0,1, 0,1,0,0, 0,0,1,1, 0,0,1,0, 0,0,0,1, 0,0,0,0)

After permutation: Word 7 (0-3) <- word 6 (4-7): (0,1,1,0) -> first 4 bits of result = 0110 = 6 ✓ Word 6 (4-7) <- word 4 (12-15): (0,1,0,0) -> 0100 = 4 ✓ Word 5 (8-11) <- word 7 (0-3): (0,1,1,1) -> 0111 = 7 ✓ Word 4 (12-15) <- word 5 (8-11): (0,1,0,1) -> 0101 = 5 ✓ Word 3 (16-19) <- word 2 (20-23): (0,0,1,0) -> 0010 = 2 ✓ Word 2 (20-23) <- word 0 (28-31): (0,0,0,0) -> 0000 = 0 ✓ Word 1 (24-27) <- word 3 (16-19): (0,0,1,1) -> 0011 = 3 ✓ Word 0 (28-31) <- word 1 (24-27): (0,0,0,1) -> 0001 = 1 ✓

Result vector: (0,1,1,0, 0,1,0,0, 0,1,1,1, 0,1,0,1, 0,0,1,0, 0,0,0,0, 0,0,1,1, 0,0,0,1) = 0110 0100 0111 0101 0010 0000 0011 0001 = 0x64752031 ✓

So the permutation is correct.

Now let me understand the Feistel network in the cipher:

For each round i: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)
This means: new right half = F(old right half, round key) XOR (old left half <<< 8)
new left half = old right half
Wait, in a Feistel network: Initially: L = X1, R = X0 After round 1: L1 = R0 = X0, R1 = F(L0, K0) XOR R0 = F(X1, K1) XOR X0

Wait, the spec says Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8). For i=2: X2 = F(X1, K1) XOR (X0 <<< 8)

But the figure shows:

X0 goes through <<< 8
X1 goes through F with K1
Then they are XORed
Then there's a swap
And after the swap, the outputs become the inputs for the next round.

Let's trace through the first round from the figure:

Inputs: X1 (left) and X0 (right)
X0 <<< 8
F(X1, K1)
XOR of these two
Then swap: the XOR result becomes the new left, and X1 becomes the new right
Wait, the figure shows X1 going down to the bottom left (becoming X32 eventually) and the XOR output going down to the bottom right. But there's a cross in between (swap).

Actually looking at the figure more carefully: Top: X1 on left, X0 on right After first round operations: there are two lines crossing The left output of the first round goes down to become the right input of the second round... Wait, in a Feistel network typically: L_{i+1} = R_i R_{i+1} = L_i XOR F(R_i, K_i)

But LBlock is a "variant" Feistel network. Looking at the equation: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)

For round 1 (i=2): X2 = F(X1, K1) XOR (X0 <<< 8)

And looking at the figure, after the first round:

The left branch output is X1 (unchanged, just crossed over)
The right branch output is X2 = F(X1, K1) XOR (X0 <<< 8)
Wait no, in the figure, X1 goes into F, and X0 goes through <<< 8, then they XOR. The output of XOR then swaps with X1. So after the first round: New left = X1 (which was old left, but it swapped) New right = F(X1, K1) XOR (X0 <<< 8)

Actually in the figure, the left output after the first crossing is the XOR result, and the right output is X1. So: After round 1: left = F(X1, K1) XOR (X0 <<< 8) = X2, right = X1

For round 2 (i=3): X3 = F(X2, K2) XOR (X1 <<< 8)

So the pattern is: After round i-1: left = Xi-1, right = Xi-2 During round i: new_left = Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8), new_right = Xi-1

But the swap means the output of round i is: left_out = Xi-1 (going to the right branch) right_out = Xi (going to the left branch)

Wait, let me re-read the figure. The dashed box indicates multiple rounds. After the first crossing:

The line that was on the left (from X1) goes to the right
The line that was on the right (from XOR) goes to the left
Actually looking at standard Feistel diagrams, the crossing is a swap. After the swap:

The left half becomes what was on the right (the XOR output)
The right half becomes what was on the left (X1)
Hmm, but looking at the final output labels: X32 on the left, X33 on the right. And the inputs are X1 on the left, X0 on the right.

Let me trace: Start: left=X1, right=X0 Round 1: temp = F(X1, K1) XOR (X0 <<< 8) = X2 After swap: left=X2, right=X1 Round 2: temp = F(X2, K2) XOR (X1 <<< 8) = X3 After swap: left=X3, right=X2 ... Round 32: After computing X33, is there a final swap?

The spec says: Output C = X32 || X33 And looking at the figure, after the last F function and XOR, there is NO swap. The left output is X32 (directly from the left line) and the right output is X33 (from the XOR).

Wait, let me look again. The last round shows:

Left input goes to F with K32
Right input goes through <<< 8
They XOR
Left output is the left input directly (X32)
Right output is the XOR result (X33)
So it seems like there is a swap after every round EXCEPT the last one? Or maybe the convention is that after each round there IS a swap, but in the diagram the crossings represent the swaps.

Let's think about this more carefully. In the figure:

Top left: X1, top right: X0
First crossing (after round 1): the line from X1 goes to the right, the XOR result goes to the left
After the dashed rounds, there's another crossing
Then the last round: left input comes from the left side of the second crossing, right input comes from the right side
Actually, in the figure there are TWO visible crossings: one before the dashed box and one after. The dashed box represents rounds 2-31.

Wait, I think the standard interpretation is:

Before round 1: X1 (left), X0 (right)
After round 1: the outputs cross, so left=X2, right=X1
Rounds 2-31 follow the same pattern
After round 31: left=X32, right=X31
After round 32: left=X32, right=X33
But the figure shows the last round differently: there is no swap at the end. The left output is X32 and the right is X33.

Let me re-read the equation: For i = 2, 3, ..., 33: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)

And C = X32 || X33

So:

X2 = F(X1, K1) XOR (X0 <<< 8)
X3 = F(X2, K2) XOR (X1 <<< 8)
...
X33 = F(X32, K32) XOR (X31 <<< 8)
The ciphertext is X32 || X33.

In a Feistel network implementation, if we start with (X1, X0):

After round 1 (using K1): the halves would typically be (X0, F(X1,K1) XOR X0) without swap, or (F(X1,K1) XOR X0, X1) with swap.
Looking at the diagram again carefully: The top crossing means: after the first round, the left half is X2 and the right half is X1. Then rounds 2-31 follow. After the bottom crossing: left is X32 and right is X31? Wait, the bottom crossing appears BEFORE the last round.

Tracing through the figure:

Start: left=X1, right=X0
First round: compute F(X1,K1) XOR (X0<<<8) = X2
Swap: left=X2, right=X1
Rounds 2-31 continue similarly...
Before round 32: left=X32, right=X31
Round 32: compute F(X32, K32) XOR (X31<<<8) = X33
Output: left=X32, right=X33 (NO final swap)
Wait, but the figure shows a swap AFTER the last round too? No, looking at the figure, after the last XOR on the right side, the output goes directly to X33. The left side goes directly to X32. But there IS a crossing shown between rounds 31 and 32.

Actually wait, I think I miscounted. The figure shows one crossing between round 1 and round 2 (the top crossing), and another crossing after the last block of rounds (the bottom crossing). The dashed box represents rounds 2 through 31.

Wait, there are 32 rounds total. After round 1 there's a swap. Then rounds 2-31. Before round 32 there's another swap. Then round 32 with no final swap.

No, that would mean there are swaps after rounds 1, 2, ..., 31 but not after 32.

Actually in the figure:

Top: Inputs X1, X0
Round 1 (K1): compute F(X1,K1) XOR (X0<<<8)
Crossing: swap
Dashed: rounds 2-31 (with swaps between them)
Crossing: swap
Round 32 (K32): compute F(X32,K32) XOR (X31<<<8)
Outputs: X32, X33 (no final swap)
Hmm, but that would mean there are 32 rounds with 32 swaps, plus an extra swap before round 32? That seems wrong.

Let me re-examine. The figure shows:

A horizontal line for X1 going through to the first F box, then continuing downward
A horizontal line for X0 going to <<<8, then XOR, then crossing down
The crossing sends X1 to the right side and the XOR result to the left side
Dashed box: rounds in between
Another crossing
After the bottom crossing, left side continues to the last F, right side continues to last <<<8
After last XOR: outputs X32 and X33
So the structure is: Round 1: compute X2, then swap so left=X2, right=X1 Round 2: compute X3, then swap so left=X3, right=X2 ... Round 31: compute X32, then swap so left=X32, right=X31 Round 32: compute X33, NO swap, output left=X32, right=X33

Wait, if round 31 ends with a swap, then before round 32: left=X32, right=X31. Then round 32: X33 = F(X32, K32) XOR (X31 <<< 8). Output: left=X32, right=X33. This matches the figure!

But actually, looking at standard Feistel ciphers, the last round typically does NOT include a swap. This is consistent with what I see.

So in the implementation:

Start with left half and right half
For each of 32 rounds:
new_left = F(old_left, Ki) XOR (old_right <<< 8)
new_right = old_left
Swap for next round (except after last round)
Wait, after computing new_left and new_right, if we swap, then for the next round: old_left_next = new_right = old_left old_right_next = new_left = F(old_left, Ki) XOR (old_right <<< 8)

But the equation says: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)

If after round i-1, the halves are (Xi-1, Xi-2) with Xi-1 on the left and Xi-2 on the right: Round i: new_left = F(Xi-1, Ki) XOR (Xi-2 <<< 8) = Xi After swap: left=Xi-1, right=Xi

Hmm, that doesn't match. Without the swap view: If we DON'T swap after computing:

After round 1: left=X2, right=X1
Round 2 uses left=X2 and right=X1: computes X3 = F(X2, K2) XOR (X1 <<< 8)
After round 2: left=X3, right=X2
...
After round 31: left=X32, right=X31
Round 32: computes X33 = F(X32, K32) XOR (X31 <<< 8)
Final: left=X33, right=X32
But the ciphertext is X32 || X33, not X33 || X32. So the last round must NOT swap, and we output (right, left) = (X32, X33).

Actually, I think the cleanest way is:

After each round, swap the halves.
The round computes: new_right = F(old_left, Ki) XOR (old_right <<< 8), new_left = old_left
Wait no, that's not right either.
Let's think about it differently. In a Feistel network, the usual structure is: L_{i+1} = R_i R_{i+1} = L_i XOR F(R_i, K_i)

For LBlock: L_{i+1} = R_i <<< 8? No... Actually if we define: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)

Then comparing to standard Feistel: If L_i = Xi-1 and R_i = Xi-2, then: L_{i+1} = R_i = Xi-2? No...

Let me try: Let L_i = Xi and R_i = Xi-1. Then for round i+1: L_{i+1} = R_i = Xi-1? Still doesn't match.

OK, let me just follow the equations directly: Start: state = (X1, X0) For i from 1 to 32: temp = F(state[0], Ki) XOR (state[1] <<< 8) = Xi+1 state = (state[1], temp) if i < 32? No...

Wait. Let's trace: i=1: temp = F(X1, K1) XOR (X0 <<< 8) = X2 After round 1, for round 2, we need (X2, X1) as inputs... or (X1, X2)?

Looking at round 2: we need X2 and X1. X2 is the result of F(X1,K1) XOR (X0<<<8). X1 was the left input. In the diagram, after round 1, the left line carries the XOR result (X2) and the right line carries X1. But then the swap crosses them, so going into round 2:

Left line has X2
Right line has X1
For round 2: F uses left input (X2) with K2, right input (X1) goes through <<<8. Result: X3 = F(X2, K2) XOR (X1 <<< 8) After swap: left has X3, right has X2.

Pattern after each round with swap: After round i: left =

Let me look at how cipher.add_subcipher handles edges, and read sboxcipher.py and wordbasedcipher.py briefly, to understand WordSBoxCipher better.

Now I have a good understanding of the codebase. Let me design the LBlock implementation.

LBlock is a 64-bit block cipher with 32 rounds. It uses:

Variant Feistel network
Round function F: XOR with round key -> S-box layer -> permutation P
8 parallel 4-bit S-boxes (s0-s7)
Word-level permutation P on 8 words of 4 bits each
Left rotation by 8 bits on 32-bit word
For the CiVerLy implementation, LBlock uses:

S-boxes: SBox_CVL
Permutation: PermuteLayer_CVL with word_coarseness=4
Rotation: RotateLayer_CVL with word_coarseness=1 (or 8? the rotation is on 32 bits, shifting by 8 bits, which is exactly 2 bytes, or 8 bits)
XOR: XOR_CVL
Key mixing: RoundkeyXOR_CVL
Since LBlock is S-box based with linear layers (permutation) and XORs, it fits well in SBoxCipher. But since it also has word-oriented structure (4-bit words), maybe WordSBoxCipher would be appropriate if we want wordwise MILP. However, PRESENT uses WordSBoxCipher with wordsize=4.

For LBlock, the S-boxes are 4-bit, the permutation acts on 4-bit words, and the rotation acts on bits (<<< 8 on 32 bits, which is exactly 2 bytes). For WordSBoxCipher, we would use wordsize=4.

Actually, let me check if RotateLayer_CVL works with WordSBoxCipher. In PRESENT, they use PermuteLayer_CVL on bits. For LBlock, the rotation is <<< 8 on 32 bits. Since 8 is a multiple of 4, it can be seen as a rotation of 2 words if word_coarseness=4. But the spec defines it as an 8-bit left cyclic shift on 32-bit, so it's a bit-level rotation of 8 positions.

Let me think about whether to use SBoxCipher or WordSBoxCipher. Since LBlock's state is naturally decomposed into 4-bit words (the S-box inputs), and we might want wordwise MILP modeling, WordSBoxCipher with wordsize=4 seems like a good choice, similar to PRESENT.

But wait, RotateLayer_CVL with word_coarseness=1 would rotate bits, and RotateLayer_CVL with word_coarseness=4 would rotate words. For LBlock, the rotation is 8 bits on a 32-bit word. That's RotateLayer_CVL(32, 8, word_coarseness=1). If we use WordSBoxCipher(4, 16, 16), the rotation would need to act on bits...

Wait, looking at WordBasedCipher, maybe RotateLayer_CVL works the same regardless. Let me check if there's any restriction.

Looking at component.py, RotateLayer_CVL inherits from PermuteLayer_CVL. It can work with any word_coarseness.

For WordSBoxCipher, the edges are given in terms of word indices (not bit indices). So if wordsize=4, a 32-bit value has 8 words. The rotation by 8 bits (2 words) would correspond to rotating the 8 words by 2 positions to the left.

In WordSBoxCipher, add_subcipher handles the edges as word indices. So:

RotateLayer_CVL(32, 8, word_coarseness=1) rotates 32 bits by 8 bit positions. But in a WordSBoxCipher with wordsize=4, we'd need to express this as a word-level operation.
Actually, wait. WordBasedCipher.add_subcipher expands word edges to bit edges internally. So if we add a RotateLayer_CVL(32, 8, word_coarseness=1) to a WordSBoxCipher, the edges would be word indices but the component operates on bits.
Hmm, let me re-read wordbasedcipher.py to understand how edges work.

Actually, I don't have wordbasedcipher.py content yet, but from the README:

WordBasedCipher.add_subcipher() edges like bit edges instead of word edges; the method expands them internally.

Wait, actually that says "Using bit edges instead of word edges". Let me re-read: "Using WordBasedCipher.add_subcipher() edges like bit edges instead of word edges; the method expands them internally."

So in WordBasedCipher (and thus WordSBoxCipher), when you add an edge (node, (src, dst)), src and dst are WORD indices, not bit indices. The cipher automatically expands them.

But components like PermuteLayer_CVL and RotateLayer_CVL operate on bits. So when we add PermuteLayer_CVL to a WordSBoxCipher, if the permutation is on words, we set word_coarseness=wordsize, and if it's on bits, we set word_coarseness=1.

For LBlock:

S-boxes operate on 4-bit words
Permutation P operates on 4-bit words (word_coarseness=4)
Rotation <<< 8 operates on bits but 8 is a multiple of 4, so it's effectively rotating 8 words by 2 word positions. So word_coarseness=4, RotateLayer_CVL(8, 2, word_coarseness=4)... wait no.
Actually RotateLayer_CVL(input_length, r, word_coarseness) where input_length is the number of units. If word_coarseness=4, then we're rotating input_length/4 words? No, input_length is in bits.

So for a 32-bit rotation:

RotateLayer_CVL(32, 8, word_coarseness=1) rotates 32 bit positions by 8 bits.
For WordSBoxCipher with wordsize=4, if we want to express the rotation in word edges:

The 32-bit value has 8 words (0 to 7).
Rotating left by 8 bits = rotating left by 2 words.
So we could use RotateLayer_CVL(32, 8, word_coarseness=1), and when wiring it in a WordSBoxCipher, we'd need to wire all 32 bits (or 8 words?).
Wait, I need to understand how WordBasedCipher handles edges. Since I don't have wordbasedcipher.py, let me look at how PRESENT does it. In PRESENT:

sboxlayer = WordSBoxCipher(4, 16, 16, name="SBoxLayer")
for j in range(16):
    node = sboxlayer.add_subcipher(s, [(sboxlayer.IN, (j, 0))])
    sboxlayer.add_output([(node, (0, j))])
And for the permutation:

permutation = PermuteLayer_CVL([...64 entries...], name="Permutation")
Wait, the permutation is on 64 bits, and they wire it with [(node, (i, i)) for i in range(16)] where i goes from 0 to 15. But the permutation array has 64 entries (bit-level). In WordSBoxCipher, the edges are word indices. So range(16) means 16 words, each of 4 bits = 64 bits. The add_subcipher in WordBasedCipher expands word edges to bit edges internally.

So for WordSBoxCipher with wordsize=4:

An edge (node, (i, i)) where i is a word index means bits 4*i to 4*i+3 are connected from source bit 4*i to dest bit 4*i.
For PermuteLayer_CVL, if we want a word-level permutation, we need word_coarseness=4. But PRESENT's permutation is a bit-level permutation (word_coarseness defaults to 1), and they still use range(16) edges. How does that work?

Actually wait, looking at PRESENT again:

node = present_round.add_subcipher(
    permutation, [(node, (i, i)) for i in range(16)]
)
If WordBasedCipher expands word indices to bit indices, then (i, i) for i in range(16) would expand to (4*i + j, 4*i + j) for j in range(4). That means it connects word i to word i of the permutation. But the permutation is bit-level, so within each word, the bits are permuted according to the PermuteLayer_CVL array. Since the permutation array has 64 entries and word_coarseness=1, it operates on individual bits. The wiring connects all 64 bits (mapped through the word expansion), so it works correctly.

For LBlock, if we use WordSBoxCipher(4, 16, 16) (wordsize=4, 16 input words, 16 output words = 64 bits), the edges in add_subcipher are word indices from 0 to 15.

Wait, PRESENT is WordSBoxCipher(4, 16, 16) meaning wordsize=4, 16 input words, 16 output words. Total bits = 64.

For LBlock, the block size is 64 bits. So we'd also use WordSBoxCipher(4, 16, 16).

Now for the Feistel structure of LBlock: Each round operates on 64 bits, split into two 32-bit halves.

Left half: 8 words (indices 0-7 in the 64-bit state? or 0-7 for the upper 32 bits?)
Right half: 8 words (indices 8-15)
In PRESENT, the state is flat. For LBlock Feistel, I need to decide how to map the 64 bits to 16 words. Word 0-7: left half (32 bits, MSB half) Word 8-15: right half (32 bits, LSB half)

Or maybe: Word 0-7: right half? Let me think about int_to_vec mapping.

int_to_vec(plaintext, 64) maps bit 0 of vector to MSB of the 64-bit integer. If we think of X1 || X0 as a 64-bit integer, then X1 is the upper 32 bits (MSB half) and X0 is the lower 32 bits.

In the vector:

Vector indices 0-31 correspond to X1 (MSB half)
Vector indices 32-63 correspond to X0 (LSB half)
In terms of words (wordsize=4):

Words 0-7 correspond to X1 (bits 0-31)
Words 8-15 correspond to X0 (bits 32-63)
For RotateLayer_CVL(32, 8) on the right half: Wait, we only want to rotate the right half by 8 bits, not the whole 64 bits. So we need a rotation on a 32-bit chunk.

Hmm, in DES example, they handle halves by wiring specific indices. For LBlock, we can do the same: instead of using RotateLayer_CVL, we can manually create a PermuteLayer_CVL that represents the rotation on the right half while keeping the left half unchanged... or we can just use RotateLayer_CVL on the full 64-bit state but with a permutation that only rotates the right half.

Actually, a simpler approach is to use SBoxCipher (not WordSBoxCipher) so we can work with bit indices directly. Since LBlock's Feistel structure requires flexible wiring between halves, using bit-level edges might be clearer. We would lose wordwise MILP, but PRESENT has the same wordwise MILP limitation anyway (branch number of permutation is 2).

Actually, looking at the DES implementation, they use SBoxCipher with explicit bit indices. DES also has a Feistel structure with left/right halves, and they wire specific bit positions.

I think using SBoxCipher with bit-level wiring would be cleaner for LBlock's Feistel structure, and it avoids any confusion about word-level permutations vs bit-level rotations.

Let me design the LBlock round using SBoxCipher:

Round function inputs: 64 bits (left=32, right=32) Round function outputs: 64 bits

Inside a round:

Apply F to the left half (32 bits) with the round key
RoundkeyXOR_CVL(32) on left half
SBox layer: 8 parallel SBox_CVL(4-bit)
Permutation P: PermuteLayer_CVL(32, word_coarseness=4 or bit-level)
XOR F output with rotated right half
Rotate right half by 8 bits
XOR with F output
Swap: left half for next round = old right half, right half = XOR result
Wait, in the Feistel structure of LBlock:

Start: left=X1, right=X0
Round i: new_left = right, new_right = F(left, Ki) XOR (right <<< 8)
This is with swap. After 32 rounds, output = left || right.
Actually let's trace: i=1: temp = F(X1, K1) XOR (X0 <<< 8) = X2. After swap: left = X0, right = X2. Wait, that's not right. After swap, left should be the previous right, and right should be temp. If we define: L_{i+1} = R_i R_{i+1} = F(L_i, K_i) XOR (R_i <<< 8)

Wait, no. Let me re-read the equations: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8)

At round 1 (i=2): X2 = F(X1, K1) XOR (X0 <<< 8) If L_1 = X1, R_1 = X0: L_2 = R_1 = X0? No, L_2 should be X2. Wait, maybe: L_i = Xi, R_i = Xi-1 Then L_{i+1} = X_{i+1} = F(Xi, Ki) XOR (Xi-1 <<< 8) = F(L_i, Ki) XOR (R_i <<< 8) And R_{i+1} = L_i = Xi

So: L_{i+1} = F(L_i, Ki) XOR (R_i <<< 8) R_{i+1} = L_i

After round 1: L_2 = X2, R_2 = X1 After round 2: L_3 = X3, R_3 = X2 ... After round 32: L_33 = X33, R_33 = X32

But the ciphertext is X32 || X33. So: C = R_33 || L_33

This means after the last round, we need to output (R_33, L_33) instead of (L_33, R_33). That's equivalent to doing a final swap, or just wiring the outputs in reverse order.

Wait, actually in the standard Feistel view: After round i, the state is (L_{i+1}, R_{i+1}). After 32 rounds, state is (L_33, R_33) = (X33, X32). Ciphertext = X32 || X33 = R_33 || L_33.

So after 32 rounds, we output (right, left) - a final swap.

But looking at the LBlock figure again, there doesn't seem to be a final swap in the diagram. The left output is X32 and the right output is X33.

Let me look at the figure once more. The bottom round computes:

Left line goes into F
Right line goes through <<< 8
XOR
Left output is X32 (directly from the left input line)
Right output is X33 (from XOR)
Wait, that's NOT a swap! In the last round, the left output is the left input, and the right output is the XOR result. But in standard Feistel, we'd have: L_{33} = F(L_{32}, K_{32}) XOR (R_{32} <<< 8) = X33 R_{33} = L_{32} = X32

But the figure shows X32 on the left and X33 on the right. So the state after round 32 is (X32, X33), not (X33, X32). That means there was NO swap after round 32.

If there was a swap after each of rounds 1-31, then before round 32: State = (X32, X31) Round 32: L_{33} = F(X32, K32) XOR (X31 <<< 8) = X33, R_{33} = X32 Without swap: output = (X32, X33) ... wait, if we don't swap after round 32, the output would be (L_{32}, R_{32}) before round 32? No...

Let me think about this differently. Suppose each round is defined as: temp = F(left, Ki) XOR (right <<< 8) new_left = right new_right = temp

This is WITH swap.

After round 1: (X0, X2) if left started as X1 and right as X0? No, left=X1, right=X0. temp = F(X1, K1) XOR (X0 <<< 8) = X2 new_left = X0, new_right = X2

After round 2: left=X0, right=X2. temp = F(X0, K2) XOR (X2 <<< 8) = X3? But the equation says X3 = F(X2, K2) XOR (X1 <<< 8).

So this doesn't work. The left half for round 2 must be X2, not X0.

So the update must be: temp = F(left, Ki) XOR (right <<< 8) new_left = temp new_right = left

Wait, after round 1: left=X2, right=X1. Round 2: temp = F(X2, K2) XOR (X1 <<< 8) = X3. new_left = X3, new_right = X2. ✓ ... After round 31: left=X32, right=X31. Round 32: temp = F(X32, K32) XOR (X31 <<< 8) = X33. new_left = X33, new_right = X32.

If we then do NOT swap, the final state is (X33, X32). But the ciphertext should be X32 || X33. So we need the final state to be (X32, X33). This requires a final swap.

Hmm, but the figure doesn't show a final swap. It shows the outputs directly as X32 and X33 with X32 on the left and X33 on the right.

Wait! Maybe the crossings in the diagram ARE the swaps. Let me look at the diagram more carefully.

In the figure, round 1 is at the top. After the XOR, there are two lines that cross (swap). Then there are dashed lines for intermediate rounds. Then before round 32, there are two lines that cross again. Then round 32 happens. Then the outputs come out without crossing.

So:

Start: X1 (left), X0 (right)
Round 1: XOR result = X2
Cross/swap: left becomes X2? No, the swap sends the right branch (X0) to the left and the XOR result (X2) to the right. So after swap: left=X0, right=X2.
But then round 2 would use left=X0, which is wrong because X3 = F(X2, K2) XOR (X1 <<< 8).
Wait, maybe I have the branches mixed up. In the diagram:

X1 is the top-left input
X0 is the top-right input
X1 goes to F
X0 goes to <<< 8
They XOR
The XOR output is on the right side after the XOR circle
Then both lines go to a crossing
After the crossing, the left line comes from the right side (i.e., from the XOR output)
The right line comes from the left side (i.e., from X1)
Wait, actually in standard Feistel diagrams:

Left input and right input
F operates on left
XOR with right
Then SWAP: the new left = old right, new right = XOR result
But in LBlock, F operates on the left, XORs with rotated right, then the outputs cross so that:

New left = old right (which wasn't changed, except it went to the right branch then crossed to left)
New right = XOR result (which crossed from right to left, then... wait)
Actually, looking at the crossing more carefully:

The line coming from X1 (left input) goes down and crosses to the RIGHT side
The line coming from XOR (right side) goes down and crosses to the LEFT side
So after the crossing:

Left side carries the XOR result = X2
Right side carries X1
Then round 2 uses left=X2 and right=X1. That makes sense! X3 = F(X2, K2) XOR (X1 <<< 8). ✓

And after round 2:

Left side = X3
Right side = X2
...

After round 31:

Left side = X32
Right side = X31
Before round 32, there is another crossing shown in the figure! Wait, looking at the figure again, there are two crossings: one after round 1, and one after the dashed box (before round 32).

After that second crossing:

Left side = X31
Right side = X32
Then round 32:

F operates on left = X31 with K32
XOR with right <<< 8 = X32 <<< 8
Result = X33? But the equation says X33 = F(X32, K32) XOR (X31 <<< 8).
This is wrong! F should operate on X32, not X31.

Let me look at the figure again very carefully. Actually, maybe I'm miscounting the crossings.

Looking at the figure:

Top: X1, X0
After round 1: lines cross (one crossing)
Dashed box: rounds 2 to 31
After dashed box: lines cross again (second crossing)
Then round 32
Outputs: X32, X33
Wait, maybe the dashed box corresponds to rounds 2 through 31, and the crossings at the boundaries of the dashed box are just showing that there are swaps between every pair of consecutive rounds. So:

After round 1: swap
After round 2: swap
...
After round 31: swap
Round 32: no swap after
If there are 32 rounds, and we swap after rounds 1 through 31, then: After 31 rounds with swaps: since 31 is odd, the halves are swapped relative to the standard. Actually, let me just trace mathematically:

Define round operation with swap: Start: (L, R) = (X1, X0) For round i from 1 to 32: T = F(L, Ki) XOR (R <<< 8) If i < 32: (L, R) = (T, L) # swap Else: (L, R) = (L, T) # no swap? Or (T, L)?

Wait, the equation says Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8). And ciphertext = X32 || X33.

Let's try: For i=1 to 32: T = F(L, Ki) XOR (R <<< 8) (L, R) = (R, T) # standard Feistel with swap

Round 1: T = F(X1, K1) XOR (X0 <<< 8) = X2 (L, R) = (X0, X2)

Round 2: T = F(X0, K2) XOR (X2 <<< 8) But we need X3 = F(X2, K2) XOR (X1 <<< 8). So this is wrong.

Try without swap: For i=1 to 32: T = F(L, Ki) XOR (R <<< 8) (L, R) = (T, L) # new left = T, new right = old left

Round 1: T = X2. (L, R) = (X2, X1). Round 2: T = F(X2, K2) XOR (X1 <<< 8) = X3. (L, R) = (X3, X2). ✓ ... Round 31: (L, R) = (X32, X31). Round 32: T = F(X32, K32) XOR (X31 <<< 8) = X33. (L, R) = (X33, X32).

Now the final state is (X33, X32). But we want ciphertext = X32 || X33. So we need to output the final state as (R, L) = (X32, X33).

This means: use the "no swap after last round" variant, but then reverse the halves for output. OR: use swap after all rounds, and output (L, R).

Actually, if we use swap after all rounds: Round 32: T = X33. (L, R) = (X32, X33) if we swap. But then the equation for round 32 would be wrong because we'd need F(R, K32) XOR (L <<< 8) with L=X32 and R=X33? No, that doesn't match.

Wait, let me re-think. The DES example in the code:

round_function.add_output(
    [(round_function.IN, (i + 32, i)) for i in range(32)]
)
round_function.add_output(
    [(xor_node, (i, i + 32)) for i in range(32)]
)
This means:

Output bits 0-31 (left half) = input bits 32-63 (right half)
Output bits 32-63 (right half) = XOR result bits 0-31
So for DES, the round function outputs: (old_right, F(old_right) XOR old_left) with a swap.

In standard Feistel: L' = R R' = L XOR F(R)

But DES outputs: (R, L XOR F(R)). Wait, the round function in DES includes the swap! And then in the full cipher, the round function is applied R times, and there is NO final swap.

For LBlock, maybe it's the same: the round function includes a swap. Then after 32 rounds, since all rounds have swaps, the final output would be: After round 32: L' = R, R' = F(L, K32) XOR (R <<< 8) But we need this to equal (X32, X33).

Let's trace with round function including swap: Start: (X1, X0) Round 1: L' = X0, R' = F(X1, K1) XOR (X0 <<< 8) = X2 But we need after round 1 for round 2 inputs to be (X2, X1). So this is wrong.

Let's try again with round function that swaps but using the "variant" Feistel order: LBlock round function:

Input: (L, R)
Compute T = F(L, Ki) XOR (R <<< 8)
Output: (R, T) -- swap
Wait, output (R, T) means: After round 1: (X0, X2) Round 2 inputs: L=X0, R=X2 T = F(X0, K2) XOR (X2 <<< 8) But equation says X3 = F(X2, K2) XOR (X1 <<< 8). This would need L=X2, not X0.

So swap doesn't help. What if round function is:

Output: (T, R)? Round 1: (X2, X0) Round 2: L=X2, R=X0 T = F(X2, K2) XOR (X0 <<< 8) But equation needs X3 = F(X2, K2) XOR (X1 <<< 8). R should be X1, not X0.
What if round function is:

Output: (T, L)? Round 1: (X2, X1) ✓ Round 2: L=X2, R=X1 T = F(X2, K2) XOR (X1 <<< 8) = X3 Output: (X3, X2) ✓ ... Round 31: (X32, X31) Round 32: L=X32, R=X31 T = F(X32, K32) XOR (X31 <<< 8) = X33 Output: (X33, X32)
For ciphertext X32 || X33, we need to output the reverse: (X32, X33). So after 32 rounds with output=(T, L), we need to reverse the halves for the final output, OR add a final swapping layer.

But in the figure, after the last XOR, there is no swap. The left output is X32 and right is X33.

Wait, I think the round 32 in the figure is the LAST round, and there IS a swap before it. Let me look at the crossings in the figure again.

Actually, maybe the figure shows rounds with the following pattern:

Before round 1: (X1, X0)
Round 1 computes X2 = F(X1, K1) XOR (X0 <<< 8)
After round 1, swap: (X1, X2) [left=X1, right=X2]
Round 2 computes X3 = F(X2, K2) XOR (X1 <<< 8)? No, F operates on left=X1.
So that can't be right.

OK, let's just follow the equations directly and not worry about swaps in the figure. The spec is clear: For i = 2, ..., 33: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8) C = X32 || X33

If we view this as a recurrence where each new state depends on the previous two:

State after step i: (Xi, Xi-1)

Start state: (X1, X0) Step 1 (i=2): X2 = F(X1, K1) XOR (X0 <<< 8), state = (X2, X1) Step 2 (i=3): X3 = F(X2, K2) XOR (X1 <<< 8), state = (X3, X2) ... Step 31 (i=32): X32 = F(X31, K31) XOR (X30 <<< 8), state = (X32, X31) Step 32 (i=33): X33 = F(X32, K32) XOR (X31 <<< 8), state = (X33, X32)

Ciphertext = X32 || X33.

So after 32 steps, the state is (X33, X32), but we output (X32, X33). This is equivalent to: after the 32 rounds, swap the halves.

In CiVerLy, we can implement each round as:

Inputs: (L, R) = (Xi-1, Xi-2)
Compute T = F(L, Ki) XOR (R <<< 8) = Xi
Output: (T, L) = (Xi, Xi-1)
After 32 rounds, the output of the 32nd round is (X33, X32). Then we swap to get (X32, X33) as the final ciphertext.

So the round function in CiVerLy outputs (T, L), and after all rounds, we do a final swap.

Wait, but in the figure, the last round outputs X32 and X33 WITHOUT a swap. Let me look at the bottom of Figure 1 again very carefully.

Actually, looking at the figure: The bottom crossing comes BEFORE round 32. After the crossing, the left line is X31 and the right line is X32. Then the last F takes the left line (X31) into F with K32, and the right line (X32) goes through <<<8, and they XOR to produce X33 on the right side. The left output is X31, not X32!

WAIT! That contradicts the labels in the figure! The figure labels are X32 on the left and X33 on the right.

Hmm, maybe the crossings in the figure don't represent swaps of the entire halves, but just crossing lines? In electronic circuit diagrams, a crossing without a dot usually means the wires just cross without connecting.

Actually, in Feistel network diagrams, the lines crossing usually means a swap. But maybe in this figure, after the dashed box, the left line is already X32 and the right line is X31, and the "crossing" is just showing they pass each other. Then round 32 uses left=X32 and right=X31.

Wait, look at the figure. There are two visible crossings: one after the first round, and one after the dashed rounds.

Let me trace the lines carefully: After round 1 XOR, there are two lines going down. The left line (from X1) goes down-right across the crossing. The right line (from XOR) goes down-left across the crossing. After the crossing, the left side gets the XOR output, and the right side gets X1.

Then those go through the dashed box (rounds 2-31). Inside the dashed box, there are similar rounds with crossings between them. After the dashed box: The left line (which has been through the rounds) goes down-right across the second crossing. The right line goes down-left across the second crossing. After the second crossing, the left side gets what was on the right before, and vice versa.

Actually, let me think of it this way: In a Feistel network, there is a swap after each round. After 31 rounds (rounds 1-31), the state has been swapped 31 times. Since 31 is odd, the halves are reversed relative to the "no swap" state.

After round 31, before swap: (L, R) = (X32, X31) if we define the round as: new_L = F(L, Ki) XOR (R <<< 8) new_R = L

Wait, if each round is: new_L = F(L, Ki) XOR (R <<< 8) new_R = L (no explicit swap, just the assignment)

Then after round 1: (X2, X1) After round 2: (X3, X2) ... After round 31: (X32, X31) After round 32: (X33, X32)

But the figure shows crossings (swaps) between rounds. Let's try: Each round is: T = F(L, Ki) XOR (R <<< 8) (new_L, new_R) = (R, T) # swap, standard Feistel

Start: (X1, X0) After round 1: (X0, X2) After round 2: (X2, F(X0, K2) XOR (X2 <<< 8)) But we need X3 = F(X2, K2) XOR (X1 <<< 8). The right half should be X1 after round 1 for this to work, but it's X0.

So standard Feistel swap doesn't work.

What if the swap is different? Let's try: (new_L, new_R) = (T, R) # no swap of halves, just update left

Start: (X1, X0) After round 1: (X2, X0) After round 2: F(X2, K2) XOR (X0 <<< 8) = X3? No, need XOR with X1.

What if: (new_L, new_R) = (T, L)?

Start: (X1, X0) After round 1: (X2, X1) After round 2: (X3, X2) ... After round 32: (X33, X32)

This matches perfectly! And the ciphertext C = X

Let me re-check the Feistel structure by looking at the DES example which is a standard Feistel network. In DES, the round function is defined as:

f_node = round_function.add_subcipher(
    f, [(round_function.IN, (i + 32, i)) for i in range(32)]
)
xor_node = round_function.add_subcipher(
    xor,
    [
        (f_node, (i, i)) for i in range(32)
    ] + [
        (round_function.IN, (i, i + 32)) for i in range(32)
    ]
)

round_function.add_output(
    [(round_function.IN, (i + 32, i)) for i in range(32)]
)
round_function.add_output(
    [(xor_node, (i, i + 32)) for i in range(32)]
)
So DES round function outputs:

Left half (bits 0-31) = right half of input (bits 32-63)
Right half (bits 32-63) = XOR of F(right) with left
This is the standard Feistel: output = (R, L XOR F(R)).

For LBlock, if each round outputs (T, L) where T = F(L) XOR (R <<< 8):

Output bits 0-31 = T
Output bits 32-63 = L
So in CiVerLy:

F operates on left half: bits 0-31
Rotate right half: bits 32-63 <<< 8
XOR F output with rotated right
Output: left = XOR result, right = old left
This would be:

# F on left half
f_node = round.add_subcipher(f, [(round.IN, (i, i)) for i in range(32)])

# Rotate right half by 8
rot_node = round.add_subcipher(rot, [(round.IN, (i + 32, i)) for i in range(32)])

# XOR: F output XOR rotated right
xor_node = round.add_subcipher(xor, 
    [(f_node, (i, i)) for i in range(32)] + 
    [(rot_node, (i, i + 32)) for i in range(32)]
)

# Output: left = xor result, right = old left
round.add_output([(xor_node, (i, i)) for i in range(32)])
round.add_output([(round.IN, (i, i + 32)) for i in range(32)])
Wait, XOR_CVL takes input of size 2*word_length and outputs word_length. Here we want to XOR two 32-bit values. So XOR_CVL(32) with inputs of 64 bits total. Edges: [(f_node, (i, i)) for i in range(32)] + [(rot_node, (i, i + 32)) for i in range(32)] This means: input to XOR is f_output[0:32] concatenated with rot_output[0:32], total 64 bits. Output is 32 bits.

Then round outputs:

bits 0-31 = xor_node output
bits 32-63 = round input bits 0-31 (old left)
After 32 rounds: Start: (X1, X0) After round 1: (X2, X1) After round 2: (X3, X2) ... After round 32: (X33, X32)

Ciphertext = X32 || X33.

But after the last round, the state is (X33, X32). We want (X32, X33). So we need a final swap.

In the figure, the outputs are X32 (left) and X33 (right) with no final swap visible. BUT WAIT! Looking at the figure labels again: maybe the figure is slightly misleading, or maybe my interpretation of which line is which is wrong.

Actually, let me look at the figure labels very carefully. At the bottom left: X32 At the bottom right: X33 The left output line comes from the line that went straight down (didn't go through the XOR). The right output line comes from the XOR.

If the round function is defined such that:

Left output = old right
Right output = F(old left) XOR (old right <<< 8)
Then after round 32:

Left output = old right = X31
Right output = F(X32) XOR (X31 <<< 8) = X33
But the label says X32 on the left! That doesn't match.

Wait, maybe the crossings in the diagram ARE part of the rounds, and after 32 rounds with crossings, the state comes out correctly.

Let me try a different interpretation: The diagram shows that the "crossing" is actually part of the round structure. Maybe LBlock does NOT have a swap in the standard sense. Instead: Round i:

The right half of the previous round becomes the left half of the current round.
The left half of the previous round goes through F and is XORed with the rotated right half.
This is equivalent to: L_i = R_{i-1} R_i = F(L_{i-1}, K_i) XOR (R_{i-1} <<< 8)

Wait, if L_i = R_{i-1}, then for round 2: L_2 = R_1 = X0. But we need L_2 = X2 for round 3.

OK, I think the most reliable thing is to follow the equations directly: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8) C = X32 || X33

And implement it such that after 32 rounds, we can verify with test vectors.

Let me write a reference implementation in Python to verify the test vectors and understand the exact data flow.

... (writing own python implementation based on java implementation)

The reference implementation failed. I need to debug it. The issue could be in:

S-box ordering (which nibble goes to which S-box)
Permutation direction
Key schedule
Bit ordering / nibble ordering
Let me check the S-box indexing first. In the paper and Java code, S-boxes are s0-s9. The round function uses s0-s7. The figure shows s7 on the left, s0 on the right.

In my code, I did S[7 - i][nibble] where i is the nibble position from LSB. Let me reconsider.

If the 32-bit word is Y = Y7 || Y6 || Y5 || Y4 || Y3 || Y2 || Y1 || Y0:

Y7 is the most significant nibble (bits 28-31)
Y0 is the least significant nibble (bits 0-3)
And in the spec: Z7 = s7(Y7), Z6 = s6(Y6), ..., Z0 = s0(Y0)

So for nibble at position i from the left (i=0 is MSB):

nibble i goes to S-box s_{7-i}
In my code, I used i from 0 to 7 where i=0 is the LSB. That's wrong if Y0 is the LSB nibble. Wait, in the spec: Y = Y7||Y6||...||Y0, with Y7 MSB and Y0 LSB. So Y7 = bits 28-31, Y6 = bits 24-27, ..., Y0 = bits 0-3.

In my loop for i in range(8): nibble = (x >> (4 * i)) & 0xF, when i=0 I'm getting the LSB nibble, which is Y0. That should go to s0. When i=7, I'm getting the MSB nibble (bits 28-31), which is Y7. That should go to s7.

So it should be S[i][nibble], not S[7-i][nibble]. Let me fix that.

Actually wait, I also need to think about whether the S-box table in the paper is indexed with MSB-first or LSB-first. In the Java code:

uBitleri[i] = bits[i];
That code in the Java reference is incomplete, but the S-boxes are given as arrays of 16 values. Typically, S[x] means input x gives output S[x].

Let me fix the S-box indexing and see. But the bigger issue might be the permutation or key schedule.

Actually, let me write a more careful test by cross-checking individual components. Let me also check the bit ordering in int_to_vec used by CiVerLy. The vector representation has bit 0 as MSB.

For nibble extraction in my Python reference, (x >> (4 * i)) & 0xF with i=0 gives the LSB nibble. In CiVerLy's int_to_vec, bit 0 is MSB. But this is just my reference implementation - I need to make sure the math is correct regardless of representation.

Actually, for the reference implementation, the "endianness" only matters if I match it consistently. The test vectors are given as hex strings, so my math should be consistent with the hex representation.

In my current code:

for i in range(8):
    nibble = (x >> (4 * i)) & 0xF
    y |= S[7 - i][nibble] << (4 * i)
When i=0: nibble = x[0:3] (LSB), S-box = s7. But Y0 should go to s0. When i=7: nibble = x[28:31] (MSB), S-box = s0. But Y7 should go to s7.

So it should be:

for i in range(8):
    nibble = (x >> (4 * i)) & 0xF
    y |= S[i][nibble] << (4 * i)
Wait, but the Java code doesn't help because it's incomplete. Let me look at the spec again. "Z7 = s7(Y7), Z6 = s6(Y6), Z5 = s5(Y5), Z4 = s4(Y4), Z3 = s3(Y3), Z2 = s2(Y2), Z1 = s1(Y1), Z0 = s0(Y0)."

Since Y0 is the LSB nibble and s0 is applied to it, and Y7 is the MSB nibble and s7 is applied to it, the mapping is: Position i (from LSB, 0 to 7) -> nibble Yi -> si.

So yes, it should be S[i]. Let me fix that.

For the permutation: "U7 = Z6, U6 = Z4, U5 = Z7, U4 = Z5, U3 = Z2, U2 = Z0, U1 = Z3, U0 = Z1."

Where Zi is at position i (from LSB, 0 to 7). So: U7 = Z6 means MSB nibble of output = nibble at position 6 (bits 24-27) U6 = Z4 means nibble at position 6 of output = nibble at position 4 (bits 16-19) ...

In my code:

u[7] = n[6]  # MSB of output = nibble 6
u[6] = n[4]
u[5] = n[7]
u[4] = n[5]
u[3] = n[2]
u[2] = n[0]
u[1] = n[3]
u[0] = n[1]
This looks correct. Let me fix the S-box ordering first.

For the key schedule, let me re-read the spec: "K <<< 29" means left rotate the 80-bit key register by 29 bits. Then: "[k79 k78 k77 k76] = s9[k79 k78 k77 k76]" "[k75 k74 k73 k72] = s8[k75 k74 k73 k72]" "[k50k49k48k47k46] ⊕ [i]2"

In my code, I do:

K = ((K << 29) & ((1 << 80) - 1)) | (K >> (80 - 29))
This is a left rotation of the 80-bit value. Then:

nibble9 = (K >> 76) & 0xF
nibble8 = (K >> 72) & 0xF
K >> 76 gives the top 4 bits (k79 k78 k77 k76). Correct. K >> 72 gives bits k75-k72. Correct.

Then:

counter = (i + 1) & 0x1F
k_bits = (K >> 46) & 0x1F
k_bits ^= counter
K = (K & ~(0x1F << 46)) | (k_bits << 46)
K >> 46 gives bits k50-k46. XOR with 5-bit counter. Correct.

And the test vectors say: Round key K1 is the leftmost 32 bits BEFORE any update.

In my code:

for i in range(rounds):
    rks.append((K >> 48) & 0xFFFFFFFF)  # leftmost 32 bits
    # ... update K
Wait, K >> 48 gives bits k79 down to k48. That's 32 bits (79-48+1 = 32). Correct. But we need K1 for round 1, then update, then K2 for round 2, etc.

In the spec:

Output K1 (leftmost 32 bits of initial K)
For i = 1 to 31: (a) K <<< 29 (b) apply s9, s8 (c) XOR counter (d) Output Ki+1 (leftmost 32 bits)
So:

K1 from initial K
After first update: K2
...
After 31st update: K32
In my code, I'm doing for i in range(rounds):

i=0: append K1, update K to get K2
i=1: append K2, update K to get K3
...
i=31: append K32
This seems correct. But wait, rounds=32, so range(32) gives i=0 to 31, which appends 32 round keys. Correct.

Let me fix the S-box and run again.

Both test vectors pass. Now I understand the cipher correctly:

S-box layer: For each nibble position i (0=LSB to 7=MSB), apply S[i] to that nibble. Permutation: U7=Z6, U6=Z4, U5=Z7, U4=Z5, U3=Z2, U2=Z0, U1=Z3, U0=Z1. Feistel: Xi = F(Xi-1, Ki-1) XOR (Xi-2 <<< 8), ciphertext C = X32 || X33.

In terms of state updates (without explicit swap in each round): State after round i: (Xi+1, Xi)

Start: (X1, X0) Round 1: X2 = F(X1, K1) XOR (X0 <<< 8), state (X2, X1) Round 2: X3 = F(X2, K2) XOR (X1 <<< 8), state (X3, X2) ... Round 32: X33 = F(X32, K32) XOR (X31 <<< 8), state (X33, X32)

Output should be X32 || X33, but the state after round 32 is (X33, X32). So we need to output the halves reversed.

Wait, this means my CiVerLy round function should output:

Left half = F(L, Ki) XOR (R <<< 8)
Right half = L
After 32 rounds, the state is (X33, X32). We want ciphertext X32 || X33. So the final output should be the right half concatenated with the left half, i.e., a final swap.

In terms of the figure in the paper, maybe the crossings show a different convention. But mathematically, this is correct because the test vectors pass.

Wait, actually let me think about the DES round function structure again. In DES:

round_function.add_output(
    [(round_function.IN, (i + 32, i)) for i in range(32)]
)
round_function.add_output(
    [(xor_node, (i, i + 32)) for i in range(32)]
)
This means:

Output bits 0-31 = input bits 32-63 (old_right -> new_left)
Output bits 32-63 = xor_node bits 0-31 (new_right)
So DES round outputs: (old_right, XOR_result). Standard Feistel with swap.

For LBlock, if we want the state after each round to be (Xi, Xi-1): Round i inputs: L = Xi-1, R = Xi-2 Round computes: T = F(L, Ki) XOR (R <<< 8) = Xi Round outputs: (T, L) = (Xi, Xi-1)

So:

Output bits 0-31 = T (XOR result)
Output bits 32-63 = L (old left)
After 32 rounds, output = (X33, X32). Final ciphertext should be X32 || X33, so we reverse the halves.

In CiVerLy:

# Output: new_left = xor result, new_right = old left
round.add_output([(xor_node, (i, i)) for i in range(32)])
round.add_output([(round.IN, (i, i + 32)) for i in range(32)])
Wait, that's wrong. round.IN bits 0-31 are the left half. We want the new right half to be the old left half. So:

Output bits 0-31 (new left) = xor_node output bits 0-31
Output bits 32-63 (new right) = round.IN bits 0-31 (old left)
round.add_output([(xor_node, (i, i)) for i in range(32)])
round.add_output([(round.IN, (i, i + 32)) for i in range(32)])
Yes, that's correct.

Now for the full cipher, after 32 rounds we add a final output. But since the 32nd round's output is (X33, X32), and we want (X32, X33), we'll need to reverse the halves. We can do this with a final PermuteLayer_CVL that swaps the two halves.

Actually, wait - looking at the LBlock spec figure again: the outputs are labeled X32 and X33, but if my interpretation of the rounds is correct, the state after 32 rounds would naturally be (X33, X32) if each round outputs (T, L). So either:

The figure implicitly includes a final swap that I haven't noticed
Or my understanding of the rounds is slightly off
But the test vectors verify that my equations are correct. Let me check if maybe the ciphertext is defined differently...

Spec: "Output C = X32 || X33 as the 64-bit ciphertext."

And my Python code produces the correct test vectors with the update: State after round i: (Xi+1, Xi) Final state after 32 rounds: (X33, X32) Ciphertext = (X32 << 32) | X33 = concatenation of X32 then X33.

Wait, in my Python code I have:

return (x[rounds] << 32) | x[rounds + 1]
After 32 rounds, x[32] = X32, x[33] = X33. And x array is updated as x[i] = F(x[i-1], rks[i-2]) ^ rotl8(x[i-2]).

So the equations are: X2 = F(X1, K1) XOR (X0 <<< 8) X3 = F(X2, K2) XOR (X1 <<< 8) ... X33 = F(X32, K32) XOR (X31 <<< 8)

C = X32 || X33.

In the state machine where state = (current_Xi, previous_Xi-1): Start: (X1, X0) After step 2: (X2, X1) -- because X2 is computed from X1 and X0 After step 3: (X3, X2) ... After step 33: (X33, X32)

The final step is step 33 (i=33), which computes X33. But the cipher has 32 rounds, each computing one Xi. Round 1 computes X2. Round 2 computes X3. ... Round 32 computes X33.

After round 32, the "current" value is X33 and the "previous" is X32. Output = X32 || X33.

This is equivalent to: after the last round, swap the two halves before outputting.

In CiVerLy, I'll implement:

Each round outputs (T, L) as discussed
After round 32, the state is (X33, X32)
Add a final permutation that swaps the two 32-bit halves to produce (X32, X33)
Let me now think about how to build the LBlock round function in CiVerLy.

Components needed:

RoundkeyXOR_CVL(32) - XOR round key with left half
SBox_CVL - 8 parallel 4-bit S-boxes
PermuteLayer_CVL - the P permutation (word-level on 4-bit words)
RotateLayer_CVL(32, 8) - rotate right half by 8 bits
XOR_CVL(32) - XOR F output with rotated right half
For (2), I need to create an SBox layer cipher containing 8 SBox_CVL in parallel. I can use SBoxCipher for this layer.

Wait, but the README says: "When you add multiple parallel instances of a component, prefer building a dedicated layer cipher (S-box layer, linear layer, etc.)."

So I'll create:

sbox_layer = SBoxCipher(32, 32, name="S")
Add 8 SBox_CVL components in parallel
For the P permutation, looking at my verification: perm = [4, 5, 6, 7, 12, 13, 14, 15, 0, 1, 2, 3, 8, 9, 10, 11, 20, 21, 22, 23, 28, 29, 30, 31, 16, 17, 18, 19, 24, 25, 26, 27]

Wait, let me double-check this. The permutation P maps 4-bit words. In terms of bit indices (0=MSB of 32-bit word):

Output bits 0-3 (word 7) <- input bits 4-7 (word 6)
Output bits 4-7 (word 6) <- input bits 12-15 (word 4)
Output bits 8-11 (word 5) <- input bits 0-3 (word 7)
Output bits 12-15 (word 4) <- input bits 8-11 (word 5)
Output bits 16-19 (word 3) <- input bits 20-23 (word 2)
Output bits 20-23 (word 2) <- input bits 28-31 (word 0)
Output bits 24-27 (word 1) <- input bits 16-19 (word 3)
Output bits 28-31 (word 0) <- input bits 24-27 (word 1)
Wait, in the bit-level PermuteLayer_CVL, the array perm means output[i] = input[perm[i]]. So: perm[0] = 4 means output bit 0 gets input bit 4. perm[1] = 5 means output bit 1 gets input bit 5. ... perm[4] = 12 means output bit 4 gets input bit 12. ...

But in my earlier analysis, I said: dest 0 <- source 4 dest 1 <- source 5 dest 2 <- source 6 dest 3 <- source 7

So perm[0]=4, perm[1]=5, perm[2]=6, perm[3]=7. Correct.

dest 4 <- source 12 dest 5 <- source 13 dest 6 <- source 14 dest 7 <- source 15

So perm[4]=12, perm[5]=13, perm[6]=14, perm[7]=15. Correct.

Continuing: perm[8]=0, perm[9]=1, perm[10]=2, perm[11]=3 perm[12]=8, perm[13]=9, perm[14]=10, perm[15]=11 perm[16]=20, perm[17]=21, perm[18]=22, perm[19]=23 perm[20]=28, perm[21]=29, perm[22]=30, perm[23]=31 perm[24]=16, perm[25]=17, perm[26]=18, perm[27]=19 perm[28]=24, perm[29]=25, perm[30]=26, perm[31]=27

Let me verify this against my reference Python code. In the reference:

u[7] = n[6]  # MSB output nibble = nibble 6
...
result |= u[i] << (4 * i)
For i=7: result |= u[7] << 28. u[7] = n[6] = (z >> 24) & 0xF. So output bits 28-31 = input bits 24-27. In PermuteLayer_CVL: perm[28]=24, perm[29]=25, perm[30]=26, perm[31]=27. Correct.

For i=0: result |= u[0] << 0. u[0] = n[1] = (z >> 4) & 0xF. So output bits 0-3 = input bits 4-7. In PermuteLayer_CVL: perm[0]=4, perm[1]=5, perm[2]=6, perm[3]=7. Correct.

For i=2: result |= u[2] << 8. u[2] = n[0] = (z >> 0) & 0xF. So output bits 8-11 = input bits 0-3. In PermuteLayer_CVL: perm[8]=0, perm[9]=1, perm[10]=2, perm[11]=3. Correct.

So the permutation array is:

perm = [
    4, 5, 6, 7,       # word 7 <- word 6
    12, 13, 14, 15,   # word 6 <- word 4
    0, 1, 2, 3,       # word 5 <- word 7
    8, 9, 10, 11,     # word 4 <- word 5
    20, 21, 22, 23,   # word 3 <- word 2
    28, 29, 30, 31,   # word 2 <- word 0
    16, 17, 18, 19,   # word 1 <- word 3
    24, 25, 26, 27    # word 0 <- word 1
]
Now for the rotation. We need R <<< 8 on 32 bits. RotateLayer_CVL(32, 8, word_coarseness=1) should do a left rotation of 32 bits by 8 positions.

Let me verify: RotateLayer_CVL(16, 4) gave vec_to_int(rot(int_to_vec(0x182b, 16))) = 33457. 0x182b = 0001 1000 0010 1011. Rotate left by 4 bits: 1000 0010 1011 0001 = 0x82B1. 0x82B1 = 33457. Correct.

So RotateLayer_CVL(32, 8, word_coarseness=1) would give a 32-bit left rotation by 8 bits.

Now for wiring. Since I'm using SBoxCipher, edges are bit indices.

States are 64 bits total. Left half: bits 0-31 Right half: bits 32-63

Round function design:

rk_node = round.add_subcipher(RoundkeyXOR_CVL(32), [(round.IN, (i, i)) for i in range(32)])
This XORs round key with left half (bits 0-31)
sbox_nodes = [round.add_subcipher(SBox_CVL(SBox(s_i)), [(rk_node, (j + 4*i, j)) for j in range(4)]) for i in range(8)] Wait, need to be careful about which S-box gets which nibble.
In the 32-bit word (bits 0-31, where bit 0 is MSB):

Bits 0-3 = word 7 (MSB nibble) -> s7
Bits 4-7 = word 6 -> s6
Bits 8-11 = word 5 -> s5
Bits 12-15 = word 4 -> s4
Bits 16-19 = word 3 -> s3
Bits 20-23 = word 2 -> s2
Bits 24-27 = word 1 -> s1
Bits 28-31 = word 0 (LSB nibble) -> s0
Wait, in int_to_vec, bit 0 is MSB of the integer. For a 32-bit value:

bit 0 = most significant bit
bit 31 = least significant bit
So for 32-bit word X:

Bits 0-3 = MSB nibble = Y7 in the spec
Bits 28-31 = LSB nibble = Y0 in the spec
And s7 is applied to Y7, s6 to Y6, ..., s0 to Y0.

So:

S-box s7: source bits 0-3, output bits 0-3
S-box s6: source bits 4-7, output bits 4-7
...
S-box s0: source bits 28-31, output bits 28-31
In reverse order of the S-box array index:

S[0] = s0 -> bits 28-31
S[1] = s1 -> bits 24-27
...
S[7] = s7 -> bits 0-3
So the wiring should be:

for i in range(8):
    # i=0 -> s0 -> bits 28-31
    # i=7 -> s7 -> bits 0-3
    src_start = 28 - 4*i
    dst_start = 28 - 4*i
    node = round.add_subcipher(SBox_CVL(SBox(S[i])), [(rk_node, (src_start + j, j)) for j in range(4)])
    sbox_nodes.append(node)
    # Then output wiring...
Actually, for the S-box layer, I create a sub-cipher:

sbox_layer = SBoxCipher(32, 32, name="SBoxLayer")
for i in range(8):
    src_start = 28 - 4*i
    sbox = SBox_CVL(SBox(S[i]), name=f"s{i}")
    node = sbox_layer.add_subcipher(sbox, [(sbox_layer.IN, (src_start + j, j)) for j in range(4)])
    sbox_layer.add_output([(node, (j, src_start + j)) for j in range(4)])
Hmm wait, in the PRESENT code:

sboxlayer = WordSBoxCipher(4, 16, 16, name="SBoxLayer")
for j in range(16):
    node = sboxlayer.add_subcipher(s, [(sboxlayer.IN, (j, 0))])
    sboxlayer.add_output([(node, (0, j))])
For WordSBoxCipher, (j, 0) means word j goes to input word 0 of the S-box (which is 4 bits). Output word 0 goes to output word j of the layer.

For SBoxCipher, I need bit-level edges. SBox_CVL takes 4 input bits and produces 4 output bits. [(sbox_layer.IN, (src_start + j, j)) for j in range(4)] means:

source bit src_start+j -> destination bit j of the S-box
And output: [(node, (j, src_start + j)) for j in range(4)] means:

source bit j of the S-box -> destination bit src_start+j of the layer output
But wait, src_start should be consistent with the spec. Let me map it carefully:

S-box s7 operates on Y7 = bits 0-3 of the 32-bit word
S-box s6 operates on Y6 = bits 4-7
S-box s5 operates on Y5 = bits 8-11
S-box s4 operates on Y4 = bits 12-15
S-box s3 operates on Y3 = bits 16-19
S-box s2 operates on Y2 = bits 20-23
S-box s1 operates on Y1 = bits 24-27
S-box s0 operates on Y0 = bits 28-31
So for S-box i where i is the index in S array (0=s0, 1=s1, ..., 7=s7):

s0: bits 28-31
s1: bits 24-27
...
s7: bits 0-3
src_start = 28 - 4*i gives:

i=0: 28 (s0, bits 28-31) ✓
i=1: 24 (s1, bits 24-27) ✓
...
i=7: 0 (s7, bits 0-3) ✓
Good.

Permutation layer on the 32-bit S-box output.
P_perm = PermuteLayer_CVL([
    4, 5, 6, 7,
    12, 13, 14, 15,
    0, 1, 2, 3,
    8, 9, 10, 11,
    20, 21, 22, 23,
    28, 29, 30, 31,
    16, 17, 18, 19,
    24, 25, 26, 27
], name="P")
But we can also set word_coarseness=4: Actually, the permutation operates on 4-bit words, so word_coarseness=4 is appropriate. But PermuteLayer_CVL with word_coarseness=4 means that the permutation array contains word indices, not bit indices.

With word_coarseness=4 and 32 bits = 8 words: The permutation on words would be: perm_words = [6, 4, 7, 5, 2, 0, 3, 1] where perm_words[i] means output word i gets input word perm_words[i].

But PermuteLayer_CVL with word_coarseness=4 takes a permutation array of length input_length / word_coarseness = 32/4 = 8. And the permutation is: output[word_coarseness * i + j] = input[word_coarseness * perm[i] + j].

So for word i, the output comes from word perm[i].

We want: Output word 7 <- input word 6 Output word 6 <- input word 4 Output word 5 <- input word 7 Output word 4 <- input word 5 Output word 3 <- input word 2 Output word 2 <- input word 0 Output word 1 <- input word 3 Output word 0 <- input word 1

perm_words = [1, 3, 0, 2, 5, 7, 4, 6] Wait, check:

perm[0] = 1 -> output word 0 <- input word 1 ✓ (U0 = Z1)
perm[1] = 3 -> output word 1 <- input word 3 ✓ (U1 = Z3)
perm[2] = 0 -> output word 2 <- input word 0 ✓ (U2 = Z0)
perm[3] = 2 -> output word 3 <- input word 2 ✓ (U3 = Z2)
perm[4] = 5 -> output word 4 <- input word 5 ✓ (U4 = Z5)
perm[5] = 7 -> output word 5 <- input word 7 ✓ (U5 = Z7)
perm[6] = 4 -> output word 6 <- input word 4 ✓ (U6 = Z4)
perm[7] = 6 -> output word 7 <- input word 6 ✓ (U7 = Z6)
Great! So PermuteLayer_CVL([1, 3, 0, 2, 5, 7, 4, 6], word_coarseness=4, name="P").

Wait, but in the DES example, they used P_perm = PermuteLayer_CVL([p-1 for p in P_perm], name="P").inv(). And they didn't set word_coarseness at all (defaults to 1).

For my case, if I use word_coarseness=4, when I wire it in SBoxCipher, I need to be careful. SBoxCipher edges are bit indices. PermuteLayer_CVL with word_coarseness=4 acts on 8 words of 4 bits. The input_length is 32 bits (since len(perm) * word_coarseness = 8 * 4 = 32).

Actually, looking at PermuteLayer_CVL.__init__:

def __init__(self, perm, word_coarseness=1, name=None):
    super().__init__(len(perm) * word_coarseness, len(perm) * word_coarseness, name=name)
So PermuteLayer_CVL([1, 3, 0, 2, 5, 7, 4, 6], word_coarseness=4) has input_length = 8 * 4 = 32. Correct.

When adding to SBoxCipher, the edges are bit indices. So I'd wire:

node_p = round.add_subcipher(P_perm, [(node_s, (i, i)) for i in range(32)])
Wait, but P_perm with word_coarseness=4 operates on words, and the edges [(node_s, (i, i)) for i in range(32)] connect all 32 bits directly. That should work because PermuteLayer_CVL.eval maps bits according to the permutation including the word coarseness.

Actually, looking at the eval of PermuteLayer_CVL:

def eval(self, x):
    answer = [x[self.perm[i//self.word_coarseness]*self.word_coarseness + i%self.word_coarseness] for i in range(self.input_length)]
    return vector(GF(2), answer)
Wait, that's possibly wrong but the concept is: output bit i comes from input bit perm[i//wc] * wc + i % wc.

For i=0: output bit 0 <- input bit perm[0]*4 + 0 = 1*4 + 0 = 4. Correct (word 7 gets word 6's MSB). For i=4: output bit 4 <- input bit perm[1]*4 + 0 = 3*4 + 0 = 12. Correct (word 6 gets word 4's MSB).

So yes, PermuteLayer_CVL with word_coarseness=4 works correctly.

Rotate right half by 8 bits. RotateLayer_CVL(32, 8, word_coarseness=1) operates on 32 bits, rotating left by 8.
But actually, we only want to rotate the right half, not the entire 64-bit state. So we wire it to only the right half bits.

XOR F output with rotated right half. XOR_CVL(32) takes 64 bits: first 32 bits = F output, second 32 bits = rotated right half.
Now let me draft the complete round function:

lblock_round = SBoxCipher(64, 64, name="LBlock_round")

# Round key XOR on left half
rk = RoundkeyXOR_CVL(32, 0x0, name="rk")
node_rk = lblock_round.add_subcipher(rk, [(lblock_round.IN, (i, i)) for i in range(32)])

# S-box layer
sbox_layer = SBoxCipher(32, 32, name="SBoxLayer")
S_BOXES = [...]  # list of 8 S-box tables
for i in range(8):
    src_start = 28 - 4*i
    sbox = SBox_CVL(SBox(S_BOXES[i]), name=f"s{i}")
    node = sbox_layer.add_subcipher(sbox, [(sbox_layer.IN, (src_start + j, j)) for j in range(4)])
    sbox_layer.add_output([(node, (j, src_start + j)) for j in range(4)])

node_s = lblock_round.add_subcipher(sbox_layer, [(node_rk, (i, i)) for i in range(32)])

# Permutation P
P_perm = PermuteLayer_CVL([1, 3, 0, 2, 5, 7, 4, 6], word_coarseness=4, name="P")
node_p = lblock_round.add_subcipher(P_perm, [(node_s, (i, i)) for i in range(32)])

# Rotate right half by 8 bits
rot = RotateLayer_CVL(32, 8, word_coarseness=1, name="rot")
node_rot = lblock_round.add_subcipher(rot, [(lblock_round.IN, (i + 32, i)) for i in range(32)])

# XOR F output with rotated right half
xor = XOR_CVL(32, name="xor")
node_xor = lblock_round.add_subcipher(xor, 
    [(node_p, (i, i)) for i in range(32)] +
    [(node_rot, (i, i + 32)) for i in range(32)]
)

# Round output: (T, L) where T = XOR result, L = old left
lblock_round.add_output([(node_xor, (i, i)) for i in range(32)])
lblock_round.add_output([(lblock_round.IN, (i, i + 32)) for i in range(32)])
Wait, for the XOR component, the input should be f_output || rot_output. The edges are:

(node_p, (i, i)) for i in range(32): this connects node_p output bit i to XOR input bit i
(node_rot, (i, i + 32)) for i in range(32): this connects node_rot output bit i to XOR input bit i+32
So XOR input bits 0-31 come from node_p, and bits 32-63 come from node_rot. Correct. XOR output is 32 bits.

Then round output:

bits 0-31 = node_xor output (T)
bits 32-63 = old left half (round.IN bits 0-31)
Now for the full cipher:

cipher = SBoxCipher(64, 64, name=name)
node = cipher.IN
for r in range(R):
    lblock_round.nodes[node_rk].const = rks[r]
    node = cipher.add_subcipher(lblock_round, [(node, (i, i)) for i in range(64)])
After 32 rounds, node carries bits (X33, X32). We need final output (X32, X33). So we need a final swap.

# Final swap: output X32 || X33
swap = PermuteLayer_CVL(
    list(range(32, 64)) + list(range(32)),
    name="swap"
)
node = cipher.add_subcipher(swap, [(node, (i, i)) for i in range(64)])
cipher.add_output([(node, (i, i)) for i in range(64)])
Wait, PermuteLayer_CVL maps output[i] = input[perm[i]]. If perm = [32, 33, ..., 63, 0, 1, ..., 31]:

output bit 0 = input bit 32 (old right half MSB)
output bit 32 = input bit 0 (old left half MSB)
This swaps the two halves. Correct.

But wait, is there a final swap in the actual LBlock cipher? The figure doesn't show one. Let me check if the test vectors would require it.

In my Python reference: After 32 rounds, the last two values are X33 and X32. The ciphertext is (X32 << 32) | X33.

So yes, after the 32 rounds that compute X33 from (X32, X31), we need to present the output as X32 || X33.

Actually, in my reference implementation, I didn't have a "final swap" step - I just returned the values in the right order. The internal state progression was just computing Xi values.

So in terms of a sequence of operations: State before round i: (Xi-1, Xi-2) State after round i: (Xi, Xi-1)

This means: Start: (X1, X0) After round 1: (X2, X1) After round 2: (X3, X2) ... After round 32: (X33, X32)

Output = X32 || X33.

So yes, the CiVerLy round outputs (new_left, new_right) = (Xi, Xi-1), and after 32 rounds we get (X33, X32). We then swap to get (X32, X33).

Actually wait, I realize the issue. In my reference code, x[i] is the i-th value. The "state" isn't really two halves; it's just a sequence. Let me think about how the round function should be structured in CiVerLy.

In CiVerLy, the state at any point is a single vector of 64 bits. After each round subcipher, it becomes a new 64-bit vector.

If round subcipher transforms (L, R) -> (T, L): After 1 round: (X2, X1) After 2 rounds: (X3, X2) ... After 32 rounds: (X33, X32)

Then we need a swap to get (X32, X33).

Alternatively, we could define the round as (L, R) -> (R, T): After 1 round: (X0, X2) which doesn't match.

Or (L, R) -> (L, T): After 1 round: (X1, X2) After 2 rounds: (X1, F(X1,K2) XOR (X2<<<8)) which is wrong.

So (T, L) is the natural choice for the round output.

Now, let me think about the key schedule. The LBlock spec mentions an 80-bit key and a key schedule. For the CiVerLy implementation, we can pre-compute the round keys and pass them as rks to the constructor.

Looking at the test vectors: Plaintext 0x00...00, Key 0x00...00 -> Ciphertext 0xc218185308e75bcd

If I pass rks computed from the all-zero key, I should get this ciphertext.

Let me write the key schedule function to generate round keys.

From my reference python code, the key schedule is:

def lblock_key_schedule(key, rounds=32):
    K = key & ((1 << 80) - 1)
    rks = []
    for i in range(rounds):
        rks.append((K >> 48) & 0xFFFFFFFF)  # leftmost 32 bits
        K = ((K << 29) & ((1 << 80) - 1)) | (K >> (80 - 29))
        nibble9 = (K >> 76) & 0xF
        nibble8 = (K >> 72) & 0xF
        K = (K & ~((0xF << 76) | (0xF << 72))) | (S[9][nibble9] << 76) | (S[8][nibble8] << 72)
        counter = (i + 1) & 0x1F
        k_bits = (K >> 46) & 0x1F
        k_bits ^= counter
        K = (K & ~(0x1F << 46)) | (k_bits << 46)
    return rks
I need to implement this in the

... (small changes to own implementation)

Both test vectors pass. Now let me draft the lblock.py file for CiVerLy. I need to follow the patterns from the README and existing implementations.

Key design decisions:

Use SBoxCipher (not WordSBoxCipher) because the Feistel wiring with left/right halves is cleaner with bit indices. Also, PRESENT's WordSBoxCipher approach with wordwise modeling doesn't yield very useful results anyway.
Build each round as a named subcipher.
Provide an R parameter for number of rounds (default 32).
Provide rks for round keys (pre-computed list of 32-bit integers).
Implement doctests with test vectors.
Include modeling doctests (optional - solver tags).
For the key schedule, I'll implement it as a static method or helper function within the class, so users can generate round keys from an 80-bit master key.

Wait, do the existing cipher implementations include key schedule generation? Looking at PRESENT:

PRESENT_CVL takes R=31 and rks=[] as parameters.
If rks == [], it defaults to [0 for _ in range(R+1)].
The test vectors in the doctest use explicit rks.
For DES:

DES_CVL takes R and rks=[].
If rks == [], defaults to [0 for _ in range(R)].
For LBlock, I'll do the same. But it would be useful to provide a key schedule helper for the test vectors.

Actually, looking at the doctest for DES:

sage: rks = [0x0B02679B49A5, ...]
sage: des = DES_CVL(R=16, rks=rks)
So rks are passed explicitly for test vectors.

For LBlock, the test vectors require specific round keys computed from the master key. I'll provide a key_schedule helper and use it in the doctests.

Let me think about the structure:

from sage.crypto.sbox import SBox
from civerly.sboxcipher import SBoxCipher
from civerly.component import SBox_CVL, PermuteLayer_CVL, RotateLayer_CVL
from civerly.component import RoundkeyXOR_CVL, XOR_CVL

# S-box tables
S_BOXES = [
    [14, 9, 15, 0, 13, 4, 10, 11, 1, 2, 8, 3, 7, 6, 12, 5],
    [4, 11, 14, 9, 15, 13, 0, 10, 7, 12, 5, 6, 2, 8, 1, 3],
    [1, 14, 7, 12, 15, 13, 0, 6, 11, 5, 9, 3, 2, 4, 8, 10],
    [7, 6, 8, 11, 0, 15, 3, 14, 9, 10, 12, 13, 5, 2, 4, 1],
    [14, 5, 15, 0, 7, 2, 12, 13, 1, 8, 4, 9, 11, 10, 6, 3],
    [2, 13, 11, 12, 15, 14, 0, 9, 7, 10, 6, 3, 1, 8, 4, 5],
    [11, 9, 4, 14, 0, 15, 10, 13, 6, 12, 5, 7, 3, 8, 1, 2],
    [13, 10, 15, 0, 14, 4, 9, 11, 2, 1, 8, 3, 7, 5, 12, 6],
    [8, 7, 14, 5, 15, 13, 0, 6, 11, 12, 9, 10, 2, 4, 1, 3],
    [11, 5, 15, 0, 7, 2, 9, 13, 4, 8, 1, 12, 14, 10, 3, 6],
]

class LBLOCK_CVL:
    def __init__(self, R=32, rks=None, name=None):
        # ...
Wait, should the S-boxes be SBox objects from Sage? Yes, SBox_CVL requires a Sage SBox. So:

from sage.crypto.sbox import SBox
S = [SBox(s) for s in S_BOXES]
Actually, looking at DES:

from sage.crypto.sbox import SBox as SBox_sage
S = [SBox_CVL(SBox_sage(s), name=f"S{i}") for i, s in enumerate(S_new)]
So I'll create Sage SBox objects.

Now let me draft the complete file.

Let me write the lblock.py file. I'll base it on the DES example since LBlock is also a Feistel cipher.

I need to be very careful about the bit ordering and wiring.

Actually, let me re-examine the S-box wiring within the 32-bit word. In the spec and figure:

Y = Y7 || Y6 || ... || Y0, where Y7 is MSB and Y0 is LSB
Z7 = s7(Y7), ..., Z0 = s0(Y0)
In int_to_vec, bit 0 is the MSB of the integer. For a 32-bit integer X:

bits 0-3 = MSB nibble = Y7
bits 4-7 = Y6
bits 8-11 = Y5
bits 12-15 = Y4
bits 16-19 = Y3
bits 20-23 = Y2
bits 24-27 = Y1
bits 28-31 = LSB nibble = Y0
So:

S-box s7 operates on bits 0-3
S-box s6 operates on bits 4-7
...
S-box s0 operates on bits 28-31
In my reference Python code, for the 32-bit word x:

for i in range(8):
    nibble = (x >> (4 * i)) & 0xF  # i=0: LSB nibble = Y0
    y |= S[i][nibble] << (4 * i)   # S[0]=s0 applied to Y0
Wait, in my Python reference, (x >> (4*i)) & 0xF for i=0 gets the LSB nibble (Y0), and S[0] is s0. That means:

LSB nibble (bits 0-3 of integer) -> s0
MSB nibble (bits 28-31 of integer) -> s7
But in int_to_vec, bit 0 is the MSB of the integer. So for the integer's MSB nibble (bits 28-31 of integer):

These correspond to vector bits 0-3.
So in the CiVerLy vector representation:

Vector bits 0-3 = integer bits 28-31 = Y0
Vector bits 4-7 = integer bits 24-27 = Y1
...
Vector bits 28-31 = integer bits 0-3 = Y7? No...
Wait, I'm confusing myself. Let me be very precise.

int_to_vec(value, 32) creates a vector of 32 bits where:

vec[0] = MSB of value = bit 31 of the integer
vec[31] = LSB of value = bit 0 of the integer
So for a 32-bit integer, the mapping is:

Vector bit i = integer bit (31 - i)
For a nibble (4 bits):

Vector bits 0-3 = integer bits 31-28 = MSB nibble = Y7
Vector bits 4-7 = integer bits 27-24 = Y6
Vector bits 8-11 = integer bits 23-20 = Y5
Vector bits 12-15 = integer bits 19-16 = Y4
Vector bits 16-19 = integer bits 15-12 = Y3
Vector bits 20-23 = integer bits 11-8 = Y2
Vector bits 24-27 = integer bits 7-4 = Y1
Vector bits 28-31 = integer bits 3-0 = LSB nibble = Y0
So in CiVerLy vector terms:

Y7 = vector bits 0-3
Y6 = vector bits 4-7
Y5 = vector bits 8-11
Y4 = vector bits 12-15
Y3 = vector bits 16-19
Y2 = vector bits 20-23
Y1 = vector bits 24-27
Y0 = vector bits 28-31
And:

s7 operates on Y7 = vector bits 0-3
s6 operates on Y6 = vector bits 4-7
...
s0 operates on Y0 = vector bits 28-31
Therefore, in the S-box layer for CiVerLy:

s0 (index 0) -> vector bits 28-31
s1 (index 1) -> vector bits 24-27
...
s7 (index 7) -> vector bits 0-3
So:

for i in range(8):
    src_start = 28 - 4*i
    sbox = SBox_CVL(S[i], name=f"s{i}")
    node = sbox_layer.add_subcipher(sbox, [(sbox_layer.IN, (src_start + j, j)) for j in range(4)])
    sbox_layer.add_output([(node, (j, src_start + j)) for j in range(4)])
Wait, when i=0: src_start = 28. So s0 gets vector bits 28-31. Output goes back to vector bits 28-31. Correct. When i=7: src_start = 0. So s7 gets vector bits 0-3. Output goes back to vector bits 0-3. Correct.

Now for the permutation P: P operates on Z = Z7 || ... || Z0. In CiVerLy vector terms:

Z7 = vector bits 0-3
Z6 = vector bits 4-7
Z5 = vector bits 8-11
Z4 = vector bits 12-15
Z3 = vector bits 16-19
Z2 = vector bits 20-23
Z1 = vector bits 24-27
Z0 = vector bits 28-31
Output U = U7 || ... || U0 where:

U7 = Z6 = vector bits 4-7
U6 = Z4 = vector bits 12-15
U5 = Z7 = vector bits 0-3
U4 = Z5 = vector bits 8-11
U3 = Z2 = vector bits 20-23
U2 = Z0 = vector bits 28-31
U1 = Z3 = vector bits 16-19
U0 = Z1 = vector bits 24-27
In PermuteLayer_CVL with word_coarseness=4: The permutation array perm means output_word[i] = input_word[perm[i]].

Wait, PermuteLayer_CVL.eval:

answer = [x[self.perm[i//self.word_coarseness]*self.word_coarseness + i%self.word_coarseness] for i in range(self.input_length)]
So output bit i = input bit perm[i//wc] * wc + i % wc. This means output word w gets input word perm[w].

So for word indices:

Output word 0 (bits 28-31 of 32-bit word) = U0 = Z1 = input word 1 (bits 24-27)
Output word 1 (bits 24-27) = U1 = Z3 = input word 3 (bits 16-19)
Output word 2 (bits 20-23) = U2 = Z0 = input word 0 (bits 28-31)
Output word 3 (bits 16-19) = U3 = Z2 = input word 2 (bits 20-23)
Output word 4 (bits 12-15) = U4 = Z5 = input word 5 (bits 8-11)
Output word 5 (bits 8-11) = U5 = Z7 = input word 7 (bits 0-3)
Output word 6 (bits 4-7) = U6 = Z4 = input word 4 (bits 12-15)
Output word 7 (bits 0-3) = U7 = Z6 = input word 6 (bits 4-7)
Wait, but in PermuteLayer_CVL, the word indices are based on the vector position. Vector bit 0-3 is word 0? Or vector bit 0-3 is word 7?

In PermuteLayer_CVL, it's just a permutation of bits grouped by word_coarseness. The "word index" is i // word_coarseness. So:

Vector bits 0-3 = word index 0
Vector bits 4-7 = word index 1
...
Vector bits 28-31 = word index 7
So:

Output word 0 (vector bits 0-3) gets input word perm[0]
Output word 7 (vector bits 28-31) gets input word perm[7]
We want:

Output word 0 (bits 0-3) = U7 = Z6 = input word 1 (bits 4-7) Wait, no! I need to reconcile the vector representation with the integer representation.
In the vector:

bits 0-3 = MSB nibble = Y7
bits 28-31 = LSB nibble = Y0
So vector word index 0 = bits 0-3 = Y7 Vector word index 7 = bits 28-31 = Y0

In PermuteLayer_CVL:

word index 0 = bits 0-3
word index 1 = bits 4-7
...
word index 7 = bits 28-31
Now, for the permutation P: U7 = Z6 U6 = Z4 U5 = Z7 U4 = Z5 U3 = Z2 U2 = Z0 U1 = Z3 U0 = Z1

Where Zi is at vector word position (7 - i):

Z7 = word 0
Z6 = word 1
Z5 = word 2
Z4 = word 3
Z3 = word 4
Z2 = word 5
Z1 = word 6
Z0 = word 7
So:

U7 = Z6 = word 1. Output word 0 gets input word 1? No, U7 is the MSB, which is output word 0. Output word 0 = U7 = Z6 = input word 1. So perm[0] = 1.
U6 = Z4 = word 3. Output word 1 gets input word 3. So perm[1] = 3.
U5 = Z7 = word 0. Output word 2 gets input word 0. So perm[2] = 0.
U4 = Z5 = word 2. Output word 3 gets input word 2. So perm[3] = 2.
U3 = Z2 = word 5. Output word 4 gets input word 5. So perm[4] = 5.
U2 = Z0 = word 7. Output word 5 gets input word 7. So perm[5] = 7.
U1 = Z3 = word 4. Output word 6 gets input word 4. So perm[6] = 4.
U0 = Z1 = word 6. Output word 7 gets input word 6. So perm[7] = 6.
So perm = [1, 3, 0, 2, 5, 7, 4, 6].

Let me verify with my reference implementation.

In my Python ref, for integer representation (LSB = bit 0 of integer):

Z0 = integer bits 0-3
Z1 = integer bits 4-7
...
Z7 = integer bits 28-31
And I compute:

u[7] = n[6]  # MSB output nibble = nibble 6 (integer bits 24-27)
u[6] = n[4]  # nibble 6 (integer bits 16-19)
u[5] = n[7]  # nibble 5 (integer bits 28-31)
...
In the integer, the output is u[7] || u[6] || ... || u[0].

For vec_to_int in CiVerLy, bit 0 of vector corresponds to MSB of integer (bit 31). So vector bit 0 = integer bit 31.

In my ref, u[7] is the MSB nibble of the integer, which corresponds to vector bits 0-3. u[7] = n[6] where n[6] is integer bits 24-27 = vector bits 4-7.

So output vector word 0 (bits 0-3) = input vector word 1 (bits 4-7). This means perm[0] = 1. Correct.

u[6] is integer bits 24-27 in output, which corresponds to vector bits 4-7. u[6] = n[4] where n[4] is integer bits 16-19 = vector bits 12-15. So output vector word 1 (bits 4-7) = input vector word 3 (bits 12-15). This means perm[1] = 3. Correct.

u[0] is integer bits 0-3 in output, which corresponds to vector bits 28-31. u[0] = n[1] where n[1] is integer bits 4-7 = vector bits 24-27. So output vector word 7 (bits 28-31) = input vector word 6 (bits 24-27). This means perm[7] = 6. Correct.

So perm = [1, 3, 0, 2, 5, 7, 4, 6] for PermuteLayer_CVL with word_coarseness=4 is correct.

Now for the rotation <<< 8 on 32 bits. RotateLayer_CVL(32, 8, word_coarseness=1) rotates left by 8 bit positions on a 32-bit input.

In vector terms: output bit i = input bit (i + 8) mod 32. Wait, RotateLayer_CVL converts r rotation to a permutation:

perm = list(range((-r) % input_length, input_length)) + list(range((-r) % input_length))
For r=8, input_length=32: (-8) % 32 = 24 perm = list(range(24, 32)) + list(range(24)) perm = [24, 25, 26, 27, 28, 29, 30, 31, 0, 1, 2, 3, ..., 23]

And eval of PermuteLayer_CVL does answer[i] = x[perm[i]]. So output bit 0 = input bit 24. Output bit 1 = input bit 25. ... Output bit 7 = input bit 31. Output bit 8 = input bit 0. ...

This is a left rotation by 8? Let's check. If input is ABCDEFGH (8 bytes, 64 bits, but let's use 32 bits = 4 bytes). RotateLayer_CVL(32, 8): Output bit 0 = input bit 24. In the vector, bit 0 is MSB. Bit 24 is... let's see:

bit 0 = MSB of byte 0
bit 7 = LSB of byte 0
bit 8 = MSB of byte 1
...
bit 24 = MSB of byte 3
So output bit 0 = input bit 24 = MSB of byte 3. Output bit 8 = input bit 0 = MSB of byte 0.

The output vector starts with byte 3, then byte 0, byte 1, byte 2. For 32-bit word 0x12345678: Vector: 0001 0010 0011 0100 0101 0110 0111 1000 Output: 0111 1000 0001 0010 0011 0100 0101 0110 = 0x78123456

Wait, but 0x12345678 <<< 8 should be 0x34567812 (left rotation by 8 bits = 1 byte).

Hmm, 0x12345678 in little-endian bytes is 78 56 34 12. Left rotate by 1 byte: 56 34 12 78. As hex: 0x34567812.

But my calculation gave 0x78123456. That's a right rotation by 8 bits!

Let me check RotateLayer_CVL again.

perm = list(range((-r) % input_length, input_length)) + \
    list(range((-r) % input_length))
For r=8, input_length=32: (-8) % 32 = 24 perm = [24, 25, 26, 27, 28, 29, 30, 31, 0, 1, 2, ..., 23]

And eval does:

answer = [x[self.perm[i]] for i in range(self.input_length)]
Output bit 0 = input bit 24. If bit 0 is MSB and bit 31 is LSB, then input bit 24 is 8 bits from the left, or equivalently 24 bits from the right. For 0x12345678 = 0001 0010 0011 0100 0101 0110 0111 1000: Bit 0 = 0, bit 1 = 0, ..., bit 3 = 1 (MSB nibble = 1) Bit 24 = 0? Let me count: bits 0-3: 0001 bits 4-7: 0010 bits 8-11: 0011 bits 12-15: 0100 bits 16-19: 0101 bits 20-23: 0110 bits 24-27: 0111 bits 28-31: 1000

So bit 24 = 0 (first bit of nibble 7 = 0x7 = 0111). Output bit 0 = 0. Output bit 1 = bit 25 = 1. Output bit 2 = bit 26 = 1. Output bit 3 = bit 27 = 1. Output bits 0-3 = 0111.

Output bit 4 = bit 28 = 1. Output bit 5 = bit 29 = 0. Output bit 6 = bit 30 = 0. Output bit 7 = bit 31 = 0. Output bits 4-7 = 1000.

So output = 0111 1000 0001 0010 0011 0100 0101 0110 = 0x78123456.

But 0x12345678 <<< 8 = left shift by 8 bits on the integer: 0x34567812.

So RotateLayer_CVL(32, 8) is NOT doing <<< 8. Let me re-read the docstring.

"Rotate to the left, i.e. \\lll"

And the test:

sage: rot = RotateLayer_CVL(16, 4)
sage: vec_to_int(rot(int_to_vec(0x182b, 16)))
33457
0x182b = 0001 1000 0010 1011. Rotate left by 4 bits: 1000 0010 1011 0001 = 0x82B1. 0x82B1 = 33457. ✓

For 16 bits: (-4) % 16 = 12. perm = [12, 13, 14, 15, 0, 1, 2, ..., 11] Output bit 0 = input bit 12. For 0x182b: bits 0-3 = 0001 bits 4-7 = 1000 bits 8-11 = 0010 bits 12-15 = 1011

Output bit 0 = bit 12 = 1. Output bit 1 = bit 13 = 0. Output bit 2 = bit 14 = 1. Output bit 3 = bit 15 = 1. Output bits 0-3 = 1011 = 0xB.

Output bit 4 = bit 0 = 0. Output bit 5 = bit 1 = 0. Output bit 6 = bit 2 = 0. Output bit 7 = bit 3 = 1. Output bits 4-7 = 0001 = 0x1.

Output = 1011 0001 0001 1000 = 0xB118. Wait, that's not 0x82B1. Let me compute more carefully.

0x182b = binary: 0001 1000 0010 1011 Vector: (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1)

In the vector, index 0 = MSB = bit 15 of integer. Index 15 = LSB = bit 0 of integer.

So: vector[0] = 0 = integer bit 15 vector[1] = 0 = integer bit 14 vector[2] = 0 = integer bit 13 vector[3] = 1 = integer bit 12 vector[4] = 1 = integer bit 11 vector[5] = 0 = integer bit 10 vector[6] = 0 = integer bit 9 vector[7] = 0 = integer bit 8 vector[8] = 0 = integer bit 7 vector[9] = 0 = integer bit 6 vector[10] = 1 = integer bit 5 vector[11] = 0 = integer bit 4 vector[12] = 1 = integer bit 3 vector[13] = 0 = integer bit 2 vector[14] = 1 = integer bit 1 vector[15] = 1 = integer bit 0

For RotateLayer_CVL(16, 4): perm = [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

Output vector[0] = input vector[12] = integer bit 3 = 1 Output vector[1] = input vector[13] = integer bit 2 = 0 Output vector[2] = input vector[14] = integer bit 1 = 1 Output vector[3] = input vector[15] = integer bit 0 = 1 Output nibble 0 = 1011 = 0xB

Output vector[4] = input vector[0] = integer bit 15 = 0 Output vector[5] = input vector[1] = integer bit 14 = 0 Output vector[6] = input vector[2] = integer bit 13 = 0 Output vector[7] = input vector[3] = integer bit 12 = 1 Output nibble 1 = 0001 = 0x1

Output vector[8] = input vector[4] = integer bit 11 = 1 Output vector[9] = input vector[5] = integer bit 10 = 0 Output vector[10] = input vector[6] = integer bit 9 = 0 Output vector[11] = input vector[7] = integer bit 8 = 0 Output nibble 2 = 1000 = 0x8

Output vector[12] = input vector[8] = integer bit 7 = 0 Output vector[13] = input vector[9] = integer bit 6 = 0 Output vector[14] = input vector[10] = integer bit 5 = 1 Output vector[15] = input vector[11] = integer bit 4 = 0 Output nibble 3 = 0010 = 0x2

So output integer = 0xB182. Let me verify: vec_to_int(output) = 0xB182.

Wait, the docstring says vec_to_int(rot(int_to_vec(0x182b, 16))) = 33457. 0x82B1 = 1000 0010 1011 0001. 1000 0010 1011 0001 = 8*4096 + 2*256 + 11*16 + 1 = 32768 + 512 + 176 + 1 = 33457. ✓

But my calculation gave 0xB182. There's a discrepancy!

Actually, I think I messed up. The docstring says RotateLayer_CVL(16, 4) and vec_to_int(rot(int_to_vec(0x182b, 16))) = 33457.

Let me trace through more carefully using the actual int_to_vec and vec_to_int functions.

int_to_vec(0x182b, 16):

ZZ(0x182b).digits(2, padto=16)[::-1]
0x182b = 0001 1000 0010 1011. In binary from MSB to LSB: 0 0 0 1 1 0 0 0 0 0 1 0 1 0 1 1. So vector = (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1).

Now rot = RotateLayer_CVL(16, 4). perm = [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

Output = [input[12], input[13], input[14], input[15], input[0], input[1], input[2], input[3], input[4], input[5], input[6], input[7], input[8], input[9], input[10], input[11]]

input[12] = 1, input[13] = 0, input[14] = 1, input[15] = 1 input[0] = 0, input[1] = 0, input[2] = 0, input[3] = 1 input[4] = 1, input[5] = 0, input[6] = 0, input[7] = 0 input[8] = 0, input[9] = 0, input[10] = 1, input[11] = 0

Output = (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0)

vec_to_int(output):

1<<15 + 0<<14 + 1<<13 + 1<<12 + 0<<11 + 0<<10 + 0<<9 + 1<<8 + 1<<7 + 0<<6 + 0<<5 + 0<<4 + 0<<3 + 0<<2 + 1<<1 + 0<<0
= 32768 + 8192 + 4096 + 256 + 128 + 2
= 45442
Wait, that's not 33457. hmm... let me re-read vec_to_int:

output_num = 0
for i in input_vec:
    output_num <<= 1
    output_num += ZZ(i)
return output_num
So for vector (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0):

0 -> 0
1 -> 1
0 -> 2
1 -> 5
1 -> 11
0 -> 22
0 -> 44
0 -> 88
1 -> 177
1 -> 355
0 -> 710
0 -> 1420
0 -> 2840
0 -> 5680
1 -> 11361
0 -> 22722
So vec_to_int = 22722? No wait, I need to trace more carefully.

Actually, let me just use Python: vec_to_int([1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0]):

start: 0
i=0: 0<<1 + 1 = 1
i=1: 1<<1 + 0 = 2
i=2: 2<<1 + 1 = 5
i=3: 5<<1 + 1 = 11
i=4: 11<<1 + 0 = 22
i=5: 22<<1 + 0 = 44
i=6: 44<<1 + 0 = 88
i=7: 88<<1 + 1 = 177
i=8: 177<<1 + 1 = 355
i=9: 355<<1 + 0 = 710
i=10: 710<<1 + 0 = 1420
i=11: 1420<<1 + 0 = 2840
i=12: 2840<<1 + 0 = 5680
i=13: 5680<<1 + 0 = 11360
i=14: 11360<<1 + 1 = 22721
i=15: 22721<<1 + 0 = 45442
So vec_to_int = 45442 = 0xB182.

But the docstring says 33457 = 0x82B1.

There's a contradiction! Either the docstring is wrong, or I'm misunderstanding the permutation.

Wait, let me re-read the docstring:

sage: rot = RotateLayer_CVL(16, 4)
sage: vec_to_int(rot(int_to_vec(0x182b, 16)))
33457
Hmm, 0x182b in binary: 0001100000101011. Maybe int_to_vec gives different bits than I computed?

ZZ(0x182b).digits(2, padto=16): 0x182b = 6251. In binary (LSB first): 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0 (padded to 16). [::-1] reverses it: 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1.

Wait, that's (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1).

Hmm, I computed it earlier as (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1). Yes.

Now rot with perm = [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]:

output = [input[12], input[13], input[14], input[15], input[0], input[1], input[2], input[3], input[4], input[5], input[6], input[7], input[8], input[9], input[10], input[11]]

input[12] = 1, input[13] = 0, input[14] = 1, input[15] = 1 input[0] = 0, input[1] = 0, input[2] = 0, input[3] = 1 input[4] = 1, input[5] = 0, input[6] = 0, input[7] = 0 input[8] = 0, input[9] = 0, input[10] = 1, input[11] = 0

output = (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0)

vec_to_int of this:

0 -> 1 -> 2 -> 5 -> 11 -> 22 -> 44 -> 88 -> 177 -> 355 -> 710 -> 1420 -> 2840 -> 5680 -> 11361 -> 22722
Wait, let me recompute:

0
0*2 + 1 = 1
1*2 + 0 = 2
2*2 + 1 = 5
5*2 + 1 = 11
11*2 + 0 = 22
22*2 + 0 = 44
44*2 + 0 = 88
88*2 + 1 = 177
177*2 + 1 = 355
355*2 + 0 = 710
710*2 + 0 = 1420
1420*2 + 0 = 2840
2840*2 + 0 = 5680
5680*2 + 1 = 11361
11361*2 + 0 = 22722
So vec_to_int = 22722.

But the docstring says 33457. There must be something wrong with either my understanding or the docstring. Let me check the docstring from the source code.

Actually, the source I read says:

sage: rot = RotateLayer_CVL(16, 4)
sage: vec_to_int(rot(int_to_vec(0x182b, 16)))
33457
Wait, but I read this from component.py lines 1961-1963. Let me verify this via Sage directly.

Actually, I can just run a test in bash using Python with sage. But it might be easier to trust that RotateLayer_CVL(32, 8, word_coarseness=1) does what it's supposed to do and verify with my own test.

Actually, looking at the docstring again, I see:

sage: vec_to_int(rot(rot(rot(rot(
....:   int_to_vec(0x182b, 16)
....: ))))) == 0x182b
True
If 4 rotations by 4 bits bring it back to the original, and each rotation gives 33457... then 4 * 33457 cycles back. That's consistent.

Wait, let me compute `

... (smaller code executions for explicit components of the cipher)

So RotateLayer_CVL(16, 4) applied to 0x182b gives 33457 which is 0x82B1. And 4 rotations give 0x182b back. So RotateLayer_CVL works correctly for that example.

My manual calculation was wrong because I mis-indexed the vector. Let me understand what's happening.

v = (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1)

perm = [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

output[0] = v[12] = 1 output[1] = v[13] = 0 output[2] = v[14] = 1 output[3] = v[15] = 1 output[4] = v[0] = 0 output[5] = v[1] = 0 output[6] = v[2] = 0 output[7] = v[3] = 1 output[8] = v[4] = 1 output[9] = v[5] = 0 output[10] = v[6] = 0 output[11] = v[7] = 0 output[12] = v[8] = 0 output[13] = v[9] = 0 output[14] = v[10] = 1 output[15] = v[11] = 0

So output = (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0)

Earlier I said v[12] = 1, v[13] = 0, v[14] = 1, v[15] = 1. That's correct. And output = (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0).

vec_to_int of this:

0*2+1 = 1
1*2+0 = 2
2*2+1 = 5
5*2+1 = 11
11*2+0 = 22
22*2+0 = 44
44*2+0 = 88
88*2+1 = 177
177*2+1 = 355
355*2+0 = 710
710*2+0 = 1420
1420*2+0 = 2840
2840*2+0 = 5680
5680*2+0 = 11360
11360*2+1 = 22721
22721*2+0 = 45442
Wait, but the output says 33457! So my manual vec_to_int trace is wrong because v[12], v[13], etc. are different from what I think.

Let me check v again: v = (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1)

v[0] = 0
v[1] = 0
v[2] = 0
v[3] = 1
v[4] = 1
v[5] = 0
v[6] = 0
v[7] = 0
v[8] = 0
v[9] = 0
v[10] = 1
v[11] = 0
v[12] = 1
v[13] = 0
v[14] = 1
v[15] = 1
So: output[0] = v[12] = 1 output[1] = v[13] = 0 output[2] = v[14] = 1 output[3] = v[15] = 1 output[4] = v[0] = 0 output[5] = v[1] = 0 output[6] = v[2] = 0 output[7] = v[3] = 1 output[8] = v[4] = 1 output[9] = v[5] = 0 output[10] = v[6] = 0 output[11] = v[7] = 0 output[12] = v[8] = 0 output[13] = v[9] = 0 output[14] = v[10] = 1 output[15] = v[11] = 0

Output = (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0)

vec_to_int:

bit 0=1: 1
bit 1=0: 2
bit 2=1: 5
bit 3=1: 11
bit 4=0: 22
bit 5=0: 44
bit 6=0: 88
bit 7=1: 177
bit 8=1: 355
bit 9=0: 710
bit 10=0: 1420
bit 11=0: 2840
bit 12=0: 5680
bit 13=0: 11360
bit 14=1: 22721
bit 15=0: 45442
But sage says 33457! So either v[12] is not 1, or the perm is different.

Wait, looking at rot vec from sage output: (1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1).

This is different from my output! My output was (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0).

So where did I go wrong? Let me check v again from sage: (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1).

v[12]=1, v[13]=0, v[14]=1, v[15]=1. That matches.

But the actual output vector from sage is (1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1).

This means perm might be different from what I computed. Let me re-read RotateLayer_CVL.__init__:

perm = list(range((-r) % input_length, input_length)) + \
    list(range((-r) % input_length))
For r=4, input_length=16: (-4) % 16 = 12 perm = list(range(12, 16)) + list(range(12)) perm = [12, 13, 14, 15] + [0, 1, 2, ..., 11] perm = [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

And eval:

def eval(self, x):
    answer = [x[self.perm[i]] for i in range(self.input_length)]
    return vector(GF(2), answer)
Wait, looking at PermuteLayer_CVL.eval:

answer = [x[self.perm[i//self.word_coarseness]*self.word_coarseness + i%self.word_coarseness] for i in range(self.input_length)]
Since word_coarseness=1 for RotateLayer_CVL(16, 4): answer[i] = x[perm[i]]

So: output[0] = x[12] = 1 output[1] = x[13] = 0 output[2] = x[14] = 1 output[3] = x[15] = 1 output[4] = x[0] = 0 output[5] = x[1] = 0 output[6] = x[2] = 0 output[7] = x[3] = 1 output[8] = x[4] = 1 output[9] = x[5] = 0 output[10] = x[6] = 0 output[11] = x[7] = 0 output[12] = x[8] = 0 output[13] = x[9] = 0 output[14] = x[10] = 1 output[15] = x[11] = 0

Output = (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0)

But Sage says output is (1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1)!

Something is fundamentally different. Let me print rot.perm to see.

OK, so the permutation IS [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], and the output SHOULD be (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0) according to the permutation.

But Sage says rot(v) = (1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1)!

Wait, is it possible that rot(v) is printing a Sage vector that gets truncated or rearranged? No, vectors print sequentially.

Let me directly check rot.eval(v).

... (reasoning about rotation)

OK, so the permutation IS [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], and the output SHOULD be (1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0) according to the permutation.

But Sage says rot(v) = (1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1)!

Wait, is it possible that rot(v) is printing a Sage vector that gets truncated or rearranged? No, vectors print sequentially.

Let me directly check rot.eval(v).

PYTHONPATH=src sage -c "
from civerly.util import int_to_vec, vec_to_int
from civerly.component import RotateLayer_CVL
rot = RotateLayer_CVL(16, 4)
v = int_to_vec(0x182b, 16)
r = rot.eval(v)
print('eval result:', r)
print('type:', type(r))
print('list:', list(r))
print('r[0]:', r[0])
print('r[1]:', r[1])
print('r[12]:', r[12])
print('r[13]:', r[13])
"
eval result: (1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1)
type: <class 'sage.modules.vector_mod2_dense.Vector_mod2_dense'>
list: [1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1]
r[0]: 1
r[1]: 0
r[12]: 0
r[13]: 0
This is very strange. rot.perm says [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], but rot.eval(v) gives a result that doesn't match this permutation applied to v.

Wait, could there be an inv() being applied somewhere? Or maybe PermuteLayer_CVL.eval does something else.

Let me look at the actual eval method of PermuteLayer_CVL more carefully. I only saw it partially before.

Actually, looking at the component.py output I got earlier around line 1800:

def eval(self, x):
    answer = [x[self.perm[i//self.word_coarseness]*self.word_coarseness + i%self.word_coarseness] for i in range(self.input_length)]
    return vector(GF(2), answer)
Wait, that's output[i] = input[perm[i//wc] * wc + i % wc].

For wc=1: output[i] = input[perm[i]].

So for i=0: output[0] = input[perm[0]] = input[12] = 1. Correct. For i=4: output[4] = input[perm[4]] = input[0] = 0. Correct.

But the actual result shows output[0] = 1, output[1] = 0, output[2] = 0, output[3] = 0. Output[2] should be input[perm[2]] = input[14] = 1, but it's 0!

What? Let me check if perm from rot is actually inherited correctly.

Oh wait... RotateLayer_CVL inherits from PermuteLayer_CVL. But maybe PermuteLayer_CVL stores self.perm differently? Let me check rot.__dict__ or rot.perm.

Actually, in the bash output, rot.perm prints as [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]. And we verified v[rot.perm[2]] = v[14] = 1.

But r[2] = 0. How can this be?

Unless... rot.eval is NOT PermuteLayer_CVL.eval but something else? No, RotateLayer_CVL does not override eval except to call super().eval(x).

OH WAIT! The issue might be that PermuteLayer_CVL.eval doesn't do what I think. Let me read it precisely from the source.

Let me search for the eval method in component.py. I only read lines up to around 1900. Let me search for it.

PermuteLayer_CVL inherits from LinearLayer_CVL! That changes everything. It doesn't have its own eval method that uses perm directly. Instead, it converts the permutation into a binary matrix and uses LinearLayer_CVL.eval.

Let me read PermuteLayer_CVL from line 1753.

Ah, I see! PermuteLayer_CVL converts the permutation into a binary matrix using:

arr = [[0 for _ in range(len(perm))] for _ in range(len(perm))]
for i in range(len(perm)):
    arr[perm[i]][i] = identity_matrix(word_coarseness)
binary_matrix = block_matrix(GF(2), arr, subdivide=False)
Then eval uses LinearLayer_CVL.eval, which does binary_matrix * x.

The matrix construction is: arr[perm[i]][i] = I. So row perm[i], column i gets the identity.

This means: output[perm[i]] = input[i] or equivalently output[j] = input[perm^{-1}(j)].

The standard permutation convention in CiVerLy is that perm[i] is the DESTINATION of input i. No wait, looking at the eval: Mx where M[perm[i]][i] = I. For standard matrix multiplication (Mx)_j = sum_k M[j][k] * x_k. Since M[perm[i]][i] = I, we have (Mx)_{perm[i]} = x_i. So output at position perm[i] equals input at position i. This means output[perm[i]] = input[i], or output[j] = input[perm^{-1}(j)].

In standard permutation notation, if perm[i] = j, it means input i goes to output j. That's the standard convention.

But wait, looking at DES_S1_1 and how inv() works:

permute = PermuteLayer_CVL([p-1 for p in P_perm], name="P").inv()
And the P permutation in DES maps output bit j to input bit P_perm[j] (1-indexed). In DES, P_perm = [16, 7, 20, 21, ...]. permute = PermuteLayer_CVL([15, 6, 19, 20, ...], name="P").inv()

If P_perm means "output bit 1 comes from input bit 16", then PermuteLayer_CVL([15, 6, 19, ...]) creates: arr[15][0] = I, arr[6][1] = I, arr[19][2] = I, ... This means output[15] = input[0], output[6] = input[1]. But we want output[0] = input[15] (output bit 0 comes from input bit 15, since P_perm[0] = 16 means 1-indexed input 16).

So actually, PermuteLayer_CVL does the inverse of what we might naively expect.

Wait, in DES they do .inv() on the PermuteLayer_CVL. So: PermuteLayer_CVL([15, 6, 19, ...]).inv() returns a permutation where output[i] = input[15] for output 0, etc.

Let me verify with a simple example from the docstring:

sage: perm = PermuteLayer_CVL([1, 3, 2, 0])
sage: vec_to_int(perm(int_to_vec(0x9, 4)))
12
0x9 = 1001. Vector = (1, 0, 0, 1). Expected output: perm[0]=1 means input 0 -> output 1. Input 0 = 1, so output[1] = 1. perm[1]=3 means input 1 -> output 3. Input 1 = 0, so output[3] = 0. perm[2]=2 means input 2 -> output 2. Input 2 = 0, so output[2] = 0. perm[3]=0 means input 3 -> output 0. Input 3 = 1, so output[0] = 1.

Output = (1, 1, 0, 0) = 0xC = 12. ✓

So PermuteLayer_CVL DOES follow the convention: perm[i] is the output position where input i goes. output[perm[i]] = input[i].

Now for RotateLayer_CVL(16, 4): perm = [12, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

output[12] = input[0], output[13] = input[1], ...

For 0x182b = vector (0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1):

output[12] = input[0] = 0
output[13] = input[1] = 0
output[14] = input[2] = 0
output[15] = input[3] = 1
output[0] = input[4] = 1
output[1] = input[5] = 0
output[2] = input[6] = 0
output[3] = input[7] = 0
output[4] = input[8] = 0
output[5] = input[9] = 0
output[6] = input[10] = 1
output[7] = input[11] = 0
output[8] = input[12] = 1
output[9] = input[13] = 0
output[10] = input[14] = 1
output[11] = input[15] = 1
Output = (1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1)

This matches the Sage output! I had the permutation direction wrong in my manual trace.

So RotateLayer_CVL(16, 4) means: output[12] = input[0] output[13] = input[1] ... output[0] = input[4]

For integer 0x182b = 0001 1000 0010 1011: input[0..3] = 0001 input[4..7] = 1000 input[8..11] = 0010 input[12..15] = 1011

output: [12..15] = input[0..3] = 0001 [0..3] = input[4..7] = 1000 [4..7] = input[8..11] = 0010 [8..11] = input[12..15] = 1011

Output = 1000 0010 1011 0001 = 0x82B1 = 33457. ✓

So my earlier manual computation used the wrong permutation direction. perm[i] means input i goes to output perm[i]. Not output i gets input perm[i].

This means for LBlock's P permutation: We want: output word 7 <- input word 6 output word 6 <- input word 4 ... output word 0 <- input word 1

In PermuteLayer_CVL: perm[6] = 7 (input word 6 -> output word 7) perm[4] = 6 (input word 4 -> output word 6) perm[7] = 5 (input word 7 -> output word 5) perm[5] = 4 (input word 5 -> output word 4) perm[2] = 3 (input word 2 -> output word 3) perm[0] = 2 (input word 0 -> output word 2) perm[3] = 1 (input word 3 -> output word 1) perm[1] = 0 (input word 1 -> output word 0)

So perm = [2, 0, 3, 1, 6, 4, 7, 5].

Let me verify with my reference Python code.

In my reference, for integer representation (LSB = bit 0): n[0] = integer bits 0-3 = Y0 n[1] = integer bits 4-7 = Y1 ... n[7] = integer bits 28-31 = Y7

u[0] = n[1] -> output bits 0-3 = input bits 4-7 u[1] = n[3] -> output bits 4-7 = input bits 12-15 u[2] = n[0] -> output bits 8-11 = input bits 0-3 u[3] = n[2] -> output bits 12-15 = input bits 8-11 u[4] = n[5] -> output bits 16-19 = input bits 20-23 u[5] = n[7] -> output bits 20-23 = input bits 28-31 u[6] = n[4] -> output bits 24-27 = input bits 16-19 u[7] = n[6] -> output bits 28-31 = input bits 24-27

In vector representation: Vector bit 0 = integer bit 31. Vector bit 31 = integer bit 0.

So vector word index 0 = bits 0-3 = integer bits 31-28 = Y7 Vector word index 7 = bits 28-31 = integer bits 3-0 = Y0

For PermuteLayer_CVL with word_coarseness=4: Input word 0 = vector bits 0-3 = Y7 Input word 1 = vector bits 4-7 = Y6 ... Input word 7 = vector bits 28-31 = Y0

We want:

Output word 0 (bits 0-3, Y7 position) = U7 = Z6 = input word 1 (Y6)
Output word 1 (bits 4-7, Y6 position) = U6 = Z4 = input word 3 (Y4)
Output word 2 (bits 8-11, Y5 position) = U5 = Z7 = input word 0 (Y7)
Output word 3 (bits 12-15, Y4 position) = U4 = Z5 = input word 2 (Y5)
Output word 4 (bits 16-19, Y3 position) = U3 = Z2 = input word 5 (Y2)
Output word 5 (bits 20-23, Y2 position) = U2 = Z0 = input word 7 (Y0)
Output word 6 (bits 24-27, Y1 position) = U1 = Z3 = input word 4 (Y3)
Output word 7 (bits 28-31, Y0 position) = U0 = Z1 = input word 6 (Y1)
So:

perm[1] = 0 (input word 1 -> output word 0)
perm[3] = 1 (input word 3 -> output word 1)
perm[0] = 2 (input word 0 -> output word 2)
perm[2] = 3 (input word 2 -> output word 3)
perm[5] = 4 (input word 5 -> output word 4)
perm[7] = 5 (input word 7 -> output word 5)
perm[4] = 6 (input word 4 -> output word 6)
perm[6] = 7 (input word 6 -> output word 7)
perm = [2, 0, 3, 1, 6, 4, 7, 5]

Wait, this is the OPPOSITE of what I computed before. Let me verify with a concrete example.

Take Z = 0x76543210. In vector representation (MSB first): Vector bits 0-3 = Y7 = 7 Vector bits 4-7 = Y6 = 6 Vector bits 8-11 = Y5 = 5 Vector bits 12-15 = Y4 = 4 Vector bits 16-19 = Y3 = 3 Vector bits 20-23 = Y2 = 2 Vector bits 24-27 = Y1 = 1 Vector bits 28-31 = Y0 = 0

Expected output U = 0x64752031: Vector bits 0-3 = U7 = 6 Vector bits 4-7 = U6 = 4 Vector bits 8-11 = U5 = 7 Vector bits 12-15 = U4 = 5 Vector bits 16-19 = U3 = 2 Vector bits 20-23 = U2 = 0 Vector bits 24-27 = U1 = 3 Vector bits 28-31 = U0 = 1

For PermuteLayer_CVL([2, 0, 3, 1, 6, 4, 7, 5], word_coarseness=4): perm[0] = 2: input word 0 (Y7=7) -> output word 2 (U5). U5 should be Z7=7. But we want U5=Z7=7. Output word 2 should be 7. Correct. perm[1] = 0: input word 1 (Y6=6) -> output word 0 (U7). U7 should be Z6=6. Correct. perm[2] = 3: input word 2 (Y5=5) -> output word 3 (U4). U4 should be Z5=5. Correct. perm[3] = 1: input word 3 (Y4=4) -> output word 1 (U6). U6 should be Z4=4. Correct. perm[4] = 6: input word 4 (Y3=3) -> output word 6 (U1). U1 should be Z3=3. Correct. perm[5] = 4: input word 5 (Y2=2) -> output word 4 (U3). U3 should be Z2=2. Correct. perm[6] = 7: input word 6 (Y1=1) -> output word 7 (U0). U0 should be Z1=1. Correct. perm[7] = 5: input word 7 (Y0=0) -> output word 5 (U2). U2 should be Z0=0. Correct.

So perm = [2, 0, 3, 1, 6, 4, 7, 5] is correct for PermuteLayer_CVL.

Now for RotateLayer_CVL(32, 8, word_coarseness=1): We need to verify what it does.

perm = list(range((-8) % 32, 32)) + list(range((-8) % 32)) (-8) % 32 = 24 perm = [24, 25, ..., 31, 0, 1, ..., 23]

This means: input[0] -> output[24] input[1] -> output[25] ... input[7] -> output[31] input[8] -> output[0] ... input[31] -> output[23]

In vector terms: output bit 0 = input bit 8 output bit 1 = input bit 9 ... output bit 24 = input bit 0 ...

This is a LEFT rotation by 8 bits? Let's verify.

For vector (0, 0, 0, 0, 1, 1, 1, 1, ...) where bits 4-7 are all 1s: output bit 0 = input bit 8.

Wait, a left rotation by 8 bits on a 32-bit integer 0x12345678: 0x12345678 <<< 8 = 0x34567812.

In vector representation: input: 0001 0010 0011 0100 0101 0110 0111 1000 RotateLayer_CVL(32, 8) output:

output[0] = input[8] = 0 output[1] = input[9] = 0 output[2] = input[10] = 1 output[3] = input[11] = 1 output[4] = input[12] = 0 output[5] = input[13] = 1 output[6] = input[14] = 0 output[7] = input[15] = 0 output[8..15] = input[16..23] = 0101 0110 output[16..23] = input[24..31] = 0111 1000 output[24..31] = input[0..7] = 0001 0010

Output vector: 0011 0100 0101 0110 0111 1000 0001 0010 = 0x34567812. ✓

So RotateLayer_CVL(32, 8, word_coarseness=1) correctly implements <<< 8.

Now for the S-box layer. I need to correctly wire the S-boxes.

For SBoxCipher, edges are bit-level. SBox_CVL(S) takes 4 input bits and produces 4 output bits.

In the 32-bit word vector representation:

Vector bits 0-3 = MSB nibble = Y7 -> s7
Vector bits 4-7 = Y6 -> s6
...
Vector bits 28-31 = LSB nibble = Y0 -> s0
For the S-box layer (a sub-cipher with 32 input bits and 32 output bits):

sbox_layer = SBoxCipher(32, 32, name="SBoxLayer")
for i in range(8):
    src_start = 28 - 4*i
    sbox = SBox_CVL(S[i], name=f"s{i}")
    node = sbox_layer.add_subcipher(sbox, [(sbox_layer.IN, (src_start + j, j)) for j in range(4)])
    sbox_layer.add_output([(node, (j, src_start + j)) for j in range(4)])
Wait, when i=0: src_start = 28. s0 gets vector bits 28-31. Correct. When i=7: src_start = 0. s7 gets vector bits 0-3. Correct.

Actually, should the output go back to the same positions? Yes, the S-box layer just replaces each nibble with its S-box output in the same position.

Now let me verify the whole round function with a concrete example using Sage.

Actually, before implementing the full CiVerLy cipher, let me write a small test script in Sage to verify the round function components match my Python reference.

... (implementation in lblock.py)

All components match. Now I can proceed to write the full lblock.py implementation.

Key elements:

S-box tables
Key schedule helper
LBLOCK_CVL class with:
__init__ building the cipher DAG
Doctests for test vectors
Modeling doctests
For the cipher DAG:

Build round function as SBoxCipher(64, 64)
In round:
rk = RoundkeyXOR_CVL(32) on left half
sbox_layer on 32 bits
P_perm on 32 bits
rot = RotateLayer_CVL(32, 8) on right half
xor = XOR_CVL(32) combining P output and rotated right
Output: left=xor output, right=old left
Build full cipher = SBoxCipher(64, 64)
Add 32 rounds
Final swap to get (X32, X33) from (X33, X32)
For the key schedule, since the README says to provide rks as a parameter (like DES and PRESENT), I'll include a static method key_schedule(key) that computes the round keys, and the default rks will be all zeros.

Actually, looking at how other ciphers handle this - they require rks to be passed for test vectors, and default to all zeros. I'll do the same.

But it would be nice to have the key schedule available for users.

For the doctests, I'll include:

Test vector 1: all-zero plaintext and key
Test vector 2: non-zero plaintext and key
Optional SAT modeling test
Optional MILP modeling test
Let me write the full file now.

One more thing - I need to decide how to structure the final swap. After 32 rounds, the state is (X33, X32). We want to output (X32, X33).

swap = PermuteLayer_CVL(
    list(range(32, 64)) + list(range(32)),
    name="swap"
)
node = cipher.add_subcipher(swap, [(node, (i, i)) for i in range(64)])
cipher.add_output([(node, (i, i)) for i in range(64)])
Wait, PermuteLayer_CVL with perm = [32, 33, ..., 63, 0, 1, ..., 31]:

perm[0] = 32: input bit 0 -> output bit 32
perm[32] = 0: input bit 32 -> output bit 0
This means:

output bit 0 = input bit 32
output bit 32 = input bit 0
Which swaps the two halves. Correct.

Alternatively, I could just use:

cipher.add_output([(node, (i + 32, i)) for i in range(32)])
cipher.add_output([(node, (i - 32, i)) for i in range(32, 64)])
Wait, add_output takes edges (node, (src_index, dst_index)). So [(node, (i + 32, i)) for i in range(32)] means:

output bit 0 = node bit 32
output bit 1 = node bit 33 ...
output bit 31 = node bit 63
And [(node, (i - 32, i)) for i in range(32, 64)] means:

output bit 32 = node bit 0
output bit 33 = node bit 1 ...
output bit 63 = node bit 31
This is a swap without needing a PermuteLayer_CVL! But I need to make sure all output bits are covered.

Actually, cipher.add_output can take multiple calls or a single combined list:

cipher.add_output([(node, (i + 32, i)) for i in range(32)] + [(node, (i - 32, i)) for i in range(32, 64)])
This directly maps the outputs. It's simpler than adding a swap component.

But looking at DES, they use ip.inv() to do a final permutation. And in the README it says: "If the cipher has an initial or final whitening layer, model these as separate subciphers (or as round 0 and round R+1) so they do not interfere with round-indexed slicing."

For round slicing, we want the final swap to be a separate named component if possible. But actually, a simple output wiring without a component might also be fine. Let me check if there are unnamed components issues.

For LBlock, I'll use a PermuteLayer_CVL for the swap to make it explicit.

Wait, actually, looking at the README again: "Missing or incomplete add_output calls" is a pitfall. And "Using WordBasedCipher.add_subcipher() edges like bit edges instead of word edges" is another pitfall.

I'll use SBoxCipher with bit-level edges, so no worries about word edges.

Now let me write the complete lblock.py.

The key schedule doctest failed. The expected output was wrong - I put a placeholder. Let me compute the actual round keys for the all-zero key and fix the doctest.

Actually, the key schedule itself works because the test vectors pass. But my doctest example in lblock_key_schedule was just a guess. Let me compute the correct first 4 round keys for key=0x0.

... (small changes to key schedule and test runs)

Implemented LBLOCK_CVL in src/civerly/cipher_implementations/lblock.py.

Structure of the implementation:

S-box layer: 8 parallel SBox_CVL components (s0 through s7) wired to a 32-bit subcipher. The upper nibble (vector bits 0–3) feeds s7 and the lower nibble (bits 28–31) feeds s0, matching the specification.
Permutation P: PermuteLayer_CVL([2, 0, 3, 1, 6, 4, 7, 5], word_coarseness=4) implements the word-wise permutation.
Feistel round: Each round XORs the round key with the left half, applies the S-box layer and P, rotates the right half by 8 bits (RotateLayer_CVL(32, 8)), and XORs the two branches. The round outputs (new_left, old_left).
Final swap: After 32 rounds the state is (X33, X32); a PermuteLayer_CVL swaps the halves to produce the required X32 || X33 ciphertext.
Key schedule: lblock_key_schedule(key) derives the 32-bit round keys from an 80-bit master key, applying the 29-bit left rotation, s9/s8 updates, and round-counter XOR.
Doctests cover:

Both official test vectors (all-zero and non-zero key/plaintext pairs)
SAT-based differential analysis with CRYPTOMINISAT_CVL and ESPRESSO_CVL
MILP-based differential analysis with SCIP_CVL
All doctests pass and the cipher is compatible with SBoxCipher modeling pipelines.

