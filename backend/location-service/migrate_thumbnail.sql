-- Migration: thêm cột thumbnail vào bảng locations
-- Chạy 1 lần trên MySQL:
ALTER TABLE locations
  ADD COLUMN thumbnail VARCHAR(2048) NULL
  AFTER images;
