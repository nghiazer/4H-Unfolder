import SwiftUI
import SceneKit
import CoreGraphics
import simd
@testable import FourHUnfolderCore

// MARK: - Native 3D viewport backed by SCNView (Metal-accelerated)
//
// Features:
//  - Expanded vertex buffer (un-indexed) — each face-vertex carries its own UV
//  - One SCNGeometryElement + SCNMaterial per materialId group (multi-material)
//  - Texture from textureCache (CGImage) or solid blue fallback
//  - Per-vertex smooth normals (averaged face normals)
//  - Selected face orange highlight (renderingOrder=10)
//  - Camera auto-framed on mesh update
//  - UV convention: stored UVs have Y=0 at top. SceneKit needs Y=0 at bottom → V-flip applied.

struct SceneKitView: NSViewRepresentable {
    let mesh: Mesh?
    let selectedFaceId: Int?
    let textureCache: [Int: CGImage]

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.allowsCameraControl      = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode         = .multisampling4X
        view.backgroundColor          = NSColor(white: 0.10, alpha: 1)
        view.showsStatistics          = false

        let scene = view.scene!

        let camNode = SCNNode(); camNode.name = "camera"
        camNode.camera = SCNCamera()
        camNode.camera!.fieldOfView = 60
        camNode.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(camNode)
        view.pointOfView = camNode

        let ambNode = SCNNode(); ambNode.name = "ambient"
        ambNode.light = SCNLight()
        ambNode.light!.type      = .ambient
        ambNode.light!.intensity = 250
        ambNode.light!.color     = NSColor.white
        scene.rootNode.addChildNode(ambNode)

        let dirNode = SCNNode(); dirNode.name = "sun"
        dirNode.light = SCNLight()
        dirNode.light!.type      = .directional
        dirNode.light!.intensity = 800
        dirNode.light!.color     = NSColor.white
        dirNode.eulerAngles      = SCNVector3(-0.6, 0.8, 0)
        scene.rootNode.addChildNode(dirNode)

        return view
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        let root = scnView.scene!.rootNode
        root.childNodes(passingTest: { n, _ in
            n.name == "mesh_main" || n.name == "mesh_sel"
        }).forEach { $0.removeFromParentNode() }

        guard let mesh, mesh.isValid else { return }

        root.addChildNode(buildMainNode(mesh: mesh))

        if let selId = selectedFaceId,
           let selNode = buildSelectionNode(mesh: mesh, faceId: selId) {
            root.addChildNode(selNode)
        }

        autoFrameCamera(scnView, mesh: mesh)
    }

    // MARK: - Multi-material mesh geometry

    private func buildMainNode(mesh: Mesh) -> SCNNode {
        // Accumulate per-vertex smooth normals from face normals
        var vertNormAccum = [SIMD3<Float>](repeating: .zero, count: mesh.vertices.count)
        for face in mesh.faces {
            let n = computeFaceNormal(mesh, face)
            if face.a < mesh.vertices.count { vertNormAccum[face.a] += n }
            if face.b < mesh.vertices.count { vertNormAccum[face.b] += n }
            if face.c < mesh.vertices.count { vertNormAccum[face.c] += n }
        }

        // Expanded arrays: 3 independent entries per face (no vertex sharing across triangles)
        var positions: [SCNVector3] = []
        var normals:   [SCNVector3] = []
        var uvCoords:  [CGPoint]    = []
        positions.reserveCapacity(mesh.faces.count * 3)
        normals.reserveCapacity(mesh.faces.count * 3)
        uvCoords.reserveCapacity(mesh.faces.count * 3)

        var groups: [Int: [Int32]] = [:]  // materialId → sequential vertex indices

        for (fi, face) in mesh.faces.enumerated() {
            guard face.a < mesh.vertices.count,
                  face.b < mesh.vertices.count,
                  face.c < mesh.vertices.count else { continue }

            let base = Int32(positions.count)

            positions.append(SCNVector3(mesh.vertices[face.a].position))
            positions.append(SCNVector3(mesh.vertices[face.b].position))
            positions.append(SCNVector3(mesh.vertices[face.c].position))

            normals.append(normalizedSCN(vertNormAccum[face.a]))
            normals.append(normalizedSCN(vertNormAccum[face.b]))
            normals.append(normalizedSCN(vertNormAccum[face.c]))

            // UV: stored with Y=0 at top; SceneKit needs Y=0 at bottom → V-flip (1 - v)
            let faceUV = (fi < mesh.faceUVs.count && !mesh.uvs.isEmpty)
                ? mesh.faceUVs[fi] : (ua: 0, ub: 0, uc: 0)
            uvCoords.append(sceneKitUV(faceUV.ua, mesh: mesh))
            uvCoords.append(sceneKitUV(faceUV.ub, mesh: mesh))
            uvCoords.append(sceneKitUV(faceUV.uc, mesh: mesh))

            groups[face.materialId, default: []].append(contentsOf: [base, base + 1, base + 2])
        }

        let posSrc  = SCNGeometrySource(vertices: positions)
        let normSrc = SCNGeometrySource(normals: normals)
        let uvSrc   = SCNGeometrySource(textureCoordinates: uvCoords)

        let sortedMatIds = groups.keys.sorted()
        let elements  = sortedMatIds.map { SCNGeometryElement(indices: groups[$0]!, primitiveType: .triangles) }
        let materials = sortedMatIds.map { makeMaterial(matId: $0) }

        let geo       = SCNGeometry(sources: [posSrc, normSrc, uvSrc], elements: elements)
        geo.materials = materials

        let node = SCNNode(geometry: geo); node.name = "mesh_main"
        return node
    }

    private func sceneKitUV(_ uvIdx: Int, mesh: Mesh) -> CGPoint {
        guard uvIdx < mesh.uvs.count else { return .zero }
        let v = mesh.uvs[uvIdx]
        return CGPoint(x: CGFloat(v.x), y: CGFloat(1.0 - v.y))
    }

    private func normalizedSCN(_ v: SIMD3<Float>) -> SCNVector3 {
        let len = simd_length(v)
        return len > 1e-10 ? SCNVector3(v / len) : SCNVector3(0, 1, 0)
    }

    private func makeMaterial(matId: Int) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.isDoubleSided     = true
        mat.lightingModel     = .phong
        mat.specular.contents = NSColor(white: 0.3, alpha: 1)
        mat.shininess         = 50
        if let img = textureCache[matId] {
            mat.diffuse.contents = img
        } else {
            mat.diffuse.contents = NSColor(red: 0.55, green: 0.78, blue: 1.00, alpha: 1)
        }
        return mat
    }

    // MARK: - Selection highlight

    private func buildSelectionNode(mesh: Mesh, faceId: Int) -> SCNNode? {
        guard faceId < mesh.faces.count else { return nil }
        let face = mesh.faces[faceId]
        guard face.a < mesh.vertices.count,
              face.b < mesh.vertices.count,
              face.c < mesh.vertices.count else { return nil }

        let positions = mesh.vertices.map { SCNVector3($0.position) }
        let posSrc = SCNGeometrySource(vertices: positions)
        let el     = SCNGeometryElement(
            indices: [Int32(face.a), Int32(face.b), Int32(face.c)],
            primitiveType: .triangles
        )
        let geo = SCNGeometry(sources: [posSrc], elements: [el])

        let mat = SCNMaterial()
        mat.diffuse.contents    = NSColor.orange.withAlphaComponent(0.65)
        mat.emission.contents   = NSColor.orange.withAlphaComponent(0.25)
        mat.isDoubleSided       = true
        mat.writesToDepthBuffer = false
        geo.materials = [mat]

        let node = SCNNode(geometry: geo); node.name = "mesh_sel"
        node.renderingOrder = 10
        let n = computeFaceNormal(mesh, face)
        node.position = SCNVector3(n.x * 0.002, n.y * 0.002, n.z * 0.002)
        return node
    }

    // MARK: - Camera framing

    private func autoFrameCamera(_ scnView: SCNView, mesh: Mesh) {
        let (center, radius) = boundingSphere(of: mesh)
        guard let cam = scnView.pointOfView else { return }
        let dist = radius * 2.5
        cam.position = SCNVector3(center.x, center.y, center.z + dist)
        cam.look(at: SCNVector3(center))
    }

    // MARK: - Geometry helpers

    private func computeFaceNormal(_ mesh: Mesh, _ face: Face) -> SIMD3<Float> {
        let a = mesh.vertices[face.a].position
        let b = mesh.vertices[face.b].position
        let c = mesh.vertices[face.c].position
        let n = simd_cross(b - a, c - a)
        let len = simd_length(n)
        return len > 1e-10 ? n / len : SIMD3(0, 1, 0)
    }

    private func boundingSphere(of mesh: Mesh) -> (center: SIMD3<Float>, radius: Float) {
        guard !mesh.vertices.isEmpty else { return (.zero, 1) }
        let positions = mesh.vertices.map { $0.position }
        let center    = positions.reduce(.zero, +) / Float(positions.count)
        let radius    = positions.map { simd_length($0 - center) }.max() ?? 1.0
        return (center, max(radius, 0.001))
    }
}

// MARK: - SCNVector3 convenience

private extension SCNVector3 {
    init(_ v: SIMD3<Float>) { self.init(v.x, v.y, v.z) }
}
