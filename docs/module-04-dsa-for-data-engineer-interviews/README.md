# Module 04 – DSA for Data Engineer Interviews

> **Classification:** Supplementary prerequisite. Databricks does not use DSA as a primary platform-learning track; this module exists to build algorithmic reasoning for Data Engineering coding tests and interviews.

## Source alignment

### Databricks relationship

Databricks remains the backbone of the overall course, but this module is intentionally vendor-neutral. The connection back to Databricks is indirect: better complexity reasoning helps you understand why local Python solutions do not automatically scale to Spark, why driver-side collections are dangerous, and why algorithm/data-structure choice matters before distributed execution.

### Supplementary primary sources

- MIT OpenCourseWare – 6.006 Introduction to Algorithms: https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/
- MIT 6.006 lecture notes: https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/resources/lecture-notes/
- Python Data Structures: https://docs.python.org/3/tutorial/datastructures.html
- Python `collections.deque`: https://docs.python.org/3/library/collections.html#collections.deque
- Python `heapq`: https://docs.python.org/3/library/heapq.html
- Python `bisect`: https://docs.python.org/3/library/bisect.html

## Mục tiêu

Module này không nhằm biến bạn thành competitive programmer. Sau khi hoàn thành, bạn phải có thể:

- phân tích time/space complexity ở mức interview;
- chọn list/dict/set/deque/heap theo access pattern;
- nhận diện các pattern array/string phổ biến;
- dùng hashing để đổi bài toán O(n²) thành O(n) expected-time khi phù hợp;
- dùng two pointers, sliding window và prefix accumulation;
- dùng stack/queue/deque cho parsing, streaming-window và traversal;
- giải binary search trên sorted data và binary search trên answer space;
- dùng heap cho top-K / priority processing;
- hiểu linked list/tree/graph ở mức đủ để BFS/DFS;
- viết code đúng, có test cases, giải thích invariant và edge cases;
- hoàn thành coding test dưới time pressure mà không lao vào code trước khi xác định constraints.

## Scope

### Bắt buộc

- Big-O / asymptotic reasoning;
- array/string;
- hash map/set;
- two pointers;
- sliding window;
- prefix sum/counter;
- stack/queue/deque;
- binary search;
- sorting reasoning;
- heap / priority queue;
- linked-list awareness;
- tree traversal;
- BFS/DFS;
- coding-test workflow.

### Chỉ awareness

- balanced BST internals;
- union-find;
- shortest paths;
- topological sort;
- dynamic programming.

Các chủ đề awareness có thể xuất hiện ở interview, nhưng không phải trọng tâm pass criteria của Module 04.

## Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm |
|---|---|---|
| 01 | Complexity, Constraints & Problem-Solving Invariants | Làm sao biết solution có scale đủ trước khi code? |
| 02 | Arrays, Strings, Two Pointers & Sliding Window | Khi nào một scan tuyến tính thay thế nested loop? |
| 03 | Hash Maps, Sets & Counting Patterns | Khi nào memory đổi lấy lookup nhanh hơn? |
| 04 | Stack, Queue, Deque & Monotonic Reasoning | Khi nào cần LIFO/FIFO và state theo thứ tự? |
| 05 | Binary Search, Sorting & Search on Answer | Làm sao khai thác monotonicity/sorted order? |
| 06 | Heap & Top-K / Priority Patterns | Khi không cần sort toàn bộ, giữ K phần tử tốt nhất thế nào? |
| 07 | Linked Lists, Trees, BFS & DFS | Làm sao reasoning trên cấu trúc liên kết/hierarchy/graph? |
| 08 | DE Coding Patterns, Mock Interview & Communication | Làm sao biến DSA thành kỹ năng thi/phỏng vấn thực tế? |

## Case study xuyên suốt

Các bài coding dùng domain telecom/data pipeline giả lập thay vì chỉ `nums = [1,2,3]`:

- duplicate event detection;
- latest event/version tracking;
- rolling error windows;
- top-K noisy towers;
- merge sorted batches;
- find timestamp boundary;
- dependency traversal;
- retry queue;
- detect cycle trong pipeline dependencies;
- memory-safe counters.

Mục tiêu là thấy một DSA pattern có thể xuất hiện dưới ngôn ngữ Data Engineering như thế nào.

## Quy trình giải mọi coding problem

Trước khi code, bắt buộc viết hoặc nói:

```text
1. Input / output là gì?
2. Constraints là gì?
3. Edge cases?
4. Brute force là gì và complexity?
5. Bottleneck của brute force?
6. Data structure / invariant nào loại bottleneck?
7. Target time / space complexity?
8. Test cases trước khi submit?
```

Sau khi code:

```text
9. Dry-run một case nhỏ.
10. Test empty / one-element / duplicates / boundary.
11. Nói lại correctness invariant.
12. Nói complexity.
```

## Lab structure

```text
labs/module-04-dsa/
├── README.md
└── practice-set.md
```

Không cung cấp starter implementation cho mọi bài. Mục tiêu là tự viết function signatures và tests.

## Suggested pace

| Tuần | Nội dung |
|---|---|
| 1 | Lesson 01–02 + 12 bài easy/medium |
| 2 | Lesson 03–04 + 12 bài hash/stack/queue |
| 3 | Lesson 05–06 + 12 bài binary-search/heap |
| 4 | Lesson 07–08 + mock tests + Final Assessment |

## Completion target

Không cần chạy theo số lượng LeetCode. Một target hợp lý của module là **40–60 bài được chọn theo pattern**, nhưng mỗi bài phải có:

- brute-force reasoning;
- optimized invariant;
- time/space complexity;
- ít nhất 3 test cases;
- verbal explanation.

> **Pattern recognition without correctness reasoning is memorization. Correctness without complexity awareness does not scale.**