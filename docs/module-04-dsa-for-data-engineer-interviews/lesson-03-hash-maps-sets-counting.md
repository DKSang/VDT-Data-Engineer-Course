# Lesson 03 – Hash Maps, Sets & Counting Patterns

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- chọn `set` khi chỉ cần membership/uniqueness;
- chọn `dict` khi cần key → state/value;
- dùng frequency maps cho counting/grouping;
- giải pair/complement problems bằng hashing;
- phân biệt first-seen/latest-seen semantics;
- nhận diện memory trade-off của hashing;
- giải thích expected O(1) lookup mà không tuyên bố absolute O(1).

## 2. Source alignment

### Primary Databricks sources

Không có; Supplementary prerequisite.

### Supplementary primary sources

- MIT 6.006 – Hashing topics: https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2008/pages/lecture-notes/
- Python dictionaries/sets: https://docs.python.org/3/tutorial/datastructures.html
- Python `collections.Counter`: https://docs.python.org/3/library/collections.html#collections.Counter
- Python `defaultdict`: https://docs.python.org/3/library/collections.html#collections.defaultdict

## 3. Principles

### Principle 1 – Hashing indexes state by a key

Câu hỏi quan trọng nhất:

> “Tôi cần tra cứu thông tin nào bằng key nào?”

Ví dụ:

```text
event_id -> latest version
customer_id -> revenue
value -> previous index
province -> count
```

### Principle 2 – Key design is part of correctness

`event_id` và `(tower_id, event_id)` không tương đương. Key phải phản ánh definition of sameness.

### Principle 3 – A set is a dict-shaped idea without associated payload

Nếu chỉ cần “đã thấy chưa?”, `set` truyền đạt intent tốt hơn `dict[key] = True`.

### Principle 4 – Hashing trades memory for avoiding repeated scans

Common transformation:

```text
nested lookup O(n²)
        ↓
build hash state O(n)
        ↓
expected O(1) lookup per item
```

## 4. Fundamentals

### 4.1 Set patterns

Duplicate detection:

```python
seen = set()
for x in values:
    if x in seen:
        ...
    seen.add(x)
```

Intersection:

```python
common = set(a) & set(b)
```

### 4.2 Frequency map

```python
freq = {}
for value in values:
    freq[value] = freq.get(value, 0) + 1
```

Hoặc:

```python
from collections import Counter
freq = Counter(values)
```

Trong interview, hiểu pattern quan trọng hơn API shortcut.

### 4.3 Group-by-in-memory pattern

```python
from collections import defaultdict

groups = defaultdict(list)
for event in events:
    groups[event["tower_id"]].append(event)
```

Cẩn thận memory: group toàn bộ raw events có thể không phù hợp nếu dataset lớn.

### 4.4 Complement lookup – Two Sum pattern

```python
def two_sum(values, target):
    seen = {}

    for i, value in enumerate(values):
        need = target - value
        if need in seen:
            return seen[need], i
        seen[value] = i

    return None
```

Invariant:

> `seen` chứa value → index của các phần tử trước current index.

### 4.5 First-seen vs last-seen

Nếu:

```python
positions[value] = i
```

mỗi lần gặp, ta giữ latest index.

Nếu cần first occurrence:

```python
if value not in positions:
    positions[value] = i
```

Đây là semantics, không phải style preference.

### 4.6 Composite keys

```python
key = (event["tower_id"], event["event_id"])
```

Tuple immutable có thể dùng làm dict/set key nếu các thành phần hashable.

### 4.7 Counting vs dedup

Frequency map trả số lần xuất hiện.

Set chỉ biết membership.

Nếu requirement cần:

```text
first duplicate
most frequent
exact count
```

set có thể không đủ state.

## 5. Worked example – Latest payload version per event

### Requirement

Mỗi `event_id` có nhiều versions. Giữ event có `payload_version` lớn nhất; nếu tie, `ingested_at` mới nhất.

### State design

```text
key   = event_id
value = current winning event
```

```python
def latest_events(events):
    winners = {}

    for event in events:
        key = event["event_id"]
        current = winners.get(key)

        if current is None:
            winners[key] = event
            continue

        candidate_rank = (event["payload_version"], event["ingested_at"])
        current_rank = (current["payload_version"], current["ingested_at"])

        if candidate_rank > current_rank:
            winners[key] = event

    return list(winners.values())
```

Expected time O(n), extra state O(k) unique event IDs.

### Correctness invariant

Sau khi xử lý prefix `events[:i]`:

> Với mỗi event_id đã thấy, `winners[event_id]` là winner tốt nhất trong prefix theo rank rule.

## 6. Hands-on lab

### Core exercises

1. Frequency count của customer IDs.
2. First repeated value.
3. First non-repeated value.
4. Intersection của hai customer sets.
5. Two Sum.
6. Group transactions by customer.
7. Most frequent tower.
8. Count event types/tower bằng composite key.
9. Latest index của mỗi event ID.
10. First index của mỗi event ID.

### Telecom challenge – duplicate taxonomy

Cho events có:

```text
same event_id + same payload
same event_id + newer version
same event_id + same version + later ingestion
```

Tạo output:

```python
{
  "event_id": {
    "count": ...,
    "max_version": ...,
    "winner": ...
  }
}
```

Giải thích:

- khi nào chỉ `set` đủ;
- khi nào cần `dict`;
- key nào đại diện business event;
- space complexity theo số distinct IDs.

### Challenge – join-like lookup

Có:

```python
customers = [{"customer_id": 1, "province": "HN"}, ...]
transactions = [{"customer_id": 1, "amount": 100}, ...]
```

Viết nested-loop join trước, sau đó build:

```text
customer_id -> customer
```

và enrich transactions trong expected O(n + m).

Liên hệ với hash join mental model nhưng không khẳng định database/Spark implementation giống Python dict.

## 7. Knowledge check – MCQ

**Q1.** Nếu chỉ cần membership, cấu trúc biểu đạt intent tốt nhất thường là:  
A. set  
B. list-of-lists  
C. heap  
D. recursion

**Q2.** Frequency map dùng để:  
A. key → count  
B. sorted range only  
C. BFS queue  
D. binary search tree bắt buộc

**Q3.** Hash lookup trong interview thường reasoning là:  
A. expected O(1)  
B. always mathematical O(1)  
C. O(n!)  
D. O(log log n) guaranteed

**Q4.** Composite key hữu ích khi:  
A. uniqueness phụ thuộc nhiều fields  
B. cần recursion  
C. muốn giảm key semantics  
D. chỉ có one integer

**Q5.** `dict[value] = i` mọi lần gặp giữ:  
A. latest assigned index  
B. first index bắt buộc  
C. all indexes  
D. sorted index

**Q6.** Hash-join-like enrichment có thể giảm nested O(nm) xuống expected:  
A. O(n+m)  
B. O(nm²)  
C. O(2^n)  
D. O(1) total

## 8. Tự luận / Interview

1. Set vs dict khác nhau về intent/state thế nào?
2. Vì sao key design ảnh hưởng correctness của dedup?
3. First-seen vs last-seen dùng trong business rules nào?
4. Memory cost của hashing là gì?
5. Two Sum hash solution có invariant nào?
6. Tại sao Python dict lookup không nên mô tả là “always O(1)”?
7. Khi data không fit memory, hash-map local solution gợi ý vấn đề gì cho production design?
8. Hash-based enrichment local liên hệ thế nào với join reasoning của Module 02?

## 9. Exit criteria

- [ ] Dùng đúng set/dict theo requirement.
- [ ] Viết frequency map không nhìn template.
- [ ] Giải Two Sum expected O(n).
- [ ] Thiết kế composite key đúng semantics.
- [ ] Viết latest-version state machine O(n).
- [ ] Giải thích memory trade-off.
- [ ] Đạt >=5/6 MCQ.