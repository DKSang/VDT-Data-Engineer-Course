# Lesson 05 – Slowly Changing Dimensions & Late-Arriving Data

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- phân biệt SCD Type 1 và Type 2 theo business requirement;
- hiểu Type 0/3 ở mức awareness nhưng không lạm dụng taxonomy;
- thiết kế validity intervals không overlap;
- map fact vào đúng dimension version tại event time;
- xử lý early-arriving fact / late-arriving dimension;
- giải thích late-arriving correction khác ingestion-time ordering;
- liên hệ SCD với Databricks AUTO CDC/history tracking.

## 2. Source alignment

### Primary Databricks sources

- Lakeflow Connect history tracking / SCD: https://docs.databricks.com/aws/en/ingestion/lakeflow-connect/scd
- ETL in Databricks SQL / AUTO CDC: https://docs.databricks.com/aws/en/sql/get-started/sql-etl-tutorial
- Lakeflow Declarative Pipelines CDC tutorial: https://docs.databricks.com/aws/en/ldp/tutorial-pipelines
- Delta `MERGE`: https://docs.databricks.com/aws/en/delta/merge

### Databricks semantics

Current Databricks history tracking distinguishes SCD Type 1 (latest state overwrite) and SCD Type 2 (retain change history). AUTO CDC can declaratively sequence changes and store SCD Type 1/2 outputs, including out-of-order changes when sequencing information is valid.

### Scope note

Validity interval design, surrogate keys and point-in-time fact joins are vendor-neutral dimensional-modeling fundamentals.

## 3. Principles

### Principle 1 – Choose history behavior from the business question

Do not choose SCD2 because it is “more advanced”.

Ask:

> Should historical facts be reported with the attribute value at event time or with today’s value?

### Principle 2 – Effective time and ingestion time are different

A customer segment change effective on Aug 1 may arrive Aug 5.

For historical reporting, the effective date can matter more than ingestion order.

### Principle 3 – SCD2 requires non-overlapping validity for each business key

For one customer:

```text
[2026-01-01, 2026-06-01)
[2026-06-01, infinity)
```

Intervals must not overlap if facts need deterministic point-in-time mapping.

### Principle 4 – Late data needs repair logic, not hope

A pipeline must define what happens when:

- a fact arrives before its dimension;
- a dimension correction arrives late;
- history is backdated;
- an old fact must be remapped.

## 4. Fundamentals

### 4.1 SCD Type 0 – retain original

Attribute never changes after initial load.

Use only when business semantics truly require immutable original value.

### 4.2 SCD Type 1 – overwrite current

Example:

```text
customer_id = 1001
province = Ha Noi
```

Correction:

```text
province = Hanoi
```

Old value disappears.

Good for correction/current-state attributes where historical value is not needed.

### 4.3 SCD Type 2 – add version

```text
customer_key | customer_id | segment | effective_from | effective_to | is_current
101          | 1001        | mass    | 2026-01-01     | 2026-06-01   | false
205          | 1001        | premium | 2026-06-01     | NULL         | true
```

Fact event at 2026-03-15 → key 101.  
Fact event at 2026-07-10 → key 205.

### 4.4 Type 3 awareness

Stores limited previous/current values in columns.

Example:

```text
current_segment
previous_segment
```

Useful for very limited history; not a replacement for full Type 2 history.

### 4.5 Point-in-time join

Concept:

```sql
fact.customer_id = dim.customer_id
AND fact.event_ts >= dim.effective_from
AND fact.event_ts < COALESCE(dim.effective_to, TIMESTAMP '9999-12-31')
```

The result should match at most one dimension version/fact row.

### 4.6 Early-arriving fact

Fact arrives for customer not yet in dimension.

Options:

1. map to unknown surrogate key and repair later;
2. create inferred/minimal dimension member;
3. hold fact temporarily if latency allows.

Choice depends on SLA and governance.

### 4.7 Late-arriving dimension correction

Suppose on Aug 10 we learn that segment changed effective Aug 3, not Aug 10.

Then SCD2 history may need:

- closing previous version at Aug 3;
- inserting new version effective Aug 3;
- remapping facts from Aug 3 onward if their surrogate keys were assigned using old history.

This is a **historical repair**, not just insert-new-current-row.

### 4.8 AUTO CDC awareness

Databricks AUTO CDC accepts:

- business keys;
- sequencing column/expression;
- delete behavior;
- SCD storage mode.

This reduces procedural merge complexity, but correct sequencing semantics are still a source-data contract requirement.

## 5. Worked example – Segment changes

Events:

```text
2026-01-01 customer 1001 segment=mass
2026-08-10 record arrives: segment=premium effective 2026-08-05
```

Billing facts:

```text
Aug 04 transaction A
Aug 06 transaction B
```

Desired reporting:

```text
A → mass version
B → premium version
```

If dimension version were created with `effective_from = ingestion_date Aug 10`, B would be reported incorrectly.

Lesson: source sequencing/effective-time contract controls historical truth.

## 6. Hands-on lab

### Part A – SCD1

For `dim_plan`, decide one attribute to treat as Type 1 correction. Write before/after rows.

### Part B – SCD2

For `dim_customer.segment`:

1. build two versions/customer;
2. close old version;
3. insert new version;
4. validate only one current row;
5. validate no overlapping intervals.

### Part C – Point-in-time mapping

Map billing transactions to customer version by transaction timestamp.

Validation:

```text
rows after mapping = fact rows before mapping
max matches per fact = 1
orphan/unknown rate explicit
```

### Part D – Early-arriving fact

Simulate transaction for customer 9999.

Choose:

- unknown key;
- inferred member;
- holding area.

Explain SLA trade-off.

### Part E – Late backdated change

A segment correction arrives today but is effective three days ago.

Write the repair steps and list which facts must be re-evaluated.

## 7. Knowledge check – MCQ

**Q1.** SCD1 usually:  
A. overwrites previous value; B. stores all versions; C. creates fact; D. means snapshot fact.

**Q2.** SCD2 usually:  
A. retains historical versions; B. deletes history; C. removes surrogate keys; D. means raw ingestion.

**Q3.** For historical truth, dimension version selection often needs:  
A. effective-time semantics; B. only ingestion order; C. only file name; D. only warehouse size.

**Q4.** SCD2 intervals for same business key should generally:  
A. overlap freely; B. not overlap; C. all be NULL; D. use no dates.

**Q5.** Early-arriving fact can be handled with:  
A. explicit unknown/inferred strategy; B. random surrogate key; C. deleting business event always; D. no policy.

**Q6.** AUTO CDC removes the need to define:  
A. business key and sequence semantics; B. some procedural merge code; C. target SCD mode; D. delete semantics.

Correct answer for Q6: **B**.

## 8. Tự luận / Interview

1. SCD1 vs SCD2: what business question decides the choice?
2. Why can ingestion time create historically wrong reporting?
3. How do you validate a Type 2 dimension?
4. What is an early-arriving fact?
5. How would you repair a backdated dimension change?
6. What problem does AUTO CDC solve and what source contract does it still require?

## 9. Exit criteria

- [ ] Build SCD1 and SCD2 examples.
- [ ] Validate one-current-row + no-overlap rules.
- [ ] Point-in-time map facts deterministically.
- [ ] Define late-data repair strategy.
- [ ] Score >=5/6 MCQ.
