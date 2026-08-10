# Module 06 – Practice Set

> Mọi bài từ P09 trở đi phải ghi `Business process`, `Fact grain`, `History rule` và ít nhất một validation.

## Level 1 – Process, Grain & Facts

### P01
Cho requirement “daily successful revenue by province”, xác định business process, detailed fact grain và aggregate result grain.

### P02
Giải thích vì sao `customer` không phải business process.

### P03
Thiết kế transaction fact cho billing.

### P04
Thiết kế periodic snapshot cho active subscriptions/day.

### P05
Thiết kế accumulating snapshot cho subscription onboarding.

### P06
Phân loại: amount, balance, drop_rate, transaction_count thành additive/semi/non-additive.

### P07
Cho `drop_rate`, viết numerator/denominator đúng để aggregate nhiều towers.

### P08
Tìm một mixed-grain anti-pattern trong schema tự tạo và giải thích double-count risk.

## Level 2 – Dimensions & Star Schema

### P09
Thiết kế `dim_customer` gồm natural key, surrogate key và unknown member.

### P10
Thiết kế `dim_plan` và giải thích current catalog price khác actual billed amount.

### P11
Tạo `dim_date` cho năm 2026.

### P12
Dùng `dim_date` dưới hai roles: transaction date và activation date.

### P13
Thiết kế billing star schema đầy đủ.

### P14
Thiết kế network-quality star schema ở event grain.

### P15
Thiết kế network daily aggregate fact ở tower/day grain.

### P16
Reconcile event fact với daily aggregate fact.

### P17
So sánh star vs snowflake cho tower → province → region.

### P18
Nêu trường hợp một identifier nên là degenerate dimension.

## Level 3 – SCD & History

### P19
Implement SCD1 cho một plan attribute.

### P20
Build SCD2 customer dimension from `silver.customer_history`.

### P21
Check one-current-row/business key.

### P22
Check SCD2 overlapping intervals.

### P23
Point-in-time map billing transaction to customer version.

### P24
Show why joining billing to `is_current=true` customer can rewrite historical segmentation.

### P25
Handle early-arriving fact `customer_id=9999` using unknown member.

### P26
Design inferred-member alternative to P25.

### P27
Simulate backdated segment change and list fact rows requiring re-evaluation.

### P28
Explain event/effective time vs ingestion time in SCD history.

## Level 4 – Conformed Dimensions & Multiple Marts

### P29
Build bus matrix for Billing, Subscription and Network.

### P30
Define conformance contract for `dim_date`.

### P31
Define conformance contract for `dim_customer`.

### P32
Explain customer province vs tower province semantic roles.

### P33
Design a shared geography dimension or justify keeping role-specific geography attributes.

### P34
Calculate daily ARPU by province without raw fact-to-fact join.

### P35
Show an example where raw fact-to-fact join fans out.

### P36
Design a bridge for customer ↔ campaigns and explain measure allocation risk.

## Level 5 – Databricks Incremental Loading

### P37
Pre-dedup staged customer changes with `QUALIFY ROW_NUMBER`.

### P38
Implement SCD1 `MERGE` for `dim_plan`.

### P39
Write pseudo-flow for SCD2 close-old + insert-new.

### P40
Describe equivalent AUTO CDC configuration: keys, sequence, delete rule, SCD mode.

### P41
Map Silver billing natural keys to Gold surrogate keys.

### P42
MERGE billing fact by transaction_id and prove rerun does not duplicate.

### P43
Create monitoring for unknown-customer fact count and amount.

### P44
Design late-fact overlap/reprocessing strategy.

### P45
Explain why delete signal still needs analytical delete semantics.

## Level 6 – Gold Serving & Quality

### P46
Build Gold Finance query: daily revenue by province/segment/plan.

### P47
Build Gold Network query: drop rate/tower/day from additive components.

### P48
Create 12-check Gold validation suite.

### P49
Design a monthly revenue aggregate and document grain/source/reconciliation.

### P50 – VDT-style dimensional modeling case

Requirement:

> A telecom company wants one governed analytics platform. Finance needs transaction-level revenue and historical customer segmentation. Network Operations needs daily tower drop rate. Executives need daily ARPU by province. Source systems can update customer attributes late and network events can arrive out of order.

Deliver:

1. Medallion architecture placement.
2. Silver assets.
3. Gold facts/dimensions.
4. Grain of every fact.
5. Measure additivity table.
6. Customer SCD policy.
7. Unknown/late-arriving policy.
8. Bus matrix.
9. Incremental load strategy.
10. Databricks `MERGE`/AUTO CDC placement.
11. 10+ validation checks.
12. Explain ARPU without fact-to-fact fan-out.
13. Explain one performance optimization and its correctness risk.
14. Give a 5-minute architecture defense.

## Completion rubric

- 30/50: basic warehouse vocabulary usable.
- 40/50: ready to proceed, review SCD/conformance misses.
- 45+/50: strong fresher-level warehouse foundation.

A problem does **not** count as complete when only SQL works but grain/history/reconciliation cannot be explained.
