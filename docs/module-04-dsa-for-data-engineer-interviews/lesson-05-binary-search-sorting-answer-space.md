# Lesson 05 – Binary Search, Sorting & Search on Answer

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- viết binary search không lỗi boundary phổ biến;
- phân biệt tìm exact value, first true, lower bound và upper bound;
- dùng `bisect` sau khi hiểu invariant;
- nhận diện khi sort trước giúp đơn giản hóa bài toán;
- reasoning về stable sorting và multi-key sort ở mức thực dụng;
- áp dụng binary search trên **answer space** khi có monotonic predicate.

## 2. Source alignment

### Primary Databricks sources

Không có; Supplementary prerequisite.

### Supplementary primary sources

- MIT OCW 6.006 – searching/sorting materials: https://ocw.mit.edu/courses/6-006/introduction-to-algorithms-spring-2008/pages/lecture-notes/
- Python sorting HOWTO: https://docs.python.org/3/howto/sorting.html
- Python `bisect`: https://docs.python.org/3/library/bisect.html

## 3. Principles

### Principle 1 – Binary search requires monotonic structure

Classic case: sorted array.

General case: predicate chuyển từ `False` sang `True` một lần:

```text
False False False True True True
```

Binary search tìm boundary thay vì scan toàn bộ.

### Principle 2 – Define interval convention before coding

Hai style hợp lệ:

```text
[left, right]
[left, right)
```

Sai lầm đến từ trộn conventions.

Module dùng chủ yếu `[left, right)` vì dễ biểu diễn empty interval và `right = len(values)`.

### Principle 3 – Sorting can expose structure

Sort tốn O(n log n), nhưng đổi lại:

- neighboring duplicates;
- two pointers;
- binary search;
- deterministic ordering;
- easier interval reasoning.

O(n log n) có thể tốt hơn O(n²) brute force đáng kể.

### Principle 4 – Search on answer needs a monotonic feasibility test

Nếu với capacity C xử lý được workload, và mọi capacity lớn hơn C cũng xử lý được, predicate `feasible(C)` monotonic → binary search minimum feasible C.

## 4. Fundamentals

### 4.1 Exact binary search

```python
def binary_search(values, target):
    left = 0
    right = len(values)  # exclusive

    while left < right:
        mid = left + (right - left) // 2

        if values[mid] < target:
            left = mid + 1
        else:
            right = mid

    if left < len(values) and values[left] == target:
        return left
    return -1
```

Đây thực chất tìm first index có `value >= target`, rồi kiểm tra equality.

### 4.2 Lower bound

Tìm vị trí đầu tiên `value >= target`:

```python
def lower_bound(values, target):
    left, right = 0, len(values)
    while left < right:
        mid = (left + right) // 2
        if values[mid] < target:
            left = mid + 1
        else:
            right = mid
    return left
```

### 4.3 Upper bound

Tìm vị trí đầu tiên `value > target`:

```python
def upper_bound(values, target):
    left, right = 0, len(values)
    while left < right:
        mid = (left + right) // 2
        if values[mid] <= target:
            left = mid + 1
        else:
            right = mid
    return left
```

Count occurrences trong sorted list:

```text
upper_bound(target) - lower_bound(target)
```

### 4.4 Python bisect

```python
from bisect import bisect_left, bisect_right
```

- `bisect_left`: lower-bound style;
- `bisect_right`: upper-bound style.

Không học API mà bỏ qua semantics.

### 4.5 Sorting by key

```python
events.sort(key=lambda e: (e["event_ts"], e["event_id"]))
```

Multi-key ordering cần tie-breaker khi deterministic order quan trọng.

Python sort là stable, nên records có equal key giữ relative order trước sort.

### 4.6 Search on answer

Problem:

> Có jobs với sizes; cần minimum daily capacity để xử lý trong D days, jobs phải preserve order.

Predicate:

```python
def feasible(capacity):
    days = 1
    used = 0

    for size in jobs:
        if used + size > capacity:
            days += 1
            used = 0
        used += size

    return days <= D
```

Nếu C feasible, mọi C lớn hơn cũng feasible.

Search range:

```text
low  = max(jobs)
high = sum(jobs)
```

Binary search minimum true.

## 5. Worked example – First event at or after timestamp

### Problem

Events sorted theo `event_ts`. Tìm index đầu tiên có timestamp >= query timestamp.

```python
def first_at_or_after(timestamps, target):
    left, right = 0, len(timestamps)

    while left < right:
        mid = (left + right) // 2
        if timestamps[mid] < target:
            left = mid + 1
        else:
            right = mid

    return left
```

Nếu return `len(timestamps)`, không có event nào >= target.

### Invariant

```text
All indices < left are known < target.
Any valid answer remains in [left, right).
```

### DE use

- locate watermark boundary in sorted in-memory batch;
- find first partition/event after time cutoff;
- bisect sorted offsets;
- not a substitute for indexed/distributed query planning.

## 6. Hands-on lab

### Core exercises

1. Exact binary search.
2. Lower bound.
3. Upper bound.
4. Count occurrences in sorted list.
5. First event timestamp >= target.
6. Last event timestamp <= target.
7. Sort transactions by amount desc, then timestamp desc, then id desc.
8. Dedup sorted IDs by neighbor scan.
9. Compare pair-sum: sort+two-pointers vs hash map.
10. Use `bisect_left/right` and verify against own implementation.

### Answer-space challenge – minimum worker capacity

Có partition sizes:

```python
sizes = [8, 5, 10, 4, 6]
```

Cần process theo order trong tối đa `D=3` rounds. Mỗi round total size <= capacity.

Tìm minimum capacity.

Yêu cầu:

- define `feasible(capacity)`;
- prove monotonicity;
- low/high bounds;
- complexity O(n log S), S = sum range magnitude;
- test one job, D=1, D>=n.

### Telecom challenge – timestamp range

Cho sorted event timestamps và `[start,end)`:

- dùng lower bound tìm start index;
- dùng lower bound tìm end index;
- slice corresponding events;
- complexity của searching vs slicing.

Giải thích nếu input chưa sorted thì preprocessing cost gì.

## 7. Knowledge check – MCQ

**Q1.** Binary search cần:  
A. monotonic/sorted structure phù hợp  
B. hash map bắt buộc  
C. graph DAG  
D. random ordering

**Q2.** Lower bound thường trả:  
A. first index value >= target  
B. last index value < target luôn  
C. random occurrence  
D. max value

**Q3.** Với `[left,right)`, initial right thường là:  
A. len(values)  
B. len(values)-1 bắt buộc  
C. 0  
D. target

**Q4.** Sort trước O(n log n) có thể đáng giá nếu thay:  
A. O(n²) repeated searching bằng structured scan/search  
B. O(1) bằng O(n²)  
C. heap bằng graph  
D. memory bằng network

**Q5.** Binary search on answer cần predicate:  
A. monotonic  
B. random  
C. recursive only  
D. constant false

**Q6.** Python stable sort nghĩa là:  
A. equal-key items giữ relative order  
B. O(1) sort  
C. không cần memory  
D. output unique

## 8. Tự luận / Interview

1. Vì sao binary search bug thường đến từ boundary convention?
2. Exact search có thể xây trên lower bound như thế nào?
3. Lower vs upper bound khác gì?
4. Khi nào sort+two-pointer hợp lý hơn hash map?
5. Stable sort hữu ích với multi-stage ordering như thế nào?
6. Thế nào là monotonic feasibility predicate?
7. Search-on-answer khác search trong array ở điểm nào?
8. Nếu event batch 10M rows chưa sorted, binary search có giúp ngay không? Vì sao?

## 9. Exit criteria

- [ ] Viết binary search theo một interval convention nhất quán.
- [ ] Viết lower/upper bound.
- [ ] Dùng bisect sau khi giải thích semantics.
- [ ] Nêu trade-off sort+scan vs hash.
- [ ] Giải một bài binary-search-on-answer có proof monotonicity.
- [ ] Đạt >=5/6 MCQ.