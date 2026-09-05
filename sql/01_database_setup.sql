-- =============================================================
-- OLIST E-COMMERCE SQL PORTFOLIO PROJECT
-- File 01: Database Setup, Tables, Relationships & Import Checks
-- PostgreSQL
-- =============================================================

-- Run this file in a NEW database (recommended database name: olist_ecommerce).
-- CSV files were imported with pgAdmin Import/Export after each table was created.

-- 1. SCHEMA
CREATE SCHEMA IF NOT EXISTS olist;

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'olist';

-- =============================================================
-- 2. TABLE CREATION
-- =============================================================

-- Customers
CREATE TABLE IF NOT EXISTS olist.customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);
-- Import: olist_customers_dataset.csv

-- Orders
CREATE TABLE IF NOT EXISTS olist.orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);
-- Import: olist_orders_dataset.csv

-- Product category translation
CREATE TABLE IF NOT EXISTS olist.product_category_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);
-- Import: product_category_name_translation.csv

-- Products
CREATE TABLE IF NOT EXISTS olist.products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photo_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);
-- Import: olist_products_dataset.csv

-- Sellers
CREATE TABLE IF NOT EXISTS olist.sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);
-- Import: olist_sellers_dataset.csv

-- Order items
CREATE TABLE IF NOT EXISTS olist.order_items (
    order_id VARCHAR(50),
    order_item_id INTEGER,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);
-- Import: olist_order_items_dataset.csv

-- Order payments
CREATE TABLE IF NOT EXISTS olist.order_payments (
    order_id VARCHAR(50),
    payment_sequential INTEGER,
    payment_type VARCHAR(30),
    payment_installments INTEGER,
    payment_value NUMERIC(12,2),
    PRIMARY KEY (order_id, payment_sequential)
);
-- Import: olist_order_payments_dataset.csv

-- Order reviews
-- review_id is intentionally NOT a primary key because duplicate review IDs exist.
CREATE TABLE IF NOT EXISTS olist.order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);
-- Import: olist_order_reviews_dataset.csv

-- Geolocation
-- ZIP prefix is intentionally NOT a primary key because it appears multiple times.
CREATE TABLE IF NOT EXISTS olist.geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat NUMERIC(10,7),
    geolocation_lng NUMERIC(10,7),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(10)
);
-- Import: olist_geolocation_dataset.csv

-- =============================================================
-- 3. RELATIONSHIPS
-- =============================================================
-- Add these after importing and validating the CSVs.

ALTER TABLE olist.orders
ADD CONSTRAINT fk_orders_customer
FOREIGN KEY (customer_id)
REFERENCES olist.customers(customer_id);

ALTER TABLE olist.order_items
ADD CONSTRAINT fk_order_items_order
FOREIGN KEY (order_id)
REFERENCES olist.orders(order_id);

ALTER TABLE olist.order_items
ADD CONSTRAINT fk_order_items_product
FOREIGN KEY (product_id)
REFERENCES olist.products(product_id);

ALTER TABLE olist.order_items
ADD CONSTRAINT fk_order_items_seller
FOREIGN KEY (seller_id)
REFERENCES olist.sellers(seller_id);

ALTER TABLE olist.order_payments
ADD CONSTRAINT fk_payments_order
FOREIGN KEY (order_id)
REFERENCES olist.orders(order_id);

ALTER TABLE olist.order_reviews
ADD CONSTRAINT fk_reviews_order
FOREIGN KEY (order_id)
REFERENCES olist.orders(order_id);

-- Note: product_category_name is not enforced as a foreign key in the raw model
-- because the source data initially contains missing/untranslated categories.

-- =============================================================
-- 4. IMPORT VALIDATION / EXPECTED ROW COUNTS
-- =============================================================
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM olist.customers
UNION ALL
SELECT 'orders', COUNT(*) FROM olist.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM olist.order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM olist.order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM olist.order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM olist.products
UNION ALL
SELECT 'sellers', COUNT(*) FROM olist.sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM olist.geolocation
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM olist.product_category_translation
ORDER BY table_name;

-- Expected raw counts from this project:
-- customers: 99,441
-- orders: 99,441
-- order_items: 112,650
-- order_payments: 103,886
-- order_reviews: 99,224
-- products: 32,951
-- sellers: 3,095
-- geolocation: 1,000,163
-- product_category_translation: 71 before the two manual translation additions

-- Relationship integrity checks
SELECT COUNT(*) AS unmatched_order_customers
FROM olist.orders o
LEFT JOIN olist.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS unmatched_order_items_products
FROM olist.order_items oi
LEFT JOIN olist.products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS unmatched_order_items_sellers
FROM olist.order_items oi
LEFT JOIN olist.sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

SELECT COUNT(*) AS unmatched_payment_orders
FROM olist.order_payments p
LEFT JOIN olist.orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL;
