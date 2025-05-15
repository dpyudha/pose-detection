import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pose_detection_realtime/ExercisePoseClassifier.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/PoseReferenceRecorder.dart';
import 'package:pose_detection_realtime/PoseRecordingScreen.dart' as custom_recording;

import 'main.dart';

class DetectionScreen extends StatefulWidget {
  DetectionScreen({Key? key, required this.exerciseDataModel})
    : super(key: key);
  ExerciseDataModel exerciseDataModel;
  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  dynamic controller;
  bool isBusy = false;
  late Size size;

  // Pose detector
  late PoseDetector poseDetector;
  
  // Pose classifier
  ExercisePoseClassifier? _poseClassifier;
  
  // Rep counter
  int _repCount = 0;
  
  // Status message
  String _statusMessage = '';
  bool _usingClassifier = false;
  
  // Debug mode for squat detection
  bool _debugMode = true;
  String _lastDetectedState = '';
  Map<String, double> _lastScores = {};
  
  @override
  void initState() {
    super.initState();
    initializeCamera();
    _initializePoseClassifier();
  }

  // Initialize the pose classifier
  Future<void> _initializePoseClassifier() async {
    try {
      setState(() {
        _statusMessage = 'Initializing pose classifier...';
      });
      
      // Create the classifier
      final classifier = ExercisePoseClassifier(exerciseType: widget.exerciseDataModel.type);
      
      // For squats, we'll always use the classifier with predefined poses
      if (widget.exerciseDataModel.type == ExerciseType.Squats) {
        // Give the classifier a moment to load the poses
        await Future.delayed(Duration(milliseconds: 500));
        
        setState(() {
          _poseClassifier = classifier;
          _usingClassifier = true;
          _statusMessage = 'Using predefined squat poses for detection';
        });
      } else {
        // For other exercises, try to load saved poses
        final recorder = PoseReferenceRecorder();
        final savedPoses = await recorder.loadRecordedPoses(widget.exerciseDataModel.type);
        
        if (savedPoses.isNotEmpty) {
          // Use classifier if we have saved poses
          setState(() {
            _poseClassifier = classifier;
            _usingClassifier = true;
            _statusMessage = 'Using pose classifier';
          });
        } else {
          // No saved poses for other exercises, use traditional detection
          setState(() {
            _usingClassifier = false;
            _statusMessage = 'No saved poses found. Using traditional detection.';
          });
        }
      }
    } catch (e) {
      print('Error initializing pose classifier: $e');
      setState(() {
        _usingClassifier = false;
        _statusMessage = 'Error loading poses. Using traditional detection.';
      });
    }
  }

  // Initialize camera
  initializeCamera() async {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);

    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      imageFormatGroup:
          Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
    );
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream(
        (image) => {
          if (!isBusy) {isBusy = true, img = image, doPoseEstimationOnFrame()},
        },
      );
    });
  }

  // Pose detection on a frame
  dynamic _scanResults;
  CameraImage? img;
  doPoseEstimationOnFrame() async {
    var inputImage = _inputImageFromCameraImage();
    if (inputImage != null) {
      final List<Pose> poses = await poseDetector.processImage(inputImage!);
      _scanResults = poses;
      
      if (poses.isNotEmpty) {
        if (_usingClassifier && _poseClassifier != null) {
          // Use the classifier for pose detection
          final newCount = _poseClassifier!.processPose(poses.first);
          
          if (newCount != _repCount) {
            if (mounted) {
              setState(() {
                _repCount = newCount;
              });
            }
          }
          
          // For squats, update the status message with more information
          if (widget.exerciseDataModel.type == ExerciseType.Squats) {
            // Get the last detected state from the classifier
            try {
              final classifier = _poseClassifier as ExercisePoseClassifier;
              _lastDetectedState = classifier.getCurrentState() ?? 'none';
              _lastScores = classifier.getLastScores();
            } catch (e) {
              print('Error getting classifier state: $e');
            }
            
            if (mounted) {
              setState(() {
                _statusMessage = 'Using classifier: $_repCount reps';
              });
            }
          }
        } else {
          // Use traditional detection methods for non-squat exercises
          if (widget.exerciseDataModel.type == ExerciseType.PushUps) {
            detectPushUp(poses.first.landmarks);
          } else if (widget.exerciseDataModel.type == ExerciseType.DownwardDogPlank) {
            detectPlankToDownwardDog(poses.first);
          } else if (widget.exerciseDataModel.type == ExerciseType.JumpingJack) {
            detectJumpingJack(poses.first);
          }
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _scanResults;
        isBusy = false;
      });
    } else {
      isBusy = false;
    }
  }

  //close all resources
  @override
  void dispose() {
    // Stop image stream first
    controller?.stopImageStream();
    
    // Small delay to ensure any pending operations complete
    Future.delayed(Duration(milliseconds: 100), () {
      controller?.dispose();
      poseDetector.close();
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove the special prompt for squats since we're using predefined poses
    // We don't need to check for saved poses anymore

    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child:
                (controller.value.isInitialized)
                    ? AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    )
                    : Container(),
          ),
        ),
      );

      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: buildResult(),
        ),
      );
      
      // Rep counter
      stackChildren.add(
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: Colors.black.withOpacity(0.7),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _usingClassifier ? "$_repCount" : getTraditionalCount(),
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  if (_statusMessage.isNotEmpty)
                    Text(
                      _statusMessage,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                ],
              ),
            ),
            width: 120,
            height: 80,
          ),
        ),
      );

      // Add debug info for squat detection if in debug mode
      if (_debugMode && widget.exerciseDataModel.type == ExerciseType.Squats) {
        stackChildren.add(
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Squat Debug Mode',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Current count: $_repCount',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    'Current state: $_lastDetectedState',
                    style: TextStyle(color: _lastDetectedState == 'squat_up' ? Colors.green : 
                                      _lastDetectedState == 'squat_down' ? Colors.orange : Colors.white, 
                           fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (_lastScores.isNotEmpty) ...[
                    Text(
                      'Match scores:',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    ..._lastScores.entries.map((e) => Text(
                      '  ${e.key}: ${e.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: e.key == _lastDetectedState ? Colors.green : Colors.white, 
                        fontSize: 12,
                        fontWeight: e.key == _lastDetectedState ? FontWeight.bold : FontWeight.normal,
                      ),
                    )).toList(),
                  ],
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseDataModel.title),
        actions: [
          // Toggle debug mode for squats
          if (widget.exerciseDataModel.type == ExerciseType.Squats)
            IconButton(
              icon: Icon(_debugMode ? Icons.bug_report : Icons.bug_report_outlined),
              onPressed: () {
                setState(() {
                  _debugMode = !_debugMode;
                });
              },
              tooltip: 'Toggle debug mode',
            ),
          // Reset counter button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (_usingClassifier && _poseClassifier != null) {
                _poseClassifier!.resetCount();
                setState(() {
                  _repCount = 0;
                });
              } else {
                setState(() {
                  pushUpCount = 0;
                  plankToDownwardDogCount = 0;
                  jumpingJackCount = 0;
                });
              }
            },
            tooltip: 'Reset counter',
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.only(top: 0),
        color: Colors.black,
        child: Stack(children: stackChildren),
      ),
    );
  }
  
  // Get the count from traditional detection methods
  String getTraditionalCount() {
    switch (widget.exerciseDataModel.type) {
      case ExerciseType.PushUps:
        return "$pushUpCount";
      case ExerciseType.Squats:
        // Squats always use the classifier, so this should never be called
        return "0";
      case ExerciseType.DownwardDogPlank:
        return "$plankToDownwardDogCount";
      case ExerciseType.JumpingJack:
        return "$jumpingJackCount";
      default:
        return "0";
    }
  }

  // Traditional detection methods below
  int pushUpCount = 0;
  bool isLowered = false;
  void detectPushUp(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null) {
      return; // Skip if any landmark is missing
    }

    // Calculate elbow angles
    double leftElbowAngle = calculateAngle(leftShoulder, leftElbow, leftWrist);
    double rightElbowAngle = calculateAngle(
      rightShoulder,
      rightElbow,
      rightWrist,
    );
    double avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    // Calculate torso alignment (ensuring a straight plank)
    double torsoAngle = calculateAngle(
      leftShoulder,
      leftHip,
      leftKnee ?? rightKnee!,
    );
    bool inPlankPosition =
        torsoAngle > 160 && torsoAngle < 180; // Slight flexibility

    if (avgElbowAngle < 90 && inPlankPosition) {
      // User is in the lowered push-up position
      isLowered = true;
    } else if (avgElbowAngle > 160 && isLowered && inPlankPosition) {
      // User returns to the starting position
      pushUpCount++;
      isLowered = false;

      // Update UI
      if (mounted) {
        setState(() {});
      }
    }
  }

  int plankToDownwardDogCount = 0;
  bool isInDownwardDog = false;
  void detectPlankToDownwardDog(Pose pose) {
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftWrist == null ||
        rightWrist == null) {
      return; // Skip detection if any key landmark is missing
    }

    // **Step 1: Detect Plank Position**
    bool isPlank =
        (leftHip.y - leftShoulder.y).abs() < 30 &&
        (rightHip.y - rightShoulder.y).abs() < 30 &&
        (leftHip.y - leftAnkle.y).abs() > 100 &&
        (rightHip.y - rightAnkle.y).abs() > 100;

    // **Step 2: Detect Downward Dog Position**
    bool isDownwardDog =
        (leftHip.y < leftShoulder.y - 50) &&
        (rightHip.y < rightShoulder.y - 50) &&
        (leftAnkle.y > leftHip.y) &&
        (rightAnkle.y > rightHip.y);

    // **Step 3: Count Repetitions**
    if (isDownwardDog && !isInDownwardDog) {
      isInDownwardDog = true;
    } else if (isPlank && isInDownwardDog) {
      plankToDownwardDogCount++;
      isInDownwardDog = false;

      // Update UI
      if (mounted) {
        setState(() {});
      }
    }
  }

  int jumpingJackCount = 0;
  bool isJumping = false;
  bool isJumpingJackOpen = false;
  void detectJumpingJack(Pose pose) {
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftAnkle == null ||
        rightAnkle == null ||
        leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftWrist == null ||
        rightWrist == null) {
      return; // Skip detection if any landmark is missing
    }

    // Calculate distances
    double legSpread = (rightAnkle.x - leftAnkle.x).abs();
    double armHeight = (leftWrist.y + rightWrist.y) / 2; // Average wrist height
    double hipHeight = (leftHip.y + rightHip.y) / 2; // Average hip height
    double shoulderWidth = (rightShoulder.x - leftShoulder.x).abs();

    // Define thresholds based on shoulder width
    double legThreshold =
        shoulderWidth * 1.2; // Legs should be ~1.2x shoulder width apart
    double armThreshold =
        hipHeight - shoulderWidth * 0.5; // Arms should be above shoulders

    // Check if arms are raised and legs are spread
    bool armsUp = armHeight < armThreshold;
    bool legsApart = legSpread > legThreshold;

    // Detect full jumping jack cycle
    if (armsUp && legsApart && !isJumpingJackOpen) {
      isJumpingJackOpen = true;
    } else if (!armsUp && !legsApart && isJumpingJackOpen) {
      jumpingJackCount++;
      isJumpingJackOpen = false;

      // Update UI
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Function to calculate angle between three points (shoulder, elbow, wrist)
  double calculateAngle(
    PoseLandmark shoulder,
    PoseLandmark elbow,
    PoseLandmark wrist,
  ) {
    double a = distance(elbow, wrist);
    double b = distance(shoulder, elbow);
    double c = distance(shoulder, wrist);

    double angle = acos((b * b + a * a - c * c) / (2 * b * a)) * (180 / pi);
    return angle;
  }

  // Helper function to calculate Euclidean distance
  double distance(PoseLandmark p1, PoseLandmark p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  InputImage? _inputImageFromCameraImage() {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    final camera = cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;
    // get image format
    final format = InputImageFormatValue.fromRawValue(img!.format.raw);

    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
        if (Platform.isAndroid && format == InputImageFormat.yuv_420_888) {
          return convertYUV420ToInputImage(img, rotation);
        }
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (img!.planes.length != 1) return null;
    final plane = img!.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(img!.width.toDouble(), img!.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format!, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  InputImage? convertYUV420ToInputImage(CameraImage? img, InputImageRotation rotation) {
    if (Platform.isAndroid && img!.format.group != ImageFormatGroup.yuv420) return null;

    final width = img!.width;
    final height = img.height;

    final yPlane = img.planes[0];
    final uPlane = img.planes[1];
    final vPlane = img.planes[2];

    final ySize = yPlane.bytes.length;
    final uvSize = width * height ~/ 2;
    final nv21Bytes = Uint8List(ySize + uvSize);

    // Copy Y
    nv21Bytes.setRange(0, ySize, yPlane.bytes);

    // Interleave V and U (NV21 expects V first, then U)
    int offset = ySize;
    final pixelStride = uPlane.bytesPerPixel ?? 2; // typically 2
    final rowStride = uPlane.bytesPerRow;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final uvIndex = row * rowStride + col * pixelStride;
        nv21Bytes[offset++] = vPlane.bytes[uvIndex]; // V
        nv21Bytes[offset++] = uPlane.bytes[uvIndex]; // U
      }
    }

    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21, // must match the bytes layout
        bytesPerRow: width, // optional on Android
      ),
    );
  }

  //Show rectangles around detected objects
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Text('');
    }
    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = PosePainter(imageSize, _scanResults);
    return CustomPaint(painter: painter);
  }
}
