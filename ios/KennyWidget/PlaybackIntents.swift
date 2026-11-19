import AppIntents
import Foundation
import WidgetKit

/// Botones del widget (anterior, reproducir/pausa, siguiente).
/// Al ser un `AudioPlaybackIntent`, iOS lo ejecuta dentro de la app (no del
/// widget), así que puede controlar la música directamente.
/// Este archivo pertenece a los dos targets: Runner y KennyWidgetExtension.
@available(iOS 17.0, *)
struct KennyControlIntent: AudioPlaybackIntent {
  static var title: LocalizedStringResource = "Controlar Kenny Music"
  static var isDiscoverable: Bool = false

  @Parameter(title: "Acción")
  var action: String

  init() {}

  init(action: String) {
    self.action = action
  }

  func perform() async throws -> some IntentResult {
    let defaults = UserDefaults(suiteName: SharedStore.group())
    let before = defaults?.string(forKey: SharedStore.dataKey)

    await MainActor.run {
      NotificationCenter.default.post(
        name: Notification.Name("KennyWidgetCommand"),
        object: nil,
        userInfo: ["action": action]
      )
    }

    // iOS redibuja el widget apenas termina este botón. Se espera (máx. 2 s)
    // a que la app guarde la canción nueva, así el widget ya la muestra.
    for _ in 0..<20 {
      try? await Task.sleep(nanoseconds: 100_000_000)
      if defaults?.string(forKey: SharedStore.dataKey) != before { break }
    }
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}
