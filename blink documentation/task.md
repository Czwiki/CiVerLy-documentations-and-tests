Prompt for this task: Your task is located at @blink documentation/task.md , the specifications can be found at @blink documentation/blink.md .


Task

Implement the tweakable block cipher Blink in Python as a working reference implementation.

The implementation must exactly match the following specification. It is not about performance, but about correctness and transparency.

1. Basic Requirements
Language: Python 3.10+
No external libraries (no numpy, no cryptography)
Only standard library allowed
Focus: Clarity > Optimization
2. Data Model
2.1 State

The state is a list of 4-bit values (nibbles):

state: list[int]  # Value range: 0..15

Size:

64-bit block → 16 nibbles
128-bit block → 32 nibbles
2.2 Bit representation (only for Tweak/Hash)
bits: list[int]  # Values 0/1

LSB-first representation.

3. S-Box
SBOX = [
    0x1,0x0,0x9,0x3,
    0x8,0x5,0xE,0x7,
    0x4,0x2,0xC,0xB,
    0xA,0xF,0x6,0xD
]

Properties:

involutory → INV_SBOX = SBOX
Application
state[i] = SBOX[state[i]]
4. MixColumns (Midori)

For each column (a,b,c,d):

a' = b ^ c ^ d
b' = a ^ c ^ d
c' = a ^ b ^ d
d' = a ^ b ^ c
5. Permutation P

For 128-bit (32 nibbles):

P = [
5,12,4,1,17,9,10,16,
28,14,21,22,11,27,8,13,
2,25,18,3,30,6,19,20,
0,23,24,31,7,15,29,26
]

Inverse must be computed automatically.

6. Toeplitz Hash
6.1 Definition
h(t) = T · t  over GF(2)
T is an n × τ Toeplitz matrix
t is a bit vector
6.2 Representation

Toeplitz is stored as:

k: list[int]  # Length n + tau - 1
6.3 Computation
def toeplitz_hash(k, t, n):
    out = [0] * n
    tau = len(t)

    for i in range(n):
        acc = 0
        for j in range(tau):
            if t[j] == 1:
                acc ^= k[i + j]
        out[i] = acc

    return out
6.4 Hash functions
h1(t) = T1 · t
h2(t) = T2 · t
h(t)  = h1(t) XOR h2(t)
7. Key Schedule

Master Key Layout:

k = w1 || w2 || rks...

All parts are the same size as the state.

def key_schedule(master, n_rounds, n):
    w1 = master[0:n]
    w2 = master[n:2*n]

    rks = []
    idx = 2*n

    for _ in range(n_rounds):
        rks.append(master[idx:idx+n])
        idx += n

    return w1, w2, rks
8. Round Function

A forward round:

S
M
AddRoundKey
AddTweak (if defined in the flow)
Permutation
9. Whitening
state ^= w1   # before start
state ^= w2   # at the end
10. Tweak Processing
t_bits = int_to_bits(t, tau)
11. Encryption (main structure)

Implement exactly the following structure:

def encrypt(m, t, key):
    state = m[:]

    state = xor(state, key.w1)

    # forward rounds
    for i in range(a):
        state = S(state)
        state = M(state)
        state = xor(state, key.rk[i])

    state = xor(state, h1(t))

    for i in range(a, a+b):
        state = S(state)
        state = M(state)
        state = xor(state, key.rk[i])

    state = xor(state, h(t))

    # backward rounds
    for i in reversed(range(a, a+b)):
        state = S(state)
        state = M(state)
        state = xor(state, key.rk[i])

    state = xor(state, h2(t))

    state = xor(state, key.w2)

    return state
12. Decryption
identical structure
inverse order
S and M are self-inverse
replace Permutation with INV_P
13. Helper functions (required)
xor(state, key)
S(state)
M(state)
permute(state)
inv_permute(state)
int_to_bits(x)
bits_to_int(x)
14. Important rules
No optimization
No clever bit hacks
Write each transformation explicitly
No round compression
No "magical combining" of XOR steps
15. Validation (required tests)
assert decrypt(encrypt(m, t, k), t, k) == m
assert SBOX[SBOX[x]] == x for all x
16. Goal

At the end, a file must exist:

blink.py

with:

encrypt()
decrypt()
all components implemented internally
without external dependencies
End of prompt
