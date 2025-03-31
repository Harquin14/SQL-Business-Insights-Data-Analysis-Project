-- ==================================================================
-- Exploratory Data Analysis (EDA) on Sales Data
-- ==================================================================

-- Step 1: View all sales data
SELECT * FROM gold.fact_sales;

-- ==================================================================
-- Step 2: Monthly Sales Trend
-- ==================================================================
-- This query calculates total sales per month to identify trends.
SELECT 
    MONTH(order_date) AS order_month,  -- Extract the month from order date
    SUM(sales_amount) AS Total_Sales  -- Sum of sales for each month
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date);

-- ==================================================================
-- Step 3: Monthly Sales Trend (Using DATETRUNC)
-- ==================================================================
-- This query provides the same sales trend analysis but groups by full month (YYYY-MM format).
SELECT 
    DATETRUNC(MONTH, order_date) AS order_month,  -- Truncate date to month level
    SUM(sales_amount) AS Total_Sales  -- Sum of sales per month
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date);

-- ==================================================================
-- Step 4: Running Total of Sales Over the Years
-- ==================================================================
-- This query calculates cumulative sales over the years to track overall growth.
SELECT 
    order_dates, 
    SUM(Total_Sales) OVER(ORDER BY order_dates) AS Running_Total -- Running total sales
FROM (
    SELECT 
        YEAR(order_date) AS order_dates,  -- Extract year from order date
        SUM(sales_amount) AS Total_Sales -- Total sales per year
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date)
) V;

-- ==================================================================
-- Step 5: Cumulative Sales Per Product Over Time
-- ==================================================================
-- This query tracks the sales progression for each product over time.
WITH per AS (
    SELECT 
        p.product_name, 
        s.order_date,  -- Include order date for time-based aggregation
        SUM(s.sales_amount) AS total_sales  -- Total sales per product
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p 
        ON s.product_key = p.product_key
    GROUP BY p.product_name, s.order_date
)
SELECT 
    product_name, 
    order_date,
    total_sales, 
    SUM(total_sales) OVER(PARTITION BY product_name ORDER BY order_date) AS cumulative_sales,  -- Running total sales per product
    LAG(total_sales) OVER(PARTITION BY product_name ORDER BY order_date) AS previous_sales  -- Previous month's sales
FROM per
ORDER BY product_name, order_date;

-- ==================================================================
-- Step 6: Contribution of Each Product Category to Total Sales
-- ==================================================================
-- This query determines which category contributes the most to overall revenue.
WITH part AS (
    SELECT 
        category, 
        SUM(sales_amount) AS Total_sales  -- Sum of sales per category
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_products p 
        ON s.product_key = p.product_key
    GROUP BY category
)
SELECT 
    category,
    Total_sales,
    SUM(Total_sales) OVER() AS Overall_Sales,  -- Total sales across all categories
    CONCAT(ROUND((CAST(Total_sales AS FLOAT) / SUM(Total_sales) OVER()) * 100, 2), '%') AS Percentage_Contribution  -- Category's contribution in percentage
FROM part;

-- ==================================================================
-- Step 7: Segment Products into Cost Ranges
-- ==================================================================
-- This query groups products based on cost and counts how many products fall into each range.
WITH cost AS (
    SELECT 
        product_key,
        product_name, 
        cost,
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100 - 500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500 - 1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT 
    cost_range,
    COUNT(DISTINCT product_name) AS total_products -- Count number of products in each price segment
FROM cost
GROUP BY cost_range
ORDER BY total_products DESC;

-- ==================================================================
-- Step 8: Customer Segmentation Based on Spending Behavior
-- ==================================================================
-- This query groups customers into three categories based on their spending habits.
-- - VIP: Customers with at least 12 months of history and spending more than $5000.
-- - REGULAR: Customers with at least 12 months of history and spending $5000 or less.
-- - NEW: Customers with a lifespan of less than 12 months.

WITH cust_segment AS (
    SELECT 
        c.customer_key, 
        SUM(s.sales_amount) AS total_sales,  -- Total spending per customer
        MIN(s.order_date) AS first_order,  -- First order date
        MAX(s.order_date) AS last_order,  -- Most recent order date
        DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) AS Life_span  -- Customer lifespan in months
    FROM gold.fact_sales s
    JOIN gold.dim_customers c
        ON s.customer_key = c.customer_key
    GROUP BY c.customer_key
)
SELECT 
    Customers_segment, 
    COUNT(customer_key) AS total_customers -- Total number of customers in each segment
FROM (
    SELECT 
        total_sales, 
        Life_span,
        CASE 
            WHEN total_sales > 5000 AND Life_span >= 12 THEN 'VIP'
            WHEN total_sales <= 5000 AND Life_span >= 12 THEN 'REGULAR'
            ELSE 'NEW'
        END AS Customers_segment,  -- Assign customer category based on spending behavior
        customer_key
    FROM cust_segment
) V
GROUP BY Customers_segment
ORDER BY COUNT(customer_key) DESC;
