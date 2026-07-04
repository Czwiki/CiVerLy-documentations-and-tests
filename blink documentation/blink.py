from typing import List

SBOX = [
    0x1, 0x0, 0x9, 0x3,
    0x8, 0x5, 0xE, 0x7,
    0x4, 0x2, 0xC, 0xB,
    0xA, 0xF, 0x6, 0xD,
]

P = [
    5, 12, 4, 1, 17, 9, 10, 16,
    28, 14, 21, 22, 11, 27, 8, 13,
    2, 25, 18, 3, 30, 6, 19, 20,
    0, 23, 24, 31, 7, 15, 29, 26,
]

INV_P = [0] * len(P)
for i, j in enumerate(P):
    INV_P[j] = i


def xor(state: List[int], key: List[int]) -> List[int]:
    return [s ^ k for s, k in zip(state, key)]


def S(state: List[int]) -> List[int]:
    return [SBOX[s] for s in state]


def M(state: List[int]) -> List[int]:
    n = len(state)
    columns = n // 4
    result = [0] * n

    for col in range(columns):
        a = state[col]
        b = state[col + columns]
        c = state[col + 2 * columns]
        d = state[col + 3 * columns]

        result[col] = b ^ c ^ d
        result[col + columns] = a ^ c ^ d
        result[col + 2 * columns] = a ^ b ^ d
        result[col + 3 * columns] = a ^ b ^ c

    return result


def permute(state: List[int], p: List[int] = P) -> List[int]:
    return [state[i] for i in p]


def inv_permute(state: List[int], p: List[int] = INV_P) -> List[int]:
    return [state[i] for i in p]


def int_to_bits(x: int, tau: int) -> List[int]:
    return [(x >> i) & 1 for i in range(tau)]


def bits_to_int(bits: List[int]) -> int:
    result = 0
    for i, b in enumerate(bits):
        result |= (b << i)
    return result


def toeplitz_hash(k: List[int], t: List[int], n: int) -> List[int]:
    tau = len(t)
    out = [0] * n

    for i in range(n):
        acc = 0
        for j in range(tau):
            if t[j] == 1:
                acc ^= k[i + j]
        out[i] = acc

    return out


def key_schedule(master: List[int], n_rounds: int, n: int):
    w1 = master[0:n]
    w2 = master[n:2 * n]

    rks = []
    idx = 2 * n
    for _ in range(n_rounds):
        rks.append(master[idx:idx + n])
        idx += n

    return w1, w2, rks


class KeySchedule:
    def __init__(self, master_key: List[int], n_rounds: int, n: int):
        self.w1 = master_key[:n]
        self.w2 = master_key[n:2 * n]

        rks = []
        idx = 2 * n
        for _ in range(n_rounds):
            rks.append(master_key[idx:idx + n])
            idx += n

        self.rk = rks


def h1(tweak: int, h1_keys: List[int], n: int, tau: int) -> List[int]:
    t_bits = int_to_bits(tweak, tau)
    return toeplitz_hash(h1_keys, t_bits, n)


def h2(tweak: int, h2_keys: List[int], n: int, tau: int) -> List[int]:
    t_bits = int_to_bits(tweak, tau)
    return toeplitz_hash(h2_keys, t_bits, n)


def h(tweak: int, h1_keys: List[int], h2_keys: List[int], n: int, tau: int) -> List[int]:
    h1_t = h1(tweak, h1_keys, n, tau)
    h2_t = h2(tweak, h2_keys, n, tau)
    return xor(h1_t, h2_t)


def encrypt(plaintext: List[int], tweak: int, key: KeySchedule, h1_keys: List[int], h2_keys: List[int], a: int, b: int, n: int, tau: int) -> List[int]:
    state = plaintext[:]

    state = xor(state, key.w1)

    # forward rounds (first group)
    for i in range(a):
        state = S(state)
        state = M(state)
        state = xor(state, key.rk[i])

    state = xor(state, h1(tweak, h1_keys, n, tau))

    # forward rounds (second group)
    for i in range(a, a + b):
        state = S(state)
        state = M(state)
        state = xor(state, key.rk[i])

    state = xor(state, h(tweak, h1_keys, h2_keys, n, tau))

    # backward rounds
    for i in reversed(range(a, a + b)):
        state = S(state)
        state = M(state)
        state = xor(state, key.rk[i])

    state = xor(state, h2(tweak, h2_keys, n, tau))

    state = xor(state, key.w2)

    return state


def decrypt(ciphertext: List[int], tweak: int, key: KeySchedule, h1_keys: List[int], h2_keys: List[int], a: int, b: int, n: int, tau: int) -> List[int]:
    state = ciphertext[:]

    state = xor(state, key.w2)

    state = xor(state, h2(tweak, h2_keys, n, tau))

    # reverse backward rounds (encrypt ran i = a+b-1 .. a with S -> M -> xor rk[i])
    for i in range(a, a + b):
        state = xor(state, key.rk[i])
        state = M(state)
        state = S(state)

    state = xor(state, h(tweak, h1_keys, h2_keys, n, tau))

    # reverse second forward group (encrypt ran i = a .. a+b-1 with S -> M -> xor rk[i])
    for i in range(a + b - 1, a - 1, -1):
        state = xor(state, key.rk[i])
        state = M(state)
        state = S(state)

    state = xor(state, h1(tweak, h1_keys, n, tau))

    # reverse first forward group (encrypt ran i = 0 .. a-1 with S -> M -> xor rk[i])
    for i in range(a - 1, -1, -1):
        state = xor(state, key.rk[i])
        state = M(state)
        state = S(state)

    state = xor(state, key.w1)

    return state


if __name__ == "__main__":
    # 15. Validation (required tests)

    # S-Box involution
    for x in range(16):
        assert SBOX[SBOX[x]] == x, f"S-Box involution failed for x={x}"

    # --- Test 1: Original hardcoded vector (Blink-128a) ---
    n = 32
    tau = 128
    a = 3
    b = 3
    n_rounds = a + b

    master = [i % 16 for i in range(2 * n + n_rounds * n)]
    key = KeySchedule(master, n_rounds, n)

    h1_keys = [i % 2 for i in range(n + tau - 1)]
    h2_keys = [(i * 3) % 2 for i in range(n + tau - 1)]

    m = [i % 16 for i in range(n)]
    t = 0xDEADBEEF

    c = encrypt(m, t, key, h1_keys, h2_keys, a, b, n, tau)
    m2 = decrypt(c, t, key, h1_keys, h2_keys, a, b, n, tau)
    assert m == m2, f"Encrypt/Decrypt failed: {m} != {m2}"

    # --- Test 2: Multiple random vectors (Blink-128a) ---
    import random
    for _ in range(100):
        m_rand = [random.randint(0, 15) for _ in range(n)]
        t_rand = random.randint(0, (1 << tau) - 1)
        c_rand = encrypt(m_rand, t_rand, key, h1_keys, h2_keys, a, b, n, tau)
        m2_rand = decrypt(c_rand, t_rand, key, h1_keys, h2_keys, a, b, n, tau)
        assert m_rand == m2_rand, "Random round-trip failed"

    # --- Test 3: Blink-64a variant ---
    n64 = 16
    tau64 = 64
    a64 = 2
    b64 = 3
    n_rounds64 = a64 + b64

    master64 = [i % 16 for i in range(2 * n64 + n_rounds64 * n64)]
    key64 = KeySchedule(master64, n_rounds64, n64)

    h1_keys64 = [i % 2 for i in range(n64 + tau64 - 1)]
    h2_keys64 = [(i * 7 + 1) % 2 for i in range(n64 + tau64 - 1)]

    m64 = [random.randint(0, 15) for _ in range(n64)]
    t64 = random.randint(0, (1 << tau64) - 1)
    c64 = encrypt(m64, t64, key64, h1_keys64, h2_keys64, a64, b64, n64, tau64)
    m64_2 = decrypt(c64, t64, key64, h1_keys64, h2_keys64, a64, b64, n64, tau64)
    assert m64 == m64_2, "Blink-64a round-trip failed"

    print("All tests passed!")
