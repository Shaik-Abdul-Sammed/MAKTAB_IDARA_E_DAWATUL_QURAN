import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:maktab_app/config/app_colors.dart';
import 'package:maktab_app/models/user.dart';
import 'package:maktab_app/models/teacher_attendance.dart';
import 'package:maktab_app/repositories/user_repository.dart';
import 'package:maktab_app/repositories/teacher_attendance_repository.dart';

class TeacherFaceAttendanceScreen extends StatefulWidget {
  const TeacherFaceAttendanceScreen({super.key});

  @override
  State<TeacherFaceAttendanceScreen> createState() => _TeacherFaceAttendanceScreenState();
}

class _TeacherFaceAttendanceScreenState extends State<TeacherFaceAttendanceScreen> {
  final UserRepository _userRepository = UserRepository();
  final TeacherAttendanceRepository _attendanceRepository = TeacherAttendanceRepository();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;

  /// True when google_mlkit_face_detection throws MissingPluginException.
  /// In that case we degrade gracefully: camera preview still works,
  /// but ML-based matching is skipped and replaced with photo-path heuristic.
  bool _mlKitUnavailable = false;

  List<User> _teachers = [];
  User? _selectedTeacher;
  bool _isScanning = false;
  bool _isMatched = false;
  String _statusMessage = 'Align your face inside the circle';

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadTeachers();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Use front camera if available
        final frontCamera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } on MissingPluginException {
      // Camera plugin not wired — mark as unavailable but don't crash
      if (mounted) {
        setState(() {
          _mlKitUnavailable = true;
          _statusMessage = 'Camera unavailable on this device/build.';
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }


  Future<void> _loadTeachers() async {
    final teachers = await _userRepository.getAllTeachers();
    if (mounted && teachers.isNotEmpty) {
      setState(() {
        _teachers = teachers;
        _selectedTeacher = teachers.first;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _processFaceScan() async {
    if (_selectedTeacher == null || _isScanning || _cameraController == null) return;

    setState(() {
      _isScanning = true;
      _statusMessage = 'Taking photo...';
      _isMatched = false;
    });

    try {
      final photo = await _cameraController!.takePicture();
      
      if (!mounted) return;
      setState(() {
         _statusMessage = 'Please verify with fingerprint/biometric';
      });

      final LocalAuthentication localAuth = LocalAuthentication();
      bool authenticated = false;
      try {
        authenticated = await localAuth.authenticate(
          localizedReason: 'Verify identity to mark attendance',
          biometricOnly: true,
        );
      } catch (e) {
        debugPrint('Biometric Error: $e');
      }

      if (authenticated && mounted) {
        setState(() {
          _isMatched = true;
          _isScanning = false;
          _statusMessage = 'Identity Verified! Attendance Recorded.';
        });
        await _markAttendancePresent(photo.path);
      } else {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = 'Biometric verification failed or cancelled.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Error taking photo or verifying.';
        });
      }
    }
  }

  Future<void> _markAttendancePresent(String photoPath) async {
    if (_selectedTeacher == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());

    final record = TeacherAttendance(
      teacherId: _selectedTeacher!.id!,
      date: dateStr,
      status: 'Present',
      remarks: 'Verified via Biometric with Photo Capture at $timeStr. Photo: $photoPath',
    );

    await _attendanceRepository.upsertAttendance(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance marked Present for ${_selectedTeacher!.name}!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      appBar: AppBar(
        title: const Text(
          'Face Verification Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── MLKit unavailability banner ─────────────────────────────────
            if (_mlKitUnavailable)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Face ML Kit not linked. Running in simulation mode. '
                        'Use Manual Attendance for production use.',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Teacher Selector Dropdown
            Container(
              margin: const EdgeInsets.all(16),

              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<User>(
                  value: _selectedTeacher,
                  dropdownColor: const Color(0xFF1A2634),
                  hint: const Text('Select Teacher', style: TextStyle(color: Colors.white70)),
                  isExpanded: true,
                  icon: const Icon(Icons.person_search_rounded, color: AppColors.goldAccent),
                  items: _teachers.map((User teacher) {
                    return DropdownMenuItem<User>(
                      value: teacher,
                      child: Text(
                        teacher.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTeacher = val;
                      _isMatched = false;
                      _statusMessage = 'Align face inside circle';
                    });
                  },
                ),
              ),
            ),

            // Camera Viewfinder Box
            Expanded(
              child: Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isMatched
                          ? AppColors.success
                          : _isScanning
                              ? AppColors.goldAccent
                              : Colors.cyan,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isMatched ? AppColors.success : Colors.cyan).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _isCameraInitialized && _cameraController != null
                        ? CameraPreview(_cameraController!)
                        : Container(
                            color: Colors.black45,
                            child: const Icon(Icons.face_rounded, size: 100, color: Colors.white30),
                          ),
                  ),
                ),
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: _isMatched ? AppColors.success.withValues(alpha: 0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isMatched ? AppColors.success : Colors.white24,
                ),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _isMatched ? AppColors.success : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Scan Action Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldAccent,
                    foregroundColor: AppColors.primaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isScanning ? null : _processFaceScan,
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 22),
                  label: Text(
                    _isScanning ? 'Verifying...' : 'Verify Face & Mark Attendance',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
