-- ============================================================
-- TRAWiMe — Full Database Initialization Script
-- Chạy 1 lần để tạo toàn bộ bảng + seed data mặc định.
-- Database: trawime_db (MySQL 5.7+ / MariaDB 10.3+)
-- ============================================================

CREATE DATABASE IF NOT EXISTS trawime_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE trawime_db;

-- ── AUTH / USER ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    avatar_url    VARCHAR(500) NULL,
    phone         VARCHAR(20)  NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'user',
    is_active     TINYINT(1)   NOT NULL DEFAULT 1,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── LOCATION ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS categories (
    id   INT AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(50)  NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    INDEX idx_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS locations (
    id                    INT AUTO_INCREMENT PRIMARY KEY,
    name                  VARCHAR(255) NOT NULL,
    description           TEXT         NULL,
    category              VARCHAR(50)  NOT NULL,
    address               VARCHAR(500) NULL,
    city                  VARCHAR(100) NOT NULL,
    country               VARCHAR(100) NOT NULL DEFAULT 'Vietnam',
    latitude              FLOAT        NULL,
    longitude             FLOAT        NULL,
    images                JSON         NULL,
    thumbnail             VARCHAR(2048) NULL,
    description_embedding JSON         NULL,
    created_by            INT          NULL,
    created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_city     (city),
    INDEX idx_category (category),
    FULLTEXT INDEX ft_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS location_categories (
    location_id INT NOT NULL,
    category_id INT NOT NULL,
    PRIMARY KEY (location_id, category_id),
    FOREIGN KEY (location_id) REFERENCES locations(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── REVIEW ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reviews (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT          NOT NULL,
    user_name   VARCHAR(100) NULL,
    user_email  VARCHAR(255) NULL,
    location_id INT          NOT NULL,
    rating      FLOAT        NOT NULL,
    comment     TEXT         NULL,
    photos      JSON         NULL,
    visited_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_location (location_id),
    INDEX idx_user     (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── ITINERARY ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS itineraries (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    user_id     INT          NOT NULL,
    title       VARCHAR(255) NOT NULL,
    description TEXT         NULL,
    start_date  DATETIME     NULL,
    end_date    DATETIME     NULL,
    status      VARCHAR(20)  NOT NULL DEFAULT 'planned',
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS itinerary_days (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    itinerary_id  INT          NOT NULL,
    day_number    INT          NOT NULL,
    date          DATE         NULL,
    title         VARCHAR(255) NULL,
    description   TEXT         NULL,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE,
    INDEX idx_itinerary (itinerary_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS itinerary_activities (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    day_id        INT          NOT NULL,
    location_id   INT          NULL,
    location_name VARCHAR(255) NULL,
    location_lat  FLOAT        NULL,
    location_lng  FLOAT        NULL,
    location_image TEXT        NULL,
    title         VARCHAR(255) NOT NULL,
    description   TEXT         NULL,
    start_time    TIME         NULL,
    end_time      TIME         NULL,
    cost_estimate FLOAT        NULL,
    note          TEXT         NULL,
    order_index   INT          NOT NULL DEFAULT 0,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (day_id) REFERENCES itinerary_days(id) ON DELETE CASCADE,
    INDEX idx_day (day_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── AI CHAT ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS chat_sessions (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    user_id    INT          NOT NULL,
    title      VARCHAR(255) NULL,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS chat_messages (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT          NOT NULL,
    role       VARCHAR(20)  NOT NULL DEFAULT 'user',
    content    TEXT         NOT NULL,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE,
    INDEX idx_session (session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── SEED DATA ─────────────────────────────────────────────────────────────────
-- Toàn bộ dữ liệu demo (categories, locations, users, reviews) được tạo bởi:
--   python seed_data.py
--
-- Script init_db.sql chỉ tạo schema (cấu trúc bảng), KHÔNG insert data.

SELECT 'Tables created! Now run: python seed_data.py' AS next_step;
