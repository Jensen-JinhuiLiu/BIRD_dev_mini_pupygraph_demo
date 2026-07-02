# Graph Agent Special Report: PuppyGraph Engine / Date-Result Issues


These are all graph-failed cases identified as likely engine/result-format issues rather than semantic reasoning failures.

### codebase_community Q669 — `puppygraph_engine_date_format`

**Question:** When did 'chl' cast its first vote in a post?

**Evidence:** DisplayName = 'chl'; cast its first vote refers to MIN(CreationDate);

**GT SQL**
```sql
SELECT T2.CreationDate FROM users AS T1 INNER JOIN votes AS T2 ON T1.Id = T2.UserId WHERE T1.DisplayName = 'chl' ORDER BY T2.CreationDate NULLS FIRST LIMIT 1
```

**GT answer snapshot**
```json
[
  {
    "creationdate": "2010-08-13"
  }
]
```

**Predicted graph Cypher**
```cypher
MATCH (u:Users {displayname:'chl'})<-[:VOTE_BY_USER]-(v:Votes)-[:VOTE_ON_POST]->(:Posts)
RETURN min(v.creationdate) AS first_vote_date
```

**Predicted Cypher result snapshot**
```json
[
  {
    "first_vote_date": "2010-08-13T00:00:00.000000000+00:00"
  }
]
```

**Failure reason:** PuppyGraph returns date-like values as timestamp strings while the PostgreSQL gold output uses date strings; normalized values match.

### formula_1 Q981 — `puppygraph_engine_date_format`

**Question:** On what year did the youngest driver had his first qualifying race? Also state the name, date and time of the race.

**Evidence:** date of birth refers to drivers.dob; The larger the birthday value, the younger the person is, and vice versa; first qualifying race refers to MIN(races.date);

**GT SQL**
```sql
SELECT T3.year, T3.name, T3.date, T3.time FROM qualifying AS T1 INNER JOIN drivers AS T2 ON T1.driverId = T2.driverId INNER JOIN races AS T3 ON T1.raceId = T3.raceId WHERE T1.driverId = (SELECT driverId FROM drivers ORDER BY dob DESC NULLS LAST LIMIT 1) ORDER BY T3.date ASC NULLS FIRST LIMIT 1
```

**GT answer snapshot**
```json
[
  {
    "year": 2017,
    "name": "Chinese Grand Prix",
    "date": "2017-04-09",
    "time": "06:00:00"
  }
]
```

**Predicted graph Cypher**
```cypher
MATCH (d:Drivers)
WITH d
ORDER BY d.dob DESC
LIMIT 1
MATCH (q:Qualifying)-[:QUALIFYING_BY_DRIVER]->(d)
MATCH (q)-[:QUALIFYING_IN_RACE]->(r:Races)
WITH r
ORDER BY r.date ASC
LIMIT 1
RETURN r.year AS year, r.name AS race_name, r.date AS date, r.time AS time
```

**Predicted Cypher result snapshot**
```json
[
  {
    "year": 2017,
    "race_name": "Chinese Grand Prix",
    "date": "2017-04-09T00:00:00.000000000+00:00",
    "time": "06:00:00"
  }
]
```

**Failure reason:** PuppyGraph returns date-like values as timestamp strings while the PostgreSQL gold output uses date strings; normalized values match.

### thrombosis_prediction Q1155 — `puppygraph_engine_date_format`

**Question:** List the patient ID, sex and birthday of patient with LDH beyond normal range.

**Evidence:** LDH beyond normal range refers to LDH > '500';

**GT SQL**
```sql
SELECT DISTINCT T1.ID, T1.SEX, T1.Birthday FROM Patient AS T1 INNER JOIN Laboratory AS T2 ON T1.ID = T2.ID WHERE T2.LDH > 500
```

**GT answer snapshot**
```json
[
  {
    "id": 1650222,
    "sex": "F",
    "birthday": "1947-03-17"
  },
  {
    "id": 4840422,
    "sex": "F",
    "birthday": "1962-01-18"
  },
  {
    "id": 5404650,
    "sex": "F",
    "birthday": "1963-04-07"
  },
  {
    "id": 4915498,
    "sex": "F",
    "birthday": "1959-01-22"
  },
  {
    "id": 4415406,
    "sex": "F",
    "birthday": "1935-06-03"
  }
]
...
```

**Predicted graph Cypher**
```cypher
MATCH (p:Patient)-[:HAD_LAB_PANEL]->(l:Laboratory)
WHERE l.ldh > 500
RETURN DISTINCT p.id AS patient_id, p.sex AS sex, p.birthday AS birthday
ORDER BY patient_id
```

**Predicted Cypher result snapshot**
```json
[
  {
    "patient_id": 27654,
    "sex": "F",
    "birthday": "1936-03-25T00:00:00.000000000+00:00"
  },
  {
    "patient_id": 57266,
    "sex": "M",
    "birthday": "1923-07-25T00:00:00.000000000+00:00"
  },
  {
    "patient_id": 81043,
    "sex": "M",
    "birthday": "1967-03-25T00:00:00.000000000+00:00"
  },
  {
    "patient_id": 540520,
    "sex": "F",
    "birthday": "1941-11-21T00:00:00.000000000+00:00"
  },
  {
    "patient_id": 912147,
    "sex": "F",
    "birthday": "1975-02-17T00:00:00.000000000+00:00"
  }
]
...
```

**Failure reason:** PuppyGraph returns date-like values as timestamp strings while the PostgreSQL gold output uses date strings; normalized values match.

### thrombosis_prediction Q1220 — `puppygraph_engine_date_format`

**Question:** Provide all ID, sex and birthday of patients whose urea nitrogen (UN) just within the borderline of passing?

**Evidence:** urea nitrogen (UN) just within the borderline of passing refers to UN = 29; 

**GT SQL**
```sql
SELECT DISTINCT T1.ID, T1.SEX, T1.Birthday FROM Patient AS T1 INNER JOIN Laboratory AS T2 ON T1.ID = T2.ID WHERE T2.UN = 29
```

**GT answer snapshot**
```json
[
  {
    "id": 27654,
    "sex": "F",
    "birthday": "1936-03-25"
  },
  {
    "id": 444499,
    "sex": "M",
    "birthday": "1954-01-24"
  },
  {
    "id": 912147,
    "sex": "F",
    "birthday": "1975-02-17"
  },
  {
    "id": 1138737,
    "sex": "F",
    "birthday": "1965-11-18"
  },
  {
    "id": 1185720,
    "sex": "F",
    "birthday": "1953-10-12"
  }
]
...
```

**Predicted graph Cypher**
```cypher
MATCH (p:Patient)-[:HAD_LAB_PANEL]->(l:Laboratory)
WHERE l.un = 29
RETURN DISTINCT p.id AS id, p.sex AS sex, p.birthday AS birthday
ORDER BY id
```

**Predicted Cypher result snapshot**
```json
[
  {
    "id": 27654,
    "sex": "F",
    "birthday": "1936-03-25T00:00:00.000000000+00:00"
  },
  {
    "id": 444499,
    "sex": "M",
    "birthday": "1954-01-24T00:00:00.000000000+00:00"
  },
  {
    "id": 912147,
    "sex": "F",
    "birthday": "1975-02-17T00:00:00.000000000+00:00"
  },
  {
    "id": 1138737,
    "sex": "F",
    "birthday": "1965-11-18T00:00:00.000000000+00:00"
  },
  {
    "id": 1185720,
    "sex": "F",
    "birthday": "1953-10-12T00:00:00.000000000+00:00"
  }
]
...
```

**Failure reason:** PuppyGraph returns date-like values as timestamp strings while the PostgreSQL gold output uses date strings; normalized values match.

### thrombosis_prediction Q1281 — `puppygraph_engine_date_format`

**Question:** Among the patients who have an abnormal level of glutamic oxaloacetic transaminase, when was the youngest of them born?

**Evidence:** abnormal level of glutamic oxaloacetic transaminase refers to GOT > = 60; The larger the birthday value, the younger the person is, and vice versa;

**GT SQL**
```sql
SELECT T1.Birthday FROM Patient AS T1 INNER JOIN Laboratory AS T2 ON T1.ID = T2.ID WHERE T2.GOT >= 60 ORDER BY T1.Birthday DESC NULLS LAST LIMIT 1
```

**GT answer snapshot**
```json
[
  {
    "birthday": "1987-12-05"
  }
]
```

**Predicted graph Cypher**
```cypher
MATCH (p:Patient)-[:HAD_LAB_PANEL]->(l:Laboratory)
WHERE l.got >= 60 AND p.birthday IS NOT NULL
WITH DISTINCT p
RETURN max(p.birthday) AS youngest_birthday
```

**Predicted Cypher result snapshot**
```json
[
  {
    "youngest_birthday": "1987-12-05T00:00:00.000000000+00:00"
  }
]
```

**Failure reason:** PuppyGraph returns date-like values as timestamp strings while the PostgreSQL gold output uses date strings; normalized values match.
