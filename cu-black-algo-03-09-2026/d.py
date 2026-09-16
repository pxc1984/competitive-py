_f = input().split()
assert len(_f) == 2
n, m = list(map(int, _f))

sorted_arr = list(map(int, input().split()))
assert len(sorted_arr) == n
sequence = list(map(int, input().split()))
assert len(sequence) == m

arr_unique = []
arr_unique_count = []
for i in sorted_arr:
    if len(arr_unique) > 0 and arr_unique[-1] == i:
        arr_unique_count[-1] += 1
    else:
        arr_unique.append(i)
        arr_unique_count.append(1)
arr_unique_count_prefix_sum = [0]
for i in arr_unique_count:
    arr_unique_count_prefix_sum.append(arr_unique_count_prefix_sum[-1] + i)


def find_index_binsearch(number: int, arr: list[int]) -> int:
    l, r = 0, len(arr)
    middle = l + (r - l) // 2
    if number > arr[-1] or number < arr[0]:
        return -1
    while arr[middle] != number and r > l:
        if number < arr[middle]:
            r = middle
        else:
            l = middle
        middle = l + (r - l) // 2
    if r < l:
        return -1
    return middle

for i in sequence:
    index = find_index_binsearch(i, arr_unique)
    if index == -1:
        print(0)
        continue
    print(arr_unique_count_prefix_sum[index] + 1, arr_unique_count_prefix_sum[index] + arr_unique_count[index])
