-- Migration: thêm cột user_name và user_email vào bảng reviews
-- Chạy 1 lần trên MySQL để lưu tên user vào review (tránh N+1 query):
ALTER TABLE reviews
  ADD COLUMN user_name VARCHAR(100) NULL AFTER user_id,
  ADD COLUMN user_email VARCHAR(255) NULL AFTER user_name;
