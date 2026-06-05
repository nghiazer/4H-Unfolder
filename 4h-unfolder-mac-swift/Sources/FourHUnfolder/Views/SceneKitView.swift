import SwiftUI
import SceneKit
import simd

// MARK: - Native 3D viewport backed by SCNView (Metal-accelerated)
//
// Features:
//  - Per-vertex normals (averaged from adjacent face normals) for smooth shading
//  - Selected face orange highlight (separate SCNNode, renderingOrder=10)
//  - Camera auto-framed on mesh load / update
//  - Ambient + directional lighting

struct SceneKitView: NSViewRepresentable {
    let mesh: Mesh?
    let selectedFaceId: Int?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.allowsCameraControl  = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode     = .multisampling4X
        view.backgroundColor      = NSColor(white: 0.10, alpha: 1)
        view.showsStatistics      = false

        let scene = view.scene!

        // Camera
        let camNode = SCNNode(); camNode.name = "camera"
        camNode.camera = SCNCamera()
        camNode.camera!.fieldOfView = 60
        camNode.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(camNode)
        view.pointOfView = camNode

        // Ambient light
        let ambNode = SCNNode(); ambNode.name = "ambient"
        ambNode.light = SCNLight()
        ambNode.light!.type      = .ambient
        ambNode.light!.intensity = 250
        ambNode.light!.color     = NSColor.white
        scene.rootNode.addChildNode(ambNode)

        // Directional light
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
        // Remove previous mesh + selection nodes
        root.childNodes(passingTest: { n, _ in
            n.name == "mesh_main" || n.name == "mesh_sel"
        }).forEach { $0.removeFromParentNode() }

        guard let mesh, mesh.isValid else { return }

        root.addChildNode(buildMainNode(mesh: mesh))

        if let selId = selectedFaceId {
            if let selNode = buildSelectionNode(mesh: mesh, faceId: selId) {
                root.addChildNode(selNode)
            }
        }

        autoFrameCamera(scnView, mesh: mesh)
    }

    // MARK: - Mesh geometry

    private func buildMainNode(mesh: Mesh) -> SCNNode {
        // Compute per-face normals, accumulate into per-vertex normals
        var accum = [SIMD3<Float>](repeating: .zero, count: mesh.vertices.count)
        for face in mesh.faces {
            guard face.a < mesh.vertices.count,
                  face.b < mesh.vertices.count,
                  face.c < mesh.vertices.count else { continue }
            let n = computeFaceNormal(mesh, face)
            accum[face.a] += n; accum[face.b] += n; accum[face.c] += n
        }

        let positions = mesh.vertices.map { SCNVector3($0.position) }
        let normals   = accum.map { v -> SCNVector3 in
            let len = simd_length(v)
            return len > 1e-10 ? SCNVector3(v / len) : SCNVector3(0, 1, 0)
        }

        var idx: [Int32] = []
        idx.reserveCapacity(mesh.faces.count * 3)
        for face in mesh.faces {
            idx.append(Int32(face.a)); idx.append(Int32(face.b)); idx.append(Int32(face.c))
        }

        let posSrc  = SCNGeometrySource(vertices: positions)
        let normSrc = SCNGeometrySource(normals: normals)
        let element = SCNGeometryElement(indices: idx, primitiveType: .triangles)
        let geo     = SCNGeometry(sources: [posSrc, normSrc], elements: [element])

        let mat = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 0.55, green: 0.78, blue: 1.00, alpha: 1)
        mat.specular.contents = NSColor(white: 0.4, alpha: 1)
        mat.shininess         = 60
        mat.isDoubleSided     = true
        mat.lightingModel     = .phong
        geo.materials         = [mat]

        let node = SCNNode(geometry: geo); node.name = "mesh_main"
        return node
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
        mat.diffuse.contents   = NSColor.orange.withAlphaComponent(0.65)
        mat.emission.contents  = NSColor.orange.withAlphaComponent(0.25)
        mat.isDoubleSided      = true
        mat.writesToDepthBuffer = false
        geo.materials = [mat]

        let node = SCNNode(geometry: geo); node.name = "mesh_sel"
        node.renderingOrder = 10   // draw on top of main mesh
        // Offset slightly along face normal to avoid z-fighting
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
