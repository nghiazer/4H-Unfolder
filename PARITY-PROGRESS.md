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

---

## Kế hoạch xử lý tồn đọng (2026-07-25)

Sau khi GĐ1-4 + cross-review xong (v0.4.0.A / v0.0.0.7-alpha), khảo sát lại toàn bộ tech-debt còn mở
trong `CLAUDE.md` + `wiki/Roadmap.md` (13 việc, không có GitHub issue/PR nào đang mở — mọi thứ track
nội bộ). Lên kế hoạch 8 phase, ưu tiên theo mức độ tác động/rủi ro, **triển khai từng phase một, dừng
xin xác nhận trước khi sang phase kế tiếp** (không dồn nhiều phase vào 1 phiên).

Phát hiện khi khảo sát làm đổi phạm vi 2 việc:
- `EditFlapsViewModel` "hardcode" 5mm/45° thực ra chỉ là cosmetic — constructor đã ghi đè bằng
  `AppSettings` trước khi dùng. Không phải bug chức năng, chỉ là dọn code trùng magic number.
- `PNGExporter` bỏ qua `svgScaleFactor` là bug ở **cả 2 nền tảng**, không chỉ macOS — Windows
  `PngExporter.cs` có lỗ hổng y hệt. Phase 4 chỉ fix macOS (đúng phạm vi ghi trong Roadmap hiện tại),
  ghi nhận thêm dòng roadmap mới cho phía Windows thay vì scope-creep.

| Phase | Nền tảng | Việc | Mức ưu tiên | Trạng thái |
|:---:|:---:|---|:---:|:---:|
| 1 | macOS | Wire Outline Padding vào export/canvas — port `BoundaryPolygonComputer` (edge-chain), gọi `PolygonOffset.inflate`, layer SVG mới + canvas overlay + UI toggle | 🔴 | ✅ |
| 2 | Windows | 3 quick-win: cảnh báo `FlapOverride.Deserialize` lỗi, dọn magic-number `EditFlapsViewModel`, thêm setting `OverlapRetrySeedCount` (thay 8 cứng) | 🟢 | ✅ |
| 3 | macOS | Hợp nhất undo stack — `OverrideSnapshot` thêm `pieceOffsets`/`pieceRotations`/`userGroups`, push undo ở drag/rotate/align (pre-capture pattern như Windows `PushDragUndo`) | 🟡 | ⬜ |
| 4 | macOS | Fix `PNGExporter` bỏ qua `svgScaleFactor` — scale mm→px transform + sửa lại 2 chỗ chia font-size không nhất quán | 🟡 | ⬜ |
| 5 | macOS | Thêm import STL — `StlMeshLoader` conform `MeshLoaderProtocol` có sẵn, không cần dependency ngoài | 🟡 | ⬜ |
| 6 | macOS | Chuẩn bị ký/notarize bản phân phối — entitlements + `ExportOptions.plist` + notarize step gate bằng env var; **phần credentials (Apple Developer ID) cần user cung cấp, không tự làm được** | 🟡 | ⬜ |
| 7 | Windows | Select Symmetrical Pair (scoped: mode-toggle + mirror-plane estimate). Split Window / Change Coordinates: giữ nguyên "deferred as too complex"/"scope unclear" theo `SESSION_PROGRESS.md`, không tự ý scope nông | 🟢 | ⬜ |
| 8 | Cả 2 | Perf: dựng mesh >2000 face đo thực nghiệm chi phí retry 9x. Docs: 1 GIF demo + 3 screenshot còn thiếu trong wiki (`Home.md`, `Quick-Start.md`) | 🟢 | ⬜ |

Chi tiết implementation từng phase (file cụ thể, pattern tham chiếu từ Windows, cách verify) nằm trong
plan file phiên làm việc — sẽ chép lại phần liên quan vào mục tương ứng của tài liệu này ngay khi
phase đó bắt đầu triển khai, để không phụ thuộc vào file plan tạm.

### Phase 1 macOS: Outline Padding — hoàn thành (2026-07-25)

`PolygonOffset.inflate` đã có sẵn từ GĐ1 nhưng không có gì gọi tới (0 call site ngoài test) vì macOS
chưa có bộ dựng boundary polygon theo từng piece. Đã port `BoundaryPolygonComputer.Compute`/
`ChainEdges` (Windows) sang `Core/Algorithms/BoundaryPolygonComputer.swift`: gom cạnh non-fold
(cut + boundary — cả 2 đều bị cắt vật lý) của một piece, dedupe theo `meshEdgeId` (fallback theo toạ
độ khi `meshEdgeId < 0`), chain thành vòng kín có thứ tự. API nhận thêm closure `vertsFor` để 1 hàm
dùng chung được cho cả export (toạ độ thô `result.faces`) lẫn canvas (toạ độ hiệu lực sau
rotate+offset, qua `effectiveVerts`).

**Phát hiện + fix một bug thật khi viết test (không chỉ port máy móc):** `ChainEdges` bản Windows để
lại 1 điểm đóng vòng trùng lặp (điểm cuối == điểm đầu) trong output — vô hại bên Windows vì
`Clipper.InflatePaths` tự dọn điểm trùng/thẳng hàng trước khi offset. `PolygonOffset.inflate` bên
macOS **không** có bước dọn dẹp đó (tài liệu chính nó ghi rõ "Clipper-free... chỉ join cục bộ") — nếu
port y nguyên, điểm trùng lặp biến 1 góc thật thành 2 cạnh độ dài 0 liên tiếp, khiến `inflate` bỏ qua
hẳn góc đó (notch phẳng thay vì bo tròn/miter đúng) ở **mọi** piece xuất ra. Xác nhận bằng thực nghiệm
(script `swiftc` độc lập, xem bên dưới) trước khi thêm bước trim điểm trùng ở cuối `chainEdges` — chỉ
xảy ra khi vòng đã đóng kín thật (so `polygon.count >= 4` + so điểm đầu/cuối), không đổi hành vi ported
logic ở phần còn lại.

Wire vào:
- `SVGExporter.swift`: layer mới `<g inkscape:label="Outline Padding">`, gate bằng
  `outlinePaddingMm > 0`, style khớp Windows (`stroke="#404040" stroke-width="0.8"
  stroke-dasharray="4,4" fill="none" opacity="0.7"`). Chỉ SVG + canvas, **không** PDF — khớp Windows
  (`PdfExporter.cs` cũng chưa từng nhận `paddingPolygons`), không tự ý mở rộng phạm vi.
- `PatternCanvasView.swift`: `drawOutlinePadding` mới, gọi sau `drawTabs`, dùng `effectiveVerts` nên
  theo đúng vị trí piece đang kéo/xoay tay trên canvas. Gate trực tiếp bằng giá trị setting (không
  toggle canvas riêng) — khớp Windows (`PatternCanvasControl` cũng chỉ check `paddingMm > 0`).
- `PreferencesView.swift`: field "Outline Padding" (mm) trong Print tab, cạnh Margin/SVG Scale —
  đúng lý do trước đây item này bị deferred ("chưa show UI control để tránh no-op").

**Kiểm chứng (thực thi thật, không chỉ typecheck):**
- `swift build` (Core+App) sạch.
- Script `swiftc`-linked độc lập (biên dịch thẳng toàn bộ `Sources/FourHUnfolderCore` +
  script test làm `main.swift`) chạy **10/10 assertion thật pass** — gồm: piece hình vuông 2 tam giác
  (fold ở đường chéo) chain đúng 4 góc không có điểm trùng lặp; `PolygonOffset.inflate` trên polygon
  đó giữ **đủ cả 4 góc** sau khi bo tròn (bbox nở đúng 0.5mm mỗi phía — nếu chưa fix bug điểm trùng thì
  1 góc sẽ bị mất, bbox sẽ lệch); piece tam giác đơn; toàn-fold trả `nil`; input rỗng trả `nil`;
  closure `vertsFor` được áp dụng đúng.
- `BoundaryPolygonComputerTests.swift` (5 `XCTestCase` test, cùng nội dung với script trên) +
  toàn bộ 18 file test suite hiện có type-check sạch qua shim XCTest tái tạo (đã vá thêm `XCTFail`,
  `XCTAssertGreaterThan`/`LessThan`, `XCTAssertThrowsError`, `XCTUnwrap` — thiếu so với lần trước;
  cũng gặp lại đúng lỗ hổng "thiếu re-export Foundation" đã ghi nhận ở GĐ4, vá bằng `@_exported import
  Foundation` như lần trước).
- Smoke-launch app đã build (`FourHUnfolder` binary) — mở và chạy ổn định >2s, không crash ngay khi
  thêm `drawOutlinePadding` vào vòng lặp render Canvas.
- **Chưa làm được:** click-through UI thật (load mesh → bật Outline Padding trong Preferences → xác
  nhận bằng mắt đường dash hiện trên canvas) — môi trường phiên này không xác nhận được quyền
  Accessibility cho UI automation macOS. Nên xác nhận lại bằng mắt trong lần chạy Xcode thật tiếp theo.

### Phase 2 Windows: 3 quick-win — hoàn thành (2026-07-25)

1. **`FlapOverride.Deserialize` corrupt-data warning** — không sửa `Deserialize` (vẫn giữ nguyên
   `Debug.WriteLine` + trả `null`), thay vào đó đếm số override bị bỏ qua ngay tại call site
   (`MainViewModel.RestoreProjectState`) và đẩy vào `state.Warnings` — cơ chế **đã có sẵn**, được
   `ProjectSerializer.cs` dùng cho "Mesh file not found"/"Texture file not found" và hiển thị gộp qua
   `StatusText` ở cuối `RestoreProjectState` ("Project loaded with warnings: ..."). Không cần dựng UI
   cảnh báo mới — tận dụng đúng đường ống đã có, nhất quán với cách warning khác đã được surface.
2. **`EditFlapsViewModel` magic-number cleanup** — xác nhận đây chỉ là cosmetic: constructor
   (`HeightMm = mainVm.CurrentPrintSettings.GlueTabDepthMm` …) đã ghi đè giá trị hardcode 5.0/45.0
   trước khi dialog hiện ra, nên không phải bug chức năng. Bỏ initializer trùng lặp trên 3
   `[ObservableProperty]` (`_heightMm`, `_leftAngle`, `_rightAngle`), để `AppSettings` là nguồn sự
   thật duy nhất, kèm comment giải thích tại sao field không cần default nữa.
3. **`OverlapRetrySeedCount` setting** (thay số 8 cứng trong `UnfoldService.Unfold`'s `seedCount`
   default) — theo đúng khuôn `CoplanarAngleDeg`: `AppSettings.PrintSettings.OverlapRetrySeedCount`
   (int, default 8) → `SettingsViewModel` (`LoadFrom`/`ToSettings`) → `SettingsDialog.xaml` row 12 mới
   (Slider 0–20 + TextBox) trong GroupBox "Page Layout & Tab Geometry", cùng chỗ với Coplanar
   threshold. Cả 3 call site `_unfoldService.Unfold(...)` trong `MainViewModel.cs` (Unfold thường,
   `RerunUnfold`, `RestoreProjectState`) trước đây luôn dùng default ngầm — nay truyền tường minh
   `seedCount: _settingsService.Current.Print.OverlapRetrySeedCount` bằng named argument (tránh lẫn
   vị trí tham số optional `flapOverrides` phía trước).

**Kiểm chứng:** `dotnet build -p:EnableWindowsTargeting=true` 0 lỗi (chỉ 7 NU1603 warning baseline có
sẵn). `dotnet test tests/FourHUnfolder.Tests` **127/127 pass** — không đổi so với baseline trước phase
này (đúng như kỳ vọng: cả 3 việc đều là app-layer wiring/plumbing trên `MainViewModel`/`SettingsViewModel`
— các lớp này không nằm trong test suite portable, WPF không chạy runtime ngoài Windows; logic thuật
toán bên dưới — `UnfoldService.Unfold(seedCount:)`, `FlapOverride.Deserialize` — không đổi, vẫn được
test từ GĐ2/GĐ3, `FlapOverrideTests.cs` hiện có vẫn pass nguyên vì file đó không bị đụng tới). Không
thêm test mới vì không có logic thuật toán mới để test — khớp tiền lệ `PngDpi` (setting field không
có dedicated wiring test, chỉ compile-check qua App build).

---

## Cross-review Phase 1 + Phase 2 (2026-07-25) — không có bug thật, 1 scope gap tự bắt được

Đọc lại toàn bộ diff của cả 2 phase một cách hoài nghi (không tin vào chính write-up vừa viết ở trên),
đối chiếu tay với Windows reference nơi áp dụng. Không tìm thấy bug chức năng nào. 2 việc đáng ghi
nhận:

| # | Mức độ | Phát hiện | Xử lý |
|---|--------|-----------|-------|
| 1 | 🟡 Scope gap | Kế hoạch gốc scope "Configurable retry budget" (Phase 2) chỉ cho **Windows**, theo đúng cách `wiki/Roadmap.md` liệt kê nó (chỉ nằm trong bảng Windows). Nhưng bảng tech-debt macOS trong `CLAUDE.md` (dòng riêng, không nằm trong phạm vi khảo sát ban đầu của Phase 2) đã ghi rõ: `UnfoldService.swift` (mac) **cũng** hardcode `seedCount = 8` y hệt Windows — cùng 1 gap, 2 nền tảng, giống hệt kiểu phát hiện đã có với `PNGExporter`/`svgScaleFactor` ở khảo sát ban đầu. Bỏ sót vì lấy `wiki/Roadmap.md` làm nguồn scope chính cho Phase 2 thay vì đối chiếu cả `CLAUDE.md` | Thêm `overlapRetrySeedCount` cho macOS ngay trong cùng phiên cross-review này (không tách phase riêng vì nhỏ, rủi ro thấp, đúng khuôn `outlinePaddingMm` vừa làm ở Phase 1): `AppSettings.PrintSettings.overlapRetrySeedCount` (Int, default 8, có tolerant-decoder) → `AppState.unfold()` truyền `seedCount: settings.print.overlapRetrySeedCount` → field mới trong `PreferencesView` Print tab, cạnh Coplanar Threshold. `swift build` sạch. |
| 2 | 🟢 Ghi nhận, không phải bug | `SettingsDialog.xaml` (Win): `OverlapRetrySeedCount` (`int`) bind TwoWay vào `Slider.Value` (`double`) — pattern chuẩn WPF (numeric TypeConverter tự convert), nhưng đây là **lần đầu codebase này bind 1 `int` ObservableProperty vào Slider** (grep xác nhận không có tiền lệ). Không sửa gì (tin vào hành vi WPF chuẩn, rủi ro thấp nếu sai là binding im lặng không update chứ không crash) — **cần xác nhận bằng mắt trên Windows thật** trước khi coi là 100% chắc, theo đúng quy tắc "WPF runtime cần verify trên Windows thật" đã lặp lại nhiều lần trong tài liệu này. |
| 3 | 🟢 Phát hiện phụ, không liên quan Phase 1/2 | Viết script round-trip thật (`JSONEncoder`/`JSONDecoder`) để kiểm chứng `overlapRetrySeedCount` mới không phá tolerant-decoder của `PrintSettings` — **pass**. Nhưng bản nháp đầu của script (dùng JSON với `view2D`/`view3D`/`general` rỗng hoàn toàn để mô phỏng "settings.json cũ") **fail** — hoá ra không liên quan gì đến field mới: `View2DSettings`/`View3DSettings`/`GeneralSettings` **chưa từng có** tolerant `init(from:)` như `PrintSettings` (chỉ `PrintSettings` được vá sau sự cố GĐ1). Đây là lỗ hổng có sẵn từ trước, không do Phase 1/2 gây ra — nếu tương lai thêm field mới vào 1 trong 3 struct đó mà không thêm decoder chịu lỗi, sẽ lặp lại đúng bug đã fix cho `PrintSettings`. Không fix ngay (ngoài phạm vi Phase 1/2) — ghi nhận tech-debt trong `CLAUDE.md`. |

**Ghi nhận riêng, không phải bug — hiệu năng (Phase 1, mức thấp, đã biết trước):**
`PatternCanvasView.drawOutlinePadding` gọi lại `BoundaryPolygonComputer.compute` + `PolygonOffset.inflate`
(chain cạnh + tính arc lượng giác) cho **mọi piece, mỗi frame render** khi Outline Padding bật — không
cache/memoize. Với mesh nhỏ/vừa (đa số model giấy thực tế) không đáng kể; với mesh nhiều piece/cạnh có
thể cộng dồn vào chi phí retry 9x đã biết (mục Performance trong `CLAUDE.md`/`wiki/Roadmap.md` GĐ Phase
8). Không fix ngay — thêm cache đúng cách cần key theo `(result, pieceOffsets, pieceRotations,
outlinePaddingMm)` và invalidation rõ ràng, việc lớn hơn phạm vi "wire up" của Phase 1. Để lại cho
Phase 8 (profiling) quyết định có đáng làm không dựa trên số đo thật thay vì đoán.

**Đồng bộ tài liệu (lý do trước đây cố tình hoãn tới bước này):** cả 2 branch phase trước đó là
`wip/` riêng biệt, sửa `CLAUDE.md`/`wiki/Roadmap.md` (bảng dùng chung) ở mỗi branch sẽ tạo conflict khi
merge. Nay merge thẳng cả 2 phase vào `main` trong 1 lượt nên đồng bộ luôn: xoá TD-36-2, TD-36-3, dòng
"Wire outline padding" (mac 🔴) khỏi `CLAUDE.md`; xoá "Settings wiring", "Corrupt-data warning",
"Configurable retry budget" (Win) khỏi `wiki/Roadmap.md`, thêm dòng retry-budget mac mới đã fix luôn
trong cross-review này.

---

### Phase 3 macOS: hợp nhất undo stack cho piece layout — hoàn thành (2026-07-25)

**Phát hiện kiến trúc quan trọng trước khi code (thay đổi hẳn cách tiếp cận so với kế hoạch ban đầu):**
kế hoạch gốc định "thêm `pieceOffsets`/`pieceRotations`/`userGroups` vào snapshot rồi restore trực
tiếp" — nhưng đọc kỹ `unfold()` mới thấy nó **tự xoá `pieceOffsets`/`pieceRotations` về `{:}`** ở cuối
mỗi lần chạy (không chỉ `autoArrange()` như tài liệu cũ mô tả). `undo()`/`redo()` cũ gọi
`unfold(); autoArrange()` sau khi restore edges/flaps — nếu chỉ thêm field vào snapshot mà không đổi
gì khác, `autoArrange()` sẽ xoá sạch giá trị vừa restore ngay lập tức. Đối chiếu với
`splitEdge`/`joinEdge`/`joinEdgeGroup` (đã có sẵn từ GĐ3.3) xác nhận đúng pattern cần dùng: gọi
`unfold()` **một mình** (không `autoArrange()`), rồi gán lại `pieceOffsets`/`pieceRotations` SAU khi
`unfold()` hoàn tất — an toàn để restore theo index thô vì `unfold()` xác định (deterministic) với
cùng `(mesh, edgeOverrides, flapOverrides)`, nên `result.pieces` dựng lại đúng thứ tự/thành phần như
lúc chụp snapshot.

**Việc đã làm** (`AppState.swift`):
- `OverrideSnapshot` mở rộng từ `(edges, flaps)` thành `(edges, flaps, pieceOffsets, pieceRotations,
  userGroups)`; `pushUndo()`/`undo()`/`redo()` dùng chung `currentSnapshot()`/`restoreSnapshot()`.
- `restoreSnapshot()` gọi `unfold()` rồi mới gán `pieceOffsets`/`pieceRotations` (đè lên `{:}` vừa bị
  `unfold()` xoá) + `recomputePagesForOffsets()` — không gọi `autoArrange()`.
- `alignSelectedPieces()`: thêm `pushUndo()` trước khi áp delta — xoá đoạn doc-comment cũ giải thích
  giới hạn (nay đã fix), theo đúng khuyến nghị closing-the-loop.
- Thêm cặp `beginLayoutEdit()`/`commitPendingLayoutUndo()`/`cancelPendingLayoutUndo()` — snapshot
  "chờ" (`pendingLayoutUndo`) chụp TRƯỚC khi gesture bắt đầu mutate, chỉ thật sự push vào undo stack
  ở cuối gesture nếu có thay đổi thật — mirror `PushDragUndo(preDragPositions)` bên Windows (capture
  trước, quyết định push sau, tránh gesture click-không-kéo làm bẩn lịch sử undo).

**Việc đã làm** (`PatternCanvasView.swift`) — wire 3 luồng gesture mutate `pieceOffsets`/
`pieceRotations` vào cặp begin/commit trên, xác nhận bằng cách đọc lại toàn bộ
`makeUnifiedDragGesture` rằng 3 luồng **loại trừ lẫn nhau trong cùng 1 gesture** (handle-rotate và
piece-drag đều yêu cầu `!isHandleRotating && !isDraggingPieces` làm tiền đề, nên không bao giờ cả 2
cùng true) — tránh double-commit:
1. Rotate-pivot phase 2 — `beginLayoutEdit()` ở `.onChanged` đầu tiên của MỖI lần kéo rời rạc (phase
   có thể tồn tại qua nhiều lần nhấn-kéo-thả riêng biệt do pivot vẫn "được chọn" cho tới khi user tự
   reset — cần cờ `pivotDragActive` riêng thay vì chỉ gọi 1 lần ở lúc phase chuyển 0→1→2).
2. Rotate-handle drag (selection) — tận dụng đúng điểm code cũ đã detect "lần đầu" (nơi
   `isHandleRotating = true` được set).
3. Multi-piece translate drag — tương tự, tại điểm `isDraggingPieces = true`.

`.onEnded` commit dựa vào cờ local đã lưu TRƯỚC `defer` (vì `defer` reset các cờ về false trước khi
code trong `.onEnded` kịp đọc) — không cần ngưỡng "đã di chuyển >0.5mm" kiểu Windows vì
`DragGesture(minimumDistance: 4)` của SwiftUI đã tự đảm bảo ≥4pt di chuyển trước khi `.onChanged` bắn
lần đầu, nên nếu 1 trong 3 cờ từng true nghĩa là đã có thay đổi thật.

**Kiểm chứng (thực thi thật, không chỉ build):** `AppState`/`PatternCanvasView` sống ở App target mà
test target không phụ thuộc vào (giới hạn đã ghi nhận từ GĐ3.3, giống `alignSelectedPieces`/
`repositionAfterSplit`) — không viết được `XCTestCase`. Thay vào đó: build thành công
`Sources/FourHUnfolderCore` (28 file `.o` có sẵn từ `swift build`) + `AppState.swift` thành 1
executable độc lập bằng `swiftc` (link trực tiếp `.o`, không qua SPM), dựng mesh cube thật (12 mặt,
2 cạnh ép `.cut`), gọi `unfold()` thật (không giả lập), rồi thực thi kịch bản kéo→undo→redo→gesture-huỷ
qua **8 assertion thực thi thật, tất cả pass**:
- `undo()` sau khi drag khôi phục đúng `pieceOffsets[0]`/`pieceRotations[0]` về `nil` (giá trị trước
  drag) — xác nhận qua `unfoldResult` thật được build lại bởi `unfold()` async thật, không phải mock.
- `redo()` khôi phục đúng lại `(42,17)`/`90°` đã drag.
- `beginLayoutEdit()` rồi `cancelPendingLayoutUndo()` (mô phỏng click không kéo) **không** tạo thêm
  entry trong undo stack — xác nhận gián tiếp qua việc `undo()` lần tiếp theo vẫn về đúng state trước
  drag, không có bước thừa nào chen giữa.
- Lỗi thực khi viết script lần đầu (không phải bug sản phẩm): dùng `Task { @MainActor in ... };
  sem.wait()` để chờ async từ 1 script top-level → deadlock thật (semaphore chặn main thread trước khi
  Task kịp chạy trên main actor) — sửa bằng top-level `await run()` trực tiếp (Swift hỗ trợ async
  top-level code trong `main.swift`).

`swift build` (Core+App): sạch. Không có regression trong 18 file `XCTestCase` hiện có (Phase 3 không
đụng file nào trong `FourHUnfolderCore`).

---

### Phase 4 macOS: fix PNGExporter bỏ qua svgScaleFactor — hoàn thành (2026-07-25)

**Quyết định thiết kế (lý do phase này trước đây bị coi là "cần design call"):** SVG/PDF không có khái
niệm trang cố định — cả document co giãn theo `content_bbox * sc + margin`. PNG thì khác hẳn: cần
kích thước trang CỐ ĐỊNH tính bằng pixel (khớp giấy in thật @ DPI thật), vì đó chính là ý nghĩa của
"PNG mỗi trang cho máy cắt" — in/cắt trên khổ giấy vật lý thật. Quyết định: **giữ nguyên `pixelW`/
`pixelH`** (kích thước trang vật lý, không đổi theo `sc`) — trang in vẫn là khổ giấy thật; chỉ áp `sc`
vào phép biến đổi toạ độ mm→px (`px`/`py`), khiến nội dung to/nhỏ lại quanh gốc toạ độ CỦA TỪNG TRANG,
giống hệt cách 1 hệ số hiệu chỉnh in nhỏ (gần 1.0) hoạt động trên SVG/PDF. Không cố gắng làm cho
`autoArrange()` (vốn không biết gì về `sc`) nhận biết trang-theo-tỉ-lệ — ngoài phạm vi "fix bug bỏ
qua setting", sẽ cần thiết kế lại thuật toán xếp trang, chỉ hợp lý nếu setting này được dùng cho hiệu
chỉnh LỚN thay vì hiệu chỉnh in nhỏ (trường hợp dùng thực tế).

**Việc đã làm** (`PNGExporter.swift`):
- `px`/`py` nhân thêm `* sc` (`sc = settings.svgScaleFactor`) vào phép biến đổi toạ độ — khớp cách
  SVG/PDF áp `sc` lên hình học.
- **Không** đổi `ctx.setLineWidth(...)` (độ dày nét fold/cut) — đối chiếu `SVGExporter.swift` xác nhận
  SVG cũng **không** nhân `stroke-width` với `sc` (độ dày nét đại diện cho đặc tính công cụ cắt — dao
  laser/dao kéo, không phải thứ cần hiệu chỉnh theo giấy co giãn) — giữ nhất quán, không tự ý mở rộng.
- Sửa 2 chỗ tính `fontSize` (nhãn cặp cạnh + nhãn trang) từ `pxPerMm / sc` (chia — không nhất quán,
  hình học không hề nhân sc ở bất cứ đâu khác trong file trước fix này) thành `pxPerMm * sc` — khớp
  cách `SVGExporter`'s `font-size="3"` tự động co giãn theo `sc` (vì toạn bộ hệ toạ độ SVG viewBox đã
  ở "đơn vị mm-của-output-đã-scale").

**Kiểm chứng (thực thi thật, lấy mẫu pixel):**
- Script `swiftc` độc lập dựng 1 tam giác biết trước toạ độ mm, export PNG ở `sc=0.5/1.0/2.0`, đếm số
  pixel không-trắng trong ảnh xuất ra (foolproof hơn dò 1 pixel đơn lẻ — lần thử đầu dùng cách lấy mẫu
  1 pixel bị lỗi Y-flip trong chính script test, không phải bug sản phẩm; đổi sang đo diện tích tô màu
  toàn ảnh để tránh hẳn lớp toán map toạ độ dễ sai).
- Diện tích tô màu tỉ lệ đúng theo **bình phương** hệ số scale (hình học 2D): `sc=2.0` cho diện tích
  gấp **4.007×** so với `sc=1.0` (lý thuyết 4×); `sc=0.5` cho **0.254×** (lý thuyết 0.25×) — sai số
  ~0.2%, xác nhận scale áp dụng đúng vào hình học, không phải hiệu ứng ngẫu nhiên/làm tròn.
- Smoke test render nhãn (`includePageLabel`/`includeEdgeLabels`) ở `sc=2.0` và `sc=0.1` (biên cực
  đoan) — không crash, vẫn xuất file — xác nhận công thức `fontSize` mới không tạo giá trị âm/NaN cho
  `CTFontCreateWithName`.

`swift build`: sạch. Đã đóng 2 mục tech-debt liên quan: `CLAUDE.md` macOS table (chỉ còn 1 mục
`View2DSettings`/... tolerant-decoder, phát hiện từ Phase 1+2), `wiki/Roadmap.md` macOS table (xoá
dòng PNGExporter/svgScaleFactor và dòng Undo stack — cả 2 đã fix ở Phase 3/4).

---

### Phase 5 macOS: thêm import STL — hoàn thành (2026-07-25)

**Vì sao STL trước, không cần dependency ngoài:** `MeshLoaderProtocol`/`MeshLoaderFactory` đã có sẵn
extension point (chỉ cần conform + đăng ký) — không phải xây kiến trúc mới. STL là format phổ biến
nhất trong giới in-3D/laser-cut mà app này đang nhắm tới (SVG cutting-machine layers từ GĐ4), và định
dạng đơn giản, đã biết rõ đặc tả (binary + ASCII) — không cần thư viện ngoài, khớp quy ước codebase
(PolygonOffset/FlapMerger cũng cố tình tránh Clipper2 tương tự).

**Thách thức kỹ thuật chính:** STL (cả 2 biến thể) **không có topology chia sẻ đỉnh** — mỗi tam giác
tự liệt kê 3 đỉnh độc lập bằng số thực thô, khác hẳn OBJ (tham chiếu index) hay PDO. `Mesh.getOrAddEdge`
dedupe theo **INDEX đỉnh**, không theo toạ độ — nếu không "hàn" (weld) các đỉnh trùng vị trí từ nhiều
tam giác khác nhau thành cùng 1 index trước khi build edge, mọi mặt sẽ thành piece riêng biệt (không
cạnh nào chia sẻ, BFS của UnfoldEngine vô dụng). Giải pháp: `WeldKey` — key toạ độ làm tròn (giống
hệt kiểu `coordKey` đã dùng trong `BoundaryPolygonComputer` ở Phase 1), dict tra cứu O(1) trong lúc
duyệt tam giác.

**Phân biệt binary/ASCII:** dùng công thức kích thước file (`84 + N*50` byte cho binary) làm tiêu chí
chính, **không** chỉ dựa vào tiền tố `"solid"` — vì 1 số exporter binary cũng ghi chữ "solid" vào 80
byte header (thói quen sao chép từ quy ước ASCII), khiến check tiền tố đơn thuần sai với những file đó.

**Việc đã làm:**
- `StlMeshLoader.swift` (`FourHUnfolderCore/IO/Loaders/`) — conform `MeshLoaderProtocol`, parser binary
  (đọc little-endian qua `Data` byte-by-byte, không dùng `withUnsafeBytes` load trực tiếp vì `Data`
  slice không đảm bảo alignment) + parser ASCII (quét dòng `vertex x y z`, gộp mỗi 3 dòng thành 1 tam
  giác — không phụ thuộc cấu trúc `facet`/`outer loop` chặt chẽ, chịu được biến thể format giữa các
  exporter khác nhau).
- Đăng ký vào `MeshLoaderFactory.loaders`.
- `AppState.openMeshFilePicker()`: thêm `"stl"` vào `allowedContentTypes` — thiếu bước này thì loader
  có hoạt động cũng vô ích vì user không chọn được file `.stl` qua dialog Open.

**Kiểm chứng (thực thi thật + XCTestCase, khác Phase 3 vì file này sống trong `FourHUnfolderCore` —
test được, không bị giới hạn App-target):**
- Script `swiftc` độc lập: dựng cube tổng hợp theo đúng kiểu STL thật (36 đỉnh thô lặp lại qua 12 tam
  giác, KHÔNG dùng index như `TestMesh.cube()`), build cả buffer binary lẫn ASCII trong bộ nhớ, chạy
  qua loader thật — **17/17 assertion thực thi thật pass**: `isBinary()` đúng cho cả 3 trường hợp
  (binary thật, ASCII thật, binary có header chứa "solid" — trường hợp khó); weld đúng 36→8 đỉnh; 18
  cạnh; **toàn bộ 18 cạnh đều nối 2 mặt, 0 cạnh biên** (phát hiện lỗi trong chính test lúc đầu: kỳ vọng
  sai "6 cạnh chéo nối 2 mặt, 12 cạnh biên" — thực ra 1 khối lập phương kín thì KHÔNG có cạnh biên nào,
  toàn bộ 18 cạnh — kể cả 12 cạnh thật của khối lập phương — đều nối đúng 2 tam giác; sửa lại kỳ vọng
  test, không phải bug sản phẩm); `MeshLoaderFactory` route đúng `.stl`; **và chạy full pipeline
  `UnfoldService().unfold(...)` thật** trên mesh STL vừa load — ra đúng 12 mặt, ≥1 piece, xác nhận STL
  không chỉ parse được mà còn dùng được thật trong app.
- `StlMeshLoaderTests.swift` (19 test `XCTestCase`, cùng nội dung + thêm error-case: file rỗng, dữ
  liệu rác không phải UTF-8 cũng không đúng kích thước binary, ASCII không có dòng `vertex` nào) — type-
  check sạch qua toàn bộ 19 file test suite hiện có (thêm 1 file mới so với trước).

`swift build`: sạch.

---

### Phase 6 macOS: chuẩn bị ký/notarize bản phân phối — hoàn thành phần code, chờ credentials thật (2026-07-25)

**Giới hạn đã biết trước (không phải phát hiện mới):** ký Developer ID + notarize cần tài khoản
Apple Developer Program trả phí thật của user — không có cách nào tự động hoá bước này. Phạm vi thực
tế của phase: chuẩn bị đầy đủ script/scaffolding, **gate bằng biến môi trường** để hành vi mặc định
(không có credentials) giữ nguyên y hệt trước đây — không phải là "làm nửa vời", mà là làm tối đa phần
code có thể làm, để khi user có tài khoản chỉ cần set 2 biến môi trường là chạy được.

**Việc đã làm:**
- `Resources/4H-Unfolder.entitlements` (mới) — **cố tình tối giản, không sandbox**: app phân phối qua
  GitHub release chứ không qua Mac App Store nên không bắt buộc App Sandbox — chỉ cần chữ ký Developer
  ID hợp lệ + Hardened Runtime (`codesign --options runtime`) là đủ điều kiện notarize. `Package.swift`
  không có dependency ngoài nào (đã xác nhận từ khảo sát backlog ban đầu), chỉ link framework hệ thống
  của Apple → không cần entitlement ngoại lệ nào (JIT, unsigned executable memory, disable library
  validation) — để trống, có comment giải thích, sẵn sàng mở rộng khi cần.
- `scripts/build-release.sh`: mở rộng bước ký (step 3) — nếu `APPLE_DEVELOPER_ID` được set, ký thật
  với `--options runtime` + entitlements; nếu không, giữ nguyên ad-hoc sign như cũ (default không đổi
  hành vi). Thêm step notarize mới (step 4) — chỉ chạy khi **CẢ** `APPLE_DEVELOPER_ID` **VÀ**
  `APPLE_NOTARY_PROFILE` đều được set: zip tạm → `notarytool submit --wait` → `stapler staple` **lên
  chính .app bundle** (không phải lên file zip tạm — staple sửa đổi bundle thật, phải làm TRƯỚC khi
  tạo zip phân phối cuối cùng, thứ tự này dễ làm sai nếu không để ý) → xoá zip tạm → mới tới bước đóng
  gói zip phân phối cuối (step 5, dùng bundle đã stapled). Comment đầu file hướng dẫn đầy đủ cách lấy
  credentials (`notarytool store-credentials`) và cách chạy.
- **Tiện phát hiện khi rà `Info.plist`:** `CFBundleDocumentTypes` liệt kê OBJ/PDO/4hu nhưng **thiếu
  STL** dù Phase 5 đã thêm loader — nếu không có entry này, Finder/"Open With" sẽ không liên kết file
  `.stl` với app dù loader hoạt động đúng. Tiện tay fix luôn (không đợi review riêng) vì đang có mặt
  trong cùng khu vực file này.

**Kiểm chứng (thực thi thật cho phần CÓ THỂ test; phần cần credentials thật thì không):**
- `bash -n` xác nhận cú pháp script hợp lệ.
- **Chạy thật** `./scripts/build-release.sh` ở chế độ mặc định (không set biến môi trường) — build
  release thành công, ký ad-hoc như cũ, notarize bị skip đúng với thông báo rõ ràng, zip tạo thành
  công, `codesign -dv` xác nhận `flags=0x2(adhoc)` (đúng như trước khi sửa script — không có regression
  ở đường mặc định). Smoke-launch binary thật trong bundle vừa build — chạy ổn định, không crash.
  Xác nhận `Info.plist` trong bundle đã đóng gói có entry STL mới. Dọn sạch artifact test sau khi xong
  (không để lại trong `publish/` — thư mục này đã gitignore nên cũng không lọt vào commit).
- `plutil -lint` xác nhận cả `Info.plist` (sau khi thêm STL) và `4H-Unfolder.entitlements` là XML plist
  hợp lệ.
- **Không kiểm chứng được** (cần Apple Developer ID + notarytool credentials thật, không có trong môi
  trường này): đường ký thật + notarize thật. Ghi nhận trung thực đây là giới hạn đã biết trước từ lúc
  lên kế hoạch, không phải bỏ sót.

---

## Cross-review Phase 3–6 (2026-07-25) — không có bug thật

Đọc lại toàn bộ diff 4 phase (so với `main` đã merge Phase 1+2) một cách hoài nghi, đối chiếu tay
với hành vi kỳ vọng và với Windows reference nơi áp dụng. Không tìm thấy bug chức năng cần sửa.

| # | Phase | Điều đã kiểm tra kỹ | Kết luận |
|---|-------|----------------------|----------|
| 1 | 3 | `toggleEdge`/`setFlapOverride`/`clearEdgeOverrides`/`splitEdge`/`joinEdge`/`joinEdgeGroup` đều gọi `pushUndo()` sẵn có — snapshot rộng hơn (thêm piece layout) có phá các đường undo CŨ này không? | **Không những không phá, còn tốt hơn trước**: undo 1 thao tác `splitEdge`/`joinEdge` giờ khôi phục đúng layout piece TRƯỚC thao tác đó (vì `unfold()` xác định + edgeOverrides khôi phục đúng → topology dựng lại y hệt lúc chụp snapshot → offset theo index vẫn đúng piece). Trước Phase 3, undo các thao tác này gọi `autoArrange()` nên **xáo trộn toàn bộ layout** thay vì khôi phục đúng — Phase 3 sửa luôn 1 bug tiềm ẩn ở các đường undo cũ, không chỉ thêm undo cho drag/align mới. |
| 2 | 3 | Race lý thuyết: `beginLayoutEdit()` chụp snapshot "chờ" — nếu 1 hành động khác gọi `pushUndo()`/`undo()` xen giữa lúc đang kéo (trước `.onEnded`), `pendingLayoutUndo` có thể bị lệch | Biên độ cực hẹp: SwiftUI/AppKit không dispatch phím tắt trong lúc 1 gesture kéo chuột đang giữ input; không tìm được đường thực tế nào kích hoạt được. Ghi nhận là giới hạn lý thuyết của chính pattern "capture trước, commit sau" (Windows `PushDragUndo` cũng có cùng lớp rủi ro về nguyên tắc) — không fix (over-engineering cho 1 kịch bản không tái hiện được). |
| 3 | 4 | Công thức mới `(v.x - oxMm) * pxPerMm * sc` có còn đúng khi `pagesWide/pagesTall > 1` (nhiều trang), không chỉ trường hợp 1 trang đã test? | Đúng về mặt công thức cho hiệu chỉnh NHỎ (giá trị thực tế của setting này, gần 1.0) — mỗi trang co giãn quanh gốc CỦA CHÍNH nó (`oxMm` không đổi). Giới hạn kiến trúc đã ghi nhận sẵn trong comment code + PARITY-PROGRESS (Phase 4): `sc` lớn vẫn có thể đẩy nội dung tràn trang vì `autoArrange()` không biết về `sc` — không phải bug mới, là giới hạn đã biết trước, đã viết rõ trong code. |
| 4 | 5 | Tam giác suy biến (3 đỉnh khác nhau nhưng thẳng hàng, diện tích 0) — `StlMeshLoader` chỉ chặn trường hợp 2 đỉnh trùng nhau (`a != b, b != c, a != c`), không chặn thẳng hàng | Đối chiếu `ObjMeshLoader`: **cũng không** chặn tam giác thẳng hàng (không `guard` nào cho collinearity). `StlMeshLoader` đang ở đúng mức độ chặt chẽ ngang bằng loader tham chiếu hiện có trong repo — không phải hổng riêng của STL, không tự ý làm chặt hơn tiêu chuẩn đã chấp nhận sẵn trong codebase. |
| 5 | 6 | Thứ tự notarize/staple/zip trong `build-release.sh` — staple đúng lên `.app` bundle (không phải lên zip tạm dùng để submit), và đúng TRƯỚC khi tạo zip phân phối cuối | Đọc lại từng dòng xác nhận đúng thứ tự: `zip tạm → notarytool submit --wait → stapler staple "$BUNDLE" → xoá zip tạm → (cd "$STAGE") → zip zip phân phối cuối từ chính `$BUNDLE` vừa stapled`. Đúng. |
| 6 | — | Branch ancestry: `wip/backlog-phase6-...` có phải hậu duệ sạch của `main` hiện tại (đã merge Phase 1+2) không, hay lẫn commit trùng/conflict? | `git merge-base` == tip `origin/main` chính xác — 4 commit Phase 3-6 nằm gọn phía trên, không trùng lặp, PR sẽ ra diff sạch. |

**Không tìm thấy finding nào cần code fix mới** trong lượt cross-review này (khác Phase 1+2, nơi tự
bắt được 1 scope gap thật) — 3 sửa "tiện tay" đã làm ngay trong lúc code (STL vào `Info.plist`) đã
tính là một phần commit Phase 6, không phải phát hiện riêng của cross-review.

---

### Phase 7 Windows: Select Symmetrical Pair (TD-38-4) — hoàn thành (2026-07-25)

**Thu hẹp phạm vi có chủ đích:** TD-38 gốc gộp chung 3 việc "quá phức tạp" (Select Symmetrical Pair /
Split Window / Change Coordinates). Đúng như plan ban đầu đã phân tích: chỉ Select Symmetrical Pair
đủ rõ ràng để làm ngay ("chọn 1 piece, tự động chọn thêm piece đối xứng gương") — Split Window (multi-
window WPF, chưa có scaffolding) và Change Coordinates (chính `SESSION_PROGRESS.md` ghi "scope
unclear") **cố tình để lại**, không tự ý thu hẹp phạm vi cho vừa 1 phiên code.

**Quyết định thiết kế — chỉ đối xứng theo trục toạ độ chính (X/Y/Z), không tìm mặt phẳng đối xứng bất
kỳ hướng nào:** đối xứng tổng quát (arbitrary-orientation) là lý do TD-38-4 bị coi "quá phức tạp" từ
đầu. Hầu hết model đối xứng thật (nhân vật, xe, robot) đều được dựng thẳng đứng, cân đối theo 1 trong
3 trục toạ độ chính — thu hẹp còn 3 mặt phẳng ứng viên (qua tâm bounding-box, vuông góc X/Y/Z) là đủ
cho tuyệt đại đa số model thực tế, mà không cần thuật toán PCA/tối ưu hướng phức tạp.

**Kiến trúc — tách thuật toán thuần khỏi glue code WPF** (đúng khuôn `PieceAligner`/
`BoundaryPolygonComputer` bên macOS): `SymmetryDetector` mới trong `FourHUnfolder.Geometry.Algorithms`
(test được trong suite portable):
- `DetectMirrorPlane(positions, threshold=0.9)` — với mỗi trục X/Y/Z, tính điểm đối xứng bằng lưới
  không gian (spatial hash, bucket = epsilon, tra cứu hàng xóm 3×3×3 — cùng hình dạng thuật toán với
  `OverlapDetector`'s candidate-pair phase) đo tỉ lệ đỉnh có ảnh gương trùng khớp; chọn trục điểm cao
  nhất, chỉ chấp nhận nếu ≥90% đỉnh khớp (dưới ngưỡng → coi model không đối xứng, trả `null` thay vì
  đoán liều).
- `FindMirrorPiece(plane, pickedPieceId, pieceCentroids, tolerance=5mm)` — so khớp centroid 3D (KHÔNG
  phải vị trí 2D sau unfold — vị trí 2D không liên quan gì tới đối xứng 3D thật) của piece được chọn,
  phản chiếu qua mặt phẳng, tìm piece khác có centroid gần ảnh phản chiếu nhất; loại piece tự thân
  (piece nằm đúng trên mặt phẳng — như mảnh "xương sống" — không có cặp riêng biệt) và loại kết quả
  nếu khoảng cách vượt ngưỡng dung sai (tránh trả về "gần nhất dù xa" như thể là cặp thật).
- Glue code trong `PatternCanvasControl.xaml.cs` (`SelectSymmetricalPair()`, theo đúng mẫu
  `AlignSelected`/`RotateSelected` — thao tác 1 lần trên piece đang chọn, không phải mode toggle như
  Rotate-by-Point/Edit-Edges): yêu cầu đúng 1 piece đang chọn, dựng dict `pieceId → centroid 3D` từ
  `PieceViewModel.Faces[].FaceId` tra `mesh.Faces`/`mesh.Vertices`, gọi `SymmetryDetector`, set
  `IsSelected=true` cho piece khớp + báo `StatusText` (tận dụng cơ chế đã có, không dựng UI mới —
  giống cách Phase 2 xử lý cảnh báo `FlapOverride`).
- Icon toolbar: tái dùng **`&#xE7B8;` (Flip)** — glyph đã dùng sẵn cho tính năng "Mirror Inversion"
  hiện có trong `MainWindow.xaml`, tránh đoán liều 1 codepoint Segoe Fluent Icons chưa được xác nhận
  hiển thị đúng (rủi ro thật vì máy Darwin không cài font này để tự kiểm tra bằng mắt).

**Kiểm chứng (thực thi thật — C#/.NET chạy được trên Darwin, khác nhóm WPF-only):**
- `SymmetryDetectorTests.cs` (9 test `xUnit`+`FluentAssertions`, đúng convention
  `GeometryAlgorithmTests.cs`) — **chạy thật qua `dotnet test`, không phải chỉ compile-check**: phát
  hiện đúng trục X + tâm 0 cho tập điểm đối xứng tổng hợp (bao gồm 1 điểm nằm đúng trên mặt phẳng);
  trả `null` cho tập điểm rải rác không đối xứng; xử lý an toàn input rỗng/1 điểm (bounding-box suy
  biến, tránh chia 0); `Mirror()` đúng công thức phản chiếu cho cả 3 trục + tâm lệch khỏi gốc toạ độ;
  `FindMirrorPiece` chọn đúng centroid gần nhất, từ chối piece ở xa dù cùng phía trục khớp, không bao
  giờ tự khớp với chính piece đang chọn.
- `dotnet build -p:EnableWindowsTargeting=true`: 0 lỗi. `dotnet test`: **136/136 pass** (127 cũ + 9
  mới), không regression.
- Glue code `PatternCanvasControl.xaml.cs` (WPF, không compile-check được ngoài Windows runtime theo
  đúng giới hạn đã ghi nhận nhiều lần) — code ngắn, chỉ gọi vào `SymmetryDetector` đã test kỹ, khớp
  đúng mẫu `AlignSelected` hiện có (không unit test riêng, giống tiền lệ).

---

### Phase 8a — Cross-cutting: profile overlap-retry cost trên mesh lớn (2026-07-25)

**Không có fixture/benchmark sẵn** trên cả 2 nền tảng trước đây (đã xác nhận từ khảo sát backlog ban
đầu) — phải tự dựng mesh lớn để đo, không phải chỉ "chạy lại benchmark có sẵn".

**Mesh tổng hợp:** UV-sphere dựng bằng vòng lặp lat/long (không cần thuật toán icosphere phức tạp),
độ phân giải 20×20/30×30/40×40 → 800/1800/3200 mặt tam giác. Chọn hình cầu **có chủ đích**: một mặt
cầu về bản chất **không thể trải phẳng thành 1 mảnh liền mà không chồng lấn** — đảm bảo trigger overlap
+ retry loop THẬT, thay vì phải đoán/ép 1 mesh nhân tạo có overlap.

**Kết quả đo thật (Release build, cả 2 nền tảng):**

| Mesh | Windows: 1 lần (không retry) | Windows: mặc định (retry 8) | Tỉ lệ | macOS: 1 lần | macOS: mặc định | Tỉ lệ |
|---|---|---|---|---|---|---|
| 800 mặt | 34,6 ms | 155,8 ms | 4,5× | 29,4 ms | 1189,5 ms | 40,5× |
| 1800 mặt | 7,6 ms | 248,1 ms | 32,5× | 54,3 ms | 3006,2 ms | 55,4× |
| 3200 mặt | 16,6 ms | 555,4 ms | 33,5× | 97,2 ms | 5471,8 ms | 56,3× |

**Phát hiện quan trọng — tỉ lệ thật (33-56×) tệ hơn nhiều so với con số "9×" vẫn được nhắc trong
`CLAUDE.md`/`wiki/Roadmap.md` từ trước (dựa trên "1 lần chạy gốc + tối đa 8 lần retry = 9 lần"):**
đo tách riêng `HasOverlaps` (early-exit, dừng ngay khi thấy 1 cặp chồng lấn) và `CountOverlaps` (quét
hết, dùng để SO SÁNH các candidate retry — bắt buộc phải biết chính xác số lượng, không thể early-exit)
trên cùng 1 kết quả unfold (mesh 3200 mặt, 849/922 cặp chồng lấn thật — mesh cầu chồng lấn RẤT nặng):

| | Windows | macOS |
|---|---|---|
| `HasOverlaps`/`hasOverlaps` (early-exit) | 5,48 ms | 20,62 ms |
| `CountOverlaps`/`countOverlaps` (quét hết) | 48,76 ms | 456,17 ms |
| Tỉ lệ | ~9× | ~22× |

Retry loop gọi `CountOverlaps` **9 lần** (1 lần tính `bestCount` ban đầu + tối đa 8 lần trong vòng
lặp), trong khi đường "1 lần, không retry" (dùng để so `Single pass` ở bảng trên) **không bao giờ**
gọi `CountOverlaps` — chỉ dùng `HasOverlaps` rẻ hơn nhiều bên trong `UnfoldOnce`. Đây chính là lý do
tỉ lệ thật cao hơn hẳn "9×" ngây thơ: không phải bản thân `UnfoldOnce` (dual graph + MST + BFS + glue
tabs) đắt hơn 9 lần mỗi lượt, mà là **riêng phần đếm overlap để so sánh candidate đã đắt gấp ~9-22 lần
so với chỉ cần biết có/không** — nhân dồn với 9 lần gọi.

**macOS chậm hơn Windows đáng kể về số tuyệt đối** (5,4 giây so với 555 ms cho mesh 3200 mặt, cùng 1
workload) — ghi nhận trung thực, không đi sâu điều tra nguyên nhân chênh lệch nền tảng (ngoài phạm vi
"profile & document" của phase này; có thể do khác biệt cấu trúc dữ liệu `struct`-heavy của Swift hay
chi tiết cài đặt spatial grid — cần điều tra riêng nếu muốn tối ưu).

**Hướng fix khả dĩ cho tương lai (không làm ngay — đúng phạm vi phase này là "đo & ghi nhận", không
phải "redesign"):** cho `CountOverlaps` một early-exit CÓ ĐIỀU KIỆN (dừng sớm khi đã chắc chắn candidate
hiện tại không thể thắng `bestCount` đang giữ, ví dụ dừng ngay khi đếm vượt quá best hiện tại — vẫn
chính xác, không cần đổi thuật toán) — đây là optimization tự nhiên nhất, không cần đổi kiến trúc.

**Không thêm fixture/benchmark cố định vào repo** — đúng theo kế hoạch ban đầu ("chỉ thêm benchmark
lâu dài nếu profiling thực sự lộ ra hotspot đáng sửa"); phát hiện lần này ĐÃ đáng ghi nhận cụ thể
(con số thật + cơ chế chính xác) nhưng bản thân việc FIX là 1 quyết định thiết kế riêng (early-exit
điều kiện làm thay đổi hành vi retry loop, cần cân nhắc kỹ, không phải thay đổi nhỏ) — để lại cho
phiên làm việc riêng, không tự ý mở rộng phạm vi phase này.

---

### Phase 8b — Cross-cutting: wiki docs placeholder (2026-07-25)

**Glossary: đã xong từ trước, không phải việc cần làm** — đọc `wiki/Glossary.md` xác nhận đầy đủ,
chính xác (13 mục thuật ngữ, khớp đúng kiến thức đã tích luỹ suốt các phase trong tài liệu này) — mục
"add a Glossary" trong mô tả tech-debt cũ đã lỗi thời, chỉ đơn giản chưa ai xoá khỏi `wiki/Roadmap.md`.
Đã sửa lại mô tả cho đúng thực tế.

**1 GIF demo (`Home.md`) + 3 screenshot (`Quick-Start.md`, bước 1/2/4): đã thử thật, không chỉ giả
định bị chặn.** Khởi chạy app đã build (`FourHUnfolder` binary), xác nhận qua `System Events` app CÓ
cửa sổ thật (`{name: "FourHUnfolder", windows: 1}`), lấy được toạ độ cửa sổ thật (`{8, 33, 1664, 946}`)
— tức là quyền Accessibility CÓ hoạt động, khác với đánh giá "không xác nhận được" ở Phase 1. Nhưng khi
chụp bằng `screencapture -R` theo đúng toạ độ đó, ảnh chụp lại ra **cửa sổ IDE/terminal của phiên làm
việc này, không phải app** — xác nhận `screencapture` trong môi trường này không map đúng tới cùng
"màn hình" mà `System Events` báo cáo toạ độ (khả năng cao đây là 1 kiểu remote/virtual display, nơi
"màn hình" IDE nhìn thấy khác với nơi ứng dụng GUI thật sự render). Đây là giới hạn **thật của môi
trường**, không phải giả định — đã tự tay xác nhận trước khi kết luận, không đoán liều rồi bỏ cuộc.

**Kết luận:** không tạo ảnh/GIF giả hoặc placeholder rỗng để "coi như xong" — việc này cần 1 người có
phiên desktop thật (không phải qua remote-IDE) để: mở app → load model mẫu → unfold → xếp trang → chụp
màn hình 3 bước + quay 1 đoạn GIF ngắn. Để nguyên placeholder hiện có trong wiki (đã ghi rõ ràng nội
dung cần chụp cho từng vị trí) — không đụng vào, không giả vờ giải quyết được việc không thể làm trong
môi trường này.

---

## Cross-review Phase 7–8 (2026-07-25) — 1 bug thật, đã fix

Đọc lại diff Phase 7+8 một cách hoài nghi. Phase 8 (chỉ đổi docs, không code) không có gì để review
thêm ngoài kiểm tra số liệu khớp với output terminal thật (đã đối chiếu, khớp). Phase 7 tìm ra 1 vấn
đề thật, đã fix ngay trong lượt cross-review này.

| # | Mức độ | Phát hiện | Xử lý |
|---|--------|-----------|-------|
| 1 | 🟡 Bug thật | `FindMirrorPiece`'s `matchToleranceMm` mặc định **cố định 5mm** cho MỌI kích thước model — mô hình nhỏ (vd. tượng nhỏ 20mm) 5mm dung sai quá RỘNG (25% kích thước cả model, dễ nhận nhầm piece sai làm cặp); mô hình lớn (vd. tượng 1-2 mét) 5mm quá HẸP (piece đối xứng thật có thể lệch centroid hơn 5mm do khác biệt tam giác hoá nhỏ giữa 2 bên, bị từ chối oan). Glue code không truyền tolerance riêng, luôn dùng mặc định cứng này | Thêm field `MeshDiagonal` vào `MirrorPlane` (tính sẵn trong `DetectMirrorPlane`, không tốn thêm chi phí tính lại bbox); `FindMirrorPiece`'s tolerance mặc định đổi thành `max(5mm, 2% đường chéo mesh)` khi caller không truyền riêng — glue code trong `PatternCanvasControl.xaml.cs` **không cần đổi gì** (đã không truyền tolerance tường minh từ đầu, tự động hưởng default mới). Thêm 2 test mới xác nhận: model 1000mm chấp nhận lệch 15mm (trong 2%=20mm); model 20mm KHÔNG chấp nhận cùng mức lệch 15mm tuyệt đối (vượt `max(5,20*0.02)=5mm`) — chứng minh tolerance thực sự co giãn theo kích thước, không phải luôn ≥15mm bất kể test data. |

**Kiểm chứng fix (thực thi thật):** `dotnet build -p:EnableWindowsTargeting=true` 0 lỗi. `dotnet test`:
**138/138 pass** (136 + 2 test mới cho hành vi scale-aware tolerance) — không regression trên 9 test
gốc của `SymmetryDetectorTests.cs` (đã cập nhật constructor `MirrorPlane` thêm tham số thứ 3, verify
lại từng test vẫn đúng ý nghĩa ban đầu).

Không tìm thêm bug nào khác trong Phase 7 (glue code, icon tái dùng, thứ tự early-exit đều đã soát kỹ
lúc review lần đầu và giữ nguyên đánh giá đó) hay Phase 8 (chỉ số liệu + docs, không code).

---

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
