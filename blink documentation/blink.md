Blink – Developer Specification
Purpose of this document

This document describes the Blink cipher completely from an implementer's perspective.

It does not replace the scientific publication, but translates its mathematical description into a technical specification that can be used directly as the basis for a software implementation.

All components are described individually.

The goal is that after reading this document, a complete reference implementation can be created, for example in Python, C or Rust.

1. Overview

Blink is a tweakable block cipher.

Unlike AES, Blink has three inputs:

Key
Tweak
Plaintext
Ciphertext = Blink(Key, Tweak, Plaintext)

The tweak is public.

It is not used for secrecy.

Instead, it ensures that the same plaintext under the same key produces different ciphertexts.

Typical tweaks:

Memory address
Sector number
Counter
Nonce
2. THF (Three Hash Framework)

Blink is based on a construction called

Three Hash Framework (THF)

The basic idea:

Instead of mixing the tweak directly into every round (like QARMA or MANTIS), the tweak is first processed through three universal hash functions.

h1(T)
h2(T)

h(T)=h1(T) xor h2(T)

These three values are introduced into the algorithm at three points.

This improves security against so-called multiple-tweak attacks.

THF structure

The mathematical construction is

π1

↓

xor h1(T)

↓

π2

↓

xor h(T)

↓

π3

↓

xor h2(T)

↓

π4

where

h(T)=h1(T) xor h2(T)

applies.

The permutations π1 to π4 are not implemented as standalone functions in Blink.

They arise from specific sequences of round transformations.

3. Blink construction

Blink uses a so-called reflection structure.

The second half of the encryption mirrors the first half.

Schematically:

Plaintext

↓

Forward Rounds

↓

Middle

↓

Backward Rounds

↓

Ciphertext

This means encryption and decryption use nearly identical hardware.

4. Supported variants

The paper defines several variants.

Name	Block	Tweak	a	b
Blink-64a	64	64	2	3
Blink-64b	64	128	2	3
Blink-128a	128	128	3	3
Blink-128b	128	256	3	3
Blink-128A	128	128	3	5
Blink-128B	128	256	3	5

For an initial implementation, it is recommended to use

Blink-128a

because it is the standard variant in the paper.

5. Block size

Blink operates on

n bits

where

n = 64

or

n = 128
6. State

The internal state does not consist of bytes like AES.

It consists of nibbles.

A nibble has four bits.

For

128 bits

there are

32 nibbles.

For

64 bits

there are

16 nibbles.
Matrix representation

The state is organized as a matrix.

For Blink-128:

4 rows

8 columns
s0  s1  s2  s3  s4  s5  s6  s7

s8  s9 s10 s11 s12 s13 s14 s15

s16 s17 s18 s19 s20 s21 s22 s23

s24 s25 s26 s27 s28 s29 s30 s31

Each element contains exactly

0 … 15

i.e., a 4-bit value.

Recommendation for Python

The simplest representation is

state = [
    0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0
]

i.e.,

list[int]

with 32 entries.

Alternatively, a numpy.ndarray can be used, but for a reference implementation a normal list is sufficient.

7. Data flow

The complete encryption flow looks like this:

Plaintext

↓

Whitening Key w1

↓

a forward rounds

↓

π1

↓

xor h1(T)

↓

b forward rounds

↓

π2

↓

xor h(T)

↓

π3

↓

b backward rounds

↓

xor h2(T)

↓

π4

↓

a backward rounds

↓

Whitening Key w2

↓

Ciphertext

This structure forms the core of the cipher and serves as a guide for implementation.

8. Round function

The entire cipher ultimately consists of a sequence of identical rounds.

Each round has exactly five operations:

State

↓

S
(SubCells)

↓

M
(MixColumns)

↓

AK
(AddRoundKey)

↓

AC
(AddRoundConstant)

↓

P
(Permutation)

↓

next round

Formal:

R = P ○ AC ○ AK ○ M ○ S

All operations are performed in exactly this order.

9. S-Box

Blink uses exactly one 4-bit S-box.

It is

involutory
bijective
Differential uniformity 4
Linearity 8

Since it is involutory, it holds that

S⁻¹(x) = S(x)

There is no second table for decryption.

Lookup table
Input : Output

0 → 1
1 → 0
2 → 9
3 → 3
4 → 8
5 → 5
6 → E
7 → 7
8 → 4
9 → 2
A → C
B → B
C → A
D → F
E → 6
F → D

Python:

SBOX = [
    0x1,
    0x0,
    0x9,
    0x3,
    0x8,
    0x5,
    0xE,
    0x7,
    0x4,
    0x2,
    0xC,
    0xB,
    0xA,
    0xF,
    0x6,
    0xD,
]

Since it is involutory:

INV_SBOX = SBOX
Application

For each nibble

state[i]

the following is executed

state[i] = SBOX[state[i]]

There are

16 applications in Blink-64
32 applications in Blink-128

All are independent of each other.

10. MixColumns

After the S-box, linear diffusion follows.

For this, Blink uses exactly the same matrix as Midori.

0 1 1 1
1 0 1 1
1 1 0 1
1 1 1 0

Since all entries are only 0 or 1, there are no GF(16) multiplications.

Only XORs are used.

Meaning

A column

a
b
c
d

is transformed to

b xor c xor d

a xor c xor d

a xor b xor d

a xor b xor c

i.e.,

a' = b⊕c⊕d

b' = a⊕c⊕d

c' = a⊕b⊕d

d' = a⊕b⊕c
Python
def mix_column(a, b, c, d):
    return (
        b ^ c ^ d,
        a ^ c ^ d,
        a ^ b ^ d,
        a ^ b ^ c,
    )
Application to the entire state

For Blink-128, each column has four nibbles.

s0
s8
s16
s24

form the first column.

s1
s9
s17
s25

the second.

etc.

So eight columns are processed.

For Blink-64, there are correspondingly four columns.

11. AddRoundKey

Then the round key is mixed in.

state = state xor round_key

The round key has the same size as the state.

So

64 bits

or

128 bits.

At the nibble level:

state[i] ^= rk[i]
12. AddRoundConstant

After the round key follows the round constant.

state ^= RC

The constants are tabulated in the paper (Appendix D).

For an implementation, they should be adopted unchanged as Python lists, for example:

ROUND_CONSTANTS = [
    ...,
]

Important: The round constants are XOR-combined after the round key. Since both AK and AC are XOR operations, they could be combined mathematically (state ^= rk ^ rc). For a reference implementation, however, it is recommended to keep both steps separate so that the flow of the specification remains clearly recognizable.

13. Shuffle (Permutation P)

At the end of each round, the nibbles are permuted.

No values are changed in the process.

Only their positions.

Blink-128
P =

[
5,
12,
4,
1,
17,
9,
10,
16,
28,
14,
21,
22,
11,
27,
8,
13,
2,
25,
18,
3,
30,
6,
19,
20,
0,
23,
24,
31,
7,
15,
29,
26
]
Meaning
new_state[0] = old_state[5]

new_state[1] = old_state[12]

...

new_state[31] = old_state[26]
Python
def permute(state):
    return [state[i] for i in P]
Inverse Permutation

For decryption, the inverse permutation is needed.

This should not be entered manually, but computed once at program startup:

INV_P = [0] * len(P)

for i, j in enumerate(P):
    INV_P[j] = i

This yields

def inv_permute(state):
    return [state[i] for i in INV_P]

This avoids errors and ensures that P and INV_P are consistent.

14. Order within a round

A forward round always consists of:

S

↓

MixColumns

↓

RoundKey

↓

RoundConstant

↓

Permutation

The backward round uses the same building blocks in reverse order due to the reflector structure. Since both the S-box and the MixColumns matrix are involutory, they can be reused in both directions. Only the permutation is replaced by its inverse, and the appropriate round keys and round constants are used in reverse order.

15. Toeplitz Hash (Core of Blink)

The Toeplitz Hash is the central component for tweak processing.

It replaces classical linear tweakey schedules and provides:

high diffusion in the tweak
logarithmic circuit depth
good security against multi-tweak attacks
15.1 Definition

The hash is defined as:

h_T(t) = T · t

where:

t is a bit vector of length τ
T is an n × τ Toeplitz matrix
multiplication is performed over GF(2)
15.2 Toeplitz structure

A Toeplitz matrix is completely defined by a diagonal:

k = (k0, k1, ..., k(n+τ-2))

Example:

T[i,j] = k[i + j]
15.3 Intuition

Each output bit is XOR of a diagonal selection of the key:

h(t)[i] = XOR_{j where t[j]=1} k[i+j]
15.4 Implementation (naive)
def toeplitz_hash(k, t, n, tau):
    # k: list of bits length (n+tau-1)
    # t: list of bits length tau
    out = [0] * n

    for i in range(n):
        acc = 0
        for j in range(tau):
            if t[j]:
                acc ^= k[i + j]
        out[i] = acc

    return out
15.5 Efficient implementation (bitwise)

For a reference implementation, the naive version is sufficient.

Optimizations (shift register / XOR parallelization) are optional.

15.6 Hash functions in Blink

Blink uses three hash functions:

h1(t) = T1 · t
h2(t) = T2 · t
h(t)  = h1(t) ⊕ h2(t)
Properties
T1 and T2 are independently and randomly chosen
h is also an AXU hash
all operations are linear in t
15.7 Python structure
class ToeplitzHash:
    def __init__(self, k, n, tau):
        self.k = k
        self.n = n
        self.tau = tau

    def __call__(self, t):
        return toeplitz_hash(self.k, t, self.n, self.tau)
15.8 Tweak Encoding

The tweak is always treated as a bit vector:

t ∈ {0,1}^τ

Python:

def int_to_bits(x, tau):
    return [(x >> i) & 1 for i in range(tau)]
16. Key Schedule

Blink intentionally does not use a classical key schedule.

Instead:

Master key is long
is sliced directly
16.1 Structure
k = w1 || w2 || rk1 || rk2 || ... || rkn
Meaning
w1: Whitening key (front)
w2: Whitening key (back)
rki: Round key
16.2 Python
def key_schedule(master_key, n_rounds, n):
    w1 = master_key[:n]
    w2 = master_key[n:2*n]

    rks = []
    offset = 2*n

    for i in range(n_rounds):
        rks.append(master_key[offset:offset+n])
        offset += n

    return w1, w2, rks
17. Whitening

Before and after encryption:

state ^= w1   (input whitening)

state ^= w2   (output whitening)
18. Encryption (complete)
def encrypt(plaintext, tweak, key):
    state = plaintext.copy()

    state ^= key.w1

    t = tweak

    state = S(state)
    state = M(state)
    state ^= key.rk[0]

    state ^= h1(t)

    for i in range(1, a):
        state = S(state)
        state = M(state)
        state ^= key.rk[i]

    state ^= h(t)

    for i in range(a, a+b):
        state = S(state)
        state = M(state)
        state ^= key.rk[i]

    state = permute(state)

    for i in reversed(range(a, a+b)):
        state = M(state)
        state = S(state)
        state ^= key.rk[i]

    state ^= h2(t)

    state ^= key.w2

    return state
19. Decryption

Decryption is structurally identical:

inverse order
same components (S and M are involutory)
inverse permutation
20. Tests

Minimal tests:

20.1 S-Box Involution
for x in range(16):
    assert SBOX[SBOX[x]] == x
20.2 Toeplitz Determinism
assert h(t) == h(t)
20.3 Encrypt/Decrypt
assert decrypt(encrypt(m, t, k), t, k) == m
21. Common implementation errors
wrong nibble order (most important error)
wrong permutation P vs INV_P
tweak not treated as bit vector
Toeplitz indices incorrectly shifted
forgotten whitening
h = h1 ⊕ h2 incorrectly combined
22. Most important design rule

If something is unclear:

👉 everything is XOR over bits or nibbles

Blink contains:

no multiplication
no multi-byte S-box networks
no modular operations
