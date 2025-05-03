import 'dart:io';
import 'package:betterbitees/screens/after_scan.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class Camera extends StatefulWidget {
  final Map<String, dynamic> userProfile; // Still needed for Camera itself

  const Camera({super.key, required this.userProfile});

  @override
  _CameraState createState() => _CameraState();
}

class _CameraState extends State<Camera> {
  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool _isInitialized = false;
  bool _isUploading = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      _cameraController = CameraController(
        _cameras[0],
        ResolutionPreset.high,
      );
      await _cameraController.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(); // Allow popping the screen
    return true; // Return true to allow pop
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Allow popping by default
      onPopInvoked: (didPop) async {
        if (didPop) return; // If already popped, do nothing
        await _onWillPop(); // Handle custom pop logic
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _isInitialized
            ? Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _cameraController.value.previewSize!.height,
                              height: _cameraController.value.previewSize!.width,
                              child: CameraPreview(_cameraController),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    left: 20, // Add back button on top-left
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop(); // Navigate back
                      },
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      onPressed: () async {
                        FlashMode currentMode = _cameraController.value.flashMode;
                        FlashMode nextMode = currentMode == FlashMode.torch
                            ? FlashMode.off
                            : FlashMode.torch;
                        await _cameraController.setFlashMode(nextMode);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image, color: Colors.white, size: 35),
                          onPressed: () => _uploadPhoto(context),
                        ),
                        FloatingActionButton(
                          backgroundColor: Colors.white,
                          onPressed: () => _capturePhoto(context),
                          child: const Icon(Icons.camera, color: Colors.black),
                        ),
                        IconButton(
                          icon: const Icon(Icons.switch_camera, color: Colors.white, size: 35),
                          onPressed: () async {
                            int nextCameraIndex =
                                (_cameras.indexOf(_cameraController.description) + 1) % _cameras.length;
                            _cameraController = CameraController(
                              _cameras[nextCameraIndex],
                              ResolutionPreset.high,
                            );
                            await _cameraController.initialize();
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _capturePhoto(BuildContext context) async {
    if (!_cameraController.value.isInitialized || _isUploading) return;

    try {
      final XFile imageFile = await _cameraController.takePicture();
      final timestamp = DateTime.now(); // Use DateTime directly
      setState(() {
        _imageFile = File(imageFile.path);
      });

      if (_imageFile != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AfterScan(
              imageFile: _imageFile,
              timestamp: timestamp, // Pass DateTime
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }

  Future<void> _uploadPhoto(BuildContext context) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      final timestamp = DateTime.now(); // Use DateTime directly

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AfterScan(
                imageFile: _imageFile,
                timestamp: timestamp, // Pass DateTime
              ),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image selected.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}