import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:detector_senas/core/theme/app_theme.dart';
import '../data/sign_vision.dart';
import '../data/tflite_sign_classifier.dart';
import '../data/yuv_camera_jpeg.dart';

enum _CameraUiStatus {
  checkingPermission,
  loading,
  ready,
  noCamera,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _disposed = false;
  CameraController? _controller;
  _CameraUiStatus _status = _CameraUiStatus.checkingPermission;
  String? _errorMessage;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _hasAppliedInitialLensPreference = false;

  late final AnimationController _scanAnimationController;
  late final AnimationController _pulseAnimationController;

  final SignVision _signVision = createSignVision();
  final TfliteSignClassifier _classifier = TfliteSignClassifier();

  SignVisionInitResult? _visionInit;
  bool _visionPipelineStarted = false;
  bool _visionBootstrapping = false;
  bool _processingFrame = false;
  int _lastDetectMs = 0;

  String _statusHeadline = 'Esperando señas…';
  String _statusSubline = '';

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCamera());
  }

  Future<void> _prepareCamera() async {
    setState(() {
      _status = _CameraUiStatus.checkingPermission;
      _errorMessage = null;
    });

    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      await _initializeCamera();
      return;
    }

    if (status.isPermanentlyDenied) {
      setState(() => _status = _CameraUiStatus.permissionDeniedForever);
    } else {
      setState(() => _status = _CameraUiStatus.permissionDenied);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'SignBridge needs camera access for the translator tab.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _status = _CameraUiStatus.loading;
      _errorMessage = null;
    });

    try {
      await _disposeController();
      _cameras = await availableCameras();
      if (_disposed || !mounted) return;
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _status = _CameraUiStatus.noCamera);
        return;
      }

      if (!_hasAppliedInitialLensPreference) {
        final frontIx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        if (frontIx >= 0) _cameraIndex = frontIx;
        _hasAppliedInitialLensPreference = true;
      } else {
        _cameraIndex = _cameraIndex.clamp(0, _cameras.length - 1);
      }
      final selected = _cameras[_cameraIndex];

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (_disposed || !mounted) {
        await controller.dispose();
        return;
      }
      _flashMode = FlashMode.off;
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Some lenses (e.g. front) may not support flash control.
      }

      if (_disposed || !mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      setState(() => _status = _CameraUiStatus.ready);
      unawaited(_bootstrapVisionPipeline());
    } catch (e, st) {
      debugPrint('Camera init error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _status = _CameraUiStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _bootstrapVisionPipeline() async {
    if (_visionBootstrapping) return;
    _visionBootstrapping = true;
    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }

      await _classifier.tryLoadFromAssetOnce('assets/models/sign_classifier.tflite');
      if (_disposed || !mounted || !identical(_controller, controller)) return;
      if (!controller.value.isInitialized) return;

      final init = await _signVision.init();
      if (_disposed || !mounted || !identical(_controller, controller)) return;
      if (!controller.value.isInitialized) return;

      setState(() {
        _visionInit = init;
        if (!init.ok) {
          _statusHeadline = _headlineForInitFailure(init);
          _statusSubline = init.hint ?? init.errorKey ?? '';
        } else {
          _statusHeadline = 'Motor de manos listo';
          _statusSubline = _classifier.isLoaded
              ? 'TFLite cargado · inferencia por fotograma'
              : 'Solo landmarks (sin sign_classifier.tflite)';
        }
      });

      if (!init.ok || !_isAndroid) {
        if (_isIos) {
          setState(() {
            _statusHeadline = 'Próximamente en iOS';
            _statusSubline = _signVision.platformCaption;
          });
        }
        return;
      }

      if (_disposed || !mounted || !identical(_controller, controller)) return;
      if (!controller.value.isInitialized) return;

      try {
        await controller.startImageStream(_onCameraImage);
        _visionPipelineStarted = true;
      } catch (e, st) {
        debugPrint('startImageStream: $e\n$st');
        if (!mounted) return;
        setState(() {
          _statusHeadline = 'No se pudo abrir el stream de video';
          _statusSubline = '$e';
        });
      }
    } finally {
      _visionBootstrapping = false;
    }
  }

  String _headlineForInitFailure(SignVisionInitResult init) {
    switch (init.errorKey) {
      case 'missing_model_asset':
        return 'Falta hand_landmarker.task (Android)';
      case 'ios_stub':
        return 'Próximamente en iOS';
      case 'init_failed':
        return 'Error al iniciar MediaPipe';
      default:
        return 'Motor de manos no disponible';
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_disposed || !_visionPipelineStarted || _processingFrame || !_isAndroid) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastDetectMs < 400) return;
    _lastDetectMs = now;
    _processingFrame = true;
    try {
      final jpeg = yuv420CameraImageToJpeg(image);
      if (jpeg == null) return;
      final det = await _signVision.detect(jpeg, now);
      if (_disposed || !mounted || !identical(_controller, controller)) return;
      if (!controller.value.isInitialized) return;

      if (!det.ok) {
        setState(() {
          _statusHeadline = 'Sin detección';
          _statusSubline = det.errorKey ?? 'error';
        });
        return;
      }

      if (det.handCount == 0) {
        setState(() {
          _statusHeadline = 'Buscando manos…';
          _statusSubline = 'MediaPipe activo';
        });
        return;
      }

      final hand0 = det.hands.first.flat;
      final clf = _classifier.classifyFirstHand(hand0);
      final energy = _meanAbsZ(hand0);
      if (clf != null) {
        setState(() {
          _statusHeadline = 'Seña · clase ${clf.index}';
          _statusSubline = 'Confianza ${(clf.confidence * 100).toStringAsFixed(0)}% · |z|≈${energy.toStringAsFixed(2)}';
        });
      } else {
        setState(() {
          _statusHeadline = 'Manos: ${det.handCount}';
          _statusSubline =
              'Landmarks 63D · |z|≈${energy.toStringAsFixed(2)} (añade sign_classifier.tflite para etiqueta)';
        });
      }
    } catch (e, st) {
      debugPrint('Vision frame error: $e\n$st');
    } finally {
      _processingFrame = false;
    }
  }

  double _meanAbsZ(List<double> flat63) {
    if (flat63.length < 63) return 0;
    var s = 0.0;
    for (var i = 2; i < 63; i += 3) {
      s += flat63[i].abs();
    }
    return s / 21.0;
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    _visionPipelineStarted = false;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) {
          await c.stopImageStream();
        }
      } catch (_) {}
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only one camera is available on this device.')),
      );
      return;
    }
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.description.lensDirection == CameraLensDirection.front) {
      if (!mounted || _disposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flash is only available on the rear camera. Switch cameras to use it.'),
        ),
      );
      return;
    }

    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await controller.setFlashMode(next);
      if (_disposed || !mounted || !identical(_controller, controller)) return;
      setState(() => _flashMode = next);
    } catch (e) {
      if (_disposed || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change flash: $e')),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimationController.dispose();
    _pulseAnimationController.dispose();
    unawaited(_disposeController());
    _classifier.close();
    unawaited(_signVision.releaseModel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_controller != null) {
        unawaited(_disposeController());
        if (mounted) setState(() => _status = _CameraUiStatus.loading);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      if (_status == _CameraUiStatus.ready &&
          _controller != null &&
          _controller!.value.isInitialized) {
        return;
      }
      unawaited(_prepareCamera());
    }
  }

  bool get _showPreviewOverlay =>
      _status == _CameraUiStatus.ready &&
      _controller != null &&
      _controller!.value.isInitialized;

  String get _badgeLabel {
    if (_isAndroid && (_visionInit?.ok ?? false)) return 'ANDROID ML';
    if (_isIos) return 'iOS PREVIEW';
    return 'PREVIEW';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMainLayer(context),
          if (_showPreviewOverlay) ..._buildScannerOverlay(context),
          _buildTopBar(context),
          if (kIsWeb) _buildWebCapabilityBanner(context),
          if (_showPreviewOverlay) _buildBottomCard(context),
          if (_showPreviewOverlay) _buildSideControls(context),
        ],
      ),
    );
  }

  Widget _buildWebCapabilityBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.of(context).padding.top + 52,
      child: Material(
        color: cs.tertiaryContainer.withOpacity(0.97),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        elevation: 2,
        shadowColor: Colors.black45,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            'Para cámara y detección (MediaPipe) usa Android o iOS. En web puedes usar el chat y los GIFs de demostración.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onTertiaryContainer,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ) ??
                TextStyle(
                  color: cs.onTertiaryContainer,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainLayer(BuildContext context) {
    switch (_status) {
      case _CameraUiStatus.ready:
        return Positioned.fill(
          child: CameraPreview(_controller!),
        );
      case _CameraUiStatus.loading:
      case _CameraUiStatus.checkingPermission:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Preparing camera…',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface.withOpacity(0.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      case _CameraUiStatus.noCamera:
        return _buildMessageState(
          icon: Icons.videocam_off_outlined,
          title: 'No camera found',
          detail: 'This device did not report any cameras.',
        );
      case _CameraUiStatus.permissionDenied:
      case _CameraUiStatus.permissionDeniedForever:
        return _buildMessageState(
          icon: Icons.privacy_tip_outlined,
          title: 'Camera permission required',
          detail:
              'Allow camera access to use SignBridge Visión. You can open system settings to enable it.',
          action: TextButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Open settings'),
          ),
        );
      case _CameraUiStatus.error:
        return _buildMessageState(
          icon: Icons.error_outline,
          title: 'Camera error',
          detail: _errorMessage ?? 'Unknown error',
          action: TextButton.icon(
            onPressed: _initializeCamera,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
    }
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String detail,
    Widget? action,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.onInverseSurface.withOpacity(0.75)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onInverseSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onInverseSurface.withOpacity(0.72),
                height: 1.45,
                fontSize: 14,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              Theme(
                data: Theme.of(context).copyWith(
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(foregroundColor: cs.primary),
                  ),
                ),
                child: action,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScannerOverlay(BuildContext context) {
    return [
      ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                backgroundBlendMode: BlendMode.dstOut,
              ),
            ),
            Align(
              alignment: const Alignment(0.0, -0.4),
              child: Container(
                width: 280,
                height: 350,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
            ),
          ],
        ),
      ),
      Align(
        alignment: const Alignment(0.0, -0.4),
        child: Container(
          width: 280,
          height: 350,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      ),
      Align(
        alignment: const Alignment(0.0, -0.4),
        child: SizedBox(
          width: 280,
          height: 350,
          child: AnimatedBuilder(
            animation: _scanAnimationController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: _scanAnimationController.value * 340,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary,
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ];
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.55),
              Colors.black.withOpacity(0.0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SignBridge Visión',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 200,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.88),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.35), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimationController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: 0.35 + (_pulseAnimationController.value * 0.65),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.error.withOpacity(0.45),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _badgeLabel,
                      style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ) ??
                          TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _statusHeadline,
                  style: tt.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ) ??
                      TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        height: 1.25,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _statusSubline,
                  style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ) ??
                      TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  _signVision.platformCaption,
                  style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant.withOpacity(0.85),
                        height: 1.25,
                      ) ??
                      TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withOpacity(0.85),
                        height: 1.25,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideControls(BuildContext context) {
    final flashOn = _flashMode == FlashMode.torch;
    return Positioned(
      right: 20,
      top: MediaQuery.of(context).size.height * 0.35,
      child: Column(
        children: [
          _buildFloatingButton(
            context,
            icon: Icons.flip_camera_ios,
            tooltip: 'Switch camera',
            onTap: _switchCamera,
          ),
          const SizedBox(height: 20),
          _buildFloatingButton(
            context,
            icon: flashOn ? Icons.flash_on : Icons.flash_off,
            tooltip: _controller?.description.lensDirection == CameraLensDirection.front
                ? 'Flash (rear camera only)'
                : 'Toggle flash',
            onTap: _toggleFlash,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.inverseSurface.withOpacity(0.38),
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
                ),
                child: Icon(icon, color: cs.onInverseSurface.withOpacity(0.92), size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
