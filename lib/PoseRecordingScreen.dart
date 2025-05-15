import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/PoseClassifier.dart';
import 'package:pose_detection_realtime/PoseReferenceRecorder.dart';
import 'package:pose_detection_realtime/main.dart';

class PoseRecordingScreen extends StatefulWidget {
  final ExerciseDataModel exerciseDataModel;
  
  const PoseRecordingScreen({Key? key, required this.exerciseDataModel}) : super(key: key);
  
  @override
  _PoseRecordingScreenState createState() => _PoseRecordingScreenState();
}

class _PoseRecordingScreenState extends State<PoseRecordingScreen> {
  // Camera controller
  CameraController? controller;
  bool isBusy = false;
  late Size size;
  
  // Pose detector
  late PoseDetector poseDetector;
  
  // Pose recorder
  final PoseReferenceRecorder _recorder = PoseReferenceRecorder();
  
  // Current pose data
  String _currentState = '';
  final List<String> _exerciseStates = [];
  dynamic _scanResults;
  CameraImage? img;
  Pose? _currentPose;
  
  // Status message
  String _statusMessage = 'Preparing camera...';
  bool _isRecording = false;
  
  @override
  void initState() {
    super.initState();
    _initializeStates();
    initializeCamera();
  }
  
  void _initializeStates() {
    switch (widget.exerciseDataModel.type) {
      case ExerciseType.PushUps:
        _exerciseStates.addAll(['push_up_up', 'push_up_down']);
        break;
      case ExerciseType.Squats:
        _exerciseStates.addAll(['squat_up', 'squat_down']);
        break;
      case ExerciseType.DownwardDogPlank:
        _exerciseStates.addAll(['plank', 'downward_dog']);
        break;
      case ExerciseType.JumpingJack:
        _exerciseStates.addAll(['jumping_jack_closed', 'jumping_jack_open']);
        break;
    }
    
    if (_exerciseStates.isNotEmpty) {
      _currentState = _exerciseStates.first;
    }
  }
  
  // Initialize camera
  initializeCamera() async {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    poseDetector = PoseDetector(options: options);

    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    
    try {
      await controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        controller!.startImageStream(
          (image) => {
            if (!isBusy) {isBusy = true, img = image, processCameraImage()},
          },
        );
        setState(() {
          _statusMessage = 'Camera ready. Select a pose state and tap Record.';
        });
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error initializing camera: $e';
      });
    }
  }
  
  // Process camera image
  processCameraImage() async {
    var inputImage = _inputImageFromCameraImage();
    if (inputImage != null) {
      final List<Pose> poses = await poseDetector.processImage(inputImage);
      
      setState(() {
        _scanResults = poses;
        if (poses.isNotEmpty) {
          _currentPose = poses.first;
          
          // If in recording mode, automatically record poses
          if (_isRecording && _currentPose != null) {
            _recorder.recordPose(_currentState, _currentPose!);
            _statusMessage = 'Recording $_currentState: ${_recorder.getRecordedPoseCount(_currentState)} samples';
          }
        }
        isBusy = false;
      });
    } else {
      setState(() {
        isBusy = false;
      });
    }
  }
  
  // Record current pose
  void _recordCurrentPose() {
    if (_currentPose == null) {
      setState(() {
        _statusMessage = 'No pose detected. Make sure you are visible in the camera.';
      });
      return;
    }
    
    _recorder.recordPose(_currentState, _currentPose!);
    setState(() {
      _statusMessage = 'Recorded pose for $_currentState. Total: ${_recorder.getRecordedPoseCount(_currentState)}';
    });
  }
  
  // Start/stop recording mode
  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _statusMessage = 'RECORDING MODE: Strike the $_currentState pose and hold steady';
      } else {
        _statusMessage = 'Recording stopped';
      }
    });
  }
  
  // Save all recorded poses
  Future<void> _saveRecordedPoses() async {
    // Check if we have enough poses for each state
    bool hasEnoughPoses = true;
    String missingStates = '';
    
    for (final state in _exerciseStates) {
      int count = _recorder.getRecordedPoseCount(state);
      if (count < 5) {  // Recommend at least 5 poses per state
        hasEnoughPoses = false;
        missingStates += '${missingStates.isEmpty ? "" : ", "}$state ($count/5)';
      }
    }
    
    if (!hasEnoughPoses) {
      // Show warning but allow saving
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Not Enough Poses'),
          content: Text(
            'For best results, record at least 5 poses for each state.\n\n'
            'Missing: $missingStates\n\n'
            'Do you want to continue saving anyway?'
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Save Anyway'),
              onPressed: () {
                Navigator.pop(context);
                _doSaveRecordedPoses();
              },
            ),
          ],
        ),
      );
    } else {
      _doSaveRecordedPoses();
    }
  }
  
  // Actually save the poses
  Future<void> _doSaveRecordedPoses() async {
    setState(() {
      _statusMessage = 'Saving poses...';
    });
    
    await _recorder.saveRecordedPoses(widget.exerciseDataModel.type);
    
    setState(() {
      _statusMessage = 'Poses saved successfully!';
    });
    
    // Show success dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Poses Saved'),
        content: Text(
          'Reference poses have been saved successfully.\n\n'
          'You can now use them for exercise detection.'
        ),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    
    // Camera preview
    if (controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: Container(
            child: (controller!.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: CameraPreview(controller!),
                  )
                : Container(),
          ),
        ),
      );

      // Pose overlay
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height,
          child: buildResult(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Record ${widget.exerciseDataModel.title} Poses'),
        actions: [
          // Clear poses button
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: _confirmClearPoses,
            tooltip: 'Clear saved poses',
          ),
          // Save button
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveRecordedPoses,
            tooltip: 'Save all recorded poses',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera and pose visualization
          Container(
            color: Colors.black,
            child: Stack(children: stackChildren),
          ),
          
          // Controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status message
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Pose state selector
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _currentState,
                      dropdownColor: Colors.grey[800],
                      style: TextStyle(color: Colors.white),
                      isExpanded: true,
                      underline: Container(),
                      items: _exerciseStates.map((state) {
                        return DropdownMenuItem<String>(
                          value: state,
                          child: Text('$state (${_recorder.getRecordedPoseCount(state)} recorded)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _currentState = value;
                          });
                        }
                      },
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                        label: Text(_isRecording ? 'Stop' : 'Start Recording'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _toggleRecording,
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.camera),
                        label: Text('Record Pose'),
                        onPressed: _recordCurrentPose,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to convert CameraImage to InputImage
  InputImage? _inputImageFromCameraImage() {
    final camera = cameras[0];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    
    if (rotation == null || img == null) return null;
    
    // get image format
    final format = InputImageFormatValue.fromRawValue(img!.format.raw);
    
    // validate format depending on platform
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
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
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
  
  // Build pose visualization
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller!.value.isInitialized) {
      return Container();
    }
    
    final Size imageSize = Size(
      controller!.value.previewSize!.height,
      controller!.value.previewSize!.width,
    );
    
    CustomPainter painter = PosePainter(imageSize, _scanResults);
    return CustomPaint(painter: painter);
  }
  
  // Confirm before clearing poses
  void _confirmClearPoses() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Poses'),
        content: Text(
          'Are you sure you want to clear all recorded poses for this exercise?\n\n'
          'This will delete both the currently recorded poses and any previously saved poses.'
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Clear All'),
            onPressed: () {
              Navigator.pop(context);
              _clearAllPoses();
            },
          ),
        ],
      ),
    );
  }

  // Clear all poses
  Future<void> _clearAllPoses() async {
    setState(() {
      _statusMessage = 'Clearing poses...';
    });
    
    try {
      // Clear in-memory poses
      _recorder.clearRecordedPoses();
      
      // Delete saved file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${widget.exerciseDataModel.type.toString()}_poses.json');
      
      if (await file.exists()) {
        await file.delete();
      }
      
      setState(() {
        _statusMessage = 'All poses cleared successfully';
      });
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All poses have been cleared')),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error clearing poses: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing poses: $e')),
      );
    }
  }
} 