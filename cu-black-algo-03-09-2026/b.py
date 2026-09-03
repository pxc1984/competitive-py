mx = 0
for _ in range(int(input())):
    rect = list(map(int, input().split()))
    assert len(rect) == 4
    area = abs(rect[2] - rect[0]) * abs(rect[3] - rect[1])
    mx = max(mx, area)
print(mx)
