-- Viewing the Data 
SELECT *
FROM ecommerce_events
LIMIT 5;

-- Removing Duplicate records
DELETE FROM ecommerce_events
WHERE user_id IS NULL
   OR product_id IS NULL
   OR event_type IS NULL
   OR event_time IS NULL
   OR category_id IS NULL
   OR category_code IS NULL
   OR brand IS NULL
   OR price IS NULL
   OR user_session IS NULL;

-- Viewing Duplicate Records
SELECT event_time,event_type,user_id,product_id,COUNT(*)
FROM ecommerce_events
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1;

-- Creating Index for faster deletion of duplicates
CREATE INDEX idx_cleanup ON ecommerce_events (user_id, product_id, event_type, event_time);

-- Creating CTE which stores the duplicate records
WITH duplicates AS (
  SELECT ctid
  FROM (
    SELECT ctid,
           ROW_NUMBER() OVER (
               PARTITION BY user_id, product_id, event_type, event_time
               ORDER BY event_time
           ) AS rn
    FROM ecommerce_events
  ) sub
  WHERE rn > 1
)
-- Deleting records from main table present in CTE
DELETE FROM ecommerce_events
WHERE ctid IN (SELECT ctid FROM duplicates);

-- Dropping index after deletion of duplicates
DROP INDEX idx_cleanup;

-- Checking if the data is deleted or not
SELECT user_id, product_id, event_type, event_time, COUNT(*) 
FROM ecommerce_events 
GROUP BY user_id, product_id, event_type, event_time 
HAVING COUNT(*) > 1;

-- Checking the data types of columns to spot any problems
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'ecommerce_events';

-- Cleaning text columns
UPDATE ecommerce_events
SET 
  event_type = TRIM(event_type),
  brand = TRIM(brand),
  category_code = TRIM(category_code),
  user_session = TRIM(user_session);

-- Converting text columns to lowercase for consistency
UPDATE ecommerce_events
SET 
  event_type = LOWER(event_type),
  brand = LOWER(brand),
  category_code = LOWER(category_code),
  user_session = LOWER(user_session);
