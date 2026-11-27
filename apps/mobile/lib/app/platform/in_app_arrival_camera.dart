import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:feature_host/feature_host.dart' as host;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Why the camera could not open.
enum CameraProblem {
  /// Denied this time: asking again may work.
  denied,

  /// Denied permanently (or restricted): only Settings can change it.
  deniedForever,

  /// This device has no front camera.
  noFrontCamera,

  /// Anything else (camera busy, hardware error).
  failed,
}

final class CameraOpenException implements Exception {
  const CameraOpenException(this.problem);
  final CameraProblem problem;
}

/// The camera operations the arrival page needs (a seam over the `camera`
/// plugin, so widget tests need no device).
abstract interface class ArrivalCameraSession {
  /// Opens the FRONT camera. Throws [CameraOpenException].
  Future<void> open();

  /// The live preview (valid after [open]).
  Widget preview();

  /// Preview width ÷ height in portrait.
  double get aspectRatio;

  /// One JPEG still.
  Future<Uint8List> takePicture();

  /// Releases the camera (idempotent).
  Future<void> close();
}

typedef ArrivalCameraSessionFactory = ArrivalCameraSession Function();

/// [ArrivalCameraSession] over the `camera` plugin (CameraX on Android).
final class PluginArrivalCameraSession implements ArrivalCameraSession {
  CameraController? _c;

  @override
  Future<void> open() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw CameraOpenException(await _problemFor(e));
    }
    final front = cameras
        .where((c) => c.lensDirection == CameraLensDirection.front)
        .firstOrNull;
    if (front == null) {
      throw const CameraOpenException(CameraProblem.noFrontCamera);
    }
    final c = CameraController(
      front,
      // 720p: sharp enough for staff review, well under the 2 MiB limit.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
    } on CameraException catch (e) {
      await c.dispose();
      throw CameraOpenException(await _problemFor(e));
    }
    _c = c;
  }

  static Future<CameraProblem> _problemFor(CameraException e) async {
    if (!e.code.contains('Access')) return CameraProblem.failed;
    final status = await Permission.camera.status;
    return status.isPermanentlyDenied || status.isRestricted
        ? CameraProblem.deniedForever
        : CameraProblem.denied;
  }

  @override
  Widget preview() => CameraPreview(_c!);

  @override
  double get aspectRatio {
    final r = _c?.value.aspectRatio ?? 3 / 4;
    // The plugin reports landscape (w/h > 1); the page is portrait.
    return r > 1 ? 1 / r : r;
  }

  @override
  Future<Uint8List> takePicture() async {
    final file = await _c!.takePicture();
    return file.readAsBytes();
  }

  @override
  Future<void> close() async {
    final c = _c;
    _c = null;
    await c?.dispose();
  }
}

/// [host.ArrivalCamera] that opens [ArrivalCameraPage] full screen inside
/// the app (replaces the external camera app, 2026-11-27). Front camera
/// only, no gallery. The existing arrival sheet then shows the preview
/// with Retake / Use photo, and the existing upload and moderation apply.
final class InAppArrivalCamera implements host.ArrivalCamera {
  InAppArrivalCamera(this._navigator, {ArrivalCameraSessionFactory? session})
    : _session = session ?? PluginArrivalCameraSession.new;

  final NavigatorState? Function() _navigator;
  final ArrivalCameraSessionFactory _session;

  @override
  Future<host.PickedPhoto?> capture() async {
    final nav = _navigator();
    if (nav == null) return null;
    final bytes = await nav.push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ArrivalCameraPage(session: _session()),
      ),
    );
    return bytes == null
        ? null
        : host.PickedPhoto(bytes: bytes, contentType: 'image/jpeg');
  }
}

/// Full-screen in-app front camera: live preview, shutter, close. Pops the
/// JPEG bytes, or null on close.
///
/// - Permission: the plugin asks; a denial shows an explanation with
///   "Try again" (or "Open settings" when denied permanently).
/// - Lifecycle: the camera is released when the app goes to the background
///   (or another app takes it) and reopened on return; always released when
///   the page closes.
class ArrivalCameraPage extends StatefulWidget {
  const ArrivalCameraPage({required this.session, super.key});

  final ArrivalCameraSession session;

  @override
  State<ArrivalCameraPage> createState() => _ArrivalCameraPageState();
}

enum _Phase { opening, ready, capturing, problem }

class _ArrivalCameraPageState extends State<ArrivalCameraPage>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.opening;
  CameraProblem? _problem;
  bool _captureFailed = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_openCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.session.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused:
        if (_open) {
          _open = false;
          unawaited(widget.session.close());
          if (mounted) setState(() => _phase = _Phase.opening);
        }
      case AppLifecycleState.resumed:
        // Back from the background, or from Settings after granting access.
        if (!_open && _phase != _Phase.capturing) unawaited(_openCamera());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _openCamera() async {
    setState(() {
      _phase = _Phase.opening;
      _problem = null;
    });
    try {
      await widget.session.open();
      if (!mounted) {
        await widget.session.close();
        return;
      }
      _open = true;
      setState(() => _phase = _Phase.ready);
    } on CameraOpenException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.problem;
          _problem = e.problem;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _phase = _Phase.problem;
          _problem = CameraProblem.failed;
        });
      }
    }
  }

  Future<void> _shoot() async {
    if (_phase != _Phase.ready) return;
    setState(() {
      _phase = _Phase.capturing;
      _captureFailed = false;
    });
    try {
      final bytes = await widget.session.takePicture();
      _open = false;
      await widget.session.close();
      if (mounted) Navigator.of(context).pop(bytes);
    } on Object {
      if (mounted) {
        setState(() {
          _phase = _Phase.ready;
          _captureFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = DashuriTheme.dark();
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Close camera',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Arrival photo'),
        ),
        body: SafeArea(
          child: switch (_phase) {
            _Phase.problem => _ProblemView(
              problem: _problem ?? CameraProblem.failed,
              onRetry: _openCamera,
            ),
            _ => Column(
              children: [
                Expanded(
                  child: Center(
                    child: _phase == _Phase.opening
                        ? const CircularProgressIndicator(
                            semanticsLabel: 'Opening the camera',
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: widget.session.aspectRatio,
                              child: widget.session.preview(),
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DashuriTokens.space6,
                    vertical: DashuriTokens.space3,
                  ),
                  child: Text(
                    _captureFailed
                        ? "That didn't work. Try again."
                        : 'Face the camera in good light. Only staff and '
                              'customers who see you online can view it.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: DashuriTokens.space6),
                  child: _Shutter(
                    enabled: _phase == _Phase.ready,
                    busy: _phase == _Phase.capturing,
                    onPressed: _shoot,
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled, busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: 'Take photo',
    child: GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? Colors.white : Colors.white38,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              : null,
        ),
      ),
    ),
  );
}

class _ProblemView extends StatelessWidget {
  const _ProblemView({required this.problem, required this.onRetry});

  final CameraProblem problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (problem) {
      CameraProblem.denied => (
        'Camera access needed',
        'Allow camera access to take your arrival photo. You can also skip '
            'it; going online never needs a photo.',
      ),
      CameraProblem.deniedForever => (
        'Camera access is off',
        'Turn on camera access for Dashuri in Settings, then come back. You '
            'can also skip the photo.',
      ),
      CameraProblem.noFrontCamera => (
        'No front camera',
        "This device has no front camera, so an arrival photo can't be "
            'taken. You can still go online without one.',
      ),
      CameraProblem.failed => (
        "Couldn't open the camera",
        'Another app may be using it. Close it and try again.',
      ),
    };
    return ResponsiveCenter(
      child: Padding(
        padding: const EdgeInsets.all(DashuriTokens.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 48,
              color: Colors.white70,
            ),
            const SizedBox(height: DashuriTokens.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: DashuriTokens.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: DashuriTokens.space6),
            if (problem == CameraProblem.deniedForever)
              FilledButton(
                onPressed: () => unawaited(openAppSettings()),
                child: const Text('Open settings'),
              )
            else if (problem != CameraProblem.noFrontCamera)
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: DashuriTokens.space2),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
