-- =====================================================================
-- Esquema de las tablas crudas (fuente). Se cargan desde data/raw/*.csv
-- =====================================================================

CREATE TABLE customers (
    customer_id     INTEGER PRIMARY KEY,
    first_name      TEXT,
    last_name       TEXT,
    email           TEXT,
    signup_date     TEXT,
    city            TEXT,
    country         TEXT,
    segment         TEXT,
    acquisition_channel TEXT
);

CREATE TABLE products (
    product_id      INTEGER PRIMARY KEY,
    product_name    TEXT,
    category        TEXT,
    unit_cost       REAL,
    unit_price      REAL,
    active          INTEGER
);

CREATE TABLE orders (
    order_id        INTEGER PRIMARY KEY,
    customer_id     INTEGER,
    order_date      TEXT,
    status          TEXT,
    payment_method  TEXT,
    shipping_cost   REAL,
    campaign_id     INTEGER,
    FOREIGN KEY(customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY(campaign_id) REFERENCES marketing_campaigns(campaign_id)
);

CREATE TABLE order_items (
    order_item_id   INTEGER PRIMARY KEY,
    order_id        INTEGER,
    product_id      INTEGER,
    quantity        INTEGER,
    unit_price      REAL,
    discount_pct    REAL,
    FOREIGN KEY(order_id) REFERENCES orders(order_id),
    FOREIGN KEY(product_id) REFERENCES products(product_id)
);

CREATE TABLE marketing_campaigns (
    campaign_id     INTEGER PRIMARY KEY,
    campaign_name   TEXT,
    channel         TEXT,
    start_date      TEXT,
    end_date        TEXT,
    budget_usd      REAL
);

CREATE TABLE reviews (
    review_id       INTEGER PRIMARY KEY,
    product_id      INTEGER,
    customer_id     INTEGER,
    rating          INTEGER,
    review_date     TEXT,
    comment         TEXT,
    FOREIGN KEY(product_id) REFERENCES products(product_id),
    FOREIGN KEY(customer_id) REFERENCES customers(customer_id)
);
