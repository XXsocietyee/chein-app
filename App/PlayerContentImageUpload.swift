import SwiftUI
import PhotosUI
import UIKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// fix-r9 player-content (R9-PC-B3-1, R7-PC-B1-7, R7-PC-C1-6): the MP picks photos with `app.chooseImage`, which uploads each
/// file through `getUploadClient().uploadAll` — multipart `file` + `bizType` (`image_free` when no crop ratio) to
/// `api/common/uploadOSS`, keeping `data.url` (chengyinhub-xcx app.js:654-683, 416-431). Photos are not money.
@MainActor struct PlayerContentImageUploader {
    enum Failure: Error { case notSignedIn, invalidImage, rejected(String?), unknown }

    let configuration: APIConfiguration
    let transport: any HTTPTransport
    let token: () -> String?
    let approvedOrigins: Set<String>

    /// Longest edge sent; the MP's `sizeType: ['compressed']` downsizes before upload too.
    static let maximumEdge: CGFloat = 2048

    /// `bizType` follows the MP crop ratio (`image_free` without one; r10 C-F8b topic cover `image_3_4`, gallery `image_16_9`).
    func upload(jpeg: Data, bizType: String = "image_free") async throws -> String {
        guard let auth = token(), AuthRequestBuilder.isValidToken(auth) else { throw Failure.notSignedIn }
        let boundary = "player-content-image-" + UUID().uuidString
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("api/common/uploadOSS"))
        request.httpMethod = "POST"; request.timeoutInterval = 30; request.httpShouldHandleCookies = false
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"bizType\"\r\n\r\n\(bizType)\r\n".utf8)
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let (data, status) = try await transport.send(request)
        guard data.count <= 1024 * 1024, let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { throw Failure.unknown }
        if envelope.code != 200 { throw Failure.rejected(envelope.msg) }
        guard (200..<300).contains(status), let raw = envelope.url, let url = URL(string: raw),
              RetainedImageOrigin.accepts(url, origins: approvedOrigins) else { throw Failure.unknown }
        return url.absoluteString
    }

    /// Loads, downsizes and uploads each picked item in order. Returns the URLs that uploaded and how many failed
    /// (MP shows `r.failures[0].msg || '上传失败'` when any file fails).
    func upload(items: [PhotosPickerItem], bizType: String = "image_free",
                aspect: (width: Int, height: Int)? = nil) async -> (urls: [String], failed: Int, message: String?) {
        var urls: [String] = []
        var failed = 0
        var message: String?
        for item in items {
            do {
                guard let raw = try await item.loadTransferable(type: Data.self),
                      let jpeg = Self.jpeg(from: raw, aspect: aspect) else { throw Failure.invalidImage }
                urls.append(try await upload(jpeg: jpeg, bizType: bizType))
            } catch Failure.rejected(let text) {
                failed += 1; if message == nil { message = text }
            } catch {
                failed += 1
            }
        }
        return (urls, failed, message)
    }

    /// `aspect` centre-crops to the MP crop ratio before downsizing (r10 C-F8b: cover 3:4, gallery 16:9).
    static func jpeg(from data: Data, aspect: (width: Int, height: Int)? = nil) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        var source = CGRect(origin: .zero, size: image.size)
        if let aspect, aspect.width > 0, aspect.height > 0, source.width > 0, source.height > 0 {
            let ratio = CGFloat(aspect.width) / CGFloat(aspect.height)
            if source.width / source.height > ratio {
                let width = source.height * ratio
                source = CGRect(x: (source.width - width) / 2, y: 0, width: width, height: source.height)
            } else {
                let height = source.width / ratio
                source = CGRect(x: 0, y: (source.height - height) / 2, width: source.width, height: height)
            }
        }
        let longest = max(source.width, source.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maximumEdge / longest)
        let target = CGSize(width: (source.width * scale).rounded(), height: (source.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(x: -source.minX * scale, y: -source.minY * scale,
                                  width: image.size.width * scale, height: image.size.height * scale))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    private struct Envelope: Decodable { let code: Int; let msg: String?; let url: String? }
}

private struct PlayerContentImageUploaderKey: EnvironmentKey {
    static let defaultValue: PlayerContentImageUploader? = nil
}

extension EnvironmentValues {
    /// Host-supplied MP `chooseImage` uploader; nil (signed out / no region) keeps photo rows disabled.
    var playerContentImageUploader: PlayerContentImageUploader? {
        get { self[PlayerContentImageUploaderKey.self] }
        set { self[PlayerContentImageUploaderKey.self] = newValue }
    }
}

extension AppSession {
    func makePlayerContentImageUploader() -> PlayerContentImageUploader? {
        guard let configuration = regionalConfiguration?.apiConfiguration else { return nil }
        let origins = RetainedImageOrigin.configured(apiBase: configuration.baseURL,
            extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String)
        return PlayerContentImageUploader(configuration: configuration, transport: runtimeHTTPTransport,
            token: { [weak self] in self?.currentRetainedImageCredentials?.token }, approvedOrigins: origins)
    }
}
