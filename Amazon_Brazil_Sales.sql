CREATE TABLE amazon_brazil.customers (
    customer_id VARCHAR PRIMARY KEY,
    customer_unique_id VARCHAR,
    customer_zip_code_prefix INTEGER
);

CREATE TABLE amazon_brazil.orders (
    order_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR REFERENCES amazon_brazil.customers(customer_id),
    order_status VARCHAR,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);


CREATE TABLE amazon_brazil.payments (
    order_id VARCHAR,
    payment_sequential INTEGER,
    payment_type VARCHAR,
    payment_installments INTEGER,
    payment_value NUMERIC(10,2)
);


CREATE TABLE amazon_brazil.product (
    product_id VARCHAR PRIMARY KEY,
    product_category_name VARCHAR,
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);


CREATE TABLE amazon_brazil.order_items (
    order_id VARCHAR,
    order_item_id INTEGER,
    product_id VARCHAR,
    seller_id VARCHAR,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2)
);


CREATE TABLE amazon_brazil.seller (
    seller_id VARCHAR PRIMARY KEY,
    seller_zip_code_prefix INTEGER
);


ALTER TABLE amazon_brazil.order_items
ADD CONSTRAINT fk_orderitems_order
FOREIGN KEY (order_id)
REFERENCES amazon_brazil.orders(order_id);

ALTER TABLE amazon_brazil.order_items
ADD CONSTRAINT fk_orderitems_product
FOREIGN KEY (product_id)
REFERENCES amazon_brazil.product(product_id);

ALTER TABLE amazon_brazil.order_items
ADD CONSTRAINT fk_orderitems_seller
FOREIGN KEY (seller_id)
REFERENCES amazon_brazil.seller(seller_id);


ALTER TABLE amazon_brazil.payments
ADD CONSTRAINT fk_payments_order
FOREIGN KEY (order_id)
REFERENCES amazon_brazil.orders(order_id);

-- **ANALYSIS 1

-- 1)
SELECT payment_type,
       ROUND(AVG(payment_value)) AS rounded_avg_payment
FROM amazon_brazil.payments
GROUP BY payment_type
ORDER BY rounded_avg_payment ASC;

--2) 

SELECT 
    payment_type,
    ROUND(
        (COUNT(DISTINCT order_id) * 100.0 / 
         (SELECT COUNT(DISTINCT order_id) FROM amazon_brazil.payments)), 
        1 ) AS percentage_orders
FROM amazon_brazil.payments
GROUP BY  payment_type
ORDER BY percentage_orders DESC;


-- 3) 

SELECT 
    oi.product_id,
    oi.price
FROM amazon_brazil.order_items oi
JOIN amazon_brazil.product p 
    ON oi.product_id = p.product_id
WHERE oi.price BETWEEN 100 AND 500
  AND p.product_category_name ILIKE '%smart%'
ORDER BY oi.price DESC;

-- 4)
SELECT 
    TO_CHAR(order_purchase_timestamp, 'Month') AS month,
    ROUND(SUM(oi.price)) AS total_sales
FROM amazon_brazil.orders o
JOIN amazon_brazil.order_items oi 
    ON o.order_id = oi.order_id
GROUP BY TO_CHAR(order_purchase_timestamp, 'Month')
ORDER BY total_sales DESC
LIMIT 3;

--5)
SELECT p.product_category_name,
       max(oi.price) - min(oi.price) as price_difference
FROM amazon_brazil.product p
JOIN amazon_brazil.order_items oi
ON p.product_id = oi.product_id
GROUP BY p.product_category_name
HAVING max(oi.price) - min(oi.price) > 500
ORDER BY price_difference DESC


--6)   
SELECT 
    payment_type,
    ROUND(STDDEV(payment_value), 2) AS std_deviation
FROM amazon_brazil.payments
GROUP BY payment_type
ORDER BY std_deviation ASC;

--7)
SELECT 
    product_id, 
    product_category_name
FROM amazon_brazil.product
WHERE product_category_name IS NULL 
   OR LENGTH(TRIM(product_category_name)) <= 1;


-- **ANALYSIS 2

-- 1)
SELECT 
     CASE
	 WHEN payment_value < 200 THEN 'low'
	 WHEN payment_value BETWEEN 200 AND 1000 THEN 'medium'
	 ELSE 'high'
	 END AS order_value_segment,
	 payment_type,
	 count(*) as payment_count
FROM amazon_brazil.payments
GROUP BY order_value_segment,payment_type
ORDER BY payment_count DESC;

--2)
SELECT 
    p.product_category_name,
    MIN(oi.price) AS min_price,
    MAX(oi.price) AS max_price,
    ROUND(AVG(oi.price), 2) AS avg_price
FROM amazon_brazil.product p
JOIN amazon_brazil.order_items oi 
    ON p.product_id = oi.product_id
GROUP BY p.product_category_name
ORDER BY avg_price DESC;

--3)
SELECT c.customer_unique_id,
       COUNT(o.order_id) AS total_orders
FROM amazon_brazil.customers AS c
JOIN amazon_brazil.orders AS o
ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(o.order_id) > 1
ORDER BY total_orders DESC;


--4) 
CREATE TEMP TABLE customer_type AS
SELECT c.customer_unique_id,
		CASE
		 WHEN COUNT(o.order_id) = 1 THEN 'New'
		 WHEN COUNT(o.order_id) BETWEEN 2 AND 4 THEN 'Returning'
		 ELSE 'Loyal'
		END AS customer_type
FROM amazon_brazil.customers AS c
JOIN amazon_brazil.orders as o
ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id ;

SELECT 
    customer_unique_id,
    customer_type
FROM customer_type
ORDER BY customer_type;


--5)

SELECT 
    p.product_category_name,
    ROUND(SUM(oi.price), 2) AS total_revenue
FROM amazon_brazil.order_items AS oi
JOIN amazon_brazil.product AS p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 5;


-- **ANALYSIS 3

--1)
SELECT 
    season,
    ROUND(SUM(total_sales)) AS total_sales
FROM (
    SELECT 
        CASE 
            WHEN EXTRACT(MONTH FROM o.order_purchase_timestamp) IN (3, 4, 5) THEN 'Spring'
            WHEN EXTRACT(MONTH FROM o.order_purchase_timestamp) IN (6, 7, 8) THEN 'Summer'
            WHEN EXTRACT(MONTH FROM o.order_purchase_timestamp) IN (9, 10, 11) THEN 'Autumn'
            ELSE 'Winter'
        END AS season,
        oi.price AS total_sales
    FROM amazon_brazil.order_items oi
    JOIN amazon_brazil.orders o 
        ON oi.order_id = o.order_id
) AS seasonal_sales
GROUP BY season
ORDER BY total_sales DESC;


--2)

SELECT product_id,
       SUM(order_item_id) as total_quantity_sold
FROM amazon_brazil.order_items
GROUP BY product_id
HAVING SUM(order_item_id) > (
       SELECT AVG (total_quantity)
	   FROM(
            SELECT  SUM(order_item_id) as total_quantity
			FROM amazon_brazil.order_items
			GROUP BY product_id	
	   )AS subquery
)
ORDER BY total_quantity_sold DESC;


--3)
SELECT TO_CHAR(o.order_purchase_timestamp,'month') as month,
       ROUND(SUM(oi.price),2) AS total_revenue
FROM amazon_brazil.orders o
JOIN amazon_brazil.order_items oi 
ON  o.order_id=oi.order_id
WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
GROUP BY TO_CHAR(o.order_purchase_timestamp,'month') , EXTRACT(MONTH FROM o.order_purchase_timestamp)
ORDER BY EXTRACT(MONTH FROM o.order_purchase_timestamp)

--4)

WITH segmentation AS (
    SELECT 
        c.customer_unique_id,
        CASE
            WHEN COUNT(o.order_id) BETWEEN 1 AND 2 THEN 'Occasional'
            WHEN COUNT(o.order_id) BETWEEN 3 AND 5 THEN 'Regular'
            ELSE 'Loyal'
        END AS customer_type
    FROM amazon_brazil.customers c
    JOIN amazon_brazil.orders o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT 
    customer_type,
    COUNT(*) AS count
FROM segmentation
GROUP BY customer_type
ORDER BY count DESC;

--5)
SELECT 
    o.customer_id,
    ROUND(AVG(oi.price),2) AS avg_order_value,
    RANK() OVER (ORDER BY AVG(oi.price) DESC) AS customer_rank
FROM amazon_brazil.orders o
JOIN amazon_brazil.order_items oi
    ON o.order_id = oi.order_id
GROUP BY o.customer_id
ORDER BY customer_rank
LIMIT 20;

--6)
WITH RECURSIVE monthly_sales AS (
    SELECT oi.product_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS sale_month,
        SUM(oi.price) AS monthly_sales
    FROM amazon_brazil.order_items oi
    JOIN amazon_brazil.orders o
        ON oi.order_id = o.order_id
    GROUP BY oi.product_id, DATE_TRUNC('month', o.order_purchase_timestamp)),
recursive_sales AS (
    SELECT product_id,
        sale_month,
        monthly_sales AS total_sales
    FROM monthly_sales
  UNION ALL

    SELECT m.product_id,
        m.sale_month,
        r.total_sales + m.monthly_sales AS total_sales
    FROM monthly_sales m
    JOIN recursive_sales r
        ON m.product_id = r.product_id
       AND m.sale_month = r.sale_month + INTERVAL '1 month' )
SELECT 
    product_id,
    TO_CHAR(sale_month, 'YYYY-MM') AS sale_month,
    ROUND(total_sales, 2) AS total_sales
FROM recursive_sales
ORDER BY product_id, sale_month;



--7)

WITH monthly_sales AS (
    SELECT 
        p.payment_type,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS sale_month,
        SUM(p.payment_value) AS monthly_total
    FROM amazon_brazil.payments p
    JOIN amazon_brazil.orders o
        ON p.order_id = o.order_id
    WHERE EXTRACT(YEAR FROM o.order_purchase_timestamp) = 2018
    GROUP BY p.payment_type, DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT 
    payment_type,
    TO_CHAR(sale_month, 'Mon YYYY') AS sale_month,
    ROUND(monthly_total, 2) AS monthly_total,
    ROUND(
        (monthly_total - LAG(monthly_total) OVER (PARTITION BY payment_type ORDER BY sale_month))
        / NULLIF(LAG(monthly_total) OVER (PARTITION BY payment_type ORDER BY sale_month), 0) * 100,
        2
    ) AS monthly_change
FROM monthly_sales
ORDER BY payment_type, sale_month;
