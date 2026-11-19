import SwiftUI
import WidgetKit

// MARK: - Datos (los escribe la app en el App Group)

struct NowPlaying: Decodable {
  let title: String
  let artist: String
  let playing: Bool
  let color: String  // "#RRGGBB" sacado de la portada
  let hasCover: Bool
  // Para la barra de progreso (milisegundos).
  let position: Double?
  let duration: Double?
  let updatedAt: Double?

  static let sample = NowPlaying(
    title: "Kenny Music", artist: "Pon una canción", playing: false, color: "#B4441A",
    hasCover: false, position: 0, duration: 0, updatedAt: 0)
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

func mmss(_ seconds: Double) -> String {
  let s = max(0, Int(seconds.rounded()))
  return String(format: "%d:%02d", s / 60, s % 60)
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
    // La app avisa al widget cada vez que cambia la canción, se pausa o se adelanta.
    completion(Timeline(entries: [e], policy: .never))
  }
}

// MARK: - Vista (diseño A: portada difuminada + progreso)

struct ControlButton: View {
  let action: String
  let symbol: String
  let size: CGFloat

  var body: some View {
    let icon = Image(systemName: symbol)
      .font(.system(size: size, weight: .semibold))
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 30)
    if #available(iOS 17.0, *) {
      Button(intent: KennyControlIntent(action: action)) { icon }
        .buttonStyle(.plain)
    } else {
      Link(destination: URL(string: "kennymusic://open")!) { icon }
    }
  }
}

/// Barra de progreso: si está sonando avanza sola (sin que la app la toque).
struct ProgressRow: View {
  let data: NowPlaying

  var body: some View {
    let dur = (data.duration ?? 0) / 1000
    let pos = (data.position ?? 0) / 1000
    VStack(spacing: 3) {
      if data.playing, dur > 0, let at = data.updatedAt, at > 0 {
        let start = Date(timeIntervalSince1970: at / 1000 - pos)
        let end = start.addingTimeInterval(dur)
        ProgressView(timerInterval: start...end, countsDown: false) {
          EmptyView()
        } currentValueLabel: {
          EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(.white)
        HStack {
          Text(start, style: .timer).monospacedDigit()
          Spacer()
          Text(mmss(dur))
        }
      } else {
        ProgressView(value: dur > 0 ? min(pos / dur, 1) : 0)
          .progressViewStyle(.linear)
          .tint(.white)
        HStack {
          Text(mmss(pos))
          Spacer()
          Text(mmss(dur))
        }
      }
    }
    .font(.system(size: 10, weight: .medium))
    .foregroundStyle(.white.opacity(0.65))
  }
}

struct BlurredBackground: View {
  let entry: Entry

  var body: some View {
    ZStack {
      Color(hex: entry.data.color)
      if let img = entry.cover {
        Image(uiImage: img)
          .resizable()
          .scaledToFill()
          .blur(radius: 22)
          .scaleEffect(1.3)
      }
      Color.black.opacity(0.28)
    }
  }
}

struct KennyWidgetView: View {
  let entry: Entry

  var body: some View {
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
      .frame(width: 116, height: 116)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

      VStack(alignment: .leading, spacing: 0) {
        Text("KENNY MUSIC")
          .font(.system(size: 10, weight: .bold))
          .kerning(0.8)
          .foregroundStyle(.white.opacity(0.6))
        Text(entry.data.title)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .padding(.top, 3)
        Text(entry.data.artist)
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.68))
          .lineLimit(1)
        Spacer(minLength: 4)
        ProgressRow(data: entry.data)
        Spacer(minLength: 4)
        HStack(spacing: 0) {
          ControlButton(action: "prev", symbol: "backward.fill", size: 18)
          ControlButton(action: "toggle", symbol: entry.data.playing ? "pause.fill" : "play.fill", size: 24)
          ControlButton(action: "next", symbol: "forward.fill", size: 18)
        }
      }
      .padding(.vertical, 2)
    }

    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) { BlurredBackground(entry: entry) }
    } else {
      content.padding().background(BlurredBackground(entry: entry))
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
    .description("La canción que suena, con su progreso y controles.")
    .supportedFamilies([.systemMedium])
  }
}
