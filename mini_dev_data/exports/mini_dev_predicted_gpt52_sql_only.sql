-- [0] db_id=debit_card_specializing
SELECT
  1.0 * SUM(CASE WHEN Currency = 'EUR' THEN 1 ELSE 0 END) /
  NULLIF(SUM(CASE WHEN Currency = 'CZK' THEN 1 ELSE 0 END), 0) AS eur_to_czk_ratio
FROM customers;

-- [1] db_id=debit_card_specializing
SELECT ym.CustomerID
FROM yearmonth AS ym
JOIN customers AS c
  ON c.CustomerID = ym.CustomerID
WHERE SUBSTR(ym.Date, 1, 4) = '2012'
  AND c.Segment = 'LAM'
GROUP BY ym.CustomerID
ORDER BY SUM(ym.Consumption) ASC
LIMIT 1;

-- [2] db_id=debit_card_specializing
SELECT AVG(y.Consumption) / 12.0 AS AvgMonthlyConsumption_SME_2013
FROM yearmonth AS y
JOIN customers AS c
  ON c.CustomerID = y.CustomerID
WHERE c.Segment = 'SME'
  AND substr(y.Date, 1, 4) = '2013'
  AND y.Date BETWEEN '201301' AND '201312';

-- [3] db_id=debit_card_specializing
SELECT
  SUM(CASE WHEN c.Currency = 'CZK' THEN y.Consumption ELSE 0 END)
  - SUM(CASE WHEN c.Currency = 'EUR' THEN y.Consumption ELSE 0 END) AS ConsumptionDifference
FROM yearmonth y
JOIN customers c ON c.CustomerID = y.CustomerID
WHERE y.Date BETWEEN '201201' AND '201212';

-- [4] db_id=debit_card_specializing
SELECT SUBSTR(ym.Date, 1, 4) AS Year
FROM yearmonth AS ym
JOIN customers AS c
  ON c.CustomerID = ym.CustomerID
WHERE c.Currency = 'CZK'
GROUP BY SUBSTR(ym.Date, 1, 4)
ORDER BY SUM(ym.Consumption) DESC
LIMIT 1

-- [5] db_id=debit_card_specializing
SELECT ym.Date AS PeakMonth
FROM yearmonth ym
JOIN customers c ON c.CustomerID = ym.CustomerID
WHERE c.Segment = 'SME'
  AND ym.Date BETWEEN '201301' AND '201312'
ORDER BY ym.Consumption DESC
LIMIT 1

-- [6] db_id=debit_card_specializing
SELECT
  sme.avg_lowest_consumption - lam.avg_lowest_consumption AS diff_sme_lam,
  lam.avg_lowest_consumption - kam.avg_lowest_consumption AS diff_lam_kam,
  kam.avg_lowest_consumption - sme.avg_lowest_consumption AS diff_kam_sme
FROM
  (
    WITH yearly AS (
      SELECT
        c.Segment,
        ym.CustomerID,
        SUM(ym.Consumption) AS total_consumption_2013
      FROM yearmonth ym
      JOIN customers c ON c.CustomerID = ym.CustomerID
      WHERE ym.Date BETWEEN '201301' AND '201312'
      GROUP BY c.Segment, ym.CustomerID
    ),
    mins AS (
      SELECT Segment, MIN(total_consumption_2013) AS min_total
      FROM yearly
      GROUP BY Segment
    ),
    lowest AS (
      SELECT y.Segment, y.CustomerID, y.total_consumption_2013
      FROM yearly y
      JOIN mins m
        ON m.Segment = y.Segment
       AND m.min_total = y.total_consumption_2013
    )
    SELECT
      Segment,
      SUM(total_consumption_2013) * 1.0 / COUNT(*) AS avg_lowest_consumption
    FROM lowest
    GROUP BY Segment
  ) AS all_avgs
JOIN (
  SELECT avg_lowest_consumption
  FROM (
    WITH yearly AS (
      SELECT
        c.Segment,
        ym.CustomerID,
        SUM(ym.Consumption) AS total_consumption_2013
      FROM yearmonth ym
      JOIN customers c ON c.CustomerID = ym.CustomerID
      WHERE ym.Date BETWEEN '201301' AND '201312'
      GROUP BY c.Segment, ym.CustomerID
    ),
    mins AS (
      SELECT Segment, MIN(total_consumption_2013) AS min_total
      FROM yearly
      GROUP BY Segment
    ),
    lowest AS (
      SELECT y.Segment, y.CustomerID, y.total_consumption_2013
      FROM yearly y
      JOIN mins m
        ON m.Segment = y.Segment
       AND m.min_total = y.total_consumption_2013
    )
    SELECT
      Segment,
      SUM(total_consumption_2013) * 1.0 / COUNT(*) AS avg_lowest_consumption
    FROM lowest
    GROUP BY Segment
  )
  WHERE Segment = 'SME'
) AS sme
JOIN (
  SELECT avg_lowest_consumption
  FROM (
    WITH yearly AS (
      SELECT
        c.Segment,
        ym.CustomerID,
        SUM(ym.Consumption) AS total_consumption_2013
      FROM yearmonth ym
      JOIN customers c ON c.CustomerID = ym.CustomerID
      WHERE ym.Date BETWEEN '201301' AND '201312'
      GROUP BY c.Segment, ym.CustomerID
    ),
    mins AS (
      SELECT Segment, MIN(total_consumption_2013) AS min_total
      FROM yearly
      GROUP BY Segment
    ),
    lowest AS (
      SELECT y.Segment, y.CustomerID, y.total_consumption_2013
      FROM yearly y
      JOIN mins m
        ON m.Segment = y.Segment
       AND m.min_total = y.total_consumption_2013
    )
    SELECT
      Segment,
      SUM(total_consumption_2013) * 1.0 / COUNT(*) AS avg_lowest_consumption
    FROM lowest
    GROUP BY Segment
  )
  WHERE Segment = 'LAM'
) AS lam
JOIN (
  SELECT avg_lowest_consumption
  FROM (
    WITH yearly AS (
      SELECT
        c.Segment,
        ym.CustomerID,
        SUM(ym.Consumption) AS total_consumption_2013
      FROM yearmonth ym
      JOIN customers c ON c.CustomerID = ym.CustomerID
      WHERE ym.Date BETWEEN '201301' AND '201312'
      GROUP BY c.Segment, ym.CustomerID
    ),
    mins AS (
      SELECT Segment, MIN(total_consumption_2013) AS min_total
      FROM yearly
      GROUP BY Segment
    ),
    lowest AS (
      SELECT y.Segment, y.CustomerID, y.total_consumption_2013
      FROM yearly y
      JOIN mins m
        ON m.Segment = y.Segment
       AND m.min_total = y.total_consumption_2013
    )
    SELECT
      Segment,
      SUM(total_consumption_2013) * 1.0 / COUNT(*) AS avg_lowest_consumption
    FROM lowest
    GROUP BY Segment
  )
  WHERE Segment = 'KAM'
) AS kam
LIMIT 1;

-- [7] db_id=debit_card_specializing
SELECT
  Segment,
  pct_increase
FROM (
  SELECT
    c.Segment,
    ((y2013.consumption_2013 - y2012.consumption_2012) / y2013.consumption_2013) * 100.0 AS pct_increase,
    RANK() OVER (ORDER BY ((y2013.consumption_2013 - y2012.consumption_2012) / y2013.consumption_2013) * 100.0 DESC) AS r_biggest,
    RANK() OVER (ORDER BY ((y2013.consumption_2013 - y2012.consumption_2012) / y2013.consumption_2013) * 100.0 ASC) AS r_lowest
  FROM customers c
  JOIN (
    SELECT
      ym.CustomerID,
      SUM(ym.Consumption) AS consumption_2012
    FROM yearmonth ym
    WHERE substr(ym.Date, 1, 4) = '2012'
    GROUP BY ym.CustomerID
  ) y2012 ON y2012.CustomerID = c.CustomerID
  JOIN (
    SELECT
      ym.CustomerID,
      SUM(ym.Consumption) AS consumption_2013
    FROM yearmonth ym
    WHERE substr(ym.Date, 1, 4) = '2013'
    GROUP BY ym.CustomerID
  ) y2013 ON y2013.CustomerID = c.CustomerID
  WHERE c.Currency = 'EUR'
    AND c.Segment IN ('SME','LAM','KAM')
    AND y2013.consumption_2013 IS NOT NULL
    AND y2013.consumption_2013 <> 0
  GROUP BY c.Segment
)
WHERE r_biggest = 1 OR r_lowest = 1
ORDER BY r_biggest, r_lowest;

-- [8] db_id=debit_card_specializing
SELECT SUM(Consumption) AS TotalConsumption
FROM yearmonth
WHERE CustomerID = 6
  AND Date BETWEEN '201308' AND '201311';

-- [9] db_id=debit_card_specializing
SELECT
  SUM(CASE WHEN Country = 'CZE' AND Segment = 'discount' THEN 1 ELSE 0 END) -
  SUM(CASE WHEN Country = 'SVK' AND Segment = 'discount' THEN 1 ELSE 0 END) AS discount_station_difference
FROM gasstations;

-- [10] db_id=debit_card_specializing
SELECT
  CASE WHEN czk_count > eur_count THEN 1 ELSE 0 END AS is_true,
  (czk_count - eur_count) AS how_many_more
FROM (
  SELECT
    SUM(CASE WHEN Currency = 'CZK' THEN 1 ELSE 0 END) AS czk_count,
    SUM(CASE WHEN Currency = 'EUR' THEN 1 ELSE 0 END) AS eur_count
  FROM customers
  WHERE Segment = 'SME'
);

-- [11] db_id=debit_card_specializing
SELECT
  (SUM(CASE WHEN y.Consumption > 46.73 THEN 1 ELSE 0 END) * 100.0) / COUNT(*) AS percent_lam_customers_consumed_more_than_46_73
FROM (
  SELECT
    c.CustomerID,
    MAX(COALESCE(y.Consumption, 0)) AS Consumption
  FROM customers c
  LEFT JOIN yearmonth y
    ON y.CustomerID = c.CustomerID
  WHERE c.Segment = 'LAM'
  GROUP BY c.CustomerID
) AS y;

-- [12] db_id=debit_card_specializing
SELECT
  100.0 * SUM(CASE WHEN Consumption > 528.3 THEN 1 ELSE 0 END) / COUNT(*) AS percentage_customers
FROM yearmonth
WHERE Date = '201202';

-- [13] db_id=debit_card_specializing
SELECT MAX(Consumption) AS HighestMonthlyConsumption2012
FROM yearmonth
WHERE SUBSTR(Date, 1, 4) = '2012';

-- [14] db_id=debit_card_specializing
SELECT DISTINCT p.Description
FROM yearmonth y
JOIN transactions_1k t
  ON t.CustomerID = y.CustomerID
 AND substr(y.Date, 1, 6) = '201309'
JOIN products p
  ON p.ProductID = t.ProductID
WHERE strftime('%Y%m', t.Date) = '201309';

-- [15] db_id=debit_card_specializing
SELECT DISTINCT gs.Country
FROM transactions_1k t
JOIN gasstations gs ON gs.GasStationID = t.GasStationID
WHERE strftime('%Y%m', t.Date) = '201306';

-- [16] db_id=debit_card_specializing
SELECT COUNT(DISTINCT y.CustomerID) AS CustomersOver1000
FROM yearmonth AS y
JOIN customers AS c
  ON c.CustomerID = y.CustomerID
WHERE c.Currency = 'EUR'
  AND y.Consumption > 1000;

-- [17] db_id=debit_card_specializing
SELECT DISTINCT p.Description
FROM transactions_1k t
JOIN gasstations g ON g.GasStationID = t.GasStationID
JOIN products p ON p.ProductID = t.ProductID
WHERE g.Country = 'CZE';

-- [18] db_id=debit_card_specializing
SELECT DISTINCT t.Time
FROM transactions_1k AS t
JOIN gasstations AS g
  ON g.GasStationID = t.GasStationID
WHERE g.ChainID = 11
ORDER BY t.Time;

-- [19] db_id=debit_card_specializing
SELECT COUNT(*) AS transaction_count
FROM transactions_1k t
JOIN gasstations g ON g.GasStationID = t.GasStationID
WHERE g.Country = 'CZE'
  AND DATE(t.Date) > DATE('2012-01-01');

-- [20] db_id=debit_card_specializing
SELECT c.Currency
FROM transactions_1k t
JOIN customers c ON c.CustomerID = t.CustomerID
WHERE t.Date = '2012-08-24'
  AND t.Time = '16:25:00';

-- [21] db_id=debit_card_specializing
SELECT c.Segment
FROM transactions_1k t
JOIN customers c ON c.CustomerID = t.CustomerID
WHERE t.Date = '2012-08-23'
  AND t.Time = '21:20:00'
LIMIT 1

-- [22] db_id=debit_card_specializing
SELECT COUNT(*) AS transaction_count
FROM transactions_1k t
JOIN gasstations g ON g.GasStationID = t.GasStationID
WHERE t.Date = '2012-08-26'
  AND t.Time BETWEEN '08:00:00' AND '09:00:00'
  AND g.Country = 'CZE';

-- [23] db_id=debit_card_specializing
SELECT gs.Country
FROM transactions_1k t
JOIN gasstations gs ON gs.GasStationID = t.GasStationID
WHERE t.Date = '2012-08-24'
  AND t.Price = 548.4
LIMIT 1;

-- [24] db_id=debit_card_specializing
SELECT
  100.0 * SUM(CASE WHEN c.Currency = 'EUR' THEN 1 ELSE 0 END) / COUNT(*) AS percentage_customers_eur
FROM (
  SELECT DISTINCT t.CustomerID
  FROM transactions_1k t
  WHERE t.Date = '2012-08-25'
) d
JOIN customers c ON c.CustomerID = d.CustomerID;

-- [25] db_id=debit_card_specializing
SELECT (y2012.Consumption - y2013.Consumption) * 1.0 / y2012.Consumption AS consumption_decrease_rate
FROM (
    SELECT CustomerID
    FROM transactions_1k
    WHERE Date = '2012-08-25' AND Price = 634.8
    LIMIT 1
) c
JOIN yearmonth y2012
  ON y2012.CustomerID = c.CustomerID
 AND substr(y2012.Date, 1, 4) = '2012'
JOIN yearmonth y2013
  ON y2013.CustomerID = c.CustomerID
 AND substr(y2013.Date, 1, 4) = '2013';

-- [26] db_id=debit_card_specializing
SELECT
  100.0 * SUM(CASE WHEN Segment = 'premium' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS premium_percentage
FROM gasstations
WHERE Country = 'SVK';

-- [27] db_id=debit_card_specializing
SELECT
  SUM(t.Amount * t.Price) AS total_spent_at_gas_stations,
  SUM(CASE WHEN ym.Date = '201201' THEN ym.Consumption ELSE 0 END) AS spent_in_january_2012
FROM transactions_1k t
LEFT JOIN yearmonth ym
  ON ym.CustomerID = t.CustomerID
WHERE t.CustomerID = 38508;

-- [28] db_id=debit_card_specializing
SELECT
  t.CustomerID,
  SUM(t.Price) AS TotalSpending,
  SUM(t.Price) * 1.0 / NULLIF(SUM(t.Amount), 0) AS AvgPricePerSingleItem,
  c.Currency
FROM transactions_1k t
JOIN customers c ON c.CustomerID = t.CustomerID
GROUP BY t.CustomerID, c.Currency
ORDER BY TotalSpending DESC
LIMIT 1

-- [29] db_id=debit_card_specializing
SELECT
  y.CustomerID,
  y.Consumption
FROM yearmonth AS y
WHERE y.Date = '201208'
  AND y.CustomerID IN (
    SELECT DISTINCT t.CustomerID
    FROM transactions_1k AS t
    WHERE t.ProductID = 5
      AND t.Amount IS NOT NULL
      AND t.Amount <> 0
      AND (t.Price * 1.0 / t.Amount) > 29.00
      AND t.CustomerID IS NOT NULL
  );

-- [30] db_id=student_club
SELECT maj.major_name
FROM member AS m
JOIN major AS maj
  ON maj.major_id = m.link_to_major
WHERE m.first_name = 'Angela'
  AND m.last_name = 'Sanders';

-- [31] db_id=student_club
SELECT COUNT(DISTINCT m.member_id) AS medium_tshirt_count
FROM attendance a
JOIN event e ON e.event_id = a.link_to_event
JOIN member m ON m.member_id = a.link_to_member
WHERE e.event_name = 'Women''s Soccer'
  AND m.t_shirt_size = 'Medium';

-- [32] db_id=student_club
SELECT COUNT(*) AS meeting_events_over_10_attendees
FROM (
  SELECT e.event_id
  FROM event e
  JOIN attendance a ON a.link_to_event = e.event_id
  GROUP BY e.event_id
  HAVING COUNT(a.link_to_member) > 10
     AND MAX(CASE WHEN e.type = 'Meeting' THEN 1 ELSE 0 END) = 1
);

-- [33] db_id=student_club
SELECT e.event_name
FROM event AS e
JOIN attendance AS a
  ON a.link_to_event = e.event_id
WHERE e.type <> 'fundraiser'
GROUP BY e.event_id, e.event_name
HAVING COUNT(a.link_to_member) > 20;

-- [34] db_id=student_club
SELECT i.amount
FROM income AS i
JOIN member AS m
  ON m.member_id = i.link_to_member
WHERE m.position = 'Vice President';

-- [35] db_id=student_club
SELECT m.first_name || ' ' || m.last_name AS full_name
FROM member AS m
JOIN zip_code AS z
  ON z.zip_code = m.zip
WHERE z.state = 'Illinois' OR z.short_state = 'IL';

-- [36] db_id=student_club
SELECT
  e.expense_id,
  e.expense_description,
  CASE
    WHEN LOWER(e.approved) IN ('true','t','1','yes','y') THEN 'True'
    WHEN LOWER(e.approved) IN ('false','f','0','no','n') THEN 'False'
    ELSE e.approved
  END AS approved
FROM expense e
JOIN budget b ON b.budget_id = e.link_to_budget
JOIN event ev ON ev.event_id = b.link_to_event
WHERE ev.event_name = 'October Meeting'
  AND ev.event_date = '2019-10-08';

-- [37] db_id=student_club
SELECT AVG(e.cost) AS avg_cost
FROM expense e
JOIN member m ON m.member_id = e.link_to_member
WHERE m.first_name = 'Elijah'
  AND m.last_name = 'Allen'
  AND CAST(SUBSTR(e.expense_date, 6, 2) AS INTEGER) IN (9, 10);

-- [38] db_id=student_club
SELECT
  COALESCE(SUM(CASE WHEN SUBSTR(e.event_date, 1, 4) = '2019' THEN b.spent ELSE 0 END), 0)
  - COALESCE(SUM(CASE WHEN SUBSTR(e.event_date, 1, 4) = '2020' THEN b.spent ELSE 0 END), 0) AS spent_difference_2019_minus_2020
FROM budget b
JOIN event e ON e.event_id = b.link_to_event;

-- [39] db_id=student_club
SELECT notes
FROM income
WHERE source = 'Fundraising'
  AND date_received = '2019-09-14';

-- [40] db_id=student_club
SELECT phone
FROM member
WHERE first_name = 'Carlo'
  AND last_name = 'Jacobs';

-- [41] db_id=student_club
SELECT b.event_status
FROM expense AS e
JOIN budget AS b ON b.budget_id = e.link_to_budget
WHERE e.expense_description = 'Post Cards, Posters'
  AND e.expense_date = '2019-8-20';

-- [42] db_id=student_club
SELECT mj.major_name
FROM member AS m
JOIN major AS mj
  ON mj.major_id = m.link_to_major
WHERE m.first_name = 'Brent'
  AND m.last_name = 'Thomason';

-- [43] db_id=student_club
SELECT COUNT(*) AS medium_business_count
FROM member m
JOIN major maj ON maj.major_id = m.link_to_major
WHERE maj.major_name = 'Business'
  AND m.t_shirt_size = 'Medium';

-- [44] db_id=student_club
SELECT mj.department
FROM member AS m
JOIN major AS mj
  ON m.link_to_major = mj.major_id
WHERE m.position = 'President';

-- [45] db_id=student_club
SELECT i.date_received
FROM income AS i
JOIN member AS m
  ON i.link_to_member = m.member_id
WHERE m.first_name = 'Connor'
  AND m.last_name = 'Hilton'
  AND i.source = 'Dues';

-- [46] db_id=student_club
SELECT
  1.0 * SUM(CASE WHEN e.event_name = 'Yearly Kickoff' THEN b.amount ELSE 0 END) /
  NULLIF(SUM(CASE WHEN e.event_name = 'October Meeting' THEN b.amount ELSE 0 END), 0) AS times_more
FROM budget b
JOIN event e ON e.event_id = b.link_to_event
WHERE b.category = 'Advertisement';

-- [47] db_id=student_club
SELECT COALESCE(SUM(cost), 0) AS total_pizza_cost
FROM expense
WHERE expense_description = 'Pizza';

-- [48] db_id=student_club
SELECT COUNT(DISTINCT city)
FROM zip_code
WHERE county = 'Orange County'
  AND state = 'Virginia';

-- [49] db_id=student_club
SELECT maj.major_name
FROM member AS m
JOIN major AS maj ON maj.major_id = m.link_to_major
WHERE m.phone = '809-555-3360';

-- [50] db_id=student_club
SELECT COUNT(DISTINCT a.link_to_member) AS members_attended
FROM attendance AS a
JOIN event AS e ON e.event_id = a.link_to_event
WHERE e.event_name = 'Women''s Soccer';

-- [51] db_id=student_club
SELECT m.first_name || ' ' || m.last_name AS full_name
FROM member AS m
JOIN major AS mj
  ON m.link_to_major = mj.major_id
WHERE mj.department = 'School of Applied Sciences, Technology and Education';

-- [52] db_id=student_club
SELECT
  e.event_id,
  e.event_name,
  CAST(b.spent AS REAL) / NULLIF(CAST(b.amount AS REAL), 0) AS spend_to_budget_ratio
FROM event AS e
JOIN budget AS b
  ON b.link_to_event = e.event_id
WHERE e.status = 'Closed'
ORDER BY spend_to_budget_ratio DESC
LIMIT 1;

-- [53] db_id=student_club
SELECT MAX(spent) AS highest_budget_spent
FROM budget;

-- [54] db_id=student_club
SELECT SUM(spent) AS total_food_spent
FROM budget
WHERE category = 'Food';

-- [55] db_id=student_club
SELECT
  m.first_name || ' ' || m.last_name AS full_name
FROM member AS m
JOIN attendance AS a
  ON a.link_to_member = m.member_id
GROUP BY
  m.member_id,
  m.first_name,
  m.last_name
HAVING COUNT(a.link_to_event) > 7;

-- [56] db_id=student_club
SELECT m.first_name || ' ' || m.last_name AS full_name
FROM event e
JOIN budget b ON b.link_to_event = e.event_id
JOIN expense x ON x.link_to_budget = b.budget_id
JOIN member m ON m.member_id = x.link_to_member
WHERE e.event_name = 'Yearly Kickoff'
LIMIT 1;

-- [57] db_id=student_club
SELECT e.event_name
FROM event AS e
JOIN budget AS b ON b.link_to_event = e.event_id
JOIN expense AS ex ON ex.link_to_budget = b.budget_id
WHERE ex.cost = (
  SELECT MIN(cost)
  FROM expense
);

-- [58] db_id=student_club
SELECT
  (SUM(CASE WHEN e.event_name = 'Yearly Kickoff' THEN ex.cost ELSE 0 END) * 100.0) / NULLIF(SUM(ex.cost), 0) AS yearly_kickoff_cost_percentage
FROM event e
JOIN budget b ON b.link_to_event = e.event_id
JOIN expense ex ON ex.link_to_budget = b.budget_id;

-- [59] db_id=student_club
SELECT MAX(source) AS top_source
FROM income
WHERE date_received BETWEEN '2019-09-01' AND '2019-09-30';

-- [60] db_id=student_club
SELECT COUNT(*) AS physics_teaching_member_count
FROM member m
JOIN major maj ON maj.major_id = m.link_to_major
WHERE maj.major_name = 'Physics Teaching';

-- [61] db_id=student_club
SELECT e.event_name
FROM budget b
JOIN event e ON e.event_id = b.link_to_event
WHERE b.category = 'Advertisement'
ORDER BY b.spent DESC
LIMIT 1

-- [62] db_id=student_club
SELECT
  CASE WHEN COUNT(*) > 0 THEN 'Yes' ELSE 'No' END AS attended
FROM attendance a
JOIN member m ON m.member_id = a.link_to_member
JOIN event e ON e.event_id = a.link_to_event
WHERE m.first_name = 'Maya'
  AND m.last_name = 'Mclean'
  AND e.event_name = 'Women''s Soccer';

-- [63] db_id=student_club
SELECT e.cost
FROM expense AS e
JOIN budget AS b ON b.budget_id = e.link_to_budget
JOIN event AS ev ON ev.event_id = b.link_to_event
WHERE e.expense_description = 'Posters'
  AND ev.event_name = 'September Speaker';

-- [64] db_id=student_club
SELECT e.event_name
FROM event e
JOIN budget b ON b.link_to_event = e.event_id
WHERE e.status = 'Closed'
  AND b.remaining < 0
ORDER BY b.remaining ASC
LIMIT 1

-- [65] db_id=student_club
SELECT
  b.category AS expense_type,
  SUM(e.cost) AS total_value
FROM event ev
JOIN budget b
  ON b.link_to_event = ev.event_id
JOIN expense e
  ON e.link_to_budget = b.budget_id
WHERE ev.event_name = 'October Meeting'
  AND e.approved = 'Yes'
GROUP BY b.category;

-- [66] db_id=student_club
SELECT
  b.category,
  SUM(b.amount) AS amount_budgeted
FROM budget AS b
JOIN event AS e
  ON e.event_id = b.link_to_event
WHERE e.event_name = 'April Speaker'
GROUP BY b.category
ORDER BY amount_budgeted ASC;

-- [67] db_id=student_club
SELECT SUM(cost) AS total_expense
FROM expense
WHERE expense_date = '2019-08-20';

-- [68] db_id=student_club
SELECT
  m.first_name || ' ' || m.last_name AS full_name,
  COALESCE(SUM(e.cost), 0) AS total_cost
FROM member AS m
LEFT JOIN expense AS e
  ON e.link_to_member = m.member_id
WHERE m.member_id = 'rec4BLdZHS2Blfp4v'
GROUP BY m.member_id, m.first_name, m.last_name;

-- [69] db_id=student_club
SELECT DISTINCT e.expense_description
FROM member m
JOIN expense e ON e.link_to_member = m.member_id
WHERE m.first_name = 'Sacha'
  AND m.last_name = 'Harrison';

-- [70] db_id=student_club
SELECT DISTINCT type
FROM event
WHERE location = 'MU 215';

-- [71] db_id=student_club
SELECT
  m.last_name,
  maj.department,
  maj.college
FROM member AS m
JOIN major AS maj
  ON m.link_to_major = maj.major_id
WHERE maj.major_name = 'Environmental Engineering';

-- [72] db_id=student_club
SELECT b.category
FROM event AS e
JOIN budget AS b
  ON b.link_to_event = e.event_id
WHERE e.location = 'MU 215'
  AND e.type = 'Guest Speaker'
  AND b.spent = 0;

-- [73] db_id=student_club
SELECT
  (CAST(SUM(CASE WHEN i.amount = 50 AND i.source = 'Student_Club' THEN 1 ELSE 0 END) AS REAL) / COUNT(DISTINCT m.member_id)) * 100.0 AS percentage
FROM member AS m
LEFT JOIN income AS i
  ON i.link_to_member = m.member_id
WHERE m.t_shirt_size = 'Medium'
  AND m.position = 'Member';

-- [74] db_id=student_club
SELECT event_name
FROM event
WHERE type = 'Game'
  AND status = 'Closed'
  AND event_date BETWEEN '2019-03-15' AND '2020-03-20';

-- [75] db_id=student_club
SELECT DISTINCT
  m.first_name || ' ' || m.last_name AS full_name,
  m.phone AS contact_number
FROM expense e
JOIN member m
  ON m.member_id = e.link_to_member
WHERE e.cost > (SELECT AVG(cost) FROM expense);

-- [76] db_id=student_club
SELECT
  m.first_name || ' ' || m.last_name AS full_name,
  e.cost
FROM expense e
JOIN member m
  ON m.member_id = e.link_to_member
WHERE e.expense_description = 'Water, Veggie tray, supplies';

-- [77] db_id=student_club
SELECT m.first_name || ' ' || m.last_name AS full_name,
       i.amount
FROM income AS i
JOIN member AS m
  ON m.member_id = i.link_to_member
WHERE i.date_received = '9/9/2019';

-- [78] db_id=thrombosis_prediction
SELECT
  CASE
    WHEN male_inpatients > male_outpatients THEN 'in-patient'
    WHEN male_inpatients < male_outpatients THEN 'outpatient'
    ELSE 'equal'
  END AS more_male_group,
  CASE
    WHEN male_outpatients = 0 THEN NULL
    ELSE (male_inpatients * 100.0) / male_outpatients
  END AS deviation_percentage
FROM (
  SELECT
    SUM(CASE WHEN SEX = 'M' AND Admission = '+' THEN 1 ELSE 0 END) AS male_inpatients,
    SUM(CASE WHEN SEX = 'M' AND Admission = '-' THEN 1 ELSE 0 END) AS male_outpatients
  FROM Patient
);

-- [79] db_id=thrombosis_prediction
SELECT
  1.0 * SUM(CASE WHEN SEX = 'F' AND CAST(strftime('%Y', Birthday) AS INTEGER) > 1930 THEN 1 ELSE 0 END)
  / NULLIF(SUM(CASE WHEN SEX = 'F' THEN 1 ELSE 0 END), 0) AS percentage_female_born_after_1930
FROM Patient;

-- [80] db_id=thrombosis_prediction
SELECT
  CAST(SUM(CASE WHEN Diagnosis = 'SLE' AND Admission = '+' THEN 1 ELSE 0 END) AS REAL) /
  NULLIF(SUM(CASE WHEN Diagnosis = 'SLE' AND Admission = '-' THEN 1 ELSE 0 END), 0) AS outpatient_to_inpatient_ratio
FROM Patient;

-- [81] db_id=thrombosis_prediction
SELECT
  p.Diagnosis AS Disease,
  l.Date AS Lab_Test_Date
FROM Patient AS p
LEFT JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE p.ID = 30609
ORDER BY l.Date;

-- [82] db_id=thrombosis_prediction
SELECT DISTINCT p.ID,
       p.SEX,
       p.Birthday
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE l.LDH > 500;

-- [83] db_id=thrombosis_prediction
SELECT
  p.ID,
  (CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) AS age
FROM Patient AS p
JOIN Examination AS e
  ON e.ID = p.ID
WHERE e.RVVT = '+';

-- [84] db_id=thrombosis_prediction
SELECT
  p.ID,
  p.SEX,
  e.Diagnosis
FROM Examination AS e
JOIN Patient AS p
  ON p.ID = e.ID
WHERE e.Thrombosis = 2;

-- [85] db_id=thrombosis_prediction
SELECT COUNT(*) AS female_patients_1997_outpatient
FROM Patient
WHERE SEX = 'F'
  AND strftime('%Y', Description) = '1997'
  AND Admission = '-'

-- [86] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient AS p
JOIN Examination AS e
  ON e.ID = p.ID
WHERE p.SEX = 'F'
  AND e.Thrombosis = 1
  AND strftime('%Y', e.`Examination Date`) = '1997';

-- [87] db_id=thrombosis_prediction
SELECT
  e.Symptoms,
  p.Diagnosis
FROM Examination AS e
JOIN Patient AS p
  ON p.ID = e.ID
WHERE e.Symptoms IS NOT NULL
  AND p.Birthday IS NOT NULL
  AND p.Birthday = (
    SELECT MAX(p2.Birthday)
    FROM Examination AS e2
    JOIN Patient AS p2
      ON p2.ID = e2.ID
    WHERE e2.Symptoms IS NOT NULL
      AND p2.Birthday IS NOT NULL
  );

-- [88] db_id=thrombosis_prediction
SELECT
  l.Date AS oldest_sjs_lab_date,
  CAST(strftime('%Y', p."First Date") AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER) AS age_at_initial_arrival
FROM Patient p
JOIN Laboratory l
  ON l.ID = p.ID
WHERE p.Diagnosis = 'SJS'
ORDER BY p.Birthday ASC, l.Date ASC
LIMIT 1;

-- [89] db_id=thrombosis_prediction
SELECT
  1.0 * SUM(CASE WHEN p.SEX = 'M' AND l.UA <= 8.0 THEN 1 ELSE 0 END) /
  NULLIF(SUM(CASE WHEN p.SEX = 'F' AND l.UA <= 6.5 THEN 1 ELSE 0 END), 0) AS male_to_female_ratio
FROM Laboratory l
JOIN Patient p ON p.ID = l.ID;

-- [90] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT e.ID) AS underage_examined_patients
FROM Examination e
JOIN Patient p ON p.ID = e.ID
WHERE CAST(strftime('%Y', e.`Examination Date`) AS INTEGER) BETWEEN 1990 AND 1993
  AND (CAST(strftime('%Y', e.`Examination Date`) AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) < 18;

-- [91] db_id=thrombosis_prediction
SELECT 
  (CAST(strftime('%Y', e."Examination Date") AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) AS Age,
  e.Diagnosis
FROM Examination e
JOIN Patient p ON p.ID = e.ID
JOIN Laboratory l ON l.ID = e.ID AND l.Date = e."Examination Date"
WHERE l.HGB = (SELECT MAX(HGB) FROM Laboratory)
LIMIT 1

-- [92] db_id=thrombosis_prediction
SELECT e.`aCL IgM`
FROM Patient p
JOIN Examination e ON e.ID = p.ID
WHERE p.Diagnosis = 'SLE'
  AND p.Description = '1994-02-19'
  AND e.`Examination Date` = '1993-11-12';

-- [93] db_id=thrombosis_prediction
SELECT
  (SUM(CASE WHEN p.Birthday = '1959-02-18' AND l.Date LIKE '1981-11-%' THEN l.`T-CHO` ELSE 0 END) -
   SUM(CASE WHEN p.Birthday = '1959-02-18' AND l.Date LIKE '1981-12-%' THEN l.`T-CHO` ELSE 0 END)) * 1.0
  / NULLIF(SUM(CASE WHEN p.Birthday = '1959-02-18' AND l.Date LIKE '1981-12-%' THEN l.`T-CHO` ELSE 0 END), 0) AS decrease_rate
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID;

-- [94] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT l.ID) AS patient_count
FROM Laboratory l
WHERE l.Date BETWEEN '1987-07-06' AND '1996-01-31'
  AND l.GPT > 30
  AND l.ALB < 4;

SELECT DISTINCT l.ID
FROM Laboratory l
WHERE l.Date BETWEEN '1987-07-06' AND '1996-01-31'
  AND l.GPT > 30
  AND l.ALB < 4
ORDER BY l.ID;

-- [95] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT e.ID) AS patient_count
FROM Examination e
WHERE e.Thrombosis = 2
  AND e.ANA = 'S'
  AND e.`aCL IgM` > (
    SELECT AVG(`aCL IgM`) * 1.2
    FROM Examination
  );

-- [96] db_id=thrombosis_prediction
SELECT DISTINCT p.*
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE p.Admission = '-'
  AND l.Date LIKE '1991-10%'
  AND l.`T-BIL` < 2.0;

-- [97] db_id=thrombosis_prediction
SELECT AVG(l.ALB) AS avg_albumin
FROM Laboratory AS l
JOIN Patient AS p ON p.ID = l.ID
WHERE p.SEX = 'F'
  AND p.Diagnosis = 'SLE'
  AND l.PLT > 400;

-- [98] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID) AS female_aps_patients
FROM Patient AS p
WHERE p.SEX = 'F'
  AND p.Diagnosis = 'APS';

-- [99] db_id=thrombosis_prediction
SELECT
  100.0 * SUM(CASE WHEN SEX = 'F' THEN 1 ELSE 0 END) / COUNT(SEX) AS percentage_women
FROM Patient
WHERE strftime('%Y', Birthday) = '1980'
  AND Diagnosis = 'RA';

-- [100] db_id=thrombosis_prediction
SELECT
  CASE
    WHEN p.SEX = 'M' AND l.UA > 8.0 THEN 'Yes'
    WHEN p.SEX = 'F' AND l.UA > 6.5 THEN 'Yes'
    ELSE 'No'
  END AS "UA within normal range"
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID
WHERE p.ID = 57266
ORDER BY l.Date DESC
LIMIT 1;

-- [101] db_id=thrombosis_prediction
SELECT DISTINCT p.ID
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE p.SEX = 'M'
  AND l.GPT >= 60;

-- [102] db_id=thrombosis_prediction
SELECT DISTINCT p.Diagnosis
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE l.GPT > 60
ORDER BY p.Birthday ASC;

-- [103] db_id=thrombosis_prediction
SELECT DISTINCT p.ID, p.SEX, p.Birthday
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE l.UN = 29;

-- [104] db_id=thrombosis_prediction
SELECT
  p.SEX,
  GROUP_CONCAT(DISTINCT p.ID) AS patient_ids
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE l.`T-BIL` >= 2.0
GROUP BY p.SEX;

-- [105] db_id=thrombosis_prediction
SELECT
  AVG((CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER))) AS average_age
FROM Patient p
JOIN Laboratory l
  ON l.ID = p.ID
WHERE p.SEX = 'M'
  AND l.`T-CHO` >= 250;

-- [106] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID
WHERE l.TG >= 200
  AND (CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) > 50;

-- [107] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE p.SEX = 'M'
  AND CAST(strftime('%Y', p.Birthday) AS INTEGER) BETWEEN 1936 AND 1956
  AND l.CPK >= 250;

-- [108] db_id=thrombosis_prediction
SELECT
  p.ID,
  p.SEX,
  (CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) AS age
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE l.GLU >= 180
  AND l.`T-CHO` < 250;

-- [109] db_id=thrombosis_prediction
SELECT
  p.ID,
  p.Diagnosis,
  (CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) AS age
FROM Patient AS p
WHERE EXISTS (
  SELECT 1
  FROM Laboratory AS l
  WHERE l.ID = p.ID
    AND l.RBC < 3.5
);

-- [110] db_id=thrombosis_prediction
SELECT p.ID, p.SEX
FROM Patient AS p
WHERE p.Diagnosis = 'SLE'
  AND EXISTS (
    SELECT 1
    FROM Laboratory AS l
    WHERE l.ID = p.ID
      AND l.HGB > 10
      AND l.HGB < 17
  )
ORDER BY p.Birthday ASC
LIMIT 1;

-- [111] db_id=thrombosis_prediction
SELECT
  p.ID,
  CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER) AS age
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID
WHERE l.HCT >= 52
GROUP BY p.ID
HAVING COUNT(*) > 2;

-- [112] db_id=thrombosis_prediction
SELECT
  COUNT(DISTINCT CASE WHEN PLT < 100 THEN ID END) AS patients_lower_than_normal,
  COUNT(DISTINCT CASE WHEN PLT > 400 THEN ID END) AS patients_higher_than_normal,
  COUNT(DISTINCT CASE WHEN PLT < 100 THEN ID END) - COUNT(DISTINCT CASE WHEN PLT > 400 THEN ID END) AS lower_minus_higher
FROM Laboratory
WHERE PLT <= 100 OR PLT >= 400;

-- [113] db_id=thrombosis_prediction
SELECT DISTINCT p.ID
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE strftime('%Y', l.Date) = '1984'
  AND (CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) < 50
  AND l.PLT BETWEEN 100 AND 400;

-- [114] db_id=thrombosis_prediction
SELECT
  100.0 * SUM(CASE WHEN p.SEX = 'F' AND l.PT >= 14 THEN 1 ELSE 0 END)
       / NULLIF(SUM(CASE WHEN l.PT >= 14 THEN 1 ELSE 0 END), 0) AS female_abnormal_pt_percentage
FROM Patient p
JOIN Laboratory l
  ON l.ID = p.ID
WHERE (CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)) > 55;

-- [115] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT l.ID) AS abnormal_fg_male_normal_wbc_patients
FROM Laboratory l
JOIN Patient p ON p.ID = l.ID
WHERE p.SEX = 'M'
  AND l.WBC > 3.5 AND l.WBC < 9.0
  AND (l.FG <= 150 OR l.FG >= 450);

-- [116] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT l.ID) AS patients_with_high_igg
FROM Laboratory AS l
WHERE l.IGG >= 2000;

-- [117] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID) AS symptom_patient_count
FROM Patient p
JOIN Laboratory l
  ON l.ID = p.ID
JOIN Examination e
  ON e.ID = p.ID
WHERE l.IGG > 900
  AND l.IGG < 2000
  AND e.Symptoms IS NOT NULL;

-- [118] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient p
JOIN Laboratory l
  ON l.ID = p.ID
WHERE p.`First Date` >= '1990-01-01'
  AND l.IGA > 80
  AND l.IGA < 500;

-- [119] db_id=thrombosis_prediction
SELECT p.Diagnosis, COUNT(*) AS cnt
FROM Patient AS p
WHERE EXISTS (
  SELECT 1
  FROM Laboratory AS l
  WHERE l.ID = p.ID
    AND l.IGM IS NOT NULL
    AND (l.IGM <= 40 OR l.IGM >= 400)
)
  AND p.Diagnosis IS NOT NULL
GROUP BY p.Diagnosis
ORDER BY cnt DESC
LIMIT 1;

-- [120] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID
WHERE l.CRP = '+'
  AND p.Description IS NULL;

-- [121] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE l.CRE >= 1.5
  AND (
    CAST(strftime('%Y', 'now') AS INTEGER) - CAST(strftime('%Y', p.Birthday) AS INTEGER)
  ) < 70;

-- [122] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID
WHERE p.Admission = '+'
  AND l.RNP IN ('-', '+-');

-- [123] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID
JOIN Examination e ON e.ID = p.ID
WHERE l.SM IN ('-', '+-')
  AND e.Thrombosis = 0;

-- [124] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID) AS female_no_symptom_normal_scl70
FROM Patient p
JOIN Laboratory l ON l.ID = p.ID
LEFT JOIN Examination e ON e.ID = p.ID
WHERE p.SEX = 'F'
  AND l.SC170 IN ('negative', '0')
  AND e.Symptoms IS NULL;

-- [125] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT p.ID)
FROM Patient AS p
JOIN Laboratory AS l
  ON l.ID = p.ID
WHERE p.SEX = 'M'
  AND l.CENTROMEA IN ('-', '+-')
  AND l.SSB IN ('-', '+-');

-- [126] db_id=thrombosis_prediction
SELECT MAX(p.Birthday) AS youngest_birthday
FROM Patient p
WHERE p.ID IN (
  SELECT l.ID
  FROM Laboratory l
  WHERE l.GOT >= 60
);

-- [127] db_id=thrombosis_prediction
SELECT COUNT(DISTINCT l.ID) AS patient_count
FROM Laboratory AS l
JOIN Examination AS e
  ON e.ID = l.ID
WHERE l.CPK < 250
  AND (e.KCT = '+' OR e.RVVT = '+' OR e.LAC = '+');

-- [128] db_id=european_football_2
SELECT l.name
FROM "Match" m
JOIN League l ON l.id = m.league_id
WHERE m.season = '2015/2016'
GROUP BY m.league_id
ORDER BY SUM(COALESCE(m.home_team_goal,0) + COALESCE(m.away_team_goal,0)) DESC
LIMIT 1;

-- [129] db_id=european_football_2
SELECT t.team_long_name
FROM Match m
JOIN League l ON l.id = m.league_id
JOIN Team t ON t.team_api_id = m.away_team_api_id
WHERE l.name = 'Scotland Premier League'
  AND m.season = '2009/2010'
  AND m.away_team_goal > m.home_team_goal
GROUP BY m.away_team_api_id
ORDER BY COUNT(*) DESC
LIMIT 1;

-- [130] db_id=european_football_2
SELECT
  t.team_long_name,
  MAX(ta.buildUpPlaySpeed) AS buildUpPlaySpeed
FROM Team_Attributes ta
JOIN Team t
  ON t.team_api_id = ta.team_api_id
GROUP BY
  t.team_api_id,
  t.team_long_name
ORDER BY
  buildUpPlaySpeed DESC
LIMIT 4;

-- [131] db_id=european_football_2
SELECT l.name
FROM "Match" m
JOIN League l ON l.id = m.league_id
WHERE m.season = '2015/2016'
GROUP BY l.id, l.name
ORDER BY SUM(CASE WHEN m.home_team_goal = m.away_team_goal THEN 1 ELSE 0 END) DESC
LIMIT 1

-- [132] db_id=european_football_2
SELECT
  p.player_api_id,
  p.player_name,
  CAST((julianday('now') - julianday(p.birthday)) / 365.25 AS INTEGER) AS age_years
FROM Player_Attributes pa
JOIN Player p
  ON p.player_api_id = pa.player_api_id
WHERE pa.sprint_speed >= 97
  AND strftime('%Y', pa.date) BETWEEN '2013' AND '2015'
GROUP BY p.player_api_id, p.player_name, age_years;

-- [133] db_id=european_football_2
SELECT
  l.name AS league_name,
  COUNT(*) AS match_count
FROM "Match" m
JOIN League l ON l.id = m.league_id
GROUP BY m.league_id
ORDER BY match_count DESC
LIMIT 1;

-- [134] db_id=european_football_2
SELECT DISTINCT team_fifa_api_id
FROM Team_Attributes
WHERE buildUpPlaySpeed > 50
  AND buildUpPlaySpeed < 60;

-- [135] db_id=european_football_2
SELECT DISTINCT t.team_long_name
FROM Team_Attributes ta
JOIN Team t
  ON t.team_api_id = ta.team_api_id
WHERE strftime('%Y', ta.date) = '2012'
  AND ta.buildUpPlayPassing IS NOT NULL
  AND ta.buildUpPlayPassing > (
    SELECT SUM(buildUpPlayPassing) * 1.0 / COUNT(*)
    FROM Team_Attributes
    WHERE strftime('%Y', date) = '2012'
      AND buildUpPlayPassing IS NOT NULL
  );

-- [136] db_id=european_football_2
SELECT
  100.0 * SUM(CASE WHEN pa.preferred_foot = 'left' THEN 1 ELSE 0 END) / COUNT(pa.player_fifa_api_id) AS pct_left_foot
FROM Player_Attributes pa
JOIN Player p ON p.player_api_id = pa.player_api_id
WHERE CAST(strftime('%Y', p.birthday) AS INTEGER) BETWEEN 1987 AND 1992;

-- [137] db_id=european_football_2
SELECT
  SUM(pa.long_shots) * 1.0 / COUNT(pa.player_fifa_api_id) AS avg_long_shots
FROM Player_Attributes AS pa
JOIN Player AS p
  ON p.player_api_id = pa.player_api_id
WHERE p.player_name = 'Ahmed Samir Farag'
  AND pa.long_shots IS NOT NULL
  AND pa.player_fifa_api_id IS NOT NULL;

-- [138] db_id=european_football_2
SELECT
  p.player_name
FROM Player AS p
JOIN Player_Attributes AS pa
  ON pa.player_fifa_api_id = p.player_fifa_api_id
WHERE p.height > 180
  AND pa.heading_accuracy IS NOT NULL
GROUP BY p.player_fifa_api_id, p.player_name
ORDER BY (SUM(pa.heading_accuracy) * 1.0) / COUNT(pa.player_fifa_api_id) DESC
LIMIT 10;

-- [139] db_id=european_football_2
SELECT l.name
FROM "Match" m
JOIN League l ON l.id = m.league_id
WHERE m.season = '2009/2010'
GROUP BY l.id, l.name
HAVING (SUM(m.home_team_goal) * 1.0) / COUNT(DISTINCT m.id) > (SUM(m.away_team_goal) * 1.0) / COUNT(DISTINCT m.id);

-- [140] db_id=european_football_2
SELECT
  player_name,
  birthday
FROM Player
WHERE substr(birthday, 1, 4) = '1970'
  AND substr(birthday, 6, 2) = '10'
ORDER BY player_name;

-- [141] db_id=european_football_2
SELECT pa.overall_rating
FROM Player_Attributes AS pa
JOIN Player AS p
  ON p.player_api_id = pa.player_api_id
WHERE p.player_name = 'Gabriel Tamas'
  AND strftime('%Y', pa.date) = '2011'
ORDER BY pa.date DESC
LIMIT 1;

-- [142] db_id=european_football_2
SELECT AVG(m.home_team_goal) AS avg_home_team_goal
FROM "Match" AS m
JOIN Country AS c
  ON c.id = m.country_id
WHERE c.name = 'Poland'
  AND m.season = '2010/2011';

-- [143] db_id=european_football_2
SELECT
  p.player_name,
  CASE
    WHEN p.height = h.max_height THEN 'highest'
    WHEN p.height = h.min_height THEN 'shortest'
  END AS height_group,
  AVG(pa.finishing) AS avg_finishing
FROM Player p
JOIN Player_Attributes pa
  ON pa.player_api_id = p.player_api_id
CROSS JOIN (
  SELECT MAX(height) AS max_height, MIN(height) AS min_height
  FROM Player
) h
WHERE p.height IN (h.max_height, h.min_height)
GROUP BY p.player_api_id, p.player_name, height_group
ORDER BY avg_finishing DESC
LIMIT 1;

-- [144] db_id=european_football_2
SELECT SUM(pa.overall_rating) * 1.0 / COUNT(pa.id) AS avg_overall_rating
FROM Player_Attributes AS pa
JOIN Player AS p
  ON p.player_api_id = pa.player_api_id
WHERE p.height > 170
  AND strftime('%Y', pa.date) >= '2010'
  AND strftime('%Y', pa.date) <= '2015'
  AND pa.overall_rating IS NOT NULL;

-- [145] db_id=european_football_2
SELECT
  (
    SUM(CASE WHEN p.player_name = 'Abdou Diallo' THEN pa.ball_control ELSE 0 END) * 1.0
    / NULLIF(COUNT(CASE WHEN p.player_name = 'Abdou Diallo' THEN pa.id ELSE NULL END), 0)
  )
  -
  (
    SUM(CASE WHEN p.player_name = 'Aaron Appindangoye' THEN pa.ball_control ELSE 0 END) * 1.0
    / NULLIF(COUNT(CASE WHEN p.player_name = 'Aaron Appindangoye' THEN pa.id ELSE NULL END), 0)
  ) AS diff_avg_ball_control
FROM Player_Attributes pa
JOIN Player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name IN ('Abdou Diallo', 'Aaron Appindangoye');

-- [146] db_id=european_football_2
SELECT
  CASE
    WHEN p1.birthday < p2.birthday THEN p1.player_name
    WHEN p2.birthday < p1.birthday THEN p2.player_name
    ELSE 'Same age'
  END AS older_player
FROM Player p1
JOIN Player p2
WHERE p1.player_name = 'Aaron Lennon'
  AND p2.player_name = 'Abdelaziz Barrada';

-- [147] db_id=european_football_2
SELECT player_name, height
FROM Player
WHERE height = (SELECT MAX(height) FROM Player);

-- [148] db_id=european_football_2
SELECT COUNT(DISTINCT player_api_id) AS left_foot_low_attacking_work_rate_players
FROM Player_Attributes
WHERE LOWER(preferred_foot) = 'left'
  AND LOWER(attacking_work_rate) = 'low';

-- [149] db_id=european_football_2
SELECT COUNT(DISTINCT p.player_api_id)
FROM Player p
JOIN Player_Attributes pa
  ON pa.player_api_id = p.player_api_id
WHERE strftime('%Y', p.birthday) < '1986'
  AND pa.defensive_work_rate = 'high';

-- [150] db_id=european_football_2
SELECT DISTINCT p.player_name
FROM Player AS p
JOIN Player_Attributes AS pa
  ON pa.player_api_id = p.player_api_id
WHERE pa.volleys > 70
  AND pa.dribbling > 70;

-- [151] db_id=european_football_2
SELECT COUNT(*) AS match_count
FROM "Match" m
JOIN League l ON l.id = m.league_id
WHERE l.name = 'Belgium Jupiler League'
  AND SUBSTR(m.date, 1, 7) = '2009-04';

-- [152] db_id=european_football_2
SELECT l.name
FROM Match AS m
JOIN League AS l ON l.id = m.league_id
WHERE m.season = '2008/2009'
GROUP BY m.league_id
ORDER BY COUNT(*) DESC
LIMIT 1;

-- [153] db_id=european_football_2
SELECT
  ((a.overall_rating - p.overall_rating) * 100.0) / p.overall_rating AS percentage_higher
FROM
  (SELECT pa.overall_rating
   FROM Player pr
   JOIN Player_Attributes pa ON pa.player_api_id = pr.player_api_id
   WHERE pr.player_name = 'Ariel Borysiuk'
   ORDER BY pa.date DESC
   LIMIT 1) a
CROSS JOIN
  (SELECT pa.overall_rating
   FROM Player pr
   JOIN Player_Attributes pa ON pa.player_api_id = pr.player_api_id
   WHERE pr.player_name = 'Paulin Puel'
   ORDER BY pa.date DESC
   LIMIT 1) p;

-- [154] db_id=european_football_2
SELECT AVG(pa.overall_rating) AS avg_overall_rating
FROM Player AS p
JOIN Player_Attributes AS pa
  ON pa.player_api_id = p.player_api_id
WHERE p.player_name = 'Pietro Marino';

-- [155] db_id=european_football_2
SELECT
  MAX(ta.chanceCreationPassing) AS highest_chanceCreationPassing,
  ta.chanceCreationPassingClass AS classification
FROM Team_Attributes ta
JOIN Team t
  ON t.team_api_id = ta.team_api_id
WHERE t.team_long_name = 'Ajax'
  AND ta.chanceCreationPassing = (
    SELECT MAX(ta2.chanceCreationPassing)
    FROM Team_Attributes ta2
    JOIN Team t2
      ON t2.team_api_id = ta2.team_api_id
    WHERE t2.team_long_name = 'Ajax'
  );

-- [156] db_id=european_football_2
SELECT p.player_name
FROM Player_Attributes pa
JOIN Player p ON p.player_api_id = pa.player_api_id
WHERE pa.overall_rating = 77
  AND pa.date LIKE '2016-06-23%'
ORDER BY p.birthday ASC
LIMIT 1;

-- [157] db_id=european_football_2
SELECT pa.overall_rating
FROM Player_Attributes AS pa
JOIN Player AS p
  ON p.player_api_id = pa.player_api_id
WHERE p.player_name = 'Aaron Mooy'
  AND pa.date LIKE '2016-02-04%';

-- [158] db_id=european_football_2
SELECT pa.attacking_work_rate
FROM Player p
JOIN Player_Attributes pa
  ON pa.player_api_id = p.player_api_id
WHERE p.player_name = 'Francesco Migliore'
  AND pa.date LIKE '2015-05-01%';

-- [159] db_id=european_football_2
SELECT pa.date
FROM Player p
JOIN Player_Attributes pa
  ON pa.player_api_id = p.player_api_id
WHERE p.player_name = 'Kevin Constant'
  AND pa.crossing = (
    SELECT MAX(pa2.crossing)
    FROM Player p2
    JOIN Player_Attributes pa2
      ON pa2.player_api_id = p2.player_api_id
    WHERE p2.player_name = 'Kevin Constant'
  )
ORDER BY pa.date ASC
LIMIT 1;

-- [160] db_id=european_football_2
SELECT ta.buildUpPlayPassingClass
FROM Team_Attributes AS ta
JOIN Team AS t
  ON t.team_api_id = ta.team_api_id
WHERE t.team_long_name = 'FC Lorient'
  AND ta.date LIKE '2010-02-22%';

-- [161] db_id=european_football_2
SELECT ta.defenceAggressionClass
FROM Team_Attributes AS ta
JOIN Team AS t
  ON t.team_api_id = ta.team_api_id
WHERE t.team_long_name = 'Hannover 96'
  AND ta.date LIKE '2015-09-10%';

-- [162] db_id=european_football_2
SELECT AVG(pa.overall_rating) AS avg_overall_rating
FROM Player_Attributes pa
JOIN Player p ON p.player_api_id = pa.player_api_id
WHERE p.player_name = 'Marko Arnautovic'
  AND substr(pa.date, 1, 10) BETWEEN '2007-02-22' AND '2016-04-21';

-- [163] db_id=european_football_2
SELECT
  ((ld.overall_rating - jb.overall_rating) * 100.0) / ld.overall_rating AS percentage_higher
FROM
  (SELECT pa.overall_rating
   FROM Player p
   JOIN Player_Attributes pa ON pa.player_api_id = p.player_api_id
   WHERE p.player_name = 'Landon Donovan'
     AND date(pa.date) = '2013-07-12'
   ORDER BY pa.date DESC
   LIMIT 1) AS ld
CROSS JOIN
  (SELECT pa.overall_rating
   FROM Player p
   JOIN Player_Attributes pa ON pa.player_api_id = p.player_api_id
   WHERE p.player_name = 'Jordan Bowery'
     AND date(pa.date) = '2013-07-12'
   ORDER BY pa.date DESC
   LIMIT 1) AS jb;

-- [164] db_id=european_football_2
SELECT player_name
FROM Player
WHERE height = (SELECT MAX(height) FROM Player);

-- [165] db_id=european_football_2
SELECT p.player_name
FROM Player_Attributes pa
JOIN Player p ON p.player_api_id = pa.player_api_id
WHERE pa.overall_rating = (SELECT MAX(overall_rating) FROM Player_Attributes);

-- [166] db_id=european_football_2
SELECT DISTINCT p.player_name
FROM Player AS p
JOIN Player_Attributes AS pa
  ON pa.player_api_id = p.player_api_id
WHERE LOWER(pa.attacking_work_rate) = 'high'
ORDER BY p.player_name;

-- [167] db_id=european_football_2
SELECT DISTINCT t.team_short_name
FROM Team_Attributes ta
JOIN Team t ON t.team_api_id = ta.team_api_id
WHERE ta.chanceCreationPassingClass = 'Safe'
  AND t.team_short_name IS NOT NULL;

-- [168] db_id=european_football_2
SELECT COUNT(*) AS num_players
FROM Player
WHERE player_name LIKE 'Aaron%'
  AND birthday > '1990';

-- [169] db_id=european_football_2
SELECT
  (SELECT jumping FROM Player_Attributes WHERE id = 6) -
  (SELECT jumping FROM Player_Attributes WHERE id = 23) AS jumping_difference;

-- [170] db_id=european_football_2
SELECT
  player_api_id
FROM Player_Attributes
WHERE preferred_foot = 'right'
  AND potential = (
    SELECT MIN(potential)
    FROM Player_Attributes
    WHERE preferred_foot = 'right'
  )
ORDER BY player_api_id
LIMIT 4;

-- [171] db_id=european_football_2
SELECT COUNT(DISTINCT player_api_id) AS num_players
FROM Player_Attributes
WHERE preferred_foot = 'left'
  AND crossing = (SELECT MAX(crossing) FROM Player_Attributes);

-- [172] db_id=european_football_2
SELECT
  m.home_team_goal AS home_team_score,
  m.away_team_goal AS away_team_score
FROM "Match" AS m
JOIN League AS l
  ON l.id = m.league_id
WHERE l.name = 'Belgium Jupiler League'
  AND m.date LIKE '2008-09-24%';

-- [173] db_id=european_football_2
SELECT ta.buildUpPlaySpeedClass
FROM Team t
JOIN Team_Attributes ta
  ON ta.team_api_id = t.team_api_id
WHERE t.team_long_name = 'KSV Cercle Brugge'
ORDER BY ta.date DESC
LIMIT 1;

-- [174] db_id=european_football_2
SELECT
  pa.finishing AS finishing_rate,
  pa.curve AS curve_score
FROM Player p
JOIN Player_Attributes pa
  ON pa.player_api_id = p.player_api_id
WHERE p.weight = (SELECT MAX(weight) FROM Player)
ORDER BY pa.date DESC
LIMIT 1;

-- [175] db_id=european_football_2
SELECT
  l.name AS league_name,
  COUNT(m.id) AS games_count
FROM "Match" AS m
JOIN League AS l
  ON l.id = m.league_id
WHERE m.season = '2015/2016'
GROUP BY l.id, l.name
ORDER BY games_count DESC
LIMIT 4;

-- [176] db_id=european_football_2
SELECT t.team_long_name
FROM "Match" m
JOIN Team t
  ON t.team_api_id = m.away_team_api_id
ORDER BY m.away_team_goal DESC
LIMIT 1;

-- [177] db_id=european_football_2
SELECT p.player_name
FROM Player_Attributes pa
JOIN Player p ON p.player_api_id = pa.player_api_id
WHERE pa.overall_rating = (SELECT MAX(overall_rating) FROM Player_Attributes)
LIMIT 1;

-- [178] db_id=european_football_2
SELECT
  100.0 * SUM(CASE WHEN p.height < 180 AND pa.strength > 70 THEN 1 ELSE 0 END) / COUNT(p.id) AS percentage
FROM Player AS p
JOIN Player_Attributes AS pa
  ON pa.player_api_id = p.player_api_id;

-- [179] db_id=formula_1
SELECT d.driverRef
FROM qualifying q
JOIN drivers d ON d.driverId = q.driverId
WHERE q.raceId = 20
  AND q.q1 IS NOT NULL
  AND TRIM(q.q1) <> ''
ORDER BY q.q1 DESC
LIMIT 5

-- [180] db_id=formula_1
SELECT d.surname
FROM qualifying q
JOIN drivers d ON d.driverId = q.driverId
WHERE q.raceId = 19
  AND q.q2 IS NOT NULL
  AND q.q2 <> ''
ORDER BY q.q2 ASC
LIMIT 1;

-- [181] db_id=formula_1
SELECT DISTINCT r.name
FROM races AS r
JOIN circuits AS c ON c.circuitId = r.circuitId
WHERE c.country = 'Germany';

-- [182] db_id=formula_1
SELECT DISTINCT c.lat, c.lng
FROM races r
JOIN circuits c ON c.circuitId = r.circuitId
WHERE r.name = 'Australian Grand Prix';

-- [183] db_id=formula_1
SELECT c.lat, c.lng
FROM races r
JOIN circuits c ON c.circuitId = r.circuitId
WHERE r.name = 'Abu Dhabi Grand Prix';

-- [184] db_id=formula_1
SELECT q.q1
FROM qualifying AS q
JOIN drivers AS d ON d.driverId = q.driverId
WHERE q.raceId = 354
  AND d.forename = 'Bruno'
  AND d.surname = 'Senna';

-- [185] db_id=formula_1
SELECT q.number
FROM qualifying AS q
WHERE q.raceId = 903
  AND q.q3 LIKE '1:54%';

-- [186] db_id=formula_1
SELECT COUNT(*) AS not_finished_drivers
FROM results r
JOIN races ra ON ra.raceId = r.raceId
WHERE ra.year = 2007
  AND ra.name = 'Bahrain Grand Prix'
  AND r.time IS NULL;

-- [187] db_id=formula_1
SELECT d.driverId,
       d.forename,
       d.surname,
       d.dob
FROM results r
JOIN drivers d ON d.driverId = r.driverId
WHERE r.raceId = 592
  AND r.time IS NOT NULL
ORDER BY d.dob ASC
LIMIT 1;

-- [188] db_id=formula_1
SELECT d.driverId,
       d.forename,
       d.surname,
       d.url
FROM lapTimes lt
JOIN drivers d ON d.driverId = lt.driverId
WHERE lt.raceId = 161
  AND lt.time LIKE '1:27%'
GROUP BY d.driverId, d.forename, d.surname, d.url;

-- [189] db_id=formula_1
SELECT
  c.location,
  c.country,
  c.lat,
  c.lng
FROM races r
JOIN circuits c ON c.circuitId = r.circuitId
WHERE r.name = 'Malaysian Grand Prix'
LIMIT 1;

-- [190] db_id=formula_1
SELECT c.url
FROM constructorResults cr
JOIN constructors c ON c.constructorId = cr.constructorId
WHERE cr.raceId = 9
ORDER BY cr.points DESC
LIMIT 1;

-- [191] db_id=formula_1
SELECT d.code
FROM qualifying q
JOIN drivers d ON d.driverId = q.driverId
WHERE q.raceId = 45
  AND q.q3 LIKE '1:33%';

-- [192] db_id=formula_1
SELECT s.url
FROM races r
JOIN seasons s ON s.year = r.year
WHERE r.raceId = 901;

-- [193] db_id=formula_1
SELECT d.driverId,
       d.driverRef,
       d.forename,
       d.surname,
       d.dob
FROM results r
JOIN drivers d ON d.driverId = r.driverId
WHERE r.raceId = 872
  AND r.time IS NOT NULL
  AND r.time <> ''
ORDER BY d.dob DESC
LIMIT 1;

-- [194] db_id=formula_1
SELECT d.nationality
FROM results r
JOIN drivers d ON d.driverId = r.driverId
WHERE CAST(r.fastestLapSpeed AS REAL) = (
  SELECT MAX(CAST(fastestLapSpeed AS REAL))
  FROM results
  WHERE fastestLapSpeed IS NOT NULL AND fastestLapSpeed <> ''
)
LIMIT 1;

-- [195] db_id=formula_1
SELECT
  ((r853.fastestLapSpeed - r854.fastestLapSpeed) * 100.0) / r853.fastestLapSpeed AS percent_faster
FROM
  (SELECT res.fastestLapSpeed
   FROM results res
   JOIN drivers d ON d.driverId = res.driverId
   WHERE d.forename = 'Paul'
     AND d.surname = 'di Resta'
     AND res.raceId = 853
   LIMIT 1) AS r853
CROSS JOIN
  (SELECT res.fastestLapSpeed
   FROM results res
   JOIN drivers d ON d.driverId = res.driverId
   WHERE d.forename = 'Paul'
     AND d.surname = 'di Resta'
     AND res.raceId = 854
   LIMIT 1) AS r854;

-- [196] db_id=formula_1
SELECT
  d.driverId,
  d.forename,
  d.surname,
  1.0 * SUM(CASE WHEN re.time IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS completion_rate
FROM races ra
JOIN results re ON re.raceId = ra.raceId
JOIN drivers d ON d.driverId = re.driverId
WHERE ra.date = '1983-07-16'
GROUP BY d.driverId, d.forename, d.surname;

-- [197] db_id=formula_1
SELECT r.name
FROM races r
WHERE strftime('%Y', r.date) = (SELECT strftime('%Y', MIN(date)) FROM races)
  AND strftime('%m', r.date) = (SELECT strftime('%m', MIN(date)) FROM races);

-- [198] db_id=formula_1
SELECT
  d.forename || ' ' || d.surname AS full_name,
  SUM(r.points) AS points
FROM results r
JOIN drivers d ON d.driverId = r.driverId
GROUP BY r.driverId
ORDER BY points DESC
LIMIT 1

-- [199] db_id=formula_1
SELECT
  d.forename,
  d.surname,
  r.name AS race,
  lt.milliseconds
FROM lapTimes lt
JOIN drivers d ON d.driverId = lt.driverId
JOIN races r ON r.raceId = lt.raceId
WHERE lt.milliseconds = (SELECT MIN(milliseconds) FROM lapTimes WHERE milliseconds IS NOT NULL);

-- [200] db_id=formula_1
SELECT AVG(lt.milliseconds) AS avg_lap_time_milliseconds
FROM lapTimes AS lt
JOIN drivers AS d ON d.driverId = lt.driverId
JOIN races AS r ON r.raceId = lt.raceId
WHERE d.forename = 'Lewis'
  AND d.surname = 'Hamilton'
  AND r.year = 2009
  AND r.name = 'Malaysian Grand Prix';

-- [201] db_id=formula_1
SELECT
  100.0 * SUM(CASE WHEN res.position > 1 THEN 1 ELSE 0 END) / COUNT(*) AS percentage_not_first
FROM results AS res
JOIN drivers AS d
  ON d.driverId = res.driverId
JOIN races AS r
  ON r.raceId = res.raceId
WHERE d.surname = 'Hamilton'
  AND r.year >= 2010;

-- [202] db_id=formula_1
SELECT
  d.forename || ' ' || d.surname AS driverName,
  d.nationality,
  dw.max_points AS maxPointScores
FROM driverStandings ds
JOIN drivers d ON d.driverId = ds.driverId
JOIN (
  SELECT driverId, MAX(points) AS max_points
  FROM driverStandings
  GROUP BY driverId
) dw ON dw.driverId = ds.driverId
GROUP BY ds.driverId
ORDER BY MAX(ds.wins) DESC
LIMIT 1

-- [203] db_id=formula_1
SELECT
  (CAST(strftime('%Y','now') AS INTEGER) - CAST(strftime('%Y', dob) AS INTEGER)) AS age,
  (forename || ' ' || surname) AS name
FROM drivers
WHERE nationality = 'Japanese'
  AND dob IS NOT NULL
ORDER BY dob DESC
LIMIT 1;

-- [204] db_id=formula_1
SELECT
  r.name AS race_name,
  c.name AS circuit_name,
  c.location
FROM races AS r
JOIN circuits AS c
  ON c.circuitId = r.circuitId
WHERE strftime('%Y', r.date) = '2005'
  AND strftime('%m', r.date) = '09';

-- [205] db_id=formula_1
SELECT DISTINCT r.name
FROM drivers d
JOIN results re ON re.driverId = d.driverId
JOIN races r ON r.raceId = re.raceId
WHERE d.forename = 'Alex'
  AND d.surname = 'Yoong'
  AND re.position < 20;

-- [206] db_id=formula_1
SELECT r.name AS race,
       r.year
FROM lapTimes lt
JOIN races r ON r.raceId = lt.raceId
JOIN drivers d ON d.driverId = lt.driverId
WHERE d.forename = 'Michael'
  AND d.surname = 'Schumacher'
  AND lt.milliseconds IS NOT NULL
ORDER BY lt.milliseconds ASC
LIMIT 1;

-- [207] db_id=formula_1
SELECT
  r.year,
  r.round,
  r.name AS raceName,
  r.date,
  res.points
FROM drivers d
JOIN results res ON res.driverId = d.driverId
JOIN races r ON r.raceId = res.raceId
WHERE d.forename = 'Lewis'
  AND d.surname = 'Hamilton'
  AND r.year = (
    SELECT MIN(r2.year)
    FROM drivers d2
    JOIN results res2 ON res2.driverId = d2.driverId
    JOIN races r2 ON r2.raceId = res2.raceId
    WHERE d2.forename = 'Lewis'
      AND d2.surname = 'Hamilton'
  )
ORDER BY r.round ASC
LIMIT 1;

-- [208] db_id=formula_1
SELECT
  100.0 * SUM(CASE WHEN c.country = 'Germany' THEN 1 ELSE 0 END) / COUNT(*) AS percentage
FROM races r
JOIN circuits c ON c.circuitId = r.circuitId
WHERE r.name = 'European Grand Prix';

-- [209] db_id=formula_1
SELECT lat, lng
FROM circuits
WHERE name = 'Silverstone Circuit';

-- [210] db_id=formula_1
SELECT circuitRef
FROM circuits
WHERE name = 'Marina Bay Street Circuit';

-- [211] db_id=formula_1
SELECT nationality AS country
FROM drivers
WHERE dob IS NOT NULL
ORDER BY dob ASC
LIMIT 1;

-- [212] db_id=formula_1
SELECT d.driverRef
FROM races r
JOIN results res ON res.raceId = r.raceId
JOIN drivers d ON d.driverId = res.driverId
WHERE r.year = 2007
  AND r.name = 'Canadian Grand Prix'
  AND res.positionOrder = 1;

-- [213] db_id=formula_1
SELECT r.raceId,
       r.name AS raceName,
       r.year,
       r.round,
       res.rank
FROM results AS res
JOIN drivers AS d
  ON d.driverId = res.driverId
JOIN races AS r
  ON r.raceId = res.raceId
WHERE d.forename = 'Lewis'
  AND d.surname = 'Hamilton'
  AND res.rank IS NOT NULL
ORDER BY res.rank ASC, r.date ASC, r.raceId ASC
LIMIT 1;

-- [214] db_id=formula_1
SELECT MAX(CAST(fastestLapSpeed AS REAL)) AS fastest_lap_speed
FROM results r
JOIN races ra ON ra.raceId = r.raceId
WHERE ra.year = 2009
  AND ra.name = 'Spanish Grand Prix'
  AND r.fastestLapSpeed IS NOT NULL
  AND r.fastestLapSpeed <> '';

-- [215] db_id=formula_1
SELECT res.positionOrder AS final_rank
FROM results AS res
JOIN drivers AS d ON d.driverId = res.driverId
JOIN races AS r ON r.raceId = res.raceId
WHERE d.forename = 'Lewis'
  AND d.surname = 'Hamilton'
  AND r.year = 2008
  AND r.name = 'Chinese Grand Prix';

-- [216] db_id=formula_1
SELECT res.time
FROM races r
JOIN results res ON res.raceId = r.raceId
WHERE r.year = 2008
  AND r.name = 'Chinese Grand Prix'
  AND res.rank = 2;

-- [217] db_id=formula_1
SELECT COUNT(DISTINCT r.driverId)
FROM races ra
JOIN results r ON r.raceId = ra.raceId
JOIN (
    SELECT driverId
    FROM results
    GROUP BY driverId
    HAVING COUNT(raceId) > 0
) p ON p.driverId = r.driverId
WHERE ra.year = 2008
  AND ra.name = 'Chinese Grand Prix'
  AND r.time IS NOT NULL;

-- [218] db_id=formula_1
SELECT
  (
    (CAST(strftime('%s', '1970-01-01 ' || lastR.time) AS REAL) - CAST(strftime('%s', '1970-01-01 ' || champR.time) AS REAL))
    / CAST(strftime('%s', '1970-01-01 ' || lastR.time) AS REAL)
  ) * 100.0 AS percent_faster
FROM races ra
JOIN results champR
  ON champR.raceId = ra.raceId
JOIN driverStandings ds
  ON ds.raceId = ra.raceId AND ds.position = 1
JOIN results lastR
  ON lastR.raceId = ra.raceId
WHERE ra.year = 2008
  AND ra.name = 'Australian Grand Prix'
  AND champR.driverId = ds.driverId
  AND champR.positionOrder = 1
  AND champR.time IS NOT NULL
  AND lastR.time IS NOT NULL
  AND lastR.positionOrder = (
    SELECT MAX(r2.positionOrder)
    FROM results r2
    WHERE r2.raceId = ra.raceId
      AND r2.time IS NOT NULL
  );

-- [219] db_id=formula_1
SELECT COUNT(*) AS circuit_count
FROM circuits
WHERE location = 'Adelaide'
  AND country = 'Australia';

-- [220] db_id=formula_1
SELECT MAX(cr.points) AS max_points
FROM constructorResults cr
JOIN constructors c ON c.constructorId = cr.constructorId
WHERE c.nationality = 'British';

-- [221] db_id=formula_1
SELECT c.name
FROM constructorResults cr
JOIN constructors c ON c.constructorId = cr.constructorId
WHERE cr.raceId = 291
  AND COALESCE(cr.points, 0) = 0;

-- [222] db_id=formula_1
SELECT COUNT(*)
FROM (
  SELECT cr.constructorId
  FROM constructorResults cr
  JOIN constructors c ON c.constructorId = cr.constructorId
  WHERE c.nationality = 'Japanese'
    AND IFNULL(cr.points, 0) = 0
  GROUP BY cr.constructorId
  HAVING COUNT(DISTINCT cr.raceId) = 2
) t;

-- [223] db_id=formula_1
SELECT
  (CAST(SUM(CASE WHEN re.time IS NOT NULL THEN 1 ELSE 0 END) AS REAL) / COUNT(*)) * 100.0 AS race_completion_percentage
FROM results AS re
JOIN races AS ra ON ra.raceId = re.raceId
JOIN drivers AS d ON d.driverId = re.driverId
WHERE d.nationality = 'Japanese'
  AND ra.year BETWEEN 2007 AND 2009;

-- [224] db_id=formula_1
SELECT
  r.year,
  AVG(
    CAST(substr(res.time, 1, instr(res.time, ':') - 1) AS REAL) * 3600.0 +
    CAST(substr(substr(res.time, instr(res.time, ':') + 1), 1, instr(substr(res.time, instr(res.time, ':') + 1), ':') - 1) AS REAL) * 60.0 +
    CAST(substr(substr(res.time, instr(res.time, ':') + 1), instr(substr(res.time, instr(res.time, ':') + 1), ':') + 1) AS REAL)
  ) AS avg_champion_time_seconds
FROM races r
JOIN results res
  ON res.raceId = r.raceId
JOIN driverStandings ds
  ON ds.raceId = r.raceId
 AND ds.driverId = res.driverId
WHERE r.year < 1975
  AND ds.position = 1
  AND res.positionOrder = 1
  AND res.time IS NOT NULL
  AND res.time LIKE '%:%:%'
GROUP BY r.year
ORDER BY r.year;

-- [225] db_id=formula_1
SELECT r.fastestLap
FROM driverStandings ds
JOIN races ra ON ra.raceId = ds.raceId
JOIN results r ON r.raceId = ds.raceId AND r.driverId = ds.driverId
WHERE ra.year = 2009
  AND ra.round = (SELECT MAX(round) FROM races WHERE year = 2009)
  AND ds.position = 1
  AND r.time LIKE '%:%:%.%'
LIMIT 1;

-- [226] db_id=formula_1
SELECT AVG(CAST(fastestLapSpeed AS REAL)) AS avg_fastest_lap_speed
FROM results r
JOIN races ra ON ra.raceId = r.raceId
WHERE ra.year = 2009
  AND ra.name = 'Spanish Grand Prix'
  AND r.fastestLapSpeed IS NOT NULL;

-- [227] db_id=formula_1
SELECT
  100.0 * COUNT(DISTINCT CASE WHEN CAST(strftime('%Y', d.dob) AS INTEGER) < 1985 AND lt.lap > 50 THEN d.driverId END)
  / NULLIF(COUNT(DISTINCT CASE WHEN r.year BETWEEN 2000 AND 2005 THEN d.driverId END), 0) AS percentage
FROM lapTimes lt
JOIN races r ON r.raceId = lt.raceId
JOIN drivers d ON d.driverId = lt.driverId
WHERE r.year BETWEEN 2000 AND 2005;

-- [228] db_id=formula_1
SELECT COUNT(DISTINCT d.driverId) AS french_drivers_under_2min
FROM drivers d
JOIN lapTimes lt ON lt.driverId = d.driverId
WHERE d.nationality = 'French'
  AND lt.milliseconds IS NOT NULL
  AND lt.milliseconds < 120000;

-- [229] db_id=formula_1
SELECT code
FROM drivers
WHERE nationality = 'American';

-- [230] db_id=formula_1
SELECT
  d.code,
  d.driverId,
  d.dob,
  d.nationality,
  (SELECT COUNT(*)
   FROM (
     SELECT driverId, nationality
     FROM drivers
     ORDER BY dob DESC
     LIMIT 3
   ) t
   WHERE t.nationality IN ('Dutch','Netherlandic')
  ) AS netherlandic_count_among_top3
FROM drivers d
ORDER BY d.dob DESC
LIMIT 3;

-- [231] db_id=formula_1
SELECT driverRef
FROM drivers
WHERE nationality = 'German'
  AND dob IS NOT NULL
ORDER BY dob ASC
LIMIT 1;

-- [232] db_id=formula_1
SELECT DISTINCT d.driverId,
       d.code
FROM drivers AS d
JOIN results AS r
  ON r.driverId = d.driverId
WHERE strftime('%Y', d.dob) = '1971'
  AND r.fastestLapTime IS NOT NULL
  AND r.fastestLapTime <> ''
  AND r.fastestLapTime = (
    SELECT MIN(r2.fastestLapTime)
    FROM results AS r2
    WHERE r2.raceId = r.raceId
      AND r2.fastestLapTime IS NOT NULL
      AND r2.fastestLapTime <> ''
  );

-- [233] db_id=formula_1
SELECT COUNT(*) AS disqualified_finishers
FROM results
WHERE raceId > 50
  AND raceId < 100
  AND statusId = 2
  AND time IS NOT NULL;

-- [234] db_id=formula_1
SELECT
  COUNT(*) AS times_held,
  location,
  lat,
  lng
FROM circuits
WHERE country = 'Austria'
GROUP BY location, lat, lng;

-- [235] db_id=formula_1
SELECT
  r.year,
  d.forename || ' ' || d.surname AS driver_name,
  r.name AS race_name,
  r.date AS race_date,
  r.time AS race_time
FROM (
  SELECT
    q.driverId,
    MIN(r.date) AS first_qualifying_date
  FROM qualifying q
  JOIN races r ON r.raceId = q.raceId
  GROUP BY q.driverId
) fq
JOIN drivers d
  ON d.driverId = fq.driverId
JOIN qualifying q
  ON q.driverId = fq.driverId
JOIN races r
  ON r.raceId = q.raceId
 AND r.date = fq.first_qualifying_date
ORDER BY d.dob DESC, r.date ASC
LIMIT 1;

-- [236] db_id=formula_1
SELECT
  d.forename || ' ' || d.surname AS full_name,
  AVG(ps.milliseconds) AS avg_pitstop_ms
FROM drivers d
JOIN pitStops ps ON ps.driverId = d.driverId
WHERE d.nationality = 'German'
  AND CAST(strftime('%Y', d.dob) AS INTEGER) BETWEEN 1980 AND 1985
  AND ps.milliseconds IS NOT NULL
GROUP BY d.driverId
ORDER BY avg_pitstop_ms ASC
LIMIT 3

-- [237] db_id=formula_1
SELECT
  d.forename || ' ' || d.surname AS champion,
  r.time AS finish_time
FROM races ra
JOIN results r ON r.raceId = ra.raceId
JOIN drivers d ON d.driverId = r.driverId
WHERE ra.year = 2008
  AND ra.name = 'Canadian Grand Prix'
  AND r.positionOrder = 1;

-- [238] db_id=formula_1
SELECT c.constructorRef,
       c.url
FROM races r
JOIN results res ON res.raceId = r.raceId
JOIN constructors c ON c.constructorId = res.constructorId
WHERE r.year = 2009
  AND r.name = 'Singapore Grand Prix'
  AND res.time = (
      SELECT MAX(res2.time)
      FROM results res2
      WHERE res2.raceId = r.raceId
  );

-- [239] db_id=superhero
SELECT sp.power_name
FROM superhero s
JOIN hero_power hp ON hp.hero_id = s.id
JOIN superpower sp ON sp.id = hp.power_id
WHERE s.superhero_name = '3-D Man'
ORDER BY sp.power_name;

-- [240] db_id=formula_1
SELECT
  c.name,
  c.nationality,
  SUM(r.points) AS score
FROM races ra
JOIN results r ON r.raceId = ra.raceId
JOIN constructors c ON c.constructorId = r.constructorId
WHERE ra.name = 'Monaco Grand Prix'
  AND ra.year BETWEEN 1980 AND 2010
GROUP BY c.constructorId, c.name, c.nationality
ORDER BY score DESC
LIMIT 1;

-- [241] db_id=formula_1
SELECT d.forename || ' ' || d.surname AS full_name
FROM races r
JOIN circuits c ON c.circuitId = r.circuitId
JOIN qualifying q ON q.raceId = r.raceId
JOIN drivers d ON d.driverId = q.driverId
WHERE r.year = 2008
  AND c.name = 'Marina Bay Street Circuit'
  AND q.q3 IS NOT NULL
  AND q.q3 = (
    SELECT MIN(q2.q3)
    FROM qualifying q2
    WHERE q2.raceId = r.raceId
      AND q2.q3 IS NOT NULL
  );

-- [242] db_id=formula_1
SELECT
  d.forename || ' ' || d.surname AS full_name,
  d.nationality,
  r2.name AS first_race_name
FROM drivers d
JOIN results res ON res.driverId = d.driverId
JOIN races r2 ON r2.raceId = res.raceId
WHERE d.dob = (SELECT MAX(dob) FROM drivers)
  AND res.raceId = (
    SELECT MIN(res2.raceId)
    FROM results res2
    WHERE res2.driverId = d.driverId
  );

-- [243] db_id=formula_1
SELECT MAX(accidents) AS max_accidents
FROM (
  SELECT r.driverId, COUNT(*) AS accidents
  FROM results r
  JOIN races ra ON ra.raceId = r.raceId
  WHERE ra.name = 'Canadian Grand Prix'
    AND r.statusId = 3
  GROUP BY r.driverId
) t;

-- [244] db_id=formula_1
SELECT d.forename || ' ' || d.surname AS full_name
FROM lapTimes lt
JOIN drivers d ON d.driverId = lt.driverId
WHERE lt.milliseconds IS NOT NULL
GROUP BY lt.driverId
ORDER BY MIN(lt.milliseconds) ASC
LIMIT 20;

-- [245] db_id=formula_1
SELECT
  c.name AS circuit,
  c.location,
  c.country,
  r.raceId,
  r.year,
  r.round,
  r.name AS race,
  lt.driverId,
  d.forename || ' ' || d.surname AS driver,
  lt.time AS lapRecordTime
FROM circuits c
JOIN races r
  ON r.circuitId = c.circuitId
JOIN lapTimes lt
  ON lt.raceId = r.raceId
JOIN drivers d
  ON d.driverId = lt.driverId
WHERE c.country = 'Italy'
  AND lt.time IS NOT NULL
  AND lt.time <> ''
  AND lt.milliseconds = (
    SELECT MIN(lt2.milliseconds)
    FROM lapTimes lt2
    WHERE lt2.raceId = r.raceId
      AND lt2.milliseconds IS NOT NULL
  )
ORDER BY c.name, r.year, r.round;

-- [246] db_id=superhero
SELECT COUNT(DISTINCT s.id) AS num_heroes
FROM superhero AS s
JOIN hero_power AS hp ON hp.hero_id = s.id
JOIN superpower AS sp ON sp.id = hp.power_id
WHERE sp.power_name = 'Super Strength'
  AND s.height_cm > 200;

-- [247] db_id=superhero
SELECT COUNT(DISTINCT s.id) AS hero_count
FROM superhero AS s
JOIN colour AS c
  ON c.id = s.eye_colour_id
JOIN hero_power AS hp
  ON hp.hero_id = s.id
JOIN superpower AS sp
  ON sp.id = hp.power_id
WHERE c.colour = 'Blue'
  AND sp.power_name = 'Agility';

-- [248] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN colour AS eye ON eye.id = s.eye_colour_id
JOIN colour AS hair ON hair.id = s.hair_colour_id
WHERE eye.colour = 'Blue'
  AND hair.colour = 'Blond';

-- [249] db_id=superhero
SELECT
  s.superhero_name AS name,
  s.height_cm
FROM superhero AS s
JOIN publisher AS p
  ON p.id = s.publisher_id
WHERE p.publisher_name = 'Marvel Comics'
  AND s.height_cm IS NOT NULL
ORDER BY s.height_cm DESC, s.superhero_name ASC;

-- [250] db_id=superhero
SELECT
  c.colour AS eye_colour,
  COUNT(s.id) AS superhero_count
FROM superhero AS s
JOIN publisher AS p
  ON p.id = s.publisher_id
JOIN colour AS c
  ON c.id = s.eye_colour_id
WHERE p.publisher_name = 'Marvel Comics'
GROUP BY c.colour
ORDER BY superhero_count DESC, eye_colour ASC;

-- [251] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN publisher AS p
  ON p.id = s.publisher_id
JOIN hero_power AS hp
  ON hp.hero_id = s.id
JOIN superpower AS sp
  ON sp.id = hp.power_id
WHERE p.publisher_name = 'Marvel Comics'
  AND sp.power_name = 'Super Strength';

-- [252] db_id=superhero
SELECT p.publisher_name
FROM hero_attribute ha
JOIN attribute a ON a.id = ha.attribute_id
JOIN superhero s ON s.id = ha.hero_id
JOIN publisher p ON p.id = s.publisher_id
WHERE a.attribute_name = 'Speed'
  AND ha.attribute_value = (
    SELECT MIN(ha2.attribute_value)
    FROM hero_attribute ha2
    JOIN attribute a2 ON a2.id = ha2.attribute_id
    WHERE a2.attribute_name = 'Speed'
  );

-- [253] db_id=superhero
SELECT COUNT(*) AS gold_eyed_marvel_heroes
FROM superhero s
JOIN colour c ON c.id = s.eye_colour_id
JOIN publisher p ON p.id = s.publisher_id
WHERE c.colour = 'Gold'
  AND p.publisher_name = 'Marvel Comics';

-- [254] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN hero_attribute AS ha ON ha.hero_id = s.id
JOIN attribute AS a ON a.id = ha.attribute_id
WHERE a.attribute_name = 'Intelligence'
  AND ha.attribute_value = (
    SELECT MIN(ha2.attribute_value)
    FROM hero_attribute AS ha2
    JOIN attribute AS a2 ON a2.id = ha2.attribute_id
    WHERE a2.attribute_name = 'Intelligence'
  );

-- [255] db_id=superhero
SELECT r.race
FROM superhero s
LEFT JOIN race r ON r.id = s.race_id
WHERE s.superhero_name = 'Copycat';

-- [256] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN hero_attribute AS ha ON ha.hero_id = s.id
JOIN attribute AS a ON a.id = ha.attribute_id
WHERE a.attribute_name = 'Durability'
  AND ha.attribute_value < 50;

-- [257] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN hero_power AS hp ON hp.hero_id = s.id
JOIN superpower AS sp ON sp.id = hp.power_id
WHERE sp.power_name = 'Death Touch';

-- [258] db_id=superhero
SELECT COUNT(DISTINCT s.id)
FROM superhero AS s
JOIN gender AS g
  ON g.id = s.gender_id
JOIN hero_attribute AS ha
  ON ha.hero_id = s.id
JOIN attribute AS a
  ON a.id = ha.attribute_id
WHERE g.gender = 'Female'
  AND a.attribute_name = 'Strength'
  AND ha.attribute_value = 100;

-- [259] db_id=superhero
SELECT
  ROUND(100.0 * SUM(CASE WHEN a.alignment = 'Bad' THEN 1 ELSE 0 END) / COUNT(s.id), 2) AS bad_alignment_percentage,
  SUM(CASE WHEN a.alignment = 'Bad' AND p.publisher_name = 'Marvel Comics' THEN 1 ELSE 0 END) AS bad_alignment_marvel_count
FROM superhero s
LEFT JOIN alignment a ON a.id = s.alignment_id
LEFT JOIN publisher p ON p.id = s.publisher_id;

-- [260] db_id=superhero
SELECT
  CASE
    WHEN SUM(p.publisher_name = 'Marvel Comics') > SUM(p.publisher_name = 'DC Comics') THEN 'Marvel Comics'
    WHEN SUM(p.publisher_name = 'Marvel Comics') < SUM(p.publisher_name = 'DC Comics') THEN 'DC Comics'
    ELSE 'Tie'
  END AS publisher_with_more_superheroes,
  (SUM(p.publisher_name = 'Marvel Comics') - SUM(p.publisher_name = 'DC Comics')) AS difference
FROM superhero s
JOIN publisher p ON p.id = s.publisher_id
WHERE p.publisher_name IN ('Marvel Comics', 'DC Comics');

-- [261] db_id=superhero
SELECT id
FROM publisher
WHERE publisher_name = 'Star Trek';

-- [262] db_id=superhero
SELECT COUNT(*) AS total_superheroes_without_full_name
FROM superhero
WHERE full_name IS NULL;

-- [263] db_id=superhero
SELECT AVG(s.weight_kg) AS avg_weight_kg
FROM superhero AS s
JOIN gender AS g ON g.id = s.gender_id
WHERE g.gender = 'Female'
  AND s.weight_kg IS NOT NULL;

-- [264] db_id=superhero
SELECT DISTINCT sp.power_name
FROM superhero sh
JOIN gender g ON g.id = sh.gender_id
JOIN hero_power hp ON hp.hero_id = sh.id
JOIN superpower sp ON sp.id = hp.power_id
WHERE g.gender = 'Male'
  AND sp.power_name IS NOT NULL
LIMIT 5;

-- [265] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN colour AS c
  ON c.id = s.eye_colour_id
WHERE s.height_cm BETWEEN 170 AND 190
  AND c.colour = 'No Colour';

-- [266] db_id=superhero
SELECT c.colour
FROM superhero s
JOIN race r ON r.id = s.race_id
JOIN colour c ON c.id = s.hair_colour_id
WHERE r.race = 'human'
  AND s.height_cm = 185;

-- [267] db_id=superhero
SELECT
  100.0 * SUM(CASE WHEN p.publisher_name = 'Marvel Comics' THEN 1 ELSE 0 END) / COUNT(p.id) AS percentage_marvel_comics
FROM superhero s
JOIN publisher p ON p.id = s.publisher_id
WHERE s.height_cm BETWEEN 150 AND 180;

-- [268] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN gender AS g ON g.id = s.gender_id
WHERE g.gender = 'Male'
  AND s.weight_kg > (SELECT AVG(weight_kg) * 0.79 FROM superhero);

-- [269] db_id=superhero
SELECT sp.power_name
FROM hero_power hp
JOIN superpower sp ON sp.id = hp.power_id
WHERE hp.hero_id = 1;

-- [270] db_id=superhero
SELECT COUNT(DISTINCT hp.hero_id) AS stealth_hero_count
FROM hero_power hp
JOIN superpower sp ON sp.id = hp.power_id
WHERE sp.power_name = 'Stealth';

-- [271] db_id=superhero
SELECT s.full_name
FROM superhero AS s
JOIN hero_attribute AS ha ON ha.hero_id = s.id
JOIN attribute AS a ON a.id = ha.attribute_id
WHERE a.attribute_name = 'strength'
ORDER BY ha.attribute_value DESC
LIMIT 1;

-- [272] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN publisher AS p
  ON p.id = s.publisher_id
JOIN hero_attribute AS ha
  ON ha.hero_id = s.id
JOIN attribute AS a
  ON a.id = ha.attribute_id
WHERE p.publisher_name = 'Dark Horse Comics'
  AND a.attribute_name = 'durability'
ORDER BY ha.attribute_value DESC
LIMIT 1

-- [273] db_id=superhero
SELECT
  ce.colour AS eye_colour,
  ch.colour AS hair_colour,
  cs.colour AS skin_colour
FROM superhero s
JOIN gender g ON g.id = s.gender_id
JOIN publisher p ON p.id = s.publisher_id
LEFT JOIN colour ce ON ce.id = s.eye_colour_id
LEFT JOIN colour ch ON ch.id = s.hair_colour_id
LEFT JOIN colour cs ON cs.id = s.skin_colour_id
WHERE g.gender = 'Female'
  AND p.publisher_name = 'Dark Horse Comics';

-- [274] db_id=superhero
SELECT
  s.superhero_name,
  p.publisher_name
FROM superhero AS s
LEFT JOIN publisher AS p
  ON p.id = s.publisher_id
WHERE s.eye_colour_id = s.hair_colour_id
  AND s.hair_colour_id = s.skin_colour_id;

-- [275] db_id=superhero
SELECT
  100.0 * SUM(CASE WHEN c.colour = 'Blue' THEN 1 ELSE 0 END) / COUNT(*) AS percentage_blue_female_superheroes
FROM superhero s
JOIN gender g ON g.id = s.gender_id
LEFT JOIN colour c ON c.id = s.skin_colour_id
WHERE g.gender = 'Female';

-- [276] db_id=superhero
SELECT COUNT(*) AS power_count
FROM hero_power hp
JOIN superhero s ON s.id = hp.hero_id
WHERE s.superhero_name = 'Amazo';

-- [277] db_id=superhero
SELECT s.superhero_name,
       s.height_cm
FROM superhero AS s
JOIN colour AS c
  ON s.eye_colour_id = c.id
WHERE c.colour = 'Amber';

-- [278] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN colour AS ce ON ce.id = s.eye_colour_id
JOIN colour AS ch ON ch.id = s.hair_colour_id
WHERE ce.colour = 'Black'
  AND ch.colour = 'Black';

-- [279] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN alignment AS a ON a.id = s.alignment_id
WHERE a.alignment = 'Neutral';

-- [280] db_id=superhero
SELECT COUNT(DISTINCT ha.hero_id) AS hero_count
FROM hero_attribute ha
JOIN attribute a ON a.id = ha.attribute_id
WHERE a.attribute_name = 'Strength'
  AND ha.attribute_value = (
    SELECT MAX(ha2.attribute_value)
    FROM hero_attribute ha2
    JOIN attribute a2 ON a2.id = ha2.attribute_id
    WHERE a2.attribute_name = 'Strength'
  );

-- [281] db_id=superhero
SELECT
  100.0 * SUM(CASE WHEN g.gender = 'Female' AND p.publisher_name = 'Marvel Comics' THEN 1 ELSE 0 END)
       / COUNT(CASE WHEN p.publisher_name = 'Marvel Comics' THEN 1 END) AS percent_female_marvel
FROM superhero s
JOIN gender g ON g.id = s.gender_id
JOIN publisher p ON p.id = s.publisher_id;

-- [282] db_id=superhero
SELECT
  (SELECT SUM(weight_kg) FROM superhero WHERE full_name = 'Emil Blonsky')
  -
  (SELECT SUM(weight_kg) FROM superhero WHERE full_name = 'Charles Chandler') AS weight_difference;

-- [283] db_id=superhero
SELECT SUM(height_cm) * 1.0 / COUNT(*) AS avg_height_cm
FROM superhero
WHERE height_cm IS NOT NULL;

-- [284] db_id=superhero
SELECT sp.power_name
FROM superhero s
JOIN hero_power hp ON hp.hero_id = s.id
JOIN superpower sp ON sp.id = hp.power_id
WHERE s.superhero_name = 'Abomination';

-- [285] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN hero_attribute AS ha ON ha.hero_id = s.id
JOIN attribute AS a ON a.id = ha.attribute_id
WHERE a.attribute_name = 'Speed'
ORDER BY ha.attribute_value DESC
LIMIT 1;

-- [286] db_id=superhero
SELECT a.attribute_name,
       ha.attribute_value
FROM superhero s
JOIN hero_attribute ha ON ha.hero_id = s.id
JOIN attribute a ON a.id = ha.attribute_id
WHERE s.superhero_name = '3-D Man'
ORDER BY a.attribute_name;

-- [287] db_id=superhero
SELECT s.superhero_name
FROM superhero AS s
JOIN colour AS eye ON eye.id = s.eye_colour_id
JOIN colour AS hair ON hair.id = s.hair_colour_id
WHERE eye.colour = 'Blue'
  AND hair.colour = 'Brown';

-- [288] db_id=superhero
SELECT s.superhero_name, p.publisher_name
FROM superhero AS s
LEFT JOIN publisher AS p ON p.id = s.publisher_id
WHERE s.superhero_name IN ('Hawkman', 'Karate Kid', 'Speedy');

-- [289] db_id=superhero
SELECT
  100.0 * SUM(CASE WHEN eye_colour_id = 7 THEN 1 ELSE 0 END) / COUNT(superhero_name) AS percentage_blue_eyes
FROM superhero;

-- [290] db_id=superhero
SELECT
  1.0 * SUM(CASE WHEN s.gender_id = 1 THEN 1 ELSE 0 END) /
  NULLIF(SUM(CASE WHEN s.gender_id = 2 THEN 1 ELSE 0 END), 0) AS ratio
FROM superhero AS s;

-- [291] db_id=superhero
SELECT c.colour
FROM superhero s
JOIN colour c ON c.id = s.eye_colour_id
WHERE s.full_name = 'Karen Beecher-Duncan';

-- [292] db_id=superhero
SELECT
  SUM(CASE WHEN s.eye_colour_id = 7 THEN 1 ELSE 0 END) - SUM(CASE WHEN s.eye_colour_id = 1 THEN 1 ELSE 0 END) AS difference
FROM superhero s
WHERE s.weight_kg = 0 OR s.weight_kg IS NULL;

-- [293] db_id=superhero
SELECT COUNT(*) AS green_skinned_villains
FROM superhero s
JOIN colour c ON s.skin_colour_id = c.id
JOIN alignment a ON s.alignment_id = a.id
WHERE c.colour = 'Green'
  AND a.alignment = 'Bad';

-- [294] db_id=superhero
SELECT DISTINCT s.superhero_name
FROM superhero AS s
JOIN hero_power AS hp ON hp.hero_id = s.id
JOIN superpower AS sp ON sp.id = hp.power_id
WHERE sp.power_name = 'Wind Control'
  AND s.superhero_name IS NOT NULL
ORDER BY s.superhero_name ASC;

-- [295] db_id=superhero
SELECT g.gender
FROM superhero s
JOIN gender g ON g.id = s.gender_id
JOIN hero_power hp ON hp.hero_id = s.id
JOIN superpower sp ON sp.id = hp.power_id
WHERE sp.power_name = 'Phoenix Force'
LIMIT 1;

-- [296] db_id=superhero
SELECT
  SUM(CASE WHEN p.publisher_name = 'DC Comics' THEN 1 ELSE 0 END)
  - SUM(CASE WHEN p.publisher_name = 'Marvel Comics' THEN 1 ELSE 0 END) AS difference
FROM superhero s
JOIN publisher p ON p.id = s.publisher_id;

-- [297] db_id=codebase_community
SELECT DisplayName, Reputation
FROM users
WHERE DisplayName IN ('Harlan', 'Jarrod Dixon')
ORDER BY Reputation DESC
LIMIT 1;

-- [298] db_id=codebase_community
SELECT DisplayName
FROM users
WHERE strftime('%Y', CreationDate) = '2011';

-- [299] db_id=codebase_community
SELECT COUNT(*) AS UserCount
FROM users
WHERE LastAccessDate > '2014-09-01';

-- [300] db_id=codebase_community
SELECT u.DisplayName
FROM posts p
JOIN users u ON u.Id = p.OwnerUserId
WHERE p.Title = 'Eliciting priors from experts';

-- [301] db_id=codebase_community
SELECT COUNT(*) AS PostCount
FROM posts p
JOIN users u ON u.Id = p.OwnerUserId
WHERE u.DisplayName = 'csgillespie';

-- [302] db_id=codebase_community
SELECT u.DisplayName
FROM posts AS p
JOIN users AS u
  ON u.Id = p.LastEditorUserId
WHERE p.Title = 'Examples for teaching: Correlation does not mean causation';

-- [303] db_id=codebase_community
SELECT COUNT(*) AS PostCount
FROM posts p
JOIN users u ON u.Id = p.OwnerUserId
WHERE u.Age > 65
  AND p.Score >= 20;

-- [304] db_id=codebase_community
SELECT p.Body
FROM tags AS t
JOIN posts AS p
  ON p.Id = t.ExcerptPostId
WHERE t.TagName = 'bayesian';

-- [305] db_id=codebase_community
SELECT AVG(p.Score) AS AvgPostScore
FROM posts AS p
JOIN users AS u ON u.Id = p.OwnerUserId
WHERE u.DisplayName = 'csgillespie';

-- [306] db_id=codebase_community
SELECT
  100.0 * SUM(CASE WHEN u.Age > 65 THEN 1 ELSE 0 END) / COUNT(*) AS percentage_owned_by_elder_user
FROM posts p
JOIN users u ON u.Id = p.OwnerUserId
WHERE p.Score > 5;

-- [307] db_id=codebase_community
SELECT p.FavoriteCount
FROM comments c
JOIN posts p ON p.Id = c.PostId
WHERE c.UserId = 3025
  AND c.CreationDate = '2014/4/23 20:29:39.0';

-- [308] db_id=codebase_community
SELECT CASE WHEN p.ClosedDate IS NULL THEN 'not well-finished' ELSE 'well-finished' END AS PostWellFinished
FROM comments c
JOIN posts p ON p.Id = c.PostId
WHERE c.UserId = 23853
  AND c.CreationDate = '2013-07-12 09:08:18.0';

-- [309] db_id=codebase_community
SELECT COUNT(*) AS PostCount
FROM posts p
JOIN users u ON u.Id = p.OwnerUserId
WHERE u.DisplayName = 'Tiago Pasqualini';

-- [310] db_id=codebase_community
SELECT u.DisplayName
FROM votes v
JOIN users u ON u.Id = v.UserId
WHERE v.Id = 6347;

-- [311] db_id=codebase_community
SELECT
  CAST(COUNT(DISTINCT p.Id) AS REAL) / NULLIF(COUNT(DISTINCT v.Id), 0) AS times_posts_than_votes
FROM users u
LEFT JOIN posts p ON p.OwnerUserId = u.Id
LEFT JOIN votes v ON v.UserId = u.Id
WHERE u.Id = 24;

-- [312] db_id=codebase_community
SELECT ViewCount
FROM posts
WHERE Title = 'Integration of Weka and/or RapidMiner into Informatica PowerCenter/Developer'
LIMIT 1;

-- [313] db_id=codebase_community
SELECT Text
FROM comments
WHERE Score = 17;

-- [314] db_id=codebase_community
SELECT u.DisplayName
FROM comments c
JOIN users u ON u.Id = c.UserId
WHERE c.Text = 'thank you user93!';

-- [315] db_id=codebase_community
SELECT u.DisplayName,
       u.Reputation
FROM posts AS p
JOIN users AS u
  ON u.Id = p.OwnerUserId
WHERE p.Title = 'Understanding what Dassault iSight is doing?';

-- [316] db_id=codebase_community
SELECT u.DisplayName
FROM posts AS p
JOIN users AS u ON u.Id = p.OwnerUserId
WHERE p.Title = 'Open source tools for visualizing multi-dimensional data?';

-- [317] db_id=codebase_community
SELECT c.*
FROM comments AS c
JOIN posts AS p ON p.Id = c.PostId
WHERE p.Title = 'Why square the difference instead of taking the absolute value in standard deviation?'
  AND c.UserId IN (
    SELECT DISTINCT ph.UserId
    FROM postHistory AS ph
    WHERE ph.PostId = p.Id
      AND ph.UserId IS NOT NULL
  );

-- [318] db_id=codebase_community
SELECT u.DisplayName
FROM votes v
JOIN posts p ON p.Id = v.PostId
JOIN users u ON u.Id = v.UserId
WHERE v.BountyAmount = 50
  AND p.Title LIKE '%variance%';

-- [319] db_id=codebase_community
SELECT
  p.Title,
  c.Text AS Comment,
  AVG(p.ViewCount) AS AvgViewCount
FROM posts AS p
LEFT JOIN comments AS c
  ON c.PostId = p.Id
WHERE p.Tags = '<humor>'
GROUP BY
  p.Id,
  p.Title,
  c.Id,
  c.Text;

-- [320] db_id=codebase_community
SELECT COUNT(*)
FROM (
  SELECT UserId
  FROM badges
  WHERE UserId IS NOT NULL
  GROUP BY UserId
  HAVING COUNT(Name) > 5
) AS t;

-- [321] db_id=codebase_community
SELECT p.OwnerUserId AS UserId
FROM posts AS p
JOIN postHistory AS ph
  ON ph.PostId = p.Id
JOIN users AS u
  ON u.Id = p.OwnerUserId
WHERE u.Views >= 1000
GROUP BY p.OwnerUserId, p.Id
HAVING COUNT(ph.Id) = 1;

-- [322] db_id=codebase_community
SELECT
  (CAST(SUM(CASE WHEN Name = 'Student' AND strftime('%Y', Date) = '2010' THEN 1 ELSE 0 END) AS REAL) * 100.0 / COUNT(*))
  -
  (CAST(SUM(CASE WHEN Name = 'Student' AND strftime('%Y', Date) = '2011' THEN 1 ELSE 0 END) AS REAL) * 100.0 / COUNT(*)) AS percentage_difference
FROM badges;

-- [323] db_id=codebase_community
SELECT
  SUM(u.UpVotes) * 1.0 / COUNT(u.Id) AS AvgUpVotes,
  SUM(u.Age) * 1.0 / COUNT(u.Id) AS AvgAge
FROM users u
JOIN (
  SELECT OwnerUserId AS UserId
  FROM posts
  WHERE OwnerUserId IS NOT NULL
  GROUP BY OwnerUserId
  HAVING COUNT(*) > 10
) p ON p.UserId = u.Id;

-- [324] db_id=codebase_community
SELECT
  1.0 * SUM(CASE WHEN strftime('%Y', CreationDate) = '2010' THEN 1 ELSE 0 END)
  / NULLIF(SUM(CASE WHEN strftime('%Y', CreationDate) = '2011' THEN 1 ELSE 0 END), 0) AS vote_ratio_2010_to_2011
FROM votes;

-- [325] db_id=codebase_community
SELECT p.Id
FROM posts AS p
JOIN users AS u ON u.Id = p.OwnerUserId
WHERE u.DisplayName = 'slashnick'
ORDER BY p.AnswerCount DESC, p.Id
LIMIT 1;

-- [326] db_id=codebase_community
SELECT
  u.DisplayName,
  SUM(p.ViewCount) AS TotalViewCount
FROM users u
JOIN posts p ON p.OwnerUserId = u.Id
WHERE u.DisplayName IN ('Harvey Motulsky', 'Noah Snyder')
GROUP BY u.DisplayName
ORDER BY TotalViewCount DESC
LIMIT 1

-- [327] db_id=codebase_community
SELECT DISTINCT TRIM(t.value) AS Tag
FROM posts p
JOIN users u ON u.Id = p.OwnerUserId
JOIN json_each('["' || REPLACE(TRIM(BOTH '<>' FROM IFNULL(p.Tags,'')), '><', '","') || '"]') AS t
WHERE u.DisplayName = 'Mark Meckes'
  AND IFNULL(p.CommentCount, 0) = 0
  AND TRIM(t.value) <> ''
ORDER BY Tag;

-- [328] db_id=codebase_community
SELECT
  100.0 * SUM(CASE WHEN p.Tags LIKE '%<r>%' THEN 1 ELSE 0 END) / COUNT(*) AS percentage
FROM posts AS p
JOIN users AS u
  ON u.Id = p.OwnerUserId
WHERE u.DisplayName = 'Community';

-- [329] db_id=codebase_community
SELECT
  COALESCE(SUM(CASE WHEN u.DisplayName = 'Mornington' THEN p.ViewCount END), 0) -
  COALESCE(SUM(CASE WHEN u.DisplayName = 'Amos' THEN p.ViewCount END), 0) AS ViewCountDifference
FROM posts p
JOIN users u ON u.Id = p.OwnerUserId;

-- [330] db_id=codebase_community
SELECT COUNT(pl.Id) * 1.0 / 12.0 AS avg_monthly_links_2010_no_more_than_2_answers
FROM postLinks AS pl
JOIN posts AS p ON p.Id = pl.PostId
WHERE strftime('%Y', pl.CreationDate) = '2010'
  AND COALESCE(p.AnswerCount, 0) <= 2;

-- [331] db_id=codebase_community
SELECT MIN(v.CreationDate) AS FirstVoteDate
FROM votes v
JOIN users u ON u.Id = v.UserId
WHERE u.DisplayName = 'chl';

-- [332] db_id=codebase_community
SELECT u.DisplayName
FROM badges b
JOIN users u ON u.Id = b.UserId
WHERE b.Name = 'Autobiographer'
ORDER BY b.Date ASC
LIMIT 1

-- [333] db_id=codebase_community
SELECT COUNT(DISTINCT u.Id)
FROM users AS u
JOIN posts AS p
  ON p.OwnerUserId = u.Id
WHERE u.Location = 'United Kingdom'
  AND p.FavoriteCount >= 4;

-- [334] db_id=codebase_community
SELECT p.Id,
       p.Title
FROM posts AS p
JOIN users AS u
  ON u.Id = p.OwnerUserId
WHERE u.DisplayName = 'Harvey Motulsky'
ORDER BY p.ViewCount DESC
LIMIT 1;

-- [335] db_id=codebase_community
SELECT
  p.Id,
  p.OwnerDisplayName
FROM posts AS p
WHERE p.FavoriteCount IS NOT NULL
  AND strftime('%Y', p.CreaionDate) = '2010'
ORDER BY p.FavoriteCount DESC, p.Id ASC
LIMIT 1;

-- [336] db_id=codebase_community
SELECT
  100.0 * SUM(CASE WHEN u.Reputation > 1000 THEN 1 ELSE 0 END) / COUNT(p.Id) AS PercentageOfPosts
FROM posts AS p
JOIN users AS u
  ON u.Id = p.OwnerUserId
WHERE strftime('%Y', p.CreaionDate) = '2011';

-- [337] db_id=codebase_community
SELECT p.ViewCount AS TotalViews,
       u.DisplayName AS LastPostedBy
FROM posts AS p
LEFT JOIN users AS u
  ON u.Id = p.LastEditorUserId
WHERE p.Title = 'Computer Game Datasets'
ORDER BY p.LastEditDate DESC, p.Id DESC
LIMIT 1;

-- [338] db_id=codebase_community
SELECT COUNT(*) AS CommentCount
FROM comments
WHERE PostId = (
  SELECT Id
  FROM posts
  WHERE Score = (SELECT MAX(Score) FROM posts)
  ORDER BY Id
  LIMIT 1
);

-- [339] db_id=codebase_community
SELECT
  c.Text,
  COALESCE(u.DisplayName, c.UserDisplayName) AS DisplayName
FROM posts p
JOIN comments c
  ON c.PostId = p.Id
LEFT JOIN users u
  ON u.Id = c.UserId
WHERE p.Title = 'Analysing wind data with R'
ORDER BY c.CreationDate DESC, c.Id DESC
LIMIT 10;

-- [340] db_id=codebase_community
SELECT
  100.0 * SUM(CASE WHEN p.Score > 50 THEN 1 ELSE 0 END) / COUNT(p.Id) AS percentage_above_50
FROM posts p
WHERE p.OwnerUserId = (
  SELECT u.Id
  FROM users u
  WHERE u.Reputation = (SELECT MAX(Reputation) FROM users)
);

-- [341] db_id=codebase_community
SELECT ExcerptPostId, WikiPostId
FROM tags
WHERE TagName = 'sample';

-- [342] db_id=codebase_community
SELECT u.Reputation,
       u.UpVotes
FROM comments AS c
JOIN users AS u
  ON u.Id = c.UserId
WHERE c.Text = 'fine, you win :)'
LIMIT 1;

-- [343] db_id=codebase_community
SELECT c.Text
FROM comments AS c
JOIN posts AS p ON p.Id = c.PostId
WHERE p.ViewCount BETWEEN 100 AND 150
ORDER BY c.Score DESC, c.Id ASC
LIMIT 1;

-- [344] db_id=codebase_community
SELECT COUNT(*) AS ZeroScoreCommentsOnSingleCommentPosts
FROM posts p
JOIN comments c ON c.PostId = p.Id
WHERE p.CommentCount = 1
  AND c.Score = 0;

-- [345] db_id=codebase_community
SELECT
  100.0 * SUM(CASE WHEN u.UpVotes = 0 THEN 1 ELSE 0 END) / COUNT(c.UserId) AS percentage_users_with_0_upvotes
FROM comments c
JOIN users u ON u.Id = c.UserId
WHERE c.Score BETWEEN 5 AND 10
  AND c.UserId IS NOT NULL;

-- [346] db_id=card_games
SELECT
  *
FROM cards
WHERE cardKingdomFoilId IS NOT NULL
  AND cardKingdomId IS NOT NULL;

-- [347] db_id=card_games
SELECT
  uuid,
  name,
  setCode,
  number,
  borderColor,
  cardKingdomId,
  cardKingdomFoilId
FROM cards
WHERE borderColor = 'borderless'
  AND cardKingdomId IS NOT NULL
  AND cardKingdomFoilId IS NULL;

-- [348] db_id=card_games
SELECT DISTINCT
  c.*
FROM cards AS c
JOIN legalities AS l
  ON l.uuid = c.uuid
WHERE c.rarity = 'mythic'
  AND l.format = 'gladiator'
  AND l.status = 'Banned';

-- [349] db_id=card_games
SELECT
  c.uuid,
  c.name,
  l.status AS vintage_status
FROM cards AS c
LEFT JOIN legalities AS l
  ON l.uuid = c.uuid
 AND l.format = 'vintage'
WHERE c.types = 'Artifact'
  AND c.side IS NULL;

-- [350] db_id=card_games
SELECT DISTINCT c.id,
       c.artist
FROM cards AS c
JOIN legalities AS l
  ON l.uuid = c.uuid
WHERE (c.power = '*' OR c.power IS NULL)
  AND l.format = 'commander'
  AND l.status = 'Legal';

-- [351] db_id=card_games
SELECT
  c.id AS card_id,
  r.text AS ruling_text,
  CASE WHEN c.hasContentWarning = 1 THEN 1 ELSE 0 END AS has_missing_or_degraded_properties
FROM cards AS c
LEFT JOIN rulings AS r
  ON r.uuid = c.uuid
WHERE c.artist = 'Stephen Daniele'
ORDER BY c.id, r.date, r.id;

-- [352] db_id=card_games
SELECT
  c.name,
  c.artist,
  (c.isPromo = 1) AS isPromotionalPrinting
FROM cards AS c
JOIN rulings AS r
  ON r.uuid = c.uuid
GROUP BY c.uuid, c.name, c.artist, c.isPromo
ORDER BY COUNT(r.uuid) DESC
LIMIT 1;

-- [353] db_id=card_games
SELECT
  100.0 * SUM(CASE WHEN language = 'Chinese Simplified' THEN 1 ELSE 0 END) / COUNT(*) AS percentage_chinese_simplified
FROM foreign_data;

-- [354] db_id=card_games
SELECT COUNT(*) AS infinite_power_cards
FROM cards
WHERE power = '*';

-- [355] db_id=card_games
SELECT borderColor
FROM cards
WHERE name = 'Ancestor''s Chosen'
LIMIT 1;

-- [356] db_id=card_games
SELECT l.format,
       l.status
FROM cards AS c
JOIN legalities AS l
  ON l.uuid = c.uuid
WHERE c.name = 'Benalish Knight'
ORDER BY l.format;

-- [357] db_id=card_games
SELECT
  (COUNT(CASE WHEN borderColor = 'borderless' THEN 1 END) * 100.0) / COUNT(id) AS percentage_borderless_cards
FROM cards;

-- [358] db_id=card_games
SELECT
  100.0 * SUM(CASE WHEN fd.language = 'French' THEN 1 ELSE 0 END) / COUNT(*) AS percentage_french_story_spotlight
FROM cards c
JOIN foreign_data fd ON fd.uuid = c.uuid
WHERE c.isStorySpotlight = 1;

-- [359] db_id=card_games
SELECT COUNT(*)
FROM cards
WHERE originalType = 'Summon - Angel'
  AND subtypes IS NOT NULL
  AND TRIM(subtypes) <> 'Angel';

-- [360] db_id=card_games
SELECT id
FROM cards
WHERE duelDeck = 'a';

-- [361] db_id=card_games
SELECT COUNT(DISTINCT c.uuid) AS banned_white_border_count
FROM legalities l
JOIN cards c ON c.uuid = l.uuid
WHERE l.status = 'Banned'
  AND c.borderColor = 'white';

-- [362] db_id=card_games
SELECT DISTINCT
  c.uuid,
  c.name,
  c.setCode,
  c.originalType,
  c.colors,
  fd.language,
  fd.name AS foreignName
FROM cards AS c
JOIN foreign_data AS fd
  ON fd.uuid = c.uuid
WHERE c.originalType = 'Artifact'
  AND c.colors = 'B'
  AND fd.language IS NOT NULL
  AND TRIM(fd.language) <> '';

-- [363] db_id=card_games
SELECT manaCost
FROM cards
WHERE layout = 'normal'
  AND frameVersion = '2003'
  AND borderColor = 'black'
  AND availability = 'mtgo,paper';

-- [364] db_id=card_games
SELECT
  (CAST(SUM(CASE WHEN isStorySpotlight = 1 AND isTextless = 0 THEN 1 ELSE 0 END) AS REAL) / COUNT(*)) * 100.0 AS percentage_story_spotlight_not_textless,
  GROUP_CONCAT(CASE WHEN isStorySpotlight = 1 AND isTextless = 0 THEN id END) AS ids
FROM cards;

-- [365] db_id=card_games
SELECT COUNT(DISTINCT st.setCode) AS brazilian_portuguese_translated_sets_in_commander_block
FROM sets s
JOIN set_translations st ON st.setCode = s.code
WHERE s.block = 'Commander'
  AND st.language = 'Portuguese (Brasil)';

-- [366] db_id=card_games
SELECT DISTINCT fd.type
FROM foreign_data AS fd
JOIN cards AS c ON c.uuid = fd.uuid
WHERE fd.language = 'German'
  AND c.subtypes IS NOT NULL
  AND c.supertypes IS NOT NULL
  AND fd.type IS NOT NULL;

-- [367] db_id=card_games
SELECT COUNT(*) AS unknown_power_triggered_ability_count
FROM cards
WHERE (power IS NULL OR power = '*')
  AND text LIKE '%triggered ability%';

-- [368] db_id=card_games
SELECT COUNT(DISTINCT c.uuid) AS card_count
FROM cards AS c
JOIN legalities AS l
  ON l.uuid = c.uuid
JOIN rulings AS r
  ON r.uuid = c.uuid
WHERE l.format = 'premodern'
  AND r.text = 'This is a triggered mana ability.'
  AND c.side IS NULL;

-- [369] db_id=card_games
SELECT fd.name
FROM cards AS c
JOIN foreign_data AS fd
  ON fd.uuid = c.uuid
WHERE fd.language = 'French'
  AND c.type LIKE '%Creature%'
  AND c.layout = 'normal'
  AND c.borderColor = 'black'
  AND c.artist = 'Matthew D. Wilson';

-- [370] db_id=card_games
SELECT st.language
FROM sets AS s
JOIN set_translations AS st
  ON st.setCode = s.code
WHERE s.block = 'Ravnica'
  AND s.baseSetSize = 180;

-- [371] db_id=card_games
SELECT
  100.0 * SUM(CASE WHEN c.hasContentWarning = 0 THEN 1 ELSE 0 END) / COUNT(c.id) AS percentage_no_content_warning
FROM cards c
JOIN legalities l ON l.uuid = c.uuid
WHERE l.format = 'commander'
  AND l.status = 'legal';

-- [372] db_id=card_games
SELECT
  100.0 * SUM(CASE WHEN fd.language = 'French' THEN 1 ELSE 0 END) / COUNT(*) AS percentage_in_french
FROM cards c
LEFT JOIN foreign_data fd ON fd.uuid = c.uuid
WHERE c.power IS NULL OR c.power = '*';

-- [373] db_id=card_games
SELECT language
FROM foreign_data
WHERE multiverseid = 149934;

-- [374] db_id=card_games
SELECT
  (COUNT(CASE WHEN isTextless = 1 AND layout = 'normal' THEN 1 END) * 100.0) / NULLIF(COUNT(CASE WHEN isTextless = 1 THEN 1 END), 0) AS proportion_textless_normal_layout_pct
FROM cards;

-- [375] db_id=card_games
SELECT DISTINCT st.language
FROM sets AS s
JOIN set_translations AS st
  ON st.setCode = s.code
WHERE s.code = 'ARC'
  AND s.mcmName = 'Archenemy'
ORDER BY st.language;

-- [376] db_id=card_games
SELECT DISTINCT fd.language
FROM foreign_data AS fd
JOIN cards AS c ON c.uuid = fd.uuid
WHERE c.name = 'A Pedra Fellwar';

-- [377] db_id=card_games
SELECT
  CASE
    WHEN s.convertedManaCost > k.convertedManaCost THEN 'Serra Angel'
    WHEN s.convertedManaCost < k.convertedManaCost THEN 'Shrine Keeper'
    ELSE 'Equal'
  END AS card_with_higher_converted_mana_cost
FROM
  (SELECT MAX(convertedManaCost) AS convertedManaCost FROM cards WHERE name = 'Serra Angel') s
CROSS JOIN
  (SELECT MAX(convertedManaCost) AS convertedManaCost FROM cards WHERE name = 'Shrine Keeper') k;

-- [378] db_id=card_games
SELECT st.translation AS italian_set_name
FROM cards c
JOIN set_translations st
  ON st.setCode = c.setCode
WHERE c.name = 'Ancestor''s Chosen'
  AND st.language = 'Italian'
LIMIT 1;

-- [379] db_id=card_games
SELECT
  CASE WHEN EXISTS (
    SELECT 1
    FROM cards c
    JOIN foreign_data f ON f.uuid = c.uuid
    WHERE c.name = 'Ancestor''s Chosen'
      AND f.language = 'Korean'
  )
  THEN 1 ELSE 0 END AS has_korean_version;

-- [380] db_id=card_games
SELECT COUNT(*) AS card_count
FROM cards c
JOIN set_translations st
  ON st.setCode = c.setCode
WHERE st.translation = 'Hauptset Zehnte Edition'
  AND c.artist = 'Adam Rex';

-- [381] db_id=card_games
SELECT st.translation
FROM sets s
JOIN set_translations st ON st.setCode = s.code
WHERE s.name = 'Eighth Edition'
  AND st.language = 'Chinese Simplified';

-- [382] db_id=card_games
SELECT CASE WHEN EXISTS (
    SELECT 1
    FROM cards c
    JOIN sets s ON s.code = c.setCode
    WHERE c.name = 'Angel of Mercy'
      AND s.mtgoCode IS NOT NULL
) THEN 1 ELSE 0 END AS appeared_on_mtgo;

-- [383] db_id=card_games
SELECT COUNT(DISTINCT s.code) AS italian_translated_sets_in_ice_age_block
FROM sets AS s
JOIN set_translations AS st
  ON st.setCode = s.code
WHERE s.block = 'Ice Age'
  AND st.language = 'Italian'
  AND st.translation IS NOT NULL;

-- [384] db_id=card_games
SELECT
  CASE
    WHEN COUNT(*) > 0 AND SUM(CASE WHEN s.isForeignOnly = 1 THEN 1 ELSE 0 END) = COUNT(*) THEN 1
    ELSE 0
  END AS only_available_outside_us
FROM cards c
JOIN sets s ON s.code = c.setCode
WHERE c.name = 'Adarkar Valkyrie';

-- [385] db_id=card_games
SELECT COUNT(DISTINCT s.code) AS count_sets
FROM sets AS s
JOIN set_translations AS st
  ON st.setCode = s.code
WHERE st.language = 'Italian'
  AND st.translation IS NOT NULL
  AND s.baseSetSize < 10;

-- [386] db_id=card_games
SELECT DISTINCT c.artist
FROM cards c
JOIN sets s ON s.code = c.setCode
WHERE s.name = 'Coldsnap'
  AND c.artist IN ('Jeremy Jarvis', 'Aaron Miller', 'Chippy');

-- [387] db_id=card_games
SELECT COUNT(*) AS unknown_power_count
FROM cards AS c
JOIN sets AS s
  ON s.code = c.setCode
WHERE s.name = 'Coldsnap'
  AND c.convertedManaCost > 5
  AND (c.power IS NULL OR c.power = '*');

-- [388] db_id=card_games
SELECT fd.flavorText
FROM foreign_data AS fd
JOIN cards AS c ON c.uuid = fd.uuid
WHERE c.name = 'Ancestor''s Chosen'
  AND fd.language = 'Italian'
  AND fd.flavorText IS NOT NULL;

-- [389] db_id=card_games
SELECT
  c.name AS cardName,
  fd.text AS italianRulingText
FROM sets s
JOIN cards c
  ON c.setCode = s.code
JOIN foreign_data fd
  ON fd.uuid = c.uuid
WHERE s.name = 'Coldsnap'
  AND fd.language = 'Italian'
  AND fd.text IS NOT NULL
ORDER BY c.name, fd.id;

-- [390] db_id=card_games
SELECT fd.name
FROM cards AS c
JOIN sets AS s
  ON s.code = c.setCode
JOIN foreign_data AS fd
  ON fd.uuid = c.uuid
WHERE s.name = 'Coldsnap'
  AND fd.language = 'Italian'
  AND c.convertedManaCost = (
    SELECT MAX(c2.convertedManaCost)
    FROM cards AS c2
    JOIN sets AS s2
      ON s2.code = c2.setCode
    WHERE s2.name = 'Coldsnap'
  );

-- [391] db_id=card_games
SELECT
  100.0 * SUM(CASE WHEN c.convertedManaCost = 7 THEN 1 ELSE 0 END) / COUNT(*) AS percentage_cards_cmc_7
FROM cards c
JOIN sets s ON s.code = c.setCode
WHERE s.name = 'Coldsnap';

-- [392] db_id=card_games
SELECT
  100.0 * SUM(CASE WHEN c.cardKingdomFoilId IS NOT NULL AND c.cardKingdomId IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS percentage_incredibly_powerful
FROM cards c
JOIN sets s ON s.code = c.setCode
WHERE s.name = 'Coldsnap';

-- [393] db_id=card_games
WITH banned_counts AS (
  SELECT l.format, COUNT(*) AS banned_count
  FROM legalities l
  WHERE l.status = 'Banned'
  GROUP BY l.format
),
max_format AS (
  SELECT format
  FROM banned_counts
  WHERE banned_count = (SELECT MAX(banned_count) FROM banned_counts)
)
SELECT
  l.format,
  c.name
FROM legalities l
JOIN cards c ON c.uuid = l.uuid
WHERE l.status = 'Banned'
  AND l.format IN (SELECT format FROM max_format)
ORDER BY l.format, c.name;

-- [394] db_id=card_games
SELECT c.name, l.format
FROM cards AS c
JOIN legalities AS l
  ON l.uuid = c.uuid
WHERE c.edhrecRank = 1
  AND l.status = 'Banned';

-- [395] db_id=card_games
SELECT
  c.name AS card_name,
  l.format
FROM sets s
JOIN cards c
  ON c.setCode = s.code
JOIN legalities l
  ON l.uuid = c.uuid
WHERE s.name = 'Hour of Devastation'
  AND l.status = 'Legal'
ORDER BY c.name, l.format;

-- [396] db_id=card_games
SELECT s.name
FROM sets AS s
WHERE EXISTS (
    SELECT 1
    FROM set_translations AS st
    WHERE st.setCode = s.code
      AND st.language = 'Korean'
)
AND NOT EXISTS (
    SELECT 1
    FROM set_translations AS st
    WHERE st.setCode = s.code
      AND st.language LIKE '%Japanese%'
);

-- [397] db_id=card_games
SELECT
  c.frameVersion AS frameStyle,
  c.name AS cardName,
  c.uuid AS cardUuid,
  l.format AS bannedFormat,
  l.status AS legalityStatus
FROM cards c
LEFT JOIN legalities l
  ON l.uuid = c.uuid
  AND l.status = 'Banned'
WHERE c.artist = 'Allen Williams'
ORDER BY
  c.frameVersion,
  c.name,
  l.format;

-- [398] db_id=toxicology
SELECT bond_type
FROM bond
WHERE bond_type IS NOT NULL
GROUP BY bond_type
ORDER BY COUNT(*) DESC
LIMIT 1

-- [399] db_id=toxicology
SELECT AVG(o_cnt) AS avg_oxygen_atoms
FROM (
  SELECT m.molecule_id,
         SUM(CASE WHEN a.element = 'o' THEN 1 ELSE 0 END) AS o_cnt
  FROM molecule AS m
  JOIN bond AS b
    ON b.molecule_id = m.molecule_id
   AND b.bond_type = '-'
  JOIN atom AS a
    ON a.molecule_id = m.molecule_id
  GROUP BY m.molecule_id
);

-- [400] db_id=toxicology
SELECT
  1.0 * SUM(CASE WHEN b.bond_type = '-' THEN 1 ELSE 0 END) / COUNT(a.atom_id) AS avg_single_bonded_carcinogenic
FROM molecule m
JOIN atom a
  ON a.molecule_id = m.molecule_id
LEFT JOIN bond b
  ON b.molecule_id = m.molecule_id
WHERE m.label = '+';

-- [401] db_id=toxicology
SELECT DISTINCT m.molecule_id, m.label
FROM molecule AS m
JOIN bond AS b
  ON b.molecule_id = m.molecule_id
WHERE b.bond_type = '#'
  AND m.label = '+';

-- [402] db_id=toxicology
SELECT
  1.0 * SUM(CASE WHEN a.element = 'c' THEN 1 ELSE 0 END) / COUNT(a.atom_id) AS percentage_carbon
FROM atom AS a
WHERE a.molecule_id IN (
  SELECT DISTINCT b.molecule_id
  FROM bond AS b
  WHERE b.bond_type = '='
);

-- [403] db_id=toxicology
SELECT DISTINCT a.element
FROM connected c
JOIN atom a ON a.atom_id = c.atom_id
WHERE c.bond_id = 'TR004_8_9'
UNION
SELECT DISTINCT a2.element
FROM connected c
JOIN atom a2 ON a2.atom_id = c.atom_id2
WHERE c.bond_id = 'TR004_8_9';

-- [404] db_id=toxicology
SELECT DISTINCT a.element
FROM bond b
JOIN connected c ON c.bond_id = b.bond_id
JOIN atom a ON a.atom_id IN (c.atom_id, c.atom_id2)
WHERE b.bond_type = '=' AND a.element IS NOT NULL;

-- [405] db_id=toxicology
SELECT m.label
FROM atom a
JOIN molecule m ON m.molecule_id = a.molecule_id
WHERE a.element = 'h'
GROUP BY m.label
ORDER BY COUNT(*) DESC
LIMIT 1;

-- [406] db_id=toxicology
SELECT a.element
FROM molecule m
JOIN atom a ON a.molecule_id = m.molecule_id
WHERE m.label = '-'
  AND a.element IS NOT NULL
GROUP BY a.element
ORDER BY COUNT(*) ASC
LIMIT 1;

-- [407] db_id=toxicology
SELECT b.bond_type
FROM connected c
JOIN bond b ON b.bond_id = c.bond_id
WHERE (c.atom_id = 'TR004_8' AND c.atom_id2 = 'TR004_20')
   OR (c.atom_id = 'TR004_20' AND c.atom_id2 = 'TR004_8');

-- [408] db_id=toxicology
SELECT
  COUNT(DISTINCT CASE WHEN a.element = 'i' THEN a.atom_id END) AS iodine_atoms,
  COUNT(DISTINCT CASE WHEN a.element = 's' THEN a.atom_id END) AS sulfur_atoms
FROM atom AS a
JOIN molecule AS m
  ON m.molecule_id = a.molecule_id
WHERE EXISTS (
  SELECT 1
  FROM bond AS b
  WHERE b.molecule_id = m.molecule_id
    AND b.bond_type = '-'
);

-- [409] db_id=toxicology
SELECT
  100.0 * (
    COUNT(*) - SUM(CASE WHEN has_fluorine = 1 THEN 1 ELSE 0 END)
  ) / COUNT(*) AS pct_carcinogenic_without_fluorine
FROM (
  SELECT
    m.molecule_id,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM atom a
        WHERE a.molecule_id = m.molecule_id
          AND LOWER(a.element) = 'f'
      ) THEN 1 ELSE 0
    END AS has_fluorine
  FROM molecule m
  WHERE m.label = '+'
) t;

-- [410] db_id=toxicology
SELECT
  (SUM(CASE WHEN b.bond_type = '#' THEN 1 ELSE 0 END) * 100.0) / COUNT(b.bond_id) AS percent
FROM bond AS b
JOIN molecule AS m
  ON m.molecule_id = b.molecule_id
WHERE m.label = '+';

-- [411] db_id=toxicology
SELECT DISTINCT a.element
FROM atom AS a
WHERE a.molecule_id = 'TR000'
  AND a.element IS NOT NULL
ORDER BY a.element ASC
LIMIT 3;

-- [412] db_id=toxicology
SELECT
  printf('%.5f', 100.0 * SUM(CASE WHEN bond_type = '=' THEN 1 ELSE 0 END) / COUNT(bond_id)) AS percentage_double_bonds
FROM bond
WHERE molecule_id = 'TR008';

-- [413] db_id=toxicology
SELECT
  ROUND(100.0 * SUM(CASE WHEN label = '+' THEN 1 ELSE 0 END) / COUNT(molecule_id), 3) AS carcinogenic_percentage
FROM molecule;

-- [414] db_id=toxicology
SELECT
  printf('%.4f', 100.0 * SUM(CASE WHEN element = 'h' THEN 1 ELSE 0 END) / COUNT(atom_id)) AS hydrogen_percentage
FROM atom
WHERE molecule_id = 'TR206';

-- [415] db_id=toxicology
SELECT a.element,
       m.label
FROM molecule AS m
JOIN atom AS a
  ON a.molecule_id = m.molecule_id
WHERE m.molecule_id = 'TR060';

-- [416] db_id=toxicology
SELECT
  b.bond_type,
  COUNT(*) AS bond_count,
  CASE
    WHEN m.label LIKE '%carcinogen%' OR m.label LIKE '%carcinogenic%' THEN 'yes'
    ELSE 'no'
  END AS is_carcinogenic
FROM bond AS b
JOIN molecule AS m
  ON m.molecule_id = b.molecule_id
WHERE b.molecule_id = 'TR010'
GROUP BY b.bond_type
ORDER BY bond_count DESC
LIMIT 1;

-- [417] db_id=toxicology
SELECT DISTINCT m.molecule_id
FROM molecule AS m
JOIN bond AS b
  ON b.molecule_id = m.molecule_id
JOIN connected AS c
  ON c.bond_id = b.bond_id
JOIN atom AS a1
  ON a1.atom_id = c.atom_id
JOIN atom AS a2
  ON a2.atom_id = c.atom_id2
WHERE m.label = '-'
  AND b.bond_type = '-'
  AND a1.atom_id <> a2.atom_id
ORDER BY m.molecule_id
LIMIT 3;

-- [418] db_id=toxicology
SELECT COUNT(DISTINCT c.bond_id) AS bond_count
FROM connected c
JOIN atom a1 ON a1.atom_id = c.atom_id
JOIN atom a2 ON a2.atom_id = c.atom_id2
WHERE a1.molecule_id = 'TR009'
  AND a2.molecule_id = 'TR009'
  AND ('TR009_12' IN (c.atom_id, c.atom_id2));

-- [419] db_id=toxicology
SELECT b.bond_type,
       c.atom_id,
       c.atom_id2
FROM bond AS b
JOIN connected AS c
  ON c.bond_id = b.bond_id
WHERE b.bond_id = 'TR001_6_9';

-- [420] db_id=toxicology
SELECT COUNT(DISTINCT bond_id) AS connection_count
FROM connected
WHERE atom_id LIKE 'TR%_19' OR atom_id2 LIKE 'TR%_19';

-- [421] db_id=toxicology
SELECT DISTINCT a.element
FROM atom AS a
WHERE a.molecule_id = 'TR004'
  AND a.element IS NOT NULL;

-- [422] db_id=toxicology
SELECT DISTINCT m.molecule_id
FROM atom AS a
JOIN molecule AS m
  ON m.molecule_id = a.molecule_id
WHERE SUBSTR(a.atom_id, 7, 2) BETWEEN '21' AND '25'
  AND m.label = '+';

-- [423] db_id=toxicology
SELECT DISTINCT c.bond_id
FROM connected AS c
JOIN atom AS a1 ON a1.atom_id = c.atom_id
JOIN atom AS a2 ON a2.atom_id = c.atom_id2
WHERE c.bond_id IS NOT NULL
  AND (
    (a1.element = 'p' AND a2.element = 'n')
    OR
    (a1.element = 'n' AND a2.element = 'p')
  );

-- [424] db_id=toxicology
SELECT
  CASE WHEN m.label = '+' THEN 'yes' ELSE 'no' END AS is_carcinogenic
FROM molecule AS m
JOIN (
  SELECT molecule_id, COUNT(*) AS double_bonds
  FROM bond
  WHERE bond_type = ' = '
  GROUP BY molecule_id
  ORDER BY double_bonds DESC
  LIMIT 1
) AS x
ON x.molecule_id = m.molecule_id;

-- [425] db_id=toxicology
SELECT
  CAST(COUNT(c.bond_id) AS REAL) / NULLIF(COUNT(DISTINCT a.atom_id), 0) AS avg_bonds_per_iodine_atom
FROM atom AS a
LEFT JOIN connected AS c
  ON c.atom_id = a.atom_id OR c.atom_id2 = a.atom_id
WHERE a.element = 'i';

-- [426] db_id=toxicology
SELECT a.element
FROM atom AS a
WHERE a.atom_id NOT IN (
  SELECT atom_id FROM connected
  UNION
  SELECT atom_id2 FROM connected
);

-- [427] db_id=toxicology
SELECT
  c.atom_id,
  c.atom_id2
FROM bond AS b
JOIN connected AS c
  ON c.bond_id = b.bond_id
WHERE b.molecule_id = 'TR041'
  AND b.bond_type = '#';

-- [428] db_id=toxicology
SELECT DISTINCT a.element
FROM bond b
JOIN connected c ON c.bond_id = b.bond_id
JOIN atom a ON a.atom_id IN (c.atom_id, c.atom_id2)
WHERE b.bond_id = 'TR144_8_19';

-- [429] db_id=toxicology
SELECT DISTINCT a.element
FROM bond b
JOIN connected c ON c.bond_id = b.bond_id
JOIN atom a ON a.atom_id IN (c.atom_id, c.atom_id2)
WHERE b.bond_type = '#'
  AND a.element IS NOT NULL;

-- [430] db_id=toxicology
SELECT
  printf(
    '%.5f',
    (SUM(CASE WHEN m.label = '+' THEN 1 ELSE 0 END) * 100.0) / COUNT(b.bond_id)
  ) AS proportion_single_bonds_carcinogenic
FROM bond AS b
JOIN molecule AS m
  ON m.molecule_id = b.molecule_id
WHERE b.bond_type = '-';

-- [431] db_id=toxicology
SELECT COUNT(DISTINCT a.atom_id) AS total_atoms
FROM atom AS a
WHERE a.molecule_id IN (
  SELECT DISTINCT b.molecule_id
  FROM bond AS b
  JOIN atom AS a2
    ON a2.molecule_id = b.molecule_id
  WHERE b.bond_type = '#'
    AND a2.element IN ('p', 'br')
);

-- [432] db_id=toxicology
SELECT
  1.0 * SUM(CASE WHEN a.element = 'cl' THEN 1 ELSE 0 END) / COUNT(a.atom_id) AS percent
FROM molecule m
JOIN bond b
  ON b.molecule_id = m.molecule_id
JOIN atom a
  ON a.molecule_id = m.molecule_id
WHERE b.bond_type = '-';

-- [433] db_id=toxicology
SELECT a1.element AS element1,
       a2.element AS element2
FROM connected c
JOIN atom a1 ON a1.atom_id = c.atom_id
JOIN atom a2 ON a2.atom_id = c.atom_id2
WHERE c.bond_id = 'TR001_10_11';

-- [434] db_id=toxicology
SELECT
  1.0 * SUM(CASE WHEN a.element = 'cl' THEN 1 ELSE 0 END) / COUNT(DISTINCT m.molecule_id) AS percentage
FROM molecule AS m
JOIN atom AS a
  ON a.molecule_id = m.molecule_id
WHERE m.label = '+';

-- [435] db_id=toxicology
SELECT a.element, COUNT(*) AS tally
FROM molecule m
JOIN atom a ON a.molecule_id = m.molecule_id
WHERE m.label = '+'
  AND substr(a.atom_id, 7, 1) = '4'
GROUP BY a.element;

-- [436] db_id=toxicology
SELECT
  m.label,
  1.0 * SUM(CASE WHEN a.element = 'h' THEN 1 ELSE 0 END) / COUNT(a.element) AS hydrogen_ratio
FROM molecule AS m
JOIN atom AS a
  ON a.molecule_id = m.molecule_id
WHERE m.molecule_id = 'TR006'
GROUP BY m.label;

-- [437] db_id=toxicology
SELECT m.molecule_id,
       m.label
FROM molecule AS m
JOIN atom AS a
  ON a.molecule_id = m.molecule_id
WHERE m.label = '-'
GROUP BY m.molecule_id, m.label
HAVING COUNT(a.atom_id) > 5;

-- [438] db_id=california_schools
SELECT COUNT(DISTINCT s.CDSCode) AS num_schools
FROM schools AS s
JOIN satscores AS sat
  ON sat.cds = s.CDSCode
WHERE sat.AvgScrMath > 400
  AND s.Virtual = 'F';

-- [439] db_id=california_schools
SELECT
  CDSCode
FROM frpm
WHERE COALESCE(`Enrollment (K-12)`, 0) + COALESCE(`Enrollment (Ages 5-17)`, 0) > 500;

-- [440] db_id=california_schools
SELECT
  MAX(
    CAST(f."Free Meal Count (Ages 5-17)" AS REAL) / NULLIF(CAST(f."Enrollment (Ages 5-17)" AS REAL), 0)
  ) AS highest_eligible_free_rate_5_17
FROM satscores AS s
JOIN frpm AS f
  ON f.CDSCode = s.cds
WHERE
  CAST(s.NumGE1500 AS REAL) / NULLIF(CAST(s.NumTstTakr AS REAL), 0) > 0.3;

-- [441] db_id=california_schools
SELECT
  s.CDSCode,
  s.School,
  s.CharterNum,
  ss.AvgScrWrite
FROM satscores AS ss
JOIN schools AS s
  ON s.CDSCode = ss.cds
WHERE ss.AvgScrWrite > 499
  AND s.CharterNum IS NOT NULL
ORDER BY ss.AvgScrWrite DESC, s.School ASC;

-- [442] db_id=california_schools
SELECT
  s.School AS school_name,
  TRIM(
    COALESCE(s.Street, '') ||
    CASE WHEN s.StreetAbr IS NOT NULL AND s.StreetAbr <> '' THEN ' ' || s.StreetAbr ELSE '' END ||
    CASE WHEN s.City IS NOT NULL AND s.City <> '' THEN ', ' || s.City ELSE '' END ||
    CASE WHEN s.State IS NOT NULL AND s.State <> '' THEN ', ' || s.State ELSE '' END ||
    CASE WHEN s.Zip IS NOT NULL AND s.Zip <> '' THEN ' ' || s.Zip ELSE '' END
  ) AS full_street_address
FROM frpm f
JOIN schools s ON s.CDSCode = f.CDSCode
WHERE ABS(COALESCE(f.`Enrollment (K-12)`, 0) - COALESCE(f.`Enrollment (Ages 5-17)`, 0)) > 30;

-- [443] db_id=california_schools
SELECT DISTINCT s.School
FROM schools AS s
JOIN frpm AS f
  ON f.CDSCode = s.CDSCode
JOIN satscores AS sa
  ON sa.cds = s.CDSCode
WHERE (f.`Enrollment (K-12)` IS NOT NULL AND f.`Enrollment (K-12)` > 0)
  AND (f.`Free Meal Count (K-12)` * 1.0 / f.`Enrollment (K-12)`) > 0.1
  AND sa.NumGE1500 IS NOT NULL
  AND sa.NumGE1500 > 0;

-- [444] db_id=california_schools
SELECT
  sc.School AS SchoolName,
  sc.FundingType
FROM schools sc
JOIN satscores sa ON sa.cds = sc.CDSCode
WHERE sc.County = 'Riverside'
GROUP BY sc.CDSCode, sc.School, sc.FundingType
HAVING (SUM(sa.AvgScrMath) * 1.0) / COUNT(sa.AvgScrMath) > 400;

-- [445] db_id=california_schools
SELECT
  s.School AS "School Name",
  TRIM(
    COALESCE(s.Street, '') ||
    CASE WHEN s.Street IS NOT NULL AND s.Street <> '' THEN ', ' ELSE '' END ||
    COALESCE(s.City, '') ||
    CASE WHEN s.City IS NOT NULL AND s.City <> '' THEN ', ' ELSE '' END ||
    COALESCE(s.State, '') ||
    CASE WHEN s.State IS NOT NULL AND s.State <> '' THEN ' ' ELSE '' END ||
    COALESCE(s.Zip, '')
  ) AS "Full Communication Address"
FROM schools AS s
JOIN frpm AS f
  ON f.CDSCode = s.CDSCode
WHERE s.County = 'Monterey'
  AND s.StatusType = 'Active'
  AND s.DOCType = 'High'
  AND COALESCE(f.`FRPM Count (Ages 5-17)`, 0) > 800;

-- [446] db_id=california_schools
SELECT
  sc.School AS school_name,
  ss.AvgScrWrite AS avg_writing_score,
  sc.Phone AS communication_number
FROM satscores AS ss
JOIN schools AS sc
  ON sc.CDSCode = ss.cds
WHERE
  (sc.OpenDate > '1991-12-31' OR (sc.ClosedDate IS NOT NULL AND sc.ClosedDate < '2000-01-01'))
  AND ss.AvgScrWrite IS NOT NULL;

-- [447] db_id=california_schools
SELECT
  s.School AS "School Name",
  s.DOCType AS "DOC Type"
FROM schools s
JOIN frpm f
  ON f.CDSCode = s.CDSCode
WHERE s.FundingType = 'Locally funded'
  AND (f."Enrollment (K-12)" - f."Enrollment (Ages 5-17)") >
    (
      SELECT AVG(f2."Enrollment (K-12)" - f2."Enrollment (Ages 5-17)")
      FROM schools s2
      JOIN frpm f2
        ON f2.CDSCode = s2.CDSCode
      WHERE s2.FundingType = 'Locally funded'
        AND f2."Enrollment (K-12)" IS NOT NULL
        AND f2."Enrollment (Ages 5-17)" IS NOT NULL
    )
  AND f."Enrollment (K-12)" IS NOT NULL
  AND f."Enrollment (Ages 5-17)" IS NOT NULL;

-- [448] db_id=california_schools
SELECT
  CDSCode,
  (`Free Meal Count (K-12)` * 1.0) / NULLIF(`Enrollment (K-12)`, 0) AS eligible_free_rate_k12
FROM frpm
WHERE `Enrollment (K-12)` IS NOT NULL
ORDER BY `Enrollment (K-12)` DESC
LIMIT 2 OFFSET 9;

-- [449] db_id=california_schools
SELECT
  s.CDSCode,
  s.School,
  f."Enrollment (K-12)" AS enrollment_k12,
  f."FRPM Count (K-12)" AS frpm_count_k12,
  (1.0 * f."FRPM Count (K-12)" / NULLIF(f."Enrollment (K-12)", 0)) AS eligible_frpm_rate_k12
FROM schools AS s
JOIN frpm AS f
  ON f.CDSCode = s.CDSCode
WHERE s.DOC = '66'
  AND f."Enrollment (K-12)" IS NOT NULL
  AND f."FRPM Count (K-12)" IS NOT NULL
ORDER BY f."FRPM Count (K-12)" DESC
LIMIT 5;

-- [450] db_id=california_schools
SELECT
  sc.Street,
  sc.City,
  sc.Zip,
  sc.State
FROM satscores AS sa
JOIN schools AS sc
  ON sc.CDSCode = sa.cds
WHERE sa.NumTstTakr IS NOT NULL
  AND sa.NumTstTakr > 0
  AND sa.NumGE1500 IS NOT NULL
ORDER BY (CAST(sa.NumGE1500 AS REAL) / sa.NumTstTakr) ASC
LIMIT 1;

-- [451] db_id=california_schools
SELECT
  s.AdmFName1 || ' ' || s.AdmLName1 AS AdministratorFullName
FROM satscores AS sat
JOIN schools AS s
  ON s.CDSCode = sat.cds
WHERE sat.NumGE1500 = (SELECT MAX(NumGE1500) FROM satscores)
  AND s.AdmFName1 IS NOT NULL
  AND s.AdmLName1 IS NOT NULL
UNION
SELECT
  s.AdmFName2 || ' ' || s.AdmLName2 AS AdministratorFullName
FROM satscores AS sat
JOIN schools AS s
  ON s.CDSCode = sat.cds
WHERE sat.NumGE1500 = (SELECT MAX(NumGE1500) FROM satscores)
  AND s.AdmFName2 IS NOT NULL
  AND s.AdmLName2 IS NOT NULL
UNION
SELECT
  s.AdmFName3 || ' ' || s.AdmLName3 AS AdministratorFullName
FROM satscores AS sat
JOIN schools AS s
  ON s.CDSCode = sat.cds
WHERE sat.NumGE1500 = (SELECT MAX(NumGE1500) FROM satscores)
  AND s.AdmFName3 IS NOT NULL
  AND s.AdmLName3 IS NOT NULL;

-- [452] db_id=california_schools
SELECT AVG(ss.NumTstTakr) AS avg_test_takers
FROM schools s
JOIN satscores ss ON ss.cds = s.CDSCode
WHERE s.County = 'Fresno'
  AND strftime('%Y', s.OpenDate) = '1980';

-- [453] db_id=california_schools
SELECT sc.Phone
FROM satscores AS ss
JOIN schools AS sc
  ON sc.CDSCode = ss.cds
WHERE sc.District = 'Fresno Unified'
  AND ss.AvgScrRead IS NOT NULL
ORDER BY ss.AvgScrRead ASC
LIMIT 1;

-- [454] db_id=california_schools
SELECT
  County,
  School AS SchoolName,
  AvgScrRead
FROM (
  SELECT
    sc.County,
    sc.School,
    sa.AvgScrRead,
    DENSE_RANK() OVER (
      PARTITION BY sc.County
      ORDER BY sa.AvgScrRead DESC
    ) AS rnk
  FROM schools sc
  JOIN satscores sa
    ON sa.cds = sc.CDSCode
  WHERE sc.Virtual = 'F'
    AND sa.AvgScrRead IS NOT NULL
)
WHERE rnk <= 5
ORDER BY County, rnk, SchoolName;

-- [455] db_id=california_schools
SELECT
  sc.School AS school_name,
  AVG(ss.AvgScrWrite) AS avg_writing_score
FROM schools AS sc
JOIN satscores AS ss
  ON ss.cds = sc.CDSCode
WHERE (sc.AdmFName1 = 'Ricci' AND sc.AdmLName1 = 'Ulrich')
   OR (sc.AdmFName2 = 'Ricci' AND sc.AdmLName2 = 'Ulrich')
   OR (sc.AdmFName3 = 'Ricci' AND sc.AdmLName3 = 'Ulrich')
GROUP BY sc.CDSCode, sc.School
ORDER BY sc.School;

-- [456] db_id=california_schools
SELECT
  s.CDSCode,
  s.School,
  s.District,
  s.County,
  f."Enrollment (K-12)" AS enroll_k12
FROM schools AS s
JOIN frpm AS f
  ON f.CDSCode = s.CDSCode
WHERE s.DOC = '31'
  AND f."Enrollment (K-12)" IS NOT NULL
ORDER BY f."Enrollment (K-12)" DESC;

-- [457] db_id=california_schools
SELECT
  COUNT(*) * 1.0 / 12.0 AS monthly_avg_opened_schools_1980
FROM schools
WHERE County = 'Alameda'
  AND DOC = '52'
  AND OpenDate >= '1980-01-01'
  AND OpenDate < '1981-01-01';

-- [458] db_id=california_schools
SELECT
  1.0 * SUM(CASE WHEN DOC = '54' THEN 1 ELSE 0 END) /
  NULLIF(SUM(CASE WHEN DOC = '52' THEN 1 ELSE 0 END), 0) AS ratio_unified_to_elementary
FROM schools
WHERE County = 'ORANGE';

-- [459] db_id=california_schools
SELECT
  sc.School AS "School Name",
  sc.Street AS "Postal Street Address"
FROM satscores AS ss
JOIN schools AS sc
  ON sc.CDSCode = ss.cds
WHERE ss.AvgScrMath IS NOT NULL
ORDER BY ss.AvgScrMath DESC, sc.CDSCode ASC
LIMIT 1 OFFSET 6;

-- [460] db_id=california_schools
SELECT COUNT(DISTINCT s.CDSCode) AS total_non_chartered_schools
FROM schools AS s
JOIN frpm AS f
  ON f.CSDSCode = s.CDSCode
WHERE s.County = 'Los Angeles'
  AND s.Charter = 0
  AND f.`Enrollment (K-12)` IS NOT NULL
  AND f.`Enrollment (K-12)` > 0
  AND f.`Free Meal Count (K-12)` IS NOT NULL
  AND (f.`Free Meal Count (K-12)` * 100.0 / f.`Enrollment (K-12)`) < 0.18;

-- [461] db_id=california_schools
SELECT f.`Enrollment (Ages 5-17)`
FROM frpm AS f
JOIN schools AS s
  ON s.CDSCode = f.CDSCode
WHERE f.`Academic Year` = '2014-2015'
  AND s.EdOpsCode = 'SSS'
  AND s.City = 'Fremont'
  AND s.School = 'State Special School';

-- [462] db_id=california_schools
SELECT
  s."School" AS "School Name",
  (f."FRPM Count (Ages 5-17)" * 100.0) / NULLIF(f."Enrollment (Ages 5-17)", 0) AS "Percent (%) Eligible FRPM (Ages 5-17)"
FROM frpm AS f
JOIN schools AS s
  ON s.CDSCode = f.CDSCode
WHERE f."County Name" = 'Los Angeles'
  AND f."Low Grade" = 'K'
  AND f."High Grade" = '9';

-- [463] db_id=california_schools
SELECT
  County,
  COUNT(*) AS num_schools_no_physical_building
FROM schools
WHERE County IN ('San Diego', 'Santa Barbara')
  AND Virtual = 'F'
GROUP BY County
ORDER BY num_schools_no_physical_building DESC
LIMIT 1;

-- [464] db_id=california_schools
SELECT GSoffered
FROM schools
ORDER BY ABS(Longitude) DESC
LIMIT 1;

-- [465] db_id=california_schools
SELECT
  (SELECT COUNT(DISTINCT s.CDSCode)
   FROM schools s
   JOIN frpm f ON f.CDSCode = s.CDSCode
   WHERE s.Magnet = 1
     AND s.GSserved = 'K-8'
     AND f.`NSLP Provision Status` = 'Multiple Provision Types') AS NumK8MagnetMultipleProvisionTypes,
  c.City,
  c.NumSchoolsK8
FROM (
  SELECT
    City,
    COUNT(DISTINCT CDSCode) AS NumSchoolsK8
  FROM schools
  WHERE Magnet = 1
    AND GSserved = 'K-8'
  GROUP BY City
) AS c
ORDER BY c.City;

-- [466] db_id=california_schools
SELECT
  frpm.`District Code` AS `District Code`,
  (frpm.`Free Meal Count (K-12)` * 100.0) / NULLIF(frpm.`Enrollment (K-12)`, 0) AS `Percent (%) Eligible Free (K-12)`
FROM schools
JOIN frpm ON frpm.CDSCode = schools.CDSCode
WHERE schools.AdmFName1 = 'Alusine'
   OR schools.AdmFName2 = 'Alusine'
   OR schools.AdmFName3 = 'Alusine';

-- [467] db_id=california_schools
SELECT DISTINCT email
FROM (
  SELECT AdmEmail1 AS email
  FROM schools
  WHERE County = 'San Bernardino'
    AND District = 'San Bernardino City Unified'
    AND SOC = '62'
    AND DOC = '54'
    AND OpenDate BETWEEN '2009-01-01' AND '2010-12-31'
    AND AdmEmail1 IS NOT NULL
    AND TRIM(AdmEmail1) <> ''
    AND AdmEmail1 LIKE '%_@_%._%'

  UNION ALL

  SELECT AdmEmail2 AS email
  FROM schools
  WHERE County = 'San Bernardino'
    AND District = 'San Bernardino City Unified'
    AND SOC = '62'
    AND DOC = '54'
    AND OpenDate BETWEEN '2009-01-01' AND '2010-12-31'
    AND AdmEmail2 IS NOT NULL
    AND TRIM(AdmEmail2) <> ''
    AND AdmEmail2 LIKE '%_@_%._%'

  UNION ALL

  SELECT AdmEmail3 AS email
  FROM schools
  WHERE County = 'San Bernardino'
    AND District = 'San Bernardino City Unified'
    AND SOC = '62'
    AND DOC = '54'
    AND OpenDate BETWEEN '2009-01-01' AND '2010-12-31'
    AND AdmEmail3 IS NOT NULL
    AND TRIM(AdmEmail3) <> ''
    AND AdmEmail3 LIKE '%_@_%._%'
)
WHERE email IS NOT NULL
  AND TRIM(email) <> ''
  AND email LIKE '%_@_%._%';

-- [468] db_id=financial
SELECT COUNT(DISTINCT a.account_id) AS account_count
FROM account AS a
JOIN district AS d ON d.district_id = a.district_id
JOIN trans AS t ON t.account_id = a.account_id
WHERE d.A3 = 'East Bohemia'
  AND t.operation = 'POPLATEK PO OBRATU';

-- [469] db_id=financial
SELECT COUNT(DISTINCT d.district_id) AS num_districts
FROM district d
JOIN client c ON c.district_id = d.district_id
WHERE c.gender = 'F'
GROUP BY d.district_id
HAVING d.A11 > 6000 AND d.A11 < 10000;

-- [470] db_id=financial
SELECT COUNT(*) AS male_customers_count
FROM client c
JOIN district d ON d.district_id = c.district_id
WHERE c.gender = 'M'
  AND d.A3 = 'North Bohemia'
  AND d.A11 > 8000;

-- [471] db_id=financial
SELECT d.account_id,
       (SELECT MAX(A11) FROM district) - (SELECT MIN(di.A11)
                                         FROM client c2
                                         JOIN district di ON di.district_id = c2.district_id
                                         WHERE c2.gender = 'F') AS salary_gap
FROM disp d
JOIN client c ON c.client_id = d.client_id
JOIN district di ON di.district_id = c.district_id
WHERE c.gender = 'F'
  AND c.birth_date = (SELECT MIN(c3.birth_date)
                      FROM client c3
                      WHERE c3.gender = 'F')
  AND di.A11 = (SELECT MIN(di2.A11)
                FROM client c4
                JOIN district di2 ON di2.district_id = c4.district_id
                WHERE c4.gender = 'F');

-- [472] db_id=financial
SELECT DISTINCT d.account_id
FROM disp AS d
JOIN client AS c ON c.client_id = d.client_id
JOIN district AS di ON di.district_id = c.district_id
WHERE c.birth_date = (SELECT MAX(birth_date) FROM client)
  AND di.A11 = (SELECT MAX(A11) FROM district);

-- [473] db_id=financial
SELECT a.account_id
FROM account AS a
JOIN loan AS l
  ON l.account_id = a.account_id
WHERE l.status = 'A'
  AND strftime('%Y', l.date) = '1997'
  AND a.frequency = 'POPLATEK TYDNE'
  AND l.amount = (
    SELECT MIN(l2.amount)
    FROM loan AS l2
    WHERE l2.status = 'A'
      AND strftime('%Y', l2.date) = '1997'
  );

-- [474] db_id=financial
SELECT a.account_id, l.amount AS approved_amount
FROM account AS a
JOIN loan AS l
  ON l.account_id = a.account_id
WHERE l.duration > 12
  AND l.status = 'A'
  AND strftime('%Y', a.date) = '1993'
  AND l.amount = (
    SELECT MAX(l2.amount)
    FROM loan AS l2
    JOIN account AS a2
      ON a2.account_id = l2.account_id
    WHERE l2.duration > 12
      AND l2.status = 'A'
      AND strftime('%Y', a2.date) = '1993'
  );

-- [475] db_id=financial
SELECT COUNT(DISTINCT c.client_id) AS female_customers_before_1950_in_sokolov
FROM account a
JOIN disp d ON d.account_id = a.account_id
JOIN client c ON c.client_id = d.client_id
JOIN district di ON di.district_id = c.district_id
WHERE c.gender = 'F'
  AND c.birth_date < DATE('1950-01-01')
  AND di.A2 = 'Sokolov';

-- [476] db_id=financial
SELECT d.A2
FROM client c
JOIN disp dp ON dp.client_id = c.client_id
JOIN account a ON a.account_id = dp.account_id
JOIN district d ON d.district_id = a.district_id
WHERE c.gender = 'F'
  AND c.birth_date = '1976-01-29'
  AND dp.type = 'OWNER';

-- [477] db_id=financial
SELECT
  100.0 * SUM(CASE WHEN c.gender = 'M' THEN 1 ELSE 0 END) / COUNT(*) AS pct_male_clients
FROM client c
JOIN district d ON d.district_id = c.district_id
WHERE d.A3 = 'south Bohemia'
  AND d.A4 = (
    SELECT MAX(A4)
    FROM district
    WHERE A3 = 'south Bohemia'
  );

-- [478] db_id=financial
SELECT ((t_end.balance - t_start.balance) * 100.0) / t_start.balance AS increase_rate_percent
FROM loan l
JOIN account a ON a.account_id = l.account_id
JOIN disp d ON d.account_id = a.account_id
JOIN client c ON c.client_id = d.client_id
JOIN trans t_start ON t_start.account_id = a.account_id AND t_start.date = '1993-03-22'
JOIN trans t_end ON t_end.account_id = a.account_id AND t_end.date = '1998-12-27'
WHERE l.date = '1993-07-05'
  AND l.status = 'A'
ORDER BY l.loan_id, d.disp_id, c.client_id
LIMIT 1;

-- [479] db_id=financial
SELECT
  100.0 * SUM(CASE WHEN status = 'A' THEN amount ELSE 0 END) / SUM(amount) AS pct_fully_paid_no_issue
FROM loan;

-- [480] db_id=financial
SELECT
  100.0 * SUM(CASE WHEN status = 'C' THEN amount ELSE 0 END) / SUM(amount) AS pct_running_ok_so_far
FROM loan
WHERE amount < 100000;

-- [481] db_id=financial
SELECT
  d.A2 AS district,
  d.A3 AS state,
  ((d.A13 - d.A12) / d.A12) * 100.0 AS unemployment_increment_percentage
FROM loan l
JOIN account a ON a.account_id = l.account_id
JOIN disp di ON di.account_id = a.account_id
JOIN client c ON c.client_id = di.client_id
JOIN district d ON d.district_id = c.district_id
WHERE l.status = 'D'
  AND d.A12 IS NOT NULL
  AND d.A12 <> 0
GROUP BY d.district_id, d.A2, d.A3, d.A12, d.A13;

-- [482] db_id=financial
SELECT
  d.A2 AS district,
  COUNT(DISTINCT c.client_id) AS female_account_holders
FROM district AS d
JOIN client AS c
  ON c.district_id = d.district_id
JOIN disp AS di
  ON di.client_id = c.client_id
WHERE c.gender = 'F'
GROUP BY d.district_id, d.A2
ORDER BY female_account_holders DESC
LIMIT 9;

-- [483] db_id=financial
SELECT COUNT(*) AS approved_loans_count
FROM loan l
JOIN account a ON a.account_id = l.account_id
WHERE a.frequency = 'POPLATEK MESICNE'
  AND l.amount >= 250000
  AND l.status = 'A'
  AND l.date BETWEEN '1995-01-01' AND '1997-12-31';

-- [484] db_id=financial
SELECT
  d.A2 AS district_name,
  SUM(t.amount) AS total_withdrawals
FROM trans t
JOIN account a ON a.account_id = t.account_id
JOIN district d ON d.district_id = a.district_id
WHERE t.type = 'VYDAJ'
  AND t.date LIKE '1996-01%'
  AND (t.operation IS NULL OR t.operation <> 'VYBER KARTOU')
GROUP BY d.district_id, d.A2
ORDER BY total_withdrawals DESC
LIMIT 10;

-- [485] db_id=financial
SELECT COUNT(DISTINCT a.account_id) AS running_accounts_branch_location_1
FROM loan l
JOIN account a ON a.account_id = l.account_id
JOIN district d ON d.district_id = a.district_id
WHERE l.status = 'C'
  AND d.A2 = '1';

-- [486] db_id=financial
SELECT COUNT(DISTINCT c.client_id) AS male_clients
FROM client AS c
JOIN district AS d
  ON d.district_id = c.district_id
WHERE c.gender = 'M'
  AND d.A15 = (
    SELECT A15
    FROM district
    WHERE A15 IS NOT NULL
    ORDER BY A15 DESC
    LIMIT 1 OFFSET 1
  );

-- [487] db_id=financial
SELECT DISTINCT d.client_id
FROM trans t
JOIN disp d ON d.account_id = t.account_id
WHERE t.operation = 'VYBER KARTOU'
  AND strftime('%Y', t.date) = '1998'
  AND d.type = 'OWNER'
  AND t.amount < (
    SELECT AVG(t2.amount)
    FROM trans t2
    WHERE t2.operation = 'VYBER KARTOU'
      AND strftime('%Y', t2.date) = '1998'
  );

-- [488] db_id=financial
SELECT DISTINCT d.type
FROM disp AS d
JOIN account AS a ON a.account_id = d.account_id
JOIN district AS di ON di.district_id = a.district_id
WHERE di.A11 > 8000
  AND di.A11 <= 9000
  AND d.type <> 'OWNER';

-- [489] db_id=financial
SELECT AVG(d.A15) AS avg_crimes_1995
FROM district d
WHERE d.A15 > 4000
  AND EXISTS (
    SELECT 1
    FROM account a
    WHERE a.district_id = d.district_id
      AND CAST(strftime('%Y', a.date) AS INTEGER) >= 1997
  );

-- [490] db_id=financial
SELECT t.*
FROM trans AS t
JOIN account AS a ON a.account_id = t.account_id
JOIN disp AS d ON d.account_id = a.account_id
WHERE d.client_id = 3356
  AND t.operation = 'VYBER';

-- [491] db_id=financial
SELECT
  100.0 * SUM(CASE WHEN c.gender = 'F' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS pct_women
FROM account a
JOIN district d ON d.district_id = a.district_id
JOIN disp di ON di.account_id = a.account_id
JOIN client c ON c.client_id = di.client_id
WHERE d.A11 > 10000
  AND di.type = 'OWNER';

-- [492] db_id=financial
SELECT
  ( (SUM(CASE WHEN strftime('%Y', l.date) = '1997' THEN l.amount ELSE 0 END) -
      SUM(CASE WHEN strftime('%Y', l.date) = '1996' THEN l.amount ELSE 0 END)
    ) * 100.0
  ) / NULLIF(SUM(CASE WHEN strftime('%Y', l.date) = '1996' THEN l.amount ELSE 0 END), 0) AS growth_rate_percent
FROM loan l
JOIN account a ON a.account_id = l.account_id
JOIN disp d ON d.account_id = a.account_id
JOIN client c ON c.client_id = d.client_id
WHERE c.gender = 'M'
  AND strftime('%Y', l.date) IN ('1996','1997');

-- [493] db_id=financial
SELECT
  (SELECT frequency FROM account WHERE account_id = 3) AS statement_frequency,
  (SELECT k_symbol
   FROM trans
   WHERE account_id = 3
     AND type = 'VYDAJ'
   GROUP BY k_symbol
   HAVING SUM(amount) = 3539
  ) AS debit_aim_k_symbol;

-- [494] db_id=financial
SELECT
  100.0 * SUM(CASE WHEN c.gender = 'M' THEN 1 ELSE 0 END) / COUNT(*) AS pct_male_weekly
FROM account a
JOIN disp d ON d.account_id = a.account_id
JOIN client c ON c.client_id = d.client_id
WHERE a.frequency = 'POPLATEK TYDNE';

-- [495] db_id=financial
SELECT a.account_id
FROM client c
JOIN district d ON d.district_id = c.district_id
JOIN disp di ON di.client_id = c.client_id
JOIN account a ON a.account_id = di.account_id
WHERE c.gender = 'F'
  AND c.birth_date = (
    SELECT MIN(c2.birth_date)
    FROM client c2
    JOIN district d2 ON d2.district_id = c2.district_id
    WHERE c2.gender = 'F'
      AND d2.A11 = (
        SELECT MIN(d3.A11)
        FROM client c3
        JOIN district d3 ON d3.district_id = c3.district_id
        WHERE c3.gender = 'F'
      )
  )
  AND d.A11 = (
    SELECT MIN(d4.A11)
    FROM client c4
    JOIN district d4 ON d4.district_id = c4.district_id
    WHERE c4.gender = 'F'
  );

-- [496] db_id=financial
SELECT AVG(l.amount) AS avg_running_loan_amount
FROM loan AS l
JOIN trans AS t
  ON t.account_id = l.account_id
WHERE l.status IN ('C','D')
  AND t.operation = 'POPLATEK PO OBRATU';

-- [497] db_id=financial
SELECT
  c.client_id,
  CAST((julianday('now') - julianday(c.birth_date)) / 365.25 AS INTEGER) AS age
FROM client AS c
JOIN disp AS d
  ON d.client_id = c.client_id
JOIN card AS ca
  ON ca.disp_id = d.disp_id
WHERE ca.type = 'gold'
  AND d.type = 'OWNER';

-- [498] db_id=financial
SELECT DISTINCT
       a.account_id,
       d.A2 AS district_name,
       d.A3 AS district_region
FROM account AS a
JOIN district AS d
  ON d.district_id = a.district_id
WHERE strftime('%Y', a.date) = '1993'
  AND a.frequency = 'POPLATEK PO OBRATU';

-- [499] db_id=financial
SELECT DISTINCT
       a.account_id,
       a.frequency
FROM account AS a
JOIN district AS d
  ON d.district_id = a.district_id
JOIN disp AS dp
  ON dp.account_id = a.account_id
WHERE LOWER(d.A3) = 'east bohemia'
  AND dp.type = 'OWNER'
  AND strftime('%Y', a.date) BETWEEN '1995' AND '2000'
ORDER BY a.account_id;

