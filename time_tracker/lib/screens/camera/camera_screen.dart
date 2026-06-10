import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../main.dart';
import '../../theme/app_theme.dart';

enum CaptureMode { clockIn, clockOut, taskStart, taskEnd }

class CameraScreen extends StatefulWidget {
  final CaptureMode mode;
  final String? taskName; // shown for taskEnd mode

  const CameraScreen({
    super.key,
    required this.mode,
    this.taskName,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _initCamera(0);
  }

  Future<void> _initCamera(int index) async {
    if (cameras.isEmpty) return;
    final controller = CameraController(
      cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final XFile image = await _controller!.takePicture();
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName =
          'FC_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = path.join(appDir.path, fileName);
      await File(image.path).copy(savedPath);

      if (mounted) Navigator.pop(context, savedPath);
    } catch (e) {
      debugPrint('Capture error: $e');
      setState(() => _isCapturing = false);
    }
  }

  void _toggleCamera() async {
    if (cameras.length < 2) return;
    setState(() => _isInitialized = false);
    await _controller?.dispose();
    _isFrontCamera = !_isFrontCamera;
    await _initCamera(_isFrontCamera ? 1 : 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String get _modeLabel {
    switch (widget.mode) {
      case CaptureMode.clockIn:
        return 'CLOCK IN PHOTO';
      case CaptureMode.clockOut:
        return 'CLOCK OUT PHOTO';
      case CaptureMode.taskStart:
        return 'BEFORE PHOTO';
      case CaptureMode.taskEnd:
        return 'AFTER PHOTO';
    }
  }

  Color get _modeColor {
    switch (widget.mode) {
      case CaptureMode.clockIn:
      case CaptureMode.taskStart:
        return AppColors.success;
      case CaptureMode.clockOut:
        return AppColors.error;
      case CaptureMode.taskEnd:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isInitialized)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.amber)),

          // Top label
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                bottom: 12,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _modeLabel,
                        style: TextStyle(
                          color: _modeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (widget.taskName != null)
                        Text(
                          widget.taskName!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios,
                        color: Colors.white),
                    onPressed: _toggleCamera,
                  ),
                ],
              ),
            ),
          ),

          // Bottom shutter
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Shutter
                  Center(
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _capture,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isCapturing ? 64 : 72,
                        height: _isCapturing ? 64 : 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _modeColor, width: 4),
                        ),
                        child: Center(
                          child: _isCapturing
                              ? const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                              : Container(
                                  margin: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _modeColor,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Skip button
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'skip'),
                    child: const Text(
                      'Skip Photo',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}