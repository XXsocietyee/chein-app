import SwiftUI
import SceneKit
import ImageIO
import UIKit

/// Mini-program badge-wall header parity: lit/total caption, play-side focus readback and
/// the empty-wall explore action. Reads nothing; it only summarizes the loaded wall.
struct ObjectBadgeWallParityHeader: View {
    @Environment(\.themeDomain) private var domain
    let wall: ProfileBadgeWall
    let focusBadgeCode: String?
    @Environment(\.growthExploreHomeAction) private var onExploreHome
    @Environment(\.locale) private var locale
    @State private var exploreConsumed = false
    var body: some View {
        let summary = ObjectBadgeWallSummary(wall: wall)
        Section {
            if !wall.isPartial {
                // Album cover: the ring counts up unlocked / total (received rows only); the tiles keep the honest split.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: CYSpacing.lg) {
                        ring(summary)
                        CYCollectedLockedSummary(collected: summary.unlocked, locked: summary.locked)
                            .accessibilityIdentifier("objects.badge.summary")
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        ring(summary)
                        CYCollectedLockedSummary(collected: summary.unlocked, locked: summary.locked)
                            .accessibilityIdentifier("objects.badge.summary")
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                // ObjectBadgeWallPageState.unknown: the medal collection never arrived, so the
                // unlocked / total / waiting counts are an em dash, never a measured 0.
                let counts = ObjectBadgeWallPageState.project(wall).counts
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                    Text(verbatim: "\(counts.unlocked) / \(counts.total)")
                        .cyText(.dataXL).monospacedDigit().foregroundStyle(Theme.Color.textSecondary(in: domain))
                    Text("badgeWall.state.unknownDetail")
                        .cyText(.body).foregroundStyle(Theme.Color.textSecondary(in: domain))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("badgeWall.state.unknownDetail"))
                .accessibilityIdentifier(counts.accessibilityIdentifier)
            }
            if let focus = ObjectBadgeWallFocus.resolve(code: focusBadgeCode, wall: wall) {
                Label { focusText(focus) } icon: { Image(systemName: "scope").accessibilityHidden(true) }
                    .cyText(.body).foregroundStyle(Theme.Color.textSecondary(in: domain))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("objects.badge.focus")
            }
            if wall.isEmpty, let onExploreHome {
                Button("badgeWall.explore") {
                    guard !exploreConsumed else { return }
                    exploreConsumed = true
                    onExploreHome()
                }.buttonStyle(.bordered).cyText(.button).frame(minHeight: 44).disabled(exploreConsumed)
                    .accessibilityIdentifier("objects.badge.explore")
            }
        }
    }
    private func ring(_ summary: ObjectBadgeWallSummary) -> some View {
        CYAlbumProgressRing(value: summary.unlocked, total: summary.total, size: 84,
                            accessibilityLabel: Text(verbatim: ChannelCopy.text("已点亮 \(summary.unlocked) / \(summary.total) 枚徽章",
                                                                                "\(summary.unlocked) of \(summary.total) badges unlocked", locale: locale)))
    }
    @ViewBuilder private func focusText(_ focus: ObjectBadgeWallFocus) -> some View {
        switch focus {
        case .unlocked(let name): Text("badgeWall.focus.onWall \(name)")
        case .locked(let name): Text("badgeWall.focus.locked \(name)")
        case .notOnWall: Text("badgeWall.focus.elsewhere")
        }
    }
}

/// Mini-program badge-3d showroom: loads GLB or approved badge artwork into an interactive SceneKit
/// turntable and automatically falls back to the 2D badge preview when 3D assets are unavailable.
struct ObjectBadgeThreeDEntry: ViewModifier {
    let badge: ProfileBadgeSelection
    let reader: any ProfileReading
    let expectedIdentity: ProfileReadIdentity?
    var media: (any ObjectCardImageLoading)? = nil
    @Environment(\.objectCardMedia) private var envMedia
    @State private var scope = UUID()
    private var parameters: ObjectBadgeDetailParameters? {
        guard case .medal(let medal) = badge, ObjectBadgePresentation.style(medal: medal) == "enamel" else { return nil }
        return ObjectBadgeDetailParameters(query: ["name": medal.medalName, "style": "enamel", "rarity": "1", "img": medal.medalImage],
                                           fallbackName: "")
    }
    func body(content: Content) -> some View {
        content.toolbar {
            if let parameters, expectedIdentity != nil, reader.identity == expectedIdentity {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ObjectBadgeShowroomView(parameters: parameters, expectedScope: scope,
                            currentScope: { reader.identity == expectedIdentity ? scope : UUID() }, media: media ?? envMedia)
                    } label: { Label("badgeWall.threeD.open", systemImage: "cube") }
                        .accessibilityIdentifier("objects.badge.threeD")
                }
            }
        }
    }
}

enum ObjectBadgeShowroomMode: Equatable {
    case loading
    case threeD
    case twoDFallback
}

@MainActor enum ObjectBadgeShowroomSceneFactory {
    static func isModelAssetURL(_ raw: String) -> Bool {
        guard let components = URLComponents(string: raw),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty else { return false }
        return components.path.lowercased().hasSuffix(".glb")
    }

    static func decodeArtwork(_ data: Data) -> UIImage? {
        guard data.count <= ObjectCardMediaPolicy.maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= 32_000_000,
              let image = UIImage(data: data) else { return nil }
        return image
    }

    static func makeMedallionScene(artwork: UIImage?, title: String, style: String, rarity: Int) -> SCNScene? {
        let scene = SCNScene()
        scene.background.contents = CYBadgeShowroomPalette.stageBackground

        let turntable = SCNNode()
        turntable.name = "badgeTurntable"

        let accentColor = CYBadgeShowroomPalette.accent(style: style, rarity: rarity)

        let metal = SCNMaterial()
        metal.lightingModel = .physicallyBased
        metal.diffuse.contents = accentColor
        metal.metalness.contents = 0.85
        metal.roughness.contents = 0.22

        let body = SCNCylinder(radius: 0.72, height: 0.10)
        body.radialSegmentCount = 48
        let faceMaterial = SCNMaterial()
        faceMaterial.lightingModel = .physicallyBased
        faceMaterial.diffuse.contents = artwork ?? emblemPlaceholderImage(title: title, accent: accentColor)
        faceMaterial.metalness.contents = 0.15
        faceMaterial.roughness.contents = 0.30
        body.materials = [metal, faceMaterial, metal]

        let discNode = SCNNode(geometry: body)
        discNode.name = "badgeMedallion"
        discNode.eulerAngles.x = .pi / 2
        turntable.addChildNode(discNode)

        let rim = SCNTorus(ringRadius: 0.73, pipeRadius: 0.045)
        rim.ringSegmentCount = 48
        rim.pipeSegmentCount = 16
        rim.materials = [metal]
        let rimNode = SCNNode(geometry: rim)
        rimNode.eulerAngles.x = .pi / 2
        turntable.addChildNode(rimNode)

        scene.rootNode.addChildNode(turntable)

        let cameraNode = SCNNode()
        cameraNode.name = "showroomCamera"
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 42
        cameraNode.camera?.zNear = 0.05
        cameraNode.camera?.zFar = 50
        cameraNode.position = SCNVector3(0, 0, 2.75)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 650
        scene.rootNode.addChildNode(ambient)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1100
        keyLight.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 6, 0)
        scene.rootNode.addChildNode(keyLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 550
        rimLight.light?.color = accentColor
        rimLight.eulerAngles = SCNVector3(Float.pi / 6, -Float.pi * 0.75, 0)
        scene.rootNode.addChildNode(rimLight)

        return scene
    }

    static func prepareLoadedScene(_ loaded: SCNScene) -> SCNScene? {
        guard !loaded.rootNode.childNodes.isEmpty else { return nil }
        let scene = SCNScene()
        scene.background.contents = CYBadgeShowroomPalette.stageBackground
        let container = SCNNode()
        container.name = "badgeTurntable"
        for child in loaded.rootNode.childNodes {
            container.addChildNode(child.clone())
        }
        let box = container.boundingBox
        if let fit = try? PlayKitModelFit(
            min: (Double(box.min.x), Double(box.min.y), Double(box.min.z)),
            max: (Double(box.max.x), Double(box.max.y), Double(box.max.z)),
            targetMeters: 1.4
        ) {
            container.scale = SCNVector3(Float(fit.scale), Float(fit.scale), Float(fit.scale))
            container.position = SCNVector3(Float(fit.x), Float(fit.y), Float(fit.z))
        }
        scene.rootNode.addChildNode(container)

        let camera = SCNNode()
        camera.name = "showroomCamera"
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 42
        camera.position = SCNVector3(0, 0.2, 2.75)
        scene.rootNode.addChildNode(camera)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 700
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1000
        key.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 6, 0)
        scene.rootNode.addChildNode(key)
        return scene
    }

    private static func emblemPlaceholderImage(title: String, accent: UIColor) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            CYBadgeShowroomPalette.emblemFill.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let ringRect = CGRect(x: 36, y: 36, width: size.width - 72, height: size.height - 72)
            accent.withAlphaComponent(0.32).setStroke()
            let path = UIBezierPath(ovalIn: ringRect)
            path.lineWidth = 14
            path.stroke()
            let label = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2))
            let glyph = label.isEmpty ? "★" : label
            let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withSymbolicTraits(.traitBold)
            let font = descriptor.map { UIFont(descriptor: $0, size: 0) } ?? UIFont.preferredFont(forTextStyle: .largeTitle)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: accent
            ]
            let measured = (glyph as NSString).size(withAttributes: attrs)
            let scale = min(220 / max(measured.width, 1), 220 / max(measured.height, 1))
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.cgContext.scaleBy(x: scale, y: scale)
            (glyph as NSString).draw(at: CGPoint(x: -measured.width / 2, y: -measured.height / 2), withAttributes: attrs)
            ctx.cgContext.restoreGState()
        }
    }
}

@MainActor private struct ObjectBadgeShowroomSCNView: UIViewRepresentable {
    let scene: SCNScene
    let reduceMotion: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        // B3D-2: Reduce Motion stops the idle spin only; the player can still turn the badge by hand.
        view.allowsCameraControl = true
        view.scene = scene
        if let camera = scene.rootNode.childNode(withName: "showroomCamera", recursively: false) {
            view.pointOfView = camera
        }
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        if view.scene !== scene {
            view.scene = scene
            if let camera = scene.rootNode.childNode(withName: "showroomCamera", recursively: false) {
                view.pointOfView = camera
            }
        }
        view.allowsCameraControl = true
        if !reduceMotion, let node = scene.rootNode.childNode(withName: "badgeTurntable", recursively: false), node.action(forKey: "idleSpin") == nil {
            let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12))
            node.runAction(spin, forKey: "idleSpin")
        } else if reduceMotion, let node = scene.rootNode.childNode(withName: "badgeTurntable", recursively: false) {
            node.removeAction(forKey: "idleSpin")
        }
    }
}

@MainActor struct ObjectBadgeShowroomView: View {
    let parameters: ObjectBadgeDetailParameters
    let expectedScope: UUID
    let currentScope: () -> UUID
    var media: (any ObjectCardImageLoading)? = nil
    var glbHosts: Set<String> = []
    var glbLoader: any PlayKitGLBDataLoading = PlayKitGLBDownloader()
    var glbDecoder: any PlayKitGLBSceneDecoding = PlayKitGLBDecoder()

    @Environment(\.objectCardMedia) private var envMedia
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var mode: ObjectBadgeShowroomMode = .loading
    @State private var scene: SCNScene?
    @State private var force2DFallback = false

    private var effectiveMedia: (any ObjectCardImageLoading)? { media ?? envMedia }

    var body: some View {
        Group {
            if currentScope() != expectedScope {
                CYEmptyState(systemImage: "arrow.triangle.2.circlepath", "objects.sessionChanged")
                    .accessibilityIdentifier("objects.badge3d.error.session")
            } else if force2DFallback || mode == .twoDFallback {
                ObjectBadgeRoutePreview(
                    parameters: parameters,
                    expectedScope: expectedScope,
                    currentScope: currentScope,
                    media: effectiveMedia
                )
            } else if mode == .threeD, let scene {
                VStack(spacing: CYSpacing.lg) {
                    ObjectBadgeShowroomSCNView(scene: scene, reduceMotion: reduceMotion)
                        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
                        .accessibilityLabel(Text(verbatim: parameters.name))
                        .accessibilityIdentifier("objects.badge.turntable")
                    VStack(spacing: CYSpacing.xs) {
                        Text(verbatim: parameters.name)
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                        if !parameters.subtitle.isEmpty {
                            Text(verbatim: parameters.subtitle)
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                        // B3D-4: MP stage hint; under Reduce Motion it says the spin is off.
                        Text(reduceMotion ? "objects.badge3d.hint.reduced" : "objects.badge3d.hint.drag")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textTertiary)
                            .accessibilityIdentifier("objects.badge3d.hint")
                    }
                    Spacer(minLength: 0)
                }
                .padding(CYSpacing.pageHorizontal)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cyDomainPageBackground()
                .themeDomain(.player)
                .accessibilityIdentifier("objects.badge3d.ready")
            } else {
                ProgressView("badge3d.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cyDomainPageBackground()
                    .themeDomain(.player)
                    .accessibilityIdentifier("objects.badge3d.loading")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(force2DFallback ? "badge3d.toggle.threeD" : "badge3d.toggle.static") {
                    force2DFallback.toggle()
                    if !force2DFallback && scene == nil {
                        Task { await loadShowroom() }
                    }
                }
                .disabled(mode == .twoDFallback && scene == nil)
                .accessibilityIdentifier("objects.badge.toggleFallback")
            }
        }
        // B3D-3: inline title 徽章 (MP header); the badge name stays under the stage.
        .cyPageTitle("badge3d.title")
        .task(id: "\(expectedScope.uuidString):\(parameters.image):\(parameters.name)") {
            await loadShowroom()
        }
    }

    private func loadShowroom() async {
        guard currentScope() == expectedScope else {
            mode = .twoDFallback
            return
        }
        mode = .loading
        scene = nil

        if ObjectBadgeShowroomSceneFactory.isModelAssetURL(parameters.image),
           let glbURL = PlayKitGLBPolicy.approvedURL(parameters.image, hosts: glbHosts) {
            do {
                let data = try await glbLoader.load(glbURL, approvedHosts: glbHosts)
                let decoded = try await glbDecoder.scene(from: data)
                guard !Task.isCancelled, currentScope() == expectedScope else { return }
                if let prepared = ObjectBadgeShowroomSceneFactory.prepareLoadedScene(decoded) {
                    self.scene = prepared
                    self.mode = .threeD
                    return
                }
            } catch {
                // Fall back to image-backed medallion or 2D card preview cleanly.
            }
        }

        var loadedArtwork: UIImage? = nil
        var imageLoadFailed = false
        if !parameters.image.isEmpty, let loader = effectiveMedia {
            do {
                let bytes = try await loader.image(url: parameters.image)
                guard !Task.isCancelled, currentScope() == expectedScope else { return }
                if let decoded = ObjectBadgeShowroomSceneFactory.decodeArtwork(bytes) {
                    loadedArtwork = decoded
                } else {
                    imageLoadFailed = true
                }
            } catch {
                imageLoadFailed = true
            }
        }

        guard !Task.isCancelled, currentScope() == expectedScope else { return }
        if imageLoadFailed && parameters.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.mode = .twoDFallback
            return
        }

        if let medallion = ObjectBadgeShowroomSceneFactory.makeMedallionScene(
            artwork: loadedArtwork,
            title: parameters.name,
            style: parameters.style,
            rarity: parameters.rarity
        ) {
            self.scene = medallion
            self.mode = .threeD
        } else {
            self.mode = .twoDFallback
        }
    }
}
