import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:io' show Platform;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CameraApp(),
    );
  }
}

class CameraApp extends StatefulWidget {
  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late List<CameraDescription> cameras;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int selectedCameraIndex = 0;
  double _currentZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  final List<ResolutionPreset> _availableResolutions = [
    ResolutionPreset.low,
    ResolutionPreset.medium,
    ResolutionPreset.high,
    ResolutionPreset.veryHigh,
    ResolutionPreset.ultraHigh,
    ResolutionPreset.max,
  ];
  ResolutionPreset _currentResolution = ResolutionPreset.high;

  bool _isAutoFocusSupported = false;
  FlashMode _flashMode = FlashMode.off;

  double _currentExposureOffset = 0.0;
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;

  bool _isRecording = false;

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    return _selectCamera();
  }

  Future<void> _selectCamera() async {
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[selectedCameraIndex],
        _currentResolution,
        enableAudio: true,
      );
      await _controller.initialize();

      _maxZoomLevel = await _controller.getMaxZoomLevel();

      _isAutoFocusSupported = await _controller.value.focusPointSupported;
      print(' isAutoFocusSupported: $_isAutoFocusSupported');

      if (_isAutoFocusSupported) {
        await _controller.setFocusMode(FocusMode.auto);
        print('set FocusMode.auto');
      }

      if (_flashMode == FlashMode.torch) {
        _flashMode = FlashMode.off;
        await _controller.setFlashMode(_flashMode);
      } else {
        await _controller.setFlashMode(_flashMode);
      }

      setState(() {
        _currentExposureOffset = 0.0;
      });

      _minExposureOffset = await _controller.getMinExposureOffset();
      _maxExposureOffset = await _controller.getMaxExposureOffset();

      return;
    } else {
      throw Exception('利用可能なカメラが見つかりません。');
    }
  }

  void _handlePinchZoom(ScaleUpdateDetails details) {
    double zoomSensitivity = 0.1;
    double scaleCorrected = (details.scale - 1.0) * zoomSensitivity + 1.0;
    double newZoomLevel = _currentZoomLevel * scaleCorrected;

    if (newZoomLevel <= _maxZoomLevel && newZoomLevel >= 1.0) {
      setState(() {
        _controller.setZoomLevel(newZoomLevel);
        _currentZoomLevel = newZoomLevel;
      });
    }
  }

  String flashModeToString(FlashMode mode) {
    switch (mode) {
      case FlashMode.off:
        return 'フラッシュ：オフ';
      case FlashMode.auto:
        return 'フラッシュ：オート';
      case FlashMode.always:
        return 'フラッシュ：常時';
      case FlashMode.torch:
        return 'フラッシュ：トーチ';
      default:
        return '不明';
    }
  }

  void _increaseExposure() async {
    double newExposureOffset = _currentExposureOffset + 0.1;
    if (newExposureOffset <= _maxExposureOffset) {
      await _controller.setExposureOffset(newExposureOffset);
      setState(() {
        _currentExposureOffset = newExposureOffset;
      });
    }
  }

  void _decreaseExposure() async {
    double newExposureOffset = _currentExposureOffset - 0.1;
    if (newExposureOffset >= _minExposureOffset) {
      await _controller.setExposureOffset(newExposureOffset);
      setState(() {
        _currentExposureOffset = newExposureOffset;
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (cameras.length > 1) {
      selectedCameraIndex = selectedCameraIndex == 0 ? 1 : 0;
      await _controller.dispose();
      setState(() {
        _initializeControllerFuture = _selectCamera();
      });
    }
  }

  void _onTapToFocus(TapDownDetails details) {
    if (!_isAutoFocusSupported) {
      return;
    }

    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.globalToLocal(details.globalPosition);
    final screenSize = box.size;
    final point = Offset(
      offset.dx / screenSize.width,
      offset.dy / screenSize.height,
    );
    _controller.setFocusPoint(point);
    _controller.setFocusMode(FocusMode.auto);
  }

  Future<void> _saveImageToPhotoGallery(String imagePath) async {
    await GallerySaver.saveImage(imagePath).then((bool? success) {
      if (success != null && success) {
        print('画像をフォトギャラリーに保存しました。');
      } else {
        print('フォトギャラリーに画像を保存できませんでした。');
      }
    }).catchError((error) {
      print('画像を保存する際にエラーが発生しました: $error');
    });
  }

  void _startVideoRecording() async {
    if (!_controller.value.isInitialized) {
      print('コントローラが初期化されていません。');
      return;
    }

    if (_controller.value.isRecordingVideo) {
      return;
    }

    try {
      await _controller.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print(e);
    }
  }

  void _stopVideoRecording() async {
    if (!_controller.value.isRecordingVideo) {
      return;
    }

    try {
      XFile videoFile = await _controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      _saveVideoToPhotoGallery(videoFile.path);
    } catch (e) {
      print(e);
    }
  }

  void _saveVideoToPhotoGallery(String videoPath) async {
    await GallerySaver.saveVideo(videoPath).then((bool? success) {
      if (success != null && success) {
        print('動画をフォトギャラリーに保存しました。');
      } else {
        print('フォトギャラリーにビデオを動画できませんでした。');
      }
    }).catchError((error) {
      print('ビデオを動画する際にエラーが発生しました: $error');
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('カメラデモ'),
        ),
        body: Stack(
          children: [
            _buildCameraPreview(),
            _buildResolutionController(),
            _buildFlashModeControl(),
            _buildExposureIndicatorAndControl(),
          ],
        ),
        floatingActionButton: _buildFloatingActionButtons(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;

    return FutureBuilder(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (Platform.isAndroid) {
            return GestureDetector(
              onScaleUpdate: _handlePinchZoom,
              onTapDown: _onTapToFocus,
              child: OverflowBox(
                minWidth: size.width,
                minHeight: size.height,
                maxWidth: size.width,
                maxHeight: size.height,
                child: CameraPreview(_controller),
              ),
            );
          } else {
            return GestureDetector(
              onScaleUpdate: _handlePinchZoom,
              onTapDown: _onTapToFocus,
              child: CameraPreview(_controller),
            );
          }
        } else {
          return Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget _buildResolutionController() {
    return Positioned(
        top: 20,
        right: 20,
        child: DropdownButton<ResolutionPreset>(
          value: _currentResolution,
          onChanged: _isRecording ? null : (ResolutionPreset? newValue) {
            if (newValue != null) {
              setState(() {
                _currentResolution = newValue;
                _initializeControllerFuture = _initializeCamera();
              });
            }
          },
          items: _availableResolutions
              .map((ResolutionPreset value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value.toString().split('.').last,
                      style: TextStyle(
                        color: _isRecording ? Colors.grey : Colors.pinkAccent,
                        fontSize: 16,
                      ),
                    ),
                  ))
              .toList(),
        ));
  }

  Widget _buildExposureIndicatorAndControl() {
    String exposureText = _currentExposureOffset.toStringAsFixed(1);
    if (exposureText == "-0.0") {
      exposureText = "0.0";
    }

    return Positioned(
      top: 80,
      left: 20,
      child: Column(
        children: [
          Text(
            '露出: $exposureText',
            style: const TextStyle(
              color: Colors.green,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Opacity(
                opacity: 0.6,
                child: FloatingActionButton(
                  heroTag: 'decreaseExposure',
                  child: const Icon(Icons.remove),
                  mini: true,
                  onPressed: _decreaseExposure,
                ),
              ),
              Opacity(
                opacity: 0.6,
                child: FloatingActionButton(
                  heroTag: 'increaseExposure',
                  child: const Icon(Icons.add),
                  mini: true,
                  onPressed: _increaseExposure,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlashModeControl() {
    return FutureBuilder(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          bool isRearCamera = cameras[selectedCameraIndex].lensDirection ==
              CameraLensDirection.back;

          List<FlashMode> modes = isRearCamera
              ? [
                  FlashMode.off,
                  FlashMode.auto,
                  FlashMode.always,
                  FlashMode.torch
                ]
              : [FlashMode.off, FlashMode.auto, FlashMode.always];

          return Positioned(
              top: 20,
              left: 20,
              child: DropdownButton<FlashMode>(
                value: _flashMode,
                onChanged: _isRecording ? null : (FlashMode? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _flashMode = newValue;
                      _initializeControllerFuture = _initializeCamera();
                    });
                  }
                },
                items: modes
                    .map((FlashMode mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(
                            flashModeToString(mode),
                            style: TextStyle(
                              color: _isRecording ? Colors.grey : Colors.pinkAccent,
                              fontSize: 16,
                            ),
                          ),
                        ))
                    .toList(),
              ));
        } else {
          return CircularProgressIndicator();
        }
      },
    );
  }

  Widget _buildFloatingActionButtons() {
    return Stack(
      children: [
        _buildCaptureButton(),
        _buildToggleCameraButton(),
        _buildRecordingButton(),
      ],
    );
  }

  Widget _buildCaptureButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FloatingActionButton(
        heroTag: 'captureButton',
        child: Icon(_isRecording ? Icons.camera_alt_outlined : Icons.camera_alt),
        onPressed: _isRecording
            ? null
            : () async {
                try {
                  await _initializeControllerFuture;
                  final image = await _controller.takePicture();
                  await _saveImageToPhotoGallery(image.path);
                  print('画像保存: ${image.path}');
                } catch (e) {
                  print(e);
                }
              },
              backgroundColor: _isRecording ? Colors.grey : Colors.blue,
      ),
    );
  }

  Widget _buildToggleCameraButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: FloatingActionButton(
        heroTag: 'switchCameraButton',
        child: Icon(_isRecording ? Icons.switch_camera_outlined : Icons.switch_camera),
        onPressed: _isRecording ? null : _toggleCamera,
        backgroundColor: _isRecording ? Colors.grey : Colors.blue,
      ),
    );
  }

  Widget _buildRecordingButton() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: FloatingActionButton(
        heroTag: 'recordingButton',
        child: Icon(_isRecording ? Icons.stop : Icons.videocam),
        onPressed: _isRecording ? _stopVideoRecording : _startVideoRecording,
        backgroundColor: Colors.blue,
      ),
    );
  }
}
