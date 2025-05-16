-- Viewing only the purchased products
SELECT *
FROM ecommerce_events
WHERE event_type = 'purchase';

-- Calculating Total Sales
SELECT event_type,SUM(price) as sales
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY 1;

-- Getting category wise Sales 
SELECT category_code,SUM(price) AS revenue
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 7;

-- Brand Wise Sales
SELECT event_type,brand,SUM(price) as sales
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 7;

-- Average Order Value
SELECT SUM(price)::numeric / COUNT(*) AS avg_order_val
FROM ecommerce_events
WHERE event_type = 'purchase';

-- Highest Selling Products by revenue

SELECT category_code,COUNT(*) AS units_sold,SUM(price) AS revenue
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY 1
ORDER BY 3 DESC;

-- Over time Sales Analysis
-- Day of Week wise 
SELECT EXTRACT(DOW FROM event_time) AS day_number,TO_CHAR(event_time, 'Day') AS day_of_week,COUNT(*) AS total_orders, SUM(price) as daily_revenue
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY 1,2
ORDER BY 1;

-- Month wise
SELECT EXTRACT(Month FROM event_time) as month_of_year,COUNT(*) AS total_orders,SUM(price) AS total_revenue
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY 1
ORDER BY 3 DESC;

-- Hour wise
SELECT 
  EXTRACT(HOUR FROM event_time) AS hour_of_day,
  COUNT(*) AS total_orders,
  SUM(price) AS total_revenue
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- Day of week and hour combined
SELECT 
  EXTRACT(DOW FROM event_time) AS day_number,                          -- 0 = Sunday, 6 = Saturday
  TRIM(TO_CHAR(event_time, 'Day')) AS day_of_week,
  EXTRACT(HOUR FROM event_time) AS hour_of_day,
  COUNT(*) AS total_orders,
  SUM(price) AS total_revenue
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY day_number, day_of_week, hour_of_day
ORDER BY day_number, hour_of_day;

SELECT 
  EXTRACT(DOW FROM event_time) AS day_number,                          -- Needed for correct sorting
  TRIM(TO_CHAR(event_time, 'Day')) AS day_of_week,                    -- Display label
  EXTRACT(HOUR FROM event_time) AS hour_of_day,
  COUNT(*) AS total_orders,
  SUM(price) AS total_revenue
FROM ecommerce_events
WHERE event_type = 'purchase'
GROUP BY day_number, day_of_week, hour_of_day
ORDER BY day_number, hour_of_day;

SELECT COUNT(*) as total_revenue
FROM ecommerce_events
WHERE event_type = 'purchase';



SELECT COUNT(DISTINCT user_id) AS total_users
FROM ecommerce_events;


-- Getting the Conversion Rate
-- View Events
SELECT COUNT(*) AS view_events
FROM ecommerce_events
WHERE event_type = 'view';

-- Cart Events
SELECT COUNT(*) AS cart_events
FROM ecommerce_events
WHERE event_type = 'cart';

-- Purchase Events
SELECT COUNT(*) AS purchase_events
FROM ecommerce_events
WHERE event_type = 'purchase';

WITH funnel AS
(SELECT
    COUNT(CASE WHEN event_type = 'view' THEN 1 END) AS views,
    COUNT(CASE WHEN event_type = 'cart' THEN 1 END) AS cart_adds,
    COUNT(CASE WHEN event_type = 'purchase' THEN 1 END) AS purchases
FROM ecommerce_events)

SELECT *,
      ROUND(100 * cart_adds / views , 2) AS view_to_cart,
      ROUND(100 * purchases / cart_adds , 2) AS cart_to_purchase,
      ROUND(100 * purchases / views , 2) AS view_to_purchase
      FROM funnel;

-- Therefore computed the percentage conversion from one event to the other.




