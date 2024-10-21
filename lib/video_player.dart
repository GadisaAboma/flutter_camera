import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// import 'package:video_editor/video_editor.dart';

class PreviewScreen extends StatefulWidget {
  final Map<String, dynamic>? args;
  const PreviewScreen(this.args, {super.key});
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  XFile? videoFile;
  VideoPlayerController? _controller;

  String videoPath = "";

  // VideoEditorController? _videoEditorController;
//   final Trimmer _trimmer = Trimmer();
// await _trimmer.loadVideo(videoFile: file);
  bool isPlaying = false;
  bool isLoading = true;
  dynamic isUploaded = false;
  @override
  void initState() {
    super.initState();
    videoPath = widget.args!['video'].path;
    initializePreview(context);
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }

  Future<void> initializePreview(ctx) async
  //"File: '/data/user/0/com.elevatingfreely.cooklikeme/cache/a0ff6592-b06e-4ff5-aa0a-c4ca8213e231/VID_20240117_185107_870.mp4'"
  {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }
      if (_controller?.value.isInitialized ?? false) {
        _controller!.dispose();
      }
      final file = File(videoPath);

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (err) {
      print(err.toString());
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void playVideo() {
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Stack(
              children: [
                Positioned(
                  height: MediaQuery.of(context).size.height,
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 20,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          elevation: 0, backgroundColor: Colors.black),
                      onPressed: () {
                        _controller!.pause();
                      },
                      child: const Text(
                        "CONTINUE",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 13,
                  left: 10,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Material(
                          elevation: 4.0,
                          shape: const CircleBorder(),
                          color: Colors.black,
                          child: InkWell(
                              onTap: () {
                                playVideo();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _controller!.value.isPlaying
                                    ? const Icon(
                                        Icons.pause,
                                        color: Colors.white,
                                      )
                                    : const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () => playVideo(),
      //   backgroundColor: primaryColor,
      //   tooltip: 'Pick Video',
      //   child: _controller!.value.isPlaying
      //       ? const Icon(
      //           Icons.pause,
      //           color: Colors.white,
      //         )
      //       : const Icon(
      //           Icons.play_arrow,
      //           color: Colors.white,
      //         ),
      // ),
    );
  }
}
