import AppIntents
import Foundation

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
    await MainActor.run {
      NotificationCenter.default.post(
        name: Notification.Name("KennyWidgetCommand"),
        object: nil,
        userInfo: ["action": action]
      )
    }
    return .result()
  }
}
