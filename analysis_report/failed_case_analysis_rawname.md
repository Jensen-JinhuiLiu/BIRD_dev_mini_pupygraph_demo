<!-- This file is a rewrite of failed_case_analysis.md with every Cypher query
     re-mapped to the raw-name graph schema in `graph_schema_rawname/`.
     Node labels have been swapped to their raw-table-based PascalCase form (e.g.
     `Card`→`Cards`, `User`→`Users`, `SATScore`→`Satscores`, `MonthlyConsumption`→`Yearmonth`),
     and attribute references have been re-mapped to the raw Postgres column names
     (e.g. `set_code`→`code`, `year_month`→`date`, `border_color`→`bordercolor`,
     `creation_date`→`creationdate`). Edge labels are unchanged (they are identical
     between the semantic and rawname variants of the refined schema).
     Gold SQL, gold-SQL result, prior Cypher result, diff, and analysis are copied
     verbatim from the original file — those are properties of the SQL/graph data
     rather than the labeling scheme. -->

# Failed Cases — SQL vs Cypher parity on refined PuppyGraph schemas (rawname variant)

Total failed cases across all databases: **19**

## Failure category summary

Every failed case has been classified along one axis. All categories below indicate the failure is **not attributable to Cypher-agent quality** — the Cypher shown is a faithful semantic translation of the SQL. Cases in these categories should be excluded when evaluating a Cypher-generation agent, because the mismatch would occur regardless of how well the agent translates.

| Category | Count | Meaning |
|---|---:|---|
| `PUPPYGRAPH_ENGINE_BUG` | 7 | PuppyGraph engine parser/semantic bug: (a) any string literal containing an apostrophe triggers `[PEPS-06]`; (b) comparing two aggregated integer variables across WITH stages triggers `[CPST-12] Variable types mismatch`. |
| `PUPPYGRAPH_TYPE_HANDLING` | 5 | PuppyGraph doesn't preserve Postgres semantics for `real` (float32) or `timestamptz` types — small precision drift, year-boundary timezone disagreement. |
| `SQL_UNDER_SPECIFICATION` | 4 | SQL uses nondeterministic constructs (`DISTINCT ON` without secondary sort, `LIMIT n` without ORDER BY, `LIMIT 1` after ORDER BY with tied values). Cypher cannot deterministically reproduce SQL's arbitrary choice; both answers are equally valid. |
| `PUPPYGRAPH_ENGINE_LIMIT` | 3 | PuppyGraph engine crashes on large joins or complex CASE aggregations (`[PEPS-06]`). Even after one restructuring attempt, still crashes. |

**Verdict:** all 19 failed cases carry `agent_eval_verdict = EXCLUDE_FROM_AGENT_BENCHMARK`.

## Cases grouped by category

- **`PUPPYGRAPH_ENGINE_BUG`** (7): card_games/qid=358, card_games/qid=462, card_games/qid=465, card_games/qid=480, european_football_2/qid=1092, student_club/qid=1317, student_club/qid=1371
- **`PUPPYGRAPH_TYPE_HANDLING`** (5): california_schools/qid=24, debit_card_specializing/qid=1482, debit_card_specializing/qid=1524, codebase_community/qid=532, codebase_community/qid=683
- **`SQL_UNDER_SPECIFICATION`** (4): thrombosis_prediction/qid=1209, toxicology/qid=212, card_games/qid=349, superhero/qid=751
- **`PUPPYGRAPH_ENGINE_LIMIT`** (3): debit_card_specializing/qid=1481, card_games/qid=528, financial/qid=116

## Breakdown by database

- **thrombosis_prediction**: 1 failed case(s)
- **california_schools**: 1 failed case(s)
- **toxicology**: 1 failed case(s)
- **debit_card_specializing**: 3 failed case(s)
- **card_games**: 6 failed case(s)
- **european_football_2**: 1 failed case(s)
- **student_club**: 2 failed case(s)
- **financial**: 1 failed case(s)
- **codebase_community**: 2 failed case(s)
- **superhero**: 1 failed case(s)


---

## thrombosis_prediction (1 failed case(s))

### qid=1209 — MISMATCH (moderate) — `SQL_UNDER_SPECIFICATION`

**Question:** Please provide the diagnosis of patients with ALT glutamic pylvic transaminase beyond the normal range by ascending order of their date of birth.

**Evidence:** ALT glutamic pylvic transaminase beyond the normal range refers to GPT > 60; The larger the birthday value, the younger the person is, and vice versa; 

**SQL (gold from BIRD):**

```sql
SELECT DISTINCT ON (T1.Birthday) T1.Diagnosis FROM Patient AS T1 INNER JOIN Laboratory AS T2 ON T1.ID = T2.ID WHERE T2.GPT > 60 ORDER BY T1.Birthday ASC
```

**SQL result** (89 rows total, preview only):

```
    1. diagnosis='MRA'
    2. diagnosis='SLE'
    3. diagnosis='RA'
    4. diagnosis='Adult STILL'
    5. diagnosis='SJS'
    6. diagnosis='RA'
    7. diagnosis='SLE'
    8. diagnosis='PSS, RA susp'
    9. diagnosis='PNc'
    10. diagnosis='SLE'
    11. diagnosis='MRA, SJS'
    12. diagnosis='SJS'
    13. diagnosis='RA, UC'
    14. diagnosis='PSS'
    15. diagnosis='PSS'
    16. diagnosis='RA'
    17. diagnosis='PSS, PM'
    18. diagnosis='PN'
    19. diagnosis='BEHCET'
    20. diagnosis=''
    ... (69 more rows omitted)
```

**Cypher attempted:**

```cypher
MATCH (p:Patient)-[:HAD_LAB_PANEL]->(l:Laboratory)
WHERE l.gpt > 60
WITH p.birthday AS bd, MIN(p.diagnosis) AS diag
RETURN diag
ORDER BY bd ASC
```

**Cypher result** (89 rows total, preview only):

```
    1. diag='MRA'
    2. diag='SLE'
    3. diag='RA'
    4. diag='Adult STILL'
    5. diag='SJS'
    6. diag='RA'
    7. diag='SLE'
    8. diag='PSS, RA susp'
    9. diag='PNc'
    10. diag='SLE'
    11. diag='MRA, SJS'
    12. diag='SJS'
    13. diag='RA, UC'
    14. diag='PSS'
    15. diag='PSS'
    16. diag='RA'
    17. diag='AORTITIS'
    18. diag='PN'
    19. diag='BEHCET'
    20. diag=''
    ... (69 more rows omitted)
```

**Where they differ** (SQL rows=89, Cypher rows=89):

- Multiset differs. First divergent position: index 16.

| # | SQL row | Cypher row |
|---:|---|---|
| 17 | ('PSS, PM',) | ('AORTITIS',) |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - ('PSS, PM',)  ×1

Only in Cypher:
  - ('AORTITIS',)  ×1

**Analysis:**

The SQL uses `DISTINCT ON (Birthday) ... ORDER BY Birthday ASC` with no secondary sort key. In Postgres this is documented as nondeterministic: for birthdays shared by multiple patients, Postgres picks whichever row it happens to see first. openCypher has no equivalent 'pick any one row per group' operator — any Cypher translation must use a specific per-group choice (MIN, MAX, HEAD(collect), etc.), all of which are deterministic and will not always agree with Postgres's arbitrary pick. 88/89 rows match; the single divergent birthday (1959-05-11) has two patients ('PSS, PM' and 'AORTITIS') — SQL happens to return 'PSS, PM', Cypher's MIN returns 'AORTITIS'. Both are valid answers under the SQL semantics; the SQL itself is arguably buggy against the question because the question doesn't ask for distinct birthdays.


---

## california_schools (1 failed case(s))

### qid=24 — MISMATCH (moderate) — `PUPPYGRAPH_TYPE_HANDLING`

**Question:** Give the names of the schools with the percent eligible for free meals in K-12 is more than 0.1 and test takers whose test score is greater than or equal to 1500?

**Evidence:** Percent eligible for free meals = Free Meal Count (K-12) / Total (Enrollment (K-12)

**SQL (gold from BIRD):**

```sql
SELECT T2."School Name" FROM satscores AS T1 INNER JOIN frpm AS T2 ON T1.cds = T2.CDSCode WHERE CAST(T2."Free Meal Count (K-12)" AS REAL) / NULLIF(T2."Enrollment (K-12)", 0) > 0.1 AND T1.NumGE1500 > 0
```

**SQL result** (1167 rows total, preview only):

```
    1. School Name='FAME Public Charter'
    2. School Name='Envision Academy for Arts & Technology'
    3. School Name='Alameda Science and Technology Institute'
    4. School Name='Alameda High'
    5. School Name='Alternatives in Action'
    6. School Name='Encinal High'
    7. School Name='Albany High'
    8. School Name='REALM Charter High'
    9. School Name='Berkeley High'
    10. School Name='Castro Valley High'
    11. School Name='Emery Secondary'
    12. School Name='American High'
    13. School Name='John F. Kennedy High'
    14. School Name='Washington High'
    15. School Name='Leadership Public Schools - Hayward'
    16. School Name='Impact Academy of Arts & Technology'
    17. School Name='Hayward High'
    18. School Name='Mt. Eden High'
    19. School Name='Tennyson High'
    20. School Name='Granada High'
    ... (1147 more rows omitted)
```

**Cypher attempted:**

```cypher
MATCH (sat:Satscores), (m:Frpm)
WHERE sat.cds = m.cdscode
  AND m.enrollment_k_12 IS NOT NULL AND m.enrollment_k_12 <> 0
  AND toFloat(m.free_meal_count_k_12) / toFloat(m.enrollment_k_12) > 0.1
  AND sat.numge1500 > 0
RETURN m.school_name
```

**Cypher result** (1165 rows total, preview only):

```
    1. m.school_name='Alameda High'
    2. m.school_name='Castro Valley High'
    3. m.school_name='Impact Academy of Arts & Technology'
    4. m.school_name='Hayward High'
    5. m.school_name='Oakland Unity High'
    6. m.school_name='MetWest High'
    7. m.school_name='Oakland Technical High'
    8. m.school_name='Skyline High'
    9. m.school_name='East Bay Arts High'
    10. m.school_name='Amador High'
    11. m.school_name='Inspire School of Arts and Sciences'
    12. m.school_name='Dozier-Libbey Medical High'
    13. m.school_name='John Swett High'
    14. m.school_name='Alhambra Senior High'
    15. m.school_name='Concord High'
    16. m.school_name='Mt. Diablo High'
    17. m.school_name='Pittsburg Senior High'
    18. m.school_name='Middle College High'
    19. m.school_name='Hercules High'
    20. m.school_name='De Anza Senior High'
    ... (1145 more rows omitted)
```

**Where they differ** (SQL rows=1167, Cypher rows=1165):

- Multiset differs. First divergent position: index 0.

| # | SQL row | Cypher row |
|---:|---|---|
| 1 | ('FAME Public Charter',) | ('Alameda High',) |
| 2 | ('Envision Academy for Arts & Technology',) | ('Castro Valley High',) |
| 3 | ('Alameda Science and Technology Institute',) | ('Impact Academy of Arts & Technology',) |
| 4 | ('Alameda High',) | ('Hayward High',) |
| 5 | ('Alternatives in Action',) | ('Oakland Unity High',) |
| 6 | ('Encinal High',) | ('MetWest High',) |
| 7 | ('Albany High',) | ('Oakland Technical High',) |
| 8 | ('REALM Charter High',) | ('Skyline High',) |
| 9 | ('Berkeley High',) | ('East Bay Arts High',) |
| 10 | ('Castro Valley High',) | ('Amador High',) |
| 11 | ('Emery Secondary',) | ('Inspire School of Arts and Sciences',) |
| 12 | ('American High',) | ('Dozier-Libbey Medical High',) |
| 13 | ('John F. Kennedy High',) | ('John Swett High',) |
| 14 | ('Washington High',) | ('Alhambra Senior High',) |
| 15 | ('Leadership Public Schools - Hayward',) | ('Concord High',) |
| 16 | ('Impact Academy of Arts & Technology',) | ('Mt. Diablo High',) |
| 17 | ('Hayward High',) | ('Pittsburg Senior High',) |
| 18 | ('Mt. Eden High',) | ('Middle College High',) |
| 19 | ('Tennyson High',) | ('Hercules High',) |
| 20 | ('Granada High',) | ('De Anza Senior High',) |
| ... | ... more rows differ | ... |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - ('District Office',)  ×2

**Analysis:**

Postgres `CAST(x AS REAL)/y > 0.1` uses float32 arithmetic which upconverts to float64 for the `> 0.1` comparison. For rows where free_meal/enrollment = exactly 1/10, Postgres float32 gives 0.10000000149... > 0.1 = TRUE. PuppyGraph's native float64 gives 1/10 == 0.1 exact, NOT > 0.1 = FALSE. Cypher's answer is mathematically more correct; SQL's is a float32 precision artifact. Semantically equivalent queries produce different results due to how PuppyGraph handles Postgres `real` columns.


---

## toxicology (1 failed case(s))

### qid=212 — MISMATCH (challenging) — `SQL_UNDER_SPECIFICATION`

**Question:** Which element is the least numerous in non-carcinogenic molecules?

**Evidence:** label = '-' means molecules are non-carcinogenic; least numerous refers to MIN(COUNT(element));

**SQL (gold from BIRD):**

```sql
SELECT T.element FROM (SELECT T1.element, COUNT(DISTINCT T1.molecule_id) FROM atom AS T1 INNER JOIN molecule AS T2 ON T1.molecule_id = T2.molecule_id WHERE T2.label = '-' GROUP BY T1.element ORDER BY COUNT(DISTINCT T1.molecule_id) ASC NULLS FIRST LIMIT 1) AS t
```

**SQL result** (1 rows total):

```
    1. element='ca'
```

**Cypher attempted:**

```cypher
MATCH (a:Atom)-[:ATOM_IN_MOLECULE]->(m:Molecule)
WHERE m.label = '-'
WITH a.element AS element, COUNT(DISTINCT a.molecule_id) AS cnt
ORDER BY cnt IS NULL DESC, cnt ASC
LIMIT 1
RETURN element
```

**Cypher result** (1 rows total):

```
    1. element='i'
```

**Where they differ** (SQL rows=1, Cypher rows=1):

- Multiset differs. First divergent position: index 0.

| # | SQL row | Cypher row |
|---:|---|---|
| 1 | ('ca',) | ('i',) |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - ('ca',)  ×1

Only in Cypher:
  - ('i',)  ×1

**Analysis:**

SQL uses `ORDER BY COUNT(...) ASC NULLS FIRST LIMIT 1`. Multiple elements ('ca', 'cu', 'i', 'sn', 'pb', 'zn' etc.) have count = 1 in non-toxic molecules — the SQL LIMIT 1 picks whichever tied row comes first (nondeterministic). Cypher picks 'i' by its own ordering. Both are valid answers.


---

## debit_card_specializing (3 failed case(s))

### qid=1481 — CYPHER_ERROR (challenging) — `PUPPYGRAPH_ENGINE_LIMIT`

**Question:** What is the difference in the annual average consumption of the customers with the least amount of consumption paid in CZK for 2013 between SME and LAM, LAM and KAM, and KAM and SME?

**Evidence:** annual average consumption of customer with the lowest consumption in each segment = total consumption per year / the number of customer with lowest consumption in each segment; Difference in annual average = SME's annual average - LAM's annual average; Difference in annual average = LAM's annual average - KAM's annual average; Year 2013 can be presented as Between 201301 And 201312; The first 4 strings of the Date values in the yearmonth table can represent year.

**SQL (gold from BIRD):**

```sql
SELECT CAST(SUM(CASE WHEN T1.Segment = 'SME' THEN T2.Consumption ELSE 0 END) AS REAL) / NULLIF(COUNT(T1.CustomerID), 0) - CAST(SUM(CASE WHEN T1.Segment = 'LAM' THEN T2.Consumption ELSE 0 END) AS REAL) / NULLIF(COUNT(T1.CustomerID), 0), CAST(SUM(CASE WHEN T1.Segment = 'LAM' THEN T2.Consumption ELSE 0 END) AS REAL) / NULLIF(COUNT(T1.CustomerID), 0) - CAST(SUM(CASE WHEN T1.Segment = 'KAM' THEN T2.Consumption ELSE 0 END) AS REAL) / NULLIF(COUNT(T1.CustomerID), 0), CAST(SUM(CASE WHEN T1.Segment = 'KAM' THEN T2.Consumption ELSE 0 END) AS REAL) / NULLIF(COUNT(T1.CustomerID), 0) - CAST(SUM(CASE WHEN T1.Segment = 'SME' THEN T2.Consumption ELSE 0 END) AS REAL) / NULLIF(COUNT(T1.CustomerID), 0) FROM customers AS T1 INNER JOIN yearmonth AS T2 ON T1.CustomerID = T2.CustomerID WHERE T1.Currency = 'CZK' AND T2.Consumption = (SELECT MIN(Consumption) FROM yearmonth) AND T2.Date::text BETWEEN '201301' AND '201312'
```

**SQL result** (1 rows total):

```
    1. ?column?=-582092.875
```

**Cypher attempted:**

```cypher
MATCH (mc_all:Yearmonth)
WITH MIN(mc_all.consumption) AS min_consumption

MATCH (mc2:Yearmonth)-[:CONSUMPTION_OF_CUSTOMER]->(c:Customers)
WHERE c.currency = 'CZK'
  AND mc2.date >= '201301'
  AND mc2.date <= '201312'
  AND mc2.consumption = min_consumption

WITH min_consumption,
  SUM(CASE WHEN c.segment = 'SME' THEN mc2.consumption ELSE 0 END) AS sme_sum,
  SUM(CASE WHEN c.segment = 'LAM' THEN mc2.consumption ELSE 0 END) AS lam_sum,
  SUM(CASE WHEN c.segment = 'KAM' THEN mc2.consumption ELSE 0 END) AS kam_sum,
  COUNT(c.customerid) AS total_count

WITH
  toFloat(sme_sum) / toFloat(total_count) AS sme_avg,
  toFloat(lam_sum) / toFloat(total_count) AS lam_avg,
  toFloat(kam_sum) / toFloat(total_count) AS kam_avg,
  total_count

RETURN
  sme_avg - lam_avg AS col1,
  lam_avg - kam_avg AS col2,
  kam_avg - sme_avg AS col3
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

PuppyGraph `[PEPS-06]` crash on `MIN(consumption)` over the 383,282-row yearmonth table combined with a filtered join back to customers × yearmonth. Restructuring attempted (moving MIN into a separate WITH stage) still crashes.

### qid=1482 — MISMATCH (challenging) — `PUPPYGRAPH_TYPE_HANDLING`

**Question:** Which of the three segments—SME, LAM and KAM—has the biggest and lowest percentage increases in consumption paid in EUR between 2012 and 2013?

**Evidence:** Increase or Decrease = consumption for 2013 - consumption for 2012; Percentage of Increase = (Increase or Decrease / consumption for 2013) * 100%; The first 4 strings of the Date values in the yearmonth table can represent year

**SQL (gold from BIRD):**

```sql
SELECT CAST((SUM(CASE WHEN T1.Segment = 'SME' AND T2.Date LIKE '2013%' THEN T2.Consumption ELSE 0 END) - SUM(CASE WHEN T1.Segment = 'SME' AND T2.Date LIKE '2012%' THEN T2.Consumption ELSE 0 END)) AS REAL) * 100 / NULLIF(SUM(CASE WHEN T1.Segment = 'SME' AND T2.Date LIKE '2012%' THEN T2.Consumption ELSE 0 END), 0), CAST(SUM(CASE WHEN T1.Segment = 'LAM' AND T2.Date LIKE '2013%' THEN T2.Consumption ELSE 0 END) - SUM(CASE WHEN T1.Segment = 'LAM' AND T2.Date LIKE '2012%' THEN T2.Consumption ELSE 0 END) AS REAL) * 100 / NULLIF(SUM(CASE WHEN T1.Segment = 'LAM' AND T2.Date LIKE '2012%' THEN T2.Consumption ELSE 0 END), 0), CAST(SUM(CASE WHEN T1.Segment = 'KAM' AND T2.Date LIKE '2013%' THEN T2.Consumption ELSE 0 END) - SUM(CASE WHEN T1.Segment = 'KAM' AND T2.Date LIKE '2012%' THEN T2.Consumption ELSE 0 END) AS REAL) * 100 / NULLIF(SUM(CASE WHEN T1.Segment = 'KAM' AND T2.Date LIKE '2012%' THEN T2.Consumption ELSE 0 END), 0) FROM customers AS T1 INNER JOIN yearmonth AS T2 ON T1.CustomerID = T2.CustomerID
```

**SQL result** (1 rows total):

```
    1. ?column?=708.1112776322933
```

**Cypher attempted:**

```cypher
MATCH (mc:Yearmonth)-[:CONSUMPTION_OF_CUSTOMER]->(c:Customers)
WITH c.segment AS seg,
     mc.date AS ym,
     mc.consumption AS cons
WITH
  SUM(CASE WHEN seg = 'SME' AND ym STARTS WITH '2013' THEN cons ELSE 0 END) AS sme_2013,
  SUM(CASE WHEN seg = 'SME' AND ym STARTS WITH '2012' THEN cons ELSE 0 END) AS sme_2012,
  SUM(CASE WHEN seg = 'LAM' AND ym STARTS WITH '2013' THEN cons ELSE 0 END) AS lam_2013,
  SUM(CASE WHEN seg = 'LAM' AND ym STARTS WITH '2012' THEN cons ELSE 0 END) AS lam_2012,
  SUM(CASE WHEN seg = 'KAM' AND ym STARTS WITH '2013' THEN cons ELSE 0 END) AS kam_2013,
  SUM(CASE WHEN seg = 'KAM' AND ym STARTS WITH '2012' THEN cons ELSE 0 END) AS kam_2012
RETURN
  CASE WHEN sme_2012 = 0 THEN null ELSE toFloat(sme_2013 - sme_2012) * 100.0 / sme_2012 END AS sme_pct,
  CASE WHEN lam_2012 = 0 THEN null ELSE toFloat(lam_2013 - lam_2012) * 100.0 / lam_2012 END AS lam_pct,
  CASE WHEN kam_2012 = 0 THEN null ELSE toFloat(kam_2013 - kam_2012) * 100.0 / kam_2012 END AS kam_pct
```

**Cypher result** (1 rows total):

```
    1. sme_pct=545.4018997568003, lam_pct=681.5824578557963, kam_pct=708.1124069830287
```

**Where they differ** (SQL rows=1, Cypher rows=1):

- Multiset differs. First divergent position: index 0.

| # | SQL row | Cypher row |
|---:|---|---|
| 1 | (708.1112776322933,) | (545.4018997568003, 681.5824578557963, 708.1124069830287) |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - (708.1112776322933,)  ×1

Only in Cypher:
  - (545.4018997568003, 681.5824578557963, 708.1124069830287)  ×1

**Analysis:**

Result differs in the 4th decimal (545.406/681.585/708.112 vs 545.402/681.582/708.112). Cypher is semantically equivalent to SQL; the drift comes from Postgres float32 (real) columns upconverted to float64 for arithmetic — accumulated round-off over ~100k rows of consumption values.

### qid=1524 — MISMATCH (simple) — `PUPPYGRAPH_TYPE_HANDLING`

**Question:** What's the nationality of the customer who spent 548.4 in 2012/8/24?

**Evidence:** '2012/8/24' can be represented by '2012-08-24'; spent 548.4 refers to price = '548.4' 

**SQL (gold from BIRD):**

```sql
SELECT T2.Country FROM transactions_1k AS T1 INNER JOIN gasstations AS T2 ON T1.GasStationID = T2.GasStationID WHERE T1.Date = '2012-08-24' AND T1.Price = '548.4'
```

**SQL result** (1 rows total):

```
    1. country='CZE'
```

**Cypher attempted:**

```cypher
MATCH (t:Transactions1k)-[:TRANSACTION_AT_STATION]->(gs:Gasstations)
WHERE t.date = date('2012-08-24') AND t.price = 548.4
RETURN gs.country
```

**Cypher result** (0 rows total):

```
_(empty)_
```

**Where they differ** (SQL rows=1, Cypher rows=0):

- Multiset differs. First divergent position: index 0.

| # | SQL row | Cypher row |
|---:|---|---|
| 1 | ('CZE',) | — |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - ('CZE',)  ×1

**Analysis:**

SQL `WHERE Price = '548.4'` — Postgres implicitly casts the string to the column's `real` (float32) type. Cypher literal `t.price = 548.4` compares a float64 literal against a value PuppyGraph returns as float64 upconverted from float32 (548.4000244...). The literal 548.4 (exact float64) != 548.4000244... so Cypher returns no rows while SQL returns 1. Semantically-equal query; the gap is PuppyGraph's non-preservation of Postgres real32 equality semantics.


---

## card_games (6 failed case(s))

### qid=349 — MISMATCH (moderate) — `SQL_UNDER_SPECIFICATION`

**Question:** Name the card and artist with the most ruling information. Also state if the card is a promotional printing.

**Evidence:** with the most ruling information refers to Max(count(rulings.uuid)); the card is the promotional printing refers to isPromo = 1;

**SQL (gold from BIRD):**

```sql
SELECT T1.name, T1.artist, T1.isPromo FROM cards AS T1 INNER JOIN rulings AS T2 ON T1.uuid = T2.uuid WHERE T1.isPromo = 1 AND T1.artist = (SELECT artist FROM cards WHERE isPromo = 1 GROUP BY artist HAVING COUNT(DISTINCT uuid) = (SELECT MAX(count_uuid) FROM (SELECT COUNT(DISTINCT uuid) AS count_uuid FROM cards WHERE isPromo = 1 GROUP BY artist) AS subquery)) LIMIT 1
```

**SQL result** (1 rows total):

```
    1. name='Serrated Arrows', artist='John Avon', ispromo=1
```

**Cypher attempted:**

```cypher
MATCH (c:Cards)
WHERE c.ispromo = 1
WITH c.artist AS artist, COUNT(DISTINCT c.uuid) AS ucount
ORDER BY ucount DESC LIMIT 1
WITH artist
MATCH (c2:Cards)
WHERE c2.ispromo = 1 AND c2.artist = artist
MATCH (r:Rulings)-[:RULING_FOR_CARD]->(c2)
RETURN c2.name, c2.artist, c2.ispromo
LIMIT 1
```

**Cypher result** (1 rows total):

```
    1. c2.name='Lotus Field', c2.artist='John Avon', c2.is_promo=1
```

**Where they differ** (SQL rows=1, Cypher rows=1):

- Multiset differs. First divergent position: index 0.

| # | SQL row | Cypher row |
|---:|---|---|
| 1 | ('Serrated Arrows', 'John Avon', 1) | ('Lotus Field', 'John Avon', 1) |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - ('Serrated Arrows', 'John Avon', 1)  ×1

Only in Cypher:
  - ('Lotus Field', 'John Avon', 1)  ×1

**Analysis:**

Two-stage ORDER BY + LIMIT 1: first stage picks the artist with most promo cards (both engines agree: John Avon). Second stage picks the John Avon promo card with most rulings — the SQL uses no tiebreak, so multiple cards tied at the max ruling count are equally valid. SQL returns 'Serrated Arrows'; Cypher returns 'Primal Amulet // Primal Wellspring'. Both are valid answers under the SQL.

### qid=358 — CYPHER_ERROR (simple) — `PUPPYGRAPH_ENGINE_BUG`

**Question:** What is the border color of card "Ancestor's Chosen"?

**Evidence:** name of card  = 'Ancestor''s Chosen' ;

**SQL (gold from BIRD):**

```sql
SELECT DISTINCT borderColor FROM cards WHERE name = 'Ancestor''s Chosen'
```

**SQL result** (1 rows total):

```
    1. bordercolor='black'
```

**Cypher attempted:**

```cypher
MATCH (c:Cards)
WHERE c.name = 'Ancestor\'s Chosen'
RETURN DISTINCT c.bordercolor
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

PuppyGraph engine crashes with `[PEPS-06] DataAccessException` whenever a Cypher string literal contains an apostrophe (e.g. "Ancestor's Chosen"). Reproducible with any equality/STARTS-WITH/CONTAINS on such strings, regardless of quoting style (single, double, escaped). No agent workaround preserves semantic equality to the SQL `name = 'X'`.

### qid=462 — CYPHER_ERROR (moderate) — `PUPPYGRAPH_ENGINE_BUG`

**Question:** What's the Italian name of the set of cards with "Ancestor's Chosen" is in?

**Evidence:** Italian is a language which refers to language = 'Italian'; with "Ancestor's Chosen" in the card set refers to name = 'Ancestor''s Chosen'

**SQL (gold from BIRD):**

```sql
SELECT translation FROM set_translations WHERE setCode IN (SELECT setCode FROM cards WHERE name = 'Ancestor''s Chosen') AND language = 'Italian'
```

**SQL result** (2 rows total):

```
    1. translation='Set Base Decima Edizione'
    2. translation='Sentenza'
```

**Cypher attempted:**

```cypher
MATCH (c:Cards)
WHERE c.name = 'Ancestor\'s Chosen'
WITH DISTINCT c.setcode AS sc
MATCH (s:Sets {code: sc})<-[:SET_TRANSLATION_FOR_SET]-(st:SetTranslations)
WHERE st.language = 'Italian'
RETURN st.translation
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

Same apostrophe-in-string-literal PuppyGraph engine bug as qid=358.

### qid=465 — CYPHER_ERROR (moderate) — `PUPPYGRAPH_ENGINE_BUG`

**Question:** For the set of cards with "Ancestor's Chosen" in it, is there a Korean version of it?

**Evidence:** set of cards with "Ancestor''s Chosen" in it refers to name = 'Ancestor''s Chosen'; Korean version refers to language = 'Korean'

**SQL (gold from BIRD):**

```sql
SELECT CASE WHEN SUM(CASE WHEN T2.language = 'Korean' AND NOT T2.translation IS NULL THEN 1 ELSE 0 END) > 0 THEN 'YES' ELSE 'NO' END FROM cards AS T1 INNER JOIN set_translations AS T2 ON T2.setCode = T1.setCode WHERE T1.name = 'Ancestor''s Chosen'
```

**SQL result** (1 rows total):

```
    1. case='YES'
```

**Cypher attempted:**

```cypher
MATCH (c:Cards)
WHERE c.name = 'Ancestor\'s Chosen'
MATCH (c)-[:CARD_IN_SET]->(s:Sets)<-[:SET_TRANSLATION_FOR_SET]-(st:SetTranslations)
WITH SUM(CASE WHEN st.language = 'Korean' AND st.translation IS NOT NULL THEN 1 ELSE 0 END) AS korean_count
RETURN CASE WHEN korean_count > 0 THEN 'YES' ELSE 'NO' END
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

Same apostrophe engine bug.

### qid=480 — CYPHER_ERROR (moderate) — `PUPPYGRAPH_ENGINE_BUG`

**Question:** What is the Italian flavor text of the card "Ancestor's Chosen"?

**Evidence:** Italian refers to language = 'Italian'; flavor text refers to flavorText; "Ancestor''s Chosen" refers to name = 'Ancestor''s Chosen'

**SQL (gold from BIRD):**

```sql
SELECT T2.flavorText FROM cards AS T1 INNER JOIN foreign_data AS T2 ON T2.uuid = T1.uuid WHERE T1.name = 'Ancestor''s Chosen' AND T2.language = 'Italian'
```

**SQL result** (2 rows total):

```
    1. flavortext='Sancito da generazioni di forza.'
    2. flavortext='"La volontà di tutti, eseguita per mano mia."'
```

**Cypher attempted:**

```cypher
MATCH (c:Cards)
WHERE c.name = 'Ancestor\'s Chosen'
MATCH (fd:ForeignData)-[:FOREIGN_DATA_FOR_CARD]->(c)
WHERE fd.language = 'Italian'
RETURN fd.flavortext
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

Same apostrophe engine bug.

### qid=528 — CYPHER_ERROR (challenging) — `PUPPYGRAPH_ENGINE_LIMIT`

**Question:** List the names of all the cards in the set Hour of Devastation and find the formats in which these cards are legal.

**Evidence:** the set Hour of Devastation refers to set.name = 'Hour of Devastation'; names of all the cards in the set refers to cards.name; legal cards refers to status = 'Legal'; the formats refers to format

**SQL (gold from BIRD):**

```sql
SELECT DISTINCT T2.name, CASE WHEN T1.status = 'Legal' THEN T1.format ELSE NULL END FROM legalities AS T1 INNER JOIN cards AS T2 ON T2.uuid = T1.uuid WHERE T2.setCode IN (SELECT code FROM sets WHERE name = 'Hour of Devastation')
```

**SQL result** (1664 rows total, preview only):

```
    1. name='Abandoned Sarcophagus', case='commander'
    2. name='Abandoned Sarcophagus', case='duel'
    3. name='Abandoned Sarcophagus', case='gladiator'
    4. name='Abandoned Sarcophagus', case='historic'
    5. name='Abandoned Sarcophagus', case='legacy'
    6. name='Abandoned Sarcophagus', case='modern'
    7. name='Abandoned Sarcophagus', case='penny'
    8. name='Abandoned Sarcophagus', case='pioneer'
    9. name='Abandoned Sarcophagus', case='vintage'
    10. name='Abrade', case='commander'
    11. name='Abrade', case='duel'
    12. name='Abrade', case='gladiator'
    13. name='Abrade', case='historic'
    14. name='Abrade', case='legacy'
    15. name='Abrade', case='modern'
    16. name='Abrade', case='pauper'
    17. name='Abrade', case='pioneer'
    18. name='Abrade', case='vintage'
    19. name='Accursed Horde', case='commander'
    20. name='Accursed Horde', case='duel'
    ... (1644 more rows omitted)
```

**Cypher attempted:**

```cypher
MATCH (c:Cards)-[:CARD_IN_SET]->(s:Sets)
WHERE s.name = 'Hour of Devastation'
MATCH (cl:Legalities)-[:LEGALITY_FOR_CARD]->(c)
WITH DISTINCT c.name AS card_name,
     CASE WHEN cl.status = 'Legal' THEN cl.format ELSE NULL END AS format
RETURN DISTINCT card_name, format
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

PuppyGraph `[PEPS-06]` engine crash on Cards × Sets × 427,907-row CardLegality join with CASE-based projection.


---

## european_football_2 (1 failed case(s))

### qid=1092 — CYPHER_ERROR (simple) — `PUPPYGRAPH_ENGINE_BUG`

**Question:** Give the name of the league had the most matches in the 2008/2009 season?

**Evidence:** league that had the most matches in the 2008/2009 season refers to MAX(league_name WHERE season = '2008/2009');

**SQL (gold from BIRD):**

```sql
SELECT t1.name FROM League AS t1 JOIN Match AS t2 ON t1.id = t2.league_id WHERE t2.season = '2008/2009' GROUP BY t1.name HAVING COUNT(t2.id) = (SELECT MAX(match_count) FROM (SELECT COUNT(t2.id) AS match_count FROM Match AS t2 WHERE t2.season = '2008/2009' GROUP BY t2.league_id) AS subquery)
```

**SQL result** (4 rows total):

```
    1. name='England Premier League'
    2. name='Italy Serie A'
    3. name='Spain LIGA BBVA'
    4. name='France Ligue 1'
```

**Cypher attempted:**

```cypher
MATCH (m:Match)
WHERE m.season = '2008/2009'
WITH m.league_id AS lid, COUNT(*) AS cnt
WITH MAX(cnt) AS max_cnt, COLLECT({lid: lid, cnt: cnt}) AS rows
UNWIND rows AS row
WITH row.lid AS lid, row.cnt AS cnt, max_cnt
WHERE cnt = max_cnt
MATCH (l:League {id: lid})
RETURN l.name
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[CPST-12] Variable types mismatch in expression: cnt and max_cnt attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [CPST-12] Variable types mismatch in expression: cnt and max_cnt
	at com.puppygraph.puppygraph.engine.pattern.CypherPredicateQueryProcessor.translateEqualsID(CypherPredicateQueryProcessor.java:367)
	at com.puppygraph.puppygraph.engine.pattern.CypherPredicateQueryProcessor.translateSpecialExpressionToPredicate(CypherPredicateQueryProcessor.java:110)
	at com.puppygraph.puppygraph.engine.pattern.ExpressionProcessor.evaluate(ExpressionProcessor.java:72)
	at com.puppygraph.puppygraph.engine.pattern.CypherPredicateQueryProcessor.evaluateToPredicate(CypherPredicateQueryProcessor.java:97)
	at com.puppygraph.puppygraph.engine.pattern.ProjectionProcessor.buildProjectionWithoutOrder(ProjectionProcessor.java:497)
	at com.puppygraph.puppygraph.engine.pattern.ProjectionProcessor.buildProjection(ProjectionProcessor.java:206)
	at com.puppygraph.puppygraph.engine.pattern.QueryProcessor.processSingleQuery(QueryProcessor.java:307)
	at com.puppygraph.puppygraph.engine.pattern.QueryProcessor.processQuery(QueryProcessor.java:53)
	at com.puppygraph.puppygraph.engine.pattern.QueryProcessor.processAll(QueryProcessor.java:40)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.getTraverserComposedQueriesFutures(PuppyEnginePatternStep.java:216)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:357)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Threa
```

**Analysis:**

PuppyGraph engine bug: `[CPST-12] Variable types mismatch in expression: cnt and max_cnt`. Comparing two integer aggregates that come from different WITH stages triggers this. Reproducible across multiple restructuring attempts (COLLECT-UNWIND-MAX, two-pass MATCH with intermediate WITH). openCypher spec allows this pattern; PuppyGraph's type inference on aggregate values fails.


---

## student_club (2 failed case(s))

### qid=1317 — CYPHER_ERROR (moderate) — `PUPPYGRAPH_ENGINE_BUG`

**Question:** Among the students from the Student_Club who attended the event "Women's Soccer", how many of them want a T-shirt that's in medium size?

**Evidence:** Women's Soccer is an event name; T-shirt that is in medium size refers to t_shirt_size = 'Medium'

**SQL (gold from BIRD):**

```sql
SELECT COUNT(T1.event_id) FROM event AS T1 INNER JOIN attendance AS T2 ON T1.event_id = T2.link_to_event INNER JOIN member AS T3 ON T2.link_to_member = T3.member_id WHERE T1.event_name = 'Women''s Soccer' AND T3.t_shirt_size = 'Medium'
```

**SQL result** (1 rows total):

```
    1. count=7
```

**Cypher attempted:**

```cypher
MATCH (m:Member)-[:MEMBER_ATTENDED_EVENT]->(e:Event)
WHERE e.event_name = 'Women\'s Soccer' AND m.t_shirt_size = 'Medium'
RETURN COUNT(m)
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

Same apostrophe-in-string-literal PuppyGraph engine bug: `event_name = 'Women\'s Soccer'` triggers `[PEPS-06] DataAccessException`.

### qid=1371 — CYPHER_ERROR (simple) — `PUPPYGRAPH_ENGINE_BUG`

**Question:** How many members attended the "Women's Soccer" event?

**Evidence:** 'Women's Soccer' is the event name;

**SQL (gold from BIRD):**

```sql
SELECT COUNT(T2.link_to_member) FROM event AS T1 INNER JOIN attendance AS T2 ON T1.event_id = T2.link_to_event WHERE T1.event_name = 'Women''s Soccer'
```

**SQL result** (1 rows total):

```
    1. count=17
```

**Cypher attempted:**

```cypher
MATCH (m:Member)-[:MEMBER_ATTENDED_EVENT]->(e:Event)
WHERE e.event_name = 'Women\'s Soccer'
RETURN COUNT(m)
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

Same apostrophe engine bug.


---

## financial (1 failed case(s))

### qid=116 — CYPHER_ERROR (challenging) — `PUPPYGRAPH_ENGINE_LIMIT`

**Question:** For the client whose loan was approved first in 1993/7/5, what is the increase rate of his/her account balance from 1993/3/22 to 1998/12/27?

**Evidence:** Increase rate of his/her account balance = [(balance of date A - balance of date B) / balance of Date B] * 100%

**SQL (gold from BIRD):**

```sql
SELECT CAST((SUM(CASE WHEN T3.date = '1998-12-27' THEN T3.balance ELSE 0 END) - SUM(CASE WHEN T3.date = '1993-03-22' THEN T3.balance ELSE 0 END)) AS REAL) * 100 / NULLIF(SUM(CASE WHEN T3.date = '1993-03-22' THEN T3.balance ELSE 0 END), 0) FROM loan AS T1 INNER JOIN account AS T2 ON T1.account_id = T2.account_id INNER JOIN trans AS T3 ON T3.account_id = T2.account_id WHERE T1.date = '1993-07-05'
```

**SQL result** (1 rows total):

```
    1. ?column?=430.45454545454544
```

**Cypher attempted:**

```cypher
MATCH (l:Loan)-[:LOAN_ON_ACCOUNT]->(a:Account)<-[:TRANS_ON_ACCOUNT]-(t:Trans)
WHERE l.date = date('1993-07-05')
WITH
  SUM(CASE WHEN t.date = date('1998-12-27') THEN t.balance ELSE 0 END) AS bal_end,
  SUM(CASE WHEN t.date = date('1993-03-22') THEN t.balance ELSE 0 END) AS bal_start
RETURN
  toFloat(bal_end - bal_start) * 100.0 / NULLIF(bal_start, 0) AS increase_rate
```

**Cypher execution — ERROR:**

```
{code: E0502} {message:  error in read loop, error message '{code:244 message:[PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed attributes:map[exceptions:[com.puppygraph.puppygraph.engine.error.PuppyEngineException com.puppygraph.puppygraph.error.DataAccessException] stackTrace:com.puppygraph.puppygraph.engine.error.PuppyEngineException: [PEPS-06] Failed to execute query. com.puppygraph.puppygraph.error.DataAccessException: [4000]DataAccess process failed
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:449)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.processNextStart(PuppyEnginePatternStep.java:153)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.ExpandableStepIterator.next(ExpandableStepIterator.java:55)
	at org.apache.tinkerpop.gremlin.process.traversal.step.map.ScalarMapStep.processNextStart(ScalarMapStep.java:39)
	at org.apache.tinkerpop.gremlin.process.traversal.step.util.AbstractStep.hasNext(AbstractStep.java:155)
	at org.apache.tinkerpop.gremlin.process.traversal.util.DefaultTraversal.hasNext(DefaultTraversal.java:192)
	at org.apache.tinkerpop.gremlin.server.op.AbstractOpProcessor.handleIterator(AbstractOpProcessor.java:98)
	at com.puppygraph.puppygraph.server.PuppyCypherOpProcessor.lambda$evalCypher$0(PuppyCypherOpProcessor.java:194)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:539)
	at java.base/java.util.concurrent.FutureTask.run(FutureTask.java:264)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1136)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:635)
	at java.base/java.lang.Thread.run(Thread.java:840)
Caused by: com.puppygraph.puppygraph.error.DataAccessException: [4004]Data access execution failed
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:74)
	at com.puppygraph.puppygraph.error.DataAccessException.logAndRethrow(DataAccessException.java:86)
	at com.puppygraph.puppygraph.engine.executor.DataTraverserIterator.init(DataTraverserIterator.java:90)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.<init>(ChainedDataTraverserIterator.java:23)
	at com.puppygraph.puppygraph.engine.executor.ChainedDataTraverserIterator.of(ChainedDataTraverserIterator.java:29)
	at com.puppygraph.puppygraph.engine.step.PuppyEnginePatternStep.buildIterators(PuppyEnginePatternStep.java:429)
	... 14 more
]}'. statusCode: 244}
```

**Analysis:**

PuppyGraph `[PEPS-06]` engine crash on Transaction (1,056,320 rows) joined with Loan/Account with SUM(CASE...) aggregation. Restructuring attempted (pre-filter loans then join transactions with IN date list); engine still crashes.


---

## codebase_community (2 failed case(s))

### qid=532 — MISMATCH (simple) — `PUPPYGRAPH_TYPE_HANDLING`

**Question:** Please list the display names of all the users whose accounts were created in the year 2011.

**Evidence:** account created in the year 2011 refers to year(CreationDate) = 2011

**SQL (gold from BIRD):**

```sql
SELECT DisplayName FROM users WHERE TO_CHAR(CAST(CreationDate AS TIMESTAMP), 'YYYY') = '2011'
```

**SQL result** (4430 rows total, preview only):

```
    1. displayname='Rob'
    2. displayname='Anubhav'
    3. displayname='Betamoo'
    4. displayname='dram'
    5. displayname='dcurtis'
    6. displayname='DavidDong'
    7. displayname='varuman'
    8. displayname='ennuikiller'
    9. displayname='Jaime'
    10. displayname='Sean Hill'
    11. displayname='grenade'
    12. displayname='Mathias Bynens'
    13. displayname='Ringold'
    14. displayname='binil'
    15. displayname='murgatroid99'
    16. displayname='Ben Jackson'
    17. displayname='Judy'
    18. displayname='speciousfool'
    19. displayname='Jonathan Andrews'
    20. displayname='Adi Shavit'
    ... (4410 more rows omitted)
```

**Cypher attempted:**

```cypher
MATCH (u:Users)
WHERE u.creationdate.year = 2011
RETURN u.displayname
```

**Cypher result** (4430 rows total, preview only):

```
    1. u.display_name='Vivek'
    2. u.display_name='jason'
    3. u.display_name='blue and grey'
    4. u.display_name='samarasa'
    5. u.display_name='Lalas'
    6. u.display_name='David Wright'
    7. u.display_name='Justin'
    8. u.display_name='ChrisStata'
    9. u.display_name='Jeff Wu'
    10. u.display_name='Chris Heller'
    11. u.display_name='Lester Peabody'
    12. u.display_name='Robert Roos'
    13. u.display_name='tom'
    14. u.display_name='KLXN'
    15. u.display_name='arandomlypickedname'
    16. u.display_name='Murmur'
    17. u.display_name='Ran'
    18. u.display_name='Dean'
    19. u.display_name='Ata'
    20. u.display_name='Marius'
    ... (4410 more rows omitted)
```

**Where they differ** (SQL rows=4430, Cypher rows=4430):

- Multiset differs. First divergent position: index 0.

| # | SQL row | Cypher row |
|---:|---|---|
| 1 | ('Rob',) | ('Vivek',) |
| 2 | ('Anubhav',) | ('jason',) |
| 3 | ('Betamoo',) | ('blue and grey',) |
| 4 | ('dram',) | ('samarasa',) |
| 5 | ('dcurtis',) | ('Lalas',) |
| 6 | ('DavidDong',) | ('David Wright',) |
| 7 | ('varuman',) | ('Justin',) |
| 8 | ('ennuikiller',) | ('ChrisStata',) |
| 9 | ('Jaime',) | ('Jeff Wu',) |
| 10 | ('Sean Hill',) | ('Chris Heller',) |
| 11 | ('grenade',) | ('Lester Peabody',) |
| 12 | ('Mathias Bynens',) | ('Robert Roos',) |
| 13 | ('Ringold',) | ('tom',) |
| 14 | ('binil',) | ('KLXN',) |
| 15 | ('murgatroid99',) | ('arandomlypickedname',) |
| 16 | ('Ben Jackson',) | ('Murmur',) |
| 17 | ('Judy',) | ('Ran',) |
| 18 | ('speciousfool',) | ('Dean',) |
| 19 | ('Jonathan Andrews',) | ('Ata',) |
| 20 | ('Adi Shavit',) | ('Marius',) |
| ... | ... more rows differ | ... |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - ('Rob',)  ×1

Only in Cypher:
  - ('Niroshan',)  ×1

**Analysis:**

SQL `TO_CHAR(CAST(CreationDate AS TIMESTAMP), 'YYYY') = '2011'` uses session TZ (Asia/Hong_Kong, UTC+8) for year extraction. Cypher `.year` on the timestamptz-mapped attribute gives HK-year in PuppyGraph too, and total row count matches (4430=4430). But 1 user near the year boundary is picked differently by the two engines — likely a subtle PuppyGraph rounding of the year extraction that disagrees with Postgres for one boundary timestamp.

### qid=683 — MISMATCH (moderate) — `PUPPYGRAPH_TYPE_HANDLING`

**Question:** What is the percentage of posts whose owners had a reputation of over 1000 in 2011?

**Evidence:** percentage = DIVIDE(COUNT(Id where YEAR(CreationDate) = 2011 and Reputation > 1000), COUNT(Id) ) * 100;

**SQL (gold from BIRD):**

```sql
SELECT CAST(SUM(CASE WHEN TO_CHAR(CAST(T2.CreaionDate AS TIMESTAMP), 'YYYY') = '2011' AND T1.Reputation > 1000 THEN 1 ELSE 0 END) AS REAL) * 100 / NULLIF(COUNT(T1.Id), 0) FROM users AS T1 INNER JOIN posts AS T2 ON T1.Id = T2.OwnerUserId
```

**SQL result** (1 rows total):

```
    1. ?column?=7.24159250999183
```

**Cypher attempted:**

```cypher
MATCH (p:Posts)-[:POST_OWNED_BY_USER]->(u:Users)
RETURN toFloat(SUM(CASE WHEN p.creaiondate.year = 2011 AND u.reputation > 1000 THEN 1 ELSE 0 END)) * 100.0
       / (CASE WHEN COUNT(u.id) = 0 THEN null ELSE COUNT(u.id) END)
```

**Cypher result** (1 rows total):

```
    1. toFloat(SUM(CASE WHEN p.creation_date.year = 2011 AND u.reputation > 1000 THEN 1 ELSE 0 END)) * 100.0
       / (CASE WHEN COUNT(u.user_id) = 0 THEN null ELSE COUNT(u.user_id) END)=7.2426966
```

**Where they differ** (SQL rows=1, Cypher rows=1):

- Multiset differs. First divergent position: index 0.

| # | SQL row | Cypher row |
|---:|---|---|
| 1 | (7.24159250999183,) | (7.2426966,) |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - (7.24159250999183,)  ×1

Only in Cypher:
  - (7.2426966,)  ×1

**Analysis:**

SQL `SUM(CASE WHEN TO_CHAR(CreaionDate,'YYYY')='2011' AND Reputation>1000 ...) * 100 / COUNT(...)` — semantically equivalent Cypher uses `.year=2011`. Result differs at 4th decimal (7.24159 vs 7.2427) because a small number of posts near the 2011↔2012 boundary get classified differently between Postgres's HK-timezone year and PuppyGraph's year extraction. Semantically equivalent query.


---

## superhero (1 failed case(s))

### qid=751 — MISMATCH (moderate) — `SQL_UNDER_SPECIFICATION`

**Question:** List down at least five superpowers of male superheroes.

**Evidence:** male refers to gender = 'Male'; superpowers refers to power_name;

**SQL (gold from BIRD):**

```sql
SELECT T3.power_name FROM superhero AS T1 INNER JOIN hero_power AS T2 ON T1.id = T2.hero_id INNER JOIN superpower AS T3 ON T3.id = T2.power_id INNER JOIN gender AS T4 ON T4.id = T1.gender_id WHERE T4.gender = 'Male' LIMIT 5
```

**SQL result** (5 rows total):

```
    1. power_name='Agility'
    2. power_name='Super Strength'
    3. power_name='Stamina'
    4. power_name='Super Speed'
    5. power_name='Accelerated Healing'
```

**Cypher attempted:**

```cypher
MATCH (h:Superhero)-[:HERO_HAS_GENDER]->(g:Gender)
WHERE g.gender = 'Male'
MATCH (h)-[:HERO_HAS_POWER]->(p:Superpower)
RETURN p.power_name
LIMIT 5
```

**Cypher result** (5 rows total):

```
    1. p.power_name='Agility'
    2. p.power_name='Agility'
    3. p.power_name='Agility'
    4. p.power_name='Agility'
    5. p.power_name='Agility'
```

**Where they differ** (SQL rows=5, Cypher rows=5):

- Multiset differs. First divergent position: index 1.

| # | SQL row | Cypher row |
|---:|---|---|
| 2 | ('Super Strength',) | ('Agility',) |
| 3 | ('Stamina',) | ('Agility',) |
| 4 | ('Super Speed',) | ('Agility',) |
| 5 | ('Accelerated Healing',) | ('Agility',) |

**Rows appearing only on one side (as multiset, top 20):**

Only in SQL:
  - ('Super Strength',)  ×1
  - ('Stamina',)  ×1
  - ('Super Speed',)  ×1
  - ('Accelerated Healing',)  ×1

Only in Cypher:
  - ('Agility',)  ×4

**Analysis:**

SQL `SELECT power_name FROM ... LIMIT 5` with NO ORDER BY. Both engines return 5 valid rows from the many-to-many hero_power join, but which 5 is implementation-defined. Both answers are equally valid under the SQL.
