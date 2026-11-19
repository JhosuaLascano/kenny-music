import SwiftUI
import WidgetKit

// MARK: - Datos (los escribe la app en el App Group)

struct NowPlaying: Decodable {
  let title: String
  let artist: String
  let playing: Bool
  let color: String  // "#RRGGBB" sacado de la portada
  let hasCover: Bool

  static let sample = NowPlaying(
    title: "Kenny Music", artist: "Pon una canción", playing: false, color: "#B4441A", hasCover: false)
}

enum SharedStore {
  static let defaultGroup = "group.com.ladata.kennyMusic"
  static let dataKey = "now_playing"
  static let coverFile = "widget_cover.jpg"

  static func group() -> String {
    var candidates: [String] = []
    if let alt = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { candidates += alt }
    candidates += provisionedGroups()
    candidates.append(defaultGroup)
    return candidates.first {
      FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
    } ?? defaultGroup
  }

  /// AltStore cambia el nombre del grupo al firmar: se lee el real del perfil.
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

  static func load() -> NowPlaying? {
    guard let json = UserDefaults(suiteName: group())?.string(forKey: dataKey),
          let d = try? JSONDecoder().decode(NowPlaying.self, from: Data(json.utf8)) else { return nil }
    return d
  }

  static func cover() -> UIImage? {
    guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group()) else { return nil }
    return UIImage(contentsOfFile: dir.appendingPathComponent(coverFile).path)
  }
}

extension Color {
  init(hex: String) {
    var v: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    self.init(
      red: Double((v >> 16) & 0xFF) / 255,
      green: Double((v >> 8) & 0xFF) / 255,
      blue: Double(v & 0xFF) / 255)
  }
}

// MARK: - Línea de tiempo

struct Entry: TimelineEntry {
  let date: Date
  let data: NowPlaying
  let cover: UIImage?
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry { Entry(date: Date(), data: .sample, cover: nil) }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(Entry(date: Date(), data: SharedStore.load() ?? .sample, cover: SharedStore.cover()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let e = Entry(date: Date(), data: SharedStore.load() ?? .sample, cover: SharedStore.cover())
    // La app avisa al widget cada vez que cambia la canción o se pausa.
    completion(Timeline(entries: [e], policy: .never))
  }
}

// MARK: - Vista

struct ControlButton: View {
  let action: String
  let symbol: String
  let size: CGFloat

  var body: some View {
    let icon = Image(systemName: symbol)
      .font(.system(size: size, weight: .semibold))
      .foregroundStyle(.white.opacity(0.88))
      .frame(maxWidth: .infinity, minHeight: 36)
    if #available(iOS 17.0, *) {
      Button(intent: KennyControlIntent(action: action)) { icon }
        .buttonStyle(.plain)
    } else {
      Link(destination: URL(string: "kennymusic://open")!) { icon }
    }
  }
}

struct KennyWidgetView: View {
  let entry: Entry

  var body: some View {
    let base = Color(hex: entry.data.color)
    let content = HStack(spacing: 14) {
      Group {
        if let img = entry.cover {
          Image(uiImage: img).resizable().scaledToFill()
        } else {
          ZStack {
            LinearGradient(
              colors: [Color(hex: "#FFAA4D"), Color(hex: "#FF7A1F")],
              startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.note").font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
          }
        }
      }
      .frame(width: 118, height: 118)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(entry.data.title)
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
        Text(entry.data.artist)
          .font(.system(size: 15))
          .foregroundStyle(.white.opacity(0.62))
          .lineLimit(1)
        Spacer(minLength: 6)
        HStack(spacing: 0) {
          ControlButton(action: "prev", symbol: "backward.fill", size: 20)
          ControlButton(action: "toggle", symbol: entry.data.playing ? "pause.fill" : "play.fill", size: 26)
          ControlButton(action: "next", symbol: "forward.fill", size: 20)
        }
      }
      .padding(.vertical, 6)
    }
    let bg = LinearGradient(
      colors: [base, base.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)

    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) { bg }
    } else {
      content.padding().background(bg)
    }
  }
}

@main
struct KennyWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "KennyWidget", provider: Provider()) { entry in
      KennyWidgetView(entry: entry)
    }
    .configurationDisplayName("Kenny Music")
    .description("La canción que suena, con sus controles.")
    .supportedFamilies([.systemMedium])
  }
}
