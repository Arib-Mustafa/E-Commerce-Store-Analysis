CREATE TABLE rfm_segments AS
WITH rec AS (
-- Creating RFM and RFM Scores columns
SELECT DISTINCT user_id,DATE '2021-02-28' - MAX(event_time)::date AS recency
FROM ecommerce_events
GROUP BY 1
ORDER BY 2),
rec_score AS(
SELECT DISTINCT user_id,recency,CASE 
  WHEN recency BETWEEN 0 AND 37 THEN 5
  WHEN recency BETWEEN 38 AND 79 THEN 4
  WHEN recency BETWEEN 80 AND 116 THEN 3
  WHEN recency BETWEEN 117 AND 157 THEN 2
  ELSE 1
END AS recency_score
FROM rec),

freq AS(
SELECT DISTINCT user_id,COUNT(*) AS frequency
FROM (SELECT *
FROM ecommerce_events
WHERE event_type = 'purchase')
GROUP BY 1
),
freq_score AS(
SELECT DISTINCT user_id,frequency,CASE 
  WHEN frequency = 1 THEN 1
  WHEN frequency = 2 THEN 2
  WHEN frequency BETWEEN 3 AND 5 THEN 3
  WHEN frequency BETWEEN 6 AND 10 THEN 4
  ELSE 5
END AS frequency_score
FROM freq),

monet AS(
SELECT DISTINCT user_id,SUM(price) AS monetary
FROM(SELECT *
FROM ecommerce_events
WHERE event_type = 'purchase')
GROUP BY 1
),
monet_score AS(
SELECT DISTINCT user_id,monetary,CASE 
  WHEN monetary BETWEEN 0 AND 1 THEN 1
  WHEN monetary BETWEEN 1 AND 57 THEN 2
  WHEN monetary BETWEEN 57 AND 170 THEN 3
  WHEN monetary BETWEEN 170 AND 405 THEN 4
  ELSE 5
END AS monetary_score
FROM monet)

-- Combining CTEs to from one table for RFM Segment Evaluation
SELECT 
  COALESCE(r.user_id, f.user_id, m.user_id) AS user_id,
  recency, recency_score,
  frequency, frequency_score,
  monetary, monetary_score,
  CONCAT(recency_score, frequency_score, monetary_score) AS rfm_combined_score
FROM rec_score r
LEFT JOIN freq_score f ON r.user_id = f.user_id
LEFT JOIN monet_score m ON r.user_id = m.user_id OR f.user_id = m.user_id;

-- Replacing NULL values with appropriate values in the Frequency and Monetary columns
UPDATE rfm_segments
SET frequency = COALESCE(frequency,0);
UPDATE rfm_segments
SET monetary = COALESCE(monetary,0);
UPDATE rfm_segments
SET frequency_score = COALESCE(frequency_score,1);
UPDATE rfm_segments
SET monetary_score = COALESCE(monetary_score,1);

ALTER TABLE rfm_segments
ADD COLUMN rfm_score TEXT;
-- Added a combined RFM Score as text valye

UPDATE rfm_segments
SET rfm_score = CONCAT(recency_score,frequency_score,monetary_score);
-- Updated the newly created column

ALTER TABLE rfm_segments
ADD COLUMN rfm_segment TEXT;
-- Creating the RFM Segment column
UPDATE rfm_segments
SET rfm_segment = 
CASE
  WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
  WHEN recency_score >= 4 AND frequency_score = 3 THEN 'Potential Loyalists'
  WHEN recency_score >= 3 AND frequency_score >= 4 THEN 'Loyal Customers'
  WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
  WHEN recency_score <= 2 AND frequency_score >= 3 THEN 'Lost Customers'
  ELSE 'Others'
END;
-- Updated RFM Segment of every user according to the above logic

FROM rfm_segments
-- To check accurate ranges
SELECT 
  MIN(monetary), 
  MAX(monetary), 
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY monetary) AS Q1,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY monetary) AS Median,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY monetary) AS Q3
FROM monet;

-- Checking Segment wise user distribution and exporting to tableau for visualization
SELECT rfm_segment,COUNT(*) as Cnt 
FROM rfm_segments
GROUP BY 1

-- Checking Segment wise revenue distribution and exporting to tableau for visualization
SELECT rfm_segment,SUM(monetary) as monetary_value
FROM rfm_segments
GROUP BY 1

-- Checking total revenue and exporting to tableau for visualization
SELECT SUM(price)
FROM ecommerce_events
WHERE event_type='purchase'

-- Getting the average frequency of purchasing
WITH users AS(
  SELECT user_id as user_id
  FROM ecommerce_events
)
SELECT AVG(no_of_purchases) AS average_frequency
FROM(SELECT u.user_id,COALESCE(COUNT(e.event_type),0) AS no_of_purchases
FROM users u
LEFT JOIN ecommerce_events e
ON u.user_id = e.user_id AND e.event_type = 'purchase'
GROUP BY 1)

-- Creating the Avg. Order Value column in the table for Determining Customers with high purchasing power
ALTER TABLE rfm_segments
ADD COLUMN AOV float;

UPDATE rfm_segments
SET AOV = 
CASE WHEN frequency >= 1 THEN monetary/frequency
ELSE 0
END;


SELECT MIN(aov),MAX(aov),PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY aov) AS top_25_perc
FROM rfm_segments
WHERE frequency >= 1;

-- The top 25% spenders on the basis of average order value have an AOV of 257.87 or more.
-- So the Whales will be considered on these people
-- Now create whale flags as a seperate entity to be targeted

SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY monetary) AS top_monet
FROM rfm_segments
WHERE frequency >=1;
-- Found users with high AOV and can be targeted with special offers.
