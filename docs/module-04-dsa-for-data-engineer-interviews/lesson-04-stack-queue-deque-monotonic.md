# Lesson 04 – Stack, Queue, Deque & Monotonic Reasoning

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- phân biệt LIFO và FIFO semantics;
- dùng `list` làm stack và `collections.deque` làm queue/deque;
- tránh `list.pop(0)` cho queue workloads;
- dùng stack cho parsing/nesting/history;
- dùng queue cho BFS/work scheduling;
- hiểu monotonic stack/deque ở mức pattern nhận biết;
- giải sliding-window maximum bằng deque ở mức interview.

## 2. Source alignment

### Primary Databricks sources

Không có; Supplementary prerequisite.

### Supplementary primary sources

- Python `collections.deque`: https://docs.python.org/3/library/collections.html#collections.deque
- Python standard-library tour (`deque` used for queues/BFS): https://docs.python.org/3/tutorial/stdlib2.html
- MIT 6.006 graph/search materials: https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/resources/lecture-notes/

## 3. Principles

### Principle 1 – Choose a structure that matches removal order

- Stack: item mới nhất được xử lý trước (LIFO).
- Queue: item cũ nhất được xử lý trước (FIFO).
- Deque: push/pop hiệu quả ở cả hai đầu.

### Principle 2 – Queue implementation detail can change complexity

Python list hỗ trợ `pop(0)`, nhưng phải shift remaining elements. `deque.popleft()` phù hợp hơn cho FIFO queue.

### Principle 3 – Stack stores unresolved context

Một stack thường chứa những item chưa được “đóng” hoặc chưa tìm được counterpart:

```text
opening bracket
previous state
pending operator
unresolved next-greater candidate
```

### Principle 4 – Monotonic structures discard dominated candidates

Nếu một candidate chắc chắn không bao giờ hữu ích cho future answer, ta loại nó ngay thay vì giữ toàn bộ window/history.

## 4. Fundamentals

### 4.1 Stack with list

```python
stack = []
stack.append(item)
item = stack.pop()
```

Push/pop cuối list thường amortized O(1).

### 4.2 Queue with deque

```python
from collections import deque

q = deque()
q.append(item)
item = q.popleft()
```

### 4.3 Balanced brackets

```python
def valid_brackets(text):
    pairs = {')': '(', ']': '[', '}': '{'}
    stack = []

    for ch in text:
        if ch in '([{':
            stack.append(ch)
        elif ch in pairs:
            if not stack or stack.pop() != pairs[ch]:
                return False

    return not stack
```

Invariant:

> Stack chứa đúng các opening brackets chưa được matching của prefix đã xử lý.

### 4.4 Queue for work scheduling

```python
from collections import deque

def process(tasks):
    q = deque(tasks)
    while q:
        task = q.popleft()
        ...
```

FIFO phù hợp khi order arrival phải được preserve.

### 4.5 Monotonic stack – next greater idea

Brute force next greater element: mỗi item scan sang phải O(n²).

Stack giữ indices chưa tìm thấy next greater. Khi value mới lớn hơn stack top, ta resolve candidates.

```python
def next_greater(values):
    ans = [-1] * len(values)
    stack = []

    for i, value in enumerate(values):
        while stack and values[stack[-1]] < value:
            j = stack.pop()
            ans[j] = value
        stack.append(i)

    return ans
```

Mỗi index push một lần, pop tối đa một lần → O(n).

### 4.6 Monotonic deque – sliding maximum

Deque giữ indices của candidates theo value decreasing.

Khi right tăng:

1. remove index đã ra khỏi window từ left;
2. remove smaller/equal candidates từ right vì current value mới hơn và không kém hơn;
3. append right;
4. front là max.

```python
from collections import deque

def sliding_max(values, k):
    if k <= 0 or k > len(values):
        return []

    q = deque()
    result = []

    for i, value in enumerate(values):
        while q and q[0] <= i - k:
            q.popleft()

        while q and values[q[-1]] <= value:
            q.pop()

        q.append(i)

        if i >= k - 1:
            result.append(values[q[0]])

    return result
```

Time O(n), extra O(k).

## 5. Worked example – Retry queue with priority awareness

### FIFO baseline

Một pipeline có failed partition IDs cần retry đúng order arrival:

```python
from collections import deque

def retry_order(failures):
    q = deque(failures)
    result = []
    while q:
        result.append(q.popleft())
    return result
```

Nếu requirement đổi thành “severity cao xử lý trước”, queue FIFO không còn đúng semantics; Lesson 06 sẽ dùng heap/priority queue.

### Interview insight

Data structure phải theo policy xử lý, không theo API quen tay.

## 6. Hands-on lab

### Core exercises

1. Implement stack class wrapper bằng list.
2. Valid parentheses/brackets.
3. Remove adjacent duplicates dùng stack.
4. Simulate undo history.
5. FIFO retry queue bằng deque.
6. Moving average queue giữ tối đa k values.
7. Next greater element.
8. Daily latency next-higher-day pattern.
9. Sliding-window maximum bằng deque.
10. Compare runtime behavior `list.pop(0)` vs `deque.popleft()` trên input lớn vừa phải.

### Telecom challenge – rolling peak signal degradation

Cho mỗi minute một integer `error_count`. Trả maximum error count trong mỗi window k phút bằng monotonic deque.

Ví dụ:

```text
errors = [2,1,5,3,6,2]
k = 3
output = [5,5,6,6]
```

Yêu cầu:

- brute-force O(nk);
- optimized O(n);
- invariant của deque;
- test ties;
- test k=1, k=n.

### Concept challenge

Một queue có tasks:

```text
arrival_time
severity
retry_count
```

Nêu khi nào:

- FIFO deque đúng;
- heap đúng;
- hai-level design (priority + FIFO within priority) cần thiết.

## 7. Knowledge check – MCQ

**Q1.** Stack có semantics:  
A. FIFO  
B. LIFO  
C. sorted  
D. random

**Q2.** Queue FIFO trong Python nên ưu tiên:  
A. deque.popleft  
B. list.pop(0) cho mọi scale  
C. set.pop  
D. dict.clear

**Q3.** Monotonic stack có thể O(n) vì:  
A. mỗi item push/pop bounded số lần  
B. while không chạy  
C. sorting hidden  
D. recursion cache

**Q4.** Sliding-window max deque giữ:  
A. mọi values forever  
B. candidate indices có thứ tự giá trị monotonic  
C. hash buckets  
D. tree parent pointers

**Q5.** Valid-parentheses stack lưu:  
A. unresolved opening brackets  
B. all closed brackets only  
C. frequencies  
D. sorted tokens

**Q6.** Nếu priority phải quyết định processing order, FIFO queue:  
A. luôn đủ  
B. có thể không phù hợp  
C. tự chuyển thành heap  
D. có O(1) priority lookup tự động

## 8. Tự luận / Interview

1. Vì sao `deque` phù hợp queue hơn list trong Python?
2. Stack invariant của valid-parentheses là gì?
3. Monotonic stack loại candidate dựa trên logic nào?
4. Vì sao sliding-window max không cần sort mỗi window?
5. Queue vs heap khác nhau về scheduling semantics thế nào?
6. Một Data Engineer có thể gặp queue abstraction ở đâu trong system design dù không trực tiếp code `deque`?
7. Khi monotonic stack/deque là overkill so với simple scan?

## 9. Exit criteria

- [ ] Dùng stack/queue đúng LIFO/FIFO.
- [ ] Không dùng `pop(0)` như default queue implementation.
- [ ] Viết valid brackets.
- [ ] Giải thích amortized O(n) của monotonic stack/deque pattern.
- [ ] Viết sliding maximum hoặc mô tả invariant chính xác.
- [ ] Đạt >=5/6 MCQ.