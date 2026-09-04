n = int(input())
sequence1 = list(map(int, input().split()))
assert len(sequence1) == n

m = int(input())
sequence2 = list(map(int, input().split()))
assert len(sequence2) == m

assert 1 <= n <= 1000
assert 1 <= m <= 1000


def greatest_common_sequence(seq1, seq2):
    # dp[j] = length of the common segment
    # ending at seq1[i-1] and seq2[j-1]
    dp = [0] * (len(seq2) + 1)

    best_length = 0
    best_end = 0

    for i in range(1, len(seq1) + 1):
        # Go backwards so that dp[j - 1] still belongs
        # to the previous row.
        for j in range(len(seq2), 0, -1):
            if seq1[i - 1] == seq2[j - 1]:
                dp[j] = dp[j - 1] + 1

                if dp[j] > best_length:
                    best_length = dp[j]
                    best_end = i
            else:
                dp[j] = 0

    return seq1[best_end - best_length:best_end]


result = greatest_common_sequence(sequence1, sequence2)
print(*result)
