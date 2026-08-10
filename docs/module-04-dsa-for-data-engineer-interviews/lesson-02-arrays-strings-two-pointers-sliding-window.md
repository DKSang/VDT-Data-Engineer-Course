# Lesson 02 – Arrays, Strings, Two Pointers & Sliding Window

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- reasoning với contiguous ranges trong list/string;
- dùng two pointers khi hai index cùng di chuyển có invariant rõ;
- phân biệt fixed-size và variable-size sliding window;
- dùng prefix accumulation khi cần query tổng/count trên interval;
- tránh nested-loop recomputation trên các window liên tiếp;
- xác định khi sliding window **không** áp dụng vì condition không monotonic.

## 2. Source alignment

### Primary Databricks sources

Không có; lesson này là Supplementary prerequisite.

### Supplementary primary sources

- MIT OCW 6.006 – algorithmic problem solving: https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/
- Python list/string fundamentals: https://docs.python.org/3/tutorial/introduction.html#lists
- Python data structures: https://docs.python.org/3/tutorial/datastructures.html

### Scope note

Patterns vendor-neutral. Liên hệ DE nằm ở time-series windows, ordered event processing và bounded scans; không đồng nhất Python sliding window với Spark window functions.

## 3. Principles

### Principle 1 – Exploit order before adding data structures

Nếu input sorted, nhiều bài pair/search có thể giải bằng hai pointers thay vì hash map hoặc nested loops.

### Principle 2 – Sliding window avoids recomputing overlapping work

Hai window liên tiếp chia sẻ phần lớn dữ liệu. Thay vì tính lại tổng/count từ đầu, update state khi:

```text
right enters
left leaves
```

### Principle 3 – Window correctness depends on monotonic shrink logic

Variable-size sliding window hoạt động tốt khi việc tăng `left` có thể phục hồi condition theo cách predictable.

Ví dụ positive durations và `sum <= limit` có monotonicity.

Nếu values có cả số âm, shrink khi sum quá lớn không còn guarantee đúng.

### Principle 4 – Pointer movement must be globally bounded

Một code có nested `while` vẫn có thể O(n) nếu mỗi pointer chỉ tăng tối đa n lần.

## 4. Fundamentals

### 4.1 Contiguous vs subsequence

- subarray/substring: contiguous;
- subsequence: giữ order nhưng có thể bỏ phần tử.

Sliding window thường dành cho contiguous ranges.

### 4.2 Two pointers – opposite ends

Sorted values, tìm pair sum target:

```python
def has_pair_sum(values, target):
    left = 0
    right = len(values) - 1

    while left < right:
        total = values[left] + values[right]
        if total == target:
            return True
        if total < target:
            left += 1
        else:
            right -= 1
    return False
```

Invariant:

> Dựa trên sorted order, khi total quá nhỏ, bỏ `values[left]` không thể làm mất một pair hợp lệ với bất kỳ right nhỏ hơn hiện tại.

### 4.3 Fast/slow pointers

Dùng khi cần compact/filter in place hoặc detect relations giữa vị trí.

Ví dụ remove duplicates từ sorted list:

```python
def dedup_sorted(values):
    if not values:
        return 0

    write = 1
    for read in range(1, len(values)):
        if values[read] != values[write - 1]:
            values[write] = values[read]
            write += 1
    return write
```

### 4.4 Fixed-size window

Max drops trong k events liên tiếp:

```python
def max_drops_in_k(events, k):
    current = sum(events[:k])
    best = current

    for right in range(k, len(events)):
        current += events[right]
        current -= events[right - k]
        best = max(best, current)
    return best
```

O(n), thay vì O(nk).

### 4.5 Variable-size window

Longest interval có tổng duration <= budget, giả sử durations non-negative:

```python
def longest_under_budget(durations, budget):
    left = 0
    total = 0
    best = 0

    for right, value in enumerate(durations):
        total += value

        while total > budget:
            total -= durations[left]
            left += 1

        best = max(best, right - left + 1)

    return best
```

### 4.6 Sliding-window frequency map

Longest substring không duplicate:

```python
def longest_unique(values):
    last_seen = {}
    left = 0
    best = 0

    for right, value in enumerate(values):
        if value in last_seen and last_seen[value] >= left:
            left = last_seen[value] + 1
        last_seen[value] = right
        best = max(best, right - left + 1)

    return best
```

### 4.7 Prefix sums

Nếu cần trả nhiều range-sum queries trên cùng array:

```python
prefix = [0]
for x in values:
    prefix.append(prefix[-1] + x)

# sum [left, right)
range_sum = prefix[right] - prefix[left]
```

Build O(n), mỗi query O(1).

Prefix sum khác sliding window: prefix phù hợp static multiple interval queries; sliding window phù hợp tìm/duy trì một moving range theo condition.

## 5. Worked example – Longest healthy event window

### Problem

Cho sequence theo thời gian, `1 = error`, `0 = healthy`. Tìm longest contiguous window có tối đa `k` errors.

### Brute force

Enumerate mọi `(left, right)` và count errors: O(n²) hoặc tệ hơn nếu recount.

### Sliding-window insight

Condition:

```text
error_count <= k
```

Khi thêm event làm errors > k, chỉ có cách shrink left cho đến khi condition hợp lệ lại.

```python
def longest_window_at_most_k_errors(flags, k):
    left = 0
    errors = 0
    best = 0

    for right, flag in enumerate(flags):
        errors += flag

        while errors > k:
            errors -= flags[left]
            left += 1

        best = max(best, right - left + 1)

    return best
```

Time O(n): `right` tăng n lần, `left` cũng tối đa n lần.

Space O(1).

### DE interpretation

Đây là algorithmic window trên in-memory ordered sequence. Trong production streaming, window semantics còn liên quan event time, watermark, late data và distributed state — không được đánh đồng hai tầng.

## 6. Hands-on lab

### Core exercises

1. Reverse string/list bằng two pointers.
2. Palindrome check bỏ spaces/case.
3. Pair sum trên sorted list.
4. Remove duplicate từ sorted list in-place.
5. Maximum sum của k numbers liên tiếp.
6. Minimum average latency của k events.
7. Longest substring/list segment không duplicate.
8. Longest window có tối đa k errors.
9. Longest window có tổng duration <= budget, values non-negative.
10. Build prefix sum và trả 10 range queries.

### Telecom challenge – burst detection

Input sorted theo time:

```python
[
  {"ts": 1, "tower": 501, "is_drop": 0},
  {"ts": 2, "tower": 501, "is_drop": 1},
  ...
]
```

Cho riêng một tower, tìm longest run có tối đa 2 drops.

Sau đó trả lời:

- Nếu muốn window theo **5 phút** thay vì “k events”, pointer condition đổi thế nào?
- Nếu input không sorted theo timestamp thì cần làm gì trước?
- Sorting làm complexity thành gì?

### Anti-pattern experiment

Viết brute-force fixed-window sum:

```python
for start in ...:
    sum(values[start:start+k])
```

So với rolling update. Giải thích vì sao slicing/sum lặp lại làm extra work.

### Deliverables

- `lesson-02.py`;
- tests gồm empty, one-element, all-errors, no-errors, k=0;
- notes ghi invariant cho 3 bài.

## 7. Knowledge check – MCQ

**Q1.** Sliding window thường áp dụng cho:  
A. contiguous ranges  
B. arbitrary graph only  
C. sorting implementation only  
D. heap nodes

**Q2.** Fixed window rolling sum giảm O(nk) xuống gần:  
A. O(1) total  
B. O(n)  
C. O(n²)  
D. O(2^n)

**Q3.** Nested `while` trong sliding window vẫn có thể O(n) vì:  
A. compiler xóa loop  
B. left/right mỗi pointer di chuyển tổng cộng bounded bởi n  
C. while luôn O(1)  
D. list lookup O(log n)

**Q4.** Variable sliding window với `sum <= target` dễ reasoning nhất khi values:  
A. non-negative  
B. arbitrary complex numbers  
C. graph nodes  
D. strings only

**Q5.** Prefix sums hữu ích khi:  
A. nhiều range-sum queries trên data tương đối static  
B. cần heap  
C. cần BFS  
D. cần hash collision

**Q6.** Input sorted giúp pair-sum two pointers vì:  
A. order cho phép loại một phía có chứng minh  
B. sort tự tạo hash map  
C. pointers chạy parallel CPU  
D. O(n) biến O(n²)

## 8. Tự luận / Interview

1. Tại sao two pointers có thể O(n) dù có `while` trong `for`?
2. Khi nào hash map pair-sum tốt hơn sorted two-pointers?
3. Fixed-size vs variable-size window khác invariant nào?
4. Vì sao negative values có thể phá simple sum-window reasoning?
5. Prefix sum vs sliding window: chọn theo query pattern nào?
6. Nếu events chưa sorted và cần time window, complexity tối thiểu thêm bước gì?
7. Trong distributed Spark, vì sao không nên hiểu “sliding window O(n)” local như cost model của Spark window operator?

## 9. Exit criteria

- [ ] Viết được two-pointers pair sum không nhìn template.
- [ ] Viết fixed-size rolling window O(n).
- [ ] Viết variable sliding window với invariant rõ.
- [ ] Dùng prefix sum đúng `[left,right)`.
- [ ] Nêu trường hợp sliding window không áp dụng trực tiếp.
- [ ] Đạt >=5/6 MCQ.