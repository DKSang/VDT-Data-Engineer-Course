# Lesson 01 – Complexity, Constraints & Problem-Solving Invariants

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- giải thích Big-O, Big-Theta ở mức interview thực dụng;
- phân tích time/space complexity của loop, nested loop và common Python operations;
- dùng input constraints để loại solution không khả thi;
- phân biệt worst-case, average/expected behavior ở mức cần thiết;
- mô tả invariant trước khi code;
- bắt đầu từ brute force rồi tối ưu bottleneck có chủ đích;
- tránh tối ưu vi mô trước khi sửa algorithmic complexity.

## 2. Source alignment

### Primary Databricks sources

Không có primary Databricks source cho DSA. Đây là **Supplementary prerequisite**.

### Supplementary primary sources

- MIT OCW 6.006 – Introduction to Algorithms: https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/
- MIT 6.006 lecture notes: https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/resources/lecture-notes/
- Python data structures: https://docs.python.org/3/tutorial/datastructures.html

### Scope note

- Complexity/invariant là vendor-neutral CS fundamentals.
- Liên hệ Databricks chỉ ở mental model: local complexity awareness giúp tránh các pattern nguy hiểm như collect dữ liệu lớn về driver và xử lý bằng nested Python loops.

## 3. Principles

### Principle 1 – Constraints choose the family of algorithms

Nếu `n = 100`, O(n²) có thể hoàn toàn ổn.

Nếu `n = 10^7`, O(n²) gần như chắc chắn không khả thi.

Đừng hỏi “algorithm nào hay nhất?” trước khi biết:

```text
n là bao nhiêu?
input đã sorted chưa?
memory limit?
stream hay batch?
cần exact hay approximate?
```

### Principle 2 – Big-O models growth, not stopwatch time

O(n) không có nghĩa luôn nhanh hơn O(log n) trong mọi input nhỏ. Big-O mô tả cách work tăng theo input size, bỏ qua constants/lower-order terms để reasoning về scale.

### Principle 3 – Brute force is a reasoning tool

Brute force giúp xác định:

- solution đúng đơn giản nhất;
- bottleneck nằm ở đâu;
- operation nào đang bị lặp lại;
- data structure nào có thể cache/index state.

Sai lầm là **submit brute force mà không đánh giá complexity**, không phải việc nghĩ ra brute force.

### Principle 4 – Invariant is the contract that stays true while the algorithm runs

Ví dụ sliding window:

> Window hiện tại luôn chứa các phần tử từ `left` đến `right`, và sau khi shrink, window luôn thỏa condition X.

Nếu không nói được điều gì luôn đúng trong loop, code thường biến thành trial-and-error.

## 4. Fundamentals

### 4.1 Asymptotic notation

Ở module này, dùng chủ yếu:

- O(1): constant;
- O(log n): logarithmic;
- O(n): linear;
- O(n log n): sorting-class complexity;
- O(n²): pairwise/nested scan;
- O(2^n), O(n!): combinatorial explosion.

Mental ranking:

```text
1 < log n < n < n log n < n² < 2^n < n!
```

### 4.2 Multiple sequential loops

```python
for x in data:
    ...

for x in data:
    ...
```

O(n) + O(n) = O(n), không phải O(n²).

### 4.3 Nested loops

```python
for i in range(n):
    for j in range(n):
        ...
```

O(n²).

Nhưng nested syntax không tự động nghĩa O(n²). Nếu inner pointer chỉ tăng tổng cộng n lần trong toàn algorithm, two-pointers có thể vẫn O(n).

### 4.4 Space complexity

Ví dụ frequency map:

```python
freq = {}
for x in values:
    freq[x] = freq.get(x, 0) + 1
```

Time: expected O(n).

Extra space: O(k), với `k` là số distinct keys, worst-case O(n).

### 4.5 Common practical operations

Dùng mental model thay vì học thuộc bảng tuyệt đối:

- list index access: O(1);
- append list: amortized O(1);
- membership `x in list`: O(n);
- membership `x in set`: expected O(1);
- dict lookup: expected O(1);
- sorting n items: O(n log n);
- `pop(0)` trên list: O(n) vì shift;
- queue FIFO nên ưu tiên `collections.deque`.

### 4.6 Input-size heuristics

Không phải luật cứng, nhưng khi phỏng vấn có thể reasoning sơ bộ:

```text
n <= 20       -> exponential đôi khi có thể
n <= 1,000    -> O(n²) đôi khi chấp nhận
n <= 100,000  -> thường cần O(n log n) hoặc O(n)
n rất lớn     -> scan tuyến tính / streaming / bounded-memory thinking
```

Luôn phụ thuộc time limit, language và constant factors.

### 4.7 Worst-case vs expected

Python dict/set dùng hashing; lookup thường được reasoning là expected O(1), không phải mathematical guarantee O(1) cho mọi adversarial case.

Trong interview fresher, nói “expected O(1) average lookup” là đủ chính xác hơn “always O(1)”.

### 4.8 Correctness invariant

Ví dụ tìm duplicate bằng set:

```python
def has_duplicate(values):
    seen = set()
    for x in values:
        if x in seen:
            return True
        seen.add(x)
    return False
```

Invariant trước mỗi iteration:

> `seen` chứa đúng các values đã xuất hiện trước vị trí hiện tại.

Do đó nếu `x in seen`, ta đã chứng minh x từng xuất hiện.

## 5. Worked example – Duplicate event IDs

### Problem

Cho list `event_ids`, trả `True` nếu có event id xuất hiện ít nhất hai lần.

### Brute force

```python
def has_duplicate_bruteforce(event_ids):
    n = len(event_ids)
    for i in range(n):
        for j in range(i + 1, n):
            if event_ids[i] == event_ids[j]:
                return True
    return False
```

Time O(n²), extra space O(1).

### Bottleneck

Mỗi event phải so với nhiều event đã thấy trước đó.

Ta đang hỏi lặp đi lặp lại:

> “ID này đã từng xuất hiện chưa?”

Đây là lookup problem.

### Optimized

```python
def has_duplicate(event_ids):
    seen = set()
    for event_id in event_ids:
        if event_id in seen:
            return True
        seen.add(event_id)
    return False
```

Expected time O(n), extra space O(n) worst case.

### Trade-off

Ta đổi memory lấy lookup speed.

Nếu input là stream cực lớn và memory không đủ giữ mọi key, bài toán production có thể cần partitioning, external state, probabilistic structure hoặc distributed state — nhưng đó nằm ngoài DSA interview scope hiện tại.

## 6. Hands-on lab

### Nhiệm vụ

1. Phân tích complexity cho 10 snippets tự viết, gồm:
   - 1 loop;
   - 2 sequential loops;
   - nested loop;
   - loop + dict lookup;
   - sort + scan;
   - list membership trong loop.
2. Viết `has_duplicate_bruteforce` và `has_duplicate`.
3. Generate input 1k, 5k, 10k, đo runtime tương đối; không dùng benchmark nhỏ để tuyên bố universal law.
4. Viết function `count_pairs_equal(values)` brute force, sau đó tìm cách dùng frequency counts để giảm work.
5. Với mỗi function, ghi:

```text
Input size variable:
Time complexity:
Extra space:
Invariant:
Edge cases:
```

### Telecom challenge

Cho list events dạng:

```python
{"event_id": "e1", "tower_id": 501}
```

Tìm tower đầu tiên có duplicate `event_id` trong chính tower đó.

Yêu cầu:

- brute-force idea;
- optimized state;
- complexity theo số events `n`;
- giải thích key nên là `event_id` hay `(tower_id, event_id)` tùy data contract.

### Deliverables

- `lesson-01.py`;
- `lesson-01-tests.py`;
- `lesson-01-notes.md`.

## 7. Knowledge check – MCQ

**Q1.** Hai loop tuần tự, mỗi loop scan n phần tử, có Big-O nào?  
A. O(n²)  
B. O(2n²)  
C. O(n)  
D. O(log n)

**Q2.** `x in some_list` trong loop n lần có worst practical form thường gần:  
A. O(1)  
B. O(log n)  
C. O(n) total  
D. O(n²)

**Q3.** Hash set được dùng trong duplicate detection chủ yếu để đổi:  
A. CPU thành network  
B. memory lấy expected faster lookup  
C. O(n) thành O(n²)  
D. sorting thành recursion

**Q4.** Invariant là:  
A. biến không bao giờ đổi  
B. property luôn đúng tại các điểm xác định trong algorithm  
C. unit test cuối cùng  
D. Big-O constant

**Q5.** Sorting rồi scan duplicate thường là:  
A. O(n log n) time  
B. O(1) time  
C. O(2^n)  
D. O(n!)

**Q6.** Brute force hữu ích nhất khi:  
A. dùng để hiểu correctness và bottleneck trước optimization  
B. luôn submit  
C. bỏ qua constraints  
D. thay thế test cases

## 8. Knowledge check – Tự luận / Interview

1. Big-O giúp bạn ra quyết định gì mà stopwatch không giúp tốt?
2. Vì sao nested loop syntax chưa đủ để kết luận O(n²)?
3. Expected O(1) của hash table nghĩa là gì?
4. Khi nào O(n²) vẫn là solution hợp lý?
5. Invariant của two-pointer algorithm thường mô tả điều gì?
6. Tại sao “sort trước” đôi khi là optimization dù sorting tốn O(n log n)?
7. Nếu memory limit rất thấp, hash-set duplicate solution có trade-off gì?
8. Cho n = 10^6, bạn sẽ nghi ngờ solution nào trước: O(n), O(n log n), O(n²)? Vì sao?

## 9. Exit criteria

- [ ] Phân tích đúng complexity của các pattern cơ bản.
- [ ] Không nhầm sequential loops với nested loops.
- [ ] Giải thích expected vs worst-case hashing.
- [ ] Viết duplicate detection O(n) expected-time.
- [ ] Nói được invariant trước khi code ít nhất 3 bài.
- [ ] Luôn hỏi constraints trước optimization.
- [ ] Đạt ít nhất 5/6 MCQ.