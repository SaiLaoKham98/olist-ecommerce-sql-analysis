-- =============================================================
-- OLIST E-COMMERCE SQL PORTFOLIO PROJECT
-- File 02: Data Quality & Cleaning Checks
-- PostgreSQL
-- =============================================================

-- =============================================================
-- 1. CUSTOMERS
-- =============================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS null_customer_unique_id,
    COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS null_zip,
    COUNT(*) FILTER (WHERE customer_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS null_state
FROM olist.customers;

SELECT customer_id, COUNT(*) AS duplicate_count
FROM olist.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- =============================================================
-- 2. ORDERS
-- =============================================================
SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_order_status,
    COUNT(*) FILTER (WHERE order_purchase_timestamp IS NULL) AS null_purchase_date,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS null_approved_date,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL) AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_customer_delivery_date,
    COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) AS null_estimated_delivery_date
FROM olist.orders;

SELECT order_status, COUNT(*) AS number_of_orders
FROM olist.orders
GROUP BY order_status
ORDER BY number_of_orders DESC;

SELECT
    COUNT(*) FILTER (WHERE order_approved_at < order_purchase_timestamp) AS approved_before_purchase,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date < order_purchase_timestamp) AS carrier_before_purchase,
    COUNT(*) FILTER (WHERE order_delivered_customer_date < order_purchase_timestamp) AS delivered_before_purchase,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
    ) AS delivered_but_missing_date
FROM olist.orders;

-- Finding: 8 orders were marked delivered but had no customer delivery timestamp.
-- Decision: retain them in the raw data, but exclude them from delivery-time analysis.

-- =============================================================
-- 3. ORDER ITEMS
-- =============================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE order_item_id IS NULL) AS null_order_item_id,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS null_seller_id,
    COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS null_shipping_limit_date,
    COUNT(*) FILTER (WHERE price IS NULL) AS null_price,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS null_freight
FROM olist.order_items;

SELECT
    COUNT(*) FILTER (WHERE price <= 0) AS zero_or_negative_price,
    COUNT(*) FILTER (WHERE freight_value < 0) AS negative_freight,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price), 2) AS avg_price,
    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight,
    ROUND(AVG(freight_value), 2) AS avg_freight
FROM olist.order_items;

SELECT order_id, order_item_id, COUNT(*) AS duplicate_count
FROM olist.order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- =============================================================
-- 4. PRODUCTS & CATEGORY TRANSLATIONS
-- =============================================================
SELECT
    COUNT(*) AS total_products,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_category,
    COUNT(*) FILTER (WHERE product_name_length IS NULL) AS null_name_length,
    COUNT(*) FILTER (WHERE product_description_length IS NULL) AS null_description_length,
    COUNT(*) FILTER (WHERE product_photo_qty IS NULL) AS null_photos_qty,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS null_weight,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS null_length,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS null_height,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS null_width
FROM olist.products;

SELECT COUNT(*) AS invalid_products
FROM olist.products
WHERE product_weight_g <= 0
   OR product_length_cm <= 0
   OR product_height_cm <= 0
   OR product_width_cm <= 0;

SELECT COUNT(*) AS products_missing_category
FROM olist.products
WHERE product_category_name IS NULL;

SELECT DISTINCT p.product_category_name
FROM olist.products p
LEFT JOIN olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- Two category names had no English translation in the source translation file.
INSERT INTO olist.product_category_translation
    (product_category_name, product_category_name_english)
VALUES
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_food_preparers'),
    ('pc_gamer', 'pc_gaming')
ON CONFLICT (product_category_name) DO NOTHING;

SELECT COUNT(DISTINCT p.product_category_name) AS untranslated_categories_remaining
FROM olist.products p
LEFT JOIN olist.product_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;

-- Finding: 610 products have NULL product_category_name.
-- Decision: retain them and report them as 'Unknown' with COALESCE in analysis.

-- =============================================================
-- 5. PAYMENTS
-- =============================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE payment_sequential IS NULL) AS null_payment_sequential,
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS null_payment_type,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS null_installments,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS null_payment_value,
    COUNT(*) FILTER (WHERE payment_value <= 0) AS zero_or_negative_payments,
    COUNT(*) FILTER (WHERE payment_installments < 1) AS invalid_installments,
    COUNT(*) FILTER (WHERE payment_type = 'not_defined') AS undefined_payment_type
FROM olist.order_payments;

SELECT payment_type, COUNT(*) AS payment_records
FROM olist.order_payments
GROUP BY payment_type
ORDER BY payment_records DESC;

-- Findings from this project:
-- 9 zero-value payment records
-- 2 credit-card payment rows with installment count < 1
-- 3 rows with payment_type = 'not_defined'
-- Decision: retain raw records and filter only when a specific analysis requires valid values.

-- =============================================================
-- 6. REVIEWS
-- =============================================================
SELECT
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (WHERE review_id IS NULL) AS null_review_id,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE review_score IS NULL) AS null_review_score,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL) AS null_title,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL) AS null_message,
    COUNT(*) FILTER (WHERE review_creation_date IS NULL) AS null_creation_date,
    COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) AS null_answer_timestamp,
    MIN(review_score) AS min_review_score,
    MAX(review_score) AS max_review_score
FROM olist.order_reviews;

SELECT review_id, COUNT(*) AS duplicate_count
FROM olist.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (
    SELECT order_id
    FROM olist.order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) x;

-- Findings: 789 review IDs were duplicated and 547 orders had multiple review rows.
-- Decision: review_id was not enforced as a primary key. Review-based analysis is aggregated
-- to one row per order first to avoid duplicate joins and inflated revenue.

-- =============================================================
-- 7. SELLERS
-- =============================================================
SELECT
    COUNT(*) AS total_sellers,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS null_seller_id,
    COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL) AS null_zip,
    COUNT(*) FILTER (WHERE seller_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE seller_state IS NULL) AS null_state
FROM olist.sellers;

-- =============================================================
-- 8. GEOLOCATION
-- =============================================================
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) AS null_zip,
    COUNT(*) FILTER (WHERE geolocation_lat IS NULL) AS null_lat,
    COUNT(*) FILTER (WHERE geolocation_lng IS NULL) AS null_lng,
    COUNT(*) FILTER (WHERE geolocation_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE geolocation_state IS NULL) AS null_state,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS unique_zip_prefixes
FROM olist.geolocation;

SELECT COUNT(*) AS invalid_coordinates
FROM olist.geolocation
WHERE geolocation_lat < -90
   OR geolocation_lat > 90
   OR geolocation_lng < -180
   OR geolocation_lng > 180;

-- Finding: 1,000,163 geolocation rows map to about 19,015 ZIP prefixes.
-- Do not join raw geolocation directly to customers for revenue calculations because it can
-- duplicate rows. Aggregate geolocation to one row per ZIP prefix first when coordinates are needed.
