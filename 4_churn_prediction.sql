CREATE TABLE churn_determination AS
WITH ranked AS (
  SELECT 
    user_id,
    DATE(event_time) AS purchase_date,
    LAG(DATE(event_time)) OVER (PARTITION BY user_id ORDER BY DATE(event_time)) AS previous_purchase
  FROM ecommerce_events
  WHERE event_type = 'purchase'
)
SELECT user_id,AVG(inter_purchase_gap) avg_gap
FROM(
SELECT 
  user_id,
  purchase_date,
  previous_purchase,
   (purchase_date - previous_purchase) AS inter_purchase_gap
FROM ranked
WHERE previous_purchase IS NOT NULL)sub
GROUP BY 1
;

-- Found the average interpurchase gap for every user to create dynamic churn logic
SELECT user_id,avg_gap
FROM churn_determination;

CREATE TABLE Churn_status_prediction AS
  SELECT rs.user_id,
  CASE WHEN rs.frequency = 0 THEN 'Not Converted'
       WHEN rs.frequency = 1 THEN 'New Customer'
       WHEN cd.avg_gap IS NULL THEN 'Unknown'
       WHEN rs.recency >= cd.avg_gap * 2 THEN 'Churned'
       WHEN rs.recency > cd.avg_gap * 1 THEN 'At Risk'
       ELSE 'Active'
  END AS churn_status
  FROM churn_determination cd
  RIGHT JOIN rfm_segments rs 
  ON cd.user_id = rs.user_id;
-- Created a dynamic churn logic based on values according to the user
SELECT churn_status,COUNT(*) as cnt
FROM Churn_status_prediction
GROUP BY 1;


-- creating a joined table for combining rfm_segments and churn_status
CREATE TABLE rfm_and_churn AS(
SELECT r.user_id,r.recency,r.frequency,r.monetary,r.rfm_score,r.rfm_segment,c.churn_status
FROM rfm_segments r
LEFT JOIN Churn_status_prediction c
ON r.user_id = c.user_id);


-- Now Adding AOV & Whale_flag to identify high spenders on basis of AOV

ALTER TABLE rfm_and_churn
ADD COLUMN high_aov_customer BOOLEAN;
ALTER TABLE rfm_and_churn
ADD COLUMN AOV NUMERIC;

UPDATE rfm_and_churn rc
SET AOV = rs.aov         -- Adding AOV into the table from rfm_segments table created eariler
FROM rfm_segments rs
WHERE rc.user_id = rs.user_id

SELECT MIN(aov),MAX(aov),PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY aov) AS top_25_perc
FROM rfm_segments
WHERE frequency >= 1;
-- Checking the AOV values
UPDATE rfm_and_churn
SET high_aov_customer = aov >= 257.87 -- created whale flag on basis of aov of top 25% customers

ALTER TABLE rfm_and_churn
DROP COLUMN aov; -- Dropping AOV values since no longer needed.
ALTER TABLE rfm_and_churn
ALTER COLUMN high_aov_customer TYPE TEXT; 

SELECT *
FROM rfm_and_churn
WHERE rfm_segment  = 'Whales'

-- Finding the total churn customers per RFM segment and exporting for visualization in tableau.
CREATE TABLE churn_percentage AS
WITH churn_cnt AS(
  SELECT rfm_segment,COUNT(rc.user_id) as tl_ch_cust
FROM rfm_and_churn rc
WHERE rc.churn_status = 'Churned'
GROUP BY 1),
total_cnt AS(
  SELECT rc.rfm_segment,COUNT(*) total_cust
  FROM rfm_and_churn rc
  GROUP BY 1)
SELECT churn_cnt.rfm_segment,ROUND((churn_cnt.tl_ch_cust::numeric/total_cnt.total_cust::numeric),4) AS churn_percent
FROM churn_cnt
JOIN total_cnt
ON churn_cnt.rfm_segment = total_cnt.rfm_segment
;

-- Finding the revenue at risk due to churned or at risk customers and exporting for visualization in tableau.
CREATE TABLE revenue_at_risk AS
WITH t1 AS(
  SELECT rfm_segment,SUM(monetary) as total_revenue
  FROM rfm_segments
  GROUP BY 1
)
SELECT t1.rfm_segment,ROUND((cp.churn_percent::numeric * t1.total_revenue::numeric),2) AS Revenue_At_Risk
FROM t1
JOIN churn_percentage cp
ON t1.rfm_segment = cp.rfm_segment;

SELECT SUM(Revenue_At_Risk) revenue_at_risk
FROM revenue_at_risk;

-- Dropping tables revenue_at_risk and churn_percentage since the results are exported and visualized in tableau and no longer needed.
DROP TABLE revenue_at_risk;
DROP TABLE churn_percentage;

-- Finding Percentage of customers not converted
SELECT COUNT(*)::numeric * 100 / (SELECT COUNT(*) FROM rfm_and_churn)::numeric AS not_converted_perc
FROM rfm_and_churn
WHERE churn_status = 'Not Converted';
-- Visualizing this in tableau.