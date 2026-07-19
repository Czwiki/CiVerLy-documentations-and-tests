date: 2026-07-19T 19:30:00Z
participants:
- You: Henry
- Assistant: Kilo AI, Kimi 2.6 via Neuralwatt
topic: "Implementation of the twine cipher"

User:
Please implement the twine cipher according to the specifications of a cipher implementation in  @documentation/README.md . A python reference implementation is available @documentation/cli.py  , @documentation/cli.py  and @documentation/algo.py together with a part of the published paper @documentation/Twine.md  and figures from the latter @documentation/twine enc.png , @documentation/twine key schedule.png , @documentation/twine round function.png , @documentation/twine key schedule alt.png . Test vectors can be found at @documentation/test vectors.png  . Sage is installed via nix. If you need further information, please come forward.

The user wants me to implement the TWINE cipher according to the CiVerLy framework specifications. Let me first understand the existing codebase structure by looking at some existing implementations like present.py to understand the pattern, then implement TWINE.

Let me gather information about:

The existing cipher implementations structure
The specific TWINE algorithm details from the documentation
How to properly wire it in CiVerLy
From the documentation:

TWINE is a 64-bit block cipher with 80 or 128-bit key
36 rounds
16 sub-blocks of 4 bits each
Uses 4-bit S-box
Has a permutation layer
Type-2 GFS variant
Round function: for j=0 to 7, X_{2j+1} <- S(X_{2j} XOR RK_j) XOR X_{2j+1}
Then permutation pi
For CiVerLy:

Should probably use WordSBoxCipher since it's word-based (4-bit words) with S-boxes
Or SBoxCipher with bit-level wiring
Let me look at existing implementations first.

... (creating to-dos)

... (reading files)

Now I have a good understanding of the structure. Let me also look at the abc.py to see how SBoxCipher works with explicit round constants, and let me check the __init__.py of cipher_implementations to see how things are exported.

From the documentation and images:

TWINE is a 64-bit block cipher with 80 or 128-bit key
36 rounds
16 sub-blocks of 4 bits each
S-box: [C, 0, F, A, 2, B, 9, 5, 8, 3, D, 7, 1, E, 6, 4]
Permutation pi: [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14]
Round function: For each round i (1 to 35):
X_{2j+1} <- S(X_{2j} XOR RK_j^i) XOR X_{2j+1} for j=0..7
Then permutation: X_h^{i+1} <- X_{pi[h]}^i (i.e., shuffle blocks)
Round 36: just the S-box layer, no permutation
Key schedule produces 32-bit round keys (8 nibbles × 4 bits = 32 bits)
Looking at the round function figure:

The state has 16 4-bit words x_0 to x_15
RK^i is a 32-bit round key (8 nibbles)
For each j from 0 to 7:
x_{2j+1}^{i+1} = S(x_{2j}^i XOR RK_j^i) XOR x_{2j+1}^i
Theeven indices are just passed through... wait, let me re-read.
Actually from Algorithm 2.1:

RK^i is split into 8 4-bit values RK_0^i ... RK_7^i
For j = 0 to 7: X_{2j+1}^i <- S(X_{2j}^i XOR RK_j^i) XOR X_{2j+1}^i
For h = 0 to 15: X_{pi[h]}^{i+1} <- X_h^i
Wait, this means:

First apply the S-box+XOR operations to all odd positions
Then apply permutation to the whole state to get the next round state
But the figure shows something slightly different. Let me look more carefully.

From the figure:

x_0 goes directly to output (no change in round)
x_1 goes through F (which is S-box after XOR with roundkey) then XOR with x_1, then to some output position
The round key RK_j^i is XORed with x_{2j} before entering the S-box
Actually looking at Algorithm 2.1 again:

for j <- 0 to 7 do X_{2j+1}^i <- S(X_{2j}^i XOR RK_j^i) XOR X_{2j+1}^i
This modifies X_{2j+1}^i in place? No, the algorithm says X_{2j+1}^i gets a new value. But then:
for h <- 0 to 15 do X_{pi[h]}^{i+1} <- X_h^i
Wait, this doesn't quite make sense if X_{2j+1}^i is modified in place for the permutation step. Let me re-read...

Actually I think the intent is:

Compute new values for the odd positions: temp_{2j+1} = S(X_{2j}^i XOR RK_j^i) XOR X_{2j+1}^i
The even positions stay as X_{2j}^i
Then shuffle all 16 values according to pi to get X^{i+1}
So X_h^i for the permutation step uses the updated odd positions and unchanged even positions.

Wait, but Algorithm 2.1 says:

X_{2j+1}^i <- S(X_{2j}^i XOR RK_j^i) XOR X_{2j+1}^i
then

X_{pi[h]}^{i+1} <- X_h^i
The second line should use the already-modified X_h^i values. So:

For j=0..7, update X_{2j+1}^i (in place on the intermediate state)
Then permute to get X^{i+1}
This is a Type-2 GFS where even positions go through the round function to modify odd positions, and then a permutation shuffles everything.

For round 36, there's no permutation. From Algorithm 2.1:

for j <- 0 to 7 do   X_{2j+1}^{36} <- S(X_{2j}^{36} XOR RK_j^{36}) XOR X_{2j+1}^{36}
So the last round just has the S-box operations but no permutation.

Now for the CiVerLy implementation:

Since TWINE uses 4-bit words and S-boxes, WordSBoxCipher seems appropriate
Block size: 64 bits = 16 words of 4 bits
Round key: 32 bits = 8 words of 4 bits
For the round function in CiVerLy:

We need to model each round as having:
Key XOR (using RoundkeyXOR_CVL) - but wait, the round key is only XORed with even positions (x_0, x_2, ..., x_14) before the S-box
S-box layer
XOR with odd positions (x_1, x_3, ..., x_15)
Permutation layer
Actually, looking at the figure more carefully:

For each j, RK_j^i is XORed with x_{2j}^i
Then it goes through S-box
Then XORed with x_{2j+1}^i
The result is x_{2j+1}^{i+1} (but after permutation)
Wait, let me re-examine. In a Type-2 GFS:

The left branch (even indices) is unchanged
The right branch (odd indices) is XORed with F(left branch XOR roundkey)
Then both branches go through a permutation
So for TWINE specifically:

Even words x_0, x_2, ..., x_14 pass through unchanged (except through permutation at end)
For each j: x_{2j+1} <- S(x_{2j} XOR RK_j) XOR x_{2j+1}
Then apply permutation pi to all 16 words
In CiVerLy, we need to model this. Since the round key is only applied to even words, we could use RoundkeyXOR_CVL for those 8 words. But RoundkeyXOR_CVL applies to all input words... Actually looking at PRESENT, RoundkeyXOR_CVL(64, const) XORs a 64-bit constant with 64 bits. For word-based, it would XOR with the word positions.

For TWINE, the round key is 32 bits (8 nibbles), and it's XORed with the 8 even positions (x_0, x_2, ..., x_14). We could use RoundkeyXOR_CVL but it would need to be wired carefully. Looking at how skinny does it:

atk1 = RoundkeyXOR_CVL(4*s, const=0, name="atk1")
node_atk1 = addroundtweakey.add_subcipher(
    atk1, [(addroundtweakey.IN, (i, i)) for i in range(4)]
)
This XORs a constant with words 0..3. For TWINE, we need to XOR RK with words 0,2,4,6,8,10,12,14.

Wait, but the round key in TWINE is 8 nibbles. RK_0 is XORed with x_0, RK_1 with x_2, etc. Or from Figure 1, RK_j is XORed with x_{2j}. So:

RK_0 with x_0
RK_1 with x_2
RK_2 with x_4
...
RK_7 with x_14
We can use RoundkeyXOR_CVL(32, const) but it needs 8 inputs. Or we can use 8 separate XOR_CVL components, but that's messy.

Actually, looking at the RoundkeyXOR_CVL - it takes n bits and a constant. For word-based, we pass word edges. We can wire it to only 8 specific word positions by using word edges.

For a round in TWINE:

RoundkeyXOR_CVL(32, const=0) wired to even positions 0,2,4,6,8,10,12,14
Input: words [0, 2, 4, 6, 8, 10, 12, 14] → output words [0, 1, 2, 3, 4, 5, 6, 7] Wait no, that's not how it works.
Let me re-read the edge mapping. In WordSBoxCipher:

An edge is (node, (src_index, dst_index))
src_index and dst_index are WORD positions (for word-based)
So for RoundkeyXOR_CVL(32, ...) which takes 8 words of 4 bits:

We wire: [(cipher.IN, (0, 0)), (cipher.IN, (2, 1)), (cipher.IN, (4, 2)), ...]
This means word 0 of input goes to word 0 of RoundkeyXOR, word 2 goes to word 1, etc.
The output of RoundkeyXOR would have RK_0 XORed with input word 0 at output word 0, etc.
But then we need to combine this with the S-box and the XOR with odd words. This gets complicated.

Actually, looking at the TWINE round function figure again:

RK_j is a 4-bit round key nibble
It is XORed with x_{2j}
The result goes through S-box S
The S-box output is XORed with x_{2j+1}
The final result is one of the outputs
x_{2j} also passes through directly to an output
For each j (0..7), this is a small Feistel-like structure. In CiVerLy, we could model each of these 8 parallel "F-functions" as a small subcipher. But that becomes complex.

Alternatively, we can think about how to model this at the word level:

Have a layer that applies S-box to even positions after XOR with roundkey
Have a layer that XORs the S-box outputs with odd positions
Apply permutation
But wait, the S-box is only applied to even positions. The result is XORed with odd positions. The even positions themselves are unchanged.

Let me think about this more carefully. One approach:

Build a "round function" subcipher that takes 16 words and produces 16 words
Within this subcipher:
Use an SBox layer for the 8 even positions
But the S-box inputs are the even positions XORed with roundkey
Then XOR those S-box outputs with odd positions
Actually, maybe a simpler approach:

key_xor = RoundkeyXOR_CVL(32) wired to even positions
sbox_layer = SBox_CVL applied to the outputs of key_xor (8 S-boxes in parallel)
xor_layer = XOR the sbox outputs with odd positions
perm_layer = permutation
But XOR_CVL in CiVerLy is a bitwise XOR. For word-based, we might need a different approach.

Let me look at what components are available. Let me check the component module.

Now I have a good understanding of the CiVerLy framework. Let me think about how to model TWINE.

TWINE round function:

State: 16 words of 4 bits (x_0 to x_15)
Round key: 8 words of 4 bits (RK_0 to RK_7)
For each j = 0..7:
Compute temp = S(x_{2j} XOR RK_j)
x_{2j+1} = temp XOR x_{2j+1}
x_{2j} stays the same
Then apply permutation pi to all 16 words
The tricky part is the Feistel-like structure where S-box outputs XOR with adjacent odd words. In CiVerLy's word-based framework, I need to carefully wire this.

For each j, I need a small "F-function" that:

Takes x_{2j} and x_{2j+1} as inputs
XORs x_{2j} with RK_j
Applies S-box
XORs with x_{2j+1}
Outputs the new x_{2j+1}
Also passes x_{2j} through unchanged
But if I do 8 separate F-functions, I need to combine their outputs with the permutation.

Wait, I can think about this differently. Let me look at how SBox_CVL and XOR_CVL work:

SBox_CVL takes m bits and outputs n bits. XOR_CVL(word_length) takes 2*word_length bits and outputs word_length bits.

For TWINE at word granularity (4-bit words):

For each j, I need to compute S(x_{2j} ⊕ RK_j) ⊕ x_{2j+1}
This is the new value of the odd word.
I can build a small subcipher for each F-function:

Inputs: word 0 (x_{2j}), word 1 (x_{2j+1})
rk_xor = RoundkeyXOR_CVL(4) - takes word 0, outputs RK_j ⊕ word 0
sbox = SBox_CVL(S, 4, 4) - takes output of rk_xor
xor = XOR_CVL(4) - takes sbox output and word 1, outputs final value
But XOR_CVL takes 2 inputs of 4 bits each (total 8 bits), so it needs both the sbox output and the original x_{2j+1}.

For each F-function subcipher:

IN: 2 words (x_{2j}, x_{2j+1})
rk_xor: IN[0] -> rk_xor[0], output word 0
sbox: rk_xor[0] -> sbox[0], output word 0
xor: sbox[0] -> xor[0], IN[1] -> xor[1], output word 0
Also need to output IN[0] directly
Then the round function combines all 8 F-functions and applies the permutation.

Actually, looking at this more carefully:

Each F-function outputs 2 words: (x_{2j}, new_x_{2j+1})
After all 8 F-functions, we have 16 words
Then apply permutation pi
Let's build this step by step:

# F-function for one pair
f_func = WordSBoxCipher(4, 2, 2, name=f"F")
rk_xor = RoundkeyXOR_CVL(4, const=0, name=f"rk")
node_rk = f_func.add_subcipher(rk_xor, [(f_func.IN, (0, 0))])
sbox = SBox_CVL(SBox([...]), name=f"S")
node_s = f_func.add_subcipher(sbox, [(node_rk, (0, 0))])
xor = XOR_CVL(4, name=f"xor")
node_xor = f_func.add_subcipher(xor, [(node_s, (0, 0)), (f_func.IN, (1, 1))])
# Output word 0 is the unchanged even word
f_func.add_output([(f_func.IN, (0, 0))])
# Output word 1 is the new odd word
f_func.add_output([(node_xor, (0, 1))])
Wait, but XOR_CVL takes 2*word_length = 8 bits for word_length=4. In a word-based cipher, edges map words. So XOR_CVL(4) takes 2 words (since word_length=4 means it inputs 8 bits = 2 words of 4 bits).

So: [(node_s, (0, 0)), (f_func.IN, (1, 1))] means:

word 0 of node_s goes to word 0 of XOR_CVL
word 1 of f_func.IN goes to word 1 of XOR_CVL
And XOR_CVL outputs word 0.

Then f_func.add_output([(node_xor, (0, 1))]) means word 0 of node_xor goes to word 1 of f_func output.

For the full round:

twine_round = WordSBoxCipher(4, 16, 16, name="twine_round")
f_nodes = []
for j in range(8):
    f_func_copy = ... # Need to create separate instances or reuse?
    # Actually, we can create one f_func template and instantiate it, 
    # but in CiVerLy it seems we create fresh components
Wait, looking at present.py, they create components once and reuse them by adding them as subciphers. But for TWINE, each F-function has its own roundkey. However, the roundkey is set on the node after adding the subcipher.

Actually, looking at present.py:

key_add = RoundkeyXOR_CVL(64, 0x0, name="KeyAdd")
present_round = WordSBoxCipher(4, 16, 16, name="present_round")
node_rk = present_round.add_subcipher(key_add, ...)
Then in the loop:

for r in range(R):
    present_round.nodes[node_rk].const = rks[r]
    cipher_node = present_cipher.add_subcipher(present_round, ...)
So present_round is a template that gets instantiated multiple times, but setting const on present_round.nodes[node_rk] affects all instantiations because they share the same node object! Wait, that can't be right...

Actually, looking more carefully: when add_subcipher is called, it adds copies of the nodes. But node_rk refers to a specific node ID in the template cipher. Setting present_round.nodes[node_rk].const = rks[r] sets the constant on the template, and when add_subcipher instantiates it, each instance gets the current value. But since it's set in the loop before each add_subcipher, each round gets a different value.

Wait, but then if you look at round r, the constant was set to rks[r]. Then add_subcipher creates an instance with that constant. Then for round r+1, the constant is updated to rks[r+1], and another instance is created. This works because each instance captures the constant at instantiation time.

But hold on - do the previously instantiated rounds keep their old constant values? That depends on whether const is copied by value or by reference. Since it's an integer, it should be copied by value.

So for TWINE, I can do the same pattern:

Create a template round with 8 F-functions
Each F-function has a RoundkeyXOR_CVL(4)
In the loop, set each F-function's roundkey constant before adding the round
But there's a subtlety: the round function in TWINE has 8 different roundkey nibbles per round. And I need to set all 8 before adding the round.

Wait, but if I create the round template once, and set constants on its nodes in the loop, then add the round, each round instance will have the same constants because the template nodes are shared. Let me re-examine...

Actually, I think add_subcipher might deep copy the subcipher's nodes. Let me check by looking at the source of add_subcipher.

Actually, let me just look at how present.py handles it. It creates one present_round template, then in the loop:

present_round.nodes[node_rk].const = rks[r]
cipher_node = present_cipher.add_subcipher(present_round, ...)
Then after the loop:

key_add.const = rks[R]
cipher_node = present_cipher.add_subcipher(key_add, ...)
So the same present_round object is reused, and its node_rk constant is updated each iteration. If add_subcipher deep-copies, this works. If not, all rounds would have the same key. Since present.py works with test vectors, add_subcipher must deep-copy.

Wait, but there might still be an issue. Let me check: present_round.nodes[node_rk] accesses the node in the template. Setting .const on it modifies the template. Then add_subcipher(present_round, ...) creates an instance. Since it works for PRESENT, it must copy const by value.

For TWINE, I'll create a round template with 8 RK nodes. In the loop, I'll set each RK node to the appropriate roundkey nibble, then add the round.

Actually, there's another approach: use a single RoundkeyXOR_CVL(32) for the whole round that handles all 8 RKs at once. But then the wiring to the F-functions becomes more complex.

Let me think about what makes the cleanest implementation...

Option: Build the entire round as a flat subcipher without nested F-function subciphers. This is simpler:

Create twine_round = WordSBoxCipher(4, 16, 16, name="round")
Add 8 RoundkeyXOR_CVL(4) instances, each wired to an even position
Add 8 SBox_CVL instances
Add 8 XOR_CVL(4) instances, each wired to an SBox output and an odd word
Wire outputs: even positions pass through, odd positions come from XOR
Add permutation layer
But wait, the permutation in TWINE happens after the Feistel operations, so:

After the XOR operations, we have a 16-word intermediate state
Then permutation pi is applied
So the round outputs are the permuted state
Let me design the round template:

twine_round = WordSBoxCipher(4, 16, 16, name="round")

# Step 1: Roundkey XOR with even positions
rk_nodes = []
for j in range(8):
    rk = RoundkeyXOR_CVL(4, const=0, name=f"rk{j}")
    node_rk = twine_round.add_subcipher(rk, [(twine_round.IN, (2*j, 0))])
    rk_nodes.append(node_rk)

# Step 2: S-box on the XOR results
sbox = SBox_CVL(SBox([0xC, 0x0, ...]), name="S")
sbox_nodes = []
for j in range(8):
    node_s = twine_round.add_subcipher(sbox, [(rk_nodes[j], (0, 0))])
    sbox_nodes.append(node_s)

# Step 3: XOR with odd positions
xor_nodes = []
for j in range(8):
    xor = XOR_CVL(4, name=f"xor{j}")
    node_xor = twine_round.add_subcipher(
        xor, 
        [(sbox_nodes[j], (0, 0)), (twine_round.IN, (2*j+1, 1))]
    )
    xor_nodes.append(node_xor)

# Step 4: Build the intermediate state before permutation
# We need to output all 16 words
# For even positions: pass through from input
# For odd positions: use XOR output

intermediate_perm = PermuteLayer_CVL(
    # pi: [5,0,1,4,7,12,3,8,13,6,9,2,15,10,11,14]
    # This means input word 0 -> output word 5, input 1 -> output 0, etc.
    [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14],
    word_coarseness=4,
    name="perm"
)

# Actually, we need to create a permutation that takes the intermediate state
# The intermediate state has:
# - word 0: from input word 0 (unchanged)
# - word 1: from xor node for j=0
# - word 2: from input word 2 (unchanged)
# - word 3: from xor node for j=1
# etc.

# But PermuteLayer_CVL works on bits by default, unless word_coarseness is set.
# With word_coarseness=4, it works on 4-bit words.

# We first need to gather all 16 words, then apply permutation.
# We can use PermuteLayer_CVL directly as a subcipher.

# However, PermuteLayer_CVL takes a single input and produces a single output.
# We need to create a combined input.

# Actually in CiVerLy, when we add a subcipher, we can map multiple source 
# nodes to the input of the subcipher. So:

node_perm = twine_round.add_subcipher(
    intermediate_perm,
    [(twine_round.IN, (0, 0))]  # input word 0 -> perm word 0
    + [(xor_nodes[0], (0, 1))]   # xor0 output -> perm word 1
    + [(twine_round.IN, (2, 2))] 
    + [(xor_nodes[1], (0, 3))]
    + ... etc.
)

twine_round.add_output([(node_perm, (i, i)) for i in range(16)])
Wait, but twine_round.add_subcipher(intermediate_perm, [...]) maps source words to destination words of intermediate_perm.IN. So:

(twine_round.IN, (0, 0)) means word 0 of twine_round.IN goes to word 0 of intermediate_perm.IN
(xor_nodes[0], (0, 1)) means word 0 of xor_nodes[0] goes to word 1 of intermediate_perm.IN
This should work! Then intermediate_perm permutes all 16 words according to pi.

For round 36, we omit the permutation. We can either:

Have a separate round template for round 36, or
Add the round 36 operations separately after the loop
Looking at Algorithm 2.1, round 36 is just:

for j <- 0 to 7 do   X_{2j+1}^{36} <- S(X_{2j}^{36} XOR RK_j^{36}) XOR X_{2j+1}^{36}
So we can do the same F-function operations but without permutation, then output.

Alternatively, we can build the cipher with 35 full rounds + 1 final S-box layer.

Let me also handle the key schedule. The documentation says:

For testing, we can pass rks directly
But for completeness, we should implement the key schedule
Actually, looking at the test vectors:

80-bit key: 00112233 44556677 8899 with plaintext 01234567 89ABCDEF gives ciphertext 7C1F0F80 B1DF9C28
128-bit key: 00112233 44556677 8899AABB CCDDEEFF with same plaintext gives 979FF9B3 79B5A9B8
For the CiVerLy implementation, we can support both key sizes. The key schedule produces 36 round keys of 32 bits each.

But for simplicity and to match the rks parameter pattern in other ciphers, we should accept rks as a parameter. If not provided, compute from a master key.

Actually, looking at present.py: it takes rks as a list of roundkeys. For TWINE, I should do the same. But TWINE also has key schedule logic. Let me implement both:

If rks is provided, use it
If key and key_size are provided, compute the key schedule
Let me implement the key schedule based on the algo.py reference and the figures.

For 80-bit key schedule:

WK_0 to WK_19 (20 nibble words)
For r = 1 to 35:
RK_r = WK_1 || WK_3 || WK_4 || WK_6 || WK_13 || WK_14 || WK_15 || WK_16
WK_1 <- WK_1 ⊕ S(WK_0)
WK_4 <- WK_4 ⊕ S(WK_16)
WK_7 <- WK_7 ⊕ 0 || CON_H^r
WK_19 <- WK_19 ⊕ 0 || CON_L^r
Rot4 on WK_0..WK_3
Rot16 on WK_0..WK_19
RK_36 = WK_1 || WK_3 || WK_4 || WK_6 || WK_13 || WK_14 || WK_15 || WK_16
Wait, looking at the algo.py:

def _key_schedule_80(key):
    for r in range(1, 36):
        RK_32[r][0] = WK_80[1]
        RK_32[r][1] = WK_80[3]
        ...
Hmm, in algo.py the loop is for r in range(1, 36): which gives r = 1, 2, ..., 35. That's 35 iterations computing RK_1 through RK_35. Then RK_36 is computed after the loop.

But wait, the reference implementation in algo.py might have a bug. Looking at Algorithm 2.3:

for r <- 1 to 35
    RK^r <- ...
    ... updates ...
RK^36 <- ...
So yes, RK^1 to RK^35 are computed inside the loop, RK^36 after.

For the 128-bit version (Algorithm A.1):

for r <- 1 to 35
    RK^r <- WK_2 || WK_3 || WK_12 || WK_15 || WK_17 || WK_18 || WK_28 || WK_31
    WK_1 <- WK_1 ⊕ S(WK_0)
    WK_4 <- WK_4 ⊕ S(WK_16)
    WK_23 <- WK_23 ⊕ S(WK_30)
    WK_7 <- WK_7 ⊕ 0 || CON_H^r
    WK_19 <- WK_19 ⊕ 0 || CON_L^r
    Rot4 on WK_0..WK_3
    Rot16 on WK_0..WK_31
RK^36 <- WK_2 || WK_3 || WK_12 || WK_15 || WK_17 || WK_18 || WK_28 || WK_31
Now let me think about how to structure the final cipher file.

Actually, let me consider a cleaner approach for the round function using subciphers. In CiVerLy, we can create a subcipher for each "F-function pair" but I think a flat approach is cleaner and more aligned with the existing patterns.

Wait, one significant issue: RoundkeyXOR_CVL. Looking at PRESENT, RoundkeyXOR_CVL(64, 0x0) takes 64 bits and XORs with a constant. In a WordSBoxCipher, when wired with word edges, RoundkeyXOR_CVL operates word-wise. So RoundkeyXOR_CVL(4) takes one 4-bit word and XORs it with a 4-bit constant.

For TWINE, each RK_j is a 4-bit nibble. If I use RoundkeyXOR_CVL(4, const=0), then each instance handles one nibble. That's perfect.

Now for the last round (round 36), I need to apply the F-functions but without permutation. Looking at Algorithm 2.1 again:

for i <- 1 to 35
    RK^i split into 8 nibbles
    for j <- 0 to 7: X_{2j+1}^i <- S(X_{2j}^i XOR RK_j^i) XOR X_{2j+1}^i
    for h <- 0 to 15: X_{pi[h]}^{i+1} <- X_h^i
for j <- 0 to 7: X_{2j+1}^{36} <- S(X_{2j}^{36} XOR RK_j^{36}) XOR X_{2j+1}^{36}
C <- X_0^{36} || ... || X_15^{36}
So rounds 1-35 have permutation, round 36 does not. The ciphertext is the state after round 36.

But wait, looking at the reference Python implementation:

for i in range(1, 36):
    for j in range(0, 8):
        X_16[i][2 * j + 1] = _S(X_16[i][2 * j] ^ RK_32[i][j]) ^ X_16[i][2 * j + 1]
    for h in range(0, 16):
        X_16[i + 1][permutation_enc[h]] = X_16[i][h]

for j in range(0, 8):
    X_16[36][2 * j + 1] = _S(X_16[36][2 * j] ^ RK_32[36][j]) ^ X_16[36][2 * j + 1]
So range(1, 36) means i = 1, ..., 35. That's 35 rounds with permutation. Then the final S-box layer is for round 36.

Let me re-verify with the algo.py key schedule - it has a bug perhaps:

for r in range(1, 36):
    ...
This computes RK[1] through RK[35]. Then RK[36] is computed after. That's correct.

Wait, but the key schedule updates happen INSIDE the loop for r=1 to 35. So for r=35, we compute RK[35] from the current WK values, then update WK, then the loop ends. Then we compute RK[36] from the (already updated) WK values. That matches Algorithm 2.3.

OK, now let me design the CiVerLy implementation carefully.

For the round template with permutation:

twine_round = WordSBoxCipher(4, 16, 16, name="twine_round")

# Key XOR for even positions
rk_nodes = []
for j in range(8):
    rk_xor = RoundkeyXOR_CVL(4, const=0, name=f"rk{j}")
    node_rk = twine_round.add_subcipher(rk_xor, [(twine_round.IN, (2*j, 0))])
    rk_nodes.append(node_rk)

# S-box layer
sbox = SBox_CVL(SBox(twine_sbox), name="S")
sbox_nodes = []
for j in range(8):
    node_s = twine_round.add_subcipher(sbox, [(rk_nodes[j], (0, 0))])
    sbox_nodes.append(node_s)

# XOR with odd positions
xor_nodes = []
for j in range(8):
    xor = XOR_CVL(4, name=f"xor{j}")
    node_xor = twine_round.add_subcipher(
        xor, [(sbox_nodes[j], (0, 0)), (twine_round.IN, (2*j + 1, 1))]
    )
    xor_nodes.append(node_xor)

# Permutation
perm = PermuteLayer_CVL(
    [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14],
    word_coarseness=4,
    name="perm"
)

# Wire the permutation
perm_edges = []
for j in range(8):
    perm_edges.append((twine_round.IN, (2*j, 2*j)))       # even word j -> position 2j
    perm_edges.append((xor_nodes[j], (0, 2*j + 1)))       # odd word j -> position 2j+1

node_perm = twine_round.add_subcipher(perm, perm_edges)
twine_round.add_output([(node_perm, (i, i)) for i in range(16)])
Wait, but the permutation needs to act on the STATE, not on the separated even/odd. Let me think about what the intermediate state looks like.

After the Feistel operations (before permutation):

word 0: x_0 (unchanged)
word 1: S(x_0 ⊕ RK_0) ⊕ x_1
word 2: x_2 (unchanged)
word 3: S(x_2 ⊕ RK_1) ⊕ x_3
etc.
This is already a 16-word state. Then we apply permutation pi where pi[h] tells us where input word h goes in the output.

Actually, PermuteLayer_CVL takes a list perm where perm[i] is the output position for input bit/word i.

From Algorithm 2.1: X_{pi[h]}^{i+1} <- X_h^i This means: the value at position h in the current state goes to position pi[h] in the next state.

For PermuteLayer_CVL, the permutation list perm means: input at position i goes to output at position perm[i].

So if pi = [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14]:

Input word 0 -> output word 5
Input word 1 -> output word 0
Input word 2 -> output word 1
etc.
This matches the algorithm. So we can use PermuteLayer_CVL(pi, word_coarseness=4).

But wait, in the permutation step, we need to permute the entire state (16 words). The state after Feistel operations is:

positions 0, 2, 4, ..., 14: from input even positions (unchanged)
positions 1, 3, 5, ..., 15: from XOR outputs
So we need to combine these into a single 16-word input to the permutation layer.

In CiVerLy's add_subcipher, we can map multiple source nodes to the same destination node's input. So:

# Build the state for permutation
perm_input_edges = []
for j in range(8):
    perm_input_edges.append((twine_round.IN, (2*j, 2*j)))       # even position
    perm_input_edges.append((xor_nodes[j], (0, 2*j + 1)))       # odd position

node_perm = twine_round.add_subcipher(perm, perm_input_edges)
twine_round.add_output([(node_perm, (i, i)) for i in range(16)])
Wait, but twine_round.IN is the input node. Can we use it multiple times in add_subcipher? Looking at abc.py:

node_xor = abc_round.add_subcipher(xor, [
    (node_r, (i, i)) for i in range(64)
] + [(node_bigr, (i, i + 64)) for i in range(64)])
Yes, multiple source nodes can be mapped to a single destination node. But can the same source node be used multiple times? Probably yes, as long as the destination indices don't overlap.

But wait, in this case:

(twine_round.IN, (0, 0)) maps word 0 of IN to word 0 of perm
(twine_round.IN, (2, 2)) maps word 2 of IN to word 2 of perm
That's fine because they're mapping different source words to different destination words.

Actually wait, I need to be more careful. The add_subcipher method of WordSBoxCipher might have issues with overlapping destination indices. Let me check if the perm input edges have any overlapping destination indices:

(twine_round.IN, (0, 0)) -> dest 0
(xor_nodes[0], (0, 1)) -> dest 1
(twine_round.IN, (2, 2)) -> dest 2
(xor_nodes[1], (0, 3)) -> dest 3
etc.
All destination indices are distinct (0 through 15), so this should be fine.

But wait, twine_round.IN might be used as a source in multiple edges within the same add_subcipher call. Is that allowed? In abc.py, abc_round.IN is used in multiple add_subcipher calls, but not multiple times within one call... Let me check.

Actually in abc.py:

node_rk = abc_round.add_subcipher(rk, [
    (abc_round.IN, (i + 64, i)) for i in range(64)
])
node_bigr = abc_round.add_subcipher(bigR, [
    (abc_round.IN, (i, i)) for i in range(64)
])
These are separate add_subcipher calls. Within each call, the source is the same but destination indices are all unique.

For my case, I'd be doing:

node_perm = twine_round.add_subcipher(perm, [
    (twine_round.IN, (0, 0)),
    (xor_nodes[0], (0, 1)),
    (twine_round.IN, (2, 2)),
    (xor_nodes[1], (0, 3)),
    ...
])
Since all (src_node, dst_node) combinations are unique in terms of destination indices, this should work. The framework just needs to route each source word to the specified destination word of perm.IN.

But actually, looking at the edge definition: (node, (src_index, dst_index))

src_index: which output word of node to read from
dst_index: which input word of the new subcipher to write to
So (twine_round.IN, (0, 0)) means "take word 0 of IN, put it into word 0 of perm" and (twine_round.IN, (2, 2)) means "take word 2 of IN, put it into word 2 of perm"

This should be perfectly valid.

For the last round (round 36), without permutation:

twine_final = WordSBoxCipher(4, 16, 16, name="twine_final")
rk_nodes_final = []
for j in range(8):
    rk_xor = RoundkeyXOR_CVL(4, const=0, name=f"rk_final{j}")
    node_rk = twine_final.add_subcipher(rk_xor, [(twine_final.IN, (2*j, 0))])
    rk_nodes_final.append(node_rk)

sbox_nodes_final = []
for j in range(8):
    node_s = twine_final.add_subcipher(sbox, [(rk_nodes_final[j], (0, 0))])
    sbox_nodes_final.append(node_s)

xor_nodes_final = []
for j in range(8):
    xor = XOR_CVL(4, name=f"xor_final{j}")
    node_xor = twine_final.add_subcipher(
        xor, [(sbox_nodes_final[j], (0, 0)), (twine_final.IN, (2*j + 1, 1))]
    )
    xor_nodes_final.append(node_xor)

# Output: even positions from input, odd positions from XOR
for j in range(8):
    twine_final.add_output([(twine_final.IN, (2*j, 2*j))])
    twine_final.add_output([(xor_nodes_final[j], (0, 2*j + 1))])
Hmm wait, add_output takes a list of edges. Let me make sure I use it correctly.

Looking at present.py:

present_cipher.add_output([(node, (i, i)) for i in range(16)])
Yes, add_output takes a list of (src_node, (src_index, dst_index)) where dst_index is the output index of the cipher.

So for the final round:

for j in range(8):
    twine_final.add_output([(twine_final.IN, (2*j, 2*j))])
    twine_final.add_output([(xor_nodes_final[j], (0, 2*j + 1))])
Or more cleanly:

output_edges = []
for j in range(8):
    output_edges.append((twine_final.IN, (2*j, 2*j)))
    output_edges.append((xor_nodes_final[j], (0, 2*j + 1)))
twine_final.add_output(output_edges)
For the full cipher:

cipher = WordSBoxCipher(4, 16, 16, name=name)
node = cipher.IN
for r in range(35):
    # Set round key constants for this round
    for j in range(8):
        twine_round.nodes[rk_nodes[j]].const = (rks[r] >> (4 * (7-j))) & 0xF
        # Wait, need to determine the byte order of rks[r]
    node = cipher.add_subcipher(twine_round, [(node, (i, i)) for i in range(16)])

# Final round
for j in range(8):
    twine_final.nodes[rk_nodes_final[j]].const = (rks[35] >> (4 * (7-j))) & 0xF
node = cipher.add_subcipher(twine_final, [(node, (i, i)) for i in range(16)])
cipher.add_output([(node, (i, i)) for i in range(16)])
Wait, I need to determine the round key format. In TWINE, RK^i is a 32-bit value containing 8 nibbles. RK_j^i is the j-th nibble.

Looking at Algorithm 2.1: RK_{0(4)}^i || RK_{1(4)}^i || ... || RK_{7(4)}^i <- RK_{(32)}^i

So RK_0 is the most significant nibble (or leftmost), RK_7 is the least significant.

In the reference Python code:

RK_32[r][0] = WK_80[1]
RK_32[r][1] = WK_80[3]
...
And in encryption:

X_16[i][2 * j + 1] = _S(X_16[i][2 * j] ^ RK_32[i][j]) ^ X_16[i][2 * j + 1]
So RK_32[i][j] corresponds to RK_j^i. In the test vectors, if rks is given as a list of 32-bit integers, we need to extract each nibble.

But wait, let's think about endianness. In the reference implementation, _get_4_bits(source, pos) extracts the nibble at position pos counting from the MSB:

def _get_4_bits(source, pos):
    return source >> pos * 4 & 0xF
And for the plaintext:

for i in range(16):
    X_16[1][i] = _get_4_bits(P, 16 - 1 - i)
So X_16[1][0] is the MSB nibble of P, X_16[1][15] is the LSB nibble.

For the round key:

RK_32[r][0] = WK_80[1]
Where WK_80[1] was extracted similarly:

for i in range(20):
    WK_80.append(_get_4_bits(key, 20 - 1 - i))
So WK_80[0] is the MSB nibble of the

Now I have a good understanding. Let me check how add_subcipher handles multiple source nodes mapped to a single destination, and look at test vectors more carefully. Then I'll implement the cipher.

xBefore writing the final code, let me verify my understanding of bit/word ordering in CiVerLy by looking at how int_to_vec/vec_to_int work and how PRESENT test vectors align.

From present.py, they use int_to_vec(0xabcd1234, 64) which creates a 64-bit vector. The test vector 0x0 encrypts to 0x5579C138_7B228445 with specific rks.

For TWINE, the test vectors are:

80-bit key: 00112233 44556677 8899 = 0x00112233445566778899
Plaintext: 01234567 89ABCDEF = 0x0123456789ABCDEF
Ciphertext: 7C1F0F80 B1DF9C28 = 0x7C1F0F80B1DF9C28
128-bit key: 00112233 44556677 8899AABB CCDDEEFF
Ciphertext: 979FF9B3 79B5A9B8
My implementation should match these.

Let me now carefully build the implementation. The critical question is how int_to_vec orders bits. Let me check the utility function.

Actually, I don't have the utility code handy. But from the pattern in present.py and other ciphers, int_to_vec(value, n) converts an integer to a bit vector of length n. The standard convention in Sage/CiVerLy is typically LSB first (bit 0 is the least significant bit).

Wait, but for word-based ciphers, int_to_vec(value, n) with n=64 and word size 4 would give 16 words. The question is whether word 0 corresponds to the MSB nibble or LSB nibble.

Looking at present.py's test vector:

rks = [0x0000000000000000, 0xc000000000000000, ...]
And encryption with key=0 gives 0x5579C138_7B228445.

In PRESENT, the key is XORed as a 64-bit value. If 0xc000000000000000 is the round 1 key, that means the MSB byte is 0xc0.

For my TWINE implementation, I need to be careful about nibble ordering. Let me look at algo.py:

def _get_4_bits(source, pos):
    return source >> pos * 4 & 0xF
This extracts from the MSB side (pos=0 is the MSB nibble). And:

for i in range(16):
    X_16[1][i] = _get_4_bits(P, 16 - 1 - i)
So X_16[1][0] = MSB nibble, X_16[1][15] = LSB nibble.

In CiVerLy, it's possible that int_to_vec(0x0123456789ABCDEF, 64) gives a vector where index 0 is the LSB. So word 0 (bits 0-3) would be 0xF, word 15 (bits 60-63) would be 0x0.

This means the indexing is reversed compared to the paper! In the paper, x_0 is the MSB, while in CiVerLy's int_to_vec, word 0 is the LSB.

But wait, when we call the cipher:

present_cipher(int_to_vec(0xabcd1234, 64))
If the cipher uses word indices directly, then word 0 in the cipher corresponds to the LSB 4 bits, which is 0x4.

For PRESENT, the S-box layer applies to all 16 words in order. The permutation in PRESENT is:

permutation = PermuteLayer_CVL([
    0, 16, 32, 48, 1, 17, 33, 49, ...
], name="Permutation")
Wait, that's a bit-level permutation! PRESENT operates at the bit level within the SBoxCipher framework. But TWINE operates at the word level.

In WordSBoxCipher, edges are word indices. So word 0 is the first word. If int_to_vec(0x0123456789ABCDEF, 64) maps LSB to index 0, then:

bits 0-3 = 0xF → word 0
bits 4-7 = 0xE → word 1
...
bits 60-63 = 0x0 → word 15
But the paper says x_0 is the MSB. So to match the paper's test vectors, I may need to reverse the word order.

Hmm, let me check how int_to_vec works by looking at the util module.

Actually, let me just test my understanding by writing a quick script to see the behavior. But first, let me look at the util code.

Now I understand the bit ordering. int_to_vec(0x12340, 24) gives: (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0)

Let's verify: 0x12340 = binary 0001 0010 0011 0100 0000

Reading the vector: (0,0,0,0,0,0,0, 1,0,0,1,0,0,0,1,1,0,1, 0,0,0,0,0,0)

Wait, that's not straightforward. Let me think about vec_to_int:

for i in input_vec:
    output_num <<= 1
    output_num += ZZ(i)
So the first element of the vector becomes the MSB. For (1, 0, 0, 1, ...):

Start: 0
See 1: 0<<1 + 1 = 1
See 0: 1<<1 + 0 = 2
See 0: 2<<1 + 0 = 4
See 1: 4<<1 + 1 = 9
...
So the vector (a, b, c, d, ...) represents the integer where a is the MSB. That means int_to_vec(value, n) returns a vector where index 0 is the MSB.

Wait, but in int_to_vec(0x12340, 24): 0x12340 = 0b0001 0010 0011 0100 0000

The vector is (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0)

MSB first: 0000 0001 0010 0011 0100 0000 = 0x023400?

Wait, that doesn't match. Let me recount.

0x12340 = 74560 in decimal Binary: 10010001101000000 = 17 bits Padded to 24 bits: 0000 0001 0010 0011 0100 0000

The vector shows: (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0)

Positions 0-23: 0 0 0 0 0 0 0 1 0 0 1 0 0 0 1 1 0 1 0 0 0 0 0 0

As MSB-first: 0000 0001 0010 0011 0100 0000 = 0x023400

But that should be 0x12340... unless I'm misunderstanding.

Wait, let me compute vec_to_int on that vector:

Start: 0
0: 0
0: 0
0: 0
0: 0
0: 0
0: 0
0: 0
1: 1
0: 2
0: 4
1: 9
0: 18
0: 36
0: 72
1: 145
1: 291
0: 582
1: 1165
0: 2330
0: 4660
0: 9320
0: 18640
0: 37280
0: 74560
74560 = 0x12340. OK so the vector IS correct! The representation is MSB-first.

So in CiVerLy:

int_to_vec(0x0123456789ABCDEF, 64) gives a 64-bit vector
Vector index 0 is the MSB (bit 63 of the integer)
For a word size of 4, word 0 = bits 0-3 of the vector = bits 63-60 of the integer = 0x0
word 1 = bits 4-7 of the vector = bits 59-56 of the integer = 0x1
word 15 = bits 60-63 of the vector = bits 3-0 of the integer = 0xF
So word index 0 corresponds to the MSB nibble of the integer. This matches the paper's convention where x_0 is the MSB!

Wait, let me double-check:

Vector: (v[0], v[1], ..., v[63])
v[0] is MSB of the integer, v[63] is LSB
Word 0 = v[0:4] = MSB nibble
Word 15 = v[60:64] = LSB nibble
So word j in CiVerLy corresponds to bits 4j to 4j+3 of the vector, i.e., nibble j from the MSB side. This means:

word 0 = integer bits [63:60] = MSB nibble
word 1 = integer bits [59:56]
...
word 15 = integer bits [3:0] = LSB nibble
And this is exactly how TWINE defines its state: x_0 is the MSB nibble, x_15 is the LSB.

Great! So there's no need to reverse anything. The CiVerLy convention matches the paper.

Now, what about round key format? If someone passes rks as a list of 32-bit integers, how do we map them to RK_0 through RK_7?

Looking at the reference Python:

RK_32 = ddict(ddict)
...
RK_32[r][0] = WK_80[1]
And in encryption:

X_16[i][2 * j + 1] = _S(X_16[i][2 * j] ^ RK_32[i][j]) ^ X_16[i][2 * j + 1]
So RK_32[i][j] is the j-th round key nibble for round i. And from the key schedule, for 80-bit:

RK[0] = WK_1
RK[1] = WK_3
RK[2] = WK_4
RK[3] = WK_6
RK[4] = WK_13
RK[5] = WK_14
RK[6] = WK_15
RK[7] = WK_16
And in the reference: WK_80[0] is the MSB nibble of the key. So RK_32[r][0] = WK_80[1] is the second nibble from the MSB.

For the CiVerLy round key constants, if rks[r] is a 32-bit integer, and we want RK_j to be the j-th nibble:

If rks[r] = 0x12345678
RK_0 = nibble at bits [31:28] = 0x1
RK_1 = nibble at bits [27:24] = 0x2
...
RK_7 = nibble at bits [3:0] = 0x8
Since in CiVerLy word 0 corresponds to the MSB side, RK_0 would be (rks[r] >> 28) & 0xF. Wait, but actually RoundkeyXOR_CVL(4) takes a 4-bit constant. If rks[r] is a 32-bit value, the j-th nibble from MSB is (rks[r] >> (28 - 4*j)) & 0xF.

But maybe a more natural API is to accept rks as a list of 32-bit integers, and extract nibbles from them.

Alternatively, since in the paper each RK^i is 32 bits with 8 nibbles, the user could pass rks as a list where each element is a 32-bit round key. Then we extract:

for j in range(8):
    nibble = (rks[r] >> (28 - 4*j)) & 0xF
But wait, let me reconsider. Is word 0 really the MSB? When int_to_vec(0x12340, 24) gives a vector where the first element maps to the MSB, and when that vector is split into words in a WordSBoxCipher(4, ...), the words are 4-bit chunks starting from index 0. So word 0 = v[0:4] = MSB nibble.

Yes, that's correct.

Now let me design the TWINE implementation more carefully.

For the round function:

Even words 0, 2, ..., 14 pass through a RoundkeyXOR
S-box applied to the XOR results
XOR with odd words 1, 3, ..., 15
Permutation applied to the resulting 16-word state
For CiVerLy, the edges connect word positions:

(src_node, (src_word, dst_word))
In the round template:

twine_round = WordSBoxCipher(4, 16, 16, name="round")

# Even words go through RoundkeyXOR -> SBox
rk_nodes = []
sbox_nodes = []
for j in range(8):
    rk = RoundkeyXOR_CVL(4, const=0, name=f"rk{j}")
    node_rk = twine_round.add_subcipher(rk, [(twine_round.IN, (2*j, 0))])
    rk_nodes.append(node_rk)
    
    sbox_component = SBox_CVL(SBox(twine_sbox), name=f"S{j}")
    node_s = twine_round.add_subcipher(sbox_component, [(node_rk, (0, 0))])
    sbox_nodes.append(node_s)

# SBox outputs XORed with odd words
xor_nodes = []
for j in range(8):
    xor = XOR_CVL(4, name=f"xor{j}")
    node_xor = twine_round.add_subcipher(
        xor, 
        [(sbox_nodes[j], (0, 0)), (twine_round.IN, (2*j + 1, 1))]
    )
    xor_nodes.append(node_xor)

# Build the state and apply permutation
perm = PermuteLayer_CVL(
    [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14],
    word_coarseness=4,
    name="perm"
)

perm_edges = []
for j in range(8):
    # Even positions from input
    perm_edges.append((twine_round.IN, (2*j, 2*j)))
    # Odd positions from XOR outputs
    perm_edges.append((xor_nodes[j], (0, 2*j + 1)))

node_perm = twine_round.add_subcipher(perm, perm_edges)
twine_round.add_output([(node_perm, (i, i)) for i in range(16)])
Wait, but perm_edges maps specific words of specific nodes to perm.IN. Let me verify:

(twine_round.IN, (0, 0)): word 0 of IN -> word 0 of perm
(xor_nodes[0], (0, 1)): word 0 of xor0 -> word 1 of perm
(twine_round.IN, (2, 2)): word 2 of IN -> word 2 of perm
(xor_nodes[1], (0, 3)): word 0 of xor1 -> word 3 of perm
This creates the pre-permutation state where:

perm.IN word 0 = x_0
perm.IN word 1 = S(x_0 ⊕ RK_0) ⊕ x_1
perm.IN word 2 = x_2
perm.IN word 3 = S(x_2 ⊕ RK_1) ⊕ x_3
etc.
This is correct! Then perm maps:

word 0 -> output word 5
word 1 -> output word 0
word 2 -> output word 1
etc.
And twine_round.add_output([(node_perm, (i, i)) for i in range(16)]) outputs each word of node_perm to the corresponding output word of twine_round.

For the full cipher, in each round we need to set the 8 roundkey constants.

Actually, I just realized a problem. Looking at present.py:

present_round.nodes[node_rk].const = rks[r]
Here node_rk is a single node ID for the entire RoundkeyXOR_CVL(64) component. For TWINE, I have 8 separate RoundkeyXOR_CVL(4) nodes. So I'd set each one individually:

for j in range(8):
    rk_val = (rks[r] >> (28 - 4*j)) & 0xF
    twine_round.nodes[rk_nodes[j]].const = rk_val
node = cipher.add_subcipher(twine_round, [(node, (i, i)) for i in range(16)])
Wait, but does this work? Since twine_round is reused each iteration, but add_subcipher creates a copy, the const values are captured at the time of the call. This should work the same way as PRESENT.

Actually, there might be an issue. In PRESENT, node_rk refers to a single node. Setting present_round.nodes[node_rk].const = rks[r] modifies the template, and the next copy gets the current value. But for TWINE, if I set twine_round.nodes[rk_nodes[0]].const = val0, then twine_round.nodes[rk_nodes[1]].const = val1, etc., all before calling add_subcipher, it should work fine.

Wait, there's a subtlety. If I create twine_round once and reuse it, and I set all 8 constants each time, then call add_subcipher, the copied instance gets all 8 constants. Then for the next round, I update all 8 constants again and call add_subcipher again. This should work.

But wait - what if add_subcipher doesn't deep-copy but rather creates a shallow reference? Then all rounds would share the same RK components and changing one would change all. But present.py works, so add_subcipher must properly copy const values.

OK, another consideration: the S-box component. In PRESENT, they create one SBox_CVL and reuse it:

s = SBox_CVL(present_S, name="SBox")
Then add it to sboxlayer 16 times. For TWINE, can I reuse the same SBox_CVL object? Looking at sboxlayer in present.py:

sboxlayer = WordSBoxCipher(4, 16, 16, name="SBoxLayer")
for j in range(16):
    node = sboxlayer.add_subcipher(s, [(sboxlayer.IN, (j, 0))])
    sboxlayer.add_output([(node, (0, j))])
So reusing s is fine. For TWINE, the S-box layer has 8 instances, so I can create one SBox_CVL and use it 8 times.

Now for the final round (round 36):

twine_final = WordSBoxCipher(4, 16, 16, name="twine_final")

rk_nodes_final = []
for j in range(8):
    rk = RoundkeyXOR_CVL(4, const=0, name=f"rk_final{j}")
    node_rk = twine_final.add_subcipher(rk, [(twine_final.IN, (2*j, 0))])
    rk_nodes_final.append(node_rk)

sbox_nodes_final = []
for j in range(8):
    node_s = twine_final.add_subcipher(sbox, [(rk_nodes_final[j], (0, 0))])
    sbox_nodes_final.append(node_s)

xor_nodes_final = []
for j in range(8):
    xor = XOR_CVL(4, name=f"xor_final{j}")
    node_xor = twine_final.add_subcipher(
        xor, [(sbox_nodes_final[j], (0, 0)), (twine_final.IN, (2*j + 1, 1))]
    )
    xor_nodes_final.append(node_xor)

output_edges = []
for j in range(8):
    output_edges.append((twine_final.IN, (2*j, 2*j)))
    output_edges.append((xor_nodes_final[j], (0, 2*j + 1)))
twine_final.add_output(output_edges)
Wait, I need to confirm whether the last round is round 35 or 36. From Algorithm 2.1:

For i = 1 to 35: full round (S-box + XOR + perm)
Round 36: S-box + XOR (no perm)
Total: 36 rounds
So we need 35 iterations of twine_round + 1 final twine_final.

Actually wait, the loop for i <- 1 to 35 does rounds 1 through 35. After round 35, we have state X^{36}. Then we apply the final S-box layer to X^{36} to get the ciphertext.

But in the standard Feistel network formalism, round 36 is often considered the "last round" without permutation because the permutation is not needed for security on the final round (or it's considered part of the output).

Looking at the figure: it shows a 36-round cipher. The reference code in algo.py also has:

for i in range(1, 36):  # rounds 1 to 35
    ...
for j in range(0, 8):   # round 36
    X_16[36][2 * j + 1] = ...
So yes, 35 rounds with permutation + 1 final round without permutation = 36 rounds total.

Now for the key schedule. The TWINE specifications have two key schedules: 80-bit and 128-bit. I'll implement both.

Actually, looking at the present.py pattern, rks is a parameter. For TWINE, I'll accept either:

rks - a list of 36 32-bit round keys (used for testing)
key and key_size - the master key, from which round keys are derived
If neither is provided, default to all-zero round keys.

Let me implement the key schedule functions based on algo.py and the paper.

For 80-bit:

def _key_schedule_80(key):
    ROUND_CONSTANTS = [
        0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x03, 0x06, 0x0C, 0x18,
        0x30, 0x23, 0x05, 0x0A, 0x14, 0x28, 0x13, 0x26, 0x0F, 0x1E,
        0x3C, 0x3B, 0x35, 0x29, 0x11, 0x22, 0x07, 0x0E, 0x1C, 0x38,
        0x33, 0x25, 0x09, 0x12, 0x24
    ]
    
    TWINE_SBOX = [0xC, 0x0, 0xF, 0xA, 0x2, 0xB, 0x9, 0x5,
                  0x8, 0x3, 0xD, 0x7, 0x1, 0xE, 0x6, 0x4]
    
    # Split key into 20 nibbles (MSB first)
    WK = [(key >> (4 * (19 - i))) & 0xF for i in range(20)]
    
    rks = []
    
    for r in range(1, 36):
        # Extract round key
        rk = 0
        rk |= WK[1] << 28
        rk |= WK[3] << 24
        rk |= WK[4] << 20
        rk |= WK[6] << 16
        rk |= WK[13] << 12
        rk |= WK[14] << 8
        rk |= WK[15] << 4
        rk |= WK[16]
        rks.append(rk)
        
        # Update WK
        WK[1] = WK[1] ^ TWINE_SBOX[WK[0]]
        WK[4] = WK[4] ^ TWINE_SBOX[WK[16]]
        con_h = (ROUND_CONSTANTS[r - 1] >> 3) & 0x7  # 3-bit high part
        con_l = ROUND_CONSTANTS[r - 1] & 0x7         # 3-bit low part
        WK[7] = WK[7] ^ con_h
        WK[19] = WK[19] ^ con_l
        
        # Rot4 on WK[0:4]
        WK[0:4] = WK[1:4] + [WK[0]]
        
        # Rot16 on WK[0:20]
        WK[0:20] = WK[4:20] + WK[0:4]
    
    # Round 36
    rk = 0
    rk |= WK[1] << 28
    rk |= WK[3] << 24
    rk |= WK[4] << 20
    rk |= WK[6] << 16
    rk |= WK[13] << 12
    rk |= WK[14] << 8
    rk |= WK[15] << 4
    rk |= WK[16]
    rks.append(rk)
    
    return rks
Wait, I need to be careful with r indexing. The constants CON^r are for r = 1 to 35. In the list, index 0 corresponds to r=1. So ROUND_CONSTANTS[r-1] is correct.

But wait, the constant format: CON^r = CON_H^r || CON_L^r where each is 3 bits. The paper says 0 || CON_H^r and 0 || CON_L^r are XORed with 4-bit WK values. So we XOR the 3-bit constant with the lower 3 bits of the 4-bit WK word, keeping the MSB unchanged... or actually, since 0 || CON_H is a 4-bit value, we XOR with the full 4-bit word.

Wait: WK_7 <- WK_7 ⊕ 0 || CON_H^r means concatenate 0 (1 bit) with CON_H (3 bits) to get a 4-bit value, then XOR with the 4-bit WK_7.

But 0 || CON_H is just a 4-bit value where the MSB is 0. So WK_7 ^ (CON_H & 0x7) since the MSB is 0.

And CON_H is only 3 bits, so 0 || CON_H is a 4-bit value in range 0-7.

Actually, in the paper, CON^i(6) = CON^i_H(3) || CON^i_L(3). The round constants table shows values like 01, 02, 04, etc. in hex. These are 6-bit values:

CON^1 = 0x01 = 0b000001
CON^2 = 0x02 = 0b000010
CON^3 = 0x04 = 0b000100
So CON_H = upper 3 bits, CON_L = lower 3 bits:

CON^1: CON_H = 0b000 = 0, CON_L = 0b001 = 1
CON^2: CON_H = 0b000 = 0, CON_L = 0b010 = 2
CON^3: CON_H = 0b000 = 0, CON_L = 0b100 = 4
CON^7: CON_H = 0b000 = 0, CON_L = 0b011 = 3
Wait, but then 0 || CON_H would just be CON_H padded to 4 bits. And CON_H being 3 bits means 0 || CON_H is a 4-bit value with MSB = 0.

In algo.py:

def _CON_L(r):
    return con[r] & 0b111

def _CON_H(r):
    return con[r] >> 3 & 0b111
And:

WK_80[7] = WK_80[7] ^ _CON_H(r)
WK_80[19] = WK_80[19] ^ _CON_L(r)
So they're XORing the 3-bit constants directly with the 4-bit WK values. This is equivalent to XORing with 0 || CON because the 3-bit value is interpreted as having an implicit 0 MSB. Since XOR with a 3-bit value affects only the lower 3 bits, and the MSB of the 4-bit word is XORed with 0 (unchanged).

Ah wait, actually WK_7 ^ CON_H where CON_H is a 3-bit integer... In Python, 0x5 ^ 0x3 = 0x6. If we meant 0b0101 ^ 0b0011 = 0b0110 = 0x6. That's correct because the implicit MSB of CON_H is 0, so we're XORing the lower 3 bits.

So my key schedule is correct.

For 128-bit key schedule, the difference is:

WK has 32 nibbles
RK_r uses different positions: WK_2, WK_3, WK_12, WK_15, WK_17, WK_18, WK_28, WK_31
Additional S-box update: WK_23 <- WK_23 ⊕ S(WK_30)
Rot16 operates on WK[0:32]
def _key_schedule_128(key):
    ROUND_CONSTANTS = [...]
    TWINE_SBOX = [...]
    
    WK = [(key >> (4 * (31 - i))) & 0xF for i in range(32)]
    
    rks = []
    for r in range(1, 36):
        rk = (WK[2] << 28) | (WK[3] << 24) | (WK[12] << 20) | (WK[15] << 16) | \
             (WK[17] << 12) | (WK[18] << 8) | (WK[28] << 4) | WK[31]
        rks.append(rk)
        
        WK[1] = WK[1] ^ TWINE_SBOX[WK[0]]
        WK[4] = WK[4] ^ TWINE_SBOX[WK[16]]
        WK[23] = WK[23] ^ TWINE_SBOX[WK[30]]
        con_h = (ROUND_CONSTANTS[r - 1] >> 3) & 0x7
        con_l = ROUND_CONSTANTS[r - 1] & 0x7
        WK[7] = WK[7] ^ con_h
        WK[19] = WK[19] ^ con_l
        
        WK[0:4] = WK[1:4] + [WK[0]]
        WK[0:32] = WK[4:32] + WK[0:4]
    
    rk = (WK[2] << 28) | (WK[3] << 24) | (WK[12] << 20) | (WK[15] << 16) | \
         (WK[17] << 12) | (WK[18] << 8) | (WK[28] << 4) | WK[31]
    rks.append(rk)
    
    return rks
Now, one thing about the ROUND_CONSTANTS in the reference. In algo.py:

con = {
    0x01: 0x01,
    0x02: 0x02,
    ...
    0x23: 0x24,
}
This is a dictionary mapping round number to constant value. But the keys are 0x01, 0x02, ... which is weird. Actually, it seems like they're using the round number r directly as a key. But r goes from 1 to 35. And the constants in the paper go from CON^1 to CON^35.

In algo.py:

WK_80[7] = WK_80[7] ^ _CON_H(r)
And _CON_H(r) does con[r] >> 3 & 0b111. But r is 1, 2, ..., 35. And con has keys 1, 2, 3, ..., 35 (in hex: 0x01 to 0x23).

So the constants are:

ROUND_CONSTANTS = [
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
    0x03, 0x06, 0x0C, 0x18, 0x30, 0x23,
    0x05, 0x0A, 0x14, 0x28, 0x13, 0x26,
    0x0F, 0x1E, 0x3C, 0x3B, 0x35, 0x29,
    0x11, 0x22, 0x07, 0x0E, 0x1C, 0x38,
    0x33, 0x25, 0x09, 0x12, 0x24
]
Wait, the algo.py dictionary has entries up to 0x23: 0x24. Let me verify the full list from the image:

From the key schedule image: i: 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 CON: 01 02 04 08 10 20 03 06 0C 18 30 23 05 0A 14 28 13 26

i: 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 CON: 0F 1E 3C 3B 35 29 11 22 07 0E 1C 38 33 25 09 12 24

So the constants are (index 0 = i=1): [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x03, 0x06, 0x0C, 0x18, 0x30, 0x23, 0x05, 0x0A, 0x14, 0x28, 0x13, 0x26, 0x0F, 0x1E, 0x3C, 0x3B, 0x35, 0x29, 0x11, 0x22, 0x07, 0x0E, 0x1C, 0x38, 0x33, 0x25, 0x09, 0x12, 0x24]

That's 35 constants for rounds 1-35. Correct.

Now, let me implement the cipher. I need to think about whether to separate the key schedule computation into a function or do it inline. For cleanliness, I'll make it a static method or a module-level function.

Also, I should support the R parameter for reduced-round variants, though TWINE always has 36 rounds. Looking at present.py, it takes R=31 as a parameter. For TWINE, I can default to 36 but allow other values for analysis.

Wait, but the key schedule produces exactly 36 round keys. If R < 36, we'd need fewer. But for a general implementation, we can still accept R.

For the test vectors, I need to verify with the reference implementation. Let me pre-compute the expected round keys for the test key to make sure my key schedule is correct.

Actually, let me just write a quick verification using the reference algo.py. But algo.py computes RK as a nested dict, not a list. Let me adapt it.

Hmm, before writing the full CiVerLy file, let me run a quick test to verify my key schedule matches the reference. I'll do this in Python/Sage.

Actually, I can just run the algo.py functions and compare.

Now let me think about potential issues with my CiVerLy implementation:

S-box sharing: If I reuse the same SBox_CVL object across all 8 positions, does CiVerLy handle it correctly? In present.py, they reuse s 16 times within sboxlayer. So yes, it should be fine.
XOR_CVL in word-based mode: XOR_CVL(4) takes 8 bits = 2 words of 4 bits. In a WordSBoxCipher, edges are word-based. So [(node_a, (0, 0)), (node_b, (0, 1))] would map word 0 of node_a to word 0 of XOR, and word 0 of node_b to word 1 of XOR. The output is word 0. This should work.
Permutation wiring: The perm_edges list needs to build a complete 16-word input to the permutation. Since perm.IN needs words 0-15, and we map from various source nodes, this should work as long as all destination indices 0-15 are covered without overlap.
add_output: For the round output, twine_round.add_output([(node_perm, (i, i)) for i in range(16)]) maps each word of node_perm to the same word index in the round's output.
Final round output: For twine_final, we don't have a permutation node. We directly output from twine_final.IN and the XOR nodes.
A potential issue: twine_final.add_output([(twine_final.IN, (2*j, 2*j))]) adds one edge at a time. Let me check if calling add_output multiple times is OK or if we need to pass all edges in one call.

Looking at present.py:

sboxlayer.add_output([(node, (0, j))])
In a loop, add_output is called once per S-box. So calling it multiple times should be fine.

Actually wait, looking at sboxlayer:

sboxlayer = WordSBoxCipher(4, 16, 16, name="SBoxLayer")
for j in range(16):
    node = sboxlayer.add_subcipher(s, [(sboxlayer.IN, (j, 0))])
    sboxlayer.add_output([(

Now I have a thorough understanding. Let me verify my understanding of the bit/word ordering and then write the implementation. Let me run a quick test in Sage first to confirm vector ordering.

... (code executions)

There's a circular import issue when running with sage -python directly. Let me try using sage -c instead, which runs in the proper Sage environment.

sage -c "
import sys
sys.path.insert(0, 'src')
from civerly.util import int_to_vec, vec_to_int
v = int_to_vec(0x0123456789ABCDEF, 64)
print('Vector:', v)
for i in range(16):
    bits = list(v[4*i:4*i+4])
    val = sum(int(bits[j]) << (3-j) for j in range(4))
    print(f'word {i:2d} (bits {4*i}:{4*i+4}): {bits} -> 0x{val:X}')
print('vec_to_int:', hex(vec_to_int(v)))
"
Vector: (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1)
word  0 (bits 0:4): [0, 0, 0, 0] -> 0x0
word  1 (bits 4:8): [0, 0, 0, 1] -> 0x1
word  2 (bits 8:12): [0, 0, 1, 0] -> 0x2
word  3 (bits 12:16): [0, 0, 1, 1] -> 0x3
word  4 (bits 16:20): [0, 1, 0, 0] -> 0x4
word  5 (bits 20:24): [0, 1, 0, 1] -> 0x5
word  6 (bits 24:28): [0, 1, 1, 0] -> 0x6
word  7 (bits 28:32): [0, 1, 1, 1] -> 0x7
word  8 (bits 32:36): [1, 0, 0, 0] -> 0x8
word  9 (bits 36:40): [1, 0, 0, 1] -> 0x9
word 10 (bits 40:44): [1, 0, 1, 0] -> 0xA
word 11 (bits 44:48): [1, 0, 1, 1] -> 0xB
word 12 (bits 48:52): [1, 1, 0, 0] -> 0xC
word 13 (bits 52:56): [1, 1, 0, 1] -> 0xD
word 14 (bits 56:60): [1, 1, 1, 0] -> 0xE
word 15 (bits 60:64): [1, 1, 1, 1] -> 0xF
vec_to_int: 0x123456789abcdef
Wait, this is confusing. int_to_vec(0x0123456789ABCDEF, 64) gives a vector where:

word 0 = bits 0-3 = 0x0
word 1 = bits 4-7 = 0x1
...
word 15 = bits 60-63 = 0xF
But vec_to_int of this vector gives 0x123456789abcdef, not 0x0123456789ABCDEF. Let me verify:

The vector printed is: (0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1)

64 bits total. As MSB-first: 0000 0001 0010 0011 0100 0101 0110 0111 1000 1001 1010 1011 1100 1101 1110 1111

= 0x0123456789ABCDEF

And vec_to_int computes from MSB to LSB, so it gives 0x123456789abcdef (same as input, just lowercase).

But when I split into words of 4 bits:

word 0 = v[0:4] = (0, 0, 0, 0) = 0x0
word 1 = v[4:8] = (0, 0, 0, 1) = 0x1
So word 0 in CiVerLy is the MSB nibble! And word 15 is the LSB nibble.

This means word j corresponds to bits 4j to 4j+3 of the vector, which is the nibble at position j from the MSB side.

For 0x0123456789ABCDEF:

word 0 = 0x0 (MSB nibble)
word 1 = 0x1
word 15 = 0xF (LSB nibble)
This is perfect! It matches the TWINE paper exactly where x_0 is the MSB nibble.

Now let me write the TWINE cipher implementation. Let me be very careful about the round key extraction.

If rks[r] is a 32-bit integer, and we want to extract the 8 nibbles:

for j in range(8):
    nibble = (rks[r] >> (28 - 4*j)) & 0xF
For rks[r] = 0x12345678:

j=0: nibble = 0x1
j=1: nibble = 0x2
j=7: nibble = 0x8
And this nibble corresponds to RK_j in the paper. Good.

Now, one more thing: what should the default rks be if no key is provided? Looking at present.py, it defaults to all zeros:

if rks == []:
    rks = [0 for _ in range(R+1)]
For TWINE, the default could be all-zero round keys, or we could compute from a default master key. Let me make the constructor accept either rks or a master key with key_size.

Actually, looking at other ciphers:

present.py takes rks list
skinny.py takes key parameter
For TWINE, I'll support both. If rks is provided, use it. If key is provided, compute the key schedule. If neither, default to zero round keys.

Now, let me write the full implementation file.

Wait, there's a design question: should I create a separate round subcipher for each round, or reuse one template? The present.py approach reuses a template. But for TWINE, since the round function is uniform (only the constants change), reusing a template is fine.

Actually, there's also the option to not create a template and instead manually compose each round directly in the main cipher. That avoids any issues with template copying. Let me see which approach is cleaner.

Looking at present.py:

present_round = WordSBoxCipher(4, 16, 16, name="present_round")
# ... build round ...
node = cipher.IN
for r in range(R):
    present_round.nodes[node_rk].const = rks[r]
    node = cipher.add_subcipher(present_round, ...)
This is clean. I'll follow the same pattern.

But wait, another potential issue I need to consider: In TWINE, each F-function within a round has its own roundkey nibble. We have 8 RoundkeyXOR_CVL components per round. When we set their constants on the template and then instantiate via add_subcipher, we need to make sure each instantiation gets its own copy of the constants.

Since present.py works with a single RoundkeyXOR_CVL, and the const is an integer (immutable), I'm confident the copy works correctly.

However, there is a subtle issue: can the same node object appear as a subcipher in a parent cipher multiple times? In PRESENT's sboxlayer:

for j in range(16):
    node = sboxlayer.add_subcipher(s, [(sboxlayer.IN, (j, 0))])
    sboxlayer.add_output([(node, (0, j))])
Here s is reused 16 times. Each call to add_subcipher(s, ...) creates a new node in the sboxlayer graph. So reusing component objects is fine.

The potential issue is only if the component itself has mutable state that's modified between calls. Since SBox_CVL and RoundkeyXOR_CVL carry immutable constants (except .const which we set on the NODE in the parent cipher, not the component), this is safe.

Actually wait - in present.py:

key_add = RoundkeyXOR_CVL(64, 0x0, name="KeyAdd")
present_round = WordSBoxCipher(4, 16, 16, name="present_round")
node_rk = present_round.add_subcipher(key_add, ...)
Then later:

key_add.const = rks[R]
cipher_node = present_cipher.add_subcipher(key_add, ...)
They set const on the component object directly, not on the node! But RoundkeyXOR_CVL extends ConstXOR_CVL which probably stores const on the component. When added as a subcipher, the component is copied? Or does the node reference the component's const?

Looking at ConstXOR_CVL:

class ConstXOR_CVL(Component):
    def __init__(self, length, const, name=None):
        ...
        self.const = const
And RoundkeyXOR_CVL(ConstXOR_CVL).

In present.py:

present_round.nodes[node_rk].const = rks[r]
Wait, they're setting .const on the NODE, not the component. Let me re-read:

present_round.nodes[node_rk].const = rks[r]
present_round.nodes[node_rk] is the node object in the present_round cipher graph. It has a .const attribute. Then when present_round is added as a subcipher to present_cipher, each instantiated node gets this const value.

And for the final key addition:

key_add.const = rks[R]
cipher_node = present_cipher.add_subcipher(key_add, ...)
Here they're setting const on the component directly. Since key_add hasn't been added to any cipher yet, this sets the default const for when it's instantiated.

So for TWINE, I have two options:

Set const on the template's nodes before each instantiation
Set const on the components directly
For the round template approach, option 1 is more appropriate since the template already has nodes. Let me make sure this is correct.

Actually, let me just read how nodes[node_id] works. In a Cipher object, nodes is a dictionary mapping node IDs to node objects. Each node object stores the component and its state (like const).

When add_subcipher is called, it creates new nodes in the parent cipher by copying the nodes from the subcipher. The copy should include the current const value.

So for TWINE:

for r in range(35):
    for j in range(8):
        rk_val = (rks[r] >> (28 - 4*j)) & 0xF
        twine_round.nodes[rk_nodes[j]].const = rk_val
    node = cipher.add_subcipher(twine_round, [(node, (i, i)) for i in range(16)])
This should work.

Wait, but there's a potential problem with reusing the same twine_round object. The nodes dictionary on twine_round is shared. When we call cipher.add_subcipher(twine_round, ...), CiVerLy creates copies of the nodes. If it copies by value, then modifying twine_round.nodes[...].const for the next round won't affect previously added rounds. This is what we want.

But if it copies by reference for some mutable fields... However, const is just an integer, so it's copied by value. And since present.py works exactly this way, it should be fine.

Now, there might be another issue. Looking at the round template more carefully:

twine_round = WordSBoxCipher(4, 16, 16, name="round")

# Even positions: RK XOR
rk_nodes = []
for j in range(8):
    rk = RoundkeyXOR_CVL(4, const=0, name=f"rk{j}")
    node_rk = twine_round.add_subcipher(rk, [(twine_round.IN, (2*j, 0))])
    rk_nodes.append(node_rk)

# S-box
sbox = SBox_CVL(SBox(twine_sbox), name="S")
sbox_nodes = []
for j in range(8):
    node_s = twine_round.add_subcipher(sbox, [(rk_nodes[j], (0, 0))])
    sbox_nodes.append(node_s)

# XOR with odd
xor_nodes = []
for j in range(8):
    xor = XOR_CVL(4, name=f"xor{j}")
    node_xor = twine_round.add_subcipher(
        xor,
        [(sbox_nodes[j], (0, 0)), (twine_round.IN, (2*j + 1, 1))]
    )
    xor_nodes.append(node_xor)

# Permutation layer
perm = PermuteLayer_CVL(
    [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14],
    word_coarseness=4,
    name="perm"
)

perm_edges = []
for j in range(8):
    perm_edges.append((twine_round.IN, (2*j, 2*j)))
    perm_edges.append((xor_nodes[j], (0, 2*j + 1)))
node_perm = twine_round.add_subcipher(perm, perm_edges)
twine_round.add_output([(node_perm, (i, i)) for i in range(16)])
One concern: Can twine_round.IN be used multiple times as a source in the same add_subcipher call? In perm_edges, twine_round.IN appears multiple times with different destination indices. Let me check if CiVerLy allows this.

Looking at the Cipher.add_subcipher method... I don't have it handy, but the abc.py example shows:

node_xor = abc_round.add_subcipher(xor, [
    (node_r, (i, i)) for i in range(64)
] + [(node_bigr, (i, i + 64)) for i in range(64)])
Here, node_r and node_bigr are two different source nodes, and they're mapped to xor.IN. But they're different nodes.

For my case, the same source node twine_round.IN is mapped to multiple destination indices. I believe this should work because each edge is independent. The framework just routes source words to destination words.

Actually, looking at sboxlayer in present.py:

for j in range(16):
    node = sboxlayer.add_subcipher(s, [(sboxlayer.IN, (j, 0))])
    sboxlayer.add_output([(node, (0, j))])
Here sboxlayer.IN is used in 16 different add_subcipher calls, each mapping a different word to the S-box. This is similar but across different calls. Within a single call, I don't see an example with the same source node multiple times.

But logically, adding [(src, (0, 0)), (src, (1, 1))] should be fine - it just means "take word 0 of src to word 0 of dst, and word 1 of src to word 1 of dst."

To be safe, I could avoid reusing twine_round.IN within the same add_subcipher by restructuring. But I think it's fine.

Wait, actually there's another option: build the intermediate state first using an identity layer, then apply permutation. But that adds complexity.

Actually, looking more carefully at add_subcipher in cipher.py might help. Let me check if there's any validation that prevents duplicate source nodes.

Actually, let me take a different approach to be completely safe. Instead of building the pre-permutation state by merging twine_round.IN and xor_nodes directly into perm.IN, I can build a small intermediate cipher that explicitly constructs the state:

# Build intermediate state explicitly
intermediate = WordSBoxCipher(4, 16, 16, name="intermediate")
for j in range(8):
    intermediate.add_output([(intermediate.IN, (2*j, 2*j))])
    intermediate.add_output([(intermediate.IN, (2*j+1, 2*j+1))])
No wait, that doesn't help. The issue is routing from multiple source nodes of twine_round to perm.IN.

Actually, I just realized PermuteLayer_CVL acts on a single input and outputs a single output. The input edges to add_subcipher just specify how to construct the input to perm from the available nodes. Since each edge maps a specific word from a specific source to a specific word of the destination, there should be no conflict.

Let me just proceed with this design. If there's an issue, I'll debug it.

One more thing: the perm_edges need to cover all 16 words of perm.IN:

Words 0, 2, 4, ..., 14: from twine_round.IN (even positions)
Words 1, 3, 5, ..., 15: from xor_nodes (odd positions)
And none of the destination indices overlap. This is correct.

For the final round:

twine_final = WordSBoxCipher(4, 16, 16, name="twine_final")
# ... same F-functions ...
output_edges = []
for j in range(8):
    output_edges.append((twine_final.IN, (2*j, 2*j)))
    output_edges.append((xor_nodes_final[j], (0, 2*j + 1)))
twine_final.add_output(output_edges)
Now let me write the complete file.

I also need to think carefully about the name handling. RoundkeyXOR_CVL(4, const=0, name=f"rk{j}") - the name helps in trail reports.

For doctests, I need:

Encryption test with 80-bit key
Encryption test with 128-bit key
Modeling test (MILP bitwise)
Modeling test (SAT optional)
Check for "Unnamed Component"
And I should verify the endianness of round keys. If rks is passed as a list of integers, each should be a 32-bit value. But actually, looking at present.py:

rks = [0x0000000000000000, 0xc000000000000000, ...]
Each element is a 64-bit integer. For TWINE, each rks[r] should be a 32-bit integer.

Wait, but what if rks is passed as a flat list of 8×36 nibbles? Or as a list of 36 integers? For consistency with present.py, we should accept a list of integers where each integer represents a round key.

But present.py has R+1 round keys because PRESENT has a final key addition after the last round. For TWINE, round 36 has its own round key built into the final round. So we still need 36 round keys, indexed 0 to 35 (for rounds 1 to 36).

Actually, if I make the loop for r in range(R) where R defaults to 36, and I use rks[r] for round r, I need len(rks) == R.

But what if R < 36? Then we'd have fewer rounds. The key schedule in the constructor can compute exactly R round keys if a master key is given. For the default R=36, it computes 36.

Wait, but TWINE always has 36 rounds in the specification. Should R default to 36? Looking at present.py, R=31 is a parameter. For TWINE, R=36 should be the default, but we can allow other values for cryptanalysis purposes.

But the key schedule only makes sense for the full 36 rounds (or fewer, if you just take the first R keys). And the test vectors are for 36 rounds.

Let me handle this by defaulting to R=36, and if a master key is given, computing R round keys.

Now, there's another subtlety. In present.py, they have R rounds + 1 final key addition, so rks needs R+1 elements. For TWINE, the last round is just a special round without permutation, but it still uses a round key. Since we have R rounds total (35 regular + 1 final, or R rounds for reduced variants), rks should have R elements.

Actually, let me think about reduced-round variants. If someone wants 4 rounds of TWINE for analysis:

Round 1: regular round with permutation
Round 2: regular round with permutation
Round 3: regular round with permutation
Round 4: final round without permutation
So for R rounds, we have R-1 regular rounds and 1 final round. But only if R >= 1. For analysis, this is useful.

However, looking at skinny.py, they have R parameter and all rounds are the same. For TWINE, the last round is different. Let me implement it as:

R rounds total
The last round (round R) is always without permutation
Rounds 1 to R-1 are with permutation
For the default R=36:

35 rounds with permutation
Round 36 without permutation
And rks needs exactly R elements.

Now let me write the file.

Wait, I should also figure out the proper path. Looking at src/civerly/cipher_implementations/present.py, the file is at that path. So I'll create src/civerly/cipher_implementations/twine.py.

Then I need to update __init__.py if it exports anything. Looking at the current __init__.py, it's empty. So no need to update.

Let me now write the full implementation.

One more thing to verify: the PermuteLayer_CVL permutation. The paper says: pi : {0, ..., 15} -> {0, ..., 15} where j-th sub-block is mapped to pi[j]-th sub-block.

And from Algorithm 2.1: X_{pi[h]}^{i+1} <- X_h^i

This means: input at position h goes to output at position pi[h].

PermuteLayer_CVL takes a list perm where perm[i] is the output position for input i.

So if pi = [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14]:

input 0 -> output 5
input 1 -> output 0
input 2 -> output 1
etc.
This matches PermuteLayer_CVL([5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14], word_coarseness=4).

And from the test, the reference Python uses:

permutation_enc = {
    0x0: 0x5, 0x1: 0x0, 0x2: 0x1, 0x3: 0x4,
    0x4: 0x7, 0x5: 0xC, 0x6: 0x3, 0x7: 0x8,
    0x8: 0xD, 0x9: 0x6, 0xA: 0x9, 0xB: 0x2,
    0xC: 0xF, 0xD: 0xA, 0xE: 0xB, 0xF: 0xE,
}
And in encryption:

X_16[i + 1][permutation_enc[h]] = X_16[i][h]
So permutation_enc[h] is the output position for input h. This matches PermuteLayer_CVL's interface perfectly.

Now let me draft the file:

from sage.crypto.sbox import SBox
from civerly.wordsboxcipher import WordSBoxCipher
from civerly.component import SBox_CVL, PermuteLayer_CVL, RoundkeyXOR_CVL, XOR_CVL

class TWINE_CVL:
    _SBOX_TABLE = [0xC, 0x0, 0xF, 0xA, 0x2, 0xB, 0x9, 0x5,
                   0x8, 0x3, 0xD, 0x7, 0x1, 0xE, 0x6, 0x4]
    _PERMUTATION = [5, 0, 1, 4, 7, 12, 3, 8, 13, 6, 9, 2, 15, 10, 11, 14]
    _ROUND_CONSTANTS = [
        0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
        0x03, 0x06, 0x0C, 0x18, 0x30, 0x23,
        0x05, 0x0A, 0x14, 0x28, 0x13, 0x26,
        0x0F, 0x1E, 0x3C, 0x3B, 0x35, 0x29,
        0x11, 0x22, 0x07, 0x0E, 0x1C, 0x38,
        0x33, 0x25, 0x09, 0x12, 0x24
    ]

    def _key_schedule_80(key):
        WK = [(key >> (4 * (19 - i))) & 0xF for i in range(20)]
        rks = []
        for r in range(1, 36):
            rk = (WK[1] << 28) | (WK[3] << 24) | (WK[4] << 20) | (WK[6] << 16) | \
                 (WK[13] << 12) | (WK[14] << 8) | (WK[15] << 4) | WK[16]
            rks.append(rk)
            WK[1] = WK[1] ^ TWINE_CVL._SBOX_TABLE[WK[0]]
            WK[4] = WK[4] ^ TWINE_CVL._SBOX_TABLE[WK[16]]
            con = TWINE_CVL._ROUND_CONSTANTS[r - 1]
            WK[7] = WK[7] ^ ((con >> 3) & 0x7)
            WK[19] = WK[19] ^ (con & 0x7)
            WK[0:4] = WK[1:4] + [WK[0]]
            WK[0:20] = WK[4:20] + WK[0:4]
        rk = (WK[1] << 28) | (WK[3] << 24) | (WK[4] << 20) | (WK[6] << 16) | \
             (WK[13] << 12) | (WK[14] << 8) | (WK[15] << 4) | WK[16]
        rks.append(rk)
        return rks

    def _key_schedule_128(key):
        WK = [(key >> (4 * (31 - i))) & 0xF for i in range(32)]
        rks = []
        for r in range(1, 36):
            rk = (WK[2] << 28) | (WK[3] << 24) | (WK[12] << 20) | (WK[15] << 16) | \
                 (WK[17] << 12) | (WK[18] << 8) | (WK[28] << 4) | WK[31]
            rks.append(rk)
            WK[1] = WK[1] ^ TWINE_CVL._SBOX_TABLE[WK[0]]
            WK[4] = WK[4] ^ TWINE_CVL._SBOX_TABLE[WK[16]]
            WK[23] = WK[23] ^ TWINE_CVL._SBOX_TABLE[WK[30]]
            con = TWINE_CVL._ROUND_CONSTANTS[r - 1]
            WK[7] = WK[7] ^ ((con >> 3) & 0x7)
            WK[19] = WK[19] ^ (con & 0x7)
            WK[0:4] = WK[1:4] + [WK[0]]
            WK[0:32] = WK[4:32] + WK[0:4]
        rk = (WK[2] << 28) | (WK[3] << 24) | (WK[12] << 20) | (WK[15] << 16) | \
             (WK[17] << 12) | (WK[18] << 8) | (WK[28] << 4) | WK[31]
        rks.append(rk)
        return rks

    def __init__(self, R=36, rks=None, key=None, key_size=80, name=None):
        # docstring with doctests
        ...
Wait, doctests in the __init__ docstring should contain test cases. But looking at present.py, the doctests are in the docstring of __init__. And in __init__, R=36 should be the default.

For key handling:

If rks is provided, use it
If key is provided, compute rks from key based on key_size
If neither, default to all-zero round keys
For key_size, valid values are 80 and 128.

One concern: what if someone passes both rks and key? We'll prioritize rks.

Actually, there's another issue. Looking at skinny.py:

def __init__(self, n=64, t=64, R=None, key=None, name=None):
And in present.py:

def __init__(self, R=31, rks=[], name=None):
For TWINE, I'll follow a hybrid approach.

Now, let me think about the class docstring. It should include:

Description of the cipher
Parameters
Examples for encryption with test vectors
Examples for modeling
Let me draft the full file now.

One more consideration: the key parameter. If I accept key as an integer, for 80-bit keys it's 0x00112233445566778899 and for 128-bit it's 0x00112233445566778899AABBCCDDEEFF. This matches the test vectors.

Wait, but do I need to handle key_size properly? If key_size=80 and someone passes a larger key, should I truncate or error? I'll just use the lower key_size bits.

Actually, algo.py uses the whole key and splits into nibbles. So (key >> (4 * (19 - i))) & 0xF for 80-bit. If the key is larger than 80 bits, the extra bits are ignored because i only goes up to 19. So that's fine.

For 128-bit: (key >> (4 * (31 - i))) & 0xF for i in 0..31.

Now, the ciphertext computation in my reference implementation is:

C = 0
for i in range(16):
    C = (C << 4) | X[36][i]
Where X[36][0] is the MSB nibble and X[36][15] is the LSB. This matches CiVerLy's word ordering (word 0 = MSB nibble).

So int_to_vec(P, 64) gives word 0 = MSB nibble, which is X[36][0]. And calling the cipher should produce a vector where vec_to_int gives the correct ciphertext.

Let me think about this: if cipher(int_to_vec(P, 64)) produces output vector v, then vec_to_int(v) should give C.

In the reference implementation, X[36][0] is the MSB. In CiVerLy, v[0:4] is the MSB nibble. So v[0:4] should equal X[36][0]. This is consistent.

Now, one subtle thing about PermuteLayer_CVL with word_coarseness=4. When word_coarseness is set, the permutation operates on words of that size. So PermuteLayer_CVL([5, 0, 1, 4, ...], word_coarseness=4) on a 64-bit (16-word) input will map word 0 to word 5, word 1 to word 0, etc.

Wait, but does perm_edges need to be at the word level or bit level? Since we're in a WordSBoxCipher, edges are word-based. PermuteLayer_CVL with word_coarseness=4 expects word-level inputs. So when we map word 0 of twine_round.IN to word 0 of perm.IN, in the word-based framework, this is correct.

Actually, looking at PRESENT's PermuteLayer_CVL:

permutation = PermuteLayer_CVL([
    0, 16, 32, 48, 1, 17, 33, 49, ...
], name="Permutation")
PRESENT doesn't set word_coarseness because it's an SBoxCipher (bit-level). The permutation maps bits directly.

For TWINE with WordSBoxCipher, we set word_coarseness=4 because the permutation operates on 4-bit words.

And in skinny.py:

shiftrows = PermuteLayer_CVL(perm=[
    0, 1, 2, 3, 7, 4, 5, 6, 10, 11, 8, 9, 13, 14, 15, 12
], word_coarseness=s, name="ShiftRows").inv()
So setting word_coarseness is the correct approach.

Let me also double-check: in WordSBoxCipher.add_subcipher, if the component is PermuteLayer_CVL with word_coarseness=4, and we pass word-level edges like (node, (0, 0)), does it correctly map word 0 to word 0? Since the PermuteLayer_CVL is configured for word-level operation, and the parent cipher is word-based, yes.

One more thing: the XOR_CVL component. In a word-based cipher, XOR_CVL(4) takes 8 bits = 2 words. When we wire word-level edges to it, we map:

word 0 of sbox output to word 0 of XOR input
word 1 of odd input to word 1 of XOR input
This should work because XOR_CVL doesn't care about words - it just sees 8 bits. In a word-based framework, add_subcipher translates word edges to bit edges internally. So (sbox_nodes[j], (0, 0)) means "word 0 of sbox_node goes to bits 0-3 of XOR input" and (twine_round.IN, (2*j+1, 1)) means "word 2j+1 of IN goes to bits 4-7 of XOR input".

Then XOR_CVL outputs 4 bits = 1 word. So (xor_node, (0, 2*j+1)) in perm_edges means "word 0 of xor_node goes to word 2j+1 of perm input".

This all seems correct.

Now let me write the file. I'll also think about whether to use R as a parameter more carefully.

For the constructor:

def __init__(self, R=36, rks=None, key=None, key_size=80, name=None):
If rks is None and key is not None:

if key_size == 80:
    rks = TWINE_CVL._key_schedule_80(key)
elif key_size == 128:
    rks = TWINE_CVL._key_schedule_128(key)
else:
    raise ValueError(...)
If rks is still None after that:

rks = [0 for _ in range(R)]
If len(rks) < R:

raise ValueError(f"Need {R} round keys, got {len(rks)}")
If len(rks) > R:

rks = rks[:R]
Actually, for present.py:

if rks == []:
    rks = [0 for _ in range(R+1)]
No length validation. I'll add validation to be safe.

For doctests, I want to show:

TWINE-80 encryption
TWINE-128 encryption
A modeling example
For the encryption tests, I can pre-compute the round keys using the key schedule functions, or I can pass the master key. Passing the master key is more natural for users.

Let me think about the doctest API:

sage: from civerly.cipher_implementations.twine import TWINE_CVL
sage: from civerly.util import int_to_vec, vec_to_int
sage: cipher = TWINE

... (implementation and short testing)

... (trying to analyse the cipher, times out)

Wait, num_nodes is 6? That seems too few for a 4-round TWINE cipher. Let me check. With 4 rounds, we should have:

1 input node
3 regular rounds (since R=4 means 3 regular + 1 final)
1 final round
That's 5 nodes total... Hmm, actually cipher.nodes might only count the direct children, not recursively.
Actually, in CiVerLy's DAG structure, when you add a subcipher, the subcipher becomes a single node in the parent cipher. The internal nodes of the subcipher are hidden from the parent. So with 4 rounds, we'd have:

IN
3 round instances
1 final round instance = 5 nodes
But we got 6. Maybe there's an extra node from something. Or maybe cipher.nodes includes outputs separately? Let me not worry about this too much.

The important thing is is_valid: True.

Now let me run a quick MILP model with R=3. I'll also try to just test if analyse works with a shorter timeout.

Actually, the issue with the timeout might be that Sage's SCIP solver is slow. Let me check if the problem is just the solve taking too long. Let me try with R=2 first.

Wait, but present.py's doctests use R=4 with SCIP and it runs fine. Maybe something in my cipher model is causing inefficiency.

Actually, another possibility: SCIP is not installed or has issues. Let me check what happens with a simpler call.

Actually, let me just try R=2 with a longer timeout. Or better yet, let me test the SAT solver which might be faster for 3-4 rounds.

Wait, actually the timeout might also be because the MILP model generation itself is hanging. Let me try to generate the model without solving to see if that works.

Let me try with R=2 and see if it runs in reasonable time.

Actually, I just realized: in the MILP analysis, the XOR_CVL component at bitwise granularity adds constraints for each bit. With 8 XORs per round × 4 bits = 32 XOR constraints per round. With 8 S-boxes per round. This shouldn't be any slower than PRESENT.

PRESENT has 16 S-boxes and 1 permutation per round. TWINE has 8 S-boxes, 8 XORs, and 1 permutation per round. So TWINE should be comparable in complexity.

Let me check if the issue is with the solver installation. Maybe I should try a different solver or just test with R=2.

... 

The R=2 analysis works and returns 2. Let me now test R=3 and R=4 to update the expected values in my doctests. I had guessed some values in the doctests. Let me run them to get the actual values.

... (accidental deletion by switching the branch by the user, file was written again)

The SAT test failed because espresso is not installed. That's expected - the doctest has # optional - espresso tag. Let me test with logic_minimizer=None or skip espresso.

Actually, looking at present.py, they also have tests with # optional - espresso. I'll keep my doctests with the same tags.

For the SAT doctest, I should use logic_minimizer=None or just mark it as optional. But the present.py example uses ESPRESSO_CVL() with the optional tag.

Actually, I can test what the SAT solver output would look like without espresso by not using LOGICAL_COND_ESPRESSO. Or I can use a different SAT modeling option that doesn't require espresso.

Wait, SBOX_MODELING.LOGICAL_COND_ESPRESSO specifically requires espresso. But I can test with a different modeling option. Let me check what options don't require espresso.

Looking at present.py, they have tests with:

SBOX_MODELING.CONVEX_HULL (MILP)
SBOX_MODELING.LOGICAL_COND_ESPRESSO (SAT, requires espresso)
SBOX_MODELING.DISTORTED_BALL (MILP)
For SAT, if espresso isn't available, we could use SBOX_MODELING.LOGICAL_COND which uses some other minimization. But I'm not sure.

Actually, since the doctest is tagged # optional - espresso, it's fine. The test will only run when espresso is available. For my own verification, I'll skip the SAT test.

But I do need to verify the numbers in my SAT doctest (clauses, variable counts, SAT trace). Since I can't run it, I'll need to estimate or use a simpler SAT model.

Actually, looking at the error, it failed during the logic_minimizer.solve call inside the SAT modeling. But the first call to cipher.analyse would have generated the SAT model, and the second call would try to solve it... Actually for SAT, analyse calls model which calls _model_sat.

I can avoid needing espresso by using a different sbox_modeling for SAT. Let me check if there's one that doesn't require espresso.

Actually, I think SBOX_MODELING.LOGICAL_COND might not require espresso. But let me look at the model_options to see.

Alternatively, I can just run the SAT test without espresso and see if it works, then base my doctest on that. But since I can't run espresso, maybe I should just write the SAT doctest with # optional - espresso tags and use placeholder values based on typical behavior.

Actually, wait. The MILP doctests are the most important to verify because they don't require external tools (SCIP might be available). The SAT doctests are optional.

Let me verify the linear MILP test too.

And actually for the SAT test in the doctest, I should probably provide more accurate values. Let me see if I can at least get the clause count by setting logic_minimizer=None and seeing what happens without the espresso solve step... Actually no, LOGICAL_COND_ESPRESSO specifically tries to call espresso.

I could just remove the SAT test and only keep MILP tests. But present.py has SAT tests, so it's good to have them too. Since they're optional, the exact numbers aren't critical for correctness - they just need to be in the right ballpark when espresso is available.

Actually, let me check what SBOX_MODELING options exist.

The linear MILP R=4 result is 3, not 4 as I had in the doctest. Let me update the doctest. Also, the constraints count is 4385, not 3937.

Now let me also check what SAT sbox modeling options exist that don't require espresso. Looking at present.py, they use SBOX_MODELING.LOGICAL_COND_ESPRESSO for SAT. But I could also try just running without espresso to see what happens with a different option. Or I could look at the available options.

Actually, looking at the SBOX_MODELING enum, there might be SBOX_MODELING.LOGICAL_COND which might be built-in. Let me search.

But for simplicity, I'll keep the SAT doctest as is with # optional - espresso tags, but I should make the numbers plausible. Looking at present.py's SAT test for R=4:

5312 variables and 13441 clauses
For TWINE R=3, with fewer S-boxes per round (8 vs 16), I'd expect roughly half the variables. My estimate of 2536 variables and ~9500 clauses seems reasonable. Actually, 8 S-boxes × 3 rounds = 24 S-boxes. Each S-box logical condition might generate ~300-400 clauses. Plus XOR constraints... Actually, I don't have a good estimate.

Let me try to check if there's a way to run SAT without espresso. I'll look at SBOX_MODELING options.

I see that SBOX_MODELING.LOGICAL_COND exists and doesn't require espresso. Let me test with that to verify SAT works. But actually, looking at the code, LOGICAL_COND might have different clause counts.

For the doctests, since espresso isn't available in our environment, I'll use placeholders and tag them as # optional - espresso or # optional - cryptominisat. But I need the numbers to be somewhat accurate.

Actually, I think the best approach is to use LOGICAL_COND for a SAT test that I can actually run and verify. Let me test that.

Wait, but LOGICAL_COND for SAT might use a built-in minimizer. Let me try it.

CryptoMiniSat is also not installed. So I can't run SAT tests locally. That's fine - the doctests are tagged as optional.

Now I need to decide: should I keep the SAT doctest with guessed values, or should I remove it? Looking at present.py, they have extensive SAT doctests with # optional - cryptominisat and # optional - espresso tags. It seems acceptable to have these.

However, my clause/variable counts might be wrong. I should try to estimate them more carefully or just remove the SAT test and only keep MILP tests.

Actually, looking at the model generation output for LOGICAL_COND with CRYPTOMINISAT_CVL: 2536 variables and 53953 clauses were written to '...'

But that's with LOGICAL_COND (not espresso-minimized). For LOGICAL_COND_ESPRESSO, the clause count would be lower because espresso minimizes the logic.

For present.py R=4 with SAT, LOGICAL_COND_ESPRESSO: 5312 variables and 13441 clauses were written to '...'

Wait, PRESENT R=4 has 5312 variables, and TWINE R=3 has 2536 variables. That's roughly half, which makes sense because TWINE has half the S-boxes per round.

For clauses, PRESENT R=4 has 13441 clauses with espresso. TWINE R=3 might have something in that ballpark too. The LOGICAL_COND (no espresso) gives 53953 clauses, which is much higher because espresso minimization significantly reduces the clause count.

So my original guess of ~9500 clauses for TWINE R=3 with espresso might be reasonable. But actually, looking more carefully:

PRESENT R=4: 4 rounds × 16 S-boxes = 64 S-boxes TWINE R=3: 3 rounds × 8 S-boxes = 24 S-boxes

Clause ratio: 24/64 = 0.375 of PRESENT's S-box count. But each S-box in TWINE is only used in the Feistel network, and there are also XOR constraints...

Actually, there's another factor: PRESENT has 64-bit permutations and key XORs. TWINE has 8 XOR_CVLs per round (2 rounds) + 8 in final = 8×2 + 8 = 24 XOR components. PRESENT has 1 key XOR.

Each XOR_CVL at bitwise granularity adds 4 clauses per bit, so 16 clauses per 4-bit XOR. With 24 XOR_CVLs, that's 384 clauses just from XORs.

For S-boxes with espresso, PRESENT gets ~13000 clauses for 64 S-boxes + XOR + perm. That's about 200 clauses per S-box. For TWINE with 24 S-boxes, that might be ~4800 clauses.

So for TWINE R=3 with espresso, maybe around 5000-6000 clauses. But I don't have exact numbers.

For the doctest, I'll use approximate numbers and just make sure they're tagged as optional. If someone runs the doctests with espresso installed, and the numbers don't match exactly, the doctest will fail. That's not ideal.

A safer approach: I can just remove the SAT doctest, or I can use SBOX_MODELING.LOGICAL_COND and CADICAL_CVL() (which might be available?).

Actually, let me check if cadical is available.

But regardless, the doctests for present.py and skinny.py already use # optional - cryptominisat extensively. So it's a known pattern that these tests only run when the solver is available.

However, to make my SAT doctest more robust, let me use R=2 which would have fewer variables and clauses, and the search trace would be shorter.

For TWINE R=2:

1 regular round (8 S-boxes + 8 XORs + perm)
1 final round (8 S-boxes + 8 XORs)
Total: 16 S-boxes, 16 XORs
Variables: 64 (input) + 64 (output) + intermediate states... Probably around 1500-2000 variables.

Actually, let me just look at what the model would output. Since I can't run espresso, let me look at comparable numbers.

PRESENT R=4 SAT: 5312 variables, 13441 clauses TWINE has roughly similar structure but with half the S-boxes and extra XOR_CVLs.

For R=2, TWINE should have about half the variables of PRESENT R=4. Maybe ~1500-2000 variables.

For clauses with espresso: maybe ~3000-5000.

Actually, you know what, let me just be conservative. I'll write the SAT doctest with R=2 and use # optional - cadical (which might be available, or I can check).

Actually, let me check which cadical.

No SAT solvers are installed. I'll remove the SAT doctest and keep only MILP doctests. For MILP, SCIP is available. Let me also update the linear MILP doctest with the correct numbers (3, not 4, and 4385 constraints).

Actually, looking at the output again: 3296 variables and 4385 constraints were written to '...' for linear MILP R=4.

Wait, but the differential MILP R=4 was: 3296 variables and 4097 constraints

And linear was: 3296 variables and 4385 constraints

Let me update the doctests. But I need to verify if is_valid returns True and if the trail check works.

Actually, I should also add a reduced-round encryption test. Let me also verify that R=1 encryption works correctly (though there won't be a test vector for reduced rounds, I can at least run it).

And let me double-check: do I need to handle R=1 properly in my implementation? With R=1:

for r in range(R - 1) => range(0) => no regular rounds
Final round is executed So we'd get just the final round (S-box + XOR, no permutation). This is correct for a 1-round TWINE.
What about R=0? That would be problematic because we'd still try to execute the final round. But R=0 isn't really meaningful for TWINE. I should maybe add a validation.

Actually, let me look at what the __init__ validation should be. PRESENT doesn't validate R. For TWINE, we can just let it work for any R >= 1. If R=0, it would just output the input directly (since no rounds are added). Actually wait:

for r in range(R - 1):
    ...
# Final round
for j in range(8):
    ...
node = cipher.add_subcipher(twine_final, ...)
If R=0, range(-1) is empty, so no regular rounds. But we'd still add the final round. That's wrong - for R=0, we shouldn't add any rounds.

But R=0 is a weird case. Let me just add a check:

if R < 1:
    raise ValueError("R must be at least 1")
Actually, present.py allows R=0? Let me check. In present.py:

for r in range(R):
    ...
key_add.const = rks[R]
cipher_node = present_cipher.add_subcipher(key_add, ...)
For R=0, this would add just the final key addition. For TWINE, the "final key addition" is actually the final round. So R=0 doesn't make much sense.

I'll add validation for R >= 1.

Actually wait, looking at abc.py, they have R=1 in tests. And for reduced-round analysis, R=1 is valid. But R=0 might not be useful.

Let me add if R < 1: raise ValueError(...).

Also, I should check what happens if R=1. With R=1:

No regular rounds (range(0) is empty)
One final round (S-box layer without permutation)
This is a valid reduced-round TWINE.
Let me also think about R=36:

35 regular rounds with permutation
1 final round without permutation This is the full TWINE.
OK, now let me update the doctests and add the R validation.

Let me also run the full 36-round encryption test again to make sure everything still works after my update.

... (removed SAT modeling doctest)

All tests pass. Let me update the todo list and provide a final summary. I should also verify the file looks clean and consider whether to update any init.py. Since init.py is empty, no update needed.

Let me also consider if there are any other files I should update. The AGENTS.md or README in cipher_implementations might mention available ciphers, but the user didn't ask me to update docs beyond the implementation.

Let me provide a final summary.

The TWINE cipher has been implemented in src/civerly/cipher_implementations/twine.py following the CiVerLy framework conventions.

What was implemented:

TWINE_CVL class using WordSBoxCipher (16 words of 4 bits)
Full key schedules for both 80-bit and 128-bit master keys, matching the TWINE specification
Round function construction with:
RoundkeyXOR_CVL for round-key mixing on even positions
SBox_CVL for the 4-bit TWINE S-box
XOR_CVL for Feistel-style XOR with odd positions
PermuteLayer_CVL(word_coarseness=4) for the word permutation
Proper last-round handling without permutation
Support for reduced-round variants via the R parameter
__new__ returning the underlying cipher object, consistent with existing implementations
Verification performed:

80-bit test vector: 0x0123456789ABCDEF encrypts to 0x7c1f0f80b1df9c28 ✅
128-bit test vector: 0x0123456789ABCDEF encrypts to 0x979ff9b379b5a9b8 ✅
is_valid returns True ✅
MILP bitwise differential analysis for R=4 yields optimal weight 6 ✅
MILP bitwise linear analysis for R=4 yields optimal weight 3 ✅
Trail output contains no "Unnamed Component" ✅

