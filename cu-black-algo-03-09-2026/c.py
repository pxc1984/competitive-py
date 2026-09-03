n = int(input())
keyboard = list(map(int, input().split()))
assert len(keyboard) == n

k = int(input())
seq = input().split()
assert len(seq) == k

for p in map(int, seq):
    keyboard[p-1]-=1
for key in keyboard:
    print("no" if key >= 0 else "yes")
