# Kenny Music

Reproductor de música para **Android** y **iPhone**, hecho con Flutter. Escucha las canciones que ya tienes descargadas, arma tus playlists, marca tus favoritas y sigue la letra de la canción mientras suena.

## Qué hace

- **Tu música, sin internet.** Reproduce archivos mp3, m4a, flac y wav.
  - En **Android** busca solo las canciones que hay en el celular (botón *Buscar música en el celular*).
  - En **iPhone** las eliges desde la app Archivos (botón *Importar archivos*). Se guarda una copia dentro de Kenny Music.
- **Playlists.** Puedes crear, renombrar y borrar playlists, agregar o quitar canciones y mantener presionada una canción para cambiarla de lugar.
- **Favoritas.** La estrella aparece en cada canción y en el reproductor.
- **Segundo plano.** La música sigue sonando con la pantalla apagada o mientras usas otra app. Se controla desde la notificación y desde la pantalla de bloqueo.
- **Letras sincronizadas.** La línea que suena se resalta y la letra avanza sola. Si tocas una línea, la canción salta a ese momento. Kenny Music busca la letra en este orden:
  1. un archivo `.lrc` con el mismo nombre que la canción (por ejemplo `Mi canción.mp3` y `Mi canción.lrc`);
  2. la letra guardada dentro del archivo de música;
  3. internet, en [LRCLIB](https://lrclib.net) (gratis y sin cuenta), usando artista, título y duración.

  La letra encontrada en internet se guarda para usarla sin conexión. Si no aparece, la app muestra *Letra no disponible*.
- **Crossfade.** Al terminar una canción, la siguiente empieza mientras la anterior baja de volumen. Se ajusta de 0 a 12 segundos.
- **Apariencia.** Para el fondo del reproductor puedes elegir entre *portada difuminada*, *degradado* con el color de la portada o *color sólido*. El color de acento también se cambia (naranja Kenny, violeta, oro, menta, azul o rosa).
- También tiene aleatorio, repetir (todo o una canción), cola de reproducción, búsqueda y vista por artistas y álbumes.

## Instalar

### Android

1. Pasa el archivo `KennyMusic-v1.0.0.apk` al celular.
2. Ábrelo y permite *instalar apps de origen desconocido* si el celular lo pide.
3. La primera vez, toca **Buscar música en el celular** y acepta el permiso de música.

Las actualizaciones se instalan encima de la versión anterior y conservan tus playlists y favoritas.

### iPhone (con AltStore)

1. En GitHub, entra a **Actions → iOS (.ipa para AltStore)** y descarga el último `KennyMusic-iOS` (dentro está el `.ipa`). Si quieres compilar uno nuevo, usa **Run workflow**.
2. Instálalo con AltStore, como El Dato.
3. Con un Apple ID gratis, la app caduca cada 7 días. Para renovarla, abre AltStore con la PC y AltServer en la misma red Wi-Fi.

## Tecnología

- Flutter 3.47.9 / Dart 3.13
- `just_audio` y `audio_service` para la reproducción, la notificación y la pantalla de bloqueo
- `audio_metadata_reader` para leer título, artista, portada y letra de los archivos
- `file_picker` para importar en iPhone y `permission_handler` para el permiso de música en Android
- La API pública de LRCLIB para las letras

### Compilar en Windows

```powershell
flutter pub get
flutter build apk --release
```

El APK queda en `build\app\outputs\flutter-apk\app-release.apk`.

La firma usa `android/kenny_music_release.jks` y `android/key.properties`. Por seguridad, esos dos archivos **no se suben a GitHub**: guárdalos en un lugar seguro. Si se pierden, las actualizaciones ya no se podrán instalar encima de la app actual.

El `.ipa` de iPhone se compila en GitHub Actions (`.github/workflows/ios.yml`), en una Mac de GitHub, porque no hace falta tener una Mac.

---

Hecho por LA DATA.
