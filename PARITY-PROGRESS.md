# Papercraft Parity — Kế hoạch & Tiến trình

> File theo dõi nội bộ cho công cuộc học hỏi từ 2 dự án papercraft mã nguồn mở và nâng cấp
> 4H-Unfolder. Cập nhật mỗi khi hoàn thành một hạng mục.
> Cập nhật gần nhất: **2026-07-22** (đang fix 3 finding từ cross-review GĐ1+GĐ2).

## Cross-review GĐ1+GĐ2 (2026-07-22) — 3 finding đang fix

Sau khi merge PR #57, review lại toàn bộ coplanar-hide (GĐ1) + edge-labels (GĐ2) một cách hoài
nghi (không tin vào test cũ), phát hiện 3 vấn đề thật, đều xoay quanh coplanar-hide — không do GĐ2
gây ra, sót từ GĐ1:

| # | Nền tảng | Vấn đề | File |
|---|----------|--------|------|
| 1 | Windows | `HideCoplanarFolds` **vô hiệu lặng lẽ** với model import PDO — `TryBuildFromPdoLayout` không truyền `dihedralAngles` vào `UnfoldResult` (dict rỗng → check luôn fail) | `UnfoldService.cs:129` |
| 2 | Windows | `CoplanarAngleDeg` **không có control UI** — chỉ có checkbox bật/tắt, ngưỡng khoá cứng 1.0° dù ViewModel hỗ trợ đủ | `SettingsDialog.xaml:702` |
| 3 | macOS | `coplanarAngleDeg` do user đặt < 1° bị `UnfoldEngine`'s hardcoded cutoff (`angleDeg > 1`, dùng để loại bỏ nhãn góc gấp giả trên đường chéo fan-triangulation) ghi đè âm thầm | `UnfoldEngine.swift:35` |

Đang fix cả 3, xem chi tiết cách fix + kết quả kiểm chứng bên dưới sau khi hoàn thành.

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
| **GĐ 2** | Hỗ trợ lắp ráp: mountain/valley*, edge-matching labels | ✅ Xong | ✅ Xong |
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

## Giai đoạn 2 — Hỗ trợ lắp ráp ✅

### 2.1 Edge-matching labels

**Khảo sát hiện trạng (2026-07-22) — kế hoạch ban đầu đã sai:** cả 2 nền tảng thực ra **đã có** cơ
chế đánh số cặp cạnh (`CutEdgePairIds`/`cutEdgePairIds`, tính sẵn trong `UnfoldResult`). Việc thật
còn thiếu (và nay **đã hoàn thành**) là:

| Hạng mục | macOS | Windows |
|----------|:-----:|:-------:|
| Canvas: vẽ số cặp cạnh | ✅ có sẵn (`drawCutLabels`), **nay đã wire theo `v2d.showEdgeIds`** | ✅ có sẵn, đúng gate `View2D.ShowEdgeIds` |
| Export SVG: vẽ số cặp cạnh | ✅ có sẵn, **nay gate bằng `includeEdgeLabels`** | ✅ **mới thêm** (`IncludeEdgeLabels`) |
| Export PDF: vẽ số cặp cạnh | ✅ **mới gate** bằng `includeEdgeLabels` (exporter đã có sẵn, thiếu gate) | ✅ **mới thêm** (`IncludeEdgeLabels`) |
| Setting view (canvas) | `showEdgeIds` đổi default `false→true` (giữ nguyên hành vi hiện tại), **wire vào canvas** | `ShowEdgeIds` đã đúng, không đổi |
| Setting export (print) | `includeEdgeLabels` **mới** (default `true`, giữ hành vi export hiện tại) | `IncludeEdgeLabels` **mới** (default `false`, opt-in — khớp `MergeAdjacentFlaps`/`HideCoplanarFolds`) |

**Phát hiện phụ khi làm (GĐ1 gap, đã fix luôn):** macOS `PDFExporter.swift` — một exporter PDF
riêng (Core Graphics) song song với `SVGExporter.swift` mà lần trước không rà tới — **hoàn toàn
thiếu coplanar-hide** dù GĐ1 đã làm việc này cho canvas + SVG. Đã fix: gọi lại
`SVGExporter.isCoplanarFold(...)` (dùng chung logic, không lặp code) trong vòng lặp fold-edge của
`PDFExporter`.

Việc đã làm:
- **Windows:** `PrintSettings.IncludeEdgeLabels` (opt-in) + render `<text class="pairlabel">` trong
  `SvgExporter` + `gfx.DrawString` trong `PdfExporter` + checkbox `SettingsDialog.xaml` +
  `SettingsViewModel` load/save. Test mới: `SvgEdgeLabelTests.cs` (3 test).
- **macOS:** wire `v2d.showEdgeIds` vào `drawCutLabels` (canvas); `PrintSettings.includeEdgeLabels`
  (+ tolerant decoder) gate cả `SVGExporter` và `PDFExporter`; fix coplanar-hide thiếu trong
  `PDFExporter`; 2 toggle Preferences ("Show Edge IDs", "Include Edge-Matching Labels"). Test mới:
  `EdgeLabelAndCoplanarExportTests.swift` (6 test).

> **Bài học xác thực (2026-07-22):** CI thật (GitHub Actions, Xcode) chạy `swift test` đầu tiên đã
> **fail 1/103 test** — `testSVG_nonCoplanarFold_notHidden`. Nguyên nhân: test tự viết dùng nhầm
> convention `class="fold"` (kiểu Windows SvgExporter) trong khi macOS `SVGExporter` thực ra render
> fold-line bằng thuộc tính inline `stroke="<hex>"`, không có CSS class. Đây là **lỗi trong test**,
> không phải lỗi sản phẩm — code coplanar-hide/PDFExporter vẫn đúng (3 test PDF liên quan đã pass
> ngay từ đầu). Đã sửa 2 assertion dùng đúng `stroke="..."`, re-push, **CI xanh hoàn toàn** (macOS +
> Windows) trước khi merge. **Rút kinh nghiệm:** `swiftc -typecheck` qua shim (xem mục môi trường
> verify) chỉ chứng minh code *biên dịch được*, không chứng minh assertion đúng với output thật —
> không thể thay thế việc chạy suite thật; luôn cần CI (hoặc Xcode) xác nhận trước khi merge.

### 2.2 Mountain/valley fold
Đã có sẵn cả 2 nền tảng (người dùng xác nhận) → không phải việc của GĐ2, không đụng vào.

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
| 2026-07-21 | `docs/parity-progress`: thêm file tiến trình này | Merge #55 → `main` |
| 2026-07-22 | GĐ2 Windows: `IncludeEdgeLabels` (SvgExporter/PdfExporter/SettingsVM/XAML) | net8.0 libs + WPF compile ✅ · **100/100** tests ✅ (97 cũ + 3 mới) |
| 2026-07-22 | GĐ2 macOS: wire `showEdgeIds` (canvas) + `includeEdgeLabels` (SVG+PDF gate) + fix PDFExporter coplanar-hide gap (GĐ1 sót) + 2 Preferences toggle | `swift build` ✅ · type-check qua shim (không phát hiện được lỗi assertion — xem bài học bên dưới) |
| 2026-07-22 | CI thật (GitHub Actions) chạy PR #57: macOS FAIL 1/103 (`class="fold"` sai convention) → sửa 2 assertion → re-push → **CI xanh macOS+Windows** | `gh run watch` ✅ cả 2 job |
| 2026-07-22 | Merge PR #57 (`feat/parity-phase2-edge-labels`) → `main` | — |

### Lưu ý môi trường verify (máy Darwin)
- WPF App **không chạy runtime** được trên macOS (`NETSDK1100`) — dùng `-p:EnableWindowsTargeting=true`
  để compile-check C#/XAML. Hành vi runtime WPF **cần verify trên Windows thật**.
- .NET test cần `DOTNET_ROLL_FORWARD=Major` (chỉ có runtime 10.x; project target net8.0).
- Swift XCTest **không** chạy từ CLI (`swift test` → thiếu module XCTest). Validate hình học bằng
  standalone `swiftc` runner; test XCTest chạy trong Xcode.
- Để tối thiểu xác thực một file `XCTestCase` thật (không chỉ hình học thuần) khi không chạy được
  Xcode: viết một shim module tối giản định nghĩa `XCTestCase`/`XCTAssert*` cùng chữ ký, build bằng
  `swiftc -emit-module -module-name XCTest`, rồi `swiftc -typecheck -I <FourHUnfolderCore
  swiftmodule dir> -I <shim dir> <test file>`. Bắt được lỗi kiểu/cú pháp thật (đã tự kiểm chứng bằng
  cách cố tình chèn lỗi kiểu và xác nhận trình biên dịch báo lỗi) mà không cần chạy assertion thật.
