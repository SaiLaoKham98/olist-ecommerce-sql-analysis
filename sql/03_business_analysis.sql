-- =============================================================
-- OLIST E-COMMERCE SQL PORTFOLIO PROJECT
-- File 03: Business Analysis
-- PostgreSQL
-- =============================================================

-- =============================================================
-- 1. EXECUTIVE KPIs
-- =============================================================
WITH order_totals AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS order_value,
        SUM(oi.freight_value) AS freight_value
    FROM olist.order_items oi
    JOIN olist.orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
)
SELECT
    COUNT(*) AS delivered_orders,
    ROUND(SUM(order_value), 2) AS total_product_revenue,
    ROUND(AVG(order_value), 2) AS avg_order_value,
    ROUND(SUM(freight_value), 2) AS total_freight,
    (SELECT COUNT(DISTINCT c.customer_unique_id)
     FROM olist.customers c
     JOIN olist.orders o ON c.customer_id = o.customer_id
     WHERE o.order_status = 'delivered') AS unique_customers,
    (SELECT ROUND(AVG(review_score), 2)
     FROM olist.order_reviews) AS avg_review_score
FROM order_totals;

-- Project results:
-- Delivered orders: 96,478
-- Product revenue: 13,221,498.11
-- Average order value: 137.04
-- Total freight: 2,198,275.64
-- Overall average review score: 4.09

-- =============================================================
-- 2. MONTHLY REVENUE TREND
-- =============================================================
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM olist.orders o
JOIN olist.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month;

-- =============================================================
-- 3. MONTH-OVER-MONTH REVENUE GROWTH (2017+)
-- =============================================================
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        SUM(oi.price) AS revenue
    FROM olist.orders o
    JOIN olist.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= DATE '2017-01-01'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
),
growth AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM monthly_revenue
)
SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND((revenue - previous_month_revenue) / previous_month_revenue * 100, 2) AS mom_growth_pct
FROM growth
WHERE previous_month_revenue IS NOT NULL
ORDER BY month;

-- Insight: Revenue growth was volatile. December 2017 had the sharpest visible MoM decline
-- at -26.50%, following a strong November.

-- =============================================================
-- 4. YEAR-OVER-YEAR REVENUE GROWTH (CALENDAR-BASED)
-- =============================================================
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        SUM(oi.price) AS revenue
    FROM olist.orders o
    JOIN olist.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
)
SELECT
    current.month,
    ROUND(current.revenue, 2) AS revenue,
    ROUND(previous.revenue, 2) AS previous_year_revenue,
    ROUND((current.revenue - previous.revenue) / previous.revenue * 100, 2) AS yoy_growth_pct
FROM monthly_revenue current
JOIN monthly_revenue previous
    ON current.month = previous.month + INTERVAL '1 year'
ORDER BY current.month;

-- Insight: 2018 delivered-order revenue was substantially above the same months in 2017.
-- January 2018 showed especially high growth, but the low January 2017 base should be considered.

-- =============================================================
-- 5. CUSTOMER RETENTION / REPEAT PURCHASE RATE
-- =============================================================
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM olist.customers c
    JOIN olist.orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE total_orders > 1) AS repeat_customers,
    COUNT(*) FILTER (WHERE total_orders = 1) AS one_time_customers,
    ROUND(COUNT(*) FILTER (WHERE total_orders > 1) * 100.0 / COUNT(*), 2) AS repeat_customer_rate_pct,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    MAX(total_orders) AS max_orders_by_customer
FROM customer_orders;

-- Insight: Repeat customer rate = 3.00%; average delivered orders per customer = 1.03.
-- Olist relies heavily on one-time buyers, creating a clear retention opportunity.

-- =============================================================
-- 6. TOP CUSTOMERS BY SPENDING
-- =============================================================
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_spent
FROM olist.customers c
JOIN olist.orders o ON c.customer_id = o.customer_id
JOIN olist.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY total_spent DESC
LIMIT 10;

-- =============================================================
-- 7. CUSTOMER VALUE BY STATE
-- =============================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT c.customer_unique_id), 2) AS revenue_per_customer
FROM olist.customers c
JOIN olist.orders o ON c.customer_id = o.customer_id
JOIN olist.order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Insight: SP dominates total revenue because of scale, while several smaller states show
-- higher revenue per customer. Evaluate geography using both market size and customer value.

-- =============================================================
-- 8. TOP PRODUCT CATEGORIES BY REVENUE
-- =============================================================
SELECT
    COALESCE(t.product_category_name_english, 'Unknown') AS product_category,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM olist.order_items oi
JOIN olist.orders o ON oi.order_id = o.order_id
JOIN olist.products p ON oi.product_id = p.product_id
LEFT JOIN olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
ORDER BY revenue DESC
LIMIT 10;

-- Insight: health_beauty leads delivered product revenue, while bed_bath_table leads unit volume.

-- =============================================================
-- 9. TOP PRODUCT CATEGORIES BY UNIT VOLUME
-- =============================================================
SELECT
    COALESCE(t.product_category_name_english, 'Unknown') AS product_category,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue
FROM olist.order_items oi
JOIN olist.orders o ON oi.order_id = o.order_id
JOIN olist.products p ON oi.product_id = p.product_id
LEFT JOIN olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
ORDER BY items_sold DESC
LIMIT 10;

-- =============================================================
-- 10. HIGH-PRICE CATEGORIES (MINIMUM 100 DELIVERED ITEMS)
-- =============================================================
SELECT
    COALESCE(t.product_category_name_english, 'Unknown') AS product_category,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM olist.order_items oi
JOIN olist.orders o ON oi.order_id = o.order_id
JOIN olist.products p ON oi.product_id = p.product_id
LEFT JOIN olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
HAVING COUNT(*) >= 100
ORDER BY avg_item_price DESC
LIMIT 10;

-- Insight: computers had the highest average item price among categories with >=100 delivered items.

-- =============================================================
-- 11. HIGH-REVENUE CATEGORIES WITH BELOW-4.0 REVIEWS
-- =============================================================
WITH review_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS order_review_score
    FROM olist.order_reviews
    GROUP BY order_id
),
category_performance AS (
    SELECT
        COALESCE(t.product_category_name_english, 'Unknown') AS product_category,
        SUM(oi.price) AS revenue,
        COUNT(DISTINCT o.order_id) AS total_orders,
        AVG(r.order_review_score) AS avg_review_score
    FROM olist.order_items oi
    JOIN olist.orders o ON oi.order_id = o.order_id
    JOIN olist.products p ON oi.product_id = p.product_id
    LEFT JOIN olist.product_category_translation t
        ON p.product_category_name = t.product_category_name
    JOIN review_per_order r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY product_category
    HAVING COUNT(DISTINCT o.order_id) >= 100
)
SELECT
    product_category,
    ROUND(revenue, 2) AS revenue,
    total_orders,
    ROUND(avg_review_score, 2) AS avg_review_score
FROM category_performance
WHERE avg_review_score < 4.0
ORDER BY revenue DESC;

-- Insight: office_furniture stood out with a comparatively low average review (~3.51), while
-- bed_bath_table, computers_accessories, and furniture_decor combined high revenue with <4.0 reviews.

-- =============================================================
-- 12. TOP SELLERS BY DELIVERED REVENUE
-- =============================================================
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue
FROM olist.order_items oi
JOIN olist.orders o ON oi.order_id = o.order_id
JOIN olist.sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY revenue DESC
LIMIT 10;

-- =============================================================
-- 13. TOP-10 SELLER REVENUE CONCENTRATION
-- =============================================================
WITH seller_revenue AS (
    SELECT
        s.seller_id,
        SUM(oi.price) AS revenue
    FROM olist.order_items oi
    JOIN olist.orders o ON oi.order_id = o.order_id
    JOIN olist.sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_id
),
ranked_sellers AS (
    SELECT
        seller_id,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC) AS seller_rank,
        SUM(revenue) OVER () AS total_revenue
    FROM seller_revenue
)
SELECT
    ROUND(SUM(revenue) / MAX(total_revenue) * 100, 2) AS top_10_seller_revenue_share_pct
FROM ranked_sellers
WHERE seller_rank <= 10;

-- Insight: Top 10 sellers account for 13.27% of delivered product revenue, suggesting revenue
-- is relatively distributed across the seller base rather than dominated by a few sellers.

-- =============================================================
-- 14. LATE-DELIVERY RATE
-- =============================================================
SELECT
    COUNT(*) AS delivered_orders_with_valid_delivery_date,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date > order_estimated_delivery_date
    ) AS late_orders,
    ROUND(
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date > order_estimated_delivery_date
        ) * 100.0 / COUNT(*),
        2
    ) AS late_delivery_rate_pct
FROM olist.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- Insight: 8.11% of delivered orders with a valid delivery date arrived late.

-- =============================================================
-- 15. DELIVERY PERFORMANCE VS CUSTOMER SATISFACTION
-- =============================================================
WITH review_per_order AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_order_review
    FROM olist.order_reviews
    GROUP BY order_id
)
SELECT
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On Time / Early'
    END AS delivery_status,
    COUNT(*) AS orders,
    ROUND(AVG(r.avg_order_review), 2) AS avg_review_score
FROM olist.orders o
JOIN review_per_order r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status
ORDER BY avg_review_score DESC;

-- Insight: On-time/early deliveries averaged 4.29 vs 2.57 for late deliveries.
-- Delivery reliability has a strong relationship with customer satisfaction.

-- =============================================================
-- 16. ADVANCED SQL: CUSTOMER SPENDING RANK
-- =============================================================
WITH customer_spending AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spent
    FROM olist.customers c
    JOIN olist.orders o ON c.customer_id = o.customer_id
    JOIN olist.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    total_orders,
    ROUND(total_spent, 2) AS total_spent,
    DENSE_RANK() OVER (ORDER BY total_spent DESC) AS spending_rank
FROM customer_spending
ORDER BY spending_rank
LIMIT 20;

-- =============================================================
-- FINAL BUSINESS TAKEAWAYS
-- =============================================================
-- 1. 96,478 delivered orders generated 13.22M in product revenue; AOV = 137.04.
-- 2. Repeat customer rate is only 3.00%, indicating a major retention opportunity.
-- 3. SP dominates total revenue and customer volume, but smaller states can have higher value/customer.
-- 4. health_beauty leads revenue; bed_bath_table leads unit volume.
-- 5. High-value categories such as computers depend more on price than sales volume.
-- 6. Several commercially important categories have below-4.0 review scores.
-- 7. Top 10 sellers contribute 13.27% of revenue, indicating relatively broad seller distribution.
-- 8. 8.11% of delivered orders arrive late.
-- 9. On-time/early delivery review score = 4.29 vs late delivery = 2.57.
-- 10. Delivery reliability and customer retention are two of the clearest business opportunities.
