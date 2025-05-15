import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/PoseClassifier.dart';

/// A class to record reference poses for exercises
class PoseReferenceRecorder {
  final PoseClassifier _classifier = PoseClassifier();
  final Map<String, List<PoseVector>> _recordedPoses = {};
  
  /// Record a reference pose for a specific exercise state
  void recordPose(String exerciseState, Pose pose) {
    final poseVector = _classifier.poseToVector(pose);
    if (poseVector != null) {
      if (!_recordedPoses.containsKey(exerciseState)) {
        _recordedPoses[exerciseState] = [];
      }
      _recordedPoses[exerciseState]!.add(poseVector);
      print('Recorded pose for $exerciseState. Total: ${_recordedPoses[exerciseState]!.length}');
    }
  }
  
  /// Save recorded poses to a file
  Future<void> saveRecordedPoses(ExerciseType exerciseType) async {
    if (_recordedPoses.isEmpty) {
      print('No poses recorded to save');
      return;
    }
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${exerciseType.toString()}_poses.json');
      
      // Convert pose vectors to a serializable format
      final Map<String, List<Map<String, dynamic>>> serializedPoses = {};
      
      _recordedPoses.forEach((state, vectors) {
        serializedPoses[state] = [];
        
        for (final vector in vectors) {
          final Map<String, Map<String, double>> serializedVector = {};
          
          vector.vectors.forEach((type, vec) {
            serializedVector[type.index.toString()] = {
              'x': vec.x,
              'y': vec.y,
            };
          });
          
          serializedPoses[state]!.add({'vectors': serializedVector});
        }
      });
      
      await file.writeAsString(jsonEncode(serializedPoses));
      print('Saved poses to ${file.path}');
    } catch (e) {
      print('Error saving poses: $e');
    }
  }
  
  /// Load previously recorded poses from a file
  Future<Map<String, List<PoseVector>>> loadRecordedPoses(ExerciseType exerciseType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${exerciseType.toString()}_poses.json');
      
      if (!await file.exists()) {
        print('No saved poses found for ${exerciseType.toString()}');
        return {};
      }
      
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      final Map<String, List<PoseVector>> loadedPoses = {};
      
      data.forEach((state, vectorsData) {
        loadedPoses[state] = [];
        
        for (final vectorData in vectorsData) {
          final Map<PoseLandmarkType, Vector2D> vectors = {};
          
          final Map<String, dynamic> serializedVectors = vectorData['vectors'];
          serializedVectors.forEach((keyString, value) {
            final int keyIndex = int.parse(keyString);
            final type = PoseLandmarkType.values[keyIndex];
            
            vectors[type] = Vector2D(
              value['x'],
              value['y'],
            );
          });
          
          loadedPoses[state]!.add(PoseVector(vectors));
        }
      });
      
      print('Loaded poses for ${exerciseType.toString()}');
      return loadedPoses;
    } catch (e) {
      print('Error loading poses: $e');
      return {};
    }
  }
  
  /// Clear all recorded poses
  void clearRecordedPoses() {
    _recordedPoses.clear();
    print('Cleared all recorded poses');
  }
  
  /// Get the number of recorded poses for a specific state
  int getRecordedPoseCount(String exerciseState) {
    return _recordedPoses[exerciseState]?.length ?? 0;
  }
}

/// A widget for recording reference poses
class PoseRecordingScreen extends StatefulWidget {
  final ExerciseType exerciseType;
  
  const PoseRecordingScreen({Key? key, required this.exerciseType}) : super(key: key);
  
  @override
  _PoseRecordingScreenState createState() => _PoseRecordingScreenState();
}

class _PoseRecordingScreenState extends State<PoseRecordingScreen> {
  final PoseReferenceRecorder _recorder = PoseReferenceRecorder();
  String _currentState = '';
  final List<String> _exerciseStates = [];
  
  @override
  void initState() {
    super.initState();
    _initializeStates();
  }
  
  void _initializeStates() {
    switch (widget.exerciseType) {
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
  
  void _recordPose(Pose pose) {
    _recorder.recordPose(_currentState, pose);
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    // This is a placeholder UI - in a real app, you would integrate this with camera feed
    return Scaffold(
      appBar: AppBar(
        title: Text('Record ${widget.exerciseType.toString()} Poses'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Position yourself in the $_currentState pose and tap Record',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                DropdownButton<String>(
                  value: _currentState,
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
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // In a real implementation, you would get the pose from the pose detector
                        // _recordPose(currentPose);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('This is a placeholder. In a real app, this would record the current pose.')),
                        );
                      },
                      child: Text('Record Pose'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _recorder.saveRecordedPoses(widget.exerciseType);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Poses saved successfully')),
                        );
                      },
                      child: Text('Save Poses'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 