# Module 06 Final Assessment – Data Warehouse & Dimensional Modeling

> Không xem `answers/module-06-final-solutions.md` trước khi hoàn thành.

## Quy định

- Primary platform context: Databricks SQL / Delta / medallion architecture.
- Suggested time: **180 minutes**.
- Mọi fact design phải có explicit grain.
- Mọi historical dimension phải có effective-time rule.
- SQL chạy được nhưng grain/history/additivity sai không đạt full score.

---

# Part A – Fundamentals (20 points)

1 point/question.

1. Dimensional design should begin with: A business process; B index; C dashboard; D surrogate key.
2. Grain means: A meaning of one fact row; B file size; C warehouse size; D catalog name.
3. One row/logical transaction is: A transaction fact; B periodic snapshot; C dimension; D bridge.
4. One row/subscription/day is: A periodic snapshot; B transaction fact; C SCD1; D role dimension.
5. Accumulating snapshot fits: A milestone lifecycle; B only static master data; C raw files; D Python logs.
6. Transaction amount is commonly: A additive; B semi-additive only; C non-additive; D dimension.
7. Daily account balance is commonly: A semi-additive; B fully additive across time; C no measure; D surrogate key.
8. Drop rate should normally aggregate using: A summed numerator / summed denominator; B sum percentages; C max only; D average blindly.
9. Natural key represents: A source/business identity; B warehouse version only; C SQL warehouse; D file version.
10. Surrogate key is useful for: A historical dimension versions; B replacing all business rules; C removing grain; D ACID only.
11. Same dimension used as order date and ship date is: A role-playing; B factless; C junk fact; D CDC.
12. SCD1: A overwrite current value; B preserve full row history; C fact aggregate; D query profile.
13. SCD2: A preserve historical versions; B overwrite only; C no dates; D append facts only.
14. Conformed dimension provides: A shared semantics across marts; B automatic performance; C Python type checking; D transaction lock.
15. Bus matrix rows commonly represent: A business processes/facts; B source files; C indexes; D warehouses.
16. Raw fact-to-fact join at different grains risks: A fan-out; B automatic conformance; C SCD repair; D no issue.
17. Gold on Databricks can contain: A dimensional marts/aggregates; B raw only; C no business logic; D only ML.
18. `MERGE` automatically chooses correct winner among ambiguous duplicate source business keys: A true; B false.
19. AUTO CDC still requires meaningful: A keys/sequence semantics; B dashboard theme; C Python virtualenv; D B-tree.
20. Informational PK/FK on Databricks means: A pipeline still validates integrity; B enforcement is guaranteed; C duplicates impossible; D dimensions unnecessary.

---

# Part B – Dimensional Design (40 points)

## B1 – Billing star (12 points)

Requirement:

> Finance wants daily successful revenue and transaction count by customer province, historical customer segment and plan type, with transaction drill-through.

Deliver:

1. business process;
2. fact grain;
3. fact table columns;
4. dimensions;
5. natural/surrogate keys;
6. measure additivity;
7. customer-history rule;
8. five validations.

## B2 – Network quality (10 points)

Requirement:

> NOC wants daily call-drop rate by tower/province/technology and drill-through to event detail when investigating incidents.

Design:

- detailed fact;
- daily aggregate fact;
- numerator/denominator;
- reconciliation;
- why average-of-rates can be wrong.

## B3 – Subscription lifecycle (8 points)

Compare:

- transaction/event fact;
- periodic daily snapshot;
- accumulating snapshot.

For each, state one business question it supports naturally.

## B4 – Bus matrix & cross-process KPI (10 points)

Create bus matrix for Billing / Subscription / Network.

Then design:

> daily ARPU by province = successful revenue / active subscribers

without raw fact-to-fact fan-out.

---

# Part C – History, Late Data & Incremental Loading (25 points)

## C1 – SCD2 customer (10 points)

Customer 1001:

```text
mass until 2026-08-05
premium from 2026-08-05
```

Transactions:

```text
T1 2026-08-04
T2 2026-08-06
```

Design:

- two dimension versions;
- surrogate keys;
- validity intervals;
- point-in-time mapping for T1/T2;
- one-current-row validation;
- overlap validation.

## C2 – Early-arriving fact (5 points)

Transaction arrives for customer 9999 before dimension member.

Compare:

- unknown member;
- inferred member;
- hold/retry.

Choose one for dashboard SLA <5 minutes and explain repair.

## C3 – Backdated change (5 points)

On Aug 10, source sends a segment change effective Aug 7.

Explain:

- why ingestion-time-only SCD is wrong;
- history repair;
- fact re-evaluation interval.

## C4 – Databricks incremental flow (5 points)

Design Silver→Gold incremental loading using:

- source pre-dedup;
- `MERGE` or AUTO CDC;
- source key/sequence;
- retry/idempotency;
- delete semantics.

---

# Part D – Databricks Serving & Interview Defense (15 points)

## D1 – Medallion placement (5 points)

Explain where these belong and why:

```text
raw CDC
clean integrated customer history
fact_billing_transaction
dim_customer
monthly revenue aggregate
```

## D2 – Gold quality gate (5 points)

List 10 checks required before BI consumes Finance Gold.

## D3 – Oral defense (5 points)

In <=5 minutes defend the telecom warehouse:

```text
Source → Bronze → Silver → Gold Finance/Network/Subscriber
```

Must cover:

- grain;
- facts/dimensions;
- SCD;
- conformance;
- late data;
- incremental load;
- validation;
- one conscious trade-off.

---

# Rubric

| Part | Points |
|---|---:|
| A – Fundamentals | 20 |
| B – Dimensional Design | 40 |
| C – History & Incremental | 25 |
| D – Databricks Serving | 15 |
| **Total** | **100** |

## Pass criteria

- >= **75/100** total.
- Part B >= **30/40**.
- Cannot pass while confusing:
  - business process vs dimension entity;
  - fact grain;
  - additive vs semi/non-additive;
  - natural vs surrogate key;
  - SCD1 vs SCD2;
  - current dimension vs point-in-time dimension mapping;
  - raw fact-to-fact join vs common-grain aggregation.

## Strong pass

>=85/100 and can complete D3 without notes.
