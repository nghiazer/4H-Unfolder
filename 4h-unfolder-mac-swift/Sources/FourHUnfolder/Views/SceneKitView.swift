import SwiftUI
import SceneKit
import simd

// Native 3D viewport backed by SCNView — hardware-accelerated via Metal.
struct SceneKitView: NSViewRepresentable {
    let mesh: Mesh?

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = SCNScene()
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true          // trackpad orbit / zoom / pan
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .init(white: 0.10, alpha: 1)

        let cam = SCNNode()
        cam.name = "camera"
        cam.camera = SCNCamera()
        cam.position = SCNVector3(0, 0, 5)
        view.scene!.rootNode.addChildNode(cam)
        view.pointOfView = cam

        // Subtle ambient light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 200
        view.scene!.rootNode.addChildNode(ambient)

        return view
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        // Remove old mesh
        scnView.scene?.rootNode.childNodes(passingTest: { n, _ in n.name == "mesh" })
            .forEach { $0.removeFromParentNode() }

        guard let mesh else { return }

        let node = buildNode(from: mesh)
        node.name = "mesh"
        scnView.scene!.rootNode.addChildNode(node)

        // Auto-frame the camera
        let (center, radius) = boundingSphere(of: mesh)
        if let cam = scnView.pointOfView {
            cam.position = SCNVector3(center.x, center.y, center.z + radius * 2.5)
            cam.look(at: SCNVector3(center))
        }
    }

    // MARK: - Geometry helpers

    private func buildNode(from mesh: Mesh) -> SCNNode {
        // Vertices
        let scnVerts: [SCNVector3] = mesh.vertices.map { SCNVector3($0.position.x, $0.position.y, $0.position.z) }
        let src = SCNGeometrySource(vertices: scnVerts)

        // Fan-triangulate each face
        var idx: [Int32] = []
        for face in mesh.faces {
            let v = face.vertices
            for i in 1..<(v.count - 1) {
                idx.append(contentsOf: [Int32(v[0]), Int32(v[i]), Int32(v[i + 1])])
            }
        }
        let el = SCNGeometryElement(indices: idx, primitiveType: .triangles)

        let geo = SCNGeometry(sources: [src], elements: [el])
        let mat = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 0.55, green: 0.78, blue: 1.00, alpha: 1)
        mat.specular.contents = NSColor(white: 0.3, alpha: 1)
        mat.isDoubleSided     = true
        geo.materials = [mat]

        return SCNNode(geometry: geo)
    }

    private func boundingSphere(of mesh: Mesh) -> (SIMD3<Float>, Float) {
        let positions = mesh.vertices.map { $0.position }
        let center    = positions.reduce(.zero, +) / Float(positions.count)
        let radius    = positions.map { simd_length($0 - center) }.max() ?? 1.0
        return (center, max(radius, 0.001))
    }
}

private extension SCNVector3 {
    init(_ v: SIMD3<Float>) { self.init(v.x, v.y, v.z) }
}
