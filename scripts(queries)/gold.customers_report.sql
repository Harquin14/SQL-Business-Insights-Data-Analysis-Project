/* 
====================================================
Customer Report View
====================================================

Purpose:
This report consolidates key customer metrics and behaviors

Highlights:
1. Extracts essential customer details such as name, age, and transaction data.
2. Segments customers into categories (VIP, Regular, New) based on spending and engagement.
3. Aggregates key customer-level metrics, including:
   - Total orders placed
   - Total sales amount
   - Total quantity purchased
   - Total products bought
   - Customer lifespan (in months)
4. Calculates valuable KPIs:
   - Recency (months since last order)
   - Average order value (Total Sales / Total Orders)
   - Average monthly spend (Total Sales / Lifespan)

====================================================
*/

-- Create a view that consolidates customer purchase behavior
CREATE VIEW gold.customers_reports AS

-- Step 1: Extract essential fields for customer transactions
WITH essential_fields AS (
    SELECT 
        s.order_number,                -- Unique identifier for each order
        s.product_key,                 -- Product associated with the order
        s.order_date,                  -- Date when the order was placed
        s.sales_amount,                -- Amount spent on the order
        s.quantity,                    -- Quantity of products purchased
        c.customer_key,                -- Unique identifier for each customer
        c.customer_number,             -- Customer reference number
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name, -- Full customer name
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age  -- Calculate customer's age
    FROM gold.fact_sales s
    LEFT JOIN gold.dim_customers c 
        ON s.customer_key = c.customer_key
    WHERE s.order_date IS NOT NULL -- Ensure we only consider valid transactions
),

-- Step 2: Aggregate customer transaction data
Aggregations AS (
    SELECT
        customer_key, 
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS Total_orders,  -- Count of unique orders per customer
        COUNT(DISTINCT product_key) AS Total_Products, -- Number of distinct products purchased
        SUM(sales_amount) AS Total_Sales,             -- Total revenue generated from the customer
        SUM(quantity) AS Total_Quantity,              -- Total quantity of products bought
        MAX(order_date) AS Last_Order_Date,           -- Date of the last order
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS Life_span -- Duration of customer engagement in months
    FROM essential_fields
    GROUP BY customer_key, customer_number, customer_name, age
)

-- Step 3: Final transformation and KPI calculation
SELECT 
    customer_key, 
    customer_number,
    customer_name,
    age,
    
    -- Categorize customers by age groups
    CASE 
        WHEN age < 20 THEN 'Below 20'
        WHEN age BETWEEN 30 AND 39 THEN '30 - 39'
        WHEN age BETWEEN 40 AND 49 THEN '40 - 49'
        WHEN age BETWEEN 50 AND 59 THEN '50 - 59'
        ELSE 'Above 60'
    END AS age_group,

    -- Categorize customers based on spending and engagement
    CASE 
        WHEN Total_Sales > 5000 AND Life_span >= 12 THEN 'VIP'         -- High spenders with long engagement
        WHEN Total_Sales <= 5000 AND Life_span >= 12 THEN 'REGULAR'    -- Moderate spenders with long engagement
        ELSE 'NEW'                                                     -- New or less engaged customers
    END AS Customers_category,

    Last_Order_Date,  -- The most recent purchase date
    DATEDIFF(MONTH, Last_Order_Date, GETDATE()) AS Recency, -- Months since last order

    -- Aggregate Metrics
    Total_orders,      -- Total number of orders made by the customer
    Total_Products,    -- Total number of distinct products bought
    Total_Sales,       -- Total revenue generated from the customer
    Total_Quantity,    -- Total quantity of items bought
    Life_span,         -- Duration in months from first to last order

    -- KPI: Average order value (Total Sales / Total Orders)
    CASE 
        WHEN Total_orders = 0 THEN 0
        ELSE Total_Sales / Total_orders  
    END AS Average_Order_Value,

    -- KPI: Average monthly spend (Total Sales / Life Span)
    CASE 
        WHEN Life_span = 0 THEN Total_Sales
        ELSE Total_Sales / Life_span
    END AS Average_Month_Spend

FROM Aggregations;

-- Preview the customer report view
SELECT * FROM gold.customers_reports;
