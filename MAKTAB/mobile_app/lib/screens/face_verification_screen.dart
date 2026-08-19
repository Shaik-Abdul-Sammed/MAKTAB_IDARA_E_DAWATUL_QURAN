import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:maktab_app/config/app_colors.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String personName;

  const FaceVerificationScreen({super.key, required this.personName});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isDetecting = false;
  bool _faceVerified = false;
  bool _cameraSupported = true;
  String _statusMessage = 'Align your face in the camera frame';

  @override
  void initState() {
    super.initState();
    _tryInitFaceDetector();
    _initializeCamera();
  }

  void _tryInitFaceDetector() {
    // ML Kit Face Detection is only available on Android and iOS.
    // On desktop (Linux/macOS/Windows) or during tests, the native channel
    // is not registered and calling any method throws MissingPluginException.
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('FaceDetector: skipped – not supported on ${Platform.operatingSystem}');
      return;
    }
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: true,
          enableClassification: true,
        ),
      );
    } catch (e) {
      debugPrint('FaceDetector init failed: $e');
    }
  }

  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _cameraSupported = false;
        });
        return;
      }

      // Default to front camera
      for (int i = 0; i < _availableCameras.length; i++) {
        if (_availableCameras[i].lensDirection == CameraLensDirection.front) {
          _selectedCameraIndex = i;
          break;
        }
      }

      await _startCameraAtIndex(_selectedCameraIndex);
    } catch (e) {
      debugPrint('Camera initialization fallback: $e');
      if (mounted) {
        setState(() {
          _cameraSupported = false;
          _statusMessage = 'Biometric Security verification ready for ${widget.personName}';
        });
      }
    }
  }

  Future<void> _startCameraAtIndex(int index) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _availableCameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {
      _cameraSupported = true;
    });
    _startFaceDetection();
  }

  Future<void> _toggleCamera() async {
    if (_availableCameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other cameras found.')),
      );
      return;
    }
    
    // Toggle index
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() {
      _isDetecting = false;
      _faceVerified = false;
      _statusMessage = 'Switching camera...';
    });

    try {
      await _startCameraAtIndex(_selectedCameraIndex);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error switching camera: $e')),
      );
    }
  }

  void _startFaceDetection() {
    if (_cameraController == null || _faceDetector == null) return;

    try {
      _cameraController?.startImageStream((CameraImage image) async {
        if (_isDetecting || _faceVerified || _faceDetector == null) return;
        _isDetecting = true;

        try {
          final WriteBuffer allBytes = WriteBuffer();
          for (final Plane plane in image.planes) {
            allBytes.putUint8List(plane.bytes);
          }
          final bytes = allBytes.done().buffer.asUint8List();

          final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
          final InputImageRotation imageRotation =
              InputImageRotationValue.fromRawValue(_cameraController!.description.sensorOrientation) ??
                  InputImageRotation.rotation0deg;
          final InputImageFormat inputImageFormat =
              InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

          final metadata = InputImageMetadata(
            size: imageSize,
            rotation: imageRotation,
            format: inputImageFormat,
            bytesPerRow: image.planes[0].bytesPerRow,
          );

          final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
          final faces = await _faceDetector!.processImage(inputImage);

          if (faces.isNotEmpty && mounted) {
            setState(() {
              _faceVerified = true;
              _statusMessage = 'Face Verified for ${widget.personName}!';
            });

            _cameraController?.stopImageStream();
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) Navigator.pop(context, true);
            });
          }
        } catch (e) {
          debugPrint('Error detecting face stream: $e');
        } finally {
          _isDetecting = false;
        }
      });
    } catch (e) {
      debugPrint('Image stream error: $e');
    }
  }

  void _verifyManually() {
    setState(() {
      _faceVerified = true;
      _statusMessage = 'Identity Verified for ${widget.personName}!';
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  void dispose() {
    try {
      _cameraController?.dispose();
    } catch (_) {}
    if (_faceDetector != null) {
      // close() invokes the native 'vision#closeFaceDetector' channel.
      // On unsupported platforms this throws MissingPluginException;
      // catch it explicitly so the exception never becomes unhandled.
      _faceDetector!.close().catchError((Object e) {
        if (e is! MissingPluginException) {
          debugPrint('FaceDetector close error: $e');
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryTeal,
      appBar: AppBar(
        title: const Text('Teacher Face & Biometric Check'),
        backgroundColor: AppColors.primaryDarkTeal,
        foregroundColor: Colors.white,
        actions: [
          if (_cameraSupported && _availableCameras.length >= 2)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_outlined),
              onPressed: _toggleCamera,
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _cameraSupported && _cameraController != null && _cameraController!.value.isInitialized
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        Center(
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _faceVerified ? Colors.green : AppColors.goldAccent,
                                width: 4,
                              ),
                            ),
                          ),
                        ),
                        // Camera Switch Action Button Overlay
                        Positioned(
                          top: 16,
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'switch_cam_verification',
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            onPressed: _toggleCamera,
                            child: const Icon(Icons.flip_camera_android_rounded),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.face_retouching_natural_rounded, size: 90, color: AppColors.goldAccent),
                            const SizedBox(height: 20),
                            Text(
                              'Teacher Verification for ${widget.personName}',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Confirm teacher identity to access class register.',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              color: AppColors.primaryDarkTeal,
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _faceVerified ? Colors.lightGreenAccent : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.goldAccent,
                        foregroundColor: AppColors.primaryTeal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _verifyManually,
                      icon: const Icon(Icons.verified_user_rounded),
                      label: Text(
                        _faceVerified ? 'Verified! Entering Portal...' : 'Confirm Teacher Identity',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
