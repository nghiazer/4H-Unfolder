# Papercraft Parity — Kế hoạch & Tiến trình

> File theo dõi nội bộ cho công cuộc học hỏi từ 2 dự án papercraft mã nguồn mở và nâng cấp
> 4H-Unfolder. Cập nhật mỗi khi hoàn thành một hạng mục.
> Cập nhật gần nhất: **2026-07-24** (GĐ3.3 hoàn thành: join connected cut edges + align pieces cho macOS — Windows đã có sẵn).

## Cross-review GĐ1+GĐ2 (2026-07-22) — đã fix

Sau khi merge PR #57, review lại toàn bộ coplanar-hide (GĐ1) + edge-labels (GĐ2) một cách hoài
nghi (không tin vào test cũ), phát hiện 3 vấn đề thật, đều xoay quanh coplanar-hide — không do GĐ2
gây ra, sót từ GĐ1. Cách fix + finding phụ phát hiện thêm khi viết test cho fix:

| # | Nền tảng | Vấn đề | Cách fix |
|---|----------|--------|----------|
| 1 | Windows | `HideCoplanarFolds` **vô hiệu lặng lẽ** với model import PDO — `TryBuildFromPdoLayout` không truyền `dihedralAngles` vào `UnfoldResult` (dict rỗng → check luôn fail) | `UnfoldService.cs`: build lại dual graph (`_graphBuilder.Build(mesh)`, thuần hình học, không phụ thuộc fold/cut) trong `TryBuildFromPdoLayout`, populate `dihedralAngles` giống path chính |
| 1b | Windows | **Root cause sâu hơn, lộ ra khi viết test cho fix #1:** `PdoUnfoldBuilder.Build()` chưa bao giờ truyền `meshEdgeIds` cho `UnfoldedFace` → mọi face từ PDO có `MeshEdgeIds = [-1,-1,-1]` → **cả coplanar-hide LẪN edge-labels (GĐ2) đều vô hiệu với PDO models**, bất kể fix #1 | `PdoUnfoldBuilder.cs`: thêm mảng `meshEdgeIds` từ `meshFace.EdgeIds`, truyền vào constructor |
| 2 | Windows | `CoplanarAngleDeg` **không có control UI** — chỉ có checkbox bật/tắt, ngưỡng khoá cứng 1.0° dù ViewModel hỗ trợ đủ | Thêm Slider+TextBox trong `SettingsDialog.xaml` (row 11 mới, không đụng row khác) |
| 3 | macOS | `coplanarAngleDeg` do user đặt < 1° bị `UnfoldEngine`'s hardcoded cutoff (`angleDeg > 1`, dùng để loại bỏ nhãn góc gấp giả trên đường chéo fan-triangulation) ghi đè âm thầm | `SVGExporter.isCoplanarFold`: clamp ngưỡng hiệu lực `max(1.0, coplanarAngleDeg)` — không đụng `UnfoldEngine` (tránh phá `testCube_dihedralAngles_allNinety` vốn dựa vào cutoff này) + caption UX trong Preferences |

**Bài học lặp lại:** viết test THẬT (không phải hand-built `UnfoldResult` bỏ qua pipeline) cho fix #1 đã
**tự bắt được finding 1b** ngay khi chạy — nếu chỉ test qua `SvgExporter` với `UnfoldedFace` tự dựng
(như cách viết test GĐ2 trước đó), sẽ không bao giờ lộ ra vì `meshEdgeIds` tự dựng luôn hợp lệ. Luôn
đi qua đúng pipeline thật (`UnfoldService`/`PdoUnfoldBuilder`) khi test một code path cụ thể.

Kiểm chứng: Windows **104/104 test** (100 cũ + 3 mới `UnfoldServicePdoDihedralTests.cs` + 1 mới
`PdoUnfoldBuilderTests.cs`), build 0 lỗi (`EnableWindowsTargeting`). macOS: build ✅, 4 test mới
trong `EdgeLabelAndCoplanarExportTests.swift`, mỗi assertion đã tự tay trace tay khớp với
implementation thật trước khi tin — **chờ CI thật (Xcode) xác nhận trước khi merge**, không lặp lại
sai lầm tin vào typecheck-only như lần GĐ2.

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
| **GĐ 3** | Layout & tương tác: repack, MST tie-break retry, chế độ Edge/Face | ✅ Xong (3.1+3.2+3.3) | ✅ Xong (3.2; 3.3 vốn đã có sẵn) |
| **GĐ 4** | Tiện ích I/O: PNG/trang, layer máy cắt | ✅ Xong | ✅ Xong |

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

## Cross-review GĐ3 (2026-07-22) — đã fix

Sau khi merge PR #59, review lại kỹ toàn bộ 3.1+3.2 một cách hoài nghi. Kiểm tra `OverlapDetector`,
`KruskalMstBuilder`/`KruskalMSTBuilder`, `UnfoldService` orchestrator, và phần xoay 90° macOS
(bằng đại số: ma trận biến đổi có định thức +1 → đúng là phép quay, không phải phản chiếu; `UV`
không bị biến đổi theo giấy; `mergedPolygon` từ `FlapMerger` cũng được map đúng) — không thấy bug.

**1 finding nghiêm trọng, xác nhận bằng thực nghiệm:** cơ chế tie-break retry (3.2) so sánh **bằng
tuyệt đối bit-for-bit** giữa các giá trị góc dihedral (float). Dựng thử một mesh bất đối xứng 176
cạnh (mô phỏng model thực tế — scan/sculpt, không đối xứng cố ý) và đo được **0 cặp cạnh trùng
trọng số tuyệt đối**. Nghĩa là: với đa số model thực tế, cả 8 seed thử lại cho ra **y hệt** MST gốc
— không có tác dụng gì — nhưng `Unfold()`/`.unfold()` vẫn chạy lại toàn bộ pipeline 9 lần mỗi khi có
overlap, và vòng lặp chỉ dừng sớm khi đạt đúng 0 overlap (không phải "đủ tốt"), nên với mesh có
overlap không thể tránh khỏi, chi phí 9x này lặp lại **mãi mãi ở mỗi lần chỉnh sửa** (`Unfold()` gọi
lại trên mọi edit, không chỉ lúc load) trên cả 2 nền tảng.

### Fix: epsilon-based near-tie perturbation + skip-check

**Hiệu chỉnh epsilon bằng thực nghiệm** (không đoán suông): thử mesh ngẫu nhiên 176 cạnh với nhiều
mức epsilon — đếm "gap gần" (giữa các trọng số liền kề sau sort) rất dễ gây hiểu lầm (ở epsilon=1°,
162/175 gap được coi "gần" — tưởng như quá rộng), nhưng đo trực tiếp **MST thực sự đổi bao nhiêu**
mới là chỉ số đúng: ở epsilon=1° chỉ 5/20 seed cho MST khác nhau, độ lệch tổng trọng số so với MST
thật chỉ 0.745° trên tổng 32.75 rad (~0.02%) — biến động thật nhỏ, đủ để có ích, không đủ để làm
lệch nghiêm trọng khỏi heuristic "ưu tiên cạnh phẳng nhất". Chốt **epsilon = 1°** (khớp
`CoplanarAngleDeg` đã có sẵn trong codebase).

| Thay đổi | Windows | macOS |
|----------|---------|-------|
| Tie-break: exact-equality `ThenBy` → epsilon-perturbation | `KruskalMstBuilder.TieEpsilonRad` (public const, 1°) + `TieBreakOffset` cộng dồn vào trọng số trước khi sort, giới hạn sao cho chỉ 2 cạnh lệch <epsilon mới có thể đổi thứ tự | `KruskalMSTBuilder.tieEpsilonRad` + `tieBreakOffset` tương tự |
| Skip-check khi vô vọng | `KruskalMstBuilder.HasPotentialTies(graph)` — kiểm tra có cặp cạnh nào lệch <epsilon không, dùng để `Unfold()` bỏ qua toàn bộ vòng lặp retry khi provably futile | `KruskalMSTBuilder.hasPotentialTies(graph:)` tương tự |
| Wiring | `UnfoldOnce` giờ trả thêm `DualGraph` (không rebuild thừa) để `Unfold()` gọi `HasPotentialTies` trước khi vào loop | `unfoldOnce` trả thêm `DualGraph` tương tự |

**Chứng minh cận an toàn:** với perturbation giới hạn trong `[-0.5·eps, +0.5·eps]`, hai cạnh chỉ có
thể đổi thứ tự tương đối khi hiệu trọng số thật của chúng **nhỏ hơn epsilon** — cạnh có hiệu >epsilon
không bao giờ bị ảnh hưởng bởi seed, có test riêng khẳng định (`TieBreakSeed_NeverAffectsWellSeparatedWeights`).

Kiểm chứng: Windows **121/121 test** (115 cũ + 6 mới: near-tie MST variation, well-separated
invariant, `HasPotentialTies` ×4), build 0 lỗi (`EnableWindowsTargeting`). macOS: `swift build` ✅
(Core+App), test mới type-check sạch qua shim + mỗi assertion đã tự tay trace khớp implementation
thật — chờ CI thật xác nhận trước khi merge.

---

## Giai đoạn 3 — Layout & tương tác ✅ (3.1+3.2+3.3)

**Khảo sát hiện trạng (2026-07-22) — kế hoạch ban đầu lại sai:** giống GĐ1/GĐ2, hoá ra phần lớn đã
có sẵn hoặc cần diễn giải lại cho đúng kiến trúc thực tế.

### 3.1 Repack pieces
**Đã có sẵn cả 2 nền tảng** trước phiên này — Windows `MainViewModel.RunAutoArrange()`, macOS
`AppState.autoArrange()`, cả hai là First-Fit-Decreasing shelf packing (sort theo diện tích giảm
dần, xếp theo hàng/trang). Gap duy nhất: Windows thử xoay 90° từng piece để giảm lãng phí giấy,
macOS thì không.

**Đã làm:** thêm thử xoay 90° vào macOS `autoArrange()` (mirror điều kiện Windows: chỉ xoay khi
piece đang rộng hơn cao VÀ cả hai chiều sau xoay vẫn vừa trang). **Khác biệt kiến trúc quan trọng**
phát hiện khi làm: Windows lưu geometry piece ở toạ độ **local** (`piece.Faces` chưa xoay/dịch),
rotate+translate áp dụng riêng lúc render (`RotateTransform`) và lúc export (`BuildExportLayout`).
macOS `autoArrange()` thì bake thẳng toạ độ **tuyệt đối** vào `result.faces`/`result.tabs` ngay khi
chạy — không có khái niệm "local piece space" tách biệt. Vì vậy macOS phải tự xoay vertex trực tiếp
(không thể chỉ set một `pieceRotations[i] = 90` và để render lo phần còn lại, vì export đọc thẳng
`result.faces` chứ không áp dụng `pieceRotations` overlay). Tách phần toán xoay thuần
(`rotated90InLocalBBox`) vào `FourHUnfolderCore/Core/Math/SIMDExtensions.swift` để test được — vì
`AppState.swift` nằm ở App target mà test target không phụ thuộc vào.

### 3.2 Multi-seed start face → re-scope thành "MST tie-break retry"
Ý tưởng gốc từ osresearch (thử nhiều face khởi đầu BFS, giữ layout ít overlap nhất) **không áp dụng
được** trực tiếp: ở osresearch, BFS greedy quyết định fold/cut *ngay khi duyệt* nên đổi start face →
đổi hình dạng piece → có thể đổi overlap. Ở 4H-Unfolder, fold/cut được quyết định **trước** bởi
Kruskal MST (trọng số = góc dihedral), độc lập với face khởi đầu của bước BFS unfold — đổi start
face chỉ đổi vị trí/hướng piece trên giấy, không đổi hình dạng hay overlap.

**Đòn bẩy thật đã triển khai:** khi Kruskal gặp nhiều cạnh **cùng trọng số** (ties), thêm tham số
`tieBreakSeed`/`tieBreakSeed:` phá tie bằng hash `(edgeId, seed)` — `null`/`nil` giữ nguyên hành vi
gốc (thứ tự edge-id tự nhiên, deterministic, khớp 100% hành vi cũ). `UnfoldService.Unfold`/`.unfold`
giờ là hàm điều phối: chạy baseline (seed=null) trước; nếu `HasOverlaps`, thử tối đa `seedCount`
(mặc định 8) seed khác nhau, giữ lại kết quả có `CountOverlaps` (mới, đếm toàn bộ cặp overlap thay
vì chỉ bool) thấp nhất. **Miễn phí khi không cần** — model không overlap thì không tốn thêm chi phí
nào (giống thiết kế "chỉ chạy khi cần" ở fix PDO của GĐ2-cross-review).

**Rủi ro kỹ thuật đã lường trước và fix:** `EdgeMarker.Mark()`/`.mark()` **mutate trực tiếp**
`mesh.Edges[].Type` — nếu chạy nhiều seed trên cùng 1 mesh, phải đảm bảo mesh được đánh dấu lại theo
seed **thắng cuộc**, không phải seed thử cuối cùng trong vòng lặp (vì `MainViewModel.IsEdgeFold`/
canvas đọc trực tiếp `mesh.Edges[id].Type`, và macOS `PieceComputer` cũng đọc `mesh.edges[].type`).
Fix: refactor `Unfold`/`unfold` thành hàm điều phối gọi `UnfoldOnce`/`unfoldOnce` (helper riêng cho
1 lần thử, trả về cả `foldEdgeIds` đã dùng) nhiều lần, rồi **re-mark mesh lần cuối** theo fold-set
của kết quả thắng cuộc trước khi return — có unit test riêng khẳng định invariant này
(`Unfold_MeshEdgeTypes_AreConsistentWithReturnedFoldFlags` / `testUnfold_meshEdgeTypes_...`).

**Giới hạn kiểm chứng đã ghi nhận trung thực:** không xây được 1 mesh thật chứng minh "seed X sửa
được overlap thật" một cách xác định (constructing đòi hỏi hình học bất đối xứng phức tạp, không
đáng effort). Thay vào đó test ở 2 tầng: (1) 2 primitive mới (`tieBreakSeed`, `CountOverlaps`) test
kỹ ở mức đơn vị — chứng minh cơ chế hoạt động đúng; (2) tầng `UnfoldService` test các thuộc tính an
toàn tổng quát (baseline không đổi khi không overlap, mesh-marking nhất quán, determinism) — không
test riêng "có thực sự giảm overlap cho 1 mesh cụ thể hay không".

### 3.3 Chế độ Edge/Face tương tác (rodrigorc-style)

**Khảo sát lại (2026-07-24) — kế hoạch gốc "hạng mục lớn" hoá ra sai, giống mọi giai đoạn trước:**
đào sâu code thực tế thấy rodrigorc's 3-mode system (Edge/Flap/Face-rotate) **đã tồn tại trên cả 2
nền tảng**, chỉ khác kiến trúc — macOS qua `CanvasMode` enum (`.editEdge`/`.editFlap`/`.rotatePivot`),
Windows qua các flag riêng (`_editModeActive`, `_flapEditActive` + `EditFlapsDialog` non-modal,
"Rotate-by-Point ⊙"). Không cần xây gì mới cho phần lõi 3 chế độ.

Khoanh lại phạm vi thật của 3.3 xuống 2 gap cụ thể, đã có sẵn trên Windows, thiếu trên macOS (đã
track sẵn trong wiki Roadmap):

1. **Join connected cut edges** — Windows `MainViewModel.JoinEdgeGroup`/`FindAdjacentCutEdgeGroup`:
   BFS qua các cạnh cắt (cut) nối nhau bằng đỉnh 2D chung (epsilon=0.01²), gộp cả chuỗi thành Fold
   trong 1 thao tác thay vì từng cạnh một.
2. **Align pieces** — Windows `PatternCanvasControl.AlignSelected`/`PieceAabb`: căn chỉnh 6 hướng
   (Left/Right/CenterH/Top/Bottom/CenterV) cho các piece đang chọn, dựa trên AABB đã áp dụng
   rotation+offset hiện tại.

**macOS — đã port cả 2:**
- `FourHUnfolderCore/Core/Algorithms/EdgeGroupFinder.swift` (mới): port thuần của
  `FindAdjacentCutEdgeGroup` — BFS trên map `meshEdgeId → (vertexA, vertexB)` của mọi cạnh đang là
  cut (không fold, không boundary), nối 2 cạnh nếu có 1 cặp đỉnh gần nhau (khoảng cách bình phương
  < 0.01²).
- `AppState.joinEdgeGroup(_:)`: gọi `EdgeGroupFinder`, set toàn bộ group thành `.fold` trong
  `edgeOverrides`, re-unfold + auto-arrange. Trigger: **⌥-click** lên 1 cạnh cắt trong Edit-Edges
  mode (`PatternCanvasView.handleTap`) — khác Windows (menu chuột phải) vì canvas macOS vẽ toàn bộ
  cạnh vào 1 `Canvas` view qua hit-test thủ công, không có element rời cho từng cạnh để gắn context
  menu; modifier-click nhất quán với quy ước Shift-để-chọn-thêm đã có sẵn trên cùng canvas này.
  **Không làm smart anchor-reposition** (khác `joinEdge` 1-cạnh) — khớp hành vi Windows, cũng chỉ
  re-unfold phẳng cho trường hợp group.
- `PieceAligner.swift` (mới, `FourHUnfolderCore`): port thuần của `AlignSelected`/`PieceAabb` —
  tách hẳn ra khỏi `AppState` (không viết inline như draft đầu tiên) để unit-test được, theo đúng
  tiền lệ đã lập ở 3.1 (`rotated90InLocalBBox` trong `PieceRotationTests.swift`, vì `AppState.swift`
  nằm ở App executable target mà test target không phụ thuộc vào). `AppState.alignSelectedPieces`
  giờ chỉ là wrapper mỏng gọi `PieceAligner.alignmentDeltas(...)` rồi cộng dồn vào `pieceOffsets`.
  6 nút toolbar mới (Align Left/Right/CenterH/Top/Bottom/CenterV), disable khi < 2 piece được chọn.

**Phát hiện khi làm:** `pushUndo()`/`undo()` trên macOS chỉ snapshot `edgeOverrides`/`flapOverrides`,
**không** snapshot `pieceOffsets`/`pieceRotations` — xác nhận thao tác kéo piece thủ công hiện có
trong `PatternCanvasView` cũng chưa từng gọi `pushUndo()`. Bỏ lời gọi `pushUndo()` khỏi
`alignSelectedPieces` (draft đầu có gọi, gây hiểu nhầm là undo-able) thay vì tự ý mở rộng phạm vi
undo — giữ nhất quán với giới hạn có sẵn, ghi chú rõ trong code comment.

**Lỗi build nhỏ đã fix:** thiếu `import simd` trong `AppState.swift` — `SIMD2<Float>` là stdlib
nhưng `simd_min`/`simd_max` (dùng trong `effectiveAABB`) nằm ở module `simd` riêng.

**Kiểm chứng đã làm (không chỉ typecheck):**
- Viết script `swiftc`-linked độc lập (`@testable import FourHUnfolderCore`, link trực tiếp `.o` đã
  build) dựng mesh tổng hợp: 3 cạnh cắt nối chuỗi (100↔101↔102) + 1 cạnh cắt cô lập (200) cho
  `EdgeGroupFinder`; 2 piece với bbox biết trước cho `PieceAligner` (bao gồm test rotation 90°
  hoán đổi width/height, offset cộng dồn đúng, và tham chiếu align tính lại đúng khi 1 piece đã có
  offset sẵn) — **23/23 assertion thực thi thật đều pass** (không chỉ compile).
- `EdgeGroupFinderTests.swift` (5 test) + `PieceAlignerTests.swift` (12 test) mới, theo đúng convention
  `XCTestCase` như `EdgeLabelAndCoplanarExportTests.swift`/`SVGLayerTests.swift`.
- Type-check **toàn bộ** test suite (15 file, không chỉ file mới) qua XCTest shim tái tạo lại —
  sạch, không lỗi.
- Soát lại code mới tìm pattern `.contains { compoundBoolean && chain }` từng gây Swift compiler
  timeout thật trên CI ở GĐ4 (`PNGExporter.swift`) — không có; mọi `.contains` trong code mới đều
  là single-condition membership check đơn giản (`set.contains(x)`), không phải closure đa điều
  kiện với ép kiểu số ẩn.
- Windows: không cần thay đổi gì (đã có sẵn cả 2 tính năng từ trước) — không cần build/test lại.
- **Chờ CI thật (GitHub Actions, Xcode) xác nhận trước khi merge** — theo đúng quy trình bắt buộc
  đã rút ra từ GĐ2 và GĐ4 (typecheck/build cục bộ từng bỏ sót lỗi CI mới bắt được).

---

## Giai đoạn 4 — Tiện ích I/O ✅ (4.1; 4.2 bỏ qua có lý do)

### 4.1 Export PNG/trang + layer riêng (cut/fold/label) cho máy cắt

**Phát hiện kiến trúc quan trọng khi khảo sát:** Windows `SvgExporter` là **1 canvas SVG duy nhất**
(không chia trang) và dùng **CSS `<style>` class** (`class="fold"`) thay vì thuộc tính inline —
nhiều phần mềm máy cắt nhẹ (LightBurn, Cricut Design Space) **không chạy `<style>` CSS**, chỉ đọc
`stroke=`/`fill=` inline. macOS `SVGExporter` may đã dùng inline `stroke=` sẵn (không cần sửa phần
này). Cả 2 nền tảng đều **chưa** có group/layer nào cho cut/fold/label tách biệt.

**Đã làm — SVG layer (Inkscape-style `<g>` groups):**
| | Windows | macOS |
|---|---------|-------|
| `xmlns:inkscape=` trên `<svg>` root | ✅ | ✅ |
| `<g inkscape:groupmode="layer" inkscape:label="Fold Lines">` | ✅ | ✅ |
| `<g ... label="Cut Lines">` (gộp cut + boundary — cả 2 đều cần cắt vật lý) | ✅ | ✅ |
| `<g ... label="Glue Tabs">` / `label="Edge Labels"` | ✅ | ✅ |
| Inline `stroke="..."` thêm cạnh `class="..."` (fix tương thích parser nhẹ) | ✅ mới thêm | đã có sẵn từ trước |
| Giữ nguyên toàn bộ comment/class cũ | ✅ (không test nào phụ thuộc) | ✅ **bắt buộc** — 6+ test cũ (`SVGExporterTests`, `EdgeLabelAndCoplanarExportTests`) assert đúng string comment cũ, chỉ bọc thêm `<g>` xung quanh, không xoá gì |

**Đã làm — PNG export (1 file/trang):**
- **Windows:** `PngExporter.cs` — **không đặt trong `FourHUnfolder.Infrastructure`** (nơi
  `SvgExporter`/`PdfExporter` sống) mà đặt trong `FourHUnfolder.App/Services/`, vì cần
  `System.Windows.Media` (`DrawingVisual`+`RenderTargetBitmap`+`PngBitmapEncoder`) — chỉ có ở
  `net8.0-windows`+`UseWPF=true`; Infrastructure cố tình giữ `net8.0` thuần để build/test được trên
  máy không phải Windows (đã verify suốt session này). Mirror logic chia trang của `PdfExporter`
  (`pagesWide×pagesTall`, `pageSepMm`) nhưng vẽ bằng WPF, không Y-flip (WPF Y-down khớp model).
  Setting mới `PngDpi` (mặc định 300) trong `AppSettings.Print`. Wire vào `MainViewModel`
  (`ExportPngCommand`) + toolbar `MainWindow.xaml` + DI `App.xaml.cs`.
- **macOS:** `PNGExporter.swift` — dùng chung CoreGraphics với `PDFExporter.swift` (bitmap
  `CGContext` thay vì PDF context), **thêm mới** page-splitting (mac `PDFExporter` chỉ 1 trang, chưa
  từng có multi-page). Setting mới `pngDpi` (+ tolerant decoder). Wire vào `AppState.exportPNG()` +
  menu `App.swift` (⌘⇧P) + toolbar `MainView.swift`.

**Kiểm chứng bất đối xứng giữa 2 nền tảng (quan trọng, đã tự lường trước và xử lý):**
- **Windows:** thử thêm reference `FourHUnfolder.App` (WPF) vào test project portable → build FAIL
  ngay (`NETSDK1100`) — xác nhận bằng thực nghiệm, không đoán. Tệ hơn: dù có compile được qua
  `EnableWindowsTargeting`, **WPF không có runtime ngoài Windows** nên test cũng sẽ crash lúc chạy,
  không chỉ lúc build. → `PngExporterTests` **không đưa vào** test suite portable; chỉ compile-check
  qua App build (đã pass) + review logic tay cẩn thận. Output PNG thật cần verify trên Windows.
- **macOS:** CoreGraphics **chạy được thật** trên máy Darwin (không như WPF) → viết được script
  scratch gọi thẳng `PNGExporter.export(...)` qua `swiftc` (link trực tiếp `.o` đã build), **thực
  thi thật** (không chỉ typecheck): xác nhận đúng số file/trang, đúng tên file (`_p1`, `_p2`...),
  đúng kích thước pixel theo DPI (2480×3508 cho A4@300dpi), DPI cao hơn → ảnh lớn hơn, và **lấy mẫu
  pixel thật** xác nhận màu face-fill đúng như tính toán kỳ vọng (blend alpha đúng công thức) — phát
  hiện 1 bug trong chính script test (double Y-flip) khi mới viết, tự sửa và xác nhận lại bằng cách
  quét cột pixel để suy ra đúng chiều buffer bộ nhớ trước khi tin kết quả.

Kiểm chứng: Windows **127/127 test** (121 cũ + 6 mới, tất cả trong `SvgLayerTests` — `PngExporter`
không có unit test trong suite portable vì lý do đã giải thích ở trên, chỉ compile-check qua App
build), build 0 lỗi (`EnableWindowsTargeting`). macOS: `swift build` ✅ (Core+App), **type-check
sạch toàn bộ test suite** (lần đầu chạy full-suite, không chỉ file lẻ — bắt được 2 lỗ hổng trong
shim XCTest tự chế: thiếu `accuracy:` overload và thiếu re-export `Foundation`, đã vá), + verify
thật bằng `swiftc` execution (18 check tổng, tất cả pass) cho cả PNGExporter lẫn SVGLayer.

### 4.2 — bỏ qua có lý do
Undo/Redo đã có sẵn từ trước (không phải việc GĐ4). "Reload model giữ nguyên unwrap" **cố tình bỏ
qua**: ánh xạ trạng thái unwrap cũ sang mesh mới (có thể khác topology hoàn toàn) không có định
nghĩa rõ ràng — làm nửa vời còn tệ hơn không làm. Không tương đương "cân nhắc" trong bản kế hoạch
gốc; ghi nhận quyết định rõ ràng thay vì lặng lẽ bỏ qua.

### Ngách (cân nhắc sau)
- Wireframe connector generator (osresearch) — sinh khớp nối in-3D cho mô hình lớn; khác định vị paper.

---

## Cross-review GĐ3.3 + GĐ4 (2026-07-24) — đã fix 3/5, 2 ghi nhận tech-debt

Đọc lại code Windows (nguồn tham chiếu) đối chiếu tay từng dòng với code macOS mới viết — không tin
vào chính tài liệu mình vừa viết. Phát hiện 2 khẳng định "matches Windows" trong doc-comment của
chính phiên trước là **sai** (viết dựa trên giả định, chưa verify code Windows thật).

| # | Mức độ | Nền tảng | Vấn đề | Cách xử lý |
|---|--------|----------|--------|-----------|
| 1 | 🔴 Cao | macOS (3.3) | `joinEdgeGroup` gọi thẳng `autoArrange()` sau unfold → **xóa sạch vị trí thủ công của TẤT CẢ piece trên canvas**, kể cả những piece không liên quan gì đến nhóm cạnh vừa nối. Doc-comment cũ khẳng định "matches Windows, which also just re-unfolds plainly" — **sai**: `RerunUnfold(preservePositions: true)` (mặc định, dùng cho cả `JoinEdgeGroup`) khôi phục vị trí mọi piece còn giữ nguyên GroupId, chỉ đặt piece MỚI (bị merge) ở vị trí mặc định bên cạnh trang giấy. Hai method chị em `splitEdge`/`joinEdge` trên chính macOS cũng đã tự làm đúng việc này (`repositionAfterSplit`/`repositionAfterJoin`) — `joinEdgeGroup` là ngoại lệ duy nhất phá vỡ layout | Thêm `repositionAfterGroupJoin` (khái quát hoá heuristic "khớp piece cũ theo số face chung" đã có ở `repositionAfterSplit`) — thay `autoArrange()` bằng giữ nguyên vị trí piece không liên quan + piece merge kế thừa vị trí piece cũ khớp nhất |
| 2 | 🟡 Trung bình | macOS (3.3, tech debt sâu hơn) | `alignSelectedPieces` (và thao tác kéo piece thủ công có từ trước) **không undo được** trên macOS — `pushUndo`/`undo` chỉ snapshot `edgeOverrides`/`flapOverrides`. Doc-comment cũ khẳng định "matching Windows' equivalent toolbar action" — **sai theo nghĩa undo**: Windows `AlignSelected` gọi `PushDragUndo` vào **cùng một** `_undoStack` hợp nhất (`EditSnapshot` gộp edge+flap+piece-layout) nên ⌘Z trên Windows khôi phục CẢ vị trí piece. Đây là khoảng cách kiến trúc sâu, có từ trước GĐ3.3 (thao tác kéo piece thủ công cũng chưa từng gọi `pushUndo`) | **Không fix ngay** (cần thiết kế lại toàn bộ undo-stack macOS để gộp piece-layout, ảnh hưởng cả gesture kéo piece có sẵn) — sửa lại doc-comment cho đúng sự thật, ghi nhận tech-debt |
| 3 | 🟢 Thấp | macOS (3.3) | Thao tác ⌥-click để join cả nhóm cạnh cắt **không có gợi ý nào trong UI** — khác Windows, nơi tính năng tương đương là 1 mục menu chuột-phải hiện rõ ràng | Cập nhật tooltip nút "Edit Edges" trong toolbar để nhắc ⌥-click |
| 4 | 🔴 Cao | macOS (GĐ4 + kế thừa từ SVG/PDF có từ trước) | `grayscaleOutput` (toggle "Grayscale Output" trong Preferences) **chỉ ảnh hưởng màu fill mặt/tab**, không bao giờ ép màu đường fold/cut hay nhãn cặp-cạnh về xám/đen — trên **cả 3** định dạng export (SVG, PDF, và PNG mới ở GĐ4, vốn sao chép nguyên logic vẽ của PDFExporter). Windows xử lý đúng (ép `#555555`/`#000000` cho fold/cut/label khi bật grayscale) — xác nhận bằng cách đọc `SvgExporter.cs`/`PngExporter.cs` thật. PNG (GĐ4, mới) chỉ kế thừa lỗi đã có sẵn ở PDF/SVG (có từ trước GĐ4), không phải lỗi GĐ4 tự gây ra | Thêm nhánh `grayscaleOutput ? gray/black : configured-color` cho fold/cut/label ở cả 3 file (`SVGExporter.swift`, `PDFExporter.swift`, `PNGExporter.swift`) — nhất quán, tránh chỉ vá PNG mà để SVG/PDF tiếp tục sai |
| 5 | 🟡 Trung bình | macOS (GĐ4) | `PNGExporter.swift` **bỏ qua hoàn toàn** `settings.svgScaleFactor` khi tính toạ độ hình học — trong khi `SVGExporter.swift`/`PDFExporter.swift` đều nhân toạ độ với nó (dùng như hệ số hiệu chỉnh tỉ lệ in). Mặc định `svgScaleFactor=1.0` nên chưa ai gặp phải, nhưng người dùng nào hiệu chỉnh giá trị này (bù sai số máy in) sẽ thấy PNG xuất ra SAI tỉ lệ so với SVG/PDF cùng cấu hình | **Chưa fix** — cách áp dụng đúng cho PNG mơ hồ hơn PDF vì PNG dùng layout trang cố định (fixed paper size, multi-page grid) còn PDF macOS tự co trang theo pattern (single-page, auto-fit) — cần quyết định thiết kế (scale nội dung quanh đâu, có giữ nguyên kích thước trang pixel cố định không) trước khi sửa, không đoán liều |

**Kiểm chứng fix:**
- #1: build sạch; đối chiếu tay với `repositionAfterSplit`/`repositionAfterJoin` (cùng heuristic, đã có từ trước) — không viết được unit test trực tiếp vì method này (giống 2 method chị em) sống trong App target, test target không phụ thuộc vào (giới hạn đã có từ trước, không phải mới phát sinh).
- #3: chỉ đổi text tooltip, không có logic để test.
- #4: **thực thi thật** — script `swiftc` độc lập render PNG ở cả 2 chế độ (grayscale/color) rồi lấy mẫu pixel thật tại điểm nằm trên đường cut: grayscale → RGB(0,0,0) đen thật; color → RGB(255,38,0) đỏ (khớp `#ff0000` sau anti-alias) — không chỉ typecheck. Thêm 2 test `XCTestCase` mới trong `SVGExporterTests.swift` (`testSVG_grayscale_foldAndCutLinesAreNotColored`, `testSVG_color_foldAndCutLinesUseConfiguredColors`), verify thật qua scratch script + type-check toàn bộ 17 file test suite sạch.
- #2, #5: chỉ ghi nhận, không code — không cần kiểm chứng runtime.

Windows: không có thay đổi nào (đóng vai trò "nguồn đối chiếu đúng" cho cả 5 phát hiện, không tự phát
hiện lỗi mới ở phía Windows).

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
| 2026-07-22 | Cross-review GĐ1+GĐ2: PDO no-op (Win), `PdoUnfoldBuilder` thiếu `meshEdgeIds` (Win), thiếu UI `CoplanarAngleDeg` (Win), threshold <1° bị engine cutoff ghi đè (mac) | Win **104/104** test · CI xanh macOS+Windows → merge PR #58 |
| 2026-07-22 | GĐ3 Windows: `OverlapDetector.CountOverlaps`, `KruskalMstBuilder.tieBreakSeed`, `UnfoldService` refactor multi-seed retry + mesh-marking fix | net8.0 build + WPF compile (`EnableWindowsTargeting`) ✅ · **115/115** test ✅ (104 cũ + 11 mới) |
| 2026-07-22 | GĐ3 macOS: `OverlapDetector.countOverlaps`, `KruskalMSTBuilder.tieBreakSeed`, `UnfoldService.unfold` refactor multi-seed retry + mesh-marking fix, `autoArrange()` thêm xoay 90° (+ `rotated90InLocalBBox` tách sang Core để test được) | `swift build` ✅ (Core+App) · test mới type-check sạch qua shim + đối chiếu tay |
| 2026-07-22 | Merge PR #59 (`feat/parity-phase3-repack-multiseed`) → `main`, CI xanh cả 2 job ngay lần đầu | `gh run watch` ✅ |
| 2026-07-22 | Cross-review GĐ3: phát hiện tie-break dựa exact-equality gần như vô dụng với mesh bất đối xứng (thực nghiệm: 0/176 tie tuyệt đối) trong khi vẫn tốn 9x chi phí mỗi lần overlap | Thực nghiệm scratch C# console app xác nhận + hiệu chỉnh epsilon |
| 2026-07-22 | Fix: epsilon-perturbation (1°, hiệu chỉnh thực nghiệm) thay exact-equality + `HasPotentialTies`/`hasPotentialTies` skip-check cả 2 nền tảng | Win **121/121** test ✅ (115 cũ + 6 mới), build 0 lỗi · mac `swift build` ✅ + type-check sạch |
| 2026-07-22 | GĐ4 Windows: SVG layer (`xmlns:inkscape`, `<g>` fold/cut/tab/label) + inline stroke; `PngExporter.cs` mới trong App (WPF) + `PngDpi` setting + wire UI | Win **127/127** test ✅ (121 cũ + 6 mới `SvgLayerTests`), build 0 lỗi (`EnableWindowsTargeting`) |
| 2026-07-22 | GĐ4 macOS: SVG layer tương ứng (giữ comment cũ) + `PNGExporter.swift` (CoreGraphics bitmap, thêm page-splitting mới) + `pngDpi` setting + wire UI | `swift build` ✅ · type-check **toàn bộ** test suite lần đầu (vá 2 lỗ hổng shim) · verify thật qua `swiftc` execution (18 check, tất cả pass, kể cả lấy mẫu pixel màu) |
| 2026-07-22 | Merge PR #62 (`feat/parity-phase4-io`) → `main`, CI xanh cả 2 job | `gh run watch` ✅ |
| 2026-07-24 | Khảo sát 3.3: rodrigorc's 3-mode system đã có sẵn cả 2 nền tảng (kiến trúc khác nhau) → thu hẹp phạm vi còn 2 gap thật: join connected cut edges + align pieces (Windows có sẵn, macOS thiếu) | — |
| 2026-07-24 | GĐ3.3 macOS: `EdgeGroupFinder.swift` (BFS cạnh cắt nối nhau) + `PieceAligner.swift` (align 6 hướng, tách khỏi AppState để test được) + `AppState.joinEdgeGroup`/`alignSelectedPieces` + ⌥-click trigger + 6 nút toolbar align | `swift build` ✅ · scratch `swiftc` execution **23/23** assertion pass (không chỉ compile) · 17 test `XCTestCase` mới (`EdgeGroupFinderTests`+`PieceAlignerTests`) · type-check toàn bộ 15 file test suite sạch · soát lại không có pattern gây Swift compiler timeout như GĐ4 |

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
