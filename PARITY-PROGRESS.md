# Papercraft Parity — Kế hoạch & Tiến trình

> File theo dõi nội bộ cho công cuộc học hỏi từ 2 dự án papercraft mã nguồn mở và nâng cấp
> 4H-Unfolder. Cập nhật mỗi khi hoàn thành một hạng mục.
> Cập nhật gần nhất: **2026-07-22**.

## Nguồn tham chiếu

| App | Stack | Định vị | Điểm mạnh học hỏi |
|-----|-------|---------|-------------------|
| [rodrigorc/papercraft](https://github.com/rodrigorc/papercraft) | Rust | Full-featured (tương đương Pepakura) | 3 chế độ Edge/Flap/Face tương tác, repack, undo, mountain/valley, edge labels, overlap highlight, multi-format export |
| [osresearch/papercraft](https://github.com/osresearch/papercraft) | C | CLI, hướng laser-cut | Gộp tam giác đồng phẳng, chọn/random start face, wireframe connector cho mô hình lớn |

**Phát hiện nền tảng:** bảng tech-debt trong `CLAUDE.md` đã lỗi thời — TD-38-1 (Outline Padding,
Clipper2) và TD-38-2 (Merge Flaps) **đã hoàn thành trên Windows** từ trước. Luôn kiểm tra code thực
tế trước khi tin bảng đó.

---

## Trạng thái tổng quan các giai đoạn

| Giai đoạn | Nội dung | macOS | Windows |
|-----------|----------|:-----:|:-------:|
| **GĐ 1** | Chất lượng pattern: flap-merge, outline-padding, coplanar-hide | 🟡 Gần xong | ✅ Xong |
| **GĐ 2** | Hỗ trợ lắp ráp: mountain/valley*, edge-matching labels | 🚧 Đang làm | 🚧 Đang làm |
| **GĐ 3** | Layout & tương tác: repack, multi-seed start face, chế độ Edge/Face | ⬜ Chưa | ⬜ Chưa |
| **GĐ 4** | Tiện ích I/O: PNG/trang, layer máy cắt | ⬜ Chưa | ⬜ Chưa |

\* Mountain/valley và Undo/Redo: **đã có sẵn** cả 2 nền tảng (người dùng xác nhận) → loại khỏi phạm vi GĐ2.

Chú thích: ✅ xong · 🟡 một phần · ⬜ chưa bắt đầu

---

## Giai đoạn 1 — Chất lượng pattern ✅🟡

Mục tiêu: pattern sạch hơn, lấp đúng tech-debt hình học.

### 1.1 Coplanar face merge → ẩn nét gấp đồng phẳng (bài học osresearch)
Ẩn nét gấp giữa hai mặt gần đồng phẳng (dihedral < ngưỡng), cho pattern sạch với quad
fan-triangulated.

| Hạng mục | Trạng thái |
|----------|-----------|
| Setting `HideCoplanarFolds` + `CoplanarAngleDeg` (mặc định 1°) — Windows | ✅ |
| Setting `hideCoplanarFolds` + `coplanarAngleDeg` — macOS | ✅ |
| Windows: áp trong `SvgExporter`, `PdfExporter`, `PatternCanvasControl` | ✅ |
| macOS: áp trong `SVGExporter` + `PatternCanvasView` | ✅ |
| UI toggle: `SettingsDialog.xaml` (Win) + `PreferencesView` (mac) | ✅ |
| Unit test: `SvgCoplanarFoldTests.cs` (Win, 2 test) | ✅ |

> Lưu ý convention: Windows lưu dihedral cho **mọi** cạnh (present-and-<threshold = coplanar);
> Swift engine **bỏ** cạnh ≤1° khỏi `edgeDihedralAngles` (absent = coplanar).

### 1.2 Merge adjacent flaps (union tab kề nhau)
| Hạng mục | Trạng thái |
|----------|-----------|
| Windows `FlapMerger.cs` (Clipper2) — có sẵn | ✅ |
| macOS `FlapMerger.swift` — port, không dùng Clipper | ✅ |
| macOS `ConvexPolygonUnion.swift` — union 2 đa giác lồi (half-plane clip + stitch) | ✅ |
| `GlueTab.mergedPolygon` (mac) | ✅ |
| Wire vào `UnfoldService` (mac), gate bằng `mergeAdjacentFlaps` | ✅ |
| UI toggle (mac Preferences) | ✅ |
| Test `FlapMergerTests.swift` (validate qua swiftc runner 7/7) | ✅ |

### 1.3 Outline padding (seam allowance)
| Hạng mục | Trạng thái |
|----------|-----------|
| Windows `OutlinePaddingGenerator.cs` (Clipper2) + wired export/canvas — có sẵn | ✅ |
| macOS `PolygonOffset.swift` — inflate round-join, không Clipper | ✅ |
| macOS: **consume trong SVG export/canvas** | 🟥 **Deferred** — cần per-piece boundary extraction (Windows đã có, Swift chưa). Chưa show UI control để tránh no-op. |

### Ghi chú kỹ thuật GĐ1 (macOS)
- `PrintSettings` được thêm **tolerant `init(from:)`**: synthesized Decodable ném lỗi khi thiếu key,
  mà `AppSettings.load()` dùng `try?` → sẽ **xoá sạch settings** người dùng khi thêm field. Field mới
  phải khai báo trong decoder này.
- `PolygonOffset` chỉ join cục bộ (round góc lồi + miter góc lõm), **không** cleanup self-intersection
  toàn cục như Clipper — đủ cho padding nhỏ; Windows vẫn là bản tham chiếu.

---

## Giai đoạn 2 — Hỗ trợ lắp ráp 🚧

### 2.1 Edge-matching labels

**Khảo sát hiện trạng (2026-07-22) — kế hoạch ban đầu đã sai:** cả 2 nền tảng thực ra **đã có** cơ
chế đánh số cặp cạnh (`CutEdgePairIds`/`cutEdgePairIds`, tính sẵn trong `UnfoldResult`). Việc thật
còn thiếu là:

| Hạng mục | macOS | Windows |
|----------|:-----:|:-------:|
| Canvas: vẽ số cặp cạnh | ✅ có sẵn (`drawCutLabels`) nhưng **luôn bật, không theo setting** | ✅ có sẵn, đúng gate `View2D.ShowEdgeIds` |
| Export SVG: vẽ số cặp cạnh | ✅ có sẵn nhưng **luôn bật, không có toggle riêng cho export** | ❌ **chưa có** |
| Export PDF: vẽ số cặp cạnh | (không có PDF exporter riêng trên mac) | ❌ **chưa có** |
| Setting `showEdgeIds` (view) | Khai báo sẵn (`View2DSettings`, default `false`) nhưng **chưa wire vào canvas** — dead setting | ✅ hoạt động đúng |
| Setting cho export riêng | ❌ chưa có | ❌ chưa có |

Việc triển khai:
- Windows: thêm `PrintSettings.IncludeEdgeLabels` (opt-in, default `false`) + render trong
  `SvgExporter`/`PdfExporter` + toggle trong `SettingsDialog.xaml`.
- macOS: wire `v2d.showEdgeIds` vào canvas (đổi default → `true` để giữ nguyên hành vi hiển thị hiện
  tại, tránh regression); thêm `PrintSettings.includeEdgeLabels` (default `true`, giữ hành vi export
  hiện tại) để gate SVG; thêm 2 toggle vào Preferences.

### 2.2 Mountain/valley fold
Đã có sẵn cả 2 nền tảng (người dùng xác nhận) → chỉ rà soát tùy chọn kiểu nét (liền/đứt) nếu cần,
không phải việc bắt buộc của GĐ2.

---

## Giai đoạn 3 — Layout & tương tác ⬜

- **3.1 Repack pieces:** bin-packing (shelf/MaxRects) → nút "Auto-arrange", giảm số trang.
- **3.2 Multi-seed start face:** thử nhiều face khởi đầu, chọn layout ít overlap nhất (osresearch).
- **3.3 Chế độ Edge/Face tương tác:** click cạnh cắt/nối, kéo/xoay piece trên canvas 2D
  (rodrigorc). Hạng mục lớn — tách task riêng.

---

## Giai đoạn 4 — Tiện ích I/O ⬜

- **4.1 Export PNG/trang** + layer riêng (cut/fold/label) cho máy cắt (Cricut/laser).
- **4.2** (Undo/Redo, reload-giữ-unwrap): Undo/Redo đã có sẵn → cân nhắc reload-model.

### Ngách (cân nhắc sau)
- Wireframe connector generator (osresearch) — sinh khớp nối in-3D cho mô hình lớn; khác định vị paper.

---

## Nhật ký triển khai

| Ngày | Việc | Kết quả kiểm chứng |
|------|------|--------------------|
| 2026-07-21 | GĐ1 macOS: FlapMerger + ConvexPolygonUnion + PolygonOffset + coplanar-hide + tolerant settings | `swift build` ✅ · geometry swiftc runner **7/7** ✅ |
| 2026-07-21 | GĐ1 Windows: coplanar-hide (exporters, canvas, settings, XAML) | net8.0 libs build ✅ · WPF compile (`EnableWindowsTargeting`) ✅ · **97/97** tests ✅ |
| 2026-07-21 | Merge: `feat/parity-papercraft-phase1` → `docs/wiki` (#53) → `main` (#54) | — |

### Lưu ý môi trường verify (máy Darwin)
- WPF App **không chạy runtime** được trên macOS (`NETSDK1100`) — dùng `-p:EnableWindowsTargeting=true`
  để compile-check C#/XAML. Hành vi runtime WPF **cần verify trên Windows thật**.
- .NET test cần `DOTNET_ROLL_FORWARD=Major` (chỉ có runtime 10.x; project target net8.0).
- Swift XCTest **không** chạy từ CLI (`swift test` → thiếu module XCTest). Validate hình học bằng
  standalone `swiftc` runner; test XCTest chạy trong Xcode.
