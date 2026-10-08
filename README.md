# CrossShare

A Flutter application for sharing files and text over a local network. Native devices discover peers using UDP announcements and an HTTP subnet scan. A native host also serves a browser download portal.

## Architecture

The existing layered structure fits the size of this application. Keep dependencies flowing from presentation to application coordination to services and models:

- `lib/main.dart`: Flutter initialization and the Riverpod scope.
- `lib/app.dart`: app configuration, themes, and the home screen.
- `lib/ui/screens/` and `lib/ui/widgets/`: rendering, navigation, dialogs, and platform picker interaction.
- `lib/providers/session_provider.dart`: `AppSession`, which starts networking, synchronizes settings, and coordinates transfer state and history.
- `lib/providers/device_providers.dart`: current device identity and network information.
- `lib/providers/transfer_providers.dart`: selections, connected peer, active progress, and history.
- `lib/providers/settings_providers.dart`: user settings.
- `lib/providers/service_providers.dart`: service construction, dependency injection, discovery stream, and resource disposal.
- `lib/providers/app_providers.dart`: public exports for existing UI imports.
- `lib/services/`: UDP discovery, HTTP receiver, outgoing transfer engine, network information, and isolated browser portal markup.
- `lib/models/`: device, file, and transfer data.
- `lib/utils/file_metadata.dart`: shared file categories and byte formatting.

Widgets update provider state. `AppSession` synchronizes that state with services; avoid updating both a provider and a service in the same UI handler. Services never depend on widgets or Riverpod. Inject services through provider overrides when testing. ProviderScope owns sockets, timers, discovery streams, and the outgoing HTTP client.

Startup resolves device information, starts the receiver, publishes the actual bound port, then starts discovery. `HomeScreen` supplies the incoming approval dialog and displays startup errors. Received files require an approved preparation request; progress covers the entire batch, and history contains the received local paths. A receiver accepts one incoming batch at a time. An approved batch with no upload activity expires after two minutes; an upload in progress has no idle expiry.

## Validation

```sh
flutter pub get
flutter analyze
flutter test
```

The widget test overrides `AppSession` to avoid plugins and LAN scans. Service regression tests bind an ephemeral local HTTP port and use a temporary download directory. They cover UTF-8 text batches, aggregate completion, unapproved uploads, and missing source files.

## Current boundaries

- Settings, device identity, and history live in memory and reset on restart.
- Native networking uses `dart:io`; the generated Flutter web target is not a supported sending/receiving client. Browser access uses a native device's `/web` portal.
- Subnet scan fallback assumes IPv4 `/24` and probes port 53317. UDP announcements advertise a receiver's dynamically assigned port.
- Transfers use plain LAN HTTP without peer authentication or encryption. The prepare step controls acceptance but does not authenticate a peer.
- Cancellation of an outgoing upload is supported; the prepare HTTP request is not cancellable. Receiver abandonment is cleared by its idle timeout.
- Interrupted uploads can leave partial files, and receiving an existing filename overwrites it. Resumable transfers and collision handling need a separate design.
- Mobile storage permissions, platform builds, and real transfers between devices still require testing on the intended devices.

Add repositories for persisted settings/history when persistence is needed. A larger app may warrant feature folders, but extra interfaces and layers are unnecessary for the current scope.
