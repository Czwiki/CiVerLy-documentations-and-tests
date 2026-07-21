date: 2026-05-22T 21:00:00Z
participants:
- You: Henry
- Assistant: Kilo AI, Kimi 2.6 via Neuralwatt
topic: "Implementation of the blink cipher"

User:
Please implement the blink cipher according to the specifications of a cipher implementation in  @documentation/README.md . The required test vectors can be found in @documentation/blink test vectors.md . A reference implementation is available @documentation/blink.py  together with a part of the published paper @documentation/blink.md  and a figure from the latter @documentation/Screenshot 2026-06-21 162611.png . Sage is installed via nix.


... (finding files)

Let me understand the task. I need to implement the Blink cipher as a CiVerLy cipher implementation following the README.md guidelines. Let me explore the codebase structure first to understand how existing ciphers are implemented.

Let me look at the project structure and existing cipher

I'll explore the codebase to understand how existing cipher implementations are structured in CiVerLy.

ls -la && echo "---SRC---" && ls -la src 2>/dev/null; echo "---CIVERLY---" && find . -name "*.py" -path "*cipher_implementation*" 2>/dev/null | head -50
total 128
drwxr-xr-x@ 17 Uni  staff    544 Jul  5 11:48 .
drwxr-xr-x@  8 Uni  staff    256 Jun 17 13:25 ..
-rw-r--r--   1 Uni  staff     10 Jun 24 11:12 .envrc
drwxr-xr-x  16 Uni  staff    512 Jul  6 21:01 .git
drwxr-xr-x   3 Uni  staff     96 Jun 24 11:12 .github
-rw-r--r--   1 Uni  staff     90 Jun 24 11:12 .gitignore
-rw-r--r--   1 Uni  staff   1071 Jun 24 11:12 CHANGELOG.md
-rw-r--r--   1 Uni  staff  14314 May 27 10:39 LICENSE
-rw-r--r--   1 Uni  staff   5567 Jun 24 11:12 Makefile
-rw-r--r--   1 Uni  staff   4300 Jun 24 11:12 README.md
drwxr-xr-x   2 Uni  staff     64 Jul  6 21:01 __pycache__
drwxr-xr-x   3 Uni  staff     96 Jun 24 11:12 docs
drwxr-xr-x   8 Uni  staff    256 Jul  6 21:02 documentation
-rw-r--r--   1 Uni  staff   4023 Jun 24 11:12 flake.lock
-rw-r--r--   1 Uni  staff   8325 Jun 24 11:12 flake.nix
-rw-r--r--   1 Uni  staff   1296 Jun 24 11:12 pyproject.toml
drwxr-xr-x   4 Uni  staff    128 Jun 27 10:50 src
---SRC---
total 0
drwxr-xr-x   4 Uni  staff  128 Jun 27 10:50 .
drwxr-xr-x@ 17 Uni  staff  544 Jul  5 11:48 ..
drwxr-xr-x  19 Uni  staff  608 Jul  5 10:47 civerly
drwxr-xr-x@  2 Uni  staff   64 Jun 27 14:00 civerly.egg-info
---CIVERLY---
./src/civerly/cipher_implementations/speck.py
./src/civerly/cipher_implementations/craft.py
./src/civerly/cipher_implementations/chacha.py
./src/civerly/cipher_implementations/hurdle.py
./src/civerly/cipher_implementations/simon.py
./src/civerly/cipher_implementations/halfloop.py
./src/civerly/cipher_implementations/aes.py
./src/civerly/cipher_implementations/present.py
./src/civerly/cipher_implementations/weak_present.py
./src/civerly/cipher_implementations/__init__.py
./src/civerly/cipher_implementations/ascon.py
./src/civerly/cipher_implementations/skinny.py
./src/civerly/cipher_implementations/gift.py
./src/civerly/cipher_implementations/toy_ciphers/toy8.py
./src/civerly/cipher_implementations/toy_ciphers/toy9.py
./src/civerly/cipher_implementations/toy_ciphers/toy2.py
./src/civerly/cipher_implementations/toy_ciphers/toy6.py
./src/civerly/cipher_implementations/toy_ciphers/toy7.py
./src/civerly/cipher_implementations/toy_ciphers/__init__.py
./src/civerly/cipher_implementations/toy_ciphers/toy3.py
./src/civerly/cipher_implementations/toy_ciphers/toy4.py
./src/civerly/cipher_implementations/toy_ciphers/toy1.py
./src/civerly/cipher_implementations/toy_ciphers/toy_ciphers.py
./src/civerly/cipher_implementations/toy_ciphers/toy5.py
./src/civerly/cipher_implementations/toy_ciphers/toy11.py
./src/civerly/cipher_implementations/toy_ciphers/toy10.py
./src/civerly/cipher_implementations/simon_variants.py
./src/civerly/cipher_implementations/des.py
./src/civerly/cipher_implementations/abc.py
Let me examine the existing implementations to understand the patterns, particularly present.py, skinny.py, and aes.py.

Now I understand the patterns. Let me look at the component definitions and the AESlike class to understand the API better. Let me also look at the __init__.py of cipher_implementations to understand exports.

The Blink cipher has 6 variants. The key challenge is the key schedule which is quite complex (hash function, Toeplitz-like matrix from key). The README says: "Decide whether the key schedule is modeled explicitly. If you only need fixed-round testing or do not analyze related-key behavior, use constants in RoundkeyXOR_CVL and pass rks to the constructor."

Blink's key schedule involves a hash function and complex key rearrangement. For a CiVerLy implementation for differential/linear cryptanalysis (where 0 keys / fixed tweaks are used for trail search), the practical approach is:

The round keys rk, whitening keys w1, w2, and hash values h1, h2 are all derived from the master key + tweak.
For modeling purposes, these are typically treated as constants (since we analyze the core cipher structure, not the key schedule).
But there's a complication: the hash value h depends on the tweak t. For the test vectors, the tweak is fixed. For modeling, we'd set tweak to 0... but the paper says tweak non-zero for security. For our purposes (trail search), we treat the round keys, whitening keys, and h-values all as constants.

Actually, let me reconsider. The structure of Blink:

The cipher has these "operation" components that are key-dependent:

whitening with w0 (RK at start)
round key addition rk[r] for each round
round constant addition rc[r] (constant, known)
hash h0 addition (a key, derived from master key and tweak)
final whitening with w1
h1 addition in the "decrypt" direction (actually it's h2 in the reflection)
For CiVerLy modeling, the round keys, whitening keys, and h-values should all be constants passed in. The round constants rc are also constants but known.

Given the complexity, I think the most faithful and useful approach is:

Compute the actual round keys / whitening / hash values for a given (key, tweak) using the reference algorithm, then plug them as constants. But the constructor needs the key schedule.
Actually, let me think about how to make this a proper CiVerLy cipher. The constructor could take a key and tweak, compute all the derived values (rk, w0, w1, h0, h1, h2) via a faithful key schedule, and then build the DAG with those as constants.

But the key schedule in Blink is complex (it involves a Toeplitz hash). Let me re-read the key schedule and hash function in blink.py to faithfully translate.

Actually, for CiVerLy, the key schedule being a DAG of components is required for the whole cipher to be modeled. But the README explicitly says we can use constants (RoundkeyXOR_CVL with const) when we don't model the key schedule. Given the extreme complexity of Blink's key schedule (Toeplitz hash, bit permutations), modeling it precisely is out of scope and not needed for the standard differential/linear trail analysis.

So the approach: implement the cipher as a DAG where:

The state is nibble-based (4-bit words). For Blink-64: 16 nibbles state. For Blink-128: 32 nibbles.
Components: SBox (4-bit, involution), MixColumns (LinearLayer per column), PermuteLayer (the shuffle), RoundkeyXOR (for AK and AC combined? or separate), whitening.
The MixColumns layer: M matrix is applied per column. The state is 4 rows × (n/16) columns of nibbles. Column j = [s_j, s_{j+n/16}, s_{j+n/8}, s_{j+3n/16}]. For Blink-64: n/16 = 4 columns, 16 nibbles. For Blink-128: n/16 = 8 columns, 32 nibbles.

The permutation P is a nibble permutation. P = [s_0...s_{n/4-1}] <- [s_{P[0]}, ...]. Wait, the paper says [s0, s1, ..., s_{n/4-1}] <- [s_{P[0]}, s_{P[1]}, ..., s_{P[n/4-1]}]. So new position i gets value from old position P[i]. Let me check the reference implementation. In blink.py permutation:

def permutation(self, state):
    temp = [state nibbles]
    permuted[i] = temp[self.pbox[i]]
    state[i] = combine permuted[2i+1], permuted[2i]
So permuted[i] = temp[pbox[i]]. The new nibble at position i is temp[pbox[i]], i.e., old nibble at position pbox[i] moves to position i. That matches the paper: new[i] = old[P[i]]. Good.

For the CiVerLy PermuteLayer_CVL, let me check what convention it uses. In PRESENT:

permutation = PermuteLayer_CVL([
    0, 16, 32, 48, 1, 17, ...
])
PRESENT's permutation: bit i goes to position bit_permuted[i]? Let me check. Actually PRESENT bit permutation: bit i of input goes to output position P(i). The standard PRESENT permutation maps... The CiVerLy PermuteLayer perm list: output position j gets input bit perm[j]. Let me verify with PRESENT: PRESENT's permutation sends bit i to position P(i) where P = [0,16,32,...]. In CiVerLy they use perm = [0,16,32,48,1,17,33,49,...]. This means output bit j = input bit perm[j]. So output 0 = input 0, output 1 = input 16, output 2 = input 32... That sends input bit 16 to output bit 1, i.e., input bit i -> output position j where perm[j]=i. So it's the inverse convention of PRESENT's standard (which maps input i -> output P(i)). Hmm, but it works for them. Let me just check the component definition to be sure.

Let me read the component.py to understand PermuteLayer_CVL, LinearLayer_CVL, RoundkeyXOR_CVL, SBox_CVL, I_CVL, AESlike, WordSBoxCipher.

Given the complexity, maybe AESlike is the right base class since Blink has a rectangular state (4 rows × columns) with column-wise MixColumns. That matches AESlike perfectly! AESlike uses rows=4, cols = n/16. MixColumns acts per column. That's exactly Blink's M layer.

But there's subtlety: AESlike uses a specific indexing. Let me read AESlike and the component.

Let me also reconsider: should I model this with AESlike (which gives word-wise MILP support and proper column diffusion), or WordSBoxCipher with an explicit LinearLayer for MixColumns? Given Blink's MixColumns is exactly column-wise AES-like, AESlike is the natural choice.

However, the permutation P in Blink is a full-state nibble permutation that acts across all nibbles. In AESlike, PermuteLayer_CVL can act on the whole state (as noted in README: "PermuteLayer_CVL may act on the whole state"). So we can use PermuteLayer_CVL with word_coarseness = word size = 4 (nibble).

Wait, AESlike works with words. The state in AESlike is words; for Blink the word is a nibble (4 bits). AESlike(s, rows=4, cols=C). The S-box applies to each word (nibble). MixColumns is a LinearLayer per column. The permutation P is a PermuteLayer over all words.

Let me read AESlike and component carefully.

Let me also figure out the round structure for modeling. The full Blink round (forward) is R = P ∘ AC ∘ AK ∘ M ∘ S. The cipher is a reflection with forward rounds, middle h-addition, backward rounds, final whitening.

For CiVerLy, I'll build the whole thing as a DAG with constants. The hash h values and round keys are constants computed from (key, tweak). But for the test vectors, I need to faithfully compute them. So I should port the key schedule to compute these constants, then feed them into RoundkeyXOR_CVL components.

But there's a problem: the key schedule in Blink is very involved (hash function with Toeplitz matrices). Porting it correctly AND verifying with the test vectors is the safest. The reference blink.py already does this. I can reuse/port that key schedule into the CiVerLy implementation to compute rk, w, h, and round constants, then build the DAG.

So the plan:

Create src/civerly/cipher_implementations/blink.py.
Port the necessary tables (SBOX, M_MATRIX, PBOX variants, round constants) and the key schedule (hash_func, generate_round_key) from blink.py — but these are "plain Python" reference computations, not CiVerLy components. They compute the constant round keys for a given key/tweak.
Build the CiVerLy DAG: for a given variant (block size, a, b, number of rounds), construct the cipher with AESlike base, with SBox, MixColumns (per column LinearLayer), PermuteLayer (the shuffle), RoundkeyXOR for AK+AC and whitening and h-additions.
The constructor takes key, tweak (and optionally rks, etc.) — compute the derived constants, set them.
Provide test vectors as doctests.
Wait, but the constructor signature pattern in CiVerLy: __init__(self, R, rks, name). For cipher that uses key schedule, like SKINNY, it takes (n, t, R, key, name). So I can take a key and tweak parameter.

But there's a concern: the hash h depends on the tweak. For trail analysis with analyse, you'd want tweak = full zero (so h = 0) — but the paper says tweak nonzero. For modeling, we treat h and round keys as constants (any fixed constants). So we just compute them once for the given key/tweak and bake them in.

Actually, for modeling purposes, the most important thing is that the round keys / h / whitening are constants (XOR of a fixed value), which RoundkeyXOR_CVL handles. The actual values don't affect the trail weight (XOR with constant doesn't change active pattern). So we just need some constants. For test vectors, we need the correct constants derived from the right key/tweak.

So: constructor takes key (int), tweak (int), variant params. Computes rk, w0, w1, h0, h1, h2 via the key schedule. Builds DAG with these as constants.

Now the exact round structure. Let me re-derive the round function and overall flow from blink.py and the paper.

The cipher has:

ra = a forward rounds (with round keys rk[0..a-1], round consts rc[0..a-1])
then a middle part: S, M, AK with h0 (hash), P
then rb backward rounds (with round keys rk[a..a+b-1], round consts rc[a..a+b-1])
then: S, M, AK with h0^h1, S
then rb backward inv rounds (inv_P, rc'_0, rk[0], M, S) ... wait
Let me carefully transcribe the encrypt function:

whitening(state, w[0])   # XOR w0
for r in range(ra):
    sub_bytes(state)
    mix_columns(state)
    add_round_key(state, rk[r])
    add_round_constant(state, round_const[r])
    permutation(state)
sub_bytes(state)
mix_columns(state)
add_round_key(state, h[0])       # h0
permutation(state)
for r in range(rb):
    sub_bytes(state)
    mix_columns(state)
    add_round_key(state, rk[r + ra])
    add_round_constant(state, round_const[r + ra])
    permutation(state)

h_xor = h[0] ^ h[1]
sub_bytes(state)
mix_columns(state)
add_round_key(state, h_xor)       # h0^h1
sub_bytes(state)

for r in range(rb):
    inv_permutation(state)
    add_round_constant(state, round_const_prime[r])
    add_round_key(state, rk[r])    # rk[r], r from 0..rb-1
    mix_columns(state)
    sub_bytes(state)
inv_permutation(state)
add_round_key(state, h[1])         # h1
mix_columns(state)
sub_bytes(state)
for r in range(ra):
    inv_permutation(state)
    add_round_constant(state, round_const_prime[r + rb])
    add_round_key(state, rk[r + rb])
    mix_columns(state)
    sub_bytes(state)
whitening(state, w[1])             # w1
Note ra+rb total "outer" rounds plus the optional middle. Wait total rounds: ra forward "full" rounds each with S,M,AK,AC,P. Then middle S,M,AK(h0),P. Then rb forward "full" rounds S,M,AK,AC,P. Then S,M,AK(h0^h1),S. Then rb inverse rounds each P^-1,AC,rk,M,S. Then P^-1, AK(h1), M, S. Then ra inverse rounds P^-1, AC, rk, M, S. Then final whitening w1.

The round keys for the forward parts: rk[0..ra-1], then rk[ra..ra+rb-1]. For the inverse parts: rk[0..rb-1] (first rb inverse), then rk[rb..rb+ra-1] (next ra inverse). Total rk entries used: forward uses indices 0..ra+rb-1 (that's a+b of them), inverse uses 0..rb-1 and rb..rb+ra-1 (that's again a+b). So rk has ra+rb = a+b entries. Round consts: forward uses rc[0..a+b-1] (a+b entries). Round consts prime: rb + ra = a+b entries (rc'[0..rb-1] then rc'[rb..rb+ra-1]). Good, all arrays have length a+b.

So the number of "full" keyed rounds is a+b, plus the two middle keyed layers (h0, h0^h1, h1). Total "round-equivalent" layers.

This is the reflector structure. For CiVerLy, I just need to build the DAG in this exact order with constants.

Now, the MixColumns in Blink: M = [[0,1,1,1],[1,0,1,1],[1,1,0,1],[1,1,1,0]]. Applied per column. In AESlike, MixColumns is a LinearLayer per column. But here the "column" order is [s_j, s_{j+n/16}, s_{j+n/8}, s_{j+3n/16}], which is rows 0,1,2,3 of column j. So within an AESlike state with rows=4, cols=C, the column j has nibbles at word positions (in AESlike column-wise indexing) 0,1,2,3 of column j, which map to... need to be careful with AESlike indexing.

Hold on. AESlike uses column-wise indexing: state word index = columnrows + row? Let me check AESlike definition. The SKINNY code builds mixcolumns as AESlike and applies mc to positions (i+4j, i) for i in range(4), i.e., column j's 4 nibbles at input positions j4 + i (input i) -> output position i+4j. And matrix_mc uses block structure. So in AESlike, a column j occupies word indices 4j, 4j+1, 4j+2, 4j+3 (row-major within column: row 0 at 4j, row1 at 4j+1, ...). Actually they use (i+4j, i) meaning input word (4j + i) maps... input index is (i+4*j)? The add_subcipher edge is (src, (src_index, dst_index)). So src word (i+4j) -> component input i, component output 0..3 -> dst word (i+4j). So column j consists of words 4j..4j+3. The LinearLayer mc is a 4x4 block matrix acting on the 4 words (each word is s bits where here s=n/16).

So in AESlike, MixColumns per column: column j = words {4j, 4j+1, 4j+2, 4j+3}. The component mc is a LinearLayer over 4*s bits (4 words of s bits each), where the top-left block is I, etc. For Blink, M is a 4x4 binary matrix over nibbles (s=4). So the LinearLayer is M applied to the 4 nibbles (each nibble = a 4-bit word). So mc = LinearLayer_CVL(matrix(GF(2), kron? ...)).

Wait, the nibble is the word. M is a 4x4 matrix over GF(2)^4? No — M is a 4x4 matrix over bits? No. Re-read: M is the Midori involutory matrix. It's a 4x4 matrix with entries in {0,1} but it operates on nibbles: result[r] ^= coldata[c] when M[r][c]=1, where coldata[c] is a nibble and the XOR is nibble-XOR. So it's a 4x4 matrix over GF(2)^4 (each entry is either 0 or identity-ish). Since M entries are 0 or 1, and the operation is nibble-wise XOR with identity mapping, the LinearLayer is a 16x16 binary matrix = Kronecker product? Let me think: output nibble r = XOR over c of (M[r][c] ? input_nibble_c : 0). Each nibble is 4 bits. So output bit b of nibble r = XOR over c of M[r][c] * (input bit b of nibble c). So it's (M ⊗ I_4) as a 16x16 binary matrix. Yes, Kronecker product M ⊗ I_4.

In AESlike with s=4 (word = nibble), the MixColumns component mc would be a LinearLayer over 4 words (16 bits). The block_matrix in SKINNY: matrix_mc = [[I,O,I,I],[I,O,O,O],[O,I,I,O],[I,O,I,O]] where each block is s×s. That's exactly M ⊗ ... no wait. Each block is I or O (s×s identity or zero). So the full 16x16 matrix = block_matrix(M_blocks) where M_blocks[i][j] is I if M[i][j]=1 else O. That's exactly M ⊗ I_4 (Kronecker). Yes.

So I can build MixColumns the same way as SKINNY's MixColumns but with Blink's M matrix.

So Blink-64: AESlike(s=4, rows=4, cols=4) => 16 nibbles. Blink-128: AESlike(s=4, rows=4, cols=8) => 32 nibbles.

Now the permutation P. It's a nibble permutation on the whole state. As a PermuteLayer_CVL acting on words (nibbles) with word_coarseness=4. The perm list maps output nibble i = input nibble P[i]. I need to construct perm such that output position i gets input position pbox[i]. Wait biverly PermuteLayer: output[j] = input[perm[j]] (based on PRESENT convention where perm[j] is the source). Let me verify by reading component.py.

Actually I must read component.py and AESlike to get conventions exactly right. Let me do that.

Also the S-box operates on each nibble independently. SBox_CVL with SBox([...]).

Now, the round constants and round keys: these are XORed (RoundkeyXOR_CVL). The round constants rc are known constants from the tables. The round keys rk and h values come from the key schedule.

Let me design the DAG:

Components (each a layer cipher or component):

sbox_layer: SBox applied to each nibble. As AESlike subcipher applying sbox to each word.
Actually since AESlike, easier: define each round as an AESlike subcipher composed of: SBox layer (subcells), MixColumns layer, then AK+AC, then Permute.

But AK and AC are both XORs. RoundkeyXOR_CVL takes a const and XORs. We can combine: AK with rk then AC with rc = XOR with (rk ^ rc)? But for trail modeling they're separate constants; combining is fine since XOR is XOR. Actually RoundkeyXOR_CVL XORs a constant. We can set const = rk ^ rc for the combined. But to be faithful and clear, maybe keep AK and AC as separate RoundkeyXOR. But that adds components. The README suggests RoundkeyXOR for key mixing. Combining round key and round constant into one XOR of (rk^rc) is acceptable since both are constants; the trail is identical. However, for the middle layers (h0, h0^h1, h1) there's no round constant. So I'll just use RoundkeyXOR with appropriate constant.

Let me define helper to build a "round" subcipher. But the rounds differ (forward vs inverse, with different key/const). Since constants differ per round and per position, I'll build each round as its own subcipher instance OR build a single parametrized round and set constants per round via node access. Given ra/rb are small (2,3,3,5), building explicit rounds is fine but verbose. Better: build one round-subcipher template and instantiate per round, setting constants.

But the AESlike node structure for setting const: similar to SKINNY. We need references to the RoundkeyXOR nodes to set their const per round.

Let me think about how many distinct "round" structures:

Forward full round: S, M, AK(rk_r), AC(rc_r), P. (ra rounds, r=0..a-1)
Middle forward-ish: S, M, AK(h0), P. (1)
Forward full round (continuation): S, M, AK(rk[a+r]), AC(rc[a+r]), P. (rb rounds)
S, M, AK(h0^h1), S. (2 S's, 2 M's, 1 AK) — no P, no AC.
Inverse full round: P^-1, AC(rc'_r), AK(rk_r), M, S. (rb rounds, r=0..b-1)
Middle inverse: P^-1, AK(h1), M, S. (1)
Inverse full round: P^-1, AC(rc'{b+r}), AK(rk{b+r}), M, S. (ra rounds, r=0..a-1)
So there are really a few distinct template rounds; constants vary. I'll create template subciphers and reuse, setting consts each iteration.

Now there's a subtlety: P and P^-1 are PermuteLayer and its inverse. In SKINNY they used .inv() on PermuteLayer. Good. So I'll create P_perm = PermuteLayer_CVL(pbox_mapping, word_coarseness=4, name="P") and use .inv() for inverse.

I need the exact mapping convention. Let me read component.py now.

Also need AESlike class API: AESlike(s, rows, cols, name). add_subcipher, add_output, IN, nodes. And how inputs/outputs map to words (nibble positions). The state for Blink: 16 nibbles (64-bit) or 32 nibbles (128-bit). In AESlike, total words = rows*cols = 16 or 32. Each word is s=4 bits. Good.

But the indexing: AESlike likely uses column-major: word index for (row r, col c) = crows + r = c4 + r. The state as 4 rows × C cols. For Blink the state is exactly 4 rows × C cols of nibbles. Column j nibbles are rows 0..3. In Blink's MixColumns, column j = [s_j, s_{j+n/16}, s_{j+n/8}, s_{j+3n/16}] = rows 0,1,2,3 of column j. And the AESlike MixColumns operates per column on those 4 nibbles.

Now the permutation P: it permutes nibble positions within the flat state. In Blink's flat nibble indexing, nibble i is at... The state is stored as bytes; nibble i (0..n/4-1) with byte i//2, high/low. The permutation uses pbox mapping pbox[i] = source nibble index. In CiVerLy AESlike word indexing, word 0..15 (or 31). I need to map Blink's nibble index to AESlike word index.

This is the critical convention issue. Let me figure out the mapping between Blink's "nibble i" and AESlike "word w".

In blink.py, the state is stored as a list of bytes (state_bytes). The nibble index i corresponds to byte i//2, and "high_nibble = (i % 2 == 1)" means nibble 0 = low nibble of byte 0, nibble 1 = high nibble of byte 0, nibble 2 = low nibble of byte 1, etc. So nibble i = byte (i//2), bit position (i%2==1 ? high : low).

For AESlike, the word indexing within the cipher... we need to decide how the 64-bit (or 128-bit) input maps to the AESlike words, consistent with how encrypt_bytes reads/writes bytes. So I need a consistent mapping between the byte array and AESlike word order.

In encrypt_bytes: state = list(reversed(list(plaintext))). So plaintext big-endian bytes [b0, b1, ..., b_{N-1}] become state = [b_{N-1}, ..., b0]. So state[i] for i=0 is the LAST byte (least significant) of plaintext. So Blink treats state byte 0 as the least significant byte. Nibble 0 = low nibble of byte 0 = least significant nibble of the plaintext.

In CiVerLy, the cipher input is a vector of bits (int_to_vec). For an n-bit cipher, the input vector is n bits, and vec_to_int gives back. The convention: how does int_to_vec(0xabcd1234, 64) map to AESlike words? Typically the LSB is at word 0? Let me check how present/aes map. Actually I think I need to make the Blink CiVerLy implementation's own convention and just verify with test vectors by computing through the DAG and comparing vec_to_int output to expected ciphertext.

The cleanest: pick a mapping and make encrypt_bytes-equivalent. Since I'll port the full reference encrypt to compute round keys, and then build the CiVerLy DAG, I need the DAG to produce the same bit result for the same key/tweak/plaintext as the reference. So I must define the bit-to-AESlike-word mapping consistently.

Let me define: AESlike word index w (0..15 or 31) corresponds to Blink nibble index w directly. Then the plaintext integer P (n bits, big-endian as in hex) maps to nibbles: nibble 0 = LSB of P. The input vector to CiVerLy: int_to_vec(P, n) where bit 0 (LSB) is ... I need to know int_to_vec convention. Let me check util.int_to_vec.

Let me read util.py and the components and AESlike. I'll gather these.

Given the complexity, this is a substantial task. Let me read the key files.

... (reading files)

Good. Now I have enough understanding. Let me plan the implementation.

I'll create src/civerly/cipher_implementations/blink.py implementing the Blink cipher family.

Design decisions:

Base class: AESlike (since rectangular state, column-wise MixColumns => wordwise MILP support). Blink-64: AESlike(4, 4, 4) (wordsize=4, 16 nibbles). Blink-128: AESlike(4, 4, 8) (32 nibbles).
Word = nibble (4 bits). word_coarseness for PermuteLayer = 4.
S-box: SBox_CVL(SBox([0x1,0x0,0x9,0x3,0x8,0x5,0xE,0x7,0x4,0x2,0xC,0xB,0xA,0xF,0x6,0xD])) (involution).
MixColumns: LinearLayer per column, matrix M⊗I_4 (16x16). Branch number: M has differential branch number 4 over nibbles? For Midori M, branch number is 4 over 4-bit words. So branch_number_differential=4, branch_number_linear=4. Actually for wordwise modeling. Let me set both to 4 (it's the same matrix as Midori). I'll set 4.
Wait — but the LinearLayer check in AESlike.add_subcipher requires input_length == rowswordsize = 44 = 16. And alignment: edges must be a full column. The LinearLayer is 16x16. Good.

Permutation P: PermuteLayer_CVL(perm, word_coarseness=4). Need perm mapping in AESlike word indexing. The convention: perm[i] = source word index such that output word i = input word perm[i]. From component: arr[perm[i]][i] = identity, meaning binary_matrix row perm[i], col i = identity => output bit mapping: output word i gets input word perm[i]. And in wordwise MILP modeling: MILP_OUT[self.perm[i]] == MILP_IN[i]. So output word perm[i] = input word i. Wait that's the inverse of what I said. Let me re-read.
In _model_milp wordwise: self.MILP_OUT[self.perm[i]] == self.MILP_IN[i]. So for each i, MILP_OUT[perm[i]] = MILP_IN[i]. That means output position perm[i] receives input position i. So the permutation maps input i -> output perm[i].

In the binary_matrix construction: arr = [[0]*n for _ in range(n)]; for i: arr[perm[i]][i] = I. So row = perm[i], col = i is set. For a LinearLayer, output[y] = sum over x where M[y][x]=1 of input[x]. With M[y][x] = I at (y=perm[i], x=i), that means output[perm[i]] = input[i]. So yes: input i -> output perm[i].

Now the informal test: PermuteLayer_CVL([1,3,2,0]); vec_to_int(perm(int_to_vec(0x9,4))) == 12. int_to_vec(0x9,4) = bits for 0x9 = 1001 (LSB first? int_to_vec(0x9,4): digits(2,padto=4)[::-1]. 0x9=9=1001 in 4 bits digits = [1,0,0,1], reversed => [1,0,0,1]. So vector = (1,0,0,1), bit0=1,bit1=0,bit2=0,bit3=1. perm=[1,3,2,0] means output[perm[i]]=input[i]. So: output[perm[0]=1] = input[0]=1 output[perm[1]=3] = input[1]=0 output[perm[2]=2] = input[2]=0 output[perm[3]=0] = input[3]=1 output = [out0,out1,out2,out3] = [1,1,0,0]. vec_to_int((1,1,0,0)) = 1<<3 + 1<<2 = 8+4=12. Yes! Matches. Good, so perm semantics: output[perm[i]] = input[i].

Now for Blink, the permutation P: paper says [s0,s1,...,s_{n/4-1}] <- [s_{P[0]}, s_{P[1]}, ..., s_{P[n/4-1]}]. So new nibble position i has value old nibble P[i]. I.e. output[i] = input[P[i]]. That's the inverse of the CiVerLy convention (input P[i] -> output i). So the CiVerLy perm should be the inverse permutation: perm_cvl[i] such that output[perm_cvl[i]] = input[i], and we want output[i]=input[P[i]], i.e. perm_cvl[P[i]] = i, i.e. perm_cvl = inverse(P).

Let me double check with reference: blink.py permutation does permuted[i] = temp[self.pbox[i]], and then state[i] = combine(permuted[2i+1], permuted[2i]). So the new nibble at flat index i is temp[pbox[i]] (old nibble pbox[i]). So output[i] = input[pbox[i]]. Yes, Blink's P maps output position i <-> input pbox[i]. So to express in CiVerLy's PermuteLayer, we need perm such that output[perm[i]] = input[i], i.e. perm = inverse(pbox).

But wait — pbox here is the "P" from the paper. Let me verify: For 64-bit, P = [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8]. This is output[i] = input[P[i]]. So CiVerLy perm = inverse of this.

Actually, let me reconsider whether the AESlike word indexing matches Blink's flat nibble indexing directly. In Blink, nibble index i: byte i//2, high nibble if i odd. The AESlike word index w (0..15 or 31) — how does it map to bits? For AESlike(s=4, rows=4, cols=4), total 16 words, each 4 bits. The input vector to the cipher is n bits. Word w occupies bits [4w, 4w+3]? Let me check how AESlike maps input vector to words. Actually the WordBasedCipher / AESlike just treats the input as a flat bit array indexed by bit position, and word edges map via wordsize. The eval function in Cipher collects plaintext bits: output[c] from evals. The word indexing in terms of bit positions: in add_subcipher for WordBasedCipher, edge (x, y) becomes (xwordsize+o, ywordsize+o). So word index y in the component corresponds to bit positions y*wordsize+o in the component's input. And component input bits come from source via edges. For the cipher's IN, bit x of node a (IN) maps from plaintext[x].

So within the AESlike cipher, word w (in AESlike's own word indexing) corresponds to bit positions [4w .. 4w+3] of the cipher's overall input vector. And the overall input vector is int_to_vec(P, n) where bit 0 = LSB. So word w = bits [4w..4w+3], with bit 4w = LSB of word w.

Now I need the mapping between Blink's "nibble index i" and AESlike "word w" to be consistent with the test vector. The reference treats nibble 0 = LSB of plaintext. With AESlike word w corresponding to bits 4w..4w+3, word 0 = bits 0..3 = LSB nibble. So Blink nibble i = AESlike word i directly! Great, consistent: word w holds Blink nibble w.

So I can directly use Blink's nibble index = AESlike word index. The MixColumns column j = words {j, j+4, j+8, j+12} (for 4 rows: 4j+r). Blink's column j = [s_j, s_{j+n/16}, s_{j+n/8}, s_{j+3n/16}]. For n=64, n/16=4, n/8=8, 3n/16=12. So column j = nibbles {j, j+4, j+8, j+12} = AESlike column j (rows 0,1,2,3).

For n=128, n/16=8, n/8=16, 3n/16=24. column j = {j, j+8, j+16, j+24} = AESlike column j (rows 0..3, cols=8).

So the MixColumns LinearLayer per column maps input words (4j+r, r=0..3) -> output words (4j+r). The matrix M (4x4 over nibbles) as block matrix with I/O 4x4 blocks: same as SKINNY.

Now the permutation P. Blink's P (pbox) maps output nibble i = input nibble pbox[i]. In AESlike word indexing, output word i = input word pbox[i]. So the CiVerLy PermuteLayer perm must satisfy output[perm[i]] = input[i], i.e. perm = inverse(pbox). Let me compute inverse for 64-bit pbox.

pbox_64 = [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8] inverse: inv[pbox[i]] = i. pbox[0]=0 -> inv[0]=0 pbox[1]=5 -> inv[5]=1 pbox[2]=11 -> inv[11]=2 pbox[3]=10 -> inv[10]=3 pbox[4]=1 -> inv[1]=4 pbox[5]=6 -> inv[6]=5 pbox[6]=4 -> inv[4]=6 pbox[7]=13 -> inv[13]=7 pbox[8]=2 -> inv[2]=8 pbox[9]=12 -> inv[12]=9 pbox[10]=9 -> inv[9]=10 pbox[11]=15 -> inv[15]=11 pbox[12]=3 -> inv[3]=12 pbox[13]=7 -> inv[7]=13 pbox[14]=14 -> inv[14]=14 pbox[15]=8 -> inv[8]=15 So inv_64 = [0,4,8,12,6,1,5,13,15,10,3,2,9,7,14,11]

Wait but does the inverse permutation matter for trail analysis? The permutation is a bijection regardless; for correctness of evaluation and the trail, we just need it consistent. For inv_perm, PermuteLayer_CVL handles .inv() for the inverse direction. I'll build P_perm = PermuteLayer_CVL(inv_pbox, word_coarseness=4) representing the forward P. Then P^-1 = P_perm.inv(). Let me double-check: PermuteLayer.inv() computes inverse permutation of self.perm. If self.perm = inv_pbox (the CiVerLy forward mapping for Blink's P), then .inv() gives pbox (the inverse), which would be the Blink P^-1 mapping. Good.

But wait, I need to verify the forward P with inv_pbox actually computes Blink's P correctly under evaluation. Let me just trust the derivation; I'll verify by running the test vectors.

Now the round constants. The round constants rc are per-byte arrays (state_bytes entries). For Blink-64, state_bytes=8 => 8 bytes = 16 nibbles. rc[r] is a list of 8 bytes. As a single integer XORed to the state: combine bytes little? The reference add_round_constant does state[i] ^= constant[i] for i in range(state_bytes), where state[i] is byte i. So the constant integer, when interpreted as bytes state[0..state_bytes-1], XORs. To form a single integer value c such that XOR over the whole state equals XOR with c, I need to know bit/byte ordering. In the reference, state byte i is at... and the cipher's overall integer: byte 0 (LSB) corresponds to word 0 (nibbles 0,1). The constant array constant[i] is byte i. So constant integer C where byte i = constant[i]. int encoding: C = sum_{i} constant[i] << (8i). Then XOR with the state integer (LSB byte = byte 0). Since reference state byte i XOR constant[i], and the integer representation has byte i at position 8i, XOR with C does exactly that.

So I can precompute the round constant integer for each round as sum(constant[i] << 8*i). Same for round const prime, whitening keys w0, w1, round keys rk, h values. All as integers, XORed via RoundkeyXOR_CVL(const=...).

Now the key schedule. I'll port the key schedule from blink.py (hash_func, generate_round_key) to compute rk, w, h for a given master key and tweak. Since the cipher operates on the whole state as one integer, I'll compute these derived constants as integers.

The key schedule in blink.py works on byte arrays with specific LSB-first conventions. The encrypt_bytes function reverses plaintext, tweak, key bytes. So master_key passed is reversed(bytes(key)). And the state bytes are also reversed relative to big-endian. But for CiVerLy, I just need the final integer values XORed. The derived constants rk, w, h are computed from the byte arrays. The XOR constant C for a given subkey: it's an array of state_bytes bytes, where byte i of the state. Since the state integer's byte i is at 8i, C = sum(byte[i] << 8i).

So I'll port the key schedule to take the master key as an integer (big-endian bytes as in test vectors) — but the reference reverses the bytes. So I should feed master_key = list(reversed(list(key_bytes))) to generate_round_key, matching encrypt_bytes. Then take the resulting arrays rk[r] (length state_bytes), w[0], w[1], h[0], h[1], each a list of state_bytes bytes, and convert each to an integer via sum(byte[i] << 8*i).

Let me verify: in reference, state is manipulated as byte list, byte 0 = state[0]. The cipher input integer (from CiVerLy perspective) has byte 0 at bit 80. AESlike word 0 = nibbles 0,1 = bits 0..7 = byte 0. So yes byte i = state[i] maps to 8i. Good. So converting each byte-array constant to integer via sum(c[i]<<8*i) is correct.

Now, the constructor signature. I'll model it like SKINNY: BLINK_CVL(n, t, key, tweak, name) plus variant a,b, pbox, round_const tables. Actually to keep it simple and match the 6 variants, I'll make a single class BLINK_CVL that takes parameters: n (block bits), t (tweak bits), key (int), tweak (int), name. Derived: state_bytes = n//8, tweak_bytes = t//8, key_bytes = (a+b+2)*state_bytes. From key/tweak compute rk,w,h.

But a, b, and the round constant tables differ per variant. I'll derive a, b, and RC tables from (n, t, key_bytes). Actually simpler: pass explicit parameters. Let me define a helper that maps (n, t) and key length to the variant config. 6 variants:

64a: n=64, t=64, key=56 bytes, a=2,b=3, RC_64
64b: n=64, t=128, key=56, a=2,b=3, RC_64
128a: n=128,t=128,key=128,a=3,b=3,RC_128a
128b: n=128,t=256,key=128,a=3,b=3,RC_128a
128A: n=128,t=128,key=160,a=3,b=5,RC_128A
128B: n=128,t=256,key=160,a=3,b=5,RC_128A
So config determined by (n, t, keylen). I'll write a dispatch. The number of rounds = a+b (outer keyed rounds) plus the reflector structure. For modeling "R" rounds: the reference has fixed total rounds. There's no R parameter in the reference; it's fixed by a,b. Let me count total operations. The encrypt has:

ra S,M,AK,AC,P (with rk[r], rc[r]) for r in 0..a-1
S,M,AK(h0),P
rb S,M,AK,AC,P (rk[a+r], rc[a+r]) for r in 0..b-1
S,M,AK(h0^h1),S
rb inv_rounds: P^-1, AC(rc'[r]), AK(rk[r]), M, S for r in 0..b-1
P^-1, AK(h1), M, S
ra inv_rounds: P^-1, AC(rc'[b+r]), AK(rk[b+r]), M, S for r in 0..a-1
whitening w1
So total is fixed. For the CiVerLy cipher, "R" might be used to limit rounds for modeling. But the reference doesn't break it into a single R. For simplicity and to match test vectors, I'll build the FULL cipher (fixed structure from a,b). I could add an optional R to truncate for analysis, but that complicates the reflector. I'll follow the README pattern of other ciphers and just build the full cipher with name and key/tweak. Actually let me check: do the doctests need an R parameter? The README template uses R. SKINNY uses R with default None => full rounds. I'll provide R to optionally reduce the number of outer rounds for modeling convenience, but default to full (a+b rounds for each of the forward and inverse halves?).

Hmm, the reflector structure makes "R" ambiguous. To keep things robust and faithful, I'll implement the FULL cipher and not support a partial R (or support R only as number of forward keyed rounds each side). Given the task is to implement and verify test vectors, the most important is correctness of full cipher. Modeling is a bonus. I'll build full cipher.

But I want to also allow lightweight modeling tests (e.g., a few rounds) as the README requires a test with modelling. I can build the full cipher and the modelling will run on it. For test vectors, full cipher.

Actually, for a manageable modeling test, full Blink has many rounds (2+3+3+5 = ... let me count: 64a: a=2,b=3 => forward 2 + middle + forward 3 + middle2 + inverse 3 + inverse 2 = total S-layers: 2 +1 +3 +2 +3 +1 +2 = 14 S layers). That's a lot but fine for a small MILP test with bitwise. The doctest in README for PRESENT used R=4. For Blink I can just do a full-round analyze (BITWISE, small) or limit. Since full 64a has 14 rounds, modeling may be heavy but doable. Actually I worry about runtime. Let me make the modeling doctest use a reduced version. But the structure is fixed...

Alternative: I can make the cipher support an R parameter that overrides a and b? No.

Let me reconsider: I'll build the cipher with the full structure but allow the constructor to accept rounds to limit the number of outer forward+inverse rounds symmetrically for analysis. Hmm complex.

Simplest robust approach: Build the full cipher always (matches test vectors). For the modeling doctest, wrap in # optional - scip/# optional - gurobi and run analyse on full cipher (it will be heavy but it's optional and only run if solvers installed). But in this environment, sage is installed but maybe not scip/gurobi/cryptominisat. The doctests with # optional - solver won't run in normal make test. So I can include them and they'll be skipped. Good — the README wants modelling examples but they're optional.

But I should at least make sure the cipher is valid and evaluates correctly (test vectors), which I can test directly with eval (no solver needed). And I can run a bitwise MILP/SAT model generation (model()) which doesn't need a solver — model() builds the constraint system. Actually analyse needs a solver. But I can test model generation with cipher.model(model_options) which writes files but doesn't solve, without solver? Let me check: model() calls _model_milp/_model_sat which just build. analyse calls solver. So I can test cipher.model(...) to ensure the DAG models without errors, using a tempfile, no solver. That validates the structure for MILP/SAT without needing a solver.

For the doctest minimal test set, README says:

One encryption test with known test vector.
One test that runs analyse or model with supported solver (optional tag).
One test that calls get_trail and asserts no unnamed components.
For "no unnamed components", get_trail needs a solver too (reads solution). Hmm. Actually get_trail requires a solved model. Without solver, can't. But I can assert names are set by checking the report/graph has no "Unnamed Component". Actually I can add a test that builds the model and checks no component is unnamed by traversing? The README specifically says "calls get_trail and asserts that no unnamed components appear". That requires solver. I'll mark optional.

So my plan:

Implement blink.py with BLINK_CVL class (and maybe small config).
Verify test vectors by evaluation (eval the cipher on plaintext int with the computed constants, compare to expected ciphertext). Need to map the test vectors correctly.
Let me think carefully about evaluation: The cipher object, when called with int_to_vec(plaintext_int, n), should produce int_to_vec(ciphertext_int, n). The plaintext in test vectors is "00"*16 etc (all zero). The expected ciphertext is given. My derived constants (w0, rk, h, rc, w1) computed from key/tweak. The initial whitening w0 XORs plaintext. Since plaintext is 0, first whitening = 0 XOR w0 = w0. Fine.

So if my DAG and constants are correct, eval(0) should equal ciphertext int.

I need to double-check the byte/integer conversion for constants matches the reference's bit layout. The reference works on bytes where state byte 0 is LSB. The CiVerLy integer: bit 0..7 = byte 0 = word 0 (LSB). When I XOR constant C = sum(byte_i << 8i), and the state integer S = sum(state_byte_i << 8i) (state_byte_0 = LSB), then S ^ C corresponds to reference state[i] ^= constant[i].

But here's subtlety: the reference permutation P operates on nibbles, and within a byte, nibble 0 = low nibble, nibble 1 = high nibble. In my AESlike word mapping, word w = bits 4w..4w+3. Word 0 = bits 0..3 = low nibble of byte 0. Word 1 = bits 4..7 = high nibble of byte 0. So AESlike word w corresponds to Blink nibble w exactly (since Blink nibble i = byte i//2, low if i even). And the permutation P in Blink is defined on nibble indices, which = AESlike word indices. Good, consistent.

Now the round constants: rc tables are arrays of bytes (length state_bytes). As integer C = sum_{i} rc[i] << 8*i. Good.

The whitening w0, w1: w[0][i] = master_key[i], w[1][i] = master_key[i+state_bytes]. master_key is reversed key bytes. So w0 byte i = reversed_key[i] = original_key_byte[len-1-i]. As integer, C_w0 = sum_i master_key[i] << 8i. That's the reversed key interpreted as LSB-first. Fine — it's just a constant; the reference uses it the same way.

Now I'm fairly confident. Let me also double check the hash function and key schedule produce the right rk/w/h. Since the test vectors will validate the whole thing, if encrypt matches I'm good. If it doesn't match, I'll debug the key schedule or the DAG.

Now, one concern: the reference generate_round_key signature: generate_round_key(self, master_key, t) where master_key is reversed key bytes list, t is reversed tweak bytes list. And it uses self.state_bytes, self.tweak_bytes, self.key_bytes, pbox? No, key schedule doesn't use pbox. It uses self.key_bytes, self.state_bytes, self.tweak_bytes, HW2 table, and the round constants are separate. Good.

Let me port BlinkCipher's key-schedule-only methods (hash_func, generate_round_key) into the CiVerLy module as helper functions operating on integers/byte lists. Actually I can just instantiate a helper that mirrors blink.py but only for key schedule, OR I directly port the functions. Simpler: replicate the key schedule functions as standalone functions taking (key_int, tweak_int, config) and returning the integer constants. But config includes state_bytes, tweak_bytes, key_bytes. I'll write a function blink_key_schedule(key_bytes_reversed, tweak_bytes_reversed, state_bytes, tweak_bytes, key_bytes) returning (rk_list_of_ints, w0_int, w1_int, h0_int, h1_int, h_xor_int).

Actually the round keys rk[r] are arrays of state_bytes bytes => convert to int. The h values similarly. Let me write it.

Let me also handle: the reference uses master_key length = key_bytes. For 64-bit variants key_bytes=56, for 128a/b key_bytes=128, 128A/B key_bytes=160. The test vector keys are given as hex; e.g. 64a key = 56 bytes = 112 hex chars. Let me verify: 64a key string has how many hex chars? The 64a key in test vector: "d6a102d888a467e4d1d7dec33a246943" (16) + "e07c1dc6f302c57e762c2df9de6f0d21"(16) + "6dd387874a0b52ce3022e0ad78c78a06"(16) +"97779021b38e7fa1"(16) = 64 hex chars = 32 bytes?? Wait. Let me count the 64a key block in blink.py TEST_VECTORS: it has 4 lines of 16 hex each = 64 hex = 32 bytes. But key_bytes for 64a is 56. Hmm!

Wait, the test vector in blink test vectors.md: F.1 Blink-64a: k = 0xd6a1...7fa1 (a long hex). Let me count that k. In blink.py the 64a key is 4*16=64 hex=32 bytes. But key_bytes=56? That's inconsistent.

Wait, maybe I misread. Let me recount blink.py 64a key. Lines 570-574:

"d6a102d888a467e4d1d7dec33a246943"
"e07c1dc6f302c57e762c2df9de6f0d21"
"6dd387874a0b52ce3022e0ad78c78a06"
"97779021b38e7fa1"
Each line 16 hex except last 16. Total 64 hex chars = 32 bytes. But Blink_64a defined with key_bytes=56. So the test vector key is 32 bytes, not 56!

There's a discrepancy. Let me re-examine. Maybe the key schedule uses key_bytes but the test vector only provides 32 bytes? That can't work with key_bytes=56. Let me look at the actual test vector md file: F.1 Blink-64a: k = 0xd6a102d888a467e4d1d7dec33a246943e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a0697779021b38e7fa1

Let me count: d6a102d888a467e4d1d7dec33a246943 (32) + e07c1dc6f302c57e762c2df9de6f0d21 (32) =64 + 6dd387874a0b52ce3022e0ad78c78a06 (32) =96 + 97779021b38e7fa1 (16) = 112 hex chars = 56 bytes!

But the blink.py TEST_VECTORS only has 4*16=64? Let me recount line: "d6a102d888a467e4d1d7dec33a246943" that's 32 hex chars. Line 2 "e07c1dc6f302c57e762c2df9de6f0d21" 32. Line3 "6dd387874a0b52ce3022e0ad78c78a06" 32. Line4 "97779021b38e7fa1" 16. Total = 112 hex = 56 bytes. I miscounted earlier (thought each 16). 32+32+32+16 = 112 = 56 bytes.

So key_bytes=56 is correct. Good, my earlier count was wrong. Great.

So the full blink.py test vectors are consistency-checked already (run_tests passes presumably). So my port should reproduce them. Actually the blink.py is the reference; I just need to embed its key schedule and verify my CiVerLy DAG matches its encrypt. Since blink.py's run_tests already passes (presumably), I can use blink.py as ground truth: I'll compute the ciphertext via blink.py's encrypt_bytes and compare with my CiVerLy eval. If they match, done.

Let me verify blink.py works first by running it.

Let me run blink.py run

... (first implementation)

There's an issue: I call ra_rb_from_n_t in _variant_config before it's defined? Python resolves names at call time, so as long as it's defined at module level before BLINK_CVL.__init__ is called, it's fine. It's defined at the bottom. OK.

But there's a subtle bug: in _variant_config, I compute ra, rb from (n, key_bytes), but I also call ra_rb_from_n_t(n,t) to determine key_bytes when key=0. But the function signature of _variant_config already receives key_bytes. The logic for the default key_bytes when key=0: I call _variant_config(n, t, (key.bit_length()...)). Let me re-examine the call:

state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime = _variant_config(
    n, t, (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
)
Operator precedence: (key.bit_length() + 7) // 8 if key else (...). This is a conditional expression: A if key else B where A = (key.bit_length() + 7) // 8. Good. When key=0, key is falsy, so key_bytes = (n//8)*(ra_rb_from_n_t+2). Good.

Then inside _variant_config, it re-derives ra, rb from (n, key_bytes). For n=128, key_bytes=128 -> ra,rb=3,3. key_bytes=160 -> ra,rb=3,5. Good. And asserts ra+rb+2 == key_bytes//state_bytes. For n=128,key_bytes=128: 3+3+2=8 == 128/16=8. Good. For 160: 3+5+2=10 ==160/16=10. Good. For n=64,key_bytes=56: 2+3+2=7==56/8=7. Good.

Now there's a concern: when a real key is provided with a different byte length than expected, it'd assert-fail. That's acceptable; the test vectors provide exact-length keys.

Now the bigger concern: does the DAG correctly reflect the reference? Let me verify via eval against blink.py. But first, there's a potential issue with how add_subcipher to cipher for fwd_round (an AESlike) works, and then setting constants via cipher.nodes[node].nodes[node_rk].const. node_rk is the index returned by fwd_round.add_subcipher(rk_xor(0), ...). Since fwd_round is added as a subcipher (deep-copied) into cipher, the deep copy preserves the structure; cipher.nodes[node] is the deep copy of fwd_round, and .nodes[node_rk] is the deep copy of the rk_xor component. Setting .const on it modifies that instance. But note: the component rk_xor(0) is created fresh each call (good, no shared mutable instances). However, within fwd_round, I create rk_xor(0) twice (node_rk and node_rc) as separate instances — good.

But careful: cipher.nodes[node] — when we add_subcipher(fwd_round,...), it deepcopies fwd_round and appends. The returned node index node is that index. cipher.nodes[node] is the deep-copied fwd_round cipher. Its .nodes list contains deep copies of subcells, mixcolumns, rk_xor, rk_xor, perm. The index node_rk corresponds to the rk_xor used for the round key. Good. Setting const there works.

But wait: there's a subtlety with deepcopy and hashing. The components are hashed for caching in SAT modeling. Since each rk_xor instance has const=0 at build time, two fwd_rounds added to cipher would be considered equal (same hash) and the SAT modeling would reuse the first one's model — but their consts differ! That's a problem for SAT modeling (and MILP? MILP also caches by hash). Actually for RoundkeyXOR the const matters for evaluation but for the MODELING (differential/linear), the const is irrelevant (XOR with constant doesn't change activity). So caching by hash ignoring const is actually fine for modeling — the const doesn't affect the model. The eval uses the actual const. So it's okay: all rk_xor components with const=0 at hashing time are identical models, and sharing is correct.

But here's a real concern: when I build fwd_round once and add it multiple times (for r in range(ra)), the deepcopy happens each add_subcipher call, so each instance is separate. Good. But the SAT/MILP caching in model() compares comp == prev by hash. Since all fwd_round deep-copies have identical internal structure (consts all 0 at that point? No—I set consts AFTER adding). At modeling time, the consts are set to their final values. But the hash of an AESlike cipher depends on its subgraphs' hashes, which depend on components' hashes (ignoring const). So fwd_round instances are equal by hash regardless of consts. The modeling caches and reuses — fine because consts don't affect models. Good.

Actually wait, there's a deeper concern: the fwd_round and bwd_round are separate builds, and subcells, mixcolumns are shared across all rounds (same instances added multiple times). That's the intended pattern (like PRESENT's sboxlayer). Good. But the README warns: "Reusing the same mutable component object across unrelated layers can lead to confusing names or shared state; prefer building a dedicated layer ciphers." subcells and mixcolumns are built once and reused — that's the PRESENT pattern, acceptable.

Now, the crucial test: does eval produce the right ciphertext? Let me run a quick test comparing blink.py's encrypt_bytes output. But blink.py's encrypt_bytes reverses bytes. My cipher takes key/tweak as integers and expects LSB-first byte order, which matches: I build master_key from key bytes LSB-first (byte i = (key>>8i)&0xFF). And the cipher integer: plaintext int 0 -> state 0 -> after whitening w0. The reference encrypt_bytes(state=reversed(plaintext), ...). For plaintext 0, reversed is also 0, fine.

But for the comparison to be meaningful, I should compare my cipher's output integer with the expected ciphertext integer from the test vector, which is given in big-endian hex. my cipher output: vec_to_int(int_to_vec(c, n)) for c = ciphertext int. Since the reference's cipher is the same permutation of bits, and both use LSB-first integer conventions matching, the integer should match directly. Let me just test.

Actually let me reconsider the byte ordering of constants once more with a concrete check. The reference add_round_constant: state[i] ^= constant[i]. The "state" is a list of bytes, and the final ciphertext is bytes(reversed(state)). So output byte 0 (in returned bytes) = state[state_bytes-1].

Now my cipher integer: represented as int where bit position b belongs to byte (b//8) with byte 0 = LSB. When I do XOR with C = sum(constant[i] << 8i), the constant's byte i sits at byte position i. In the reference, constant[i] XORs state[i]. And the reference's state[i] is at byte position i (LSB-first), because the ciphertext returned is reversed(state), meaning state[0] = LSB byte. So both use LSB-first byte ordering with byte 0 = least significant. So XOR with C correctly matches.

The MixColumns, S-box, and permutation all operate on nibble/byte indices in the reference, and I've mapped nibble index = word index = byte i*2 + nibble. Since the reference and my mapping both use LSB-first (byte 0 = LSB, nibble 0 = low nibble of byte 0), they're identical.

So the only remaining question is whether my DAG ordering and the constant values exactly mirror the reference. Let me just test it. Let me also verify the round key generation matches by computing one and comparing.

Let me write a quick test

... (code executions)

MixColumns is correct! The issue must be the SBox ordering or the permutation. The SB+MIX combined failed. But SB alone — let me recheck. Earlier the SB alone matched (dbg5). But SB+MIX combined gave wrong. Wait, in dbg7 I did mix(int_to_vec(vec_to_int(sub(int_to_vec(v,64))),64)). Let me test SB alone then feed to MIX properly, comparing to reference sub then mix.

Actually wait — in dbg7 the refSBmix was fb7d91a353df1486 and cvl was 3814ad353a1c82ba. But MixColumns alone matches. So the SB output going into MIX must differ. Let me test sub alone in integer form and feed to mix.

Actually the issue: in dbg3, the SB alone: ref after SB only was acce9314368d322c, cvl 6dafcb42e7859310. The display was reversed (little-endian int). Let me recheck: ref SB string acce9314368d322c was ''.join(f'{x:02x}' for x in reversed(ref))? No in dbg3 I printed ref= acce9314368d322c from ref_v = st_int(ref) where st_int = int from reversed bytes (little-endian). And cvl from out_sub = int(v_sub). Both are little-endian ints. ref SB little-endian = acce9314368d322c. Let me verify SB is actually correct by the nibble-i=i test which matched.

In dbg4, state with nibble i=i, ref SB byte0=0x01, cvl SB (little-endian reversed) = 01 39 58 7e 24 bc fa d6 -> byte0=0x01 matches. Good SB correct.

So why does SB+MIX combined mismatch? Because in dbg7, the test was: v = int(reversed(state)) where state has nibble i=i. Then vec_to_int(mix(int_to_vec(vec_to_int(sub(int_to_vec(v,64))),64))). The inner vec_to_int(sub(...)) — sub takes int_to_vec(v,64) and returns a vector; vec_to_int gives integer. Then mix takes int_to_vec(that int, 64). Should be fine.

But refSBmix = fb7d91a353df1486 (little-endian) vs cvl 3814ad353a1c82ba. A LOT differs, not just permutation. Hmm but MixColumns alone matches. So the SB output must already differ before MIX? But SB alone matched...

Wait — in dbg7 I reused sub and mix from dbg7's own construction. Let me re-examine: in dbg7, did I construct them correctly? sub=AESlike(4,4,4,"S"); for i in range(16): node=sub.add_subcipher(sbox,[(sub.IN,(i,0))]); sub.add_output([(node,(0,i))]). That maps SB output nibble i = word i. And MIX as before. Then out=vec_to_int(mix(int_to_vec(vec_to_int(sub(int_to_vec(v,64))),64))).

Hold on, maybe the problem is the order: in dbg7 refSBmix, I did k.sub_bytes(ref); k.mix_columns(ref) on the SAME ref object. That's correct. And cvl did sub then mix. They should match if both components correct. But MixColumns alone matched reference mix_columns. And SB alone matched. So composition should match!

Unless... the reference mix_columns operates on the reference byte array with its specific nibble extraction, which IS what I ported. And my MIX in integer form with SB feeding produced different. Let me directly test: take the SB output integer from cvl, apply reference mix_columns (convert to bytes), compare with cvl MIX of same input.

Let me just directly test sub then reference mix on the integer.

Actually, simpler: the mismatch in dbg7 might be because I used vec_to_int(sub(int_to_vec(v,64))) — sub returns a vector, vec_to_int that. That integer, when reinterpreted as int_to_vec(64), gives the SB output. Then MIX. Fine.

Let me carefully test sub-only output integer and feed to BOTH reference mix and cvl mix.

... (code executions)

So reference mix on sbout_bytes gives fb7d91a353df1486, but CVL mix on sbout_int gives 3814ad353a1c82ba. The MIX is deterministic, so the only explanation: sbout_int interpreted as a vector by int_to_vec is NOT the same bit pattern as sbout_bytes!

int_to_vec(sbout_int, 64): it's LSB-first. So vector bit b = (sbout_int >> b) & 1. The integer sbout_int's bit b corresponds to... For CiVerLy, word w = bits 4w..4w+3, byte w//2. So the integer sbout_int maps to bytes little-endian: byte0 = sbout_int & 0xFF, byte1 = (sbout_int>>8)&0xFF, etc. sbout_int = 0xd6fabc247e583901. byte0 = 0x01, byte1=0x39,... matches sb_bytes=[1,57,88,...] = [0x01,0x39,0x58,...]. Yes same.

So int_to_vec(sbout_int,64) should equal the bit vector of sb_bytes. And reference mix on sb_bytes gives fb7d. But CVL mix gives 3814. So the MIX component produces different output than reference mix_columns on the SAME bit pattern. But earlier on nibble-i=i input they matched!

Wait — unless the MIX component is NOT actually producing the reference mix_columns. Let me recheck: on input nibble i=i, reference mix gave fedcba9876543210. Let me verify what reference mix actually does: it applies M to each column. Let me check column 0 of input nibble i=i: col0 = nibbles {0,1,2,3} = {0,1,2,3}. M*[0,1,2,3]^T. M = [[0,1,1,1],[1,0,1,1],[1,1,0,1],[1,1,1,0]]. M*[0,1,2,3] = [1+2+3, 0+2+3, 0+1+3, 0+1+2] = [6,5,4,3] = [0x6,0x5,0x4,0x3]. So new column 0 nibbles = {6,5,4,3} at rows 0,1,2,3. So output state nibble0=6, nibble1=5, nibble2=4, nibble3=3. The output integer little-endian from nibbles [6,5,4,3,2,1,0,...]? Wait input nibble i=i means nibble0=0,nibble1=1,... output nibble0=6,nibble1=5,nibble2=4,nibble3=3,nibble4=2,...? Actually MIX permutes within columns but keeps column positions; column j output goes to column j. So output nibble j (for j in col0) = new values. Output integer: nibble order 0..15 = [6,5,4,3, ...]. Hmm but reference gave fedcba9876543210 little-endian. Let me decode fedcba9876543210: that's the integer; little-endian bytes = [0x10,0x32,0x54,0x76,0x98,0xba,0xdc,0xfe]. byte0=0x10 => nibbles (lo,hi)=(0,1) => nibble0=0? No: byte0=0x10 = (hi=1,lo=0) => low nibble=0, high nibble=1 => nibble0=0, nibble1=1. byte1=0x32 => nibble2=2,nibble3=3. So output nibbles = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15] = unchanged?! That can't be right for MIX.

Wait, that means reference mix_columns on nibble-i=i input returns unchanged?! That's suspicious. Let me recompute. Oh! I think I mislabeled. fedcba9876543210 reversed (little) bytes = [0x10,0x32,...]. Actually int 'fedcba9876543210' as little-endian: the bytes stored little-endian: the int value fedcba9876543210 in hex means byte15=0xfe at MSB. int.to_bytes(8,'little') gives bytes [0x10,0x32,0x54,0x76,0x98,0xba,0xdc,0xfe]. Yes. So nibble0=0. So reference mix on input nibble i=i returns nibble i=i?! That means my reference test in dbg9 was WRONG — I compared cvl MIX which gave fedc too, so they "matched" but actually both might be identity?? No, MIX can't be identity.

Hold on. Let me reconsider. Maybe I made an error constructing the reference input. In dbg9, state=[]; for b: lo=b*2; hi=b*2+1; state.append((hi<<4)|lo). So state[0] = (1<<4)|0 = 0x10 => nibble0=0, nibble1=1. state[1]=0x32 => nibble2=2,nibble3=3. So yes input nibble i = i. reference k.mix_columns(ref) where ref=this state. Output refmix reversed = 'fedcba9876543210'. So output nibble i = i. That means mix_columns is identity on this input??

Let me actually just compute reference mix_columns output for input nibble i=i and print the actual nibbles. Let me do a careful standalone check

... (code executions)

The reference mix_columns is indeed identity on this input (because coldata [0,4,8,12] XOR pattern gives [0,4,8,12]? Let me verify: M*[0,4,8,12]: row0 = 4+8+12 = 24 mod16 = 8. But result shows row0=0?!

Wait result[0]=0 but my computation says 8. Let me recompute: M[0] = [0,1,1,1]. result[0] = sum M[0][c]coldata[c] for c in 0..3 = 00 + 14 + 18 + 1*12 = 4+8+12=24 mod16=8. But printed result=[0,4,8,12]. So M must be... wait the print shows result = coldata for all. That means M[r][c]*coldata[c] summed = coldata[r]. That would be true if M=I. But M is the Midori matrix.

OH WAIT. coldata=[0,4,8,12]. 4=0100, 8=1000, 12=1100 in binary. These are each a single bit in different positions: coldata[1] has bit1 set (0x4), coldata[2] bit3 (0x8), coldata[3] bits 2,3 (0xc). Sum (XOR) of M rows...

result[0] = coldoc[1]^coldata[2]^coldata[3] = 0x4 ^ 0x8 ^ 0xC = 0x4^0x8=0xC, 0xC^0xC=0x0 = 0. So result[0]=0 = coldata[0]. Interesting! result[1] = coldata[0]^coldata[2]^coldata[3] = 0^8^C = 4 = coldata[1]. result[2] = coldata[0]^coldata[1]^coldata[3] = 0^4^C = 8 = coldata[2]. result[3] = coldata[0]^coldata[1]^coldata[2] = 0^4^8 = C = coldata[3]. So indeed M*[0,4,8,12] = [0,4,8,12] because of the specific values! So the input nibble i=i gives coldata that are powers-of-two-combination making it invariant. Lucky. So this input is a bad test for MIX.

So I need a non-degenerate input to test MIX. Let me use input nibble i=i but in a column that isn't all-distinct-powers. Actually ALL columns are like that (col j coldata = [j,j+4,j+8,j+12], each differing by bit shifts). They're all "linearly independent" 4-bit patterns. And M is the all-ones-minus-I which happens to map them to themselves? Let me check col1: coldata=[1,5,9,13] = [0001,0101,1001,1101]. result[0]=5^9^13=0x5^0x9=0xC^0xD=0x1=1. result[0]=1=coldata[0]. Yes again invariant. So for this specific input MIX is identity. Weird but it's a property of input being a basis. Fine.

So MIX IS correct (both ref and cvl give identity on this input, and they matched). The earlier dbg9 "match" was genuine.

So why did dbg12/13 show CVL mix(sbout) != REF mix(sbout)? Let me recompute: REF mix(sbout) = fb7d91a353df1486. CVL mix(sbout) = 3814ad353a1c82ba. These differ. But MIX component supposedly correct. Unless the MIX in dbg12/13 — wait, in dbg12 I built mix and applied to sb_cvl. And in dbg13 built fresh mix. Both gave 3814. And REF (reference function) gave fb7d. So either the reference function and my MIX differ on this input, OR sbout_int is being misinterpreted.

But on the "nibble i=i" input, ref function and MIX agreed. So MIX function matches reference function. Then the discrepancy must be in how sbout_int is interpreted as bits vs how reference interprets bytes.

sbout_int = 0xd6fabc247e583901. Reference mix takes sb_bytes = [0x01,0x39,0x58,0x7e,0x36,0xbc,0xfa,0xd6] (little). Reference treats byte0=0x01 (nibbles 0=1,1=0). MIX computes.

Now CVL: int_to_vec(sbout_int, 64). sbout_int in bits: bit0 = sbout_int & 1 = 1 (since ends in ...901, odd). So word0 bit0 =1. The integer's byte0 (bits0-7) = 0x01. So CVL word0 (bits0-3) = 0x1, word1 = 0x9 (bits4-7 = 0x9? 0x01 has bits4-7=0). Wait 0x01 means bits0-7 = 0000 0001, so byte0 = 0x01, nibble0=1, nibble1=0. Same as reference. So CVL input word0=1,word1=0 matches reference nibbles 0,1. Good.

So both ref and CVL get the same bit pattern. Yet MIX gives different results?? That's impossible unless the reference function and CVL MIX are NOT the same transformation. But they agreed on nibble-i=i input. Contradiction suggests my "nibble-i=i" test was actually NOT testing MIX properly — maybe CVL MIX on that input also gave identity by coincidence AND reference also identity (both 1032... wait reference gave 1032547698badcfe and CVL gave fedcba9876543210 in dbg9!).

Wait dbg9 said: ref MIX (nibble i=i): fedcba9876543210, cvl MIX: fedcba9876543210. They MATCHED. But now I realize reference fedcba9876543210 little-endian bytes = [0x10,0x32,...] which is the ORIGINAL input, meaning reference mix returned UNCHANGED on that input (as we now know). And CVL also returned fedc (unchanged). So both identity on that input — consistent, but doesn't prove correctness.

So the real question: is CVL MIX correct on sbout input? REF says fb7d..., CVL says 3814.... Let me directly compare by feeding the SAME byte array to CVL via the proper integer. Actually let me feed reference the SAME bytes that CVL gets. The CVL input vector = int_to_vec(sbout_int). The integer sbout_int = ref SB output. So reference on those bytes = fb7d. CVL = 3814. So they DISAGREE. So MIX component is wrong, OR my _mix_columns matrix is wrong.

Let me test MIX component on the simple known column. Take col0 coldata that's non-degenerate, e.g. set nibbles 0,4,8,12 to [1,0,0,0] (only bit0 of nibble0=1, rest 0). Apply reference mix_columns and CVL mix, compare.

Actually, simpler: directly test the MIX component on an input where reference is known. Let me just apply reference mix_columns to ALL-ZERO-but-one-nibble inputs and compare to CVL.

Let me test: input where only nibble 0 = 1 (others 0). Reference: col0 coldata = [1,0,0,0]. result = M*[1,0,0,0] = [0,1,1,1] (row0=0, row1=1,row2=1,row3=1). So output nibbles 0,4,8,12 = [0,1,1,1]. So output: nibble0=0? Wait result[0] = M[0]·[1,0,0,0] = 0*1=0. result[1]=M[1]·=1. result[2]=1,result[3]=1. So nibble0=0, nibble4=1,nibble8=1,nibble12=1.

CVL MIX on integer where nibble0=1: int = 0x1 (LSB nibble=1). Let me compute CVL output and compare.

... (code executions)

So the raw LinearLayer MIX (applied to 16 bits = one column) gives output words [0,1,1,1] which matches the reference: nibbles 0,4,8,12 (which are the 4 words of the column in AESlike layout) = [0,1,1,1].

Now, in my AESlike mixcolumns wrapper, I do:

edges=[(mix.IN,(4*j+r,r)) for r in range(4)]
node=mix.add_subcipher(mc,edges)
mix.add_output([(node,(r,4*j+r)) for r in range(4)])
Here mix is AESlike(4,4,4) => 16 words, each 4 bits (64 bits total). The mc is a 16-bit LinearLayer. The edges map mix.IN word (4j+r) -> mc input word r (position r in the 16-bit input). And output mc word r -> mix output word (4j+r).

So for column j, the 4 words {4j, 4j+1, 4j+2, 4j+3} map to mc input words 0,1,2,3. mc output words 0,1,2,3 map back to mix words 4j..4j+3.

But in AESlike word indexing, column j consists of words 4j, 4j+1, 4j+2, 4j+3? Let me check. AESlike word index w: the docstring table shows:

| 0 | 4 | 8 | 12 |
| 1 | 5 | 9 | 13 |
| 2 | 6 | 10| 14 |
| 3 | 7 | 11| 15 |
So word 0 = row0col0, word 1 = row1 col0, word 2 = row2col0, word3=row3col0, word4=row0col1, etc. So column 0 = words {0,1,2,3} (NOT 0,4,8,12!).

But my edges map column j to words {4j,4j+1,4j+2,4j+3}, i.e. row-major chunks. That's WRONG for AESlike. The reference column j should be words {j, j+4, j+8, j+12} (column-major).

So my MixColumns edges are reversed: I used (4*j+r) for the source words, but AESlike column j is {j, j+4, j+8, j+12}.

Wait, but the SKINNY code used exactly (4*j + r, r) and (r, 4*j + r). Let me check SKINNY: in skinny.py mixcolumns they used:

edges = [(mixcolumns.IN, (i+4*j, i)) for i in range(4)]
mixcolumns.add_output([(node, (i, i+4*j)) for i in range(4)])
So source word (4j + i) -> mc input i, and mc output i -> destination word (4j + i). That's the SAME as mine. And SKINNY's state is also AESlike(4 rows? no, skinny s=4? skinny uses AESlike(s, rows=4, cols=4) with s=4 for 64-bit). Wait skinny AESlike(9,2,4) etc. Hmm skinny uses different. But the principle: skinny's mixcolumns with edges (i+4*j, i) treats column j = words {4j,4j+1,4j+2,4j+3}.

But AESlike layout is column-major: word indexing is column-major. So column j = words {j, j+4, j+8, j+12}. The SKINNY code's 4*j + i would be row-major (row i, col j) = word 4j+i which in column-major AESlike is... word 4j+i means col = (4j+i)//4 = j (since i<4), row = (4j+i)%4 = i. So word 4j+i = (row i, col j). And column j spans rows, i.e. words {j, j+4, j+8, j+12}. So word 4j+i is NOT in column j unless i=... wait word 4*j+i: for i=0, word=4j = (row0,col j). for i=1, word=4j+1=(row1,col j). Yes! word 4j+i = row i, col j. So the 4 words {4j,4j+1,4j+2,4j+3} = rows 0,1,2,3 of column j.

I was confused: word index = 4*col + row in SKINNY's convention? Let me recompute. AESlike docstring:

| 0 | 4 | 8 | 12 |
| 1 | 5 | 9 | 13 |
| 2 | 6 | 10| 14 |
| 3 | 7 | 11| 15 |
So word 0=row0col0, word1=row1col0, word2=row2col0, word3=row3col0, word4=row0col1. So word index = col4 + row? word4 = col1,row0 = 14+0=4. Yes! word = col4 + row. So column j words = {j, j+4, j+8, j+12}. And row i of column j = word 4j + i. So the 4 words of column j = {4j, 4j+1, 4j+2, 4j+3}. That matches my edges! Good, so my MixColumns edges ARE correct for AESlike.

So why does MIX give wrong result in dbg17? In dbg17, input nibble0=1 => integer 0x1 => word0 bit0=1 => word0 = nibble0 = 1. Column 0 words = {0,4,8,12}. So only word0=1, words4,8,12=0. mc input words 0,1,2,3 = [1,0,0,0]. mc output = [0,1,1,1] => words 0,4,8,12 = [0,1,1,1]. So output: word0=0, word4=1, word8=1, word12=1.

In dbg17, cvl output = 0000000000001110. Let me decode: 0x1110 = binary ... nibbles: 0x1110 little-endian: bytes=[0x10,0x11,0x00,0x00,0x00,0x00,0x00,0x00]. nibble0 = 0x10 low =0, nibble1=0x10 high=1. So nibble1=1. nibble4=0x11 low=1, nibble5=0x11 high=1. So nibbles 1,4,5... hmm output has 1s at nibble1, nibble4, nibble5. Expected nibbles 4,8,12 =1 (and nibble0=0).

So CVL gave nibble1=1, nibble4=1, nibble5=1, nibble? Let me recompute 0x1110: 1110 in hex = nibbles 0,1,1,1 from LSB: 0x1110 = 0001 0001 0001 0000. From LSB as 4-bit nibbles: nibble0=0, nibble1=1, nibble2=1, nibble3=1. Wait 0x1110 = binary 0001 0001 0001 0000. Nibble (4-bit) LSB order: bits0-3=0000=nibble0=0; bits4-7=0001=nibble1=1; bits8-11=0001=nibble2=1; bits12-15=0001=nibble3=1. So nibbles 1,2,3 =1. But reference gave nibbles 4,8,12=1.

So CVL output = nibbles {1,2,3} active, reference = {4,8,12} active. These are different positions. So the AESlike word mapping of "column" inside the MixColumns is rotated/misaligned.

The issue: my MixColumns maps the 4 words {4j+r} to mc, but the mc output should map back to the SAME 4 words {4j+r}. In AESlike, word 4j+r = column j, row r. So output word 4j+r = row r of column j. But reference: result[r] is the new value for row r of column j = nibble col+j... wait reference sets set_nib(s, col+4r, result[r]). Here col+4r: for column col (j) and row r: reference uses index col + 4r. In the reference, nibble index = col + 4r. And AESlike word index = 4*col + r. These DIFFER when r>0!

Wait reference: idx = col + r * cols where cols = n/16. For n=64, cols=4. So idx = col + 4r. So reference row r of column col is at nibble index col + 4r. In AESlike, word index = 4*col + r.

So reference's "column j, row r" nibble index = j + 4r. AESlike's word for column j, row r = 4j + r. These are transposed!

The reference paper arranges the state as: rows are the 4 rows, columns are n/16 columns. nibble index = col + rowcols (row-major within... actually col + rcols means it's indexed by (col, row) with row being the major? index = col + colsrow). So nibble index = col + colsrow.

AESlike indexes word = colrows + row = col4 + row (since rows=4).

So reference nibble(col,row) = col + 4row. AESlike word(col,row) = 4col + row. These are different unless we transpose.

So the state layout of Blink (reference) is TRANSPOSED relative to AESlike's column-major layout! In the reference, consecutive nibbles 0,1,2,3 are col0row0, col1row0, col2row0, col3row0 (i.e., a ROW, not a column). Because nibble0=col0row0, nibble1=col1row0, nibble2=col2row0, nibble3=col3row0. So nibble index increments along COLUMNS within a row. That's row-major storage of an (rows x cols) matrix.

AESlike stores column-major: word0=col0row0, word1=col0row1, word2=col0row2,... So word1 = col0row1 (next row same column), whereas reference nibble1 = col1row0 (next column same row).

So the reference is row-major and AESlike is column-major. This is exactly the "transpose" issue the README warns about!

So to use AESlike correctly, I need to either (a) transpose the state so that Blink's columns align with AESlike columns, or (b) avoid AESlike and use a plain WordSBoxCipher with explicit MixColumns handling.

Hmm. The reference's MixColumns operates on "columns" defined as j + 4*r (which in the reference layout is a column of the row-major matrix = actually a column when viewed as rows×cols with row-major storage). To map to AESlike, I should transpose the state: define the AESlike word index = reference nibble index. Then AESlike's "columns" would actually be Blink's rows. That breaks the MixColumns alignment.

Simplest correct approach: Don't use AESlike's built-in column assumption. Instead build the cipher as a WordSBoxCipher (or even just Cipher) with the S-box as word-subcipher, MixColumns as a single LinearLayer over the whole state (computing M over all columns in reference order), and PermuteLayer for P. This avoids the AESlike column indexing confusion entirely.

But the README recommends AESlike for wordwise MILP. However correctness is paramount. Let me reconsider: I can use AESlike but apply a transpose so that reference columns map to AESlike columns.

Actually, the cleanest: build the MixColumns as a full 16x16 (or 32x32 for 128) LinearLayer that exactly implements the reference's column-wise M (with the reference's column definition: column j nibbles = {j, j+cols, j+2cols, j+3cols} = {j, j+4, j+8, j+12}).

In the AESlike word layout, the reference nibble index = AESlike word index? If I just treat the AESlike word index w as the reference nibble index directly (no transpose), then the reference's column j = {j, j+4, j+8, j+12} = AESlike words {j, j+4, j+8, j+12}. But in AESlike, those words are rows of column j IF AESlike used row-major. AESlike uses column-major, so words {j, j+4, j+8, j+12} = column j of AESlike (good!). And reference's column j = {j, j+4, j+8, j+12} = exactly AESlike column j. So if I define the AESlike word index to EQUAL the reference nibble index, then MixColumns column j = AESlike column j.

But the problem arises in how AESlike assigns (row,col) to word index. In AESlike, word w has (row, col) = (w % rows, w // rows)? word0=(0,0), word1=(1,0), word4=(0,1). So word = colrows + row = 4col + row. That's column-major. Reference nibble index = col + 4*row (row-major).

So AESlike word w corresponds to reference nibble index: word w=4col+row corresponds to reference col4+row. So reference nibble index for AESlike(word w) = w (if we set them equal)? No: AESlike word w means (col,row)=(w//4, w%4). Reference nibble at that same physical position... The reference's nibble index for matrix-position (row, col) is col + 4row. AESlike's word index for (row,col) is 4col+row. These differ.

I think the real fix: I should define my own consistent mapping and just build MixColumns to match the reference exactly, ignoring AESlike's column semantics. The easiest robust implementation:

Use AESlike but recognize that what AESlike calls a "column" (words 4j..4j+3) is the reference's ROW j. So if I transpose the conceptual matrix, everything works. Actually, the MixColumns in AESlike operates on AESlike-columns = words {4j..4j+3}. The reference MixColumns operates on reference-columns = nibbles {j, j+4, j+8, j+12}.

To make AESlike's MixColumns (applied to words {4j..4j+3}) equal the reference MixColumns (applied to {j,j+4,j+8,j+12}), I need the AESlike word w to correspond to reference nibble (w//4 + 4*(w%4))? i.e., transpose.

This is getting complicated. Given the time, the SAFEST approach to guarantee correctness is to NOT rely on AESlike's column semantics, and instead build the MixColumns as a single LinearLayer over the FULL state that directly implements the reference operation in the reference nibble-index ordering. Then the S-box is applied per nibble (word), and the permutation P is a PermuteLayer over nibbles. Use a plain WordSBoxCipher (which still supports wordwise MILP) with wordsize=4.

Let me verify WordSBoxCipher supports MILP and the components. WordSBoxCipher = WordBasedCipher + SBoxCipher. It allows SBox_CVL, LinearLayer_CVL, PermuteLayer_CVL, RoundkeyXOR_CVL. MixColumns as a single LinearLayer (full state, 16x16 or 32x32 binary matrix) is a LinearLayer_CVL — allowed.

So I'll build:

base = WordSBoxCipher(4, state_nibbles, state_nibbles, name) (wordsize=4, state_nibbles words)
subcells: WordSBoxCipher applying SBox to each of state_nibbles words.
mixcolumns: a full-state LinearLayer_CVL whose binary matrix directly implements reference MixColumns (in reference nibble-index order). For 64-bit: 16 nibbles => 64x64 matrix. Build by, for each output nibble o, set bits from input nibbles in its column. The reference: output nibble (col+4r) = XOR over c of M[r][c] * input nibble (col+4c). In bit terms, each output bit b (nibble o, bit within nibble) = same combination of input bits in corresponding positions across the column. Since M acts identically on each of the 4 bits of the nibble, the 64x64 matrix = block matrix with 4x4 blocks each M scaled by identity? Actually since each nibble is 4 bits and M mixes nibbles (XOR of full nibbles), the operation on bits is: bit k of output nibble (col+4r) = XOR over c of M[r][c] * (bit k of input nibble (col+4c)). So it's M⊗I_4 but with the column indexing in REFERENCE order (nibble index = col+4r). The full 64x64 matrix: output bit position = 4(col+4*r) + k...
Let me just construct it directly: for reference, define function f mapping (col,row).. Simpler: build a 16x16 nibble-mixing matrix N where N[o][i] = M[r][c] if o = col+4r and i = col+4c for the SAME col, else 0. Then the 64x64 binary matrix = N ⊗ I_4 (Kronecker). And the LinearLayer applied to the bit-vector where bit position p = 4nibble + bitinNibble. Since reference uses nibble index directly and within nibble the bit order is consistent (low bit = bit0), the Kronecker product N⊗I_4 with the standard bit ordering p=4nibble+bit gives exactly the reference MixColumns.

Wait, but I must double check bit-in-nibble ordering matches. Reference: nibble i, bit extraction nibble = (state[byte_index] >> 4) & 0xF if high_nibble else state[byte_index] & 0xF. So nibble value is just the 4-bit value, XORed with M as a whole nibble. So within a nibble, all 4 bits are XORed together (it's nibble XOR). In the bit-vector of the whole state, nibble i occupies bits 4i..4i+3. The reference computes result nibble = XOR of input nibbles => result bit k (of nibble o) = XOR of input bit k of the contributing nibbles. So yes, the operation is N⊗I_4 where N is the 16x16 nibble-mixing (over the nibble index space). And bit position p=4*o+bit.

Now I need to make sure ciVerLy's integer/bit ordering matches: word w (nibble w) occupies bits 4w..4w+3 (LSB-first within word, word 0 = LSB). The reference nibble i is also at byte i//2, low/high, and in the integer (LSB-first byte) the nibble i is at bits 4i..4i+3. So they match: nibble w = bits 4w..4w+3.

So the full-state LinearLayer with matrix N⊗I_4 (nibble index = word index) exactly implements reference MixColumns. And I apply it directly to the WordSBoxCipher state. No AESlike column confusion.

Let me build N (16x16 for 64-bit, 32x32 for 128-bit). For 128-bit, cols=8. column j = {j, j+8, j+16, j+24} (since n/16=8). The 4 rows indexed r=0..3: nibble index = j + rcols = j + r8. M mixes the 4 nibbles of that column.

So N is block-diagonal with cols blocks, each block being the 4x4 matrix M (placed at positions (j+rcols, j+ccols) = (j+8r, j+8c)).

Let me construct N as a matrix over GF(2) of size (state_nibbles x state_nibbles), and then full = N ⊗ I_4 (Kronecker), implemented as block_matrix with 4x4 identity/O blocks per (r,c) of each column. Actually simpler: build the 64x64 (or 128x128) directly via block_matrix: for output row-group (nibble o) and input row-group (nibble i), if N[o][i] then I_4 else O_4. The block index in the full matrix is (o, i) for the 4x4 blocks. So full matrix blocks B[o][i] = I_4 if N[o][i] else 0. Build via block_matrix(GF(2), [[I4 if N[o][i] else O4 for i in range(Nn)] for o in range(Nn)], subdivide=False) where Nn=state_nibbles.

This is exactly _mix_columns but instead of per-column wrapping in AESlike, build the full matrix. Let me rewrite _mix_columns to return the full LinearLayer.

Actually wait — even simpler, I could keep AESlike but just build mixcolumns as the FULL-state LinearLayer and add it directly. Let me abandon AESlike entirely and use WordSBoxCipher. That removes all column-index confusion. WordSBoxCipher supports wordwise MILP (per README), so I still get the modeling benefit.

Let me verify WordSBoxCipher allows LinearLayer_CVL. The README says WordSBoxCipher supports SBox + LinearLayers. And present.py uses WordSBoxCipher with SBox and PermuteLayer (not LinearLayer) but SKINNY uses AESlike with LinearLayer for MixColumns. Does WordSBoxCipher allow LinearLayer_CVL? WordSBoxCipher inherits SBoxCipher which checks allowed component types. Let me check sboxcipher.py for what's

Conclusion of the bug hunt:

I found the bug: Blink's reference stores the state row-major (nibble index = col + cols·row), while AESlike uses column-major (word = cols·row + col). This is the transpose issue. I'll switch to WordSBoxCipher with a full-state MixColumns LinearLayer built directly in reference nibble order. Let me check SBoxCipher allowed components first.

... (code exectutions)

M[16][0]=1, so output bit 16 should be set when input bit 0 is set. But eval gives 0. So binary_matrix * x is not giving expected. Wait — M[16][0]=1 means row 16, col 0 = 1. eval = M * x, output[16] = sum_j M[16][j]*x[j] = M[16][0]x[0] + ... = 11 = 1 (since x[0]=1). So output[16] should be 1. But it's 0!

Unless x[0] is not 1. int_to_vec(0x1,64): bit0. Let me check what M*x gives. Maybe the issue is that binary_matrix * x where x is the vector and M is 64x64... output bit 16 = row 16 dot x. M[16][0]=1, x[0]=1 => 1.

But maybe there are OTHER 1s in row 16 that cancel? No, GF(2) sum, with x having only x[0]=1, output[16] = M[16][0]*1 = 1. So it must be 1. Unless M[16][0] printed as 1 but it's actually... let me print the whole row 16.

Actually wait, maybe int_to_vec(0x1,64) gives bit 63 = 1 not bit 0? Let me check util: int_to_vec: vector(GF(2), size, ZZ(input_num).digits(2, padto=size)[::-1]). digits(2, padto=size) returns digits least-significant first. So digits[0]=1 (LSB). Then [::-1] reverses => index 0 = most significant. So vector[0] = MSB = 0, vector[63] = LSB = 1. So the vector is stored MSB-first! So x[0]=MSB, x[63]=LSB=bit0 of the number. So input "bit 0" (LSB) is at vector index 63.

But eval does binary_matrix * x. The matrix M is defined such that output bit position p (in this vector indexing) = sum M[p][j] x[j]. The vector indexing: index 0 = MSB, index 63 = LSB. So "bit 0 of the integer" is at index 63. With int 0x1, only index 63 =1. So output[16] = M[16][63]*x[63] = M[16][63].

So the matrix is defined in "vector index" space where index 0 = MSB. But my N matrix assumed index = nibble*4+bit with index 0 = LSB (nibble0 bit0). The mismatch! The vector convention: index 0 corresponds to the MSB of the integer, not LSB.

So I need to map carefully. The key insight: vec_to_int reverses. int_to_vec(0x1) => vector with 1 at position 63. So position 63 = LSB = my "bit 0". In general, integer bit b (value 2^b) is at vector index (size-1-b).

So my matrix construction in terms of "nibble/bit" needs to account that the vector index = (total_bits - 1 - (4nibble+bit)). Equivalently, the matrix I built works in "bit index = 4nibble+bit (LSB=0)" space, but CiVerly uses "vector index = size-1-bit_index". Since it's just a reversal of all bit positions, applying a bit-reversal. But MixColumns is symmetric enough? No—it's a permutation of nibbles + XOR, not symmetric under reversal.

The cleanest fix: when I build the bit matrix, map nibble o, bit k to vector position p = (total_bits - 1 - (4*o + k)) for OUTPUT, and similarly input. Actually simpler: the whole cipher vector is MSB-first. So I should define everything in MSB-first bit positions.

Let me reconsider: It might be far simpler to build all components in the "natural" LSB-first nibble space and then reverse the bit order at input/output. But that complicates modeling.

Alternative: Just compute the matrix in the correct MSB-first indexing. For output nibble o, bit k: msb-first position = 63 - (4o + k). For input nibble i, bit c: msb-first position = 63 - (4i + c). So full matrix entry at (row=63-(4o+k), col=63-(4i+c)) = I4-block (N[o][i] and k==c).

Equivalently, the matrix in msb-first space = reverse both row and column order of the LSB-first matrix. Reversing both row and column order of a matrix is a similarity transform (conjugation by reversal permutation), which for a linear layer is fine.

Let me just build B in msb-first: for each o,i,k,c with N[o][i] and k==c: set M[63-(4o+k)][63-(4i+c)] = 1.

For nibble0=1 (int 0x1): input vector has 1 at msb-index 63. Output: o=4 (nibble4), k=0 => msb-index 63-(16+0)=47. M[47][63] should be 1. Let me verify: o=4,r=1,col=0; contributing i=0 (c=0) with M[1][0]=1, k=0,c=0. So set M[63-(16+0)][63-(0)] = M[47][63]=1. input index 63 => output bit 47 set => integer bit (63-47)=16 => 2^16. matches ref.

So I need to build the matrix with msb-first indexing. Let me update _mix_columns accordingly.

Actually, even simpler and less error-prone: build the LSB-first matrix L (as I did), then convert to msb-first by reversing both dimensions: M_msb = L.reversed rows & cols = L[::-1, ::-1] in terms of both. In Sage, I can do block_matrix then reverse. Or build a new matrix B where B[a][b] = L[63-a][63-b].

Let me just construct in msb-first directly in the loop. I'll modify _mix_columns to place entries at msb-first indices.

Let me rewrite _mix_columns building a 64x64 (or 128) zero GF(2) matrix and set entries.

Actually for 128-bit it's 128x128. total_bits = state_nibbles*4.

Let me write it explicitly with a matrix constructor

... (code executions)

cd /Users/Uni/Documents/GitHub/CiVerLy-forked-new && cat > /tmp/dbg26.py << 'EOF'
from civerly.cipher_implementations.blink import _mix_columns, M_MATRIX
from civerly.component import LinearLayer_CVL
from civerly.util import int_to_vec, vec_to_int

mc=_mix_columns(8)
# nibble0=1 => int 0x1 => vector index 63 =1.
# Let's find which output bits are set.
out=vec_to_int(mc(int_to_vec(0x1,64)))
print("cvl out:", f'{out:016x}')
# decode cvl output nibbles
for n in range(16):
    print(f"  nibble {n} = {(out>>(4*n))&0xF}")
# expected (ref): nibbles 4,8,12 = 1 (bits 16,32,48). 
EOF
sage -python /tmp/dbg26.py 2>&1 | tail -25
cvl out: 0000000001010100
  nibble 0 = 0
  nibble 1 = 0
  nibble 2 = 1
  nibble 3 = 0
  nibble 4 = 1
  nibble 5 = 0
  nibble 6 = 1
  nibble 7 = 0
  nibble 8 = 0
  nibble 9 = 0
  nibble 10 = 0
  nibble 11 = 0
  nibble 12 = 0
  nibble 13 = 0
  nibble 14 = 0
  nibble 15 = 0
cd /Users/Uni/Documents/GitHub/CiVerLy-forked-new && cat > /tmp/dbg27.py << 'EOF'
from civerly.cipher_implementations.blink import _mix_columns, M_MATRIX
from sage.rings.finite_rings.finite_field_constructor import GF

mc=_mix_columns(8)
M=mc.binary_matrix
# input nibble0=1: vector index 63=1.
# output should be at index 63-(16)=47 for o=4,k=0? Let's check M[47][63].
print("M[47][63]=", M[47][63])
print("M[31][63]=", M[31][63], " (o=8,k=0 -> 63-32=31)")
print("M[15][63]=", M[15][63], " (o=12,k=0 -> 63-48=15)")
# Expected ref: nibbles 4,8,12 => bits at integer positions 16,32,48 => vector indices 63-16=47, 63-32=31, 63-48=15.
# So M[47][63], M[31][63], M[15][63] should all be 1.
# But cvl gave nibbles 2,4,6 set => integer bits 8,16,24 => vector idx 55,47,39.
# Let's check what got set:
for idx in [15,31,39,47,55]:
    print(f"M[{idx}][63] =", M[idx][63])
EOF
sage -python /tmp/dbg27.py 2>&1 | tail
M[47][63]= 1
M[31][63]= 0  (o=8,k=0 -> 63-32=31)
M[15][63]= 0  (o=12,k=0 -> 63-48=15)
M[15][63] = 0
M[31][63] = 0
M[39][63] = 1
M[47][63] = 1
M[55][63] = 1
So M[47][63]=1 (o=4 bit0), M[39][63]=1 (o=... 63-39=24 => o=6, bit0), M[55][63]=1 (o=... 63-55=8 => o=2,bit0). So output nibbles 2,4,6 set instead of 4,8,12.

So my N matrix mapping is wrong. The reference: output nibble o where o = col + cols*r. For col=0 (the column containing nibble0), r=0,1,2,3 => o = 0, 4, 8, 12. But my matrix set output at o=2,4,6? The issue is M_MATRIX indexing vs reference.

Wait, M_MATRIX[r][c]: in reference, result[r] = XOR_c M[r][c]coldata[c]. coldata[c] = nibble at (col + colsc) = input nibble i = col+colsc. So output row r => o = col + colsr. For col=0: o = 0,4,8,12. M[1][0]=1 (since M[1]=[1,0,1,1], M[1][0]=1). So output o=4 from c=0 (input nibble0). Good, so output nibble4 should be set. M[2][0]=1 => o=8 set. M[3][0]=1 => o=12 set. So outputs o=4,8,12.

But my code produced o=2,4,6. So the N[o][i] assignment is transposed: I set N[o][i]=M_MATRIX[r][c] with o=col+colsr, i=col+colsc. That's correct for o. But then in the matrix I set entries at row=63-(4*o+b). For o=4 => row 47. Good. But the ACTUAL output shows o=2,4,6. So o=2,6 come from somewhere.

o=2 => col+4r=2 => col=2,r=0. o=6=>col=2,r=1. These are column 2, not column 0! So my N matrix has N[2][0]=1?? Let me check: for col=2, r=0: o=2, c=0: i=col+cols*c = 2+0=2. N[2][2]=M[0][0]=0. Hmm. For col=2,r=1: o=6, c=0: i=2, N[6][2]=M[1][0]=1. So N[6][2]=1 (output o=6 from input nibble2). That's correct for reference: column 2's row1 gets input column2 row0. But our input only had nibble0 set, so N[6][2] doesn't affect (input nibble2=0).

So why does output nibble2 get set? N[2][i] for some i with input set. Input nibble0 set => i=0. N[2][0] = M_MATRIX[r][c] where o=2=col+4r => col=2,r=0; i=0=col'+4c => col'=0,c=0. So N[2][0]=M[0][0]=0. So output nibble2 (o=2) should NOT be set from input nibble0. But cvl shows nibble2 set. Contradiction.

Unless my decoding of cvl output is off by the same MSB/LSB confusion. cvl out = 0000000001010100. Let me decode carefully as integer. 0x0000000001010100 = binary: 0000 0000 0000 0000 0000 0000 0001 0101 0100. Nibbles from MSB(15) to LSB(0): nibble15=0,nib14=0,nib13=0,nib12=0,nib11=0,nib10=0,nib9=0,nib8=0,nib7=0,nib6=1,nib5=0,nib4=1,nib3=0,nib2=1,nib1=0,nib0=0. So nibbles set: 2,4,6. Same as before.

So output has nibbles 2,4,6. But reference has 4,8,12. So my matrix puts the column-0 output at nibbles 2,4,6 instead of 4,8,12. That means my o for column 0 is 2,4,6 — i.e., the (col,r) for o: I have o = col + cols*r with cols=2?? cols=8//4=2!

BUG: cols = state_bytes // 4 = 8//4 = 2. But the reference uses cols = n/16 = 64/16 = 4! state_bytes=8, n=64, n/16=4, but state_bytes//4 = 2. Wrong! The columns in the reference = n/16 = state_bytes/2. Because state_nibbles = state_bytes2, and cols = state_nibbles/4 = state_bytes2/4 = state_bytes/2. So cols = state_bytes // 2, not state_bytes // 4!

Let me fix: cols = state_bytes // 2 (= n/16). state_nibbles = state_bytes*2. cols = state_nibbles // 4 = state_bytes // 2. Yes.

So _mix_columns should use cols = state_bytes // 2. Let me fix.

... (code executions)

cd /Users/Uni/Documents/GitHub/CiVerLy-forked-new && cat > /tmp/dbg28.py << 'EOF'
# Test the permutation direction carefully.
import importlib.util
spec = importlib.util.spec_from_file_location("blk", "documentation/blink.py")
blk = importlib.util.module_from_spec(spec); spec.loader.exec_module(blk)
from civerly.cipher_implementations.blink import SBOX, _mix_columns, _inverse_perm, _bytes_to_int
from civerly.util import int_to_vec, vec_to_int
from civerly.component import SBox_CVL, PermuteLayer_CVL, RoundkeyXOR_CVL
from civerly.wordsboxcipher import WordSBoxCipher

k=blk.Blink_64a
# Test permutation alone on nibble i=i state, then compare steps.
state=[]
for b in range(8):
    lo=b*2; hi=b*2+1
    state.append((hi<<4)|lo)
ref=copy.deepcopy(state) if False else None
import copy
ref=copy.deepcopy(state)
# reference: sub, mix, AK(rc0), P
k.sub_bytes(ref); k.mix_columns(ref); k.add_round_key(ref, k.round_const[0]); k.permutation(ref)
ref_int=int(''.join(f'{x:02x}' for x in reversed(ref)),16)

# CiVerly step by step
sbox=SBox_CVL(SBOX); sub=WordSBoxCipher(4,16,16,"S")
for i in range(16):
    node=sub.add_subcipher(sbox,[(sub.IN,(i,0))]); sub.add_output([(node,(0,i))])
mc=_mix_columns(8); mix=WordSBoxCipher(4,16,16,"M")
node=mix.add_subcipher(mc,[(mix.IN,(i,i)) for i in range(16)]); mix.add_output([(node,(i,i)) for i in range(16)])
perm=PermuteLayer_CVL(_inverse_perm(k.pbox), word_coarseness=4, name="P")
rk=RoundkeyXOR_CVL(64, _bytes_to_int(k.round_const[0]), name="RK")
# sub+const already matched? test sub alone
v=int(''.join(f'{x:02x}' for x in reversed(state)),16)
s_out=vec_to_int(sub(int_to_vec(v,64)))
# reference sub alone
rs=copy.deepcopy(state); k.sub_bytes(rs); rs_int=int(''.join(f'{x:02x}' for x in reversed(rs)),16)
print("sub: ref",f'{rs_int:016x}',"cvl",f'{s_out:016x}', rs_int==s_out)
# sub+mix
sm=vec_to_int(mix(int_to_vec(s_out,64)))
rm=copy.deepcopy(rs); k.mix_columns(rm); rm_int=int(''.join(f'{x:02x}' for x in reversed(rm)),16)
print("sub+mix: ref",f'{rm_int:016x}',"cvl",f'{sm:016x}', rm_int==sm)
# sub+mix+const
smc=vec_to_int(rk(int_to_vec(sm,64)))
print("sub+mix+const(ref rc0): ref", f'{ref_int:016x}')
rc0=_bytes_to_int(k.round_const[0])
rmc=copy.deepcopy(rm); k.add_round_key(rmc, k.round_const[0]); rmc_int=int(''.join(f'{x:02x}' for x in reversed(rmc)),16)
print("  ref after AK:",f'{rmc_int:016x}', "cvl",f'{smc:016x}', rmc_int==smc)
# now permutation
refp=copy.deepcopy(rmc); k.permutation(refp); refp_int=int(''.join(f'{x:02x}' for x in reversed(refp)),16)
cvlp=vec_to_int(perm(int_to_vec(smc,64)))
print("after P: ref",f'{refp_int:016x}',"cvl",f'{cvlp:016x}', refp_int==cvlp)
EOF
sage -python /tmp/dbg28.py 2>&1 | tail -8
sub: ref d6fabc247e583901 cvl d6fabc247e583901 True
sub+mix: ref fb7d91a353df1486 cvl fb7d91a353df1486 True
sub+mix+const(ref rc0): ref d856e8476f0cb1a2
  ref after AK: e8641b8d50af67c2 cvl e8641b8d50af67c2 True
after P: ref d856e8476f0cb1a2 cvl ebfa881766024dc5 False
cd /Users/Uni/Documents/GitHub/CiVerLy-forked-new && cat > /tmp/dbg29.py << 'EOF'
# Compare permutation: reference on input nibble i=i state, vs CiVerly.
import importlib.util, copy
spec = importlib.util.spec_from_file_location("blk", "documentation/blink.py")
blk = importlib.util.module_from_spec(spec); spec.loader.exec_module(blk)
from civerly.cipher_implementations.blink import _inverse_perm
from civerly.util import int_to_vec, vec_to_int
from civerly.component import PermuteLayer_CVL

k=blk.Blink_64a
state=[]
for b in range(8):
    lo=b*2; hi=b*2+1
    state.append((hi<<4)|lo)
ref=copy.deepcopy(state); k.permutation(ref)
ref_int=int(''.join(f'{x:02x}' for x in reversed(ref)),16)
v=int(''.join(f'{x:02x}' for x in reversed(state)),16)
perm=PermuteLayer_CVL(_inverse_perm(k.pbox), word_coarseness=4, name="P")
cvl=vec_to_int(perm(int_to_vec(v,64)))
print("P ref:", f'{ref_int:016x}')
print("P cvl:", f'{cvl:016x}')
# decode ref new nibble order
refn=copy.deepcopy(state); k.permutation(refn)
def nib(s,i):
    b=i//2; hi=(i%2==1); return (s[b]>>4)&0xF if hi else s[b]&0xF
print("ref new nibbles:", [nib(refn,i) for i in range(16)])
# ciVerly: perm semantics output[perm[i]]=input[i]. _inverse_perm(pbox).
inv=_inverse_perm(k.pbox)
print("cvl out nibble j = in[inv[j]]:", [inv[j] for j in range(16)])
EOF
sage -python /tmp/dbg29.py 2>&1 | tail
P ref: 8e73f9c2d461ab50
P cvl: fa45e9b2d360c817
ref new nibbles: [0, 5, 11, 10, 1, 6, 4, 13, 2, 12, 9, 15, 3, 7, 14, 8]
cvl out nibble j = in[inv[j]]: [0, 4, 8, 12, 6, 1, 5, 13, 15, 10, 3, 2, 9, 7, 14, 11]
Reference new nibbles after P: [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8]. This is exactly pbox (output[i] = input[pbox[i]] with input nibble j=j). So output nibble i = input nibble pbox[i]. For input nibble i=i, output nibble i = pbox[i]. So ref new nibbles = pbox. Correct.

CiVerly with _inverse_perm(pbox): output[j] = input[inv[j]] where inv=_inverse_perm(pbox). So output[j] = input at inv[j]. For input nibble j=j, output[j] = inv[j]. So cvl new nibbles = inv = [0,4,8,12,6,1,5,...].

But we WANT output[j] = pbox[j] (to match reference). So we need output[j]=pbox[j], i.e., inv[j] = pbox[j]?? No. We need output[j] = input[pbox[j]] (reference). In CiVerly, output[j] = input[inv[j]] (with our perm argument = inv). To get output[j]=input[pbox[j]], we need inv[j] = pbox[j] for all j, i.e., inv = pbox, i.e., perm argument should be pbox, NOT inverse!

So I had it backwards. Let me re-derive. CiVerly PermuteLayer with perm argument P has semantics: output[P[i]] = input[i] (from earlier analysis with the example). Wait earlier I derived output[perm[i]] = input[i]. Let me re-verify with the docstring example: PermuteLayer_CVL([1,3,2,0]) on 0x9=1001 (bits (1,0,0,1)) gave 12=1100. Output = (out0,out1,out2,out3)=(1,1,0,0). With semantics output[perm[i]]=input[i]: out[perm[0]=1]=in[0]=1 out[perm[1]=3]=in[1]=0 out[perm[2]=2]=in[2]=0 out[perm[3]=0]=in[3]=1 => out=(out0,out1,out2,out3)=(1,1,0,0). Matches 12. So semantics: output[perm[i]] = input[i]. So output position perm[i] = input position i. Equivalently, output[j] = input[ inv_pbox[j] ] where inv_pbox[perm[i]]=i.

We want output[j] = input[pbox[j]] (reference: output[j]=input[pbox[j]]). So we need inv_pbox[j] = pbox[j] => our perm argument's inverse equals pbox => perm = inverse(pbox). Wait: output[j] = input[perm_inverse[j]] where perm_inverse[perm[i]]=i. We want output[j]=input[pbox[j]]. So perm_inverse[j] = pbox[j] => perm_inverse = pbox => perm = inverse(pbox). That's what I used! But it gave wrong.

Hold on, let me recompute with perm=inverse(pbox) on the docstring example to be sure of semantics. Actually the docstring example is the ground truth: PermuteLayer_CVL([1,3,2,0]). Here perm=[1,3,2,0]. By semantics output[perm[i]]=input[i], output = input shuffled so that position perm[i] gets input i. We computed output=(1,1,0,0) and result=12. Confirmed.

Now for Blink, pbox=[0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8]. Reference output[j]=input[pbox[j]]. We want CiVerly output[j]=input[pbox[j]]. CiVerly: output[j] = input[pinv[j]] where pinv = inv(perm_arg) i.e. perm_arg[pinv[j]]=j. So we need pinv[j]=pbox[j] => perm_arg = inv(pbox).

But dbg29 with perm_arg=_inverse_perm(pbox) gave cvl new nibbles = [0,4,8,12,...] = inv(pbox), meaning output[j] = input[inv(pbox)[j]] = input[inv_pbox[j]]. That contradicts my semantics derivation!

Wait, in dbg29 I printed "cvl out nibble j = in[inv[j]]" where inv=_inverse_perm(k.pbox). And it printed [0,4,8,12,6,1,5,13,15,10,3,2,9,7,14,11]. Let me verify: inv[_inverse_perm(pbox)] = pbox? No! _inverse_perm returns the inverse of pbox. So inv = pbox^{-1}. Then "cvl out nibble j = in[inv[j]]" = in[pbox^{-1}[j]]. But that's wrong: the CiVerly output[j] should be in[pinv[j]] where pinv = inverse of the perm_argument. perm_arg = _inverse_perm(pbox) = pbox^{-1}. So pinv = inverse(perm_arg) = pbox. So output[j] = in[pbox[j]].

But the printed "cvl out nibble j = in[inv[j]]" used inv = pbox^{-1} instead of pbox. That print statement was WRONG (I used inv incorrectly). The actual cvl output nibbles should be pbox = [0,5,11,10,...]. Let me just directly decode the cvl output integer to nibbles to see what it actually is.

cvl = fa45e9b2d360c817. Let me decode nibbles LSB-first: The integer's nibble j (LSB) = (cvl >> 4j) & 0xF. fa45e9b2d360c817 hex digits from LSB: 7,1,8,c,0,6,3,d,2,9,b,e,5,4,a,f. So nibbles (LSB order, j=0..15): [7,1,8,0xc,0,6,3,0xd,2,9,0xb,0xe,5,4,0xa,0xf]. That's [7,1,8,12,0,6,3,13,2,9,11,14,5,4,10,15].

Reference new nibbles (output after P with input i=i) = pbox = [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8]. These are different! So cvl does NOT match reference. cvl gave [7,1,8,12,0,6,3,13,2,9,11,14,5,4,10,15].

So with perm_arg = pbox^{-1}, cvl output nibble order = [7,1,8,12,0,6,3,13,2,9,11,14,5,4,10,15]. We want [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8].

The reference: output[j] = input[pbox[j]]. For input j=j. So output nibble j = pbox[j]. The cvl with perm_arg gives output[j]=in[pinv[j]], pinv=inverse(perm_arg).

We want output[j] = pbox[j]. So in[pinv[j]] should equal in[pbox[j]] => pinv[j]=pbox[j] => perm_arg = inverse(pbox). That's what we used. But the result is wrong. So either the CiVerly semantics is the opposite: output[i] = input[perm[i]] (not output[perm[i]]=input[i]).

Let me re-examine the docstring example with the OTHER semantics: output[i] = input[perm[i]]. perm=[1,3,2,0]. output[0]=input[1]=0, output[1]=input[3]=0, output[2]=input[2]=0, output[3]=input[0]=1 => output=(0,0,0,1)=1. But docstring says result=12. So this semantics is WRONG. The first semantics (output[perm[i]]=input[i]) gave 12. Confirmed first semantics.

So semantics is output[perm[i]]=input[i]. With perm_arg=pbox^{-1}: output[pbox^{-1}[i]] = input[i]. So output[j] = input[i] where pbox^{-1}[i]=j, i.e., i = pbox[j]. So output[j] = input[pbox[j]]. That's exactly the reference! So cvl SHOULD give output[j]=input[pbox[j]], i.e., output nibbles = pbox = [0,5,11,...]. But the actual computed output was [7,1,8,12,...].

So my manual decoding of the cvl integer must be wrong, OR the perm implementation differs. Let me directly compute: with input nibble i=i, the EXPECTED cvl output nibble j = input[pbox[j]] = pbox[j]. So expected output integer nibbles (LSB order j=0..15) = [pbox[0],pbox[1],...,pbox[15]] = [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8]. That integer: compose from LSB: nibble0=0,nibble1=5,nibble2=11,... => bytes little: byte0 = (nibble1<<4)|nibble0 = (5<<4)|0 = 0x50. This is reference's ref_int = 8e73f9c2d461ab50. Let me decode 8e73f9c2d461ab50: bytes little = [0x50,0xab,0x61,0xd4,0xc2,0xf9,0x73,0x8e]. byte0=0x50 => nibbles (lo,hi)=(0,5)=nibble0=0,nibble1=5. Matches pbox[0]=0,pbox[1]=5.

So reference ref_int=8e73f9c2d461ab50 is the CORRECT expected output. But cvl gave fa45e9b2d360c817. So cvl is WRONG.

So PermuteLayer with perm_arg=pbox^{-1} does NOT produce output[j]=input[pbox[j]]. Contradiction with my semantics analysis. Let me just empirically find which perm_arg gives the correct output. Let me test perm_arg = pbox (not

... (difficulties with the permutations)

Neither matches! Even pbox directly doesn't match. Let me reconsider the reference semantics. Reference: permuted[i] = temp[self.pbox[i]] and state[i] = combine(permuted[2i+1], permuted[2i]). So output nibble i (flat) = temp[pbox[i]] = old nibble pbox[i]. So output nibble i = input nibble pbox[i].

But wait — the reference also does t = list(reversed(list(tweak))) etc for the actual cipher. But for the standalone permutation method, state is just the byte array in memory. The flat nibble index i maps to (byte i//2, high if i odd). So output nibble at flat index i = input nibble at flat index pbox[i]. That's what I used.

So expected output nibble i (flat) = pbox[i] (since input nibble i=i). So output flat nibble order = pbox = [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8]. And ref_int should encode that. We computed ref_int = 8e73f9c2d461ab50 and decoded its nibbles as [0,5,11,10,1,6,4,13,2,12,9,15,3,7,14,8] - wait let me recheck that decode. 8e73f9c2d461ab50 little bytes = [0x50,0xab,0x61,0xd4,0xc2,0xf9,0x73,0x8e]. byte0=0x50 => low nibble=0 (nibble0), high=5 (nibble1). => nibble0=0, nibble1=5. ✓ pbox[0]=0,pbox[1]=5. byte1=0xab => low=0xb=11 (nibble2), high=0xa=10 (nibble3). => nibble2=11,nibble3=10 ✓ pbox[2]=11,pbox[3]=10. Good so ref_int encodes output nibbles = pbox. So the EXPECTED output integer is 8e73f9c2d461ab50.

But PermuteLayer with either arg gives something else. So my understanding of PermuteLayer is broken, OR the MSB-first bit ordering affects the permutation too.

PermuteLayer is a LinearLayer (binary matrix). Its eval = binary_matrix * x. The binary matrix is built from perm as: arr[perm[i]][i] = identity_matrix(word_coarseness). So binary_matrix row = perm[i], col = i, block I. For word_coarseness=4, each entry is a 4x4 identity block. So binary_matrix[4perm[i]+b][4i+b] = 1 for b in 0..3.

So output bit (4perm[i]+b) = x[4i+b]. This means output word perm[i] = input word i. In vector terms (MSB-first), output vector position (4perm[i]+b) gets input position (4i+b).

We want output nibble j = input nibble pbox[j]. So output word j should = input word pbox[j]. I.e., output[perm_arg] = input[i] means: output word perm[i] = input word i. We want output word j = input word pbox[j]. So set perm[i] such that perm[i] = j and i = pbox[j] => perm[pbox[j]] = j => perm = inverse(pbox). So perm_arg = inverse(pbox). That's what I used as inv_pbox, giving fa45e9b2d360c817. But expected is 8e73f9c2d461ab50.

Hmm so there's still a mismatch. But wait — maybe the issue is that the vector is MSB-first and the "word" in PermuteLayer with word_coarseness=4 maps to 4 consecutive bits, BUT the permutation operates on nibbles where the NIBBLE ordering in the integer is LSB-first while the vector is MSB-first. Let me reconsider: word j in PermuteLayer = the j-th 4-bit chunk of the VECTOR. Vector index 0 = MSB. So vector word 0 = bits 0..3 of the vector = the MSB nibble of the integer. But the integer's nibble 0 (LSB) = vector bits 60..63 (last 4). So "word j" in the PermuteLayer (vector word j) corresponds to integer nibble (15 - j) for 64-bit, NOT integer nibble j!

That's the crux. The permutation operates on vector words (MSB-first), but my reference/mental model uses integer nibbles (LSB-first). So there's a reversal between vector-word-index and integer-nibble-index.

So when I set perm_arg = inverse(pbox) thinking in integer-nibble space, the actual effect is on vector words which are reversed relative to integer nibbles.

To handle this cleanly: the permutation should be expressed in VECTOR word space. Vector word j corresponds to integer nibble (nibbles-1-j). The reference defines permutation on integer nibbles: out_nib[i] = in_nib[pbox[i]]. In vector word space: out_vecword[j] = in_vecword[ q(j) ] where we need to translate.

Let me define: integer nibble n corresponds to vector word (N-1-n) where N=state_nibbles. Reference: out_nib[n] = in_nib[pbox[n]]. So out_vecword[ N-1-n ] = in_vecword[ N-1-pbox[n] ]. So in vector word space, output word j (=N-1-n) gets input word (N-1-pbox[N-1-j]). So the perm argument (call it P_vec) satisfies: output word P_vec[i] = input word i, i.e., P_vec[i] = N-1-pbox[N-1-i].

So perm_arg should be [ N-1-pbox[N-1-i] for i in range(N) ].

Let me verify: for the docstring example n=4, pbox=[1,3,2,0], N=4. perm_arg[i] = 3 - pbox[3-i]. i=0: 3-pbox[3]=3-0=3 i=1: 3-pbox[2]=3-2=1 i=2: 3-pbox[1]=3-3=0 i=3: 3-pbox[0]=3-1=2 perm_arg=[3,1,0,2]. Let me check this gives 12 on input 0x9. Hmm let me just test programmatically.

Actually, simpler: rather than reverse-transform pbox, I can figure out perm_arg directly by the relation. But even simpler: Since the components (SBox, MixColumns) all operate in vector space consistently, and I've made them match the reference by careful bit-position mapping, the permutation just needs the right perm_arg. Let me compute perm_arg = [ N-1 - pbox[N-1-i] for i ] and test.

Actually wait — but the SBox layer and MixColumns: I built MixColumns with explicit MSB-first bit positions (row = total_bits-1-(4*o+b)), so it operates correctly in vector space matching the reference's integer-nibble semantics. The SBox applies to each word (4 bits). Word j in vector = integer nibble (15-j) for 64-bit. But the SBox is applied to each 4-bit word regardless of which integer nibble it is — S-box is position-independent (applied to every nibble). So SBox layer is correct regardless of ordering.

The MixColumns matrix: I placed the M-mixing in terms of integer nibble o,i (with MSB-first bit positions). So it correctly mixes integer-nibble columns. Good.

The permutation: I need perm_arg such that in vector space it reproduces reference's integer-nibble permutation. So perm_arg = [ N-1 - pbox[N-1-i] for i ].

Let me just test this.

Actually, let me reconsider whether I even need this reversal. The whole cipher is built in vector space. The INPUT to the cipher is int_to_vec(plaintext, n) which is MSB-first. The OUTPUT is vec_to_int(cipher(...)). For the test vector, plaintext=0, so input is all-zero; the reversal doesn't matter for input=0. But the constants (w0, rk, etc.) are XORed as integers via RoundkeyXOR, and RoundkeyXOR XORs the integer — which in vector space XORs at the same bit positions. Since I computed the constants as integers matching the reference's LSB-first integer, and the vector space for integer X has bit b of integer at vector position (total-1-b), the RoundkeyXOR(const_integer) XORs bit b of const at vector position (total-1-b). That's consistent: const integer bit b maps to vector pos (total-1-b), same as plaintext integer. So constants are correct in vector space.

So the ONLY mismatched component is the permutation. Let me fix perm_arg.

Let me compute and test.



Modified
1 file
Please continue with your task
Let me carefully compare the full encrypt with the reference. I should build an eval of my cipher after each stage and compare to the reference encrypt step-by-step.

Actually, a simpler approach: write a script that imports the reference blink module, runs encrypt step-by-step, and compares with my CiVerLy cipher after each stage. To access intermediate states, I can replicate the encrypt method faithfully in the script and compare against my cipher's DAG. But I don't have access to intermediate states easily in the DAG without adding probes.

Alternative: replicate the whole encrypt as a Python function and compare the output integer directly. Since the forward round now matches, the issue is likely in the later stages. The reflection structure is complex, with inverse rounds, different rk indices, etc.

Let me re-examine the encrypt function in the reference:

def encrypt(self, state, rk, w, h):
    self.whitening(state, w[0])
    for r in range(self.ra):
        self.sub_bytes(state)
        self.mix_columns(state)
        self.add_round_key(state, rk[r])
        self.add_round_constant(state, self.round_const[r])
        self.permutation(state)
    self.sub_bytes(state)
    self.mix_columns(state)
    self.add_round_key(state, h[0])
    self.permutation(state)
    for r in range(self.rb):
        self.sub_bytes(state)
        self.mix_columns(state)
        self.add_round_key(state, rk[r + self.ra])
        self.add_round_constant(state, self.round_const[r + self.ra])
        self.permutation(state)

    h_xor = [h[0][i] ^ h[1][i] for i in range(self.state_bytes)]
    self.sub_bytes(state)
    self.mix_columns(state)
    self.add_round_key(state, h_xor)
    self.sub_bytes(state)

    for r in range(self.rb):
        self.inv_permutation(state)
        self.add_round_constant(state, self.round_const_prime[r])
        self.add_round_key(state, rk[r])
        self.mix_columns(state)
        self.sub_bytes(state)
    self.inv_permutation(state)
    self.add_round_key(state, h[1])
    self.mix_columns(state)
    self.sub_bytes(state)
    for r in range(self.ra):
        self.inv_permutation(state)
        self.add_round_constant(state, self.round_const_prime[r + self.rb])
        self.add_round_key(state, rk[r + self.rb])
        self.mix_columns(state)
        self.sub_bytes(state)
    self.whitening(state, w[1])
Now my DAG:

initial whitening w0
a forward rounds (FwdRound)
middle: S, M, AK(h0), P
b forward rounds
middle: S, M, AK(h_xor), S
b backward rounds (BwdRound)
middle: P^-1, AK(h1), M, S
a backward rounds
final whitening w1
I need to map the exact sequence. Let me verify each section matches.

The forward full round FwdRound = S, M, AK(rk), AC(rc), P. This matches the first loops: sub, mix, AK(rk), AC(rc), perm. In the reference, the forward loop is:

for r in range(ra):
    sub_bytes(state)
    mix_columns(state)
    add_round_key(state, rk[r])
    add_round_constant(state, round_const[r])
    permutation(state)
My FwdRound: subcells, mixcolumns, rk_xor(0) for round key, rk_xor(0) for round const, perm. Then after instantiation I set consts:

node_rk.const = rk_int[r]
node_rc.const = rc_int[r]
Note: the order in FwdRound is sub, mix, RK, RC, P. But in the DAG, I connect them sequentially: sub -> mix -> rk -> rc -> perm. So the output of rc = input XOR rc. Then perm operates on rc output. That matches the reference order (AC after AK, P last). Good.

In my bwd_round, I have: inv_perm, RC, RK, mix, sub. Let me check the reference for backward rounds:

for r in range(self.rb):
    self.inv_permutation(state)
    self.add_round_constant(state, self.round_const_prime[r])
    self.add_round_key(state, rk[r])
    self.mix_columns(state)
    self.sub_bytes(state)
Order: inv_permutation, AC(rc'), AK(rk), M, S. My BwdRound: inv_perm, RC, RK, mix, sub. When I instantiate, I set:

node_rc.const = rc_prime_int[r]
node_rk.const = rk_int[r]
This matches the reference order for the backward loop over r in 0..rb-1.

Then after the middle h_xor stage, the reference has:

for r in range(self.rb):
    self.inv_permutation(state)
    self.add_round_constant(state, self.round_const_prime[r + self.rb])
    self.add_round_key(state, rk[r + self.rb])
    self.mix_columns(state)
    self.sub_bytes(state)
That's another rb backward rounds but with rc'[r+rb] and rk[r+rb]. My DAG has a second set of ra backward rounds with:

node_rc.const = rc_prime_int[rb + r]
node_rk.const = rk_int[rb + r]
for r in 0..ra-1. The reference loops over ra rounds here (since r in range(self.ra)), using index r+rb for rc' and rk. This matches my second set of backward rounds.

Then the middle inverse parts between the two loops: After the first b forward rounds and S-M-AK(h_xor)-S, reference does:

inv permutation loop (rb rounds)
single inv_perm, AK(h1), M, S
inv_perm loop (ra rounds)
In my DAG, after S-M-AK(h_xor)-S:

b backward rounds with rc_prime[0..rb-1], rk[0..rb-1]
P^-1, AK(h1), M, S
a backward rounds with rc_prime[rb..rb+a-1], rk[rb..rb+a-1]
This matches exactly.

Now, one thing I notice: the middle_stage helper builds S, M, AK(c). But after the h_xor stage, the reference does S, M, AK(h_xor), S. My code has middle_stage(cipher, node, h_xor_int, "hxor") then cipher.add_subcipher(subcells, ...). That's correct: middle_stage gives S,M,AK. Then extra subcells gives final S.

However, after the first a forward rounds, there's a middle step in the reference:

self.sub_bytes(state)
self.mix_columns(state)
self.add_round_key(state, h[0])
self.permutation(state)
My code has middle_stage(cipher, node, h0_int) (S, M, AK(h0)), then perm. Correct.

Similarly after the first b forward rounds, there's the h_xor stage. Correct.

Now, the RoundkeyXOR_CVL is a ConstXOR (XOR of a constant with the input). In the forward round, the order is sub -> mix -> RK -> RC -> perm. RK and RC are both XOR with constants. So the combined effect of RK then RC is XOR with (rk ^ rc). But that's fine.

Wait, I defined rk_xor to return RoundkeyXOR_CVL(state_nibbles*word, const, name="RK"). So its input size is state_nibbles*word = 64 bits, output is 64 bits. In FwdRound, I add it after mix: sub -> mix -> rk_xor(0) -> rk_xor(0) -> perm. Both rk and rc are 64-bit components. So they consume 64 bits and output 64 bits. That's fine.

In BwdRound, I have inv_perm -> rc -> rk -> mix -> sub. OK.

But here's a potential issue: in BwdRound, node_rc and node_rk are the indices returned by add_subcipher. But after deep-copy into cipher, I access cipher.nodes[node].nodes[node_rc]. For the backward round, node_rc is the node returned by bwd_round.add_subcipher(rc, ...) and node_rk is the node returned by bwd_round.add_subcipher(rk, ...) in the bwd_round instance. However, in BwdRound, I did:

node = bwd_round.add_subcipher(inv_perm, ...)
node_rc = bwd_round.add_subcipher(rk_xor(0), [(node, ...)])
node_rk = bwd_round.add_subcipher(rk_xor(0), [(node_rc, ...)])
So node_rc adds the constant XOR to node (the inv_perm output). Then node_rk adds the constant XOR to node_rc. So the order is: inv_perm output -> RC -> RK -> mix -> S. That's correct for reference: inv_perm, AC, AK, M, S.

But when I later set cipher.nodes[node].nodes[node_rc].const = rc_prime_int[r] for backward round, I need the node_rc index to point to the first XOR (RC), and node_rk to point to the second XOR (RK). That's correct.

Now, another subtle issue: the rk_xor instances inside bwd_round are created fresh by calling rk_xor(0) each time. And node_rc and node_rk are indices local to bwd_round. But when bwd_round is deep-copied into cipher, its sub-ciphers are deep-copied too. The deep-copy should preserve the indices. So accessing cipher.nodes[node].nodes[node_rc] should work. But there's a subtle issue if Python's copy.deepcopy of a cipher object does not preserve the node indices... Actually deepcopy copies the list nodes, preserving order, so indices are the same. So it should work.

Now, let me think about the permutation again. I fixed the forward permutation to match. But for the inverse permutation, I used perm.inv(). Let me verify that perm.inv() for my corrected perm gives the correct inverse.

perm = PermuteLayer_CVL(P, word_coarseness=word) where P maps output positions. perm.inv() creates a new PermuteLayer_CVL with perm = inverse(P). That should reverse the permutation. I need to verify.

Actually perm.inv() computes:

return PermuteLayer_CVL(
    perm=[q-1 for q in Permutation([p+1 for p in self.perm]).inverse()],
    word_coarseness=self.word_coarseness, name=self.name
)
This builds the mathematical inverse permutation of self.perm. Since self.perm is the CiVerLy perm vector, the inverse undoes the CiVerLy permutation. So perm.inv() should map output positions correctly to reverse the effect. Since the forward permutation is now correct, the inverse should also be correct. So perm issue should be fixed.

Next possible issue: the round constants and round keys integer conversion. Let me verify one specific: for the backward rounds, the reference uses self.round_const_prime[r] with r in 0..rb-1. In my _bytes_to_int, the bytes are LSB-first. Since the integer bit ordering matches MSB vector space, the RoundkeyXOR(const_int) XORs the correct vector bits. Wait, RoundkeyXOR_CVL does x + int_to_vec(const, output_length). int_to_vec converts integer to MSB-first vector. So const_int's bit0 (integer) is at vector pos total-1. When XOR is applied, the MSB vector gets the correct bit positions. Since the const_int came from _bytes_to_int of LSB-first bytes, it's the correct integer.

Let me just systematically compare the full encrypt step by step by replicating the reference encrypt and comparing intermediate integers with the cipher. I can write a test that evaluates the cipher after each stage? But I can't easily get intermediate states from the cipher DAG without adding output nodes. However, I can build a smaller test: compare the FULL cipher on plaintext 0 to the reference encrypt_bytes output. Since the test vectors don't match, the issue is somewhere in the reflection part.

Let me write a script that replicates the reference encrypt step by step and also computes the same using the CiVerLy components assembled exactly as in the full blink.py DAG.


The custom-built full cipher matches the reference! So the issue is in the main BLINK_CVL.__init__ somewhere. The debug script builds the exact same components manually and matches. So there must be a subtle issue in my main __init__ — perhaps the _variant_config or _generate_round_key call has different parameters, or the ra_rb_from_n_t logic, or some other difference.

Wait, the test script test_blink.py I used earlier calls BLINK_CVL(64, 64, key=key, tweak=tweak) and gets wrong output. But the manual assembly in dbg35.py gets the right output. So the difference is in how BLINK_CVL assembles things vs the manual script. Let me compare.

In BLINK_CVL.__init__:

Computes state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime = _variant_config(n, t, key_bytes).
key_bytes = (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
For test key=0x... (112 hex chars = 56 bytes). key.bit_length() = 447? 56 bytes * 8 = 448 bits. bit_length = 447? Actually bit_length returns number of bits necessary to represent the integer in binary, excluding sign and leading zeros. So for the 56-byte key, bit_length = 447 (since MSB is 0xd6 = 1101... msb at bit 447). Then (447+7)//8 = 454//8 = 56. So key_bytes=56. Good.

Then _variant_config(64, 64, 56):

state_bytes = 8, tweak_bytes=8.
pbox = PBOX_64
ra, rb = 2, 3
rc = ROUND_CONST_64, rc_prime = ROUND_CONST_PRIME_64
Then _generate_round_key(master_key, tweak_lst, 8, 8, 56):

master_key = [(key >> 8*i) & 0xFF for i in 56]
tweak_lst = [(tweak >> 8*i) & 0xFF for i in 8]
In the manual script I used state_bytes, tweak_bytes, ra, rb, pbox, rc, rcp = _variant_config(64, 64, (key.bit_length()+7)//8). That matches.

So the difference is in the DAG construction inside BLINK_CVL. Let me compare the two.

In my __init__, I had:

fwd_round = WordSBoxCipher(4,16,16,"FwdRound")
node = fwd_round.add_subcipher(subcells, ...)
node = fwd_round.add_subcipher(mixcolumns, ...)
node_rk = fwd_round.add_subcipher(rk_xor(0), ...)
node_rc = fwd_round.add_subcipher(rk_xor(0), ...)
node = fwd_round.add_subcipher(perm, ...)
fwd_round.add_output(...)
Then later:

for r in range(ra):
    node = cipher.add_subcipher(fwd_round, ...)
    cipher.nodes[node].nodes[node_rk].const = rk_int[r]
    cipher.nodes[node].nodes[node_rc].const = rc_int[r]
This is identical to dbg35's construction! So what's different?

Wait — in my BLINK_CVL.__init__, I defined cipher = AESlike(word, rows, cols, name=name) originally, then I edited it to cipher = WordSBoxCipher(word, state_nibbles, state_nibbles, name=name). That is the same as the manual script: c = WordSBoxCipher(4,16,16,"C").

And the subcells, mix, perm, bwd components are exactly the same.

One possible difference: the middle_stage helper in my __init__ uses subcells and mixcolumns from the outer scope. In the manual script, I built everything inline without helper. But that should be equivalent.

Another possible difference: in my __init__, after the b forward rounds, I do:

node = middle_stage(cipher, node, h_xor_int, "hxor")
node = cipher.add_subcipher(subcells, [(node, (i, i)) for i in range(state_nibbles)])
Here subcells is the outer component. That's fine.

Then backward rounds:

for r in range(rb):
    node = cipher.add_subcipher(bwd_round, ...)
    cipher.nodes[node].nodes[node_rc].const = rc_prime_int[r]
    cipher.nodes[node].nodes[node_rk].const = rk_int[r]
Wait! In bwd_round: I defined node_rc = bwd_round.add_subcipher(rk_xor(0), ...) and node_rk = bwd_round.add_subcipher(rk_xor(0), ...). So node_rc is the first XOR (after inv_perm), and node_rk is the second XOR (after node_rc). In the reference, backward round order is inv_perm -> rc -> rk -> mix -> S. So node_rc should correspond to RC and node_rk to RK. Then I set:

cipher.nodes[node].nodes[node_rc].const = rc_prime_int[r]
cipher.nodes[node].nodes[node_rk].const = rk_int[r]
This matches the manual script exactly.

Wait, in my bwd_round, did I define node_rc before node_rk? Looking at the edited code:

node = bwd_round.add_subcipher(inv_perm, [(bwd_round.IN, (i, i)) for i in range(state_nibbles)])
node_rc = bwd_round.add_subcipher(
    rk_xor(0), [(node, (i, i)) for i in range(state_nibbles)]
)
node_rk = bwd_round.add_subcipher(
    rk_xor(0), [(node_rc, (i, i)) for i in range(state_nibbles)]
)
node = bwd_round.add_subcipher(
    mixcolumns, [(node_rk, (i, i)) for i in range(state_nibbles)]
)
node = bwd_round.add_subcipher(
    subcells, [(node, (i, i)) for i in range(state_nibbles)]
)
Yes, node_rc is first, node_rk second. Good.

Then in the main loops I set:

for rb backward rounds: node_rc.const = rc_prime_int[r], node_rk.const = rk_int[r]
for ra backward rounds: node_rc.const = rc_prime_int[rb+r], node_rk.const = rk_int[rb+r]
Good.

Hmm, everything seems identical. So why does the class give wrong output while manual gives correct?

Maybe there's a caching issue: the _mix_columns function returns a LinearLayer_CVL whose binary_matrix is built from sage matrices. Since Mc uses block_matrix or matrix constructor, it might have some internal state that gets modified or shared incorrectly when deep-copied? But I tested it manually and it works.

Another thought: in the class init, after editing the file, I need to reload the module. The test_blink.py script imports BLINK_CVL from the module. It might be using a stale cached version? But the script runs freshly each time. However, Python caches modules. If I edited blink.py and ran test_blink.py before reloading, it would use the old version? Actually when running sage -python the script, the module is imported fresh each execution. So no caching between runs.

Wait, let me check: c = BLINK_CVL(64, 64, key=key, tweak=tweak). This calls new which returns instance.blink_cipher. But init is called by new (super().new calls instance.init). So init is executed. The returned object is the cipher inside.

Let me just directly compare the test_blink.py call to the manual one. Maybe the difference is the name parameter or some default. But that shouldn't affect evaluation.

Actually, let me check whether the test_blink.py script imports the correct module. It uses from civerly.cipher_implementations.blink import BLINK_CVL. That imports from the installed package. Since I may not have installed the edited package, Python might be importing an older version. Let me ensure that the import uses the local src path.

Looking at the environment, earlier I checked with sage -python -c "import civerly; print(civerly.__file__)" and got /Users/Uni/Documents/GitHub/CiVerLy-forked-new/src/civerly/__init__.py. So it imports from the local src. And the script imports civerly.cipher_implementations.blink which resolves to src/civerly/cipher_implementations/blink.py. So the latest version should be used.

Let me rerun test_blink.py after making sure the module is current.

Output is wrong. The nodes list shows 25 nodes + OUT. Let's compare with the manual script's node list. Let me look at the node structure more carefully.

Actually, I notice the nodes list shows 13: RK, 14: Permutation, 15: RK, 16: MixColumns, 17: BwdRound, etc. It seems after the forward rounds and middle stages, the sequence is different. But I'd need to see the full node list. Let me count nodes and compare to the manual DAG.

Actually, the issue might be simpler: the _variant_config call in the class uses (key.bit_length() + 7) // 8 if key else .... For the test key, key.bit_length() returns 447. (447+7)//8 = 454//8 = 56. Good. So key_bytes=56.

But when key=0, the else branch: (n // 8) * (ra_rb_from_n_t(n, t) + 2). For n=64, ra_rb_from_n_t returns 5. So 8*(5+2)=56. Same.

Wait, but in the class init, I have _variant_config(n, t, (key.bit_length()+7)//8 if key else ...). The key is passed as int. key=0 is falsy. For key provided, key_bytes=(bit_length+7)//8. For n=64, key bit_length is 447, (447+7)//8=56. Good.

However, there's a subtle bug: ra_rb_from_n_t(n, t) is called BEFORE _variant_config, but _variant_config also computes ra, rb. In the class, the ra_rb_from_n_t logic is used ONLY in the else branch. When key is non-zero, _variant_config(n, t, key_bytes) computes ra, rb from key_bytes directly. So both paths are fine.

Let me inspect the node list of the manual script and compare to the class. The manual script builds:

node0 = c.IN
1: RK(w0)
2..6: FwdRound x5? No, ra=2, rb=3. So fwd rounds: 2,3 (ra=2)
4: SubCells (middle h0)
5: MixColumns
6: RK(h0)
7: Permutation
8,9,10: FwdRound x3 (rb=3)
11: SubCells (h_xor)
12: MixColumns
13: RK(h_xor)
14: SubCells
15,16,17: BwdRound x3
18: InvPermutation
19: RK(h1)
20: MixColumns
21: SubCells
22,23: BwdRound x2 (ra=2)
24: RK(w1)
25: OUT
But the class node list from dbg36 shows 13: RK, 14: Permutation, 15: RK, 16: MixColumns, 17: BwdRound, etc. That doesn't match. The sequence is different because my middle_stage helper inserts SubCells + MixColumns + RK, but then I also add Permutation after it. In the manual script, middle h0: Sub + Mix + RK + Perm. Then fwd rounds continues. In the class I do the same: middle_stage(cipher, node, h0_int, "h0") then perm.

Wait, middle_stage uses rk_xor(const) which is a RoundkeyXOR_CVL. The helper name label "h0" doesn't matter. After that I add perm. OK.

Then after b fwd rounds: middle_stage(cipher, node, h_xor_int, "hxor") then subcells. OK.

Then b backward rounds via bwd_round. In the class I have for r in range(rb): node = cipher.add_subcipher(bwd_round...).

Wait, in the node list the middle parts around 13-21 look suspicious. Let me get the FULL node list from the class.

Actually node 0 is IN, 1 is first RK(w0), 2-3 are fwd_rounds for ra=2, then 4 is SubCells from middle h0, 5 is MixColumns, 6 is RK(h0), 7 is Permutation, 8-10 are fwd_rounds for rb=3, 11 is SubCells from h_xor, 12 is MixColumns, 13 is RK(h_xor), 14 is SubCells, 15-17 are BwdRound x3, 18 is Permutation (inv?), 19 is RK(h1), 20 is MixColumns, 21 is SubCells, 22-23 are BwdRound x2, 24 is RK(w1), 25 is OUT.

But dbg36 only printed the tail (indices 17 onward). It shows:

17: BwdRound
18: Permutation
19: RK
20: MixColumns
21: SubCells
22: BwdRound
23: BwdRound
24: RK
25: Blink-64.OUT
That looks roughly correct: after backward rounds 15-17 (3 BwdRounds for rb=3), we have inv_perm (18), RK(h1) (19), MixColumns (20), SubCells (21), BwdRound (22,23 for ra=2), RK(w1) (24), OUT.

But node 18 is Permutation (not inv_perm?) Wait, the inv_perm object's name is just the name of the original perm object — but when I built perm = PermuteLayer_CVL(..., name="Permutation") then inv_perm = perm.inv(), the inverse object's name might also be "Permutation" because perm.inv() copies the name. So node 18 is inv_perm and its name prints as "Permutation". That's fine.

Now, what about the middle sections? Let me reprint the full node list and compare.

Actually, the crucial thing is: why does the manual script work but the class doesn't? Let me think about the manual script vs class differences.

One obvious difference: the manual script sets _bytes_to_int(h[0]) for h0, _bytes_to_int([h[0][i]^h[1][i]]) for h_xor, etc. These are identical to the class's computation of h0_int, h_xor_int, h1_int, w0_int, w1_int. The class computes _bytes_to_int(h[0]), which is the same.

Another difference: the manual script accesses c.nodes[node].nodes[node_rk1].const = ... where node_rk1 is the index inside fwd. The class accesses cipher.nodes[node].nodes[node_rk].const = ... where node_rk is also inside fwd_round. Both are identical.

Wait, in the class, when I add subcells and mixcolumns as subciphers of the main cipher, they are deep-copied from the same mutable objects subcells and mixcolumns. But they're added multiple times. This is the same as in the manual script.

Wait, maybe the deepcopy behavior causes an issue with the hash caching for modeling, but evaluation should be unaffected.

Actually, let me think about one thing: in the class, I build cipher = WordSBoxCipher(...). Then I add fwd_round (a WordSBoxCipher) as a subcipher. WordSBoxCipher.add_subcipher for sub_cipher being a WordBasedCipher checks if the wordsize matches and expands edges. That's fine.

In the manual script, c = WordSBoxCipher(4,16,16,"C") and c.add_subcipher(fwd,...) — same.

Then the manual script does c.add_subcipher(sub, ...), c.add_subcipher(mix, ...), etc. In the class, middle_stage does the same: cipher.add_subcipher(subcells, ...), cipher.add_subcipher(mixcolumns, ...), cipher.add_subcipher(rk_xor(const), ...).

One difference: my middle_stage uses the rk_xor helper which returns a NEW RoundkeyXOR_CVL each time. In the manual script, I built rxor(c) which also returns a new one each time. Same.

Another difference might be that in the class, I use the same rk_xor(0) inside fwd_round AND inside middle_stage. But these are each separate invocations, so they are separate objects. Good.

Wait, I notice that in the class, I add perm as a subcipher twice: once in fwd_round, once directly in the cipher for the middle. And I also use inv_perm directly. The manual script also uses perm multiple times (inside fwd and directly). But perm is a PermuteLayer_CVL which is derived from LinearLayer_CVL. Its eval method uses super().eval(x) which computes binary_matrix * x. If deepcopy shares the binary_matrix reference, that's fine because it's immutable.

Potential issue: the name attribute. When deepcopying, the name is preserved. Multiple subciphers with the same name shouldn't affect eval.

Let me just directly test the class against a modified version where I print the constants for each node to ensure they match the manual script.

Actually, a better idea: I'll add prints to the class init or run a diff between the class-generated cipher and the manual-generated cipher. Build both, then compare their hash (since Cipher objects are compared by hash of their graph). But the class has different constants set per round, while the manual script also sets constants. So if they're identical in structure and constants, their hashes should match.

Let me write a script that builds both and compares their hashes.

The hash matches! That means the two ciphers have identical structure and components. But their evaluation gives different outputs. That's very strange — if the graph is identical (same edges, same components), they should produce the same output.

Wait — the hash comparison uses the Cipher.hash which hashes based solely on the DAG edges and component types/hashes, NOT the runtime constants! The constants (RoundkeyXOR_CVL.const values) are NOT included in the hash. So hash(c1)==hash(c2) just means they have the same topology and component types, but the constants could differ.

So the constants are different between c1 and c2! That makes sense: c1 is built by BLINK_CVL class, c2 manually. The topology is the same, but constants differ. Which constant differs?

I need to compare the constants set in c1.nodes vs c2.nodes. I can do that by traversing the graph and comparing node.const values. Since the hash matches, node indices should be the same in the same topology? Not necessarily — components are hashed for equality; if I used different instances of rk_xor with same hash (since const changes hash? wait RoundkeyXOR hash includes const? Actually component hash ignores 'milp', 'sat', etc. but includes 'S' for SBox. For RoundkeyXOR_CVL, it inherits from ConstXOR_CVL which inherits from Component. The hash excludes a lot. For ConstXOR, the hash of _ConstXOR_CVL__const is included? The hash includes: if isinstance(value, (bool,str)) skip; if any(word in key for words "wordsize", "milp", "sat", "MILP", "SAT") skip; elsif matrix_type -> tuple. For RoundkeyXOR_CVL, __const is an integer (int). It should be included because it's not bool, not str, not matrix, not iterable... Wait, int is an int and the hash includes liste.append((key, value)). But the component hash excludes milp, sat, etc. It does NOT exclude the const. However, _ConstXOR_CVL__const is a mangled name because of private naming in subclass. Actually the RoundkeyXOR_CVL inherits from ConstXOR_CVL and uses a setter const.setter. The hash method enumerates keys in self.dict. For RoundkeyXOR_CVL, the const value is stored as _ConstXOR_CVL__const. The hash method checks if any(word in key for word in ["wordsize","milp","sat","MILP","SAT"]). None match. So __const is included in the hash. So if const differs, the component hash differs, and therefore comp == prev in modeling would not match. But the initial fwd_round built with const=0 has a certain hash. When deep-copied and const set later, does the deepcopy propagate? Yes. But the hash of the overall cipher might not change.

Anyway, the hash of the entire cipher being equal means the initial structure before constant modifications is identical. Later modifications of const on deep-copied subciphers modify the instances inside c1.nodes and c2.nodes. Since the deepcopy gives fresh instances, setting const on c1's instances doesn't affect c2's. But these differences are NOT reflected in Cipher.hash because it hashes the original graph snapshot (at init time) without const values.

So the hash equality is misleading. The actual issue is that some constant in c1 is wrong. Let me compare the constants of each RoundkeyXOR node in c1 and c2. Since c1 and c2 have the same structure, I can iterate over nodes and compare node.const where applicable. The top-level node indices should match because the add_subcipher order is the same. Let me write a comparison script.

Let me refine: the issue may be in how the class sets constants for backward rounds. Or maybe rc_prime vs rc confusion. Or the _variant_config returns rc_prime but the class uses it correctly... Let me systematically compare node constants. I see hash(c1)==hash(c2) but outputs differ, meaning constants are set differently. Let me compare the constants of each RoundkeyXOR node across both ciphers.

The hash matches! That means the two ciphers have identical structure and components. But their evaluation gives different outputs. That's very strange — if the graph is identical (same edges, same components), they should produce the same output.

Wait — the hash comparison uses the Cipher.hash which hashes based solely on the DAG edges and component types/hashes, NOT the runtime constants! The constants (RoundkeyXOR_CVL.const values) are NOT included in the hash. So hash(c1)==hash(c2) just means they have the same topology and component types, but the constants could differ.

So the constants are different between c1 and c2! That makes sense: c1 is built by BLINK_CVL class, c2 manually. The topology is the same, but constants differ. Which constant differs?

I need to compare the constants set in c1.nodes vs c2.nodes. I can do that by traversing the graph and comparing node.const values. Since the hash matches, node indices should be the same in the same topology? Not necessarily — components are hashed for equality; if I used different instances of rk_xor with same hash (since const changes hash? wait RoundkeyXOR hash includes const? Actually component hash ignores 'milp', 'sat', etc. but includes 'S' for SBox. For RoundkeyXOR_CVL, it inherits from ConstXOR_CVL which inherits from Component. The hash excludes a lot. For ConstXOR, the hash of _ConstXOR_CVL__const is included? The hash includes: if isinstance(value, (bool,str)) skip; if any(word in key for words "wordsize", "milp", "sat", "MILP", "SAT") skip; elsif matrix_type -> tuple. For RoundkeyXOR_CVL, __const is an integer (int). It should be included because it's not bool, not str, not matrix, not iterable... Wait, int is an int and the hash includes liste.append((key, value)). But the component hash excludes milp, sat, etc. It does NOT exclude the const. However, _ConstXOR_CVL__const is a mangled name because of private naming in subclass. Actually the RoundkeyXOR_CVL inherits from ConstXOR_CVL and uses a setter const.setter. The hash method enumerates keys in self.dict. For RoundkeyXOR_CVL, the const value is stored as _ConstXOR_CVL__const. The hash method checks if any(word in key for word in ["wordsize","milp","sat","MILP","SAT"]). None match. So __const is included in the hash. So if const differs, the component hash differs, and therefore comp == prev in modeling would not match. But the initial fwd_round built with const=0 has a certain hash. When deep-copied and const set later, does the deepcopy propagate? Yes. But the hash of the overall cipher might not change.

Anyway, the hash of the entire cipher being equal means the initial structure before constant modifications is identical. Later modifications of const on deep-copied subciphers modify the instances inside c1.nodes and c2.nodes. Since the deepcopy gives fresh instances, setting const on c1's instances doesn't affect c2's. But these differences are NOT reflected in Cipher.hash because it hashes the original graph snapshot (at init time) without const values.

So the hash equality is misleading. The actual issue is that some constant in c1 is wrong. Let me compare the constants of each RoundkeyXOR node in c1 and c2. Since c1 and c2 have the same structure, I can iterate over nodes and compare node.const where applicable. The top-level node indices should match because the add_subcipher order is the same. Let me write a comparison script.

Let me refine: the issue may be in how the class sets constants for backward rounds. Or maybe rc_prime vs rc confusion. Or the _variant_config returns rc_prime but the class uses it correctly... Let me systematically compare node constants. I see hash(c1)==hash(c2) but outputs differ, meaning constants are set differently. Let me compare the constants of each RoundkeyXOR node across both ciphers.

cd /Users/Uni/Documents/GitHub/CiVerLy-forked-new && cat > /tmp/dbg38.py << 'EOF'
from civerly.cipher_implementations.blink import BLINK_CVL, _variant_config
from civerly.cipher_implementations.blink import (_generate_round_key, _bytes_to_int, SBOX, _mix_columns, _vec_perm)
from civerly.component import SBox_CVL, PermuteLayer_CVL, RoundkeyXOR_CVL
from civerly.wordsboxcipher import WordSBoxCipher
from civerly.util import int_to_vec, vec_to_int

n=64; t=64
key = int("d6a102d888a467e4d1d7dec33a246943e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a0697779021b38e7fa1",16)
tweak = int("0123456789abcdef",16)

c1 = BLINK_CVL(n, t, key=key, tweak=tweak, name="Blink-64")

# manual rebuild
state_bytes,tweak_bytes,ra,rb,pbox,rc,rcp=_variant_config(n,t,(key.bit_length()+7)//8)
mk=[(key>>(8*i))&0xFF for i in range(state_bytes*(ra+rb+2))]
tl=[(tweak>>(8*i))&0xFF for i in range(tweak_bytes)]
rk,w,h=_generate_round_key(mk,tl,state_bytes,tweak_bytes,state_bytes*(ra+rb+2))
state_nibbles=state_bytes*2

sub=WordSBoxCipher(4,state_nibbles,state_nibbles,"S")
sbox=SBox_CVL(SBOX)
for i in range(state_nibbles):
    node=sub.add_subcipher(sbox,[(sub.IN,(i,0))]); sub.add_output([(node,(0,i))])
mx=_mix_columns(state_bytes); mix=WordSBoxCipher(4,state_nibbles,state_nibbles,"M")
node=mix.add_subcipher(mx,[(mix.IN,(i,i)) for i in range(state_nibbles)]); mix.add_output([(node,(i,i)) for i in range(state_nibbles)])
perm=PermuteLayer_CVL(_vec_perm(pbox,state_nibbles), word_coarseness=4, name="P")
inv=perm.inv()

def rxor(c):
    return RoundkeyXOR_CVL(state_nibbles*4,c,name="RK")

fwd=WordSBoxCipher(4,state_nibbles,state_nibbles,"FR")
node=fwd.add_subcipher(sub,[(fwd.IN,(i,i)) for i in range(state_nibbles)])
node=fwd.add_subcipher(mix,[(node,(i,i)) for i in range(state_nibbles)])
node_rk1=fwd.add_subcipher(rxor(0),[(node,(i,i)) for i in range(state_nibbles)])
node_rc1=fwd.add_subcipher(rxor(0),[(node_rk1,(i,i)) for i in range(state_nibbles)])
node=fwd.add_subcipher(perm,[(node_rc1,(i,i)) for i in range(state_nibbles)])
fwd.add_output([(node,(i,i)) for i in range(state_nibbles)])

bwd=WordSBoxCipher(4,state_nibbles,state_nibbles,"BR")
node=bwd.add_subcipher(inv,[(bwd.IN,(i,i)) for i in range(state_nibbles)])
node_rc2=bwd.add_subcipher(rxor(0),[(node,(i,i)) for i in range(state_nibbles)])
node_rk2=bwd.add_subcipher(rxor(0),[(node_rc2,(i,i)) for i in range(state_nibbles)])
node=bwd.add_subcipher(mix,[(node_rk2,(i,i)) for i in range(state_nibbles)])
node=bwd.add_subcipher(sub,[(node,(i,i)) for i in range(state_nibbles)])
bwd.add_output([(node,(i,i)) for i in range(state_nibbles)])

c2=WordSBoxCipher(4,state_nibbles,state_nibbles,"Blink-64")
node=c2.add_subcipher(rxor(_bytes_to_int(w[0])),[(c2.IN,(i,i)) for i in range(state_nibbles)])
for r in range(ra):
    node=c2.add_subcipher(fwd,[(node,(i,i)) for i in range(state_nibbles)])
    c2.nodes[node].nodes[node_rk1].const=_bytes_to_int(rk[r])
    c2.nodes[node].nodes[node_rc1].const=_bytes_to_int(rc[r])
node=c2.add_subcipher(sub,[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(mix,[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(rxor(_bytes_to_int(h[0])),[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(perm,[(node,(i,i)) for i in range(state_nibbles)])
for r in range(rb):
    node=c2.add_subcipher(fwd,[(node,(i,i)) for i in range(state_nibbles)])
    c2.nodes[node].nodes[node_rk1].const=_bytes_to_int(rk[ra+r])
    c2.nodes[node].nodes[node_rc1].const=_bytes_to_int(rc[ra+r])
node=c2.add_subcipher(sub,[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(mix,[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(rxor(_bytes_to_int([h[0][i]^h[1][i] for i in range(state_bytes)])),[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(sub,[(node,(i,i)) for i in range(state_nibbles)])
for r in range(rb):
    node=c2.add_subcipher(bwd,[(node,(i,i)) for i in range(state_nibbles)])
    c2.nodes[node].nodes[node_rc2].const=_bytes_to_int(rcp[r])
    c2.nodes[node].nodes[node_rk2].const=_bytes_to_int(rk[r])
node=c2.add_subcipher(inv,[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(rxor(_bytes_to_int(h[1])),[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(mix,[(node,(i,i)) for i in range(state_nibbles)])
node=c2.add_subcipher(sub,[(node,(i,i)) for i in range(state_nibbles)])
for r in range(ra):
    node=c2.add_subcipher(bwd,[(node,(i,i)) for i in range(state_nibbles)])
    c2.nodes[node].nodes[node_rc2].const=_bytes_to_int(rcp[rb+r])
    c2.nodes[node].nodes[node_rk2].const=_bytes_to_int(rk[rb+r])
node=c2.add_subcipher(rxor(_bytes_to_int(w[1])),[(node,(i,i)) for i in range(state_nibbles)])
c2.add_output([(node,(i,i)) for i in range(state_nibbles)])

# compare node lists and constants where applicable
def describe(c, title):
    print(f"--- {title} ---")
    for i,node in enumerate(c.nodes):
        const = getattr(node, 'const', None)
        name = getattr(node, 'name', str(type(node)))
        print(f"  {i}: {name}, const={hex(const) if const is not None else None}")
        if hasattr(node, 'nodes'):
            for j,sub in enumerate(node.nodes):
                sconst = getattr(sub, 'const', None)
                sname = getattr(sub, 'name', str(type(sub)))
                print(f"      {j}: {sname}, const={hex(sconst) if sconst is not None else None}")

describe(c1, "c1 (class)")
describe(c2, "c2 (manual)")
EOF
sage -python /tmp/dbg38.py 2>&1 | head -n 100
--- c1 (class) ---
  0: Blink-64.IN, const=None
  1: RK, const=0x97779021b38e7fa1
  2: FwdRound, const=None
      0: FwdRound.IN, const=None
      1: SubCells, const=None
      2: MixColumns, const=0x13198a2e03707344
      3: RK, const=0x6dd387874a0b52ce
      4: RK, const=0x0
      5: Permutation, const=None
      6: FwdRound.OUT, const=None
  3: FwdRound, const=None
      0: FwdRound.IN, const=None
      1: SubCells, const=None
      2: MixColumns, const=0x82efa98ec4e6c89
      3: RK, const=0x762c2df9de6f0d21
      4: RK, const=0x0
      5: Permutation, const=None
      6: FwdRound.OUT, const=None
  4: SubCells, const=None
      0: SubCells.IN, const=None
      1: SBox, const=None
      2: SBox, const=None
      3: SBox, const=None
      4: SBox, const=None
      5: SBox, const=None
      6: SBox, const=None
      7: SBox, const=None
      8: SBox, const=None
      9: SBox, const=None
      10: SBox, const=None
      11: SBox, const=None
      12: SBox, const=None
      13: SBox, const=None
      14: SBox, const=None
      15: SBox, const=None
      16: SBox, const=None
      17: SubCells.OUT, const=None
  5: MixColumns, const=None
      0: MixColumns.IN, const=None
      1: MixColumns, const=None
      2: MixColumns.OUT, const=None
  6: RK, const=0xc877d3e5b68357ae
  7: Permutation, const=None
  8: FwdRound, const=None
      0: FwdRound.IN, const=None
      1: SubCells, const=None
      2: MixColumns, const=0xbe5466cf34e90c6c
      3: RK, const=0xe07c1dc6f302c57e
      4: RK, const=0x0
      5: Permutation, const=None
      6: FwdRound.OUT, const=None
  9: FwdRound, const=None
      0: FwdRound.IN, const=None
      1: SubCells, const=None
      2: MixColumns, const=0x3f84d5b5b5470917
      3: RK, const=0xd1d7dec33a246943
      4: RK, const=0x0
      5: Permutation, const=None
      6: FwdRound.OUT, const=None
  10: FwdRound, const=None
      0: FwdRound.IN, const=None
      1: SubCells, const=None
      2: MixColumns, const=0xd1310ba698dfb5ac
      3: RK, const=0xd6a102d888a467e4
      4: RK, const=0x0
      5: Permutation, const=None
      6: FwdRound.OUT, const=None
  11: SubCells, const=None
      0: SubCells.IN, const=None
      1: SBox, const=None
      2: SBox, const=None
      3: SBox, const=None
      4: SBox, const=None
      5: SBox, const=None
      6: SBox, const=None
      7: SBox, const=None
      8: SBox, const=None
      9: SBox, const=None
      10: SBox, const=None
      11: SBox, const=None
      12: SBox, const=None
      13: SBox, const=None
      14: SBox, const=None
      15: SBox, const=None
      16: SBox, const=None
      17: SubCells.OUT, const=None
  12: MixColumns, const=None
      0: MixColumns.IN, const=None
      1: MixColumns, const=None
      2: MixColumns.OUT, const=None
  13: RK, const=0xd8eac24674a0201e
  14: SubCells, const=None
      0: SubCells.IN, const=None
      1: SBox, const=None
      2: SBox, const=None
      3: SBox, const=None
      4: SBox, const=None
      5: SBox, const=None
      6: SBox, const=None
Looking at c1, the MixColumns inside FwdRound are deep copies and have crazy constant values! MixColumns.const = 0x13198a2e03707344 etc. That means MixColumns (a WordSBoxCipher) was hacked — wait, the constant was set on a node inside FwdRound, but MixColumns doesn't have a const attribute. So where does that value come from?

Oh! I see the issue. In the class init, I defined mixcolumns as a WordSBoxCipher containing the LinearLayer. Then inside fwd_round, I add_mixcolumns via fwd_round.add_subcipher(mixcolumns, ...). In the main cipher, I also add mixcolumns directly via cipher.add_subcipher(mixcolumns, ...). And in middle_stage, I also add mixcolumns directly.

But here's the problem: in the class init, when I do:

for r in range(ra):
    node = cipher.add_subcipher(fwd_round, ...)
    cipher.nodes[node].nodes[node_rk].const = rk_int[r]
    cipher.nodes[node].nodes[node_rc].const = rc_int[r]
The node_rk is the index inside fwd_round for the first RK component. node_rc is the index inside fwd_round for the second RK component. But what are node_rk and node_rc in the context of cipher.nodes[node]?

Wait — cipher.nodes[node] is a deep copy of fwd_round. Its .nodes list includes the deep copies of subcells, mixcolumns, RK, RK, Permutation. The indices in that deep copy should match the original fwd_round indices because deepcopy preserves list order. So cipher.nodes[node].nodes[node_rk] should refer to the RK component.

But why does cipher.nodes[node].nodes[2] (which should be MixColumns) show a const? MixColumns is a WordSBoxCipher, which does NOT have a const attribute. So where does that value come from?

Looking at c1 dump: for node 2 (FwdRound), sub node 2 is MixColumns with const=0x13198a2e03707344. That's weird because WordSBoxCipher doesn't have const. But the dump checks getattr(node, 'const', None). If the object has a const property (like RoundkeyXOR_CVL), it returns it. WordSBoxCipher doesn't. Unless... one of the nodes inside MixColumns (the LinearLayer_CVL) doesn't have const either. So where does const come from?

Wait, looking at the top-level node 1: RK, const=0x97779021b38e7fa1 — that's the initial whitening w0, correct: w0_int = _bytes_to_int(w[0]) = 0x97779021b38e7fa1. That matches.

Node 2: FwdRound, const=None. Its sub-node 2 is MixColumns with const=0x13198a2e03707344. That means getattr on MixColumns returned a const. But WordSBoxCipher inherits from Cipher? No, WordSBoxCipher inherits WordBasedCipher and SBoxCipher, which inherits Cipher. Cipher has no const attribute. WordSBoxCipher has no const attribute. So how does MixColumns have const?

Unless MixColumns inside the FwdRound is NOT the WordSBoxCipher I built! It might be a LinearLayer_CVL that accidentally got const? No, LinearLayer_CVL also doesn't have const.

Wait — could it be that my _mix_columns function returns an object that gets modified? No.

Actually, I think getattr on MixColumns (a WordSBoxCipher) checks for const. But maybe the WordSBoxCipher (as a subclass of Cipher) inherits from Component indirectly? No, Cipher is not a Component. Cipher has no const.

Wait, let me look at the dump more carefully. For node 2 (FwdRound): 2: MixColumns, const=0x13198a2e03707344

But node 5 is also MixColumns at the top level with const=None. So the MixColumns INSIDE the FwdRound has const, while the standalone MixColumns (node 5) doesn't. How can the same object deepcopy into one with const and one without? Unless const was set on the original mixcolumns object BEFORE adding it to fwd_round.

But I never set const on mixcolumns! The only place I set constants is on node_rk and node_rc inside the main loops. Wait! Could I have accidentally mixed up node_rk and node_rc with node_mix? Let me check the class init code:

In FwdRound:

node = fwd_round.add_subcipher(subcells, ...)
node = fwd_round.add_subcipher(mixcolumns, ...)
node_rk = fwd_round.add_subcipher(rk_xor(0), ...)
node_rc = fwd_round.add_subcipher(rk_xor(0), ...)
node = fwd_round.add_subcipher(perm, ...)
So node_rk index = 3, node_rc index = 4 in fwd_round. MixColumns is index 2. In the main loop:

cipher.nodes[node].nodes[node_rk].const = rk_int[r]
cipher.nodes[node].nodes[node_rc].const = rc_int[r]
node_rk = 3, node_rc = 4. So setting const on indices 3 and 4. That should be the two RK components. Why does sub node 2 (MixColumns) get const? Unless node_rk or node_rc is 2 instead of 3/4. Did I maybe redefine node_rk somewhere? Let me re-read the init code.

I need to check the actual file content. Let me read the current state of the FwdRound construction.

Actually, wait — the dump shows node 2 inside FwdRound as MixColumns with const. And node 3 is RK, node 4 is RK with const=0x0. Wait node 4 has const=0x0? The dump says 4: RK, const=0x0. That means node_rc (index 4) has const=0, but node_rk (index 3) has const=0x6dd387874a0b52ce. So node_rk.const was set correctly to rk[0], and node_rc.const was NOT set (still 0). But we expected node_rc.const to be rc[0]! Let me check: rc[0] from tables is 0x447370032e8a1913. But node_rc.const is 0x0. So the constant was NOT set on node_rc! That means the line cipher.nodes[node].nodes[node_rc].const = rc_int[r] failed, OR node_rc points to a different node.

Wait, but the dump shows node 2 (MixColumns) has a const value 0x13198a2e03707344. That value is actually rc[0] reversed? rc[0] bytes (LSB-first) = [0x44,0x73,0x70,0x03,0x2e,0x8a,0x19,0x13]. As integer = 0x13198a2e03707344. YES! That's rc[0] int. So somehow the const was set on MixColumns (index 2) instead of the second RK (index 4).

This means node_rc must be 2! How can node_rc be 2? Because maybe node_rc was overwritten by a later assignment before the loop? Let me check the code flow in init. In the FwdRound construction:

node = fwd_round.add_subcipher(
    subcells, [(fwd_round.IN, (i, i)) for i in range(state_nibbles)]
)
node = fwd_round.add_subcipher(
    mixcolumns, [(node, (i, i)) for i in range(state_nibbles)]
)
node_rk = fwd_round.add_subcipher(
    rk_xor(0), [(node, (i, i)) for i in range(state_nibbles)]
)
node_rc = fwd_round.add_subcipher(
    rk_xor(0), [(node_rk, (i, i)) for i in range(state_nibbles)]
)
node = fwd_round.add_subcipher(
    perm, [(node_rc, (i, i)) for i in range(state_nibbles)]
)
Wait a second! Line 3 adds rk_xor(0) connected to node (the MixColumns output). So node_rk = index 3. Then line 4 adds rk_xor(0) connected to node_rk (the first RK output). So node_rc = index 4. Then line 5 adds perm connected to node_rc. So node = index 5. But after that, fwd_round.add_output uses node (index 5). Good.

So node_rk=3, node_rc=4. So why does the dump show node 2 (MixColumns) having const set? Unless... somewhere in the main loop I mistakenly set const on index 2 instead of index 4. Let me re-read the main loop code carefully.

In my __init__, after building FwdRound:

        # a forward keyed rounds
        for r in range(ra):
            node = cipher.add_subcipher(
                fwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[node_rk].const = rk_int[r]
            cipher.nodes[node].nodes[node_rc].const = rc_int[r]
Wait — but node is reassigned in the loop from the previous node (which was the whitening RK). The new node returned is the index of the deep-copied FwdRound inside cipher. Then cipher.nodes[node] is the deep-copied FwdRound. And cipher.nodes[node].nodes[node_rc] should be the RK at index 4.

But the dump clearly shows node_rc got const 0x0 and MixColumns got const rc_int[0]. Something is very wrong with node_rc assignment. Could it be that node_rc is being shadowed by another variable named node_rc later in the file? Let me search all occurrences.

In the init, I also define a node_rc for bwd_round. That might shadow the fwd_round variable? But the loop for forward rounds is before BwdRound definition, so node_rc in the loop refers to the forward_round's node_rc. However, Python closures/scope: variables in the same function scope are shared. If I define node_rc in BwdRound after the loop, it doesn't affect the loop because the loop already executed before BwdRound definition.

Actually in Python, the function scope is the entire function. So node_rc is a single variable in the function. If I set node_rc = bwd_round.add_subcipher(...) later, it overwrites the previous node_rc. But the loop that uses node_rc was executed BEFORE the bwd_round assignment. So at loop execution time, node_rc held the fwd_round value. After the loop completes, node_rc gets overwritten by the bwd_round value. But the loop already used the old value. So that's not the issue for the forward rounds.

Wait, no: I use cipher.nodes[node].nodes[node_rc] inside the loop. At execution time, node_rc is whatever it was at that moment. If the loop runs after BwdRound definition? No, the loop is defined before BwdRound in the source code. The BwdRound is built after the middle and before the backward round loops? Let me check the order in my __init__:

Looking back at the edited code:

Builds cipher = WordSBoxCipher(...)
Builds subcells
Builds mixcolumns
Builds perm and inv_perm
Builds fwd_round
Builds bwd_round
Defines middle_stage helper
Assembles cipher:
whitening
for r in range(ra): add fwd_round, set consts using node_rk, node_rc
middle h0 + perm
for r in range(rb): add fwd_round, set consts
middle hxor + sub
for r in range(rb): add bwd_round, set consts using node_rc2 and node_rk2? Wait I defined node_rc and node_rk inside bwd_round but named them node_rc and node_rk too! And then set consts: cipher.nodes[node].nodes[node_rc].const = rc_prime_int[r] cipher.nodes[node].nodes[node_rk].const = rk_int[r]
But node_rc and node_rk at that point refer to the BwdRound's node_rc and node_rk! Because BwdRound was constructed after FwdRound, and node_rc was overwritten.
Wait! In my constructor I did NOT use distinct variable names for the backward round node indices. I just reused node_rc and node_rk from the forward round. Since Python function scope is lexical but execution is top-down, the values of node_rc and node_rk when the forward-round loop executes are indeed the forward-round indices (3 and 4). Then later, after BwdRound is built, node_rc and node_rk get overwritten. But the forward-round loop already ran, so it used the correct values. So the forward rounds should be fine.

Wait — no. Let me re-read my source code. I edited BwdRound to use:

        node_rc = bwd_round.add_subcipher(
            rk_xor(0), [(node, (i, i)) for i in range(state_nibbles)]
        )
        node_rk = bwd_round.add_subcipher(
            rk_xor(0), [(node_rc, (i, i)) for i in range(state_nibbles)]
        )
Yes, node_rc and node_rk are reassigned here. But this happens AFTER the forward-round loops in the source? Let me check the order in my __init__:

The code order is:

build fwd_round
build bwd_round
define middle_stage
assemble cipher, which includes:
forward loop (ra)
middle h0 + perm
forward loop (rb)
middle hxor + sub
backward loop (rb) — uses node_rc/node_rk from bwd_round
middle inv + h1 + mix + sub
backward loop (ra) — uses node_rc/node_rk from bwd_round
So node_rc and node_rk are overwritten by bwd_round BEFORE the backward loops, but AFTER the forward loops. So forward loops use the correct fwd_round values, backward loops use the correct bwd_round values. Good.

But the dump clearly shows that for node 2 (FwdRound), the MixColumns (index 2) has const=rc[0]. How could that happen? Let me look at the code more carefully. Maybe I accidentally set const on cipher.nodes[node].nodes[node_rc] where node_rc was actually the index of mixcolumns? No, in FwdRound, mixcolumns is added as the second subcipher (index 2). Then node_rk is the third (index 3), node_rc is the fourth (index 4). Unless fwd_round.add_subcipher(mixcolumns, ...) returned index 3 because subcells inside fwd_round had more nodes? Let's count inside fwd_round:

Inside fwd_round, the subcomponents are added:

subcells (a WordSBoxCipher with SBox components inside)
mixcolumns (a WordSBoxCipher with MixColumns inside)
rk_xor(0)
rk_xor(0)
perm
But fwd_round is itself a WordSBoxCipher. When adding subcells to it, add_subcipher deepcopies subcells and appends it. subcells is a WordSBoxCipher with nodes = [IN, SBox, SBox, ..., SBox, OUT]. But when fwd_round.add_subcipher(subcells, ...) is called, does it insert the whole subcells cipher as a single node in fwd_round.nodes? Or does it flatten the subcipher?

Looking at Cipher.add_subcipher: it deepcopies the subcipher and appends it as a single node. So fwd_round.nodes after adding subcells has indices: 0=IN, 1=subcells (the WordSBoxCipher). Then adding mixcolumns -> index 2. Then adding rk_xor(0) -> index 3. Then adding rk_xor(0) -> index 4. Then adding perm -> index 5. So node_rk=3, node_rc=4. Correct.

But wait, the dump shows the FwdRound's sub-nodes as: 0: FwdRound.IN 1: SubCells 2: MixColumns 3: RK 4: RK 5: Permutation 6: FwdRound.OUT

So node_rk=3, node_rc=4. Then in the loop, cipher.nodes[node].nodes[4].const = rc_int[r] should set node 4's const. But the dump shows node 4 has const=0x0 and node 2 has const=0x13198a2e03707344. This means the assignment cipher.nodes[node].nodes[node_rc].const = rc_int[r] somehow hit node 2 instead of node 4. But node_rc is variable name 4. Unless...

Wait — the dump shows const=0x13198a2e03707344 on node 2 (MixColumns). Node 2 is the index of MixColumns inside FwdRound. But node_rc is 4. How could writing to index 4 affect index 2? Unless the variable node_rc is 2. But in the code I assigned node_rc = fwd_round.add_subcipher(rk_xor(0), ...). That should be 4.

UNLESS — after building BwdRound, node_rc got reassigned but the forward loop is somehow using the new node_rc? But as I reasoned, the forward loop executes before BwdRound is built. Python executes top-down. The forward loop is in the "assemble" section, which is after the BwdRound definition in the source! Let me check the current code order in the file.

Actually, looking back at my edit, the order in init might be:

build cipher, subcells, mixcolumns, perm, inv_perm
build fwd_round
build bwd_round
assemble
Inside assemble:

whitening
for r in range(ra): add fwd_round, set node_rk and node_rc consts.
So node_rk and node_rc used in the forward loop are the variables set during fwd_round construction. The BwdRound is built in step 3, but the forward loop in step 4 executes after step 3. So by the time the forward loop runs, node_rc has already been overwritten by the BwdRound construction! Because Python executes statements sequentially.

YES! That's the bug! In Python, execution is sequential. After building fwd_round, I build bwd_round, which reassigns node_rc and node_rk. Then when I reach the forward loop in the assembly, node_rc and node_rk refer to the BWDROUND indices, not the FWDROUND indices! The forward loop then sets constants on the wrong nodes inside the FwdRound deep copies! It sets constants on the BwdRound's node_rc/node_rk positions inside FwdRound (which don't exist or map to different components). Node BwdRound's node_rc and node_rk are different indices from FwdRound's. In BwdRound, node_rc and node_rk might be 2 and 3 (since BwdRound has inv_perm -> rc -> rk -> mix -> sub). Let's check BwdRound indices:

0: BwdRound.IN
1: inv_perm
2: RK (node_rc in bwd)
3: RK (node_rk in bwd)
4: MixColumns
5: SubCells
6: BwdRound.OUT
So node_rc = 2 (the first RK in BwdRound). When the forward loop does cipher.nodes[node].nodes[node_rc].const = rc_int[r], it sets const on FwdRound's node 2 (MixColumns) instead of FwdRound's node 4 (the second RK). And node_rk = 3 (second RK in BwdRound) maps to FwdRound node 3 (the first RK). So the forward round sets:

FwdRound node 3 (first RK) const = rk_int[r] ✓ (by coincidence correct index?) Wait FwdRound node 3 is the first RK. BwdRound node 3 is the second RK. So node_rk = 3. The forward loop sets cipher.nodes[node].nodes[3].const = rk_int[r]. That sets FwdRound's first RK. Correct! Because FwdRound's first RK is at index 3 (same as BwdRound's second RK index). Lucky coincidence! But node_rc = 2 sets FwdRound's node 2 (MixColumns) to rc_int[r]. That's wrong. And node_rc=2 in FwdRound is MixColumns, while node_rc=2 in BwdRound is the first RK. So MixColumns gets the round constant applied to it!
That explains exactly the dump: MixColumns inside FwdRound has const=rc[0], and the second RK inside FwdRound has const=0 (since BwdRound's node_rk=3 corresponds to FwdRound's first RK, not second). So node 4 (second RK in FwdRound) never gets set.

And the backward loops use node_rc and node_rk which now correctly refer to BwdRound indices. So backward rounds are correct.

So the fix is simple: use different variable names for the forward round and backward round node indices. For example, fwd_rk_index, fwd_rc_index for the forward round, and bwd_rc_index, bwd_rk_index for the backward round. Or store them in a tuple.

I need to edit the init to use distinct variable names for the indices inside fwd_round and bwd_round.

Similarly, the middle_stage uses rk_xor which creates new instances each time, and doesn't need stored indices.

Let me fix the code.

Actually, the cleanest way is to store fwd_node_rk, fwd_node_rc and bwd_node_rc, bwd_node_rk as separate variables, and use them in the respective loops.

Let me read the current code and make the edits.

Also, for the forward round, node_rk was the third subcipher and node_rc was the fourth. But since node_rc got overwritten by BwdRound's node_rc=2, the second RK in FwdRound (index 4) was never touched. So the forward rounds essentially applied RK without RC (MixColumns got RC by mistake). That explains why test vectors fail.

Fix: rename fwd indices.

I also need to check if node variable inside fwd_round construction is later used. It is overwritten by node = fwd_round.add_subcipher(perm, ...) which is fine. For the backward round, similar. The variables node_rk and node_rc are the ones causing trouble. I'll rename them.

Let me read the current code to make precise edits. The root cause is a variable name clash: node_rc and node_rk are set when building bwd_round, overwriting the indices from fwd_round. When the forward loops later run they write round constants into the wrong inner nodes (MixColumns gets the constant instead of the RK node). I need to rename the forward and backward indices. Let me read the exact current code and fix it.

The bug is clear: node_rk and node_rc are overwritten by the bwd_round construction, so the forward loops use the wrong indices. Fix: use distinct variable names for the forward and backward round inner node indices.

Specifically:

Forward round: fwd_rk = 3, fwd_rc = 4
Backward round: bwd_rc = 2, bwd_rk = 3
I'll replace node_rk with fwd_rk and node_rc with fwd_rc inside the forward round construction, and update the loops accordingly. Similarly for backward round: bwd_rc, bwd_rk.

Let me edit the file.

... (slight structural changes)

... (tests with test vectors)

All six test vectors pass! Excellent. Now I need to:

Update the doctests in the class docstring to include all test vectors.
Add a modeling test (optional solver) as per README guidelines.
Add a get_trail assertion test (optional solver).
Make sure the import path works properly (civerly.cipher_implementations.blink).
Clean up the code and docstrings.
Also, I should update the todo list and verify there are no syntax errors or issues in the file.

Let me read the current docstring and update it.

Current docstring has four test vectors (64a, 64b, 128a, 128A). I should add 128b and 128B.

Also, the modeling test currently says it requires SCIP (optional), but the docstring just says <BLANKLINE> and .... I should make it a real doctest that just builds the model (which doesn't need a solver). But model() just generates constraints and writes files; it might print something. I can make it a simple test that generates the MILP model and checks it returns something. Or I can use cipher.model(model_options) with # optional - scip and check that it doesn't raise an error. But for a doctest, I want it to run without solver. The model() call itself doesn't require a solver; analyse() does. So I can use model() without solver.

Actually, model() generates the MILP or SAT model and writes it to file. It does call model_options.milp_solver.process_solution_file only if analyse() is called. Let me check: in cipher.py model() just calls _model_milp or _model_sat. For _model_milp, it writes the .mps file. No solver invocation. So cipher.model(model_options) is safe even without a solver.

But it uses model_options.path. If path is a tempdir, it's fine. And model_options includes milp_solver=SCIP_CVL() or whatever. SCIP_CVL just a wrapper, no actual execution until solve(). So cipher.model(model_options) should work without the solver installed. But the doctest might need # optional - scip because SCIP_CVL may not be importable? Actually SCIP_CVL is imported from civerly.solvers and should be available. Even if scip isn't installed, the class exists but invoke will fail. Since model() doesn't call invoke, it's safe. But to be safe, I can mark it optional. Let me just include # optional - scip for good measure.

Wait, the README suggests using analyse optional tagged. Let me keep the optional modelling tests.

Also I need to import Path from pathlib for model tests.

Let me also consider reducing the modeling test to just R=2 or something light to keep doctest fast. But for cipher.model(), it generates the full MILP. For Blink-64a, total rounds = a+b+... = 2+3+3+2 = 10 reflections etc. That's a decent size but not huge. Model generation should be fast. I can use a small variant. Or just use the full cipher and tag optional - scip so it won't run in standard tests.

Let me now update the docstring to include all test vectors, add modeling tests, and add a SAT modelling test too optionally.

Actually, the README minimum test set:

One encryption test with a known test vector. (I'll include several)
One test that runs analyse or model with a supported solver (optional tag).
One test that calls get_trail and asserts no unnamed components. (requires solver)
For the get_trail test, since it requires solving, I'll tag it optional.

But actually, I can test cipher.model() and then is_valid and naming checks without solver. For "Unnamed Component" check, I can inspect str(cipher) or iterate nodes to ensure none are unnamed. That doesn't require a solver. Let me do that.

Let me also check: does the cipher support both bitwise and wordwise modeling? It's a WordSBoxCipher with wordsize=4, so wordwise MILP is supported. But I should verify that model() works with GRANULARITY.WORDWISE.

Let me now update the file.

First, I need to verify the file imports and top-level. Let me read the beginning.

The MILP model generation fails because LINEAR_LAYER_MODELING is not set. The default is None for bitwise modeling? Actually in the template from present.py, they don't set linear_layer_modeling for bitwise MILP because PRESENT's linear layer is a bit permutation. For Blink, the linear layer is a full-state LinearLayer_CVL. For bitwise MILP, I need to specify a linear layer modeling option.

Let me check which options are available. The README says for bitwise MILP with LinearLayer_CVL, you may need to specify LINEAR_LAYER_MODELING.MORE_DUMMIES or similar. Let me check model_options.py for defaults.

I can set linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES which is safe and general. Let me test that.

I need to verify what the MILP model output looks like to know the exact string. Let me run the test again. Also need to update the test script. Also need to include a # optional - scip tag. Actually model() doesn't need scip to generate the model, but the tag is used by doctest runner to skip if scip isn't present. Since the model generation itself doesn't invoke scip, maybe I should tag it optional but it doesn't matter. I'll keep the tag because the README examples use it.

Let me test model generation and see the output string.

... (test of modeling capabilities)

model() prints a message and returns the MILP program. The output includes "25120 variables and 26753 constraints were written to ..." and then the program representation. In a doctest, exact numbers are fragile. I should use # optional - scip and match only part of the output or just test that no exception is raised.

Actually, the model() call triggers messages because it uses existing files in the shared temp dir from previous runs? In a clean tempdir, it wouldn't print those warnings. And it writes to path / (cipher.name + ".mps"). The .model() call returns self.milp which prints as "Boolean Program (minimization, 25120 variables, 26753 constraints)".

For a doctest, I can just do:

sage: with tempfile.TemporaryDirectory() as tmpdir:  # optional - scip
....:   model_options = MODEL_OPTIONS(...)
....:   blink.model(model_options)
Boolean Program (minimization, ... variables, ... constraints)
But the exact variable counts might differ if constraints change slightly. Better to just check that it runs without error and use ... wildcards. But doctest ... only works inside the expected output block, not for arbitrary output.

Actually, I can just skip the output assertion by using a generic ... after the call. Or I can simplify the doctest to just check isinstance(blink.model(model_options), MixedIntegerLinearProgram). But doctest matching of isinstance return True is easy: True.

Actually, let me just write a doctest that checks the model returns something truthy and that no exception is raised, by asserting the result type.

Like:

sage: from civerly.cipher_implementations.blink import BLINK_CVL
sage: from civerly.model_options import *
sage: import tempfile
sage: blink = BLINK_CVL(64, 64, name="blink-model")
sage: with tempfile.TemporaryDirectory() as tmpdir:  # optional - scip
....:   model_options = MODEL_OPTIONS(
....:     cryptanalysis=CRYPTANALYSIS.DIFFERENTIAL,
....:     optimization=OPTIMIZATION.MILP,
....:     granularity=GRANULARITY.BITWISE,
....:     linear_layer_modeling=LINEAR_LAYER_MODELING.MORE_DUMMIES,
....:     sbox_modeling=SBOX_MODELING.CONVEX_HULL,
....:     milp_solver=SCIP_CVL(),
....:     path=Path(tmpdir))
....:   milp = blink.model(model_options)
....:   milp is not None
True
That avoids matching the exact output string. And naming check can be a simple doctest that iterates nodes.

Let me also think about adding a wordwise modeling doctest since the cipher is a WordSBoxCipher. That might be nice but not essential. I'll stick to one modeling test.

For the SAT modeling test, since SAT doesn't support wordwise, and we already have a MILP test, maybe I can skip SAT.

But the README suggests having at least one test with analyse or model. I'll include the MILP model test and a naming check.

Let me also ensure the docstring includes all 6 test vectors. Currently it has 4 (64a, 64b, 128a, 128A). I need to add 128b and 128B.

Now I need to decide whether the class should also support a R parameter for reduced rounds (like other CiVerLy ciphers). The README template includes R. For simplicity and since Blink has fixed reflector structure, I'll keep it without R, but provide a default key/tweak so constructing BLINK_CVL(64, 64) gives a valid cipher (with zero key, zero tweak, which the paper warns about but for modeling it's fine). Actually for modeling, the trail is independent of the key/tweak values. So BLINK_CVL(64, 64) is enough.

Let me write the final docstring.

Actually, I realize there might be a doctest issue with the # optional - scip tag: when doctest runner sees # optional - scip, it skips the whole block if scip is unavailable. Since we're just calling model(), not analyse(), scip isn't needed. But we still import SCIP_CVL(), which requires the scip solver class. That class should exist in civerly.solvers regardless of whether scip is installed. So SCIP_CVL() is just creating an instance of the wrapper. It won't fail. The # optional - scip tag is therefore unnecessary for model(), but harmless. I'll keep it to match convention.

Wait, looking at other files like present.py, they mark modelling with # optional - scip even though model() doesn't need the solver. It's treated as optional because it may be heavy. I'll keep it.

Now let me rewrite the class docstring. I'll use the edit tool to replace the docstring portion.

I also need to check for any stray issues: the _generate_round_key function signature at module level has a call to ra_rb which is defined later. Python resolves at call time, so it's fine. Actually I see _generate_round_key uses ra_rb(state_bytes, key_bytes) where ra_rb is a function defined at module level. Since the call happens inside __init__ after module load, ra_rb is defined. Good.

Let me double check the module has no syntax errors by importing it.

... (additional doctests for modeling)

# Stopped because of to many tokens

please continue with the next steps
The user asked me to continue with the next steps. Based on my previous work, the next steps are:

Validate the doctests by running the file through sage doctests.
Ensure everything is clean and working.
Let me run the doctests to verify all six encryption test vectors, the naming check, and the optional modeling test work.

I'll validate the implementation by running the doctests.

sage -t src/civerly/cipher_implementations/blink.py 2>&1 | tail -n 40
      tweak=0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef)
Exception raised:
    Traceback (most recent call last):
      File "/private/var/tmp/sage-10.7-current/local/lib/python3.13/site-packages/sage/doctest/forker.py", line 733, in _run
        self.compile_and_execute(example, compiler, test.globs)
        ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      File "/private/var/tmp/sage-10.7-current/local/lib/python3.13/site-packages/sage/doctest/forker.py", line 1157, in compile_and_execute
        exec(compiled, globs)
        ~~~~^^^^^^^^^^^^^^^^^
      File "<doctest civerly.cipher_implementations.blink.BLINK_CVL[18]>", line 1, in <module>
        blink = BLINK_CVL(Integer(128), Integer(256), key=key,   tweak=Integer(0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef))
                                                          ^^^
    NameError: name 'key' is not defined
**********************************************************************
File "src/civerly/cipher_implementations/blink.py", line 426, in civerly.cipher_implementations.blink.BLINK_CVL
Failed example:
    hex(vec_to_int(blink(int_to_vec(0, 128))))
Exception raised:
    Traceback (most recent call last):
      File "/private/var/tmp/sage-10.7-current/local/lib/python3.13/site-packages/sage/doctest/forker.py", line 733, in _run
        self.compile_and_execute(example, compiler, test.globs)
        ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      File "/private/var/tmp/sage-10.7-current/local/lib/python3.13/site-packages/sage/doctest/forker.py", line 1157, in compile_and_execute
        exec(compiled, globs)
        ~~~~^^^^^^^^^^^^^^^^^
      File "<doctest civerly.cipher_implementations.blink.BLINK_CVL[19]>", line 1, in <module>
        hex(vec_to_int(blink(int_to_vec(Integer(0), Integer(128)))))
                       ^^^^^
    NameError: name 'blink' is not defined
**********************************************************************
1 item had failures:
  18 of  29 in civerly.cipher_implementations.blink.BLINK_CVL
    [28 tests, 18 failures, 0.25s wall]
----------------------------------------------------------------------
sage -t --warn-long 5.0 --random-seed=211260155715745006038143089118291617847 src/civerly/cipher_implementations/blink.py  # 18 doctests failed
----------------------------------------------------------------------
Total time for all tests: 0.3 seconds
    cpu time: 0.2 seconds
    cumulative wall time: 0.3 seconds
Features detected for doctesting: 
The doctests failed because variables like key, tweak, blink defined in one block are not visible in subsequent blocks because the doctest runner compiles each sage:/....: block as a separate exec(). In Sage doctests, the state is shared across examples within the same docstring, but the issue here is that I probably split the key assignment and blink = BLINK_CVL(...) across different sage: prompts without using ....: continuation, or the key variable is being defined in a block where the subsequent blink = BLINK_CVL(...) block doesn't see it.

Actually looking at the error: 'key' is not defined. In the docstring, the key assignment is likely a separate sage: prompt, and then the next sage: prompt tries to use key. Wait, in Sage doctests, variables are carried over between examples? The standard doctest runner runs each sage: line as a separate statement, but the namespace is the same test.globs dict, so key defined in one example should persist to the next. However, there might be an issue with hex(vec_to_int(...)) expectations.

Wait, looking at the error: NameError: name 'key' is not defined. This is at line 426, which is the tweak=... line in the 128b test vector. That means the previous key variable assignment was somehow lost or not executed.

Wait, let me look at the traceback: File "<doctest civerly.cipher_implementations.blink.BLINK_CVL[18]>", line 1, in <module> — example index 18. If examples are 0-indexed, example 18 is the 19th example. Let me count.

Actually, the problem might be that some test vectors failed earlier and the doctest runner reports the first failure. But there are 18 failures out of 29 tests. That suggests many tests failed. The first failure might be earlier.

Wait, many failures could also be due to hex() output format. In Python, hex() returns '0x...', but in Sage, hex() might return a Sage Integer? No, hex() is Python's built-in.

Actually, I see the first reported error is about key not defined. Let's look at the exact docstring text around line 426. I need to read the file around that area.

... (doctets failed due to syntactical errors)

The doctest runner is failing because each sage: block is executed independently in some contexts, and the key variable is not persisting across blocks. Wait, actually in standard Python doctests, the namespace is shared across examples. But in Sage, the doctest compiler may treat sage: as a separate exec call, but the globals dict is reused. So key should persist.

Wait, looking at the error again: name 'key' is not defined. This is at example [18]. Let's count examples:

0: sage: from civerly.cipher_implementations.blink import BLINK_CVL 1: sage: from civerly.util import int_to_vec, vec_to_int 2: sage: key = ... 3: sage: blink = BLINK_CVL(...) 4: sage: hex(...) 5: sage: key = ... 6: sage: blink = BLINK_CVL(...) 7: sage: hex(...) 8: sage: key = ... 9: sage: blink = BLINK_CVL(...) 10: sage: hex(...) 11: sage: key = ... 12: sage: blink = BLINK_CVL(...) 13: sage: hex(...) 14: sage: key = ... 15: sage: blink = BLINK_CVL(...) 16: sage: hex(...) 17: sage: key = ... 18: sage: blink = BLINK_CVL(...) 19: sage: hex(...)

Wait, example 18 is the blink = BLINK_CVL assignment for the 128A variant (after the 128b vector). But the error says name 'key' is not defined at the line tweak=.... But the assignment key = ... is the previous example (17). In standard doctests, variables should persist. However, the Sage doctest format might require that sage: lines not be separated by blank lines? Or maybe because of blank lines between examples, the state resets? Actually in standard doctests, blank lines do NOT reset globals. But in Sage, maybe the parser behaves differently?

Wait, let me look at the actual docstring. I see blank lines between sage: hex(...) and the next sage: key = .... That's normal. Maybe the problem is that the hex() output '0x...' fails to match, causing an exception, and then the globals are reset after an exception? In doctests, if an example fails, subsequent examples in the same block are still attempted but the failure count accumulates. But if a previous example failed, the globals might still be present. Actually failures don't clear globals.

But there are 18 failures out of 29 tests. That means many examples are failing. The first failure is likely at the first hex() call because of output mismatch. Let me check what hex() returns in Sage vs Python.

In Python:

>>> hex(0xa4a0d10502be846e)
'0xa4a0d10502be846e'
In Sage, hex() is the same built-in function. The output should match. But maybe vec_to_int(blink(int_to_vec(0, 64))) returns a Sage Integer, and Python's hex() on a Sage Integer returns... let me test.

Actually, int_to_vec(0, 64) in CiVerLy returns a list of 0/1 ints. blink() returns a list. vec_to_int() converts that list to an integer. Is vec_to_int using Python ints or Sage Integers? It probably returns a Python int.

Wait, there are 18 failures. Could the first failures be happening because the first hex() output is correct, but the next hex() output is also correct... but maybe the key assignments are failing because they are multi-line? No, multi-line assignments with \ continuation are standard.

Let me run sage -t with verbose output or run a minimal python test that mimics the doctest to see the actual outputs.

Wait, maybe the problem is that sage: lines that are separated by blank lines but part of the same doctest block are fine. But what if the output '0xa4a0d10502be846e' is not matching because of some hidden whitespace? Or because hex() returns a string in Python but maybe a different representation in the environment?

Actually, Sage's doctest runner is known to strip trailing whitespace and compare. It should match. Let me check the first failure more carefully. The error dump only shows the first failure. It says NameError: name 'key' is not defined at example [18]. This is for the 128A test vector (the one with the longer key). Example 17 is key = .... Example 18 is blink = BLINK_CVL(..., key=key, ...). If key is not defined, then example 17 must have failed silently or not been executed.

Wait, I see a possible issue: in the docstring, the key assignments use \ continuation. The sage: prompt and ....: continuation should work. But if any key = ... line has a syntax error, that example would fail and the variable wouldn't be defined. But why would there be a syntax error?

Let me write a small Python script that executes the exact docstring text to see what's going on. I'll extract the docstring and run the examples.

Actually, a better idea: run sage -t --verbose or look at the first failing example. The output says 1 item had failures: 18 of 29 in ... [28 tests, 18 failures]. That means there are 29 examples total, and 18 of them failed. The first failure is example 18. That means examples 0-17 passed. So the first two test vectors (examples 2-4: 64a key, blink, hex; examples 5-7: 64b key, blink, hex; examples 8-10: 128a key, blink, hex; examples 11-13: 128b key, blink, hex; examples 14-16: 128A key, blink, hex) all passed. Then example 17 (128B key) failed. Wait, example 17 is key = ... for 128B. If example 17 failed, example 18 (which uses key) fails with NameError.

Why would example 17 fail? The 128B key assignment is the longest. Maybe there's a line continuation issue or a typo in the key constant. Let me compare the key constant in the docstring with the test vectors.

The 128B test vector key from the paper: d6a102d888a467e4d1d7dec33a246943e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a0697779021b38e7fa15e2b66350517f80f2961c648d578bae174d70cb769c30a45cc40300fe8a342ca57a0bd0251ae39b621b8f104904374bbd6a102e234a664e421b8f104904374bbd6a102d888a666e428962a4c96893eda752c17026a6395c2d6963be43b2fc10813d73f5a4a48d28d

Wait, the 128A key is exactly the same as the 128B key? No, 128A uses the shorter key (128a has ra=2, rb=2? No let's recheck).

Actually, looking at the docstring:

64a: key = 40 bytes (0xd6a1...)
64b: key = 40 bytes (same as 64a)
128a: key = 80 bytes (0xd6a1...5e2b...)
128A: key = 120 bytes (0xd6a1...2896...)
128b: key = 80 bytes (0xd6a1...21b8...)
128B: key = 120 bytes (0xd6a1...2896...d696...)
Wait, in the docstring:

Example 8-10 (128a): key has 80 bytes (lines 387-391)
Example 11-13 (128b): key has 80 bytes (lines 397-401) — wait, line 397 starts key = 0xd6a102d8... and goes through line 401. It ends with 21b8f...a666e4. That's the same as the 128a key. No, 128a key ends with 21b8f104904374bbd6a102d888a666e4, and 128b key also ends with the same thing. Wait, looking at documentation/blink test vectors.md, the 128b key is the same as 128a key? Let me check.
Actually, looking at the paper, 128a and 128b have the same key length (80 bytes) but different tweak length (128 vs 256). So the key is indeed the same for 128a and 128b. Good.

Similarly, 128A and 128B have the same key length (120 bytes) but different tweak length. So the key is the same. Good.

So example 17 is key = ... for 128B (which is the same key as 128A). If example 14-16 passed (128A), then example 17 should also pass. Why would it fail?

Wait, the key for 128A in the docstring is:

0xd6a102d888a467e4d1d7dec33a246943 \
  e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
  97779021b38e7fa15e2b66350517f80f2961c648d578bae174d70cb769c30a45 \
  cc40300fe8a342ca57a0bd0251ae39b621b8f104904374bbd6a102e234a664e4 \
  21b8f104904374bbd6a102d888a666e428962a4c96893eda752c17026a6395c2 \
  d6963be43b2fc10813d73f5a4a48d28d
And the key for 128B in the docstring is:

0xd6a102d888a467e4d1d7dec33a246943 \
  e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
  97779021b38e7fa15e2b66350517f80f2961c648d578bae174d70cb769c30a45 \
  cc40300fe8a342ca57a0bd0251ae39b621b8f104904374bbd6a102e234a664e4 \
  21b8f104904374bbd6a102d888a666e428962a4c96893eda752c17026a6395c2 \
  d6963be43b2fc10813d73f5a4a48d28d
Wait, these are exactly the same! The key for 128A and 128B should indeed be identical because they have the same key length. So why did example 17 fail?

Maybe it's not a key assignment issue. Perhaps example 17 didn't fail; maybe the failure count starts from example 18 because example 17 is key = ... but it's not actually numbered as a separate test if it has no output? No, in doctests, every sage: line is an example.

Wait, looking at the error output again:

1 item had failures:
  18 of  29 in civerly.cipher_implementations.blink.BLINK_CVL
    [28 tests, 18 failures, 0.25s wall]
"18 of 29" means example index 18 failed (0-indexed). That means examples 0 through 17 passed. Example 18 is:

sage: blink = BLINK_CVL(128, 256, key=key, \
....:   tweak=0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef)
This is the 128B test vector. It uses key which was defined in example 17. But example 17 passed, so key should be defined. Unless there's a subtlety: maybe the \ continuation in example 18 causes the key=key to be parsed incorrectly? No.

Wait, maybe the problem is blank lines in the docstring? In some doctest parsers, blank lines within an example can cause issues, but Sage handles them.

Actually, I might be misreading the failure. There could be 18 failures total, but the first one is example 18. That means examples 0-17 passed. So example 17 passed. Then example 18 failed with NameError: name 'key' is not defined. That's weird.

Could the problem be that the with tempfile.TemporaryDirectory() as tmpdir: block from the previous doctest (if it appears before example 18) resets the namespace? No, the modeling test is at the end, after example 18.

Wait, there are 29 examples, and 18 failures. The first failure is example 18. So examples 0-17 passed. Examples 18-29 (except maybe some correct ones) failed. That means examples 18, 19, 20, ... failed.

If example 18 failed with NameError('key'), then examples 19 and onwards would also fail because they also use blink or other variables. But example 20 is sage: key = ... again, which wouldn't need blink. But example 20 is just a new key assignment. If example 18 fails, it doesn't clear globals, so example 19 (hex(...)) fails because blink isn't defined? Actually blink from example 14 might still be in globals. But example 19 tries blink(int_to_vec(0, 128)) with tweak from 128B? No, example 19 is hex(vec_to_int(blink(int_to_vec(0, 128)))). If blink from example 16 is still defined (128A variant with 128-bit state, 128-bit tweak), then hex(...) would return the wrong ciphertext '0x8244...' instead of '0x8dc4...'. So example 19 would fail with a wrong output. Similarly example 20 (key = ...) would pass, but example 21 (blink = ...) would pass because key is defined. Wait, example 21 uses key from example 20. So it should pass. Then example 22 (hex(...)) would also pass. If that's the case, there should be fewer failures.

But there are 18 failures. Let's count total examples and which ones might fail.

Total examples: 0: import BLINK_CVL 1: import int_to_vec, vec_to_int 2: key (64a) 3: blink (64a) 4: hex (64a) 5: key (64b) 6: blink (64b) 7: hex (64b) 8: key (128a) 9: blink (128a) 10: hex (128a) 11: key (128b) 12: blink (128b) 13: hex (128b) 14: key (128A) 15: blink (128A) 16: hex (128A) 17: key (128B) 18: blink (128B) 19: hex (128B) 20: import BLINK_CVL (naming) 21: blink = BLINK_CVL(64, 64) 22: for node in ... (naming check) 23: blink.is_valid 24: import BLINK_CVL (modeling) 25: import model_options 26: import tempfile 27: blink = BLINK_CVL(...) 28: with tempfile... model... 29: milp is not None... -> True

Wait, total says 29 tests. My count gives 30 (0-29). Maybe some blank lines are ignored? Actually sage -t counts sage: lines. Let me recount carefully.

Actually, the for-loop with ....: lines might be counted differently. In Sage doctests, ....: lines are continuations of the same example. So sage: for node in blink.nodes: + ....: is a single example. So:

0: import BLINK_CVL 1: import int_to_vec, vec_to_int 2: key (64a) 3: blink (64a) 4: hex (64a) 5: key (64b) 6: blink (64b) 7: hex (64b) 8: key (128a) 9: blink (128a) 10: hex (128a) 11: key (128b) 12: blink (128b) 13: hex (128b) 14: key (128A) 15: blink (128A) 16: hex (128A) 17: key (128B) 18: blink (128B) 19: hex (128B) 20: import BLINK_CVL 21: blink = BLINK_CVL(64, 64) 22: for node ... (multi-line, one example) 23: blink.is_valid 24: import BLINK_CVL 25: import model_options 26: import tempfile 27: blink = BLINK_CVL(...) 28: with tempfile... (multi-line, one example? Actually with + ....: is one example) Wait, sage: with tempfile...: then ....: model_options = ... then ....: milp = ... then ....: milp is not None. That's one example. So the final True is the output.

So total examples: 0-28 = 29 examples. Good.

If example 18 fails with NameError: name 'key' is not defined, but example 17 passed, that suggests example 17's output was expected to be nothing, and it was executed. But maybe the key variable was overwritten or cleared?

Wait, I just realized: in the docstring, I have:

sage: key = 0xd6a102d888a467e4d1d7dec33a246943 \
....:   e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
....:   97779021b38e7fa15e2b66350517f80f2961c648d578bae174d70cb769c30a45 \
....:   cc40300fe8a342ca57a0bd0251ae39b621b8f104904374bbd6a102e234a664e4 \
....:   21b8f104904374bbd6a102d888a666e428962a4c96893eda752c17026a6395c2 \
....:   d6963be43b2fc10813d73f5a4a48d28d
sage: blink = BLINK_CVL(128, 256, key=key, \
....:   tweak=...)
Is there a problem with the key = ... assignment in example 17? Let me check if the backslash continuation works correctly across lines with a leading ....:. In Sage doctests, ....: is just the prompt, and the text after it is the continuation. It should work.

Wait, maybe the key value is too large and Sage converts it to a Sage Integer automatically. Then key is a Sage Integer. But that should be fine for BLINK_CVL(..., key=key).

Wait, actually I see something in the original file! Let me read the full docstring area around the 128A and 128B keys. Let me check the exact text.

The docstring looks fine syntactically. The issue might be that the hex() output format in Sage includes an L suffix for long integers in Python 2, but we're in Python 3. Or maybe hex() returns a string in Python 3, which matches.

But there are 18 failures. Example 18 is the first failure. Let's think about why example 18 fails with NameError. Example 17 is key = ... (128B key) which passed. Then example 18 is blink = BLINK_CVL(128, 256, key=key, ...). If key is not defined at example 18, maybe the key variable from example 17 is shadowed or overwritten by another key assignment in a different doctest block? No, all examples run in the same namespace.

Wait, I just realized: in doctests, if an example has no expected output (like a key = ... assignment with no output line), the doctest runner expects no output. But if the assignment produces output (e.g., from a trailing comment or because of some syntax issue), it would fail. However, a plain assignment produces no output. So example 17 should pass.

Could the problem be that the previous hex() example (example 16: 128A) has incorrect expected output, causing a failure at example 16, which might somehow clear globals? No, doctest failures don't clear globals.

Actually, looking at the exact count of 18 failures out of 29 tests. Let's see which examples pass and fail.

0-1 pass (imports)
2-4 pass (64a)
5-7 pass (64b)
8-10 pass (128a)
11-13 pass (128b)
14-16 pass (128A)
17 pass (key 128B)
18 FAIL (blink 128B)
19 FAIL (hex 128B) - because 18 failed
20 pass? (import) - but it says 18 failures, which means maybe 20 also fails? No, 20 is a simple import.
21 pass? (blink = BLINK_CVL(64,64)) - should pass.
22 pass? (for loop) - should pass.
23 pass? (blink.is_valid) - should be True.
24-28: modeling test. These might fail if scip is not available? But the tag # optional - scip should skip them if scip is unavailable. However, the tag is attached to the with line. Maybe the Sage doctest runner is not skipping the whole block correctly because the tag is on a line with a with statement, and subsequent ....: lines are considered part of the same example, but the tag might only apply to that one line? Or maybe optional - scip only skips the tagged line, not the example? In Sage doctests, # optional applies to the whole example. Since the with + ....: is one example, it should be skipped entirely if scip is unavailable. But if scip IS available (it is, because SCIP_CVL class exists), it will run. And if it runs, it should pass because we tested it. But maybe blink.model(model_options) prints those warnings about "Using existing file ...", and the expected output is True, so the extra printouts cause a failure. Actually, in our manual test, model() printed:
Using existing file ...
Using existing file ...
25120 variables and 26753 constraints were written to '...'
Boolean Program (minimization, 25120 variables, 26753 constraints)
But wait, model() doesn't return anything; it sets self.milp and returns it. The return value is the MILP object, and when it's displayed in the interpreter, it prints its repr. But in a doctest, if model_options has path=Path(tmpdir), and we call blink.model(model_options), the output is whatever model() prints plus the repr of the returned object.

Actually in Sage, milp = blink.model(model_options) is an assignment. Assignments in doctests produce no output, unless the assigned object is None? No, assignment produces no output. The expected output is then the next expression: milp is not None. And its output is True. So the example should be:

sage: with tempfile.TemporaryDirectory() as tmpdir:  # optional - scip
....:   model_options = MODEL_OPTIONS(...)
....:   milp = blink.model(model_options)
....:   milp is not None
True
But in our manual test, model() printed warnings. Those warnings go to stdout and would appear in the doctest output before True. In a doctest, any output before the expected output causes a failure. So the modeling example would fail because of the "Using existing file ..." warnings.

Wait, but those warnings are printed by SCIP_CVL().solve() or something? Actually in our manual test script, we only called model(), not analyse(). Let me re-check the manual test output:

Using existing file /var/folders/.../a933628d.sol, make sure it is up to date!
Using existing file /var/folders/.../a933628d.sol, make sure it is up to date!
25120 variables and 26753 constraints were written to '/var/folders/.../blink-test.mps'
Boolean Program (minimization, 25120 variables, 26753 constraints)
Naming OK
Where did the first two lines come from? They look like they come from .mps writing or from the MILP solver wrapper when it tries to read an existing .sol file. In our manual test, SCIP_CVL() is instantiated. When blink.model(model_options) is called, it might trigger milp_solver initialization that prints those warnings.

In a doctest with a clean tempdir, would those warnings still appear? The tempdir is fresh, so there should be no existing .sol files. Unless SCIP_CVL() has a default path. Let me check what SCIP_CVL() does.

In the present.py doctest, they use # optional - scip and the expected output is an Integer or True. Maybe those warnings only appear because my manual test reused a global temp path. In a doctest with a fresh tempdir, it's likely clean. But I'm not sure. To be safe, I should change the modeling test to avoid output from model(). I could suppress warnings by assigning to _ and checking a property, but the warnings might still print.

Alternatively, I can just check blink.model(model_options) in a separate line and then check blink.milp is not None in the next line. But warnings from model() would still be printed.

Actually, the simplest fix is to remove the modeling doctest or make it very robust. In the present.py file, they have:

sage: present.analyse(model_options)
0b0
So they call analyse() directly and check the result. But they omit the intermediate model() call? Or maybe model() is called inside analyse(). Actually present.py docstring says:

sage: with tempfile.TemporaryDirectory() as tmpdir:  # optional - sat
....:   model_options = MODEL_OPTIONS(...)
....:   present.analyse(model_options)
0b0
They call analyse directly. But they don't call model separately. In our case, we tested that model works. For the doctest, I can also call analyse or just call model and suppress output. But model might print stuff.

Wait, looking at sage -t output, there are 18 failures. That's a lot. It suggests that from example 18 onwards, many things fail. The first failure is example 18 (NameError for key). But maybe example 17 actually also fails? The doctest runner says "18 of 29", which means example index 18 is the first failure. If example 17 failed, the first failure would be 17. So example 17 passed. This means key is defined after example 17. But example 18 says key is not defined. This implies the key variable was somehow deleted between examples 17 and 18.

Is there anything in the doctest runner that resets the namespace after a certain number of examples or after a blank line? In standard doctests, no. In Sage, I think it might reset after a doctest directive or after a ....: block? No.

Wait, could example 17 have an expected output that matches the actual output? But example 17 is an assignment, so expected output is empty. It passed.

Why would key disappear? Unless... the key variable in example 17 is shadowed by a local variable inside a previous with block? No, there is no with block before example 18.

Actually, I just realized something. The doctest might be failing because of the \ line continuation in the tweak argument. In the blink = BLINK_CVL(...) line, the \ continues the line to the next ....:. The tweak=... line is very long. In Python, a backslash continuation must be the last character on the line. But in the docstring source, there might be trailing whitespace after the \. If there is trailing whitespace, the \ is not the last character, and Python treats it as a syntax error. But if it were a syntax error, example 18 would fail with SyntaxError, not NameError.

Wait, but example 18 is blink = BLINK_CVL(128, 256, key=key, \. If the backslash fails because of trailing whitespace, the expression would be BLINK_CVL(128, 256, key=key, which is a syntax error. But the error says NameError. So maybe the backslash itself is fine, and the key variable is genuinely missing.

Let me run a quick manual test: extract examples 14-19 and run them in a Python script. Actually, I can just run the doctest with a single example or run a small script.

Wait, I notice that the error traceback is:

  File "<doctest civerly.cipher_implementations.blink.BLINK_CVL[18]>", line 1, in <module>
    blink = BLINK_CVL(Integer(128), Integer(256), key=key,   tweak=Integer(0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef))
                                                          ^^^
NameError: name 'key' is not defined
But example 18 in the traceback is line 1, which is the blink = BLINK_CVL(...) call. It seems the key variable really is not in the namespace.

Could the issue be that the previous key = ... assignment (example 17) is actually inside a different doctest item because there is a blank line between examples? No, blank lines separate examples but don't reset globals.

Wait, maybe there's a blank line within the key = ... assignment? No.

Actually, I just thought: maybe the problem is hex() output for Python 3. Let's check what the hex() output actually is. If hex() returns '0xa4a0d10502be846e' etc., the doctest should pass. But maybe vec_to_int(blink(int_to_vec(0, 64))) returns a Sage Integer, and hex() of a Sage Integer in Python 3 returns something different? In Sage, hex(SageInteger) returns 0x... same as Python. So it should match.

Let me just run the doctest for a single example to verify the first few pass, and then run examples 17-19 in isolation.

Wait, a more productive approach: run sage -python with the exact commands.

Interesting! The verbose output shows "Trying (line 372): key = 0xd6a102d8... Expecting nothing" followed immediately by "Failed example:" without any detail. This means EVERY key = ... assignment is failing. And then every subsequent example using key or blink also fails.

Why would key = 0xd6a102d8... fail? It's a simple assignment. The verbose output doesn't show the actual exception. Let me get the full verbose output for the first few examples.

Actually, the Expecting nothing line is there, but the Failed example: line immediately after it means the example's output did not match the expected output (nothing). But a simple assignment should produce no output. Unless the assignment itself raises an exception.

Wait, maybe the issue is that the integer literal is too large for Python 2, but we are in Python 3. In Python 3, arbitrarily large integers are fine.

Maybe the \ continuation is broken. In the source, there's a backslash at the end of the line. But in the doctest, the ....: prompt is inserted. The actual code executed is:

key = 0xd6a102d888a467e4d1d7dec33a246943 \
  e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
  ...
But in the docstring, the ....: lines start with leading spaces. When Python executes this, the backslash joins the lines, so spaces after the backslash are ignored. But the second line starts with spaces, then e07c1dc6.... Python interprets this as part of the same statement. So it's key = 0x...e07c1dc6... which is a valid integer literal.

Wait, but what if there is a trailing space after the backslash \ in the source file? Then the backslash is NOT escaping the newline, and the line ends, and the next line e07c1dc6... is treated as a separate statement, which would be a NameError (e07c1dc6... is undefined). That would explain exactly why key = ... fails! The assignment of key only gets the first hexadecimal literal, but the \ doesn't continue to the next line because of trailing spaces. Then:

sage: key = 0xd6a102d888a467e4d1d7dec33a246943 \
....:   e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
becomes:

key = 0xd6a102d888a467e4d1d7dec33a246943 \
and then a new command e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 which is not a valid statement (NameError or invalid syntax). This would cause an exception, so the key assignment might partially succeed (setting key to the truncated integer?) but then the next command raises an exception, causing the whole example to fail.

Actually, in Sage doctests, if an example raises an exception, the expected output should be the traceback. If the expected output is nothing, then any exception causes a failure. The key = ... example would fail because the second line e07c1dc6... raises a NameError. Then key is NOT defined because the exception aborts the example.

But wait, if the backslash has trailing whitespace, then key = 0xd6a102d8... \ is a syntax error because the backslash must be the very last character. Actually, \ followed by space is not a valid escape. In Python, key = 1 \␣ (where ␣ is a space) results in SyntaxError: unexpected character after line continuation character or something like that. In Python 3, \ at the end of a line with trailing whitespace is a SyntaxError.

Yes! That would explain everything. The key = ... assignments have a backslash \ at the end of the source line, but if there's a trailing space after the backslash, it's a SyntaxError. The doctest would fail with SyntaxError. The key variable is never assigned.

Why would there be trailing spaces? Looking at the write output that created the file... The original file content was written by me using string concatenation, and then edit was used to replace parts. In the edit operations, I used strings ending with \ followed by spaces? No, in the edit operations, I used raw strings or normal strings. In the newString of the edit, the backslash is the last character before a newline inside the tool call. The tool may have preserved trailing spaces? Actually, when I used edit to replace docstrings, the oldString and newString were literal Python strings in JSON. The JSON parser preserves spaces. But when I wrote the newString, did I put a space after the backslash? Let me check the exact content.

Let me read a specific line to see if there's a trailing space.

... (error pinned down to key declaration)

The backslash is followed by \n with no trailing space. So the line continuation is valid. But the doctest still fails.

Let me check what Sage does with \ in doctests. Actually, I suspect the issue is that Sage replaces ....: with (4 spaces), but the backslash \ is literally there, and when Python compiles the combined string, it sees key = 0x... \\\n e07c1.... The \ escapes the newline, and then the next line is indented with 4 spaces. In Python, if a line continuation is used, the next line cannot be indented unless it's inside a block. Actually, in Python, line continuation ignores the newline but the next line must not be indented if it's a simple statement continuation. Wait, is that true?

In Python:

x = 1 \
    + 2
This is valid. The backslash at the end of line 1 continues to line 2, and the indentation on line 2 is allowed? Actually, yes, it's allowed for implicit line continuation after backslash? Let me test.

Wait, in Python, if you use a backslash for explicit line continuation, the next line cannot be indented. Or can it?

x = 1 \
  + 2
This is valid. But:

x = 1 \
    + 2
Is this valid? I think it is. Let me test quickly.

python3 -c "
x = 1 \\
    + 2
print(x)
"
3
So backslash continuation with indentation is fine in Python. Then what is causing the key = ... assignments to fail in doctests?

Let me run a minimal doctest to see the actual exception. I'll create a small Python file with the exact docstring text and run sage -t on it. Or better, I can run the doctest for just the first key example using Python's own doctest module to see the exact error. But Sage's doctest runner might behave differently.

Another thought: maybe the key = ... example expects no output, but the hex() assignment has a bad expected output. But the verbose log showed key = ... itself fails.

Wait, I just noticed something in the verbose output: after Trying (line 372): key = ... Expecting nothing, it says Failed example: immediately. But it doesn't show the actual output. Maybe the output was a traceback but the verbose mode truncates? In Sage doctests, if an example raises an exception, the traceback is captured and compared to expected output. If expected output is nothing, it fails.

Let me capture the full verbose output to a file and read the failure reason.

sage -t --verbose src/civerly/cipher_implementations/blink.py > /tmp/doctest_out.txt 2>&1; head -n 100 /tmp/doctest_out.txt
Running doctests with ID 2026-07-06-22-47-29-374b97d1.
Running with SAGE_LOCAL='/private/var/tmp/sage-10.7-current/local' and SAGE_VENV='/private/var/tmp/sage-10.7-current/local'
Using --optional=pip,sage
Features to be detected: 4ti2,SAGE_SRC,benzene,bliss,buckygen,conway_polynomials,coxeter3,csdp,cvxopt,cvxopt,database_cremona_ellcurve,database_cremona_mini_ellcurve,database_cubic_hecke,database_ellcurves,database_graphs,database_jones_numfield,database_knotinfo,dot2tex,dvipng,ecm,flatter,fpylll,fricas,gap_package_atlasrep,gap_package_design,gap_package_grape,gap_package_guava,gap_package_hap,gap_package_polenta,gap_package_polycyclic,gap_package_qpa,gap_package_quagroup,gfan,giac,glucose,graphviz,imagemagick,info,ipython,jmol,jupymake,jupyter_sphinx,kenzo,kissat,latte_int,lrcalc_python,lrslib,mathics,matroid_database,mcqd,meataxe,meson_editable,mpmath,msolve,nauty,networkx,numpy,palp,pandoc,pdf2svg,pdftocairo,pexpect,phitigra,pillow,plantri,polytopes_db,polytopes_db_4d,pplpy,primecountpy,ptyprocess,pycosat,pycryptosat,pynormaliz,pyparsing,python_igraph,requests,rpy2,rubiks,sage.combinat,sage.geometry.polyhedron,sage.graphs,sage.groups,sage.libs.braiding,sage.libs.ecl,sage.libs.flint,sage.libs.gap,sage.libs.giac,sage.libs.homfly,sage.libs.linbox,sage.libs.m4ri,sage.libs.ntl,sage.libs.pari,sage.libs.singular,sage.misc.cython,sage.modular,sage.modules,sage.numerical.mip,sage.plot,sage.rings.complex_double,sage.rings.finite_rings,sage.rings.function_field,sage.rings.number_field,sage.rings.padics,sage.rings.polynomial.pbori,sage.rings.real_double,sage.rings.real_mpfr,sage.sat,sage.schemes,sage.symbolic,sage_numerical_backends_coin,sagemath_doc_html,scipy,singular,sirocco,sloane_database,sphinx,symengine_py,sympy,tdlib,threejs,topcom
Doctesting 1 file.
sage -t --warn-long 5.0 --random-seed=199902165496741862158803372502297704459 src/civerly/cipher_implementations/blink.py
Trying (line 369):    from civerly.cipher_implementations.blink import BLINK_CVL
Expecting nothing
ok [0.03s wall]
Trying (line 370):    from civerly.util import int_to_vec, vec_to_int
Expecting nothing
ok [0.00s wall]
Trying (line 372):    key = 0xd6a102d888a467e4d1d7dec33a246943 \
      e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
      97779021b38e7fa1
Expecting nothing
**********************************************************************
File "src/civerly/cipher_implementations/blink.py", line 372, in civerly.cipher_implementations.blink.BLINK_CVL
Failed example:
    key = 0xd6a102d888a467e4d1d7dec33a246943 \
      e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
      97779021b38e7fa1
Exception raised:
    Traceback (most recent call last):
      File "/private/var/tmp/sage-10.7-current/local/lib/python3.13/site-packages/sage/doctest/forker.py", line 733, in _run
        self.compile_and_execute(example, compiler, test.globs)
        ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      File "/private/var/tmp/sage-10.7-current/local/lib/python3.13/site-packages/sage/doctest/forker.py", line 1155, in compile_and_execute
        compiled = compiler(example)
      File "/private/var/tmp/sage-10.7-current/local/lib/python3.13/site-packages/sage/doctest/forker.py", line 699, in compiler
        code = compile(example.source, filename, "single",
                       compileflags, 1)
      File "<doctest civerly.cipher_implementations.blink.BLINK_CVL[2]>", line 1
        key = Integer(0xd6a102d888a467e4d1d7dec33a246943)   e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06   97779021b38e7fa1
                                                                                                                                      ^
    SyntaxError: invalid decimal literal
Trying (line 375):    blink = BLINK_CVL(64, 64, key=key, tweak=0x0123456789abcdef)
Expecting nothing
**********************************************************************
File "src/civerly/cipher_implementations/blink.py", line 375, in ci
… (truncated, 3783 chars omitted)
Now I see the issue! The Sage doctest parser is not preserving the backslash continuation correctly. It compiles the source as a single line:

key = Integer(0xd6a102d888a467e4d1d7dec33a246943)   e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06   97779021b38e7fa1
It replaced \ with spaces! The backslash is gone, and the lines are joined with spaces. This is because in the docstring, the ....: lines are treated as continuations, but the \ at the end of the sage: line is being escaped or removed by the docstring parser because it's inside a raw string? No, the docstring itself is a normal Python string (triple quotes), so \\ in the source would become \ in the string. But here we have a single \ in the source file, which is correct.

Wait, but in the traceback, the \ is missing. Let me look at the raw source again. The raw bytes for line 372 were b'4d1d7dec33a246943 \\\n'. That's a backslash then a space then newline? Wait, repr(line[-20:]) showed b'4d1d7dec33a246943 \\\n'. That means the last characters are \, space, \n. So there IS a trailing space after the backslash!

Oh! My earlier check for trailing spaces was flawed. Let me recheck. repr(line[-20:]) for line 372 showed b'4d1d7dec33a246943 \\\n'. That's a backslash, a space, and then a newline. So there IS a trailing space after the backslash.

Wait, but my regex check earlier didn't find it because I searched for line.endswith(' \\\n') or similar. b' \\\n' is space-backslash-space-newline? No. The line ends with \\\n which is backslash-space-newline. The bytes are 0x5C 0x20 0x0A. So the line ends with ' \\\n'? No, ' \\\n' is 0x20 0x5C 0x0A. The actual bytes are 0x5C 0x20 0x0A, which is '\\ \n'. My earlier check used line.endswith(' \\\n') which is 0x20 0x5C 0x0A, so it didn't match.

So the problem is that the backslash is followed by a space, then newline. In Python, \ followed by a space is a valid line continuation? Actually no! In Python, \ must be the very last character before the newline. If there's a space after the \, it's a syntax error.

Wait, but when I tested backslash continuation earlier, I used python3 -c "x = 1 \\\n + 2" — I typed the backslash directly before the newline, with no space. In the source file, the backslash is followed by a space. So in Python, key = 0x... \ (backslash space) is a syntax error!

But why didn't my manual Python test fail? Because the manual test was in a bash command where the backslash was used to escape the newline in the shell, not in a Python string.

So the issue is clear: the lines in the source file end with \n (backslash space newline), which is a syntax error in Python. The doctest parser sees the backslash but because it's not the last character (space follows), it might treat it differently, but the compiled code clearly shows the backslash is gone and replaced by spaces. Actually, in Python, \ followed by a space is not a line continuation; the backslash escapes the space? Wait, in Python strings, \ followed by a space is just a backslash and a space. But in code (not inside a string), \ outside a string is a line continuation if it's at the end of the line. If there's a space after it, it's actually still valid in Python? Let me test.

x = 1 \ 
+ 2
Is this valid? Let me test.

Aha! The bytes are 0x34 0x33 0x20 0x5c 0xa. Wait, that means the line ends with '3 \n', not '\\ \n'. Let's decode: 0x34 = '4', 0x33 = '3', 0x20 = space, 0x5c = \, 0xa = newline. So the last 5 characters are 3 \n which is 3, space, backslash, newline. So the line is ...43 \\\n. Wait, 0x34 is '4', 0x33 is '3'. So the last characters before the newline are 3 \. So the backslash is indeed the second-to-last character, with a space before it. So it's ...43 \n. Wait, no: ...43 then space then \ then newline. That's ...43 \\\n? No, ...43 is the end of the hex string, then a space, then a backslash, then newline. So the backslash IS the last non-whitespace character.

But the byte sequence shows: 0x20 (space) then 0x5c (backslash) then 0x0a (newline). So the line is ...943 \\\n where the space is BEFORE the backslash. That means the backslash IS the last character before the newline. So the line continuation should be valid!

Wait, but the traceback showed the compiled code as:

key = Integer(0xd6a102d888a467e4d1d7dec33a246943)   e07c1...
The backslash is gone, and the next line e07c1... is joined with spaces. That's exactly what line continuation does! So the backslash is working. But why is it a SyntaxError?

Ah! Because the ....: prompt is stripped, and the next line starts with spaces. In Python, after a backslash continuation, the next line must not have leading spaces if it's a simple statement. Wait, no, Python allows:

x = 1 \
    + 2
I tested that and it worked. But that was in a script. In compile(..., "single") mode (which is what the doctest uses), does it behave differently?

Let me test compile("x = 1 \\\n + 2", "", "single").


The problem is now clear! In the source file, the line ends with ...943 \ (backslash preceded by a space). But then the next line starts with ....: e07c1.... When Sage doctest processes this, it strips the ....: and leaves e07c1.... But the generated source string has backslash followed by newline, then spaces, then e07c1.... In Python compile(..., "single"), this is valid. However, in my manual test, I failed because in the shell string src = '''... \\\n ...''', the \\ in a normal Python string becomes \. Wait, '''... \\n''' is backslash backslash n? No, \\ in a normal string means a single backslash. But then \n inside a '...' string is interpreted as a newline? No, \n is a newline character.

Wait, my manual test string was:

src = '''key = 0x... \
      e07c1... \
      97779021b38e7fa1'''
In a normal Python triple-quoted string, the backslash at the end of the line does NOT continue the string across the newline inside the string literal. Backslash-newline inside a string literal is not valid in Python 3 unless it's outside a string. Wait, actually in a string literal, backslash-newline is just a line continuation for the string literal if it's not inside quotes? No, inside a triple-quoted string, a backslash at the end of a line is just a backslash character, because triple-quoted strings don't have implicit line continuation with backslash (they already include newlines). But backslash-newline is removed even inside triple-quoted strings? Actually, in Python, implicit line joining (backslash-newline) happens at the tokenizer level, not the string literal level. But inside a string literal, backslash-newline might be an error because the backslash escapes the newline? No, in string literals, backslash-newline is actually removed! Example: s = "a\\\nb" -> s = "ab". Wait, is that true?

Let me test:

The problem is now clear! In the source file, the line ends with ...943 \ (backslash preceded by a space). But then the next line starts with ....: e07c1.... When Sage doctest processes this, it strips the ....: and leaves e07c1.... But the generated source string has backslash followed by newline, then spaces, then e07c1.... In Python compile(..., "single"), this is valid. However, in my manual test, I failed because in the shell string src = '''... \\\n ...''', the \\ in a normal Python string becomes \. Wait, '''... \\n''' is backslash backslash n? No, \\ in a normal string means a single backslash. But then \n inside a '...' string is interpreted as a newline? No, \n is a newline character.

Wait, my manual test string was:

src = '''key = 0x... \
      e07c1... \
      97779021b38e7fa1'''
In a normal Python triple-quoted string, the backslash at the end of the line does NOT continue the string across the newline inside the string literal. Backslash-newline inside a string literal is not valid in Python 3 unless it's outside a string. Wait, actually in a string literal, backslash-newline is just a line continuation for the string literal if it's not inside quotes? No, inside a triple-quoted string, a backslash at the end of a line is just a backslash character, because triple-quoted strings don't have implicit line continuation with backslash (they already include newlines). But backslash-newline is removed even inside triple-quoted strings? Actually, in Python, implicit line joining (backslash-newline) happens at the tokenizer level, not the string literal level. But inside a string literal, backslash-newline might be an error because the backslash escapes the newline? No, in string literals, backslash-newline is actually removed! Example: s = "a\\\nb" -> s = "ab". Wait, is that true?

Let me test:

Let me understand exactly how the docstring raw source translates through the doctest parser.

python3 << 'PYEOF'
# Test what compile("single") does with exact source
src = "key = 0xd6a102d888a467e4d1d7dec33a246943 \\\n      e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \\\n      97779021b38e7fa1"
try:
    compile(src, "<test>", "single")
    print("ok")
except SyntaxError as e:
    print("SyntaxError:", e)
    print(repr(src))
PYEOF
SyntaxError: invalid decimal literal (<test>, line 3)
'key = 0xd6a102d888a467e4d1d7dec33a246943 \\\n      e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \\\n      97779021b38e7fa1'
Aha! src = "key = ... \\\n e07c1... \\\n 97779021b38e7fa1" has the backslash followed by a newline, which in a normal string literal becomes \n (newline character)? No, wait. In a normal Python string, \\ is an escaped backslash, so \\n is a backslash followed by the letter n, not a newline. But in the f-string or normal string, \\\\n would be \\n. Wait, I used "key = ... \\\n e07c1...". In a normal double-quoted string, \\ escapes the backslash, resulting in a single backslash. Then \n is the newline escape sequence. So the actual string content is:

key = 0xd6a102d888a467e4d1d7dec33a246943 \
      e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
      97779021b38e7fa1
Where \ is immediately followed by a newline. This is valid Python! But compile gave SyntaxError invalid decimal literal (<test>, line 3).

Wait, line 3 of the compiled source? The source is 3 lines. Line 3 is 97779021b38e7fa1. That's a valid decimal integer. But because the previous line ends with \, lines 2 and 3 are continuations of the same statement. So the statement is:

key = 0xd6a102d888a467e4d1d7dec33a246943 \
      e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 \
      97779021b38e7fa1
Python parses this as key = 0x...e07c1...97779021b38e7fa1 (all one integer literal). Wait, but in Python, you cannot have spaces inside an integer literal. The backslash-newline removes the newline but keeps the spaces. So it becomes key = 0xd6a102... e07c1... 97779021b38e7fa1. And since e07c1dc6... starts with e, which is a valid hex digit, the hex literal continues until it hits a space? No, hex literal stops at the space. Then e07c1... is seen as a separate token, which starts with e but is not a valid hex prefix (that would be 0x). So Python treats e07c1... as a name/identifier? No, because it starts with a digit? Wait, e07c1... starts with e, which is a letter. But then it contains digits. In Python, a token starting with a letter is an identifier. But e07c1dc6f302c57e762c2df9de6f0d216dd387874a0b52ce3022e0ad78c78a06 is not a valid identifier? Actually it is! It's a valid Python identifier name (letters and digits, starting with a letter). So Python interprets the continuation as key = 0x... identifier identifier. That is a syntax error because it's like key = 123 abc def.

Yes! That's exactly the issue. In Python, x = 1 \ followed by + 2 is valid because + 2 is a valid continuation of the expression. But x = 0x1 \ followed by abc is NOT valid because abc is a separate identifier token, and you can't have two identifiers next to each other without an operator.

The backslash continuation preserves the indentation spaces but joins the line. Because the integer literal ends with the space before the backslash, the next line's e07c1... is a new token. For arithmetic expressions, 1 \n + 2 is fine because + is an operator. But for a hex literal that's being continued, it's NOT fine because there's no operator between the first literal and the next token.

So the backslash continuation is the wrong approach for long integer literals in doctests. I need to avoid breaking the integer literal across lines.

The solution is to either:

Put each key on a single line (the line might be long, but doctests can handle long lines).
Use string concatenation: key = 0x... + (0x... << 128) + ... but that's messy.
Use a helper function or string conversion: key = int("d6a102...97779021b38e7fa1", 16).
Option 3 is the cleanest and most robust for doctests.

So I need to rewrite all the key = 0x... \ assignments to use int("...", 16).

I'll use edit to replace the test vector block in the docstring.

Actually, looking at the paper/PRESENT examples, they use long ints on single lines. I can just put the integer on one line without backslashes. The lines will be ~200 characters long, which is fine.

Or better, to keep it readable, I can assign each key like:

sage: key = int("d6a102d888a467e4d1d7dec33a246943"
....:            "e07c1dc6f302c57e762c2df9de6f0d21"
....:            "6dd387874a0b52ce3022e0ad78c78a06"
....:            "97779021b38e7fa1", 16)
This is valid Python string concatenation. But in doctests, the ....: lines are treated as continuation lines, so the string concatenation works.

Alternatively, I can just put the integer on a single line. Given the docstring already has long lines, I'll do that for simplicity.

Wait, but the README might discourage very long lines. But it's a docstring test vector, so a long line is acceptable. Let me check the PRESENT test vectors. In present.py, do they have long ints on one line?

Yes, looking at present.py:

sage: key = 0x123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0
That's a single line. So I should do the same.

I'll replace all the key = 0x... \ blocks with single-line key = 0x... assignments.

And similarly for the tweak arguments that use \ continuation? Actually the tweak arguments also use \ continuation inside BLINK_CVL(...). Like:

sage: blink = BLINK_CVL(64, 128, key=key, \
....:   tweak=0x0123456789abcdef0123456789abcdef)
This is fine because it's a function call with key=key, then \ then tweak=.... The \ is used to continue the function call, and tweak=... is a valid keyword argument. This should work because key=key, \ followed by tweak=... is valid. But actually, let me check: blink = BLINK_CVL(64, 128, key=key, \\\n tweak=.... In Python, inside a function call, after a comma, you can continue the arguments on the next line with a backslash. The next line starts with spaces and tweak=.... This is fine because tweak=... is a valid argument.

But wait, the traceback for the first failure was specifically for the key = ... assignment, not the blink = ... call. The blink = ... call failed because key was undefined, not because of syntax.

So the tweak continuations in BLINK_CVL(...) are probably fine. But to be safe, I could also put the tweak on the same line.

However, the hex() expected outputs might also have issues if the doctest comparison is strict. But manual tests show they match.

Let me rewrite the docstring to avoid backslash line continuations in integer literals. I'll replace the long key = 0x... \ blocks with single-line key = 0x....

Actually, I can use write or edit to replace the entire docstring block. Using edit to find the old block and replace with new one. Let me grab the exact old block.

... (removing backslash continuation in key declaration)

All 28 doctests passed! Great.

Now let me update the todo list and then think if there's anything else to do.

The current state:

The implementation is complete.
All 6 test vectors pass.
Doctests pass (28 tests).
Modeling test is included with # optional - scip.
Naming check is included.
I should do a quick sanity check that the file imports correctly and is syntactically valid. It is, since doctests passed.

Is there anything else the user wants? The user asked "What did we do so far?" earlier, and I provided a comprehensive summary. Then the user said "please continue with the next steps". I've fixed the doctest issues. The implementation is essentially done.

I should summarize what was done and what the final state is, and mark the task as complete. I should also mention that all tests pass and the implementation is ready.

Wait, are there any other files that need to be updated? The README doesn't require updating for a new cipher implementation unless explicitly asked. The AGENTS.md might need updating, but not necessarily.

Let me also check if there are any linter issues. But since doctests pass and the manual tests pass, it's fine.

So the next step is to report completion.

But before I do that, let me check if there are any remaining todo items that I should verify:

Validate doctests: Done.
Check modeling test works in doctest context: It passed (but # optional - scip might have skipped it if scip isn't installed? Wait, the doctest passed, and the modeling test was example 28. If # optional - scip is present, the Sage doctest runner checks if scip is available. If it is, it runs the test. If not, it skips it. The total test count was 28. The previous run said 29 tests but 18 failures. After removing backslashes, the count became 28 tests and all passed. That means the modeling test was either skipped or passed. Given that SCIP_CVL class exists, and scip might be available in the environment, it could have been run and passed. Or it might have been skipped because scip binary is not installed. Either way, it's fine.
I think the task is complete. I'll provide a concise summary.

Actually, looking at the todo I created earlier, step 4 was "Add complete doctests and validate". That's now done. I should update the todo list to mark it complete. Then provide the final response.

Also, I should check if there are any other issues like imports or code style. The file is 665 lines. It imports matrix, GF, Permutation, WordSBoxCipher, PermuteLayer_CVL, RoundkeyXOR_CVL, S_CVL, LinearLayer_CVL, XOR_CVL. It defines helper functions and then the class. It seems well-structured.

One thing: the MixColumns helper uses matrix(GF(2), total_bits, total_bits, 0) which creates a zero matrix, and then sets entries one by one. This is fine.

Another thing: the Offset component is defined as class Offset(Component_CVL): ... at the top of the file. It's a simple wrapper around XOR_CVL that adds an offset and then removes it. This might be slightly unusual but it's necessary because the key schedule constants need to be applied as XOR after the backward rounds but before the whitening and h addition. Actually, it's used in the w_p section. It's fine.

The _generate_round_key and hash_func functions are transcribed faithfully from documentation/blink.py.

I think we are done. I'll finish.

# final answer


The user asked me to continue with the next steps. I've completed all the steps: implemented the Blink cipher, verified test vectors, fixed the docstring to avoid backslash continuations in integer literals, and validated all doctests pass. I should now summarize the completion.

I should also consider if there's any final suggestion to make, like a code review. Since I completed non-trivial file-changing work, I could use the suggest tool to offer a local code review of the uncommitted changes. The user hasn't explicitly asked for review, but the instructions say to use suggest after non-trivial work. This is appropriate.

Let me provide the summary first, then suggest a review.

The implementation is complete and all tests pass.

What was done

Implemented the full Blink tweakable block cipher family (64a, 64b, 128a, 128b, 128A, 128B) as a WordSBoxCipher in src/civerly/cipher_implementations/blink.py.
Ported the key schedule (hash_func, generate_round_key) from documentation/blink.py to produce integer constants.
Built the full-state MixColumns as a single LinearLayer_CVL (avoiding the AESlike column-major / Blink row-major transpose mismatch).
Translated Blink's LSB-first nibble permutation into CiVerLy's MSB-first vector indexing.
Fixed a critical variable-shadowing bug where node_rc/node_rk were overwritten before the forward loops completed.
Added doctests for all 6 published test vectors, a # optional - scip MILP modeling test, and a naming sanity check.
Fixed a doctest syntax issue where long integer literals were split with backslashes (invalid in Python), switched to single-line literals.
Validation

All 28 doctests pass (sage -t src/civerly/cipher_implementations/blink.py).
Manually verified all 6 published test vectors match the reference implementation.


User:
Please refine the implementation of blink in @src/civerly/cipher_implementations/blink.py  to perform attacks for a variable number of  forward and inverse rounds by passing optional parameters (for the rl and rr rounds) to the constructor for an object. I wan to test some claims stated in the paper @documentation/analysis.md . The guide @documentation/README.md also holds information on this topic, too. For completeness, you can find a reference implementation @documentation/blink.py  and further information @documentation/blink.md . If you need further information, please come forward.

The user wants to refine the BLINK_CVL implementation in src/civerly/cipher_implementations/blink.py to allow testing claims from the paper. Specifically, they want to be able to construct a cipher with a variable number of forward rounds (rl) and inverse rounds (rr).

From documentation/analysis.md, I see claims about:

Differential analysis (10-round distinguisher for Blink-64, etc.)
Impossible differential attacks with r1 rounds of the upper half and r2 rounds of the lower half.
The current BLINK_CVL class hardcodes the full cipher structure with ra forward rounds in the first half, rb in the second, then rb backward and ra backward. The user wants to be able to pass rl and rr (or similar) to choose how many forward rounds and how many inverse rounds to include. This sounds like they want to construct a reduced-round version of the cipher, specifically for analyzing the "upper half" and "lower half" mentioned in the impossible differential analysis.

Let's re-read the blink.py source and the analysis.md carefully.

The structure of Blink is:

Whitening w0
ra forward keyed rounds (R)
Middle: S, M, AK(h0), P
rb forward keyed rounds (R)
Middle: S, M, AK(h0^h1), S
rb backward keyed rounds (R^-1)
Middle: P^-1, AK(h1), M, S
ra backward keyed rounds (R^-1)
Whitening w1
In analysis.md, impossible differential attacks are described as "r1-rounds of the upper half and r2-rounds of the lower half". The "upper half" likely refers to the rounds above the center, and the "lower half" to the rounds below. For Blink, the upper half could mean the rounds from the start towards the middle, and the lower half from the middle to the end.

The user wants "optional parameters (for the rl and rr rounds)". This likely means:

rl: number of rounds in the left (upper) part.
rr: number of rounds in the right (lower) part.
But we need to be careful. The paper says "considering r1-rounds of the upper half and r2-rounds of the lower half". The upper half of Blink is ra + 1 + rb rounds (if we count from whitening w0 to the center S), but the rounds themselves are the keyed rounds and the middle rounds. Let's look at the structure.

Actually, in the analysis of impossible differentials, one usually considers a truncated cipher consisting of r1 rounds forward from plaintext and r2 rounds backward from ciphertext, leaving a 'miss-in-the-middle' in the middle. For a reflective cipher like Blink, the structure is symmetric.

Let's look at how the user phrased it: "perform attacks for a variable number of forward and inverse rounds by passing optional parameters (for the rl and rr rounds) to the constructor for an object."

This means they want a BLINK_CVL where instead of the full ra, rb, etc., they can specify rl and rr to build an object with:

rl forward rounds at the beginning?
rr inverse rounds at the end?
Or perhaps rl rounds of the upper half and rr rounds of the lower half. Let's think about what would be useful for impossible differentials.

For the impossible differential claims:

Blink-64: longest impossible differential spans 7 rounds.
Blink-128: spans 9 rounds.
These are constructed as r1 + r2 impossible differential trails. So the user might want to construct a cipher that has r1 rounds of the forward part and r2 rounds of the inverse part, or some combination. However, for impossible differential analysis of the center structure, they might want to construct a cipher that only contains a certain number of rounds.

But BLINK_CVL returns a cipher object for modeling. If we want to test claims like "7 rounds impossible differential", we usually don't need a new cipher class but rather analyze the existing full cipher and constrain the model. However, the user explicitly wants to pass rl and rr to the constructor to build a reduced-round or partial-round object.

What would be the most natural interpretation? The construction has:

ra rounds of type Fwd
1 middle stage (S, M, AK(h0), P)
rb rounds of type Fwd
1 middle stage (S, M, AK(h0^h1), S)
rb rounds of type Bwd
1 middle stage (P^-1, AK(h1), M, S)
ra rounds of type Bwd
Total keyed rounds = ra + rb + rb + ra = 2*(ra+rb). Plus the middle stages.

If the user wants rl forward rounds and rr inverse rounds, maybe they want:

Up to rl forward rounds from the start (could be toward the middle)
Up to rr inverse rounds from the end (could be from the middle backward)
But in the context of impossible differentials, rl and rr usually mean left rounds and right rounds, i.e., rounds added on the left (encryption) and right (decryption) of a distinguisher. The distinguisher is typically in the middle.

Wait, could it be that they want to parameterize the number of rounds of the round function R applied in the upper part and lower part? The upper half consists of ra + rb keyed rounds. The lower half also consists of ra + rb keyed rounds. If rl and rr are the numbers of rounds, they might want to replace ra and rb with rl and rr in the round counts. But ra and rb are fixed by the variant configuration based on key length. The constructor already infers ra and rb if key is not provided.

Let's search for "rl" or "rr" in the documentation or code. I don't see rl or rr in the provided snippets.

Let's think about how other ciphers in CiVerLy handle variable rounds. Let's check abc.py or present.py for examples. Since I don't have those files open, I'll rely on the README snippets.

The README says in section 6: "If the key schedule matters to your analysis, model it as a dedicated subcipher instead of hard-coding the constants in the round function." and "if the examples in skinny.py or abc.py set round constants on a node before each round, follow that pattern".

For variable rounds, the typical approach is to pass R to the constructor.

But the user specifically asks for rl and rr. Let's re-read analysis.md carefully.

Section 7.2: "We explored the impossible differential trails for the center structure, considering r1-rounds of the upper half and r2-rounds of the lower half."

So the full upper half has some number of rounds, and the full lower half has some number. The user wants to test different numbers of upper and lower rounds. This means we should allow construction of a cipher that contains only r1 rounds of the upper half and r2 rounds of the lower half.

What exactly constitutes the "upper half" and "lower half"? Based on Figure 2 in blink.md: Upper half (from top to center):

Whitening w1
ra rounds of R (S, MK, P)
Middle: S, MK(h1), P
rb rounds of R (S, MK, P)
Middle: S, MK(h(t))
Wait, looking at the figure in blink.md: The top part is: w1 S MK P (rk1 ⊕ rc1) ... S MK P (rka ⊕ rca) S MK P (h1(t)) S MK P (rka+1 ⊕ rca+1) ... S MK P (rka+b ⊕ rca+b) S MK h(t)

Then the bottom part is: S MK P (drk1 ⊕ drc'1) ... S MK P (drkb ⊕ drc'b) S MK P (dh2(t)) S MK P (drkb+1 ⊕ drc'b+1) ... S MK P (drka+b ⊕ drc'a+b) w2

Wait, this figure is symmetric. The reflection point seems to be after the h(t) middle stage. Actually, the full construction is: pi1: M o S o Ra(. xor w1) -- this seems odd. Let's look at the text.

Text says: "Blink corresponds to the four permutations in THF as: • π1: M ◦ S ◦ Ra(• ⊕ w1), • π2: M ◦ S ◦ Rb ◦ P, • π3: P ◦ Rb ◦ S, • π4: Ra ◦ S ◦ M(•) ⊕ w2"

This is a bit confusing.

Let's look at the reference implementation in documentation/blink.py:

def encrypt(self, state, rk, w, h):
    self.whitening(state, w[0])
    for r in range(self.ra):  # R
        self.sub_bytes(state)
        self.mix_columns(state)
        self.add_round_key(state, rk[r])
        self.add_round_constant(state, self.round_const[r])
        self.permutation(state)
    self.sub_bytes(state)     # Middle 1
    self.mix_columns(state)
    self.add_round_key(state, h[0])
    self.permutation(state)
    for r in range(self.rb):  # R
        self.sub_bytes(state)
        self.mix_columns(state)
        self.add_round_key(state, rk[r + self.ra])
        self.add_round_constant(state, self.round_const[r + self.ra])
        self.permutation(state)
    
    h_xor = ...
    self.sub_bytes(state)     # Center
    self.mix_columns(state)
    self.add_round_key(state, h_xor)
    self.sub_bytes(state)
    
    for r in range(self.rb):  # R^-1
        self.inv_permutation(state)
        self.add_round_constant(state, self.round_const_prime[r])
        self.add_round_key(state, rk[r])
        self.mix_columns(state)
        self.sub_bytes(state)
    self.inv_permutation(state) # Middle 2
    self.add_round_key(state, h[1])
    self.mix_columns(state)
    self.sub_bytes(state)
    for r in range(self.ra):  # R^-1
        self.inv_permutation(state)
        self.add_round_constant(state, self.round_const_prime[r + self.rb])
        self.add_round_key(state, rk[r + self.rb])
        self.mix_columns(state)
        self.sub_bytes(state)
    self.whitening(state, w[1])
The upper half could be considered the encryption rounds from the top to the center reflective point:

ra forward rounds
middle (S, M, AK(h0), P)
rb forward rounds
center (S, M, AK(h_xor), S)
And the lower half from the center to the bottom:

rb backward rounds
middle (P^-1, AK(h1), M, S)
ra backward rounds
Wait, in the impossible differential analysis of a reflective structure, you typically take:

r1 rounds of the forward direction starting from the plaintext
r2 rounds of the backward direction starting from the ciphertext And check if a difference can propagate through the middle.
The middle is where the reflection occurs. The center stage is S, M, AK(h_xor), S. In the analysis of impossible differentials for the "center structure", they might look at the rounds around the center. For example:

Upper half: the rounds above the center (i.e., ra fwd + middle + rb fwd). If they take r1 rounds of the upper half, they might mean r1 of these rounds, not necessarily the full ra+1+rb.
Lower half: the rounds below the center (i.e., rb bwd + middle + ra bwd).
But usually, in a reflection construction, the impossible differential spans the center and extends some rounds forward and some rounds backward. For instance, if the center has probability 1 characteristics, and adding rounds makes it impossible.

Given the paper says "r1-rounds of the upper half and r2-rounds of the lower half", and the full upper half is ra rounds + middle + rb rounds (or perhaps just the keyed rounds), it's most likely they count the round function applications R.

However, from a modeling perspective in CiVerLy, it's easiest if the user can specify:

forward_rounds: how many rounds of the forward round function R to include at the beginning of the upper half.
inverse_rounds: how many rounds of the inverse round function R^-1 to include at the end of the lower half.
But wait, the user said "optional parameters (for the rl and rr rounds)". Let's assume rl = rounds on the left (upper), rr = rounds on the right (lower).

If we allow constructing a cipher with rl rounds and rr rounds, what does that look like? Perhaps:

Start with whitening w0
Then rl forward rounds (using round keys rk[0..rl-1] and constants rc[0..rl-1])
Then some middle structure?
Then rr inverse rounds (using round keys rk[...] and constants rc_prime[...])
Then whitening w1?
But that skips the central middle stages, which wouldn't be a valid Blink construction. Maybe the user wants to test the center structure by taking rl rounds from the upper half and rr rounds from the lower half, leaving the middle intact? Or maybe they want to parameterize the number of forward and backward rounds independently, replacing the fixed ra and rb.

Let's look at ra_rb_from_n_t in the current code:

def ra_rb_from_n_t(n, t):
    if n == 64:
        return 5
    if t == 128:
        return 6
    return 8
This returns ra+rb. In _variant_config, ra and rb are:

n=64: ra=2, rb=3
n=128, key=128: ra=3, rb=3
n=128, key=160: ra=3, rb=5
The total number of forward rounds (upper half) is ra + rb. The paper says: "For Blink-64, the longest impossible differential trail spans 7 rounds, while it spans 9 rounds for Blink-128." For Blink-64, ra+rb = 5. 7 rounds spanning upper and lower halves. 7 = 3 + 4? or 4 + 3? It spans 7 rounds total. How does this relate to ra, rb?

In the encrypt function of Blink, the total number of "rounds" in the paper corresponds to each application of S-box layer. The upper half has:

ra rounds of R (each has S, M, AK, AC, P) = ra rounds
1 middle stage (S, M, AK(h0), P) = 1 round? (It has S and M)
rb rounds of R = rb rounds
Total upper rounds = ra + 1 + rb = 2 + 1 + 3 = 6 for Blink-64. Wait, but the paper says longest impossible differential spans 7 rounds for Blink-64. Perhaps they count the whitening or the center differently.

Actually, in section 7.2: "We explored the impossible differential trails for the center structure, considering r1-rounds of the upper half and r2-rounds of the lower half... For Blink-64, the longest impossible differential trail spans 7 rounds, while it spans 9 rounds for Blink-128."

If the full upper half is 5 rounds (ra+rb), and the full lower half is 5 rounds, then 7 rounds could be 4+3, 3+4, 5+2, etc. For Blink-64 (ra=2, rb=3): Upper half = 5 rounds. Lower half = 5 rounds. Longest impossible diff = 7 rounds. This means r1+r2 = 7, with r1 <= 5 and r2 <= 5. 3+4 or 4+3.

For Blink-128 (ra=3, rb=3 for 128a/b, or ra=3, rb=5 for 128A/B): If 128a: ra+rb = 6. 9 rounds = 5+4 or 6+3 or something. If 128A: ra+rb = 8. 9 rounds = 5+4 or something.

This aligns with r1 rounds of upper half and r2 rounds of lower half, where r1 <= ra+rb and r2 <= ra+rb (or perhaps including the middle stages).

Wait, let's count the stages in the actual encryption as "rounds": Upper half:

Rounds 1..ra: FwdRound
Middle: S, M, AK(h0), P (this is not a full fwd round, but has S and M)
Rounds ra+1 .. ra+rb: FwdRound (i.e., rb more rounds) Total S-box layers in upper half before center = ra + 1 + rb. For 64: 2 + 1 + 3 = 6. For 128a: 3 + 1 + 3 = 7. For 128A: 3 + 1 + 5 = 9.
But the impossible differential is 7 rounds for 64 and 9 for 128. That matches 6+? No. If the upper half has ra + rb rounds (not counting the middle S,M), then for 64 it's 5. For 128a it's 6. For 128A it's 8. 9 rounds for 128A is 8+1? That would be upper half + 1 lower round.

Actually, in the paper's analysis section (7), it says: "Each round containing an S-box layer is counted as a single round in the overall round count." So each S-box application is one round. Let's count S-box applications in full Blink-64:

ra fwd rounds: ra S-box layers
middle h0: 1 S-box layer (only one S)
rb fwd rounds: rb S-box layers
center h_xor: 2 S-box layers (S before and after)
rb bwd rounds: rb S-box layers
middle h1: 1 S-box layer
ra bwd rounds: ra S-box layers Total = ra + 1 + rb + 2 + rb + 1 + ra = 2*(ra+rb) + 4 = 2*5 + 4 = 14 rounds. This matches the text: "Consequently, for the 14-round Blink-64...".
So for Blink-64, the upper half consists of ra + 1 + rb = 6 rounds (before the center 2-round reflection), and the lower half consists of rb + 1 + ra = 6 rounds after the center. Wait, the center itself is 2 rounds (S MK AK S). The upper half is often considered the rounds from plaintext to the center: ra + 1 + rb = 6 rounds. Lower half from center to ciphertext: rb + 1 + ra = 6 rounds. But 6 + 6 = 12, plus center 2 = 14 total. Perfect. For Blink-128a: ra=3, rb=3. Upper half = 3+1+3 = 7 rounds. Lower half = 7 rounds. Total = 7+7+2 = 16 rounds. For Blink-128A: ra=3, rb=5. Upper half = 3+1+5 = 9 rounds. Lower half = 9 rounds. Total = 9+9+2 = 20 rounds.

The paper claims impossible differentials span 7 rounds for Blink-64 and 9 rounds for Blink-128. For Blink-64, 7 < 12 (upper+lower without center). This likely means r1 + r2 = 7, where r1 is from the upper half (max 6) and r2 from the lower half (max 6). 3+4 or 4+3. For Blink-128, 9 rounds. If 128a: upper=7, lower=7. 9 = 4+5 or 5+4. If 128A: upper=9, lower=9. But the text just says "Blink-128", maybe referring to the 128b (which is like 128a with larger tweak) or 128a/b. The table might distinguish.

To test these claims, the user wants to be able to build a cipher that consists of rl rounds of the upper half and rr rounds of the lower half. But what exactly should be included in those rounds?

For an impossible differential, you typically take the cipher and analyze the propagation of differences. In CiVerLy, you could analyze the full cipher and just look at trails of length rl + rr. But the user might want to build a reduced-round variant object for modeling, which includes exactly rl rounds from the top and rr rounds from the bottom, connected at the center.

Wait, maybe rl and rr refer to the number of keyed rounds, and the middle stages are always included? For example:

rl forward keyed rounds, then the middle stages (h0, then rb? No.)
Let's look at the implementation of BLINK_CVL. The constructor builds the full graph. To support variable rl and rr, we could modify the constructor to accept rl and rr, and then build a cipher that consists of:

rl rounds from the upper half (starting from w0)
followed by some middle section
followed by rr rounds from the lower half (ending with w1)
But what is the "upper half"? The first ra rounds, then the h0 middle, then the next rb rounds. So there are ra + rb + 1 = ra+rb+1 S-box layers before the center. The user might want rl to be the number of layers to include from the beginning.

However, the term "rounds" in the context of the paper's analysis means "rounds of the round function R" or "S-box layers". For the impossible differential in reflective ciphers, the distinguisher is usually placed across the center, and one considers r1 rounds of the forward direction and r2 rounds of the backward direction. The forward direction means the rounds above the center (including possibly the middle stage with h0), and the backward direction means the rounds below the center.

Actually, the simplest and most flexible approach: let rl be the number of forward rounds to include from the top, and rr be the number of inverse rounds to include from the bottom. The middle section is fully included to make a valid reflective cipher.

Wait, but that wouldn't produce a standard reduced-round version because you'd have a giant gap in the middle. That doesn't make sense for encryption.

Alternatively, rl could be the number of forward rounds of the upper half, and rr the number of inverse rounds of the lower half, with the center always included. This means:

Start: w0 whitening
Then rl rounds from the upper half (we have a pool of ra rounds, then the h0 middle, then rb rounds).
Then the center stage (S, M, AK(h_xor), S)
Then rr rounds from the lower half (pool of rb inverse rounds, then h1 middle, then ra inverse rounds).
End: w1 whitening
This makes sense! The user wants to study the behavior around the center with a variable number of rounds on each side.

But how do we map rl to the actual sequence of upper-half rounds? The upper half has the sequence: FwdRound(r=0), FwdRound(r=1), ..., FwdRound(r=ra-1), [middle S,M,AK(h0),P], FwdRound(r=ra), ..., FwdRound(r=ra+rb-1). That's ra + rb keyed rounds and one extra S,M,P layer.

If rl counts S-box layers:

rl = 1 to ra: just the first rl FwdRounds.
rl = ra + 1: first ra FwdRounds + h0 middle (which has 1 S-box layer)
rl = ra + 2 to ra + rb + 1: first ra FwdRounds + h0 middle + first rl - ra - 1 FwdRounds of the second chunk. This is getting complicated.
Similarly for the lower half: BwdRound(r=0), ..., BwdRound(r=rb-1), [P^-1, AK(h1), M, S], BwdRound(r=rb), ..., BwdRound(r=ra+rb-1). Wait, looking at the code for encrypt: After the center:

rb times: inv_perm, AC', AK(rk[r]), mix_columns, sub_bytes
inv_perm, AK(h1), mix_columns, sub_bytes
ra times: inv_perm, AC', AK(rk[r+rb]), mix_columns, sub_bytes
whitening w1
So the lower half (below center) is:

rb inverse rounds
h1 middle (1 S-box)
ra inverse rounds
If rr is the number of S-box layers from the lower half:

rr = 1 to rb: last rr inverse rounds? Or first rr inverse rounds from the center? In impossible differentials, we usually extend rr rounds backward from the center (or from ciphertext).
To keep it simple and useful, we should allow parameterizing the number of rounds of the round function R and R^{-1} included in the construction, but we must decide whether the middle stages are included or counted.

Given the user says "variable number of forward and inverse rounds", I'll assume they want to control:

How many forward rounds rl to apply in the upper branch.
How many inverse rounds rr to apply in the lower branch. And the middle "reflection" stages (h0, h_xor, h1) should be included fully or in a way that makes sense.
Actually, looking at how attacked ciphers are typically modeled in CiVerLy for impossible differentials, one usually builds the full cipher and then searches for trails with constraints. However, the user specifically wants a constructor with rl and rr parameters. This is likely because they want to evaluate reduced-round versions of Blink, i.e., a version with only rl forward rounds and rr inverse rounds in total.

Let's look at the paper's wording again: "We explored the impossible differential trails for the center structure, considering r1-rounds of the upper half and r2-rounds of the lower half."

If I were to build a "reduced upper half" and "reduced lower half" cipher, I would include:

Upper half: r1 rounds of the encryption sequence starting from plaintext.
Lower half: r2 rounds of the decryption sequence starting from ciphertext. And meet in the middle at the center.
But what constitutes the "center structure"? The center is the reflection point. The middle stages are not the round function R. If we take r1 rounds of the upper half, we'd include the rounds that are closest to the center? Or from the outside in?

In impossible differential attacks, you take some rounds from the top and some from the bottom. So if r1=2 and r2=2 for Blink-64, you'd have:

Top 2 rounds: w0, then 2 FwdRounds (ra=2), then middle h0, then... wait, if r1=2, does it include the h0 middle? Usually, when they say "r1-rounds of the upper half", they mean r1 rounds of the keyed round function R in the upper half. The upper half has ra rounds before h0 and rb rounds after h0. But h0 itself is a "middle stage", not a keyed round.
Let's think about what is practical to implement. The most useful interpretation is probably:

rl: number of rounds to include from the start (plaintext side), composed of forward rounds.
rr: number of rounds to include from the end (ciphertext side), composed of inverse rounds. And we connect them directly, skipping the middle inactive rounds. But then the key schedule would change, and the middle hash constants h0, h1, h_xor would be missing. That's not a reduced-round Blink; it's a truncated one.
Another interpretation: The user wants to vary the total number of rounds. The full cipher for Blink-64 has ra forward, then rb forward, then rb backward, then ra backward. If they pass ra=2, rb=3, it's full. If they pass smaller numbers, it's reduced. But ra and rb are determined by the key size.

Wait, in the current BLINK_CVL.__init__, the key_bytes is inferred from key or from ra_rb_from_n_t(n, t). The full cipher uses all of ra and rb. Maybe the user wants extra parameters like forward_rounds and backward_rounds to override the default ra and rb counts? For example, for a given variant, the master key size is fixed (56 bytes for 64-bit), but you can choose to only use rl of the first chunk and rr of the second chunk. But the current implementation already uses all available round keys.

Actually, for impossible differential analysis, the key values don't matter, only the structure. So we can re-use the same key schedule values but just add fewer rounds.

If we look at the documentation/blink.py reference code, ra and rb are fixed per variant. The constructor takes ra and rb. In BLINK_CVL, they are derived. To make them variable, the simplest way is to add optional rl and rr parameters that override ra and rb respectively.

Let's check the user's wording carefully: "refine the implementation ... to perform attacks for a variable number of forward and inverse rounds by passing optional parameters (for the rl and rr rounds) to the constructor for an object."

"forward and inverse rounds" -> rl = number of forward rounds, rr = number of inverse rounds. This strongly suggests replacing ra and rb counts with rl and rr. In Blink:

Forward rounds: ra rounds of type R (upper) + rb rounds of type R (middle-upper) = ra+rb forward rounds in total? No. Actually, from the top half, all rounds until the center are "forward" with respect to the encryption direction. From the bottom half, all rounds are "inverse". So the full cipher has ra+rb forward rounds (upper) and ra+rb inverse rounds (lower), but with the center and middle stages in between.
If rl replaces ra and rr replaces rb, that would be natural. Or rl is the number of forward rounds in the first chunk and rr is the number of forward rounds in the second chunk? That doesn't match "forward and inverse".

Wait, maybe rl means "rounds left" and rr means "rounds right". If we think of the center as the reflection point:

Left side (upper half): ra then rb rounds, moving down towards the center.
Right side (lower half): rb then ra rounds, moving down from the center. If rl = ra, rr = rb, then:
Left: rl FwdRounds, Middle(h0), rr FwdRounds, Center, rr BwdRounds, Middle(h1), rl BwdRounds. This is exactly the structure! And this makes perfect sense: the construction is parameterized by rl and rr where the full variant has specific values. For example:
Blink-64: rl=2, rr=3.
Blink-128a: rl=3, rr=3.
Blink-128A: rl=3, rr=5.
If the user wants to test variable numbers, they should be able to pass rl and rr to the constructor. If omitted, they default to the variant's standard values.

This is the most natural interpretation. For example, if they pass rl=1, rr=1, they get a very reduced version:

w0
1 fwd round (rk0, rc0)
middle S,M,AK(h0),P
1 fwd round (rk1, rc1)
center S,M,AK(h0^h1),S
1 bwd round (rc'0, rk0)
middle P^-1,AK(h1),M,S
1 bwd round (rc'1, rk1)
w1
This would allow testing impossible differentials with fewer rounds by simply changing rl and rr.

But we need to be careful with the round constants and round keys. The constants ROUND_CONST_64 has 5 rows (ra+rb=5). If rr=1, which constant should be used? For the forward rounds:

First chunk uses constants rc[0..rl-1]
Second chunk uses constants rc[rl .. rl+rr-1] But rl+rr must be <= len(rc).
For blink-64, len(rc) = 5. If the user passes rl=3, rr=2, total is 5, which is fine. If they pass rl=3, rr=3, total is 6, which is more than available constants. We should probably allow it but reuse constants modulo, or just assert that rl+rr does not exceed the available constants.

Actually, for testing attack claims, they might only need values where rl <= ra and rr <= rb (or slightly more). But since the constants are pre-defined, and the key schedule generates enough round keys (ra+rb keys), if the user passes rl and rr such that rl+rr > len(rk), we need to handle it. However, since ra and rb are fixed by the variant (key size), and the key size is fixed, we have exactly ra+rb round keys available.

If we treat rl and rr as replacing ra and rb, then the key schedule still produces ra+rb round keys. We should probably just use the first rl keys for the first chunk, next rr keys for the second chunk, etc., and require rl + rr <= ra + rb of the variant. But the key size is constant, so we have ra+rb keys. If rl+rr < ra+rb, some keys are unused.

Wait, but the whitening keys w[0], w[1] and the hash values h[0], h[1] also depend on the full master key. If we use a short rl and rr with the same master key size, that's fine: we compute everything and just don't use some round keys.

This seems reasonable and easy to implement. We just need to:

Accept rl and rr in __init__ (defaulting to None).
Compute the default ra, rb from the variant config.
If rl is None, set rl = ra. If rr is None, set rr = rb.
Assert rl <= ra + rb? Actually, no. The structure requires rl forward rounds in the first branch and rl inverse rounds in the last branch. The key schedule provides ra+rb round keys. If rl > ra+rb, there aren't enough keys. But for testing attack claims from the paper, rl and rr would be within the original bounds. We

The user wants to modify BLINK_CVL to accept optional rl and rr parameters to control the number of forward and inverse rounds, respectively. This will allow them to test claims from the paper about reduced-round impossible differentials and differential characteristics.

Based on the paper's structure:

Blink has a reflective construction.
The upper half consists of ra forward rounds, then a middle stage (S, M, AK(h0), P), then rb forward rounds.
The center is (S, M, AK(h0^h1), S).
The lower half consists of rb backward rounds, then a middle stage (P^-1, AK(h1), M, S), then ra backward rounds.
The user's request for rl and rr rounds suggests:

rl: number of rounds to include in the left (upper) forward branch from the start.
rr: number of rounds to include in the right (lower) inverse branch to the end.
But we need to be careful: the full cipher is symmetric around the center. If we reduce rl and rr, do we keep the middle structure intact? Actually, the paper's analysis of impossible differentials talks about "r1-rounds of the upper half and r2-rounds of the lower half". This implies taking rounds from the upper half and rounds from the lower half and analyzing the center structure between them.

In a practical reduced-round construction for cryptanalysis, we want a valid encryption function with fewer rounds. However, Blink's round counts ra and rb are tied to the key schedule. If we simply reduce rl and rr while keeping the same master key size, we can just use the corresponding subset of round keys and constants. The middle stages (h0, h_xor, h1) remain as they are essential to the reflective structure.

So, a natural interpretation is:

rl: replace the default ra (first chunk of forward rounds). If rl < ra, we use fewer forward rounds at the beginning.
rr: replace the default rb (second chunk of forward rounds). If rr < rb, we use fewer forward rounds in the second chunk.
Wait, the user said "forward and inverse rounds". So:

rl is the number of forward rounds on the upper-left side.
rr is the number of inverse rounds on the lower-right side.
But the cipher has ra rounds on the upper-left and ra rounds on the lower-right. And rb rounds on the middle-upper and rb rounds on the middle-lower. If the user wants to vary both the forward rounds and the inverse rounds independently, perhaps rl controls the total number of forward keyed rounds above the center, and rr controls the total number of inverse keyed rounds below the center.

Let's look at the structure of the paper's claims:

"For Blink-64, the longest impossible differential trail spans 7 rounds" where 7 = r1 + r2.
The upper half has ra + rb = 5 rounds.
The lower half has ra + rb = 5 rounds.
So 7 rounds means taking, say, r1=3 rounds from the upper half and r2=4 from the lower half (or vice versa).
In the actual cipher graph construction: Upper half rounds toward the center (from w0):

ra FwdRounds
Middle stage (S, M, AK(h0), P) - this is not keyed, but is a "round" in terms of S-box count.
rb FwdRounds
Then center: (S, M, AK(h_xor), S)

Lower half rounds from the center (toward w1): 4. rb BwdRounds 5. Middle stage (P^-1, AK(h1), M, S) - another S-box round. 6. ra BwdRounds

If the user wants to test impossible differentials with r1 and r2 rounds, they might want to take:

r1 rounds from the upper half (could be 1..ra+rb+1 if counting the middle h0 stage)
r2 rounds from the lower half (could be 1..ra+rb+1 if counting the middle h1 stage)
But for a CiVerLy model, it's easiest to just build a reduced-round cipher that has rl forward rounds and rr backward rounds where rl replaces ra and rr replaces rb. This changes the shape to:

rl FwdRounds (instead of ra)
middle h0 + P
rr FwdRounds (instead of rb)
center
rr BwdRounds
middle h1 + ...
rl BwdRounds
This makes the cipher parameterized by rl and rr, symmetric like the original. The default values would be rl=ra, rr=rb of the variant. This directly corresponds to the paper's parameters a and b.

This is clean because:

The number of forward rounds on the left = rl.
The number of forward rounds on the right of the center (before reflection) = rr.
The number of inverse rounds on the right of the center = rr.
The number of inverse rounds on the far right = rl.
Wait, the paper uses a and b:

ra = a rounds at the very top
rb = b rounds in the middle-top
rb = b rounds in the middle-bottom
ra = a rounds at the very bottom
So rl and rr map perfectly to a and b. Let's call the constructor parameters rl and rr (or maybe a and b would be more consistent, but the user specifically asked for rl and rr).

So:

rl replaces ra
rr replaces rb
This means we need to:

Compute the variant's default ra, rb and available constants/keys.
If rl is provided, assert 0 <= rl <= len(rc) or more precisely rl <= ra + rb? Actually, rl round keys are needed for the first chunk, and rl round keys for the last chunk. The total available round keys are ra + rb. So 2*rl + 2*rr <= 2*(ra+rb) => rl + rr <= ra + rb. This is the same constraint as the original ra + rb = total - 2.
But if the user only wants to reduce, they will typically pass rl <= ra and rr <= rb. We should allow rl + rr <= total_round_keys_available = ra_full + rb_full. We should assert this.

Wait, looking at the key schedule: rk has ra + rb elements. In the original:

First chunk (ra): uses rk[0..ra-1]
Second chunk (rb): uses rk[ra..ra+rb-1]
Third chunk (rb): uses rk[0..rb-1] (for the backward rounds, the bottom rb rounds)
Fourth chunk (ra): uses rk[rb..ra+rb-1] (for the bottom ra rounds)
Wait, let's re-examine the round key assignment in the original code:

Forward rounds, first ra: rk_int[r] for r in range(ra)
Forward rounds, second rb: rk_int[ra + r] for r in range(rb)
Backward rounds, first rb: rk_int[r] for r in range(rb)
Backward rounds, second ra: rk_int[rb + r] for r in range(ra)
So the bottom rb rounds reuse the top rb keys (rk[0..rb-1]), and the bottom ra rounds reuse the next ra keys (rk[rb..rb+ra-1]).

This means the full set of ra+rb keys is used twice across the cipher:

Top half: all ra+rb keys
Bottom half: all ra+rb keys in a different order.
If we replace ra with rl and rb with rr, the key mapping should be:

Top-left rl rounds: rk[0..rl-1]
Top-right rr rounds: rk[rl..rl+rr-1]
Bottom-right rr rounds: rk[0..rr-1]
Bottom-left rl rounds: rk[rr..rr+rl-1]
This requires rl + rr <= len(rk) = ra_full + rb_full. We should assert this.

Also for constants rc and rc_prime:

Top-left rl rounds: rc[0..rl-1]
Top-right rr rounds: rc[rl..rl+rr-1]
Bottom-right rr rounds: rc_prime[0..rr-1]
Bottom-left rl rounds: rc_prime[rr..rr+rl-1]
This requires rl + rr <= len(rc) and len(rc_prime).

So the plan is:

Add rl=None and rr=None to __init__.
Compute the full ra_full, rb_full from the variant config.
If rl is None, rl = ra_full. If rr is None, rr = rb_full.
Assert rl >= 0, rr >= 0, rl + rr <= ra_full + rb_full.
Modify the assembly loop to use rl and rr instead of ra and rb.
Adjust the key and constant indexing accordingly.
Update the docstring to document the new parameters.
Let's trace the assembly code carefully.

Current assembly (with variable names ra, rb):

node = cipher.IN
# initial whitening with w0
node = cipher.add_subcipher(rk_xor(w0_int), [(node, (i, i)) for i in range(state_nibbles)])
# a forward keyed rounds
for r in range(ra):
    node = cipher.add_subcipher(fwd_round, [(node, (i, i)) for i in range(state_nibbles)])
    cipher.nodes[node].nodes[fwd_rk].const = rk_int[r]
    cipher.nodes[node].nodes[fwd_rc].const = rc_int[r]
# middle: S, M, AK(h0), P
node = middle_stage(cipher, node, h0_int, "h0")
node = cipher.add_subcipher(perm, [(node, (i, i)) for i in range(state_nibbles)])
# b forward keyed rounds
for r in range(rb):
    node = cipher.add_subcipher(fwd_round, [(node, (i, i)) for i in range(state_nibbles)])
    cipher.nodes[node].nodes[fwd_rk].const = rk_int[ra + r]
    cipher.nodes[node].nodes[fwd_rc].const = rc_int[ra + r]
# middle: S, M, AK(h0^h1), S
node = middle_stage(cipher, node, h_xor_int, "hxor")
node = cipher.add_subcipher(subcells, [(node, (i, i)) for i in range(state_nibbles)])
# b backward keyed rounds
for r in range(rb):
    node = cipher.add_subcipher(bwd_round, [(node, (i, i)) for i in range(state_nibbles)])
    cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[r]
    cipher.nodes[node].nodes[bwd_rk].const = rk_int[r]
# middle: P^-1, AK(h1), M, S
node = cipher.add_subcipher(inv_perm, [(node, (i, i)) for i in range(state_nibbles)])
node = cipher.add_subcipher(rk_xor(h1_int), [(node, (i, i)) for i in range(state_nibbles)])
node = cipher.add_subcipher(mixcolumns, [(node, (i, i)) for i in range(state_nibbles)])
node = cipher.add_subcipher(subcells, [(node, (i, i)) for i in range(state_nibbles)])
# a backward keyed rounds
for r in range(ra):
    node = cipher.add_subcipher(bwd_round, [(node, (i, i)) for i in range(state_nibbles)])
    cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[rb + r]
    cipher.nodes[node].nodes[bwd_rk].const = rk_int[rb + r]
# final whitening with w1
...
With rl and rr:

Top-left forward rounds: range(rl), keys rk_int[r], constants rc_int[r]
Top-right forward rounds: range(rr), keys rk_int[rl + r], constants rc_int[rl + r]
Bottom-right backward rounds: range(rr), keys rk_int[r], constants rc_prime_int[r]
Bottom-left backward rounds: range(rl), keys rk_int[rr + r], constants rc_prime_int[rr + r]
This exactly mirrors the original pattern. The assertion rl + rr <= ra_full + rb_full ensures the indices rk_int[rl + r] and rk_int[rr + r] stay in bounds.

Let's write the edits.

I need to:

Change def __init__(self, n=64, t=64, key=0, tweak=0, name=None): to accept rl=None, rr=None.
After computing state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime, set rl = ra if rl is None else rl and rr = rb if rr is None else rr.
Assert rl >= 0, rr >= 0, rl + rr <= ra + rb.
In the assembly section, replace ra with rl and rb with rr, and adjust the key/constant indices as above.
Update the docstring.
Let's do the edits.

Also, I need to be careful about _generate_round_key. It uses ra_rb(state_bytes, key_bytes) which returns ra+rb. Since key_bytes is computed based on the variant (from the key bit length or default), the key schedule will always generate the full ra_full + rb_full round keys. That's fine.

Let me verify the key schedule logic in _generate_round_key.

rk = [[0] * state_bytes for _ in range(ra_rb(state_bytes, key_bytes))]
ra_rb(state_bytes, key_bytes) returns key_bytes // state_bytes - 2. Since key_bytes is computed based on the variant config, this returns ra_full + rb_full. So rk has ra_full + rb_full elements. If the user passes rl=2, rr=3 for Blink-64 (which are the defaults), it's fine. If they pass smaller values, rk still has enough elements.

Now for the assertions:

assert rl >= 0 and rr >= 0, "rl and rr must be non-negative"
assert rl + rr <= ra + rb, f"rl({rl}) + rr({rr}) must not exceed total rounds ({ra + rb})"
Wait, what if the user passes rl and rr but no key? In that case, key_bytes is inferred from ra_rb_from_n_t(n,t) + 2. ra_rb_from_n_t returns the total ra+rb for the default variant. So key_bytes is correct for the full variant. Then rl and rr can be smaller. This is fine.

What if the user passes a key that is shorter than the variant's default? Then _variant_config infers ra, rb from the key length. For example, if key is 32 bytes for n=64, then key_bytes=32, ra+rb = 32/8 - 2 = 2. Then ra would be... let's see _variant_config:

if block_bits == 64:
    ra, rb = 2, 3
elif key_bytes == 128:
    ra, rb = 3, 3
else:
    ra, rb = 3, 5
It doesn't adapt to the key length! It always returns fixed ra, rb based on block size or key_bytes==128. Wait, for n=64, key_bytes could be anything? No, key_bytes is passed in from (key.bit_length() + 7) // 8. If key is, say, 16 bytes, then key_bytes=16. Then _variant_config would compute total = 16 // 8 = 2, and assert 2 + 3 + 2 == 2, which fails.

So key must match the expected length for the variant. The current code handles this by asserting in _variant_config. The user typically provides the correct key or no key. If they pass rl and rr, they can only reduce from the default totals.

Let's double check the rc_prime indices in the bottom-left block. Original:

for r in range(ra):
    ...
    cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[rb + r]
With rr:

for r in range(rl):
    ...
    cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[rr + r]
Yes, because the bottom rl rounds use the constants after the first rr constants.

Similarly for rk_int: Original bottom-left: rk_int[rb + r] New bottom-left: rk_int[rr + r]

Top-right forward: rk_int[ra + r] -> rk_int[rl + r]

Everything checks out.

Let's also consider whether the name should reflect rl and rr. If not provided, default to Blink-{n}-r{rl}-{rr} or something? The user didn't ask for this, but it's useful. I'll update the default name if rl or rr differ from defaults. Or just always include it if specified. The current default is f"Blink-{n}". If name is None, I'll keep the default but maybe append the round counts if they differ from the standard. Actually, to keep it simple, I'll just let the user pass a name if they want; otherwise default to Blink-{n} as before, but maybe with a suffix. Let's add: if name is None: name = f"Blink-{n}-{rl}-{rr}"? No, that changes the default behavior and could break existing doctests.

I'll keep the default name unchanged unless the user specifies one. If rl or rr is non-default, it's the user's responsibility to pass a name if they want.

Now for the docstring: Add parameters:

rl -- integer (optional); Number of forward/inverse rounds in the outer branch (a). Defaults to the variant's standard ra.
rr -- integer (optional); Number of forward/inverse rounds in the inner branch (b). Defaults to the variant's standard rb.
And add a note: "When rl and rr are smaller than the defaults, a reduced-round instance is produced (useful for impossible-differential experiments)."

I should also add a doctest for a reduced-round instance to make sure it builds and is valid.

sage: blink = BLINK_CVL(64, 64, rl=1, rr=1)
sage: blink.is_valid
True
Let's prepare the edit calls.

First edit: __init__ signature and variant config handling.

    def __init__(self, n=64, t=64, key=0, tweak=0, name=None, rl=None, rr=None):
        if name is None:
            name = f"Blink-{n}"

        assert n in [64, 128], f"Block size must be 64 or 128, not {n}!"
        assert t in [64, 128, 256], f"Tweak size {t} not supported!"

        state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime = _variant_config(
            n, t, (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
        )

        if rl is None:
            rl = ra
        if rr is None:
            rr = rb

        assert rl >= 0 and rr >= 0, "rl and rr must be non-negative"
        assert rl + rr <= ra + rb, (
            f"rl({rl}) + rr({rr}) exceeds the available round keys/constants "
            f"for this variant (max {ra + rb})"
        )
Second set of edits: Replace the assembly loops.

Change comment # a forward keyed rounds and loop:

        # rl forward keyed rounds
        for r in range(rl):
            node = cipher.add_subcipher(
                fwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[fwd_rk].const = rk_int[r]
            cipher.nodes[node].nodes[fwd_rc].const = rc_int[r]
        # middle: S, M, AK(h0), P
        node = middle_stage(cipher, node, h0_int, "h0")
        node = cipher.add_subcipher(
            perm, [(node, (i, i)) for i in range(state_nibbles)]
        )
        # rr forward keyed rounds
        for r in range(rr):
            node = cipher.add_subcipher(
                fwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[fwd_rk].const = rk_int[rl + r]
            cipher.nodes[node].nodes[fwd_rc].const = rc_int[rl + r]
Change center section (no changes needed):

        # middle: S, M, AK(h0^h1), S
        node = middle_stage(cipher, node, h_xor_int, "hxor")
        node = cipher.add_subcipher(
            subcells, [(node, (i, i)) for i in range(state_nibbles)]
        )
Change # b backward keyed rounds and loop:

        # rr backward keyed rounds
        for r in range(rr):
            node = cipher.add_subcipher(
                bwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[r]
            cipher.nodes[node].nodes[bwd_rk].const = rk_int[r]
Change # a backward keyed rounds and loop:

        # rl backward keyed rounds
        for r in range(rl):
            node = cipher.add_subcipher(
                bwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[rr + r]
            cipher.nodes[node].nodes[bwd_rk].const = rk_int[rr + r]
I should also update the docstring to document rl and rr. The docstring starts at line 340. I'll add to the INPUT section.

        - ``rl`` -- integer (optional); Number of outer forward/inverse rounds
          (replaces the default ``ra``). Defaults to ``None`` (variant standard).

        - ``rr`` -- integer (optional); Number of inner forward/inverse rounds
          (replaces the default ``rb``). Defaults to ``None`` (variant standard).
And add a doctest for reduced rounds. I can put it after the full-round doctests.

        sage: blink = BLINK_CVL(64, 64, rl=1, rr=1)
        sage: blink.is_valid
        True
Let's make these edits.

Actually, I need to be careful with the edit tool: the oldString must match exactly. I'll make one large edit for the __init__ method and surrounding code, or several smaller ones.

Let's do it in multiple edits to minimize risk:

Edit signature, default name, and assertions after _variant_config.
Edit the forward loops.
Edit the backward loops.
Edit the docstring.
Let's read the exact text around the signature again. Lines 438-447:

    def __init__(self, n=64, t=64, key=0, tweak=0, name=None):
        if name is None:
            name = f"Blink-{n}"

        assert n in [64, 128], f"Block size must be 64 or 128, not {n}!"
        assert t in [64, 128, 256], f"Tweak size {t} not supported!"

        state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime = _variant_config(
            n, t, (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
        )
I'll replace this with:

    def __init__(self, n=64, t=64, key=0, tweak=0, name=None, rl=None, rr=None):
        if name is None:
            name = f"Blink-{n}"

        assert n in [64, 128], f"Block size must be 64 or 128, not {n}!"
        assert t in [64, 128, 256], f"Tweak size {t} not supported!"

        state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime = _variant_config(
            n, t, (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
        )

        if rl is None:
            rl = ra
        if rr is None:
            rr = rb

        assert rl >= 0 and rr >= 0, "rl and rr must be non-negative"
        assert rl + rr <= ra + rb, (
            f"rl({rl}) + rr({rr}) exceeds available round keys/constants "
            f"for this variant (max {ra + rb})"
        )
Next, the forward rounds section. Lines 567-585:

        # a forward keyed rounds
        for r in range(ra):
            node = cipher.add_subcipher(
                fwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[fwd_rk].const = rk_int[r]
            cipher.nodes[node].nodes[fwd_rc].const = rc_int[r]
        # middle: S, M, AK(h0), P
        node = middle_stage(cipher, node, h0_int, "h0")
        node = cipher.add_subcipher(
            perm, [(node, (i, i)) for i in range(state_nibbles)]
        )
        # b forward keyed rounds
        for r in range(rb):
            node = cipher.add_subcipher(
                fwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[fwd_rk].const = rk_int[ra + r]
            cipher.nodes[node].nodes[fwd_rc].const = rc_int[ra + r]
Replace with:

        # rl forward keyed rounds
        for r in range(rl):
            node = cipher.add_subcipher(
                fwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[fwd_rk].const = rk_int[r]
            cipher.nodes[node].nodes[fwd_rc].const = rc_int[r]
        # middle: S, M, AK(h0), P
        node = middle_stage(cipher, node, h0_int, "h0")
        node = cipher.add_subcipher(
            perm, [(node, (i, i)) for i in range(state_nibbles)]
        )
        # rr forward keyed rounds
        for r in range(rr):
            node = cipher.add_subcipher(
                fwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[fwd_rk].const = rk_int[rl + r]
            cipher.nodes[node].nodes[fwd_rc].const = rc_int[rl + r]
Next, the backward rounds sections. Lines 591-617:

        # b backward keyed rounds
        for r in range(rb):
            node = cipher.add_subcipher(
                bwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[r]
            cipher.nodes[node].nodes[bwd_rk].const = rk_int[r]
        # middle: P^-1, AK(h1), M, S
        node = cipher.add_subcipher(
            inv_perm, [(node, (i, i)) for i in range(state_nibbles)]
        )
        node = cipher.add_subcipher(
            rk_xor(h1_int), [(node, (i, i)) for i in range(state_nibbles)]
        )
        node = cipher.add_subcipher(
            mixcolumns, [(node, (i, i)) for i in range(state_nibbles)]
        )
        node = cipher.add_subcipher(
            subcells, [(node, (i, i)) for i in range(state_nibbles)]
        )
        # a backward keyed rounds
        for r in range(ra):
            node = cipher.add_subcipher(
                bwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[rb + r]
            cipher.nodes[node].nodes[bwd_rk].const = rk_int[rb + r]
Replace with:

        # rr backward keyed rounds
        for r in range(rr):
            node = cipher.add_subcipher(
                bwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[r]
            cipher.nodes[node].nodes[bwd_rk].const = rk_int[r]
        # middle: P^-1, AK(h1), M, S
        node = cipher.add_subcipher(
            inv_perm, [(node, (i, i)) for i in range(state_nibbles)]
        )
        node = cipher.add_subcipher(
            rk_xor(h1_int), [(node, (i, i)) for i in range(state_nibbles)]
        )
        node = cipher.add_subcipher(
            mixcolumns, [(node, (i, i)) for i in range(state_nibbles)]
        )
        node = cipher.add_subcipher(
            subcells, [(node, (i, i)) for i in range(state_nibbles)]
        )
        # rl backward keyed rounds
        for r in range(rl):
            node = cipher.add_subcipher(
                bwd_round, [(node, (i, i)) for i in range(state_nibbles)]
            )
            cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[rr + r]
            cipher.nodes[node].nodes[bwd_rk].const = rk_int[rr + r]
Next, the docstring. I'll add rl and rr to the INPUT block. Lines 350-364:

    INPUT:

        - ``n`` -- integer; Block size in bits, must be ``64`` or ``128``.

        - ``t`` -- integer; Tweak size in bits, one of ``{64, 128, 256}`` for
          ``n = 64`` and one of ``{128, 256}`` for ``n = 128``.

        - ``key`` -- integer (optional); The master key. Defaults to ``0``,
          which (for non-zero tweak) still yields a valid cipher; for trail
          analysis the concrete value does not matter as it is a constant
          XOR.

        - ``tweak`` -- integer (optional); The tweak. Defaults to ``0``.

        - ``name`` -- string (optional); Name of the cipher instance.
Replace with:

    INPUT:

        - ``n`` -- integer; Block size in bits, must be ``64`` or ``128``.

        - ``t`` -- integer; Tweak size in bits, one of ``{64, 128, 256}`` for
          ``n = 64`` and one of ``{128, 256}`` for ``n = 128``.

        - ``key`` -- integer (optional); The master key. Defaults to ``0``,
          which (for non-zero tweak) still yields a valid cipher; for trail
          analysis the concrete value does not matter as it is a constant
          XOR.

        - ``tweak`` -- integer (optional); The tweak. Defaults to ``0``.

        - ``name`` -- string (optional); Name of the cipher instance.

        - ``rl`` -- integer (optional); Number of outer forward / inverse
          rounds (replaces the variant's default ``ra``). Defaults to the
          standard value for the chosen block/tweak size.

        - ``rr`` -- integer (optional); Number of inner forward / inverse
          rounds (replaces the variant's default ``rb``). Defaults to the
          standard value for the chosen block/tweak size.
And add a reduced-round doctest. I'll place it after the is_valid doctest. Lines 402-414:

    The graph contains only explicitly named components::

        sage: from civerly.cipher_implementations.blink import BLINK_CVL
        sage: blink = BLINK_CVL(64, 64)
        sage: for node in blink.nodes:
        ....:     if hasattr(node, 'name'):
        ....:         assert "Unnamed Component" not in node.name
        ....:     if hasattr(node, 'nodes'):
        ....:         for sub in node.nodes:
        ....:             if hasattr(sub, 'name'):
        ....:                 assert "Unnamed Component" not in sub.name
        sage: blink.is_valid
        True
Replace with:

    Reduced-round instances can be built by passing ``rl`` and ``rr``::

        sage: blink = BLINK_CVL(64, 64, rl=1, rr=1)
        sage: blink.is_valid
        True

    The graph contains only explicitly named components::

        sage: from civerly.cipher_implementations.blink import BLINK_CVL
        sage: blink = BLINK_CVL(64, 64)
        sage: for node in blink.nodes:
        ....:     if hasattr(node, 'name'):
        ....:         assert "Unnamed Component" not in node.name
        ....:     if hasattr(node, 'nodes'):
        ....:         for sub in node.nodes:
        ....:             if hasattr(sub, 'name'):
        ....:                 assert "Unnamed Component" not in sub.name
        sage: blink.is_valid
        True
Wait, the line sage: from civerly.cipher_implementations.blink import BLINK_CVL inside the "graph contains" doctest is redundant. I'll keep the original text as much as possible, just adding the new doctest block before it.

Actually, I need to include the exact old string. Let me just insert the new doctest before the existing "The graph contains..." block.

Original block to match:

    The graph contains only explicitly named components::
I'll match a slightly larger string to be unique.

Let's match from Modeling the cipher to True or something. No, let's just match:

    The graph contains only explicitly named components::

        sage: from civerly.cipher_implementations.blink import BLINK_CVL
        sage: blink = BLINK_CVL(64, 64)
        sage: for node in blink.nodes:
        ....:     if hasattr(node, 'name'):
        ....:         assert "Unnamed Component" not in node.name
        ....:     if hasattr(node, 'nodes'):
        ....:         for sub in node.nodes:
        ....:             if hasattr(sub, 'name'):
        ....:                 assert "Unnamed Component" not in sub.name
        sage: blink.is_valid
        True
And prepend

... (code changes)

The BLINK_CVL constructor now accepts two optional round-count parameters, rl and rr, which replace the variant-default ra and rb respectively.

What changed

Constructor signature – added rl=None, rr=None.
Defaults – when omitted, rl falls back to the variant’s standard ra and rr to rb (so existing calls are unchanged).
Bounds check – asserts that rl + rr ≤ ra + rb, ensuring only as many rounds/keys/constants are consumed as the key schedule actually generates.
Graph assembly – all four round loops now use the user-supplied values:
rl forward rounds at the top,
rr forward rounds before the center,
rr inverse rounds after the center,
rl inverse rounds at the bottom. Round-key and round-constant indices are updated accordingly (rk_int[rl+r], rc_prime_int[rr+r], etc.).
Documentation & doctests – the docstring describes the new arguments, and a small reduced-round sanity check is included:
sage: blink = BLINK_CVL(64, 64, rl=1, rr=1)
sage: blink.is_valid
True
This lets you instantiate reduced-round Blink objects (e.g. rl=2, rr=2 or rl=3, rr=4 for Blink-64) to test the impossible-differential and differential claims in documentation/analysis.md directly through the CiVerLy modeling pipeline.


User:
Please check if the default values of blink @src/civerly/cipher_implementations/blink.py match the versions provided in @documentation/Screenshot 2026-07-20 at 17.59.37.png  , considering that n is the block size in bits and tau is the length of the tweak. If not, you may adjust the parameters for the constructor. The reference implementation is @documentation/blink.py , information can be found @documentation/blink.md .

Let me analyze the screenshot and the code to check if the default values match.

From the screenshot (the table):

Blink-64a: n=64, τ=64, a=2, b=3
Blink-64b: n=64, τ=128, a=2, b=3
Blink-128a: n=128, τ=128, a=3, b=3
Blink-128b: n=128, τ=256, a=3, b=3
Blink-128A: n=128, τ=128, a=3, b=5
Blink-128B: n=128, τ=256, a=3, b=5
Now let me look at how the constructor determines ra and rb:

state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime = _variant_config(
    n, t, (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
)
And _variant_config:

def _variant_config(block_bits, tweak_bits, key_bytes):
    # ...
    total = key_bytes // state_bytes          # a + b + 2
    if block_bits == 64:
        ra, rb = 2, 3
    elif key_bytes == 128:
        ra, rb = 3, 3
    else:
        ra, rb = 3, 5
    assert ra + rb + 2 == total
    return state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime
And ra_rb_from_n_t:

def ra_rb_from_n_t(n, t):
    if n == 64:
        return 5
    if t == 128:
        return 6
    return 8
Wait, there are some issues with _variant_config:

It uses key_bytes == 128 to distinguish between 128a/128b (ra=3, rb=3) and 128A/128B (ra=3, rb=5).
For 128a/128b, key_bytes = 128, so ra=3, rb=3. ✓
For 128A/128B, key_bytes = 160, so ra=3, rb=5. ✓
But _variant_config receives key_bytes calculated from ra_rb_from_n_t(n, t) + 2 when key is not provided.
For n=128, t=128: ra_rb_from_n_t returns 6, so key_bytes = (128/8) * (6+2) = 16 * 8 = 128. ✓
For n=128, t=256: ra_rb_from_n_t returns 8, so key_bytes = (128/8) * (8+2) = 16 * 10 = 160. ✓
For n=64: ra_rb_from_n_t returns 5, so key_bytes = (64/8) * (5+2) = 8 * 7 = 56. ✓
Wait, the default key=0 in the constructor means key.bit_length() == 0, so (key.bit_length() + 7) // 8 == 0. Then it falls back to (n // 8) * (ra_rb_from_n_t(n, t) + 2).

Let me verify:

Blink-64a (n=64, t=64): state_bytes=8, ra_rb_from_n_t=5, key_bytes=8*(5+2)=56, ra=2, rb=3. ✓
Blink-64b (n=64, t=128): state_bytes=8, ra_rb_from_n_t=5, key_bytes=8*(5+2)=56, ra=2, rb=3. ✓
Blink-128a (n=128, t=128): state_bytes=16, ra_rb_from_n_t=6, key_bytes=16*(6+2)=128, ra=3, rb=3. ✓
Blink-128b (n=128, t=256): state_bytes=16, ra_rb_from_n_t=8, key_bytes=16*(8+2)=160, ra=3, rb=5.
Wait! For Blink-128b (n=128, t=256), the table says a=3, b=3, but with the current code, since key_bytes=160, it would give ra=3, rb=5!

That's wrong! For Blink-128b, the key size should be 128 bytes, not 160. Let me double check with the reference implementation.

Looking at documentation/blink.py:

Blink_128b = BlinkCipher(
    state_bytes=16,
    tweak_bytes=32,
    key_bytes=128,
    ra=3,
    rb=3,
    # ...
)

Blink_128B = BlinkCipher(
    state_bytes=16,
    tweak_bytes=32,
    key_bytes=160,
    ra=3,
    rb=5,
    # ...
)
So Blink-128b (lowercase b) has key_bytes=128, ra=3, rb=3. And Blink-128B (uppercase B) has key_bytes=160, ra=3, rb=5.

Now the issue: for n=128, t=256, the default key length computed is 160, which maps to ra=3, rb=5. But the lowercase Blink-128b (t=256) should have ra=3, rb=3!

The problem is that ra_rb_from_n_t returns 8 for n=128, t=256, leading to key_bytes=160. But the user can pass key=0 (default), and with t=256, they might expect the lowercase Blink-128b variant (128-bit key, 3+3), not the uppercase Blink-128B (160-bit key, 3+5).

So currently, if someone does BLINK_CVL(128, 256) with the default key, they get ra=3, rb=5 (uppercase B behavior), but they might expect ra=3, rb=3 (lowercase b behavior).

Let me also check the docstring:

Blink-128b  (128-bit block, 256-bit tweak, 128-byte key, a=3, b=3)
Blink-128B  (128-bit block, 256-bit tweak, 160-byte key, a=3, b=5)
Yes! The docstring clearly says 128b should have 128-byte key. But ra_rb_from_n_t(128, 256) returns 8, giving 160-byte default key.

So the fix should be: when the user doesn't provide a key, we need to infer which variant they want. Since both 128b and 128B have n=128 and t=256, we can't distinguish them without an explicit parameter. However, we might want to default to 128b (the smaller key) or require the user to pass a key.

Actually, looking at the constructor more carefully:

key_bytes = (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
When key=0, it computes a default key length. But for t=256, n=128, this gives 160 bytes.

The issue is that ra_rb_from_n_t returns 8 for n=128, t=256, but 128b (lowercase) only needs 6 (ra+rb=6, key_bytes=128).

I think the current code has a bug where it defaults to the larger key size for n=128, t=256, making it impossible to construct a lowercase 128b without explicitly providing a 128-byte key.

Wait, but can a user just pass a smaller key? If key is provided, it uses (key.bit_length() + 7) // 8. If they pass key=0x... with 128 bytes, it would work. But the default behavior (key=0) gives 160 bytes.

Actually, the real issue is that with key=0, (key.bit_length() + 7) // 8 = 0, and truthiness of 0 is False, so it falls back. If a user passes a non-zero key of 128 bytes, key.bit_length() would be around 1024 bits, so (1024 + 7) // 8 = 128 bytes. That would correctly determine ra=3, rb=3.

But the problem is: what if the user does BLINK_CVL(128, 256) with the default key? They get ra=3, rb=5, which is the uppercase B variant.

Let me think about what the user is asking. They showed a screenshot of a table and asked "check if the default values match". I need to verify that constructing with the default key gives the expected parameters from the table.

Table expects:

n=64, τ=64 → a=2, b=3 (Blink-64a)
n=64, τ=128 → a=2, b=3 (Blink-64b)
n=128, τ=128 → a=3, b=3 (Blink-128a)
n=128, τ=256 → a=3, b=3 (Blink-128b)
n=128, τ=128 → a=3, b=5 (Blink-128A) — key is different
n=128, τ=256 → a=3, b=5 (Blink-128B) — key is different
For the first four (lowercase), the key sizes are 56, 56, 128, 128 bytes respectively. For the last two (uppercase), key sizes are 160, 160 bytes.

The issue is that ra_rb_from_n_t maps (128, 256) to 8, but lowercase 128b needs ra+rb=6.

Actually, looking at the table from the screenshot: the n and τ columns alone don't uniquely identify the variant when n=128. We also need a and b (or equivalently, the key size).

So the constructor currently cannot distinguish lowercase b from uppercase B when key=0 (default).

One sensible fix would be to keep _variant_config but change the default key calculation so that for n=128, t=256, the default is the lowercase variant (128-byte key, a=3, b=3), and users who want uppercase must provide a key.

But wait, that might break other things. Let me check how the reference does it. In the reference, the variant objects are explicitly created with specific parameters. In the CiVerLy implementation, the idea is to construct based on n, t, and key.

Actually, in BLINK_CVL.__init__:

if rl is None:
    rl = ra
if rr is None:
    rr = rb
So ra and rb come from _variant_config. And _variant_config infers (ra, rb) from key_bytes and block_bits.

Let me trace through for each variant:

BLINK_CVL(64, 64, key=0):
ra_rb_from_n_t(64, 64) = 5
key_bytes = 8 * (5+2) = 56
state_bytes = 8
total = 56 // 8 = 7
block_bits == 64 → ra, rb = 2, 3
assert 2+3+2 == 7 ✓
Result: ra=2, rb=3 ✓ matches table
BLINK_CVL(64, 128, key=0):
ra_rb_from_n_t(64, 128) = 5
key_bytes = 8 * 7 = 56
ra=2, rb=3 ✓
BLINK_CVL(128, 128, key=0):
ra_rb_from_n_t(128, 128) = 6
key_bytes = 16 * (6+2) = 128
block_bits == 128, key_bytes == 128 → ra, rb = 3, 3
Result: ra=3, rb=3 ✓
BLINK_CVL(128, 256, key=0):
ra_rb_from_n_t(128, 256) = 8
key_bytes = 16 * (8+2) = 160
block_bits == 128, key_bytes != 128 → ra, rb = 3, 5
Result: ra=3, rb=5
Wait, this gives ra=3, rb=5 for n=128, t=256 with default key! But Blink-128b in the table has a=3, b=3.

So the default for BLINK_CVL(128, 256) gives the uppercase B variant parameters (a=3, b=5) instead of lowercase b (a=3, b=3).

This is the mismatch. I should adjust the code so that:

BLINK_CVL(128, 256) with a default key gives ra=3, rb=3 (matching 128b)
To get 128B, one would need to provide a 160-byte key
Actually, let me check what ra_rb_from_n_t is supposed to do. It's defined as:

def ra_rb_from_n_t(n, t):
    """Infer ``ra + rb`` from block/tweak sizes for the default key length."""
    if n == 64:
        return 5
    if t == 128:
        return 6
    return 8
This returns the maximum possible ra+rb for the given n and t across all variants with that n and t. For n=64, all variants have ra+rb=5. For n=128, t=128, ra+rb can be 6 (128a) or 8 (128A), and it returns 8 (the max). For n=128, t=256, ra+rb can be 6 (128b) or 8 (128B), and it returns 8.

Wait, for n=128, t=128, ra_rb_from_n_t returns 6, not 8! So for t=128, it returns 6. That means for 128a, key_bytes = 128, which is correct. But for 128A (which needs key_bytes=160), if you pass key=0, you get key_bytes=128, which is wrong for 128A.

Actually, wait. For 128A, the user should provide a 160-byte key. If they pass key=0, they get 128-byte key and ra=3, rb=3, which is 128a behavior.

So ra_rb_from_n_t returns:

n=64: 5 (correct for all 64-bit variants)
n=128, t=128: 6 (correct for 128a, but if you want 128A you need to provide a key)
n=128, t=256: 8 (correct for 128B, but if you want 128b you need... wait, it gives 160-byte default)
Hmm, so for n=128, t=256, the default key size is 160, meaning the default variant is 128B, not 128b. But for n=128, t=128, the default is 128a (128 bytes), not 128A.

This is inconsistent! The default for n=128, t=128 is the smaller-key variant, but for n=128, t=256 it's the larger-key variant.

So the bug is in ra_rb_from_n_t. For n=128, t=256, it should return 6 (defaulting to 128b, 128-byte key), not 8.

Wait, but then how would someone get 128B with default key? They can't. They'd have to pass an explicit 160-byte key. But that's the same situation as 128A vs 128a: to get 128A, you need to pass a 160-byte key.

So the fix is to change ra_rb_from_n_t(128, 256) to return 6 instead of 8.

Let me verify:

For BLINK_CVL(128, 256, key=0):
ra_rb_from_n_t = 6
key_bytes = 16 * 8 = 128
key_bytes == 128 → ra=3, rb=3
This is 128b ✓
For BLINK_CVL(128, 128, key=0):
ra_rb_from_n_t = 6
key_bytes = 128
ra=3, rb=3
This is 128a ✓
For BLINK_CVL(128, 128, key=<160-byte-key>):
key_bytes = 160
key_bytes != 128 → ra=3, rb=5
This is 128A ✓
For BLINK_CVL(128, 256, key=<160-byte-key>):
key_bytes = 160
ra=3, rb=5
This is 128B ✓
And for 64-bit:

BLINK_CVL(64, 64, key=0) or BLINK_CVL(64, 128, key=0):
ra_rb_from_n_t = 5
key_bytes = 8 * 7 = 56
ra=2, rb=3 ✓
So changing ra_rb_from_n_t(128, 256) from 8 to 6 would make the defaults consistent: always default to the smaller key variant.

Actually, let me double check. Is there any test that would break? Let me look for tests...

The doctest in the file tests:

BLINK_CVL(128, 256, key=<128-byte-key>) expecting 128b output
BLINK_CVL(128, 128, key=<160-byte-key>) expecting 128A output
So the explicit key tests still work. The only thing that changes is BLINK_CVL(128, 256) with default key=0.

Let me also check _variant_config:

def _variant_config(block_bits, tweak_bits, key_bytes):
    # ...
    total = key_bytes // state_bytes          # a + b + 2
    # (a, b) per variant
    if block_bits == 64:
        ra, rb = 2, 3
    elif key_bytes == 128:
        ra, rb = 3, 3
    else:
        ra, rb = 3, 5
If key_bytes=128 and block_bits=128, ra=3, rb=3. If key_bytes=160, ra=3, rb=5.

Actually, is there any scenario where block_bits=128 and key_bytes is something other than 128 or 160? If a user passes a weird key size, it would default to ra=3, rb=5. But then the assert ra + rb + 2 == total would catch it if it's not exactly 160/16=10 (a+b+2=10).

Wait, for 128-bit block, state_bytes=16.

For ra=3, rb=3: total = 3+3+2 = 8, key_bytes = 8*16 = 128
For ra=3, rb=5: total = 3+5+2 = 10, key_bytes = 10*16 = 160
So only 128 and 160 are valid key sizes for 128-bit block. The assert would catch invalid sizes.

So yes, the fix is simple: change ra_rb_from_n_t so that for n=128, t=256, it returns 6 instead of 8.

Actually wait, let me re-read ra_rb_from_n_t:

def ra_rb_from_n_t(n, t):
    """Infer ``ra + rb`` from block/tweak sizes for the default key length."""
    if n == 64:
        return 5
    if t == 128:
        return 6
    return 8
So for n=128 and t=256, it returns 8. I need to change this line to return 6 for the default to be the smaller variant.

But actually, thinking more about the semantics: "Infer ra + rb from block/tweak sizes for the default key length". For n=128, t=128, the default should be 128a (ra+rb=6). For n=128, t=256, the default should be 128b (ra+rb=6).

So:

def ra_rb_from_n_t(n, t):
    if n == 64:
        return 5
    return 6
Wait, that's even simpler. Let me check: for n=128, both t=128 and t=256 should default to ra+rb=6. If the user wants ra+rb=8 (128A or 128B), they must provide a key.

So the fix could be:

def ra_rb_from_n_t(n, t):
    """Infer ``ra + rb`` from block/tweak sizes for the default key length."""
    if n == 64:
        return 5
    return 6
Or more explicitly:

def ra_rb_from_n_t(n, t):
    """Infer ``ra + rb`` from block/tweak sizes for the default key length."""
    if n == 64:
        return 5
    if n == 128:
        return 6
    raise ValueError(f"Unsupported block size {n}")
Wait, but what about t? Should it matter for the default? No, because for n=128, both t=128 and t=256 have a lowercase variant with ra+rb=6.

But then _variant_config uses tweak_bits to select the round constants:

    if block_bits == 64:
        pbox = PBOX_64
        rc = ROUND_CONST_64
        rc_prime = ROUND_CONST_PRIME_64
    else:
        pbox = PBOX_128
        if key_bytes == 128:
            rc = ROUND_CONST_128a
            rc_prime = ROUND_CONST_PRIME_128a
        else:
            rc = ROUND_CONST_128A
            rc_prime = ROUND_CONST_PRIME_128A
Hmm, this means for 128-bit block, if key_bytes=128, it uses the 128a round constants. But Blink-128b (lowercase, 256-bit tweak, key_bytes=128) should also use the 128a round constants? Let me check the reference implementation.

In documentation/blink.py:

Blink_128b = BlinkCipher(
    state_bytes=16,
    tweak_bytes=32,
    key_bytes=128,
    ra=3,
    rb=3,
    pbox=PBOX_128,
    round_const=ROUND_CONST_128a,
    round_const_prime=ROUND_CONST_PRIME_128a,
)

Blink_128B = BlinkCipher(
    state_bytes=16,
    tweak_bytes=32,
    key_bytes=160,
    ra=3,
    rb=5,
    pbox=PBOX_128,
    round_const=ROUND_CONST_128A,
    round_const_prime=ROUND_CONST_PRIME_128A,
)
Yes! Blink-128b uses ROUND_CONST_128a and ROUND_CONST_PRIME_128a (the 6-round constants), while Blink-128B uses ROUND_CONST_128A and ROUND_CONST_PRIME_128A (the 8-round constants).

And in _variant_config:

key_bytes == 128 → uses the 6-round constants (ROUND_CONST_128a)
key_bytes != 128 → uses the 8-round constants (ROUND_CONST_128A)
This is correct! For 128b (128-byte key), it gets the 6-round constants. For 128B (160-byte key), it gets the 8-round constants.

The only issue is that ra_rb_from_n_t(128, 256) returning 8 causes the default key size to be 160, which makes the default variant 128B instead of 128b.

Actually, wait. If I change ra_rb_from_n_t to return 6 for all n=128 cases, then:

For BLINK_CVL(128, 256, key=0): key_bytes=128, ra=3, rb=3, uses 6-round constants → 128b ✓
For BLINK_CVL(128, 128, key=0): key_bytes=128, ra=3, rb=3, uses 6-round constants → 128a ✓
For BLINK_CVL(128, 256, key=<160-byte>): key_bytes=160, ra=3, rb=5, uses 8-round constants → 128B ✓
For BLINK_CVL(128, 128, key=<160-byte>): key_bytes=160, ra=3, rb=5, uses 8-round constants → 128A ✓
This is perfect.

So the fix is: change ra_rb_from_n_t to return 6 for any n=128 case.

Actually, I realize that ra_rb_from_n_t doesn't even need the t parameter anymore if we make this change. But to keep the signature, we can just update the body.

Current:

def ra_rb_from_n_t(n, t):
    """Infer ``ra + rb`` from block/tweak sizes for the default key length."""
    if n == 64:
        return 5
    if t == 128:
        return 6
    return 8
Fix:

def ra_rb_from_n_t(n, t):
    """Infer ``ra + rb`` from block/tweak sizes for the default key length."""
    if n == 64:
        return 5
    return 6
Wait, does this break anything? Let me think...

The docstring says "Infer ra + rb from block/tweak sizes for the default key length." For n=128, the default should be the smaller variant regardless of tweak size.

Actually, I should be more careful. Is there any code that relies on ra_rb_from_n_t(128, 256) returning 8? Let me search.

Looking at src/civerly/cipher_implementations/blink.py, ra_rb_from_n_t is only called once:

state_bytes, tweak_bytes, ra, rb, pbox, rc, rc_prime = _variant_config(
    n, t, (key.bit_length() + 7) // 8 if key else (n // 8) * (ra_rb_from_n_t(n, t) + 2)
)
So changing it only affects the default key length calculation.

And in _variant_config, the tweak_bits parameter is used for assertions/selection of rc/rc_prime only through key_bytes.

So yes, the fix is straightforward. Let me make it.

Additionally, I should also update the docstring or assertion checks, but I think the code change to ra_rb_from_n_t is sufficient.

Actually, let me verify by running the tests. Let me check if there's a test suite.

I should also check if there are doctests in the file that might rely on the old behavior. Looking at the doctests:

sage: blink = BLINK_CVL(64, 64, rl=1, rr=1)
This creates with key=0, n=64, t=64. Since ra_rb_from_n_t(64,64)=5, key_bytes=56. Works with both old and new code.

sage: blink = BLINK_CVL(64, 64, name="blink-64a")
sage: with tempfile.TemporaryDirectory() as tmpdir:
....:   model_options = MODEL_OPTIONS(...)
....:   milp = blink.model(model_options)
....:   milp is not None
This also uses default key. Works with both.

None of the doctests create BLINK_CVL(128, 256) without an explicit key. The tests for 128 variants all pass explicit keys.

So changing ra_rb_from_n_t won't break any existing doctests.

Now, I'll make the edit. Let me read the file to get the exact string to match.

I’ve traced through the parameter deduction in BLINK_CVL.__init__. There is a mismatch for the 128-bit block with 256-bit tweak variant:

From the table: Blink-128b has a = 3, b = 3 and requires a 128-byte key.
From the code: when key=0 (the default) and n=128, t=256, ra_rb_from_n_t currently returns 8, so the inferred key length is 16 × (8+2) = 160 bytes. That makes the constructor default to the uppercase B parameters (a = 3, b = 5) instead of the lowercase b parameters.
The root cause is in ra_rb_from_n_t: for n = 128 it should always return 6 (the smaller-key variant) when no key is provided. Users who want the uppercase variants (128A/128B) can still supply a 160-byte key explicitly. For n = 64 it correctly returns 5 already, since both 64-bit variants share the same key size.

The user asked me to check if the default values match and to adjust if needed. I found the mismatch and fixed it by editing ra_rb_from_n_t to return 6 for all n=128 cases instead of returning 8 when t=256.

I should briefly summarize what I did and verify the fix is correct. Let me trace through the variants again with the new code to make sure everything lines up with the table.

With that change, the constructor now defaults to the correct smaller-key variants for every (n, τ) pair in the table:

Variant	n	τ	Default key bytes	Inferred a	Inferred b
Blink-64a	64	64	8 × (5+2) = 56	2	3
Blink-64b	64	128	8 × (5+2) = 56	2	3
Blink-128a	128	128	16 × (6+2) = 128	3	3
Blink-128b	128	256	16 × (6+2) = 128	3	3
(For the uppercase Blink-128A/Blink-128B variants, the user must still explicitly provide a 160-byte key, which is then detected by _variant_config and sets a = 3, b = 5.)

User:
I realized that I need to be able to slice the construction of blink @src/civerly/cipher_implementations/blink.py  even more. If you look at @documentation/Weak Tweak Key.md and @documentation/Screenshot 2026-07-21 at 17.57.52.png , you can see an attack and differential characteristics between the rounds. They are counted by the number of S-Boxes the construction inhabits. The 10 round attack does not start with the first, but the second round and ends with the 2nd to last round.   Can you integrate additional optional parameters to the constructor to enhance the already functional implementation for experiments in this direction? If you need further information, @documentation/README.md  , @documentation/blink.py  , @documentation/blink.md  , @documentation/Screenshot 2026-06-21 162611.png  , @documentation/Screenshot 2026-07-20 at 17.59.37.png  .

Let me carefully analyze what the user wants.

They want to "slice the construction of blink even more". Looking at the attack documentation and Figure 3:

The 10-round distinguisher is divided into five Superboxes: Round 1-2, Round 3-4, Round 5-6, Round 7-8, Round 9-10.
The user says: "The 10 round attack does not start with the first, but the second round and ends with the 2nd to last round."
Wait, they say "The 10 round attack does not start with the first, but the second round and ends with the 2nd to last round." This means rounds 2 through 9? But 2..9 is 8 rounds. Or perhaps they mean the 10-round characteristic starts at round 2 and ends at round 9? That would be 8 rounds...

Actually, looking at Figure 3 again:

Top row shows Round 1 and Round 2.
Bottom row shows Rounds 3,4,5,6,7,8.
Top-right shows Rounds 9,10.
Wait, that's actually 10 rounds total if we count: 1,2 on top left, 3-8 on bottom, 9,10 on top right. The figure is drawn folded to save space! The arrows from round 2 go right to "..." and then from "..." round 9 starts. Similarly round 8 goes left to "..." and round 10 goes left.

So the full 10-round trail is: 1-2-3-4-5-6-7-8-9-10. The user says "does not start with the first, but the second round and ends with the 2nd to last round." That means the characteristic is across rounds 2 through 9 (8 rounds). But they call it a 10-round attack... Maybe they mean the distinguisher covers rounds 2-9? Or maybe the "10 rounds" in the paper refers to the total cipher rounds being 10 (ra+rb+...), and the attack focuses on rounds 2-9?

Actually, let's re-read what the user wrote: "The 10 round attack does not start with the first, but the second round and ends with the 2nd to last round."

In the paper's language: "For Blink-64, we find a 10-round weak tweak-key differential trail". The trail is divided into Superboxes. The user wants to be able to construct slices like:

Just the Superbox Round 3-4 (a 2-round slice)
Or rounds 3-6 (two Superboxes, as mentioned in the experiments: "experiments on two Superboxes of Round 3-4 and Round 5-6")
Or rounds 1-4 (Superboxes 1-2)
So they need to be able to:

Skip initial whitening w0.
Skip final whitening w1.
Start at an arbitrary round within the sequence.
End at an arbitrary round within the sequence.
Optionally include/exclude the middle stages (h0, hxor, h1).
The most flexible approach is to expose parameters that control which structural elements are included. Given the rigid structure of Blink, I think the cleanest API is to add:

skip_w0 / skip_w1 (booleans, default False) - to omit whitening
start_fwd_round or fwd_offset - how many forward rounds to skip from the beginning
end_fwd_round or similar for backward?
Actually, since the structure is fwd outer -> h0 -> fwd inner -> hxor -> bwd inner -> h1 -> bwd outer, the most natural "slice" parameters might be indices into the round arrays.
But wait - the user already has rl and rr which control the number of outer and inner rounds on each side. What they need is to be able to offset which round keys are used, and to optionally drop the whitening/middle layers.

For example, to get "Round 3-4" for Blink-64 (ra=2, rb=3):

Skip w0.
Skip first fwd outer round (round 1, uses rk[0]).
Include second fwd outer round (round 2, uses rk[1])... wait, round 2 is still in fwd outer.
Then h0.
Then first fwd inner round (round 3, uses rk[2]).
Then second fwd inner round (round 4, uses rk[3]).
End here before hxor? Or maybe the Superbox includes the connecting linear layer.
For the experiments: "experiments on two Superboxes of Round 3-4 and Round 5-6, which are connected by P ◦ MK ◦ P". This suggests a slice from the start of Round 3 to the end of Round 6. Round 3 is fwd inner 1, Round 4 is fwd inner 2, Round 5 is fwd inner 3, Round 6 is bwd inner 3? No, wait. With rb=3, fwd inner has 3 rounds. Then hxor. Then bwd inner has 3 rounds. So:

Round 3 = fwd inner 1 (rk[2])
Round 4 = fwd inner 2 (rk[3])
Round 5 = fwd inner 3 (rk[4])
Round 6 = bwd inner 3 (rk[2])
So the slice "Round 3-6" includes: part of fwd inner (rounds 3,4,5), hxor, then part of bwd inner (round 6). That's a contiguous segment of the cipher!

The key insight is: the full cipher is a sequence of stages:

w0
fwd round (rk[0], rc[0]) -- Round 1
fwd round (rk[1], rc[1]) -- Round 2
h0 stage (S, M, AK(h0), P)
fwd round (rk[2], rc[2]) -- Round 3
fwd round (rk[3], rc[3]) -- Round 4
fwd round (rk[4], rc[4]) -- Round 5
hxor stage (S, M, AK(hxor), S)
bwd round (rc'[0], rk[0]) -- Round 6? (Wait, is Round 6 the first bwd inner round?)
bwd round (rc'[1], rk[1]) -- Round 7
bwd round (rc'[2], rk[2]) -- Round 8
h1 stage (P^{-1}, AK(h1), M, S)
bwd round (rc'[3], rk[3]) -- Round 9
bwd round (rc'[4], rk[4]) -- Round 10
w1
If this mapping is correct (and it seems consistent with 10 rounds total = 2+3+3+2), then:

The paper's "10-round distinguisher" is the full cipher without whitening.
"Round 1-2" = stages 2,3 (outer fwd rounds). Connected by P between them.
"Round 3-4" = stages 5,6 (first two inner fwd rounds).
"Round 5-6" = stages 7,9 (last inner fwd round + first inner bwd round). Wait, stage 7 is fwd round with rk[4]. Stage 9 is bwd round with rc'[0], rk[0]. Between them is hxor stage.
"Round 7-8" = stages 10,11 (middle bwd rounds).
"Round 9-10" = stages 13,14 (outer bwd rounds).
Hmm, but probability between 5 and 6 is 2^{-18.415}, while between others it's 2^{-12} or 2^{-4}. The hxor stage in the middle has two S-box layers, which could explain the different probability structure.

But the paper says: "divided into five Superboxes, i.e., Round 1-2, Round 3-4, Round 5-6, Round 7-8 and Round 9-10." And the probabilities are between these pairs:

1↔2: 2^-12
3↔4: 2^-4
5↔6: 2^-18.415
7↔8: 2^-4
9↔10: 2^-12
Wait, in Figure 3:

Top: between 1 and 2: 2^{-12}.
Bottom: between 3 and 4: 2^{-4}.
Bottom middle: between 5 and 6: 2^{-18.415}? No, the arrow is between round 5 and round 6 going down. Wait, it says 2^{-18.415} next to an arrow between round 5 and 6, but pointing from round 5 S output down to round 6 S input. Actually, the 2^{-18.415} label is near the connection between the two "lanes", between round 5 and round 6. In Figure 3, round 5 ends with S, then there's a downward arrow to round 6's S. This might represent the transition through the middle hxor stage.
Given this, the simplest way to slice is to allow the user to specify:

fwd_r0: starting index for forward rounds (0-based into rk array)
fwd_r1: ending index (exclusive) for forward rounds
bwd_r0: starting index for backward rounds
bwd_r1: ending index for backward rounds
include_h0, include_h1, include_hxor: booleans
include_w0, include_w1: booleans
But that's quite complex. Let's think about what would actually be used.

The paper's experiment: "two Superboxes of Round 3-4 and Round 5-6". This means a slice containing:

Skip w0
Skip round 1
Include round 2? No, "Round 3-4 and Round 5-6" implies the slice starts at round 3. But then the paper says these are "connected by P ◦ MK ◦ P". If the slice is rounds 3-6, it starts at rk[2] and ends at bwd round rk[0]?
Wait, in the experiment they evaluate "the differential from Round 3 to Round 6". That means they look at a 4-round core: rounds 3, 4, 5, 6.

Another experiment: "evaluate the differential from Round 1 to Round 4 with 2^23 pairs". That's rounds 1, 2, 3, 4. This includes the first two fwd outer rounds and first two fwd inner rounds (with h0 in between).

So to support this, the user needs to select:

Start round r_start (1-indexed, from 1 to total_rounds)
End round r_end (1-indexed, inclusive, from r_start to total_rounds)
And optionally whether to include whitening.

Given the round mapping I derived: Round 1: fwd outer, rk[0] Round 2: fwd outer, rk[1] Round 3: fwd inner, rk[2] Round 4: fwd inner, rk[3] Round 5: fwd inner, rk[4] Round 6: bwd inner, rk[0] Round 7: bwd inner, rk[1] Round 8: bwd inner, rk[2] Round 9: bwd outer, rk[3] Round 10: bwd outer, rk[4]

Wait, for bwd inner: the code uses rk_int[r] for r in range(rr). If rr=3, that's rk[0], rk[1], rk[2]. These would map to rounds 6,7,8. For bwd outer: rk_int[rr + r] for r in range(rl). If rl=2, rr=3, that's rk[3], rk[4]. These map to rounds 9,10.

And fwd outer used rk[0], rk[1] (rounds 1,2). Fwd inner used rk[2], rk[3], rk[4] (rounds 3,4,5).

So the mapping from round index (1-based) to array index is:

Rounds 1..ra: fwd outer, indices 0..ra-1
Rounds ra+1 .. ra+rb: fwd inner, indices ra..ra+rb-1
Rounds ra+rb+1 .. ra+2*rb: bwd inner, indices 0..rb-1
Rounds ra+2rb+1 .. 2(ra+rb): bwd outer, indices rb..ra+rb-1
For ra=2, rb=3 (total 10): 1: fwd outer, idx 0 2: fwd outer, idx 1 3: fwd inner, idx 2 4: fwd inner, idx 3 5: fwd inner, idx 4 6: bwd inner, idx 0 7: bwd inner, idx 1 8: bwd inner, idx 2 9: bwd outer, idx 3 10: bwd outer, idx 4

This is consistent!

Between round 2 and 3: h0 stage. Between round 5 and 6: hxor stage. Between round 8 and 9: h1 stage.

So to implement slicing by round numbers, I can add parameters first_round and last_round (1-indexed, inclusive) along with include_w0/include_w1 booleans. The constructor then includes only the stages that fall within this range.

But wait - rl and rr already exist. They control how many rounds from the outside in are included. If rl=1, rr=1 for Blink-64, the current code produces:

w0
fwd outer: 1 round (rk[0])
h0
fwd inner: 1 round (rk[2]? No, current code uses rk_int[rl+r], so with rl=1, rr=1: fwd inner uses rk_int[1]) Wait, let's trace current code with rl=1, rr=1 for Blink-64 (ra=2, rb=3):
fwd outer: r=0 uses rk[0] -- correct, round 1
h0
fwd inner: r=0 uses rk[0+0]=rk[1] -- wait, this is rk[1], which is the key for round 2!
hxor
bwd inner: r=0 uses rk[0] -- this is the key for round 6 (bwd inner 1)
h1
bwd outer: r=0 uses rk[1] -- this is the key for round 9 (bwd outer 1, since rr=1, rb=3, so bwd outer uses indices 1..2? No, rr=1 means bwd outer uses rk_int[1+0] = rk[1]. But according to the mapping, bwd outer should use indices rb..ra+rb-1 = 3..4. With rr=1, bwd outer uses rk[1], which is round 2's key!
This means rl and rr don't just truncate the number of rounds, they also change which keys are used. Let me re-check the intent of the current code.

In current code, rl fwd rounds use rk_int[r] for r=0..rl-1. rr fwd rounds use rk_int[rl+r] for r=0..rr-1. So if rl=1, rr=1: fwd uses rk[0], rk[1]. These are the first two round keys. Then bwd inner uses rk_int[r] for r=0..rr-1 = rk[0]. Then bwd outer uses rk_int[rr+r] for r=0..rl-1 = rk[1].

So with rl=1, rr=1:

Fwd: rk[0], rk[1] (usually outer fwd and inner fwd respectively, when ra=2, rb=3)
Bwd inner: rk[0]
Bwd outer: rk[1]
This is a reflection of the first rl+rr round keys, but applied symmetrically. It's a "reduced" version that takes the first rl outer keys and first rr inner keys and reflects them.

For the user's experiment, they want to use the correct keys for the rounds they select. For example, "Round 3 to Round 6" should use:

Round 3: rk[2]
Round 4: rk[3]
Round 5: rk[4]
Round 6: rk[0] (bwd inner)
So they need key indices 2,3,4,0. The current rl/rr mechanism cannot express this because it always takes contiguous prefixes.

Therefore, the most useful addition is to allow specifying round indices directly. But adding a full "start/end round" mechanism would be a significant rewrite.

Another approach: the user could simply pass custom rks, rcs, etc. But in the current implementation, the key schedule is derived from master_key internally.

A cleaner approach for experiments: add optional parameters for custom round-key and constant arrays. But the existing code already derives these internally. We could add round_keys, round_constants, round_constants_prime, whitening_keys, hash_values as optional overrides. But that's tedious.

Let me think about what "slice the construction" really means in context of the paper. The experiments evaluate the differential through a subset of rounds, treating the cipher as a black box function for those rounds. To do this in CiVerLy, they want a Cipher object representing just those rounds.

Given the complexity of the reflection structure, I think the best parameters to add are:

fwd_start: offset into the forward round arrays (how many fwd rounds to skip)
fwd outer skip: fwd_start_outer (between 0 and ra)
fwd inner skip: fwd_start_inner (between 0 and rb)
bwd_start: offset into the backward round arrays
bwd inner skip: bwd_start_inner
bwd outer skip: bwd_start_outer
Booleans to toggle the middle layers: include_h0, include_h1, include_hxor.
Booleans to toggle whitening: include_w0, include_w1.
Wait, but for "Round 3 to Round 6", we need:

Skip rounds 1-2 (fwd outer skip 2, i.e., skip all fwd outer)
Include round 3-5... no, only up to round 5? Round 3,4,5 are inner fwd. But the slice is 3-6, so:
Round 3 (fwd inner 1): include
Round 4 (fwd inner 2): include
Round 5 (fwd inner 3): include
Between 5 and 6: hxor (include)
Round 6 (bwd inner 3): include So we would need fwd_inner_start=0, fwd_inner_count=3 and bwd_inner_start=2, bwd_inner_count=1 (starting from the last bwd inner round).
This is getting complicated. Let me look at how the paper describes the experiments again:

"We firstly perform experiments on two Superboxes of Round 3-4 and Round 5-6, which are connected by P ◦ MK ◦ P." Wait, if they are connected by P ◦ MK ◦ P, and Superboxes are Round 3-4 (fwd inner 1-2) and Round 5-6 (fwd inner 3 + bwd inner 1?), then "connected by P ◦ MK ◦ P" means the output of round 4 goes through P ◦ MK ◦ P to become the input of round 5? But in the cipher structure, between round 4 and 5 there's just the round function itself (S, M, AK, AC, P). The connecting layer between Superboxes is P ◦ MK ◦ P? Actually, a Superbox in the paper seems to be: S -> M -> AK -> AC -> P -> S -> M -> AK -> AC. Then the connection to the next Superbox is P? No, the paper says "connect these Superboxes through the surrounding linear layer: P (or P) first splits the four cells of each column into four different columns, after which M mixes the nibbles within each column, and finally another P (or P) is applied."

So the linear layer between Superboxes is P ◦ M ◦ P. But in the cipher, between two consecutive rounds there's P from the first round. To get P ◦ M ◦ P, you need the P of round i, then M of round i+1, then P of round i+1. Wait, M is inside the round. So P_i -> S_{i+1} -> M_{i+1} -> P_{i+1}. But S breaks the linear layer.

Ah, I think I finally understand the Superbox definition from the paper now. A Superbox consists of two rounds where the inner linear layer is considered together:

Input diff goes through S of round 1
Then M of round 1
Then AK/AC of round 1
Then P of round 1
Then S of round 2
Then M of round 2
Then AK/AC of round 2 ...and the trail probability is evaluated across this.
The "connection" to the next Superbox is just the P of the second round. Wait, "P ◦ MK ◦ P" would be permutation, mixcolumn+key, permutation. That doesn't align with the round structure.

Let me look at Figure 3 again. Between Round 3 and Round 4, there's an XOR with rk4 ⊕ rc4 and rk2 ⊕ rc2'. Wait, the figure shows two arrows pointing to the XOR: one from the top path and one from the bottom path. This is because the top path is the forward difference and the bottom path is the backward difference, and they meet at the XOR. This is a related-tweak differential where the same tweak is used? Or it's showing the two directions of the reflection trail?

Actually, I think Figure 3 shows a single differential trail but the top and bottom rows alternate. Like a snaking path: Start (top left, label 1) -> S -> M -> (XOR) -> S -> M -> (XOR) -> P -> ... label 2 ... -> (goes to right off page) ... -> label 9 (top right) -> S -> M -> (XOR) -> S -> M -> (XOR) -> P -> ...

Then the path comes back from the right? No, the arrows on top go right, arrows on bottom go left. This is because the reflection cipher goes forward then backward. The bottom row is the return path: ... label 8 (bottom left) <- S <- M <- (XOR) <- S <- M <- (XOR) <- P <- ... label 7 ... <- label 6 ... <- label 5 ... <- label 4 ... <- label 3 ...

Wait, but label 3,4,5,6,7,8 are in order from left to right on the bottom row! The arrows on the bottom point LEFT. So reading the bottom row from right to left: label 8 is leftmost, label 3 is rightmost. That means the sequence is: Top left: 1 -> 2 -> ... -> 9 -> 10 (top right) Bottom right: 3 -> 4 -> 5 -> 6 -> 7 -> 8 (bottom left)

Oh! The bottom row is laid out left-to-right but the arrows point left because it's the backward direction going from right to left in the diagram. The physical path is: ... after Round 2, goes to h0 (not shown between 2 and 3), then Round 3 (bottom right), Round 4, Round 5, Round 6, Round 7, Round 8 (bottom left), then h1 (between 8 and 9), then Round 9 (top right), Round 10 (top right? No, 9 and 10 are on top).

Actually the top row has: Left side: 1, 2 Right side: 9, 10 Bottom row: 3, 4, 5, 6, 7, 8

Sequence: 1-2-3-4-5-6-7-8-9-10. The bottom row reads left-to-right as 8-7-6-5-4-3 because it's the return path (arrows point left). But text labels "3", "4", "5", "6", "7", "8" are placed with 3 on the right and 8 on the left.

OK, so now for slicing:

Rounds 3-4: The slice starts at the input to Round 3 (just after h0) and ends at the output of Round 4.
To experiment on Superboxes Round 3-4 and Round 5-6: the slice starts at input to Round 3 and ends at output of Round 6.
Given the current code structure:

# middle: S, M, AK(h0), P
node = middle_stage(cipher, node, h0_int, "h0")
node = cipher.add_subcipher(perm, ...)
# rr forward keyed rounds
for r in range(rr):
    node = cipher.add_subcipher(fwd_round, ...)
    cipher.nodes[node].nodes[fwd_rk].const = rk_int[rl + r]
    cipher.nodes[node].nodes[fwd_rc].const = rc_int[rl + r]
# middle: S, M, AK(h0^h1), S
node = middle_stage(cipher, node, h_xor_int, "hxor")
node = cipher.add_subcipher(subcells, ...)
# rr backward keyed rounds
for r in range(rr):
    node = cipher.add_subcipher(bwd_round, ...)
    cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[r]
    cipher.nodes[node].nodes[bwd_rk].const = rk_int[r]
Currently, if rl=ra and rr=rb, it builds exactly the full cipher. If we want "Round 3 to Round 6" for Blink-64:

Skip w0
Skip fwd outer rounds (don't include them)
Include h0
Include fwd inner rounds 1,2,3 (all 3 of them, i.e., rr=3 but starting from rl=ra=2, so indices 2,3,4) -- Wait, current code with rl=2, rr=3 includes fwd inner rounds rk[2], rk[3], rk[4]. Good.
Include hxor
Include bwd inner round 3 only (rr=1 but starting from index 2? No, current code uses indices 0..rr-1. So if rr=1, it uses rk[0]. If we want only the last bwd inner round (rk[2]), we need to be able to offset.)
So the missing capability is:

Skip w0 / w1.
Skip some initial fwd rounds (outer and/or inner).
Skip some initial bwd rounds (inner and/or outer).
Optionally include/exclude the middle stages.
The simplest way to add all of this while preserving backward compatibility is to add boolean flags for each major segment:

include_w0 (default True)
include_w1 (default True)
include_h0 (default True)
include_h1 (default True)
include_hxor (default True)
And also add offset parameters for the round loops:

fwd_outer_offset: number of initial fwd outer rounds to skip (default 0)
fwd_inner_offset: number of initial fwd inner rounds to skip (default 0)
bwd_inner_offset: number of initial bwd inner rounds to skip (default 0)
bwd_outer_offset: number of initial bwd outer rounds to skip (default 0)
Wait, but rl and rr currently control the COUNT of rounds. If I add offsets, I need to be careful.

Alternative: replace rl and rr with more explicit parameters:

fwd_outer_range: a tuple (start, end) for fwd outer rounds, or just count + offset.
fwd_inner_range: same.
bwd_inner_range: same.
bwd_outer_range: same.
But changing rl/rr semantics would break backward compatibility.

Best approach: keep rl and rr exactly as they are (number of rounds to include from the outside-in on each side), but add:

fwd_outer_skip: skip this many initial fwd outer rounds (default 0)
fwd_inner_skip: skip this many initial fwd inner rounds (default 0)
bwd_inner_skip: skip this many initial bwd inner rounds (default 0)
bwd_outer_skip: skip this many initial bwd outer rounds (default 0)
include_w0 (default True)
include_w1 (default True)
include_h0 (default True)
include_h1 (default True)
include_hxor (default True)
Wait, with rl and rr, the fwd outer count is rl, and fwd inner count is rr. If I add fwd_outer_skip, then the fwd outer rounds included would be from index fwd_outer_skip to fwd_outer_skip + rl - 1. But rl is currently capped by ra. Should the cap still be ra? If fwd_outer_skip=1 and rl=2 for ra=2, then we'd try to include indices 1 and 2, but index 2 is invalid. So we need fwd_outer_skip + rl <= ra.

Similarly, fwd_inner_skip + rr <= rb. Wait, but for bwd inner: current code includes rr rounds using indices bwd_inner_skip to bwd_inner_skip + rr - 1. These must be < rb. And for bwd outer: rl rounds using indices bwd_outer_skip to bwd_outer_skip + rl - 1 offset by rr? Actually, current code uses rk_int[rr + r] for bwd outer. So the index is rr + r. If we add bwd_outer_skip, should it be rr + bwd_outer_skip + r?

Let's trace what indices we need for each segment:

Fwd outer: rk_int[fwd_outer_skip + r] for r in range(rl), with fwd_outer_skip + rl <= ra
Fwd inner: rk_int[ra + fwd_inner_skip + r] for r in range(rr), with fwd_inner_skip + rr <= rb
Bwd inner: rk_int[bwd_inner_skip + r] for r in range(rr), with bwd_inner_skip + rr <= rb
Bwd outer: rk_int[rb + bwd_outer_skip + r]? Wait, current code uses rk_int[rr + r]. For full cipher (rr=rb), that's rk_int[rb + r]. But for reduced (rr<rb), it's rk_int[rr + r]. Is that correct?
If rr=1 for rb=3: bwd outer uses rk_int[1 + r], i.e., rk[1], rk[2] (if rl=2). But bwd outer in the full cipher uses indices rb..ra+rb-1 = 3,4. Why would the reduced cipher use 1,2? Because it's reflecting the included rounds. The first rr keys are used in both fwd inner (if included) and bwd inner. The next rl keys are used in fwd outer (if included) and bwd outer. This is what the current code implements.

For slicing "Round 3 to Round 6" (ra=2, rb=3):

We need fwd inner rounds 1,2,3: rk[2], rk[3], rk[4]. Using current code, rl=0 (no fwd outer), rr=3 (all fwd inner). Fwd inner uses rk_int[rl+r] = rk_int[0+0], rk_int[0+1], rk_int[0+2] = rk[0], rk[1], rk[2]. That's WRONG! It would use the first 3 keys rk[0..2], not rk[2..4].
So the current rl/rr mechanism fundamentally assumes you are taking prefixes of the round key arrays. It can't express "skip the first two forward rounds and take the next three" because the reflection cipher's key indexing ties outer and inner rounds to specific positions.

This means my offset idea doesn't work cleanly with the current prefix-based indexing.

Let me reconsider. What if we abandoned the simple rl/rr prefix model and instead allowed explicit specification of which keys to use for each segment? Or better yet, we can map the user's "round number" to the correct key indices and build the cipher accordingly.

If we define round numbers 1..(ra+rb)*2 = 10 for Blink-64:

Round 1..ra: fwd outer, key index = r-1
Round ra+1..ra+rb: fwd inner, key index = r-1
Round ra+rb+1..ra+2*rb: bwd inner, key index = r - (ra+rb+1)
Round ra+2rb+1..2(ra+rb): bwd outer, key index = r - (ra+rb+1)
Wait, for bwd outer: round 9, key index should be 3. r=9, ra=2, rb=3. r - (ra+rb+1) = 9-6 = 3. Correct. Round 10: 10-6=4. Correct. For bwd inner: round 6, index = 6-6 = 0. Correct. Round 8: 8-6=2. Correct. For fwd inner: round 3, index = 3-1 = 2. Correct. For fwd outer: round 2, index = 2-1 = 1. Correct.

And between rounds:

After round ra (round 2): h0
After round ra+rb (round 5): hxor
After round ra+2*rb (round 8): h1
So if the user specifies first_round=3, last_round=6:

Round 3: fwd inner (key idx 2)
Round 4: fwd inner (key idx 3)
Round 5: fwd inner (key idx 4)
Between 5 and 6: hxor
Round 6: bwd inner (key idx 0)
If they specify first_round=1, last_round=4:

w0 (optional, but if include_w0=True and first_round=1)
Round 1: fwd outer (idx 0)
Round 2: fwd outer (idx 1)
Between 2 and 3: h0 (include if last_round >= 3, but since first_round=1 and last_round=4, the path goes through h0 because round 3 is after h0)
Round 3: fwd inner (idx 2)
Round 4: fwd inner (idx 3)
This is exactly what we need! The implementation would:

Determine first_round and last_round (1-indexed, inclusive, defaults 1 and total_rounds).
Determine include_w0 (default True if first_round==1 else False) and include_w1 (default True if last_round==total_rounds else False), or explicit booleans.
Iterate round numbers from first_round to last_round, appending the appropriate stage for each.
Insert h0 after round ra if `first_round <= ra < last_round

Now I have a clear picture. Looking at the reference documentation/blink.py, the encrypt function reveals the exact round sequence and key indexing:

Whitening w[0]
for r in range(ra): forward outer rounds using rk[r] and rc[r]
h0 middle (S, M, AK(h[0]), P)
for r in range(rb): forward inner rounds using rk[r + ra] and rc[r + ra]
hxor middle (S, M, AK(h_xor), S)
for r in range(rb): backward inner rounds using rk[r] and rc_prime[r]
h1 middle (P^{-1}, AK(h[1]), M, S)
for r in range(ra): backward outer rounds using rk[r + rb] and rc_prime[r + rb]
Whitening w[1]
Wait! This is subtly different from what I inferred from the CiVerLy code! In the reference code:

Backward inner uses rk[r] for r in range(rb).
Backward outer uses rk[r + rb] for r in range(ra).
For ra=2, rb=3:

Fwd outer: rk[0], rk[1]
Fwd inner: rk[2], rk[3], rk[4]
Bwd inner: rk[0], rk[1], rk[2]
Bwd outer: rk[3], rk[4]
So the mapping to paper "rounds" is: 1: fwd outer, rk[0] 2: fwd outer, rk[1] 3: fwd inner, rk[2] 4: fwd inner, rk[3] 5: fwd inner, rk[4] 6: bwd inner, rk[2] -- NOT rk[0]! It's rk[2] for the FIRST bwd inner round when rb=3. 7: bwd inner, rk[1] 8: bwd inner, rk[0] 9: bwd outer, rk[4] 10: bwd outer, rk[3]

Wait, the loop is for r in range(rb) which means r = 0, 1, 2. And it uses rk[r]. So:

Round 6 (first bwd inner): rk[0]
Round 7: rk[1]
Round 8: rk[2]
And backward outer: for r in range(ra) uses rk[r + rb]. With ra=2, rb=3:

Round 9: rk[3]
Round 10: rk[4]
So the full mapping for Blink-64 is: 1: fwd outer, rk[0] 2: fwd outer, rk[1] 3: fwd inner, rk[2] 4: fwd inner, rk[3] 5: fwd inner, rk[4] 6: bwd inner, rk[0] 7: bwd inner, rk[1] 8: bwd inner, rk[2] 9: bwd outer, rk[3] 10: bwd outer, rk[4]

But wait, the paper's Figure 2 labels backward rounds as rk_b ⊕ rc'_b, ..., rk_1 ⊕ rc'_1 (bottom inner), then rk_{b+1} ⊕ rc'_{b+1}, ..., rk_{a+b} ⊕ rc'_{a+b} (bottom outer). For a=2, b=3: bottom inner uses rk_3, rk_2, rk_1. Bottom outer uses rk_4, rk_5. In the code, bottom inner uses rk[0], rk[1], rk[2] which correspond to rk_1, rk_2, rk_3. So the code applies them in order rk_1, rk_2, rk_3. But the paper says the inverse round function uses rk_b ⊕ rc'_b first. Is there a mismatch?

Let's look at the paper's R_bar = S ◦ MK_{hat(rk) ⊕ hat(rc)} ◦ P_bar. The bottom of Figure 2 shows from right to left: S MK P_bar with rk_b ⊕ rc'_b, then ... rk_1 ⊕ rc'_1, then S MK P_bar with h2(t), then rk_{b+1} ⊕ rc'_{b+1}, ..., rk_{a+b} ⊕ rc'_{a+b}.

Wait, reading Figure 2 from left to right on the bottom: c then S MK P_bar with rk_1 ⊕ rc'_1, then ..., then S MK P_bar with rk_b ⊕ rc'_b, then S MK P_bar with h2(t), then S MK P_bar with rk_{b+1} ⊕ rc'_{b+1}, ..., then S MK P_bar with rk_{a+b} ⊕ rc'_{a+b}.

But the encrypt function in blink.py does:

for r in range(self.rb):
    self.inv_permutation(state)
    self.add_round_constant(state, self.round_const_prime[r])
    self.add_round_key(state, rk[r])
    ...
Wait! It does inv_permutation FIRST, then constant, then key, then mix, then sub! But the paper says R_bar = S ◦ MK_{hat(rk) ⊕ hat(rc)} ◦ P_bar. MK_{hat(k)}(x) = M(x) ⊕ hat(k). So R_bar = S ◦ M(• ⊕ hat(rk) ⊕ hat(rc)) ◦ P_bar? Or S ◦ (M(•) ⊕ hat(rk) ⊕ hat(rc)) ◦ P_bar. The code does: inv_permutation, add_constant, add_key, mix_columns, sub_bytes. This is: S ◦ M ◦ AK(k) ◦ AC(c) ◦ P_bar. Since S and M are involutions, S = S^{-1}, M = M^{-1}. The inverse of R = P ◦ AC ◦ AK ◦ M ◦ S is S^{-1} ◦ M^{-1} ◦ AK^{-1} ◦ AC^{-1} ◦ P^{-1}. Since AK and AC are XORs, they are self-inverse. So R^{-1} = S ◦ M ◦ AK ◦ AC ◦ P^{-1}. Yes! The code implements S ◦ M ◦ AK ◦ AC ◦ P^{-1}. The paper writes R_bar = S ◦ MK_{hat(rk) ⊕ hat(rc)} ◦ P_bar. MK_{hat(k)}(x) = M(x) ⊕ hat(k). So S ◦ MK_{hat(k)} ◦ P_bar = S ◦ (M(•) ⊕ hat(k)) ◦ P_bar. Since hat(k) = M(k)? The paper says "z_hat = M(z)". So hat(rk) ⊕ hat(rc) = M(rk) ⊕ M(rc) = M(rk ⊕ rc). And M(x) ⊕ M(k) = M(x ⊕ k). So MK_{hat(k)}(x) = M(x ⊕ k). Thus R_bar = S ◦ M(• ⊕ k) ◦ P_bar. Which is exactly S ◦ M ◦ AK(k) ◦ P_bar since M is linear. And AC is just another XOR. So yes, it matches.

Now, about the key order in backward rounds: The code's encrypt does bwd inner with rk[r] for r=0..rb-1, which is rk[0..2]. Decrypt does bwd inner with rk[self.rb - r - 1], i.e., reversed. This is consistent: encryption goes forward with keys in one order, backward with keys in potentially a different order, and decryption reverses everything.

For our purpose (differential trail analysis in CiVerLy), the CiVerLy blink.py already faithfully replicates this. The key indexing in the CiVerLy code is:

fwd outer: rk_int[r] for r in range(rl)
fwd inner: rk_int[rl + r] for r in range(rr)
bwd inner: rk_int[r] for r in range(rr)
bwd outer: rk_int[rr + r] for r in range(rl)
Wait, in CiVerLy code:

# rl backward keyed rounds
for r in range(rl):
    ...
    cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[rr + r]
    cipher.nodes[node].nodes[bwd_rk].const = rk_int[rr + r]
But in the reference blink.py:

for r in range(self.ra):
    ...
    self.add_round_constant(state, self.round_const_prime[r + self.rb])
    self.add_round_key(state, rk[r + self.rb])
There's a mismatch! The reference uses rc_prime[r + rb] for bwd outer, while CiVerLy uses rc_prime[rr + r]. Since rr <= rb, these are different when rr < rb.

Similarly for keys: reference uses rk[r + rb], CiVerLy uses rk_int[rr + r].

This means the current BLINK_CVL with reduced rr uses a different set of keys/constants than the full cipher would for those rounds. It effectively takes a prefix of rb for the inner backward rounds, and then a prefix of ra shifted by rr.

But wait, maybe the reference code's encrypt is designed such that if you want a reduced-round version, you'd call it with a truncated rk array? No, the rk array is always length ra+rb.

When ra=2, rb=3, full cipher bwd outer uses rk[3], rk[4] and rc_prime[3], rc_prime[4]. If rr=1 in CiVerLy, bwd inner uses rk[0] and rc_prime[0]. Bwd outer uses rk[1] and rc_prime[1]. But in the reference with ra=2, rb=3, you can't just change ra and rb because they are fixed per variant. The rl and rr parameters in CiVerLy are meant to let you build a reduced cipher by taking a prefix of round keys, effectively "reflecting" fewer rounds. This is a valid reduced-round construction: use the first rl outer keys and first rr inner keys and build a smaller reflected cipher.

However, for the user's purpose (slicing an existing full cipher to analyze rounds 3-6), they need to use the actual keys for those rounds, not prefixes.

So the new parameters should allow specifying offsets into the key arrays while maintaining the effective rl/rr counts.

Actually, the cleanest API that supports both "reduced round" and "sliced full cipher" is:

Keep rl and rr as the number of rounds in each segment (= count).
Add fwd_outer_offset (default 0): skip this many forward outer rounds.
Add fwd_inner_offset (default 0): skip this many forward inner rounds.
Add bwd_inner_offset (default 0): skip this many backward inner rounds.
Add bwd_outer_offset (default 0): skip this many backward outer rounds.
Add include_w0, include_w1, include_h0, include_h1, include_hxor (default True).
And then the key indices would be:

Fwd outer: fwd_outer_offset + r for r in range(rl). Must have fwd_outer_offset + rl <= ra.
Fwd inner: ra + fwd_inner_offset + r for r in range(rr). Must have fwd_inner_offset + rr <= rb.
Bwd inner: bwd_inner_offset + r for r in range(rr). Must have bwd_inner_offset + rr <= rb.
Bwd outer: rb + bwd_outer_offset + r for r in range(rl). Must have bwd_outer_offset + rl <= ra.
Wait, should bwd outer use rb as base or rr? In the reference code, bwd outer ALWAYS uses rk[r + rb] regardless of how many inner rounds you actually do. The rb in the index is the variant's total inner rounds, not the included count. But in CiVerLy's existing reduced-round model, it uses rr + r so that the reflected cipher stays consistent.

If we are slicing the full cipher, we should use the variant's fixed ra and rb as the base for offsets. The user's rl and rr then become the number of rounds to include from each segment.

For example, to get "Round 3 to Round 6" in Blink-64 (ra=2, rb=3):

Round 3 is fwd inner, index 2. fwd_inner_offset = 0? No, round 3 is the FIRST fwd inner. If we want to start at round 3, we skip fwd outer entirely (rl=0 for outer, but actually we just don't include the outer segment).
Include h0 (since round 3 comes after h0).
Include fwd inner rounds: all 3 of them. fwd_inner_offset=0, rr=3. Keys: ra+0..ra+2 = 2,3,4.
Include hxor (since round 6 comes after hxor).
Include bwd inner: only the LAST one (round 6 is bwd inner round 3? Let's check: bwd inner rounds are rk[0], rk[1], rk[2] applied in that order in encryption. Round 6 is the FIRST bwd inner round, which uses rk[0]. Wait, the loop is for r in range(rb), so the order is r=0,1,2. That's rk[0], rk[1], rk[2]. So round 6 = rk[0]. Round 8 = rk[2]. So to include round 6 only: bwd_inner_offset=0, rr=1. Key: 0.
Hmm, but the user says "Round 5-6". Round 5 is fwd inner 3 (rk[4]). Round 6 is bwd inner 1 (rk[0]). The slice 3-6 includes fwd inner 1,2,3 then hxor then bwd inner 1.

To get this with offsets:

fwd_outer_offset = 2 (skip both outer fwd), rl = 0 (include none of the outer fwd rounds... but wait, rl is defined as "number of outer rounds". If I set rl=0, then bwd outer count is also 0).
fwd_inner_offset = 0, rr = 3 (include all 3 inner fwd).
include_h0 = True, include_hxor = True.
bwd_inner_offset = 0, rr = 1 for bwd inner? But rr is used for both fwd inner and bwd inner counts in the current code.
Actually, rr is overloaded: it's the count for both fwd inner and bwd inner. We can't have fwd_inner_count=3 and bwd_inner_count=1 with a single rr parameter.

So to truly support arbitrary contiguous slices, we need separate counts for each segment OR a unified "start/end round" abstraction.

Given the complexity, a unified first_round / last_round (1-indexed) parameter set is much cleaner to use and harder to misuse.

Let me design the first_round / last_round approach.

Total rounds = 2 * (ra + rb). For each round number r (1-indexed):

Segment and key index:
1 <= r <= ra: fwd outer, array_idx = r-1
ra+1 <= r <= ra+rb: fwd inner, array_idx = r-1
ra+rb+1 <= r <= ra+2*rb: bwd inner, array_idx = r - (ra+rb+1)
ra+2*rb+1 <= r <= 2*(ra+rb): bwd outer, array_idx = r - (ra+rb+1)
Wait, let's verify with ra=2, rb=3: 1: fwd outer, idx 0 2: fwd outer, idx 1 3: fwd inner, idx 2 4: fwd inner, idx 3 5: fwd inner, idx 4 6: bwd inner, idx 0 (6 - 5 = 1? No, 6 - (2+3+1) = 0) 7: bwd inner, idx 1 8: bwd inner, idx 2 9: bwd outer, idx 3 (9 - 5 = 4? No, 9 - 6 = 3) 10: bwd outer, idx 4

Wait, the formula r - (ra+rb+1) gives: 6: 6-6=0 7: 7-6=1 8: 8-6=2 9: 9-6=3 10: 10-6=4 Yes, this matches.

Between round ra and ra+1: h0 stage.
Between round ra+rb and ra+rb+1: hxor stage.
Between round ra+2*rb and ra+2*rb+1: h1 stage.
Algorithm:

node = cipher.IN
if include_w0 and first_round == 1:
    node = AK(w0)

for r in range(first_round, last_round+1):
    determine segment and index
    add the round stage
    if r == ra and r < last_round:  # after round ra, before next round
        add h0 stage
    if r == ra+rb and r < last_round:
        add hxor stage
    if r == ra+2*rb and r < last_round:
        add h1 stage

if include_w1 and last_round == total_rounds:
    node = AK(w1)
Wait, but the stages between rounds are inserted AFTER round r if r is at a boundary and r < last_round. For example, if first_round=3, last_round=6 (ra=2, rb=3):

r=3: fwd inner (idx 2)
r=4: fwd inner (idx 3)
r=5: fwd inner (idx 4). After this, r==ra+rb (5==5) and 5 < 6, so add hxor.
r=6: bwd inner (idx 0).
If first_round=1, last_round=4:

r=1: fwd outer (idx 0)
r=2: fwd outer (idx 1). After this, r==ra (2==2) and 2 < 4, so add h0.
r=3: fwd inner (idx 2)
r=4: fwd inner (idx 3).
If first_round=7, last_round=10:

r=7: bwd inner (idx 1)
r=8: bwd inner (idx 2). After this, r==ra+2*rb (8==8) and 8 < 10, so add h1.
r=9: bwd outer (idx 3)
r=10: bwd outer (idx 4).
This works perfectly!

But we also need to preserve the existing rl/rr parameters for backward compatibility. How to reconcile first_round/last_round with rl/rr?

Option A: If first_round is specified, ignore rl/rr and raise an error if both are specified. Option B: If first_round is None, compute it from rl/rr using the old prefix logic.

Actually, the old rl/rr logic builds a reduced reflection cipher with rl outer and rr inner rounds, using keys 0..rl-1 and 0..rr-1. This can be viewed as a specific kind of slice:

first_round = 1
last_round = 2*(rl + rr) But with custom key indexing prefixes.
Wait, no. With old rl=1, rr=1 for Blink-64:

Fwd outer: rk[0]
Fwd inner: rk[1]
Bwd inner: rk[0]
Bwd outer: rk[1] Total "rounds" = 4.
In the reference full cipher (ra=2, rb=3):

Round 1: rk[0]
Round 2: rk[1]
Round 3: rk[2]
Round 4: rk[3]
Round 5: rk[4]
Round 6: rk[0]
Round 7: rk[1]
Round 8: rk[2]
Round 9: rk[3]
Round 10: rk[4]
If we use first_round=1, last_round=4, the slice would be:

Round 1: rk[0]
Round 2: rk[1]
h0
Round 3: rk[2]
Round 4: rk[3] This is a 4-round slice but uses keys rk[0..3], not the reduced cipher's rk[0..1].
So the old rl/rr semantics are NOT the same as first_round/last_round. The old semantics builds a scaled-down reflection cipher. The user might still want this capability.

My proposal:

Add first_round and last_round as new parameters.
If first_round is not None, rl/rr are ignored, and the cipher is built as a contiguous slice of the full round sequence with correct key indexing.
If first_round is None, keep the existing rl/rr behavior exactly as before.
Add explicit include_w0/include_w1 booleans that default based on whether we are at the boundaries.
Also add include_h0, include_h1, include_hxor for extra control? Actually, if you specify first_round=3, last_round=6, you automatically transit through hxor (since round 5 ends before round 6). The middle layers between rounds are structural and should be included automatically if the slice crosses them. But maybe the user wants to start after h0 (e.g., first_round=3 means the input to round 3, which is after h0). In that case, h0 is naturally omitted because first_round > ra.
Let me verify:

first_round=3 means we start at round 3. Round 3 comes after h0. So h0 should NOT be included. Correct.
last_round=5 means we stop after round 5. Round 5 ends before hxor. So hxor is NOT included.
first_round=1 means we start at round 1. We include w0 (if desired) and then round 1.
last_round=10 means we stop after round 10. We include w1 (if desired).
The middle stages h0, hxor, h1 are included if and only if the slice crosses them:

h0 included if first_round <= ra < last_round? No. h0 is BETWEEN round ra and round ra+1. So if first_round <= ra AND last_round > ra, then h0 is traversed. But if first_round = ra+1, we start AFTER h0, so h0 is not included.
More precisely: h0 included if first_round <= ra and last_round >= ra+1.
hxor included if first_round <= ra+rb and last_round >= ra+rb+1.
h1 included if first_round <= ra+2*rb and last_round >= ra+2*rb+1.
Wait, check: ra=2, rb=3. h0 is between round 2 and 3. So if first_round=1, last_round=2, h0 is not included. If first_round=2, last_round=3, h0 is included (we do round 2, then h0, then round 3). Condition: first_round <= 2 and last_round >= 3. Correct.

What about if first_round=2 and last_round=2? Then we only do round 2, no h0. Condition: first_round <= 2 (true), last_round >= 3 (false). Correct, no h0.

What if first_round=3 and last_round=3? Then we only do round 3, no h0. Condition: first_round <= 2 (false). Correct.

So the conditions are:

include_h0 = first_round <= ra and last_round > ra
include_hxor = first_round <= ra+rb and last_round > ra+rb
include_h1 = first_round <= ra+2*rb and last_round > ra+2*rb
Similarly for whitening:

include_w0 defaults to first_round == 1, but user can override.
include_w1 defaults to last_round == total_rounds, but user can override.
This is elegant and directly maps to the paper's round numbers!

Now I need to modify BLINK_CVL.__init__ to support this.

Let's sketch the new __init__:

def __init__(self, n=64, t=64, key=0, tweak=0, name=None, rl=None, rr=None,
             first_round=None, last_round=None,
             include_w0=None, include_w1=None):
If first_round is None:

Use the existing logic unchanged. This preserves backward compatibility.
rl and rr work exactly as before.
If first_round is not None:

Require last_round is not None.
rl and rr must be None (or ignored).
Compute total_rounds = 2 * (ra + rb).
Defaults: first_round=1, last_round=total_rounds.
Assert 1 <= first_round <= last_round <= total_rounds.
include_w0 defaults to first_round == 1.
include_w1 defaults to last_round == total_rounds.
Then instead of the rigid block structure, we iterate rounds:

node = cipher.IN
if include_w0:
    node = cipher.add_subcipher(rk_xor(w0_int), ...)

for r in range(first_round, last_round + 1):
    if 1 <= r <= ra:
        # fwd outer
        idx = r - 1
        node = cipher.add_subcipher(fwd_round, ...)
        cipher.nodes[node].nodes[fwd_rk].const = rk_int[idx]
        cipher.nodes[node].nodes[fwd_rc].const = rc_int[idx]
    elif ra + 1 <= r <= ra + rb:
        # fwd inner
        idx = r - 1
        node = cipher.add_subcipher(fwd_round, ...)
        cipher.nodes[node].nodes[fwd_rk].const = rk_int[idx]
        cipher.nodes[node].nodes[fwd_rc].const = rc_int[idx]
    elif ra + rb + 1 <= r <= ra + 2*rb:
        # bwd inner
        idx = r - (ra + rb + 1)
        node = cipher.add_subcipher(bwd_round, ...)
        cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[idx]
        cipher.nodes[node].nodes[bwd_rk].const = rk_int[idx]
    else:
        # bwd outer
        idx = r - (ra + rb + 1)
        node = cipher.add_subcipher(bwd_round, ...)
        cipher.nodes[node].nodes[bwd_rc].const = rc_prime_int[idx]
        cipher.nodes[node].nodes[bwd_rk].const = rk_int[idx]
    
    # insert middle stages between rounds
    if r == ra and r < last_round:
        node = middle_stage(cipher, node, h0_int, "h0")
        node = cipher.add_subcipher(perm, ...)
    elif r == ra + rb and r < last_round:
        node = middle_stage(cipher, node, h_xor_int, "hxor")
        node = cipher.add_subcipher(subcells, ...)
    elif r == ra + 2*rb and r < last_round:
        node = cipher.add_subcipher(inv_perm, ...)
        node = cipher.add_subcipher(rk_xor(h1_int), ...)
        node = cipher.add_subcipher(mixcolumns, ...)
        node = cipher.add_subcipher(subcells, ...)

if include_w1:
    node = cipher.add_subcipher(rk_xor(w1_int), ...)
cipher.add_output(...)
Wait, but we need to be careful: the middle_stage helper adds S, M, AK. But the h0 stage in the full cipher is followed by P. The hxor stage in the full cipher is followed by S. The h1 stage is P^{-1}, AK, M, S. In the existing code:

# middle: S, M, AK(h0), P
node = middle_stage(..., h0_int, ...)
node = cipher.add_subcipher(perm, ...)

# middle: S, M, AK(h0^h1), S
node = middle_stage(..., h_xor_int, ...)
node = cipher.add_subcipher(subcells, ...)

# middle: P^-1, AK(h1), M, S
node = cipher.add_subcipher(inv_perm, ...)
node = cipher.add_subcipher(rk_xor(h1_int), ...)
node = cipher.add_subcipher(mixcolumns, ...)
node = cipher.add_subcipher(subcells, ...)
So my logic above matches.

But wait - if the slice starts at round first_round > 1, the first operation applied to node is a round (FwdRound or BwdRound depending on where we are). The input node is cipher.IN (or w0-whitened input). This means the slice assumes the state at the beginning of first_round is the plaintext. That is exactly what the user wants for trail analysis.

Similarly, if the slice ends at last_round < total_rounds, the last operation is the round function for last_round, and then we optionally add w1 or just output.

One more detail: include_w0 and include_w1 should be user-overridable booleans. If the user passes first_round=1, last_round=10, include_w0=False, they get the 10-round core without whitening. This is useful.

I should also update the docstring with examples showing how to slice.

Let me write the replacement code for __init__. Actually, the file is large. I'll keep most of it and replace the assembly section (lines 587-648).

Wait, I also need to ensure the existing rl/rr code path is preserved exactly. So I'll wrap the old assembly logic in an if first_round is None: block, and put the new logic in else:.

Also, there is an assertion about rl + rr <= ra + rb that should stay in the old path.

Let me verify the round numbering for 128-bit variants:

Blink-128a: ra=3, rb=3. Total rounds = 12.
Blink-128A: ra=3, rb=5. Total rounds = 16.
The formula total_rounds = 2 * (ra + rb) is correct.

Edge case: what if first_round == last_round? Then we do exactly one round, and no middle stages (since r < last_round is false). That works.

Another edge case: first_round=ra, last_round=ra+1. Then:

r=ra: fwd outer (if ra==ra) or fwd inner? Let's check. r <= ra means fwd outer. So for r=ra, it's the last fwd outer round. Then since r == ra and r < last_round (ra < ra+1), we insert h0. Then r=ra+1: fwd inner (since ra+1 <= r <= ra+rb). Correct.
What about first_round=ra+rb, last_round=ra+rb+1?

r=ra+rb: fwd inner (last fwd inner). Then since r == ra+rb and r < last_round, insert hxor. Then r=ra+rb+1: bwd inner (first bwd inner). Correct.
What about first_round=ra+2*rb, last_round=ra+2*rb+1?

r=ra+2rb: bwd inner (last bwd inner). Then since r == ra+2*rb and r < last_round, insert h1. Then r=ra+2rb+1: bwd outer (first bwd outer). Correct.
All good.

Now I need to write the code.

One thing: bwd_round uses inv_perm first, then rk_xor, then mixcolumns, then subcells. In the existing code, bwd_rc is the constant XOR and bwd_rk is the key XOR. The order inside bwd_round is:

inv_perm
bwd_rc (constant)
bwd_rk (key)
mixcolumns
subcells
But the reference backward round is S, M, AK, AC, P^{-1}. Wait, encrypt in reference does:

self.inv_permutation(state)
self.add_round_constant(state, self.round_const_prime[r])
self.add_round_key(state, rk[r])
self.mix_columns(state)
self.sub_bytes(state)
This corresponds to S ◦ M ◦ AK ◦ AC ◦ P^{-1}. Since S and M are involutions, this is S ◦ M ◦ AK ◦ AC ◦ P^{-1}. But R^{-1} = S^{-1} ◦ M^{-1} ◦ AK^{-1} ◦ AC^{-1} ◦ P^{-1} = S ◦ M ◦ AK ◦ AC ◦ P^{-1}. So the encrypt function's backward loops are applying R^{-1}. Correct.

In the CiVerLy bwd_round, the order is:

inv_perm
bwd_rc (AC)
bwd_rk (AK)
mixcolumns (M)
subcells (S) This is S ◦ M ◦ AK ◦ AC ◦ P^{-1}. Correct.
For backward rounds, key indexing:

bwd inner in reference: rk[r] for r in range(rb). In the slice logic, idx = r - (ra + rb + 1). For r = ra+rb+1 (first bwd inner), idx = 0. Correct.
bwd outer in reference: rk[r + rb] for r in range(ra). In the slice logic, idx = r - (ra + rb + 1). For r = ra+2*rb+1 (first bwd outer), idx = rb. Correct.
Constants:

bwd inner: rc_prime_int[idx] where idx = r - (ra + rb + 1). For first bwd inner (r=ra+rb+1), idx=0. Reference uses rc_prime[r] with r=0. Correct.
bwd outer: rc_prime_int[idx] where idx = r - (ra + rb + 1). For first bwd outer (r=ra+2*rb+1), idx=rb. Reference uses rc_prime[r + rb] with r=0, so rc_prime[rb]. Correct.
Wait, in the reference:

for r in range(self.ra):
    self.inv_permutation(state)
    self.add_round_constant(state, self.round_const_prime[r + self.rb])
    self.add_round_key(state, rk[r + self.rb])
    self.mix_columns(state)
    self.sub_bytes

I will now modify the BLINK_CVL constructor to support slicing by round numbers. This enables constructing partial ciphers that correspond to specific round ranges (e.g., the Superbox experiments in the paper) while keeping the existing rl/rr interface intact for backward compatibility.

The changes will:

Add first_round, last_round, include_w0, and include_w1 parameters.
When first_round is provided, build the cipher by iterating round-by-round with correct key/constant indexing from the full schedule.
Keep the original rl/rr code path exactly as before.
Update the docstring with an example of slicing.

... (code edits and doctest testing)

I've updated BLINK_CVL to support fine-grained slicing of the cipher construction.

What changed
New slicing parameters in BLINK_CVL.__init__:
first_round – 1-based index of the first round to include.
last_round – 1-based index of the last round to include.
include_w0 / include_w1 – booleans to toggle the initial/final whitening (default sensibly based on slice boundaries).
Round numbering (for the default Blink-64 variant with ra=2, rb=3):
Rounds 1–2: outer forward block (rk[0], rk[1])
Rounds 3–5: inner forward block (rk[2], rk[3], rk[4])
Rounds 6–8: inner backward block (rk[0], rk[1], rk[2])
Rounds 9–10: outer backward block (rk[3], rk[4])
Middle stages are inserted automatically when the slice crosses them:
h0 between rounds 2 and 3
hxor between rounds 5 and 6
h1 between rounds 8 and 9
Backward compatibility: when first_round is not provided, the existing rl/rr reduced-round logic is used unchanged.
Usage examples
from civerly.cipher_implementations.blink import BLINK_CVL

# Full 10-round Blink-64 (legacy style)
full = BLINK_CVL(64, 64)

# Reduced-round variant (legacy style)
reduced = BLINK_CVL(64, 64, rl=1, rr=1)

# 4-round core used in the Round 3–4 + Round 5–6 Superbox experiments
core = BLINK_CVL(64, 64, first_round=3, last_round=6)

# 10-round core without whitening (differential trail analysis)
trail = BLINK_CVL(64, 64, first_round=1, last_round=10,
                  include_w0=False, include_w1=False)
All existing test vectors and doctests continue to pass, and the new sliced constructors are is_valid-verified.


