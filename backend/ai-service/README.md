# TRAWIME - AI Service

Dịch vụ Trí tuệ Nhân tạo (AI Service) chịu trách nhiệm tích hợp mô hình ngôn ngữ Google Gemini API để hỗ trợ chatbot hội thoại thông minh và thực hiện gợi ý địa điểm du lịch bằng tìm kiếm ngữ nghĩa (Semantic Search).

## Các chức năng chính

- Tích hợp Google Gemini API để thực hiện hội thoại thời gian thực với trợ lý du lịch ảo.
- Quản lý các phiên hội thoại (Chat Sessions) và lưu lịch sử tin nhắn của từng người dùng vào cơ sở dữ liệu.
- Tự động trích xuất các câu gợi ý nhanh (suggestions) từ phản hồi của AI để hiển thị thành các nút lựa chọn nhanh trên màn hình di động.
- Sinh vector đặc trưng (description_embedding) 768 chiều cho văn bản mô tả của địa điểm bằng mô hình `gemini-embedding-001`.
- API nội bộ nhận lệnh từ `location-service` để cập nhật vector đặc trưng theo thời gian thực khi Admin thay đổi địa điểm.
- Thuật toán gợi ý địa điểm thông minh: Nhận yêu cầu bằng ngôn ngữ tự nhiên từ người dùng, sinh vector đặc trưng cho yêu cầu đó và thực hiện tính toán độ tương đồng Cosine (Cosine Similarity) với vector đặc trưng của các địa điểm trong hệ thống để tìm ra 5 kết quả phù hợp nhất.
- Hỗ trợ cơ chế phản hồi ngoại tuyến giả lập (Mock Fallback) khi mất kết nối mạng hoặc lỗi khóa API.

## Cổng hoạt động (Port)

Dịch vụ chạy tại cổng: `8006`

## Danh sách API chính

- `POST /api/ai/recommend`: Gợi ý địa điểm thông minh dựa trên mô tả yêu cầu bằng ngôn ngữ tự nhiên và tính toán Cosine Similarity.
- `POST /api/ai/chat`: Gọi chatbot trả lời một lượt duy nhất (không lưu lại lịch sử cuộc trò chuyện).
- `POST /api/ai/generate-embeddings`: Duyệt qua toàn bộ địa điểm chưa có vector và sinh hàng loạt (yêu cầu quyền Admin).
- `POST /internal/embed-location/{location_id}`: API nội bộ dùng để tạo vector đặc trưng thời gian thực cho một địa điểm.
- `GET /api/chat/sessions`: Lấy danh sách các phiên trò chuyện cũ của tài khoản đang đăng nhập.
- `GET /api/chat/sessions/{session_id}`: Lấy toàn bộ lịch sử tin nhắn của một phiên chat cụ thể.
- `POST /api/chat/send`: Gửi tin nhắn mới vào phiên chat, lưu trữ hội thoại và trả về phản hồi từ Gemini AI.
- `DELETE /api/chat/sessions/{session_id}`: Xóa một phiên trò chuyện.
