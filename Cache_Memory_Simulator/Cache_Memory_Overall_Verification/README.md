# Cache Memory Simulator RTL – Testbench & Verification

Thư mục này chứa các file dùng để kiểm thử hệ thống Cache Memory trên ModelSim. Phần Testbench do thành viên phụ trách Verification thực hiện.

## 1. Cấu trúc thư mục

```text
rtl/
├── cache_top.v
├── cache_controller.v
├── cache_tag.v
├── cache_data.v
├── main_memory.v
├── tb_cache.v
└── run_cache.do
```

- `cache_top.v`: module tổng, kết nối các khối trong hệ thống.
- `cache_controller.v`: điều khiển hoạt động của Cache.
- `cache_tag.v`: lưu Tag và Valid bit.
- `cache_data.v`: lưu dữ liệu Cache.
- `main_memory.v`: mô hình bộ nhớ chính.
- `tb_cache.v`: Testbench kiểm thử toàn hệ thống.
- `run_cache.do`: các lệnh compile và chạy mô phỏng trên ModelSim.

## 2. Cấu hình đang dùng

Theo các file RTL được đưa vào project:

| Thông số | Giá trị |
|---|---|
| Kiểu ánh xạ | Direct-mapped |
| Số set | 4 |
| Số byte trong một block | 2 |
| Độ rộng địa chỉ CPU | 8 bit |
| Độ rộng dữ liệu | 8 bit |
| Tag | `cpu_addr[7:3]` – 5 bit |
| Index | `cpu_addr[2:1]` – 2 bit |
| Offset | `cpu_addr[0]` – 1 bit |
| Reset | Active-low (`rst_n`) |
| Yêu cầu CPU | `cpu_req` |
| Ghi dữ liệu | `cpu_we` |

CPU giữ `cpu_req` ở mức 1 và giữ ổn định địa chỉ, dữ liệu trong lúc chờ `cpu_ready`.

Controller có các trạng thái được khai báo trong RTL:

| Mã | Trạng thái |
|---|---|
| `000` | IDLE |
| `001` | CHECK |
| `010` | MISS |
| `011` | REFILL |
| `100` | WRITE_WAIT |
| `101` | DONE |

Chính sách ghi trong Controller hiện tại là **write-through** và **no-write-allocate**. Main Memory khởi tạo dữ liệu theo dạng `memory[i] = i`.

## 3. Chạy mô phỏng bằng ModelSim

1. Giải nén project.
2. Mở ModelSim và chọn **File → Change Directory**.
3. Chọn thư mục `rtl`.
4. Nhập lệnh sau trong cửa sổ Transcript:

```tcl
do run_cache.do
```

Có thể chạy thủ công bằng các lệnh:

```tcl
vlib work
vlog -2001 cache_tag.v
vlog -2001 cache_data.v
vlog -2001 main_memory.v
vlog -2001 cache_controller.v
vlog -2001 cache_top.v
vlog -2001 tb_cache.v
vsim -voptargs=+acc work.tb_cache
add wave -r sim:/tb_cache/*
run -all
```

Sau khi chạy, xem cửa sổ **Transcript** để kiểm tra kết quả từng test và cửa sổ **Wave** để theo dõi tín hiệu CPU, trạng thái Cache, giao tiếp với Main Memory và FSM.

## 4. Các nội dung được kiểm thử

Testbench hiện có các tình huống sau:

- Reset hệ thống.
- Đọc một địa chỉ chưa có trong Cache (cold miss).
- Đọc lại địa chỉ vừa truy cập (hit).
- Đọc byte thứ hai trong cùng block.
- Tạo conflict miss bằng hai địa chỉ `0x00` và `0x08`.
- Đọc lại block đã bị thay thế.
- Nạp dữ liệu vào các set khác nhau.
- Ghi khi Cache hit và đọc lại dữ liệu mới.
- Kiểm tra dữ liệu được ghi xuống Main Memory theo write-through.
- Ghi khi Cache miss và kiểm tra no-write-allocate.
- Kiểm tra dữ liệu sau khi refill.
- Theo dõi các trạng thái FSM.

Danh sách chi tiết nằm trong `Integration_Test_Cases.csv`.

## 5. Kết quả dự kiến

Với chuỗi truy cập hiện tại trong Testbench, kết quả dự kiến là:

- Tổng số truy cập: 23
- Hit: 13
- Miss: 10
- Hit rate: 56.52%

Đây là số liệu tính theo chuỗi test và cấu hình RTL hiện tại, chưa phải kết quả chạy ModelSim. Chỉ ghi nhận kiểm thử thành công khi Transcript thực tế hiển thị `OVERALL RESULT = ALL TESTS PASSED` và các giá trị Hit/Miss đúng như mong đợi.

## 6. Một số lưu ý

- Testbench được viết theo phiên bản `cache_top.v` và các module RTL đi kèm trong project này. Nếu nhóm thay đổi tên cổng hoặc tên instance, cần cập nhật lại Testbench và file `.do`.
- Testbench theo dõi FSM qua đường dẫn `dut.controller_inst.state`. Nếu instance hoặc tên biến trạng thái thay đổi, cần sửa đường dẫn này.
- Tín hiệu `cache_hit` và `cache_miss` được ghi nhận trong lúc giao dịch diễn ra; không chỉ kiểm tra tại thời điểm `cpu_ready`.
- Giá trị dữ liệu mong đợi dựa trên cách Main Memory khởi tạo `memory[i] = i` và chính sách write-through.
- `trigger_detector.sv` và `cache_storage.v` từ các bản trước không được Top hiện tại gọi trực tiếp nên không nằm trong bài Integration Test này.

## 7. Khi gặp lỗi

- Nếu báo không tìm thấy module, kiểm tra file RTL đã nằm trong thư mục `rtl` và đã được compile chưa.
- Nếu báo sai tên cổng, đối chiếu danh sách port trong `cache_top.v`.
- Nếu Testbench timeout, kiểm tra giao thức `cpu_req`/`cpu_ready` và phản hồi `mem_ready`.
- Nếu Hit/Miss hoặc dữ liệu không đúng, lưu Transcript và Wave để xác định tín hiệu sai. Không sửa kết quả mong đợi chỉ để Testbench báo PASS.

## 8. Trạng thái xác minh

Các file đã được chuẩn bị dựa trên source RTL nhóm gửi. Bộ Testbench này chưa được chạy xác nhận bằng ModelSim trong môi trường tạo file. Cần chạy `run_cache.do` trên máy có ModelSim, sau đó lưu Transcript và Wave vào thư mục Evidence để ghi nhận kết quả thực tế.
