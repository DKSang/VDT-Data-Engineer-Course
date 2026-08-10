# Lesson 06 – Heaps, Top-K & Priority Processing

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- giải thích min-heap invariant;
- dùng `heapq` cho top-K và priority queue;
- phân biệt sort toàn bộ O(n log n) với heap top-K O(n log k);
- xử lý tuples `(priority, tie_breaker, payload)` đúng semantics;
- merge nhiều sorted streams/batches bằng heap ở mức interview;
- chọn heap khi chỉ cần phần tử tốt nhất/k phần tử tốt nhất, không cần full ordering.

## 2. Source alignment

### Primary Databricks sources

Không có; Supplementary prerequisite.

### Supplementary primary sources

- MIT 6.006 heap/sorting materials: https://ocw.mit.edu/courses/6-006/introduction-to-algorithms-spring-2020/resources/lecture-notes/
- Python `heapq`: https://docs.python.org/3/library/heapq.html
- Python standard-library tour: https://docs.python.org/3/tutorial/stdlib2.html

## 3. Principles

### Principle 1 – A heap gives partial order, not full sort

Min-heap guarantee:

> root là phần tử nhỏ nhất theo ordering.

Nó không guarantee toàn array/list heap đã sorted.

### Principle 2 – Top-K does not require sorting everything

Nếu `k << n`, sort toàn bộ làm nhiều work hơn cần thiết.

Maintain heap size k:

```text
n items × O(log k)
```

### Principle 3 – Priority queue requires explicit tie semantics

Nếu hai tasks cùng priority, Python có thể cần tie-breaker để tránh compare payload không orderable hoặc để preserve deterministic policy.

### Principle 4 – Heap is useful when the next best item changes dynamically

Ví dụ:

- retry task có severity cao nhất;
- merge k sorted streams;
- keep top noisy towers;
- scheduler xử lý earliest deadline.

## 4. Fundamentals

### 4.1 Python min-heap

```python
import heapq

heap = []
heapq.heappush(heap, 5)
heapq.heappush(heap, 2)
heapq.heappush(heap, 8)

smallest = heapq.heappop(heap)  # 2
```

### 4.2 Heapify

```python
heapq.heapify(values)
```

Build heap from list in linear-time heap construction at algorithmic level.

### 4.3 Top-K largest with min-heap size k

```python
import heapq

def top_k_largest(values, k):
    if k <= 0:
        return []

    heap = []
    for value in values:
        if len(heap) < k:
            heapq.heappush(heap, value)
        elif value > heap[0]:
            heapq.heapreplace(heap, value)

    return sorted(heap, reverse=True)
```

Processing O(n log k), final sort O(k log k).

### 4.4 Priority tuples

```python
heapq.heappush(heap, (priority, sequence, task))
```

Tuple compare lexicographically:

1. priority;
2. sequence tie-breaker;
3. payload only reached if prior fields tie.

Nếu smaller numeric priority phải nghĩa “higher priority”, encode policy rõ. Nếu severity lớn hơn phải ưu tiên, có thể push negative severity.

### 4.5 K-way merge

Có k sorted event lists. Push first item của mỗi list; pop smallest; push next from same list.

```python
import heapq

def merge_sorted(streams):
    heap = []
    result = []

    for stream_id, stream in enumerate(streams):
        if stream:
            heapq.heappush(heap, (stream[0], stream_id, 0))

    while heap:
        value, stream_id, index = heapq.heappop(heap)
        result.append(value)

        next_index = index + 1
        if next_index < len(streams[stream_id]):
            heapq.heappush(
                heap,
                (streams[stream_id][next_index], stream_id, next_index),
            )

    return result
```

Heap size <= k; time O(N log k) với N tổng items.

## 5. Worked example – Top-K noisy towers

Input:

```python
tower_errors = {
    501: 12,
    502: 3,
    503: 25,
    504: 10,
    505: 18,
}
```

Requirement: top 3 towers theo error count.

### Full sort

```python
sorted(tower_errors.items(), key=lambda x: x[1], reverse=True)[:3]
```

O(n log n).

### Heap size 3

```python
import heapq

def top_k_towers(counts, k):
    heap = []

    for tower_id, count in counts.items():
        item = (count, tower_id)
        if len(heap) < k:
            heapq.heappush(heap, item)
        elif item > heap[0]:
            heapq.heapreplace(heap, item)

    return sorted(heap, reverse=True)
```

O(n log k).

### Tie semantics

Tuple `(count, tower_id)` làm tower_id lớn hơn thắng khi equal count. Nếu business muốn tower_id nhỏ hơn thắng, ordering phải đổi. Tie-breaker không được accidental.

## 6. Hands-on lab

### Core exercises

1. Min-heap push/pop.
2. K smallest values.
3. K largest values.
4. Top-K frequent event types sau frequency map.
5. Priority queue `(severity, arrival_order)`.
6. Earliest-deadline processing.
7. Merge 2 sorted lists bằng pointers; sau đó merge k lists bằng heap.
8. Find kth largest element bằng heap size k.
9. Compare full sort vs heap top-K complexity.
10. Explain why heap internal array is not fully sorted.

### Telecom challenge – incident scheduler

Incidents:

```python
{
  "incident_id": "i-1",
  "severity": 5,
  "created_at": 100,
  "tower_id": 501
}
```

Policy:

1. severity cao hơn trước;
2. nếu tie severity, created_at sớm hơn trước;
3. nếu vẫn tie, incident_id lexical để deterministic.

Implement priority queue và return processing order.

Yêu cầu ghi tuple key chính xác và giải thích dấu âm nếu dùng min-heap.

### Merge challenge – sorted event partitions

Có k partitions đã sorted theo event timestamp. Merge thành một sorted sequence, không concatenate rồi sort toàn bộ.

Trả lời:

- heap chứa state gì?
- heap size tối đa?
- complexity?
- nếu một partition không sorted thì assumption nào bị phá?

## 7. Knowledge check – MCQ

**Q1.** Python `heapq` mặc định là:  
A. min-heap  
B. max-heap only  
C. sorted list  
D. hash table

**Q2.** Root của min-heap là:  
A. minimum item theo ordering  
B. maximum always  
C. median  
D. random

**Q3.** Top-K với heap size k có processing complexity thường:  
A. O(n log k)  
B. O(n²)  
C. O(k^n)  
D. O(1)

**Q4.** Heap internal storage:  
A. không cần fully sorted  
B. luôn descending  
C. hash bucket  
D. linked list bắt buộc

**Q5.** K-way merge heap size tối đa gần:  
A. k  
B. N  
C. N²  
D. 1 bắt buộc

**Q6.** Tie-breaker trong priority tuple giúp:  
A. deterministic comparison/policy  
B. giảm mọi algorithm xuống O(1)  
C. tạo hash  
D. remove duplicates tự động

## 8. Tự luận / Interview

1. Heap khác sorted list thế nào?
2. Khi `k` gần `n`, lợi thế heap top-K so với full sort thay đổi ra sao?
3. Vì sao priority queue thường cần tie-breaker?
4. K-way merge giữ những gì trong heap?
5. Nếu dữ liệu arrive online và cần top-K current, heap phù hợp ở điểm nào?
6. Full sort vẫn tốt hơn heap khi requirement nào?
7. Trong distributed top-K, local heap insight có thể được dùng ở local aggregation stage thế nào về mặt concept, nhưng vì sao không đủ mô tả Spark execution?

## 9. Exit criteria

- [ ] Dùng `heapq` đúng min-heap semantics.
- [ ] Viết top-K O(n log k).
- [ ] Thiết kế deterministic priority tuple.
- [ ] Giải thích k-way merge O(N log k).
- [ ] Không nhầm heap với fully sorted container.
- [ ] Đạt >=5/6 MCQ.