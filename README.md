# VietMap DuoDash Bridge (Rootless iOS 16)
Dự án tweak bắc cầu dữ liệu từ ứng dụng VietMap Live sang DuoDash CarPlay Bubble.

### Hướng dẫn Build ra file .deb trong 1 bước:
1. Bạn có thể build trực tiếp trên iPhone qua Terminal (NewTerm 3):
   - Chép thư mục này vào iPhone.
   - Chạy lệnh: `make package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1`
   - File `.deb` sẽ được tạo trong thư mục `packages/`.
2. Mở file `.deb` bằng Sileo hoặc Filza và nhấn Install.
3. Vào Settings -> DuoDash -> Quản lý tweak -> Bong bóng Điều hướng -> Nguồn: Chọn "VietMap Live".
