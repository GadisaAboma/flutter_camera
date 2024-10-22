import 'dart:io';

import 'package:camera/camera.dart';
import 'package:custom_timer/custom_timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera/video_preview_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class VideoRecorderScreen extends StatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  State<VideoRecorderScreen> createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<VideoRecorderScreen>
    with TickerProviderStateMixin {
  List<CameraDescription> cameras = [];
  CameraController? controller;
  VideoPlayerController? videoController;
  CustomTimerController? _controller;

  XFile? videoFile;
  // Initial values
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = true;
  bool _isRearCameraSelected = true;
  bool _isRecordingInProgress = false;
  double _minAvailableExposureOffset = 0.0;
  double _maxAvailableExposureOffset = 0.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  // Current values
  double _currentZoomLevel = 1.0;
  double _currentExposureOffset = 0.0;
  FlashMode? _currentFlashMode;
  List<File> allFileList = [];
  final resolutionPresets = ResolutionPreset.values;
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;
  getPermissionStatus() async {
    try {
      cameras = await availableCameras();

      await Permission.camera.request();

      PermissionStatus status = await Permission.camera.status;

      setState(() {
        _isCameraPermissionGranted = true;
      });
      // Set and initialize the new camera
      onNewCameraSelected(cameras[0]);
      // refreshAlreadyCapturedImages();
    } on CameraException catch (e) {
      print('Error in fetching the cameras: $e');
    } catch (e) {}
  }

  // refreshAlreadyCapturedImages() async {
  //   final directory = await getApplicationDocumentsDirectory();
  //   List<FileSystemEntity> fileList = await directory.list().toList();
  //   allFileList.clear();
  //   List<Map<int, dynamic>> fileNames = [];
  //   for (var file in fileList) {
  //     if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
  //       allFileList.add(File(file.path));
  //       String name = file.path.split('/').last.split('.').first;
  //       fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
  //     }
  //   }
  //   if (fileNames.isNotEmpty) {
  //     final recentFile =
  //         fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
  //     String recentFileName = recentFile[1];
  //     if (recentFileName.contains('.mp4')) {
  //       _videoFile = File('${directory.path}/$recentFileName');
  //       _imageFile = null;
  //     } else {
  //       _imageFile = File('${directory.path}/$recentFileName');
  //       _videoFile = null;
  //     }
  //     setState(() {});
  //   }
  // }

  Future<XFile?> takePicture() async {
    final CameraController? cameraController = controller;
    if (cameraController!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }
    try {
      XFile file = await cameraController.takePicture();
      return file;
    } on CameraException catch (e) {
      print('Error occured while taking picture: $e');
      return null;
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;
    if (controller!.value.isRecordingVideo) {
      // A recording has already started, do nothing.
      return;
    }
    try {
      await cameraController!.startVideoRecording();
      _controller!.start();
      setState(() {
        _isRecordingInProgress = true;
        print(_isRecordingInProgress);
      });
    } on CameraException catch (e) {
      print('Error starting to record video: $e');
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Recording is already is stopped state
      return null;
    }
    try {
      XFile file = await controller!.stopVideoRecording();
      _controller!.finish();
      setState(() {
        _isRecordingInProgress = false;
      });
      return file;
    } on CameraException catch (e) {
      print('Error stopping video recording: $e');
      return null;
    }
  }

  Future<void> pauseVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // Video recording is not in progress
      return;
    }
    try {
      await controller!.pauseVideoRecording();
      _controller!.pause();
    } on CameraException catch (e) {
      print('Error pausing video recording: $e');
    }
  }

  Future<void> resumeVideoRecording() async {
    if (!controller!.value.isRecordingVideo) {
      // No video recording was in progress
      return;
    }
    try {
      await controller!.resumeVideoRecording();
      _controller!.start();
    } on CameraException catch (e) {
      print('Error resuming video recording: $e');
    }
  }

  void resetCameraValues() async {
    _currentZoomLevel = 1.0;
    _currentExposureOffset = 0.0;
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    final previousCameraController = controller;
    final CameraController cameraController = CameraController(
      cameraDescription,
      currentResolutionPreset,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await previousCameraController?.dispose();
    resetCameraValues();
    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }
    // Update UI if controller updated
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });
    try {
      await cameraController.initialize();
      await Future.wait([
        cameraController
            .getMinExposureOffset()
            .then((value) => _minAvailableExposureOffset = value),
        cameraController
            .getMaxExposureOffset()
            .then((value) => _maxAvailableExposureOffset = value),
        cameraController
            .getMaxZoomLevel()
            .then((value) => _maxAvailableZoom = value),
        cameraController
            .getMinZoomLevel()
            .then((value) => _minAvailableZoom = value),
      ]);
      _currentFlashMode = controller!.value.flashMode;
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }
    if (mounted) {
      setState(() {
        _isCameraInitialized = controller!.value.isInitialized;
      });
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
  }

  @override
  void initState() {
    _controller = CustomTimerController(
        end: Duration(hours: 24),
        begin: Duration(),
        initialState: CustomTimerState.reset,
        interval: CustomTimerInterval.seconds,
        vsync: this);
    // Hide the status bar in Android
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    getPermissionStatus();
    super.initState();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    videoController?.dispose();
    _controller!.dispose();
    super.dispose();
  }

  // Future<void> selectVideoFromFile() async {
  //   videoFile = await _picker.pickVideo(source: ImageSource.gallery);

  //   if (videoFile == null) {
  //     return;
  //   }
  //   Navigator.of(context).pushNamed(AppRoutes().videoPreviewScreen,
  //       arguments: {"video": videoFile});
  //   // Navigator.of(context).push(
  //   //   MaterialPageRoute(builder: (context) {
  //   //     return EditorView(videoFile!);
  //   //   }),
  //   // );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 35, 34, 34),
      body: _isCameraPermissionGranted
          ? _isCameraInitialized
              ? Stack(
                  children: [
                    Positioned(
                      height: MediaQuery.of(context).size.height,
                      child: CameraPreview(
                        controller!,
                        child: LayoutBuilder(builder:
                            (BuildContext context, BoxConstraints constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) =>
                                onViewFinderTap(details, constraints),
                          );
                        }),
                      ),
                    ),
                    Positioned(
                      top: 45,
                      left: 20,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 45,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE94057),
                            borderRadius: BorderRadius.circular(10)),
                        child: CustomTimer(
                            controller: _controller!,
                            builder: (state, time) {
                              return Text(
                                  "${time.hours}:${time.minutes}:${time.seconds}",
                                  style: const TextStyle(
                                      fontSize: 24.0, color: Colors.white));
                            }),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: MediaQuery.of(context).size.height * .2,
                      height: MediaQuery.of(context).size.height * .5,
                      child: Column(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(right: 8.0, top: 16.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '${_currentExposureOffset.toStringAsFixed(1)}x',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Container(
                                height: 30,
                                child: Slider(
                                  value: _currentExposureOffset,
                                  min: _minAvailableExposureOffset,
                                  max: _maxAvailableExposureOffset,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white30,
                                  onChanged: (value) async {
                                    setState(() {
                                      _currentExposureOffset = value;
                                    });
                                    await controller!.setExposureOffset(value);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * .25,
                      left: 25,
                      width: MediaQuery.of(context).size.width * .9,
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _currentZoomLevel,
                              min: _minAvailableZoom,
                              max: _maxAvailableZoom,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white30,
                              onChanged: (value) async {
                                setState(() {
                                  _currentZoomLevel = value;
                                });
                                await controller!.setZoomLevel(value);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  '${_currentZoomLevel.toStringAsFixed(1)}x',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * .15,
                      left: 4,
                      width: MediaQuery.of(context).size.width,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () async {
                                setState(() {
                                  _currentFlashMode = FlashMode.off;
                                });
                                await controller!.setFlashMode(
                                  FlashMode.off,
                                );
                              },
                              child: Icon(
                                Icons.flash_off,
                                color: _currentFlashMode == FlashMode.off
                                    ? Colors.amber
                                    : Colors.white,
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                setState(() {
                                  _currentFlashMode = FlashMode.auto;
                                });
                                await controller!.setFlashMode(
                                  FlashMode.auto,
                                );
                              },
                              child: Icon(
                                Icons.flash_auto,
                                color: _currentFlashMode == FlashMode.auto
                                    ? Colors.amber
                                    : Colors.white,
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                setState(() {
                                  _currentFlashMode = FlashMode.always;
                                });
                                await controller!.setFlashMode(
                                  FlashMode.always,
                                );
                              },
                              child: Icon(
                                Icons.flash_on,
                                color: _currentFlashMode == FlashMode.always
                                    ? Colors.amber
                                    : Colors.white,
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                setState(() {
                                  _currentFlashMode = FlashMode.torch;
                                });
                                await controller!.setFlashMode(
                                  FlashMode.torch,
                                );
                              },
                              child: Icon(
                                Icons.highlight,
                                color: _currentFlashMode == FlashMode.torch
                                    ? Colors.amber
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      width: MediaQuery.of(context).size.width,
                      bottom: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: _isRecordingInProgress
                                  ? () async {
                                      if (controller!.value.isRecordingPaused) {
                                        await resumeVideoRecording();
                                      } else {
                                        await pauseVideoRecording();
                                      }
                                    }
                                  : () {
                                      setState(() {
                                        _isCameraInitialized = false;
                                      });
                                      onNewCameraSelected(cameras[
                                          _isRearCameraSelected ? 1 : 0]);
                                      setState(() {
                                        _isRearCameraSelected =
                                            !_isRearCameraSelected;
                                      });
                                    },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.black38,
                                    size: 60,
                                  ),
                                  _isRecordingInProgress
                                      ? controller!.value.isRecordingPaused
                                          ? Icon(
                                              Icons.play_arrow,
                                              color: Colors.white,
                                              size: 30,
                                            )
                                          : Icon(
                                              Icons.pause,
                                              color: Colors.white,
                                              size: 30,
                                            )
                                      : Icon(
                                          _isRearCameraSelected
                                              ? Icons.camera_front
                                              : Icons.camera_rear,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                if (_isRecordingInProgress) {
                                  XFile? rawVideo = await stopVideoRecording();
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (context) => VideoPreviewScreen(
                                          {"video": rawVideo})));
                                } else {
                                  await startVideoRecording();
                                }
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    color: Colors.white,
                                    size: 80,
                                  ),
                                  const Icon(
                                    Icons.circle,
                                    color: Color(0xFFE94057),
                                    size: 65,
                                  ),
                                  _isRecordingInProgress
                                      ? const Icon(
                                          Icons.stop_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        )
                                      : Container(),
                                ],
                              ),
                            ),
                            // InkWell(
                            //   onTap: _imageFile != null || _videoFile != null
                            //       ? () {
                            //           Navigator.of(context).push(
                            //             MaterialPageRoute(
                            //               builder: (context) =>
                            //                   PreviewScreen(),
                            //             ),
                            //           );
                            //         }
                            //       : null,
                            //   child: Container(
                            //     width: 60,
                            //     height: 60,
                            //     decoration: BoxDecoration(
                            //       color: Colors.black,
                            //       borderRadius: BorderRadius.circular(10.0),
                            //       border: Border.all(
                            //         color: Colors.white,
                            //         width: 2,
                            //       ),
                            //       image: _imageFile != null
                            //           ? DecorationImage(
                            //               image: FileImage(_imageFile!),
                            //               fit: BoxFit.cover,
                            //             )
                            //           : null,
                            //     ),
                            //     child: videoController != null &&
                            //             videoController!.value.isInitialized
                            //         ? ClipRRect(
                            //             borderRadius:
                            //                 BorderRadius.circular(8.0),
                            //             child: AspectRatio(
                            //               aspectRatio: videoController!
                            //                   .value.aspectRatio,
                            //               child:
                            //                   VideoPlayer(videoController!),
                            //             ),
                            //           )
                            //         : Container(),
                            //   ),
                            // ),
                            InkWell(
                              // onTap: () => selectVideoFromFile(),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.video_library,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: Text(
                    'LOADING...',
                    style: TextStyle(color: Colors.white),
                  ),
                )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(),
                const Text(
                  'Permission denied',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    getPermissionStatus();
                  },
                  child: const Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Grant permission',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
