import Flutter
import UIKit
import WidgetKit

/// Puente entre Flutter y el widget de Kenny Music:
/// - "update" (Flutter → iOS): guarda la canción actual y su portada en el
///   App Group y refresca el widget.
/// - "command" (iOS → Flutter): llega cuando se toca un botón del widget
///   ("prev", "toggle", "next").
final class WidgetBridge: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  // Todo lo pesado (achicar la portada, sacar su color) se hace en esta cola
  // de fondo: así nunca frena la pantalla y funciona con la app en segundo plano.
  private let work = DispatchQueue(label: "kenny.widget", qos: .utility)
  private var lastCover: String?
  private var lastColor = "#B4441A"

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WidgetBridge()
    let channel = FlutterMethodChannel(name: "kenny/widget", binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    NotificationCenter.default.addObserver(
      instance, selector: #selector(onCommand(_:)),
      name: Notification.Name("KennyWidgetCommand"), object: nil)
  }

  @objc private func onCommand(_ note: Notification) {
    guard let action = note.userInfo?["action"] as? String else { return }
    channel?.invokeMethod("command", arguments: action)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "update", let args = call.arguments as? [String: Any] else {
      result(FlutterMethodNotImplemented)
      return
    }
    result(nil)  // Flutter no espera: el resto se hace en segundo plano.
    work.async { [self] in
      let coverPath = args["cover"] as? String
      let hasCover = saveCover(coverPath)
      let data: [String: Any] = [
        "title": args["title"] as? String ?? "Kenny Music",
        "artist": args["artist"] as? String ?? "",
        "playing": args["playing"] as? Bool ?? false,
        "color": hasCover ? lastColor : "#B4441A",
        "hasCover": hasCover,
        "position": args["position"] as? Double ?? 0,
        "duration": args["duration"] as? Double ?? 0,
        "updatedAt": args["updatedAt"] as? Double ?? 0,
      ]
      if let json = try? JSONSerialization.data(withJSONObject: data),
         let text = String(data: json, encoding: .utf8) {
        UserDefaults(suiteName: SharedStore.group())?.set(text, forKey: SharedStore.dataKey)
      }
      DispatchQueue.main.async {
        if #available(iOS 14.0, *) { WidgetCenter.shared.reloadAllTimelines() }
      }
    }
  }

  /// Copia la portada (achicada) al App Group y calcula su color.
  /// Se ejecuta siempre en la cola `work`.
  private func saveCover(_ path: String?) -> Bool {
    guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStore.group())
    else { return false }
    let dest = dir.appendingPathComponent(SharedStore.coverFile)
    guard let path = path, let img = UIImage(contentsOfFile: path) else {
      try? FileManager.default.removeItem(at: dest)
      lastCover = nil
      return false
    }
    if path == lastCover { return true }
    let side: CGFloat = 300
    let scale = side / max(img.size.width, img.size.height, 1)
    let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      img.draw(in: CGRect(origin: .zero, size: size))
    }
    try? small.jpegData(compressionQuality: 0.85)?.write(to: dest)
    lastColor = Self.backgroundColor(of: small)
    lastCover = path
    return true
  }

  /// Color promedio de la portada, algo más oscuro y vivo, como fondo.
  private static func backgroundColor(of img: UIImage) -> String {
    guard let cg = img.cgImage else { return "#B4441A" }
    var px = [UInt8](repeating: 0, count: 4)
    guard let ctx = CGContext(
      data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return "#B4441A" }
    ctx.interpolationQuality = .medium
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(red: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255,
            blue: CGFloat(px[2]) / 255, alpha: 1).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    let c = UIColor(hue: h, saturation: min(s * 1.15, 0.9),
                    brightness: min(max(b * 0.7, 0.25), 0.5), alpha: 1)
    var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
    c.getRed(&r, green: &g, blue: &bl, alpha: &a)
    return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(bl * 255))
  }
}

/// App Group compartido con el widget. AltStore cambia su nombre al firmar,
/// por eso se busca el grupo real en tiempo de ejecución.
enum SharedStore {
  static let defaultGroup = "group.com.ladata.kennyMusic"
  static let dataKey = "now_playing"
  static let coverFile = "widget_cover.jpg"
  private static var cached: String?

  static func group() -> String {
    if let c = cached { return c }
    var candidates: [String] = []
    if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { candidates += alt }
    candidates += provisionedGroups()
    candidates.append(defaultGroup)
    let found = candidates.first {
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
    } ?? defaultGroup
    cached = found
    return found
  }

  private static func provisionedGroups() -> [String] {
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .isoLatin1),
          let start = text.range(of: "<?xml"),
          let end = text.range(of: "</plist>") else { return [] }
    let plist = String(text[start.lowerBound..<end.upperBound])
    guard let obj = try? PropertyListSerialization.propertyList(from: Data(plist.utf8), options: [], format: nil),
          let dict = obj as? [String: Any],
          let ent = dict["Entitlements"] as? [String: Any],
          let groups = ent["com.apple.security.application-groups"] as? [String] else { return [] }
    return groups
  }
}
