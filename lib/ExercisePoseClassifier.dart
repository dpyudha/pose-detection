import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/PoseClassifier.dart';
import 'package:pose_detection_realtime/PoseReferenceRecorder.dart';
import 'package:pose_detection_realtime/PredefinedPoseLoader.dart';

/// A specialized classifier for exercise poses that tracks repetitions
class ExercisePoseClassifier {
  // The base pose classifier
  final PoseClassifier _classifier = PoseClassifier();
  
  // Current exercise type
  final ExerciseType exerciseType;
  
  // Track exercise state
  String? _currentState;
  int _repCount = 0;
  
  // State transitions for counting reps
  final Map<String, String> _nextStates = {};
  
  // Flag to track if poses are loaded
  bool _posesLoaded = false;
  
  // For squat detection stability
  int _consecutiveDetections = 0;
  static const int _requiredConsecutiveDetections = 2;
  String? _lastDetectedState;
  
  // For debugging
  Map<String, double> _lastScores = {};
  
  // Constructor
  ExercisePoseClassifier({required this.exerciseType}) {
    _initializeExerciseStates();
    _loadPoses();
  }
  
  /// Initialize exercise states based on the exercise type
  void _initializeExerciseStates() {
    switch (exerciseType) {
      case ExerciseType.PushUps:
        _initializePushUpStates();
        break;
      case ExerciseType.Squats:
        _initializeSquatStates();
        break;
      case ExerciseType.DownwardDogPlank:
        _initializePlankDownwardDogStates();
        break;
      case ExerciseType.JumpingJack:
        _initializeJumpingJackStates();
        break;
    }
  }
  
  /// Load poses - either predefined or recorded
  Future<void> _loadPoses() async {
    try {
      if (exerciseType == ExerciseType.Squats) {
        // For squats, use predefined poses
        final predefinedPoses = await PredefinedPoseLoader.loadPredefinedPoses(exerciseType);
        
        if (predefinedPoses.isNotEmpty) {
          // Add all predefined poses to the classifier
          predefinedPoses.forEach((state, vectors) {
            _classifier.addReferenceState(state, vectors);
          });
          print('Loaded predefined poses for squats');
          print('Available states: ${predefinedPoses.keys.join(', ')}');
          
          // For each state, print how many reference poses were loaded
          predefinedPoses.forEach((state, vectors) {
            print('State $state: ${vectors.length} reference poses');
          });
          
          _posesLoaded = true;
        } else {
          print('No predefined poses found for squats');
        }
      } else {
        // For other exercises, try to load recorded poses
        final recorder = PoseReferenceRecorder();
        final savedPoses = await recorder.loadRecordedPoses(exerciseType);
        
        if (savedPoses.isNotEmpty) {
          // Add all saved poses to the classifier
          savedPoses.forEach((state, vectors) {
            _classifier.addReferenceState(state, vectors);
          });
          print('Loaded ${savedPoses.length} pose states for ${exerciseType.toString()}');
          print('Available states: ${savedPoses.keys.join(', ')}');
          
          // For each state, print how many reference poses were loaded
          savedPoses.forEach((state, vectors) {
            print('State $state: ${vectors.length} reference poses');
          });
          
          _posesLoaded = true;
        } else {
          print('No saved poses found for ${exerciseType.toString()}');
        }
      }
    } catch (e) {
      print('Error loading poses: $e');
    }
  }
  
  /// Check if poses are loaded
  bool get posesLoaded => _posesLoaded;
  
  /// Process a pose and return the current rep count
  int processPose(Pose pose) {
    // Get the current pose state
    final detectedState = _classifier.classifyPose(pose);
    
    // Store the scores for debugging
    _lastScores = _classifier.getLastScores();
    
    // If no state detected, return current count
    if (detectedState == null) {
      _consecutiveDetections = 0;
      _lastDetectedState = null;
      return _repCount;
    }
    
    // For squats, add extra logging
    if (exerciseType == ExerciseType.Squats) {
      print('Raw detected squat state: $detectedState');
    }
    
    // For stability, require consecutive detections of the same state
    if (_lastDetectedState == detectedState) {
      _consecutiveDetections++;
    } else {
      _consecutiveDetections = 1;
      _lastDetectedState = detectedState;
      return _repCount; // Return early, wait for stable detection
    }
    
    // Only proceed if we have enough consecutive detections
    if (_consecutiveDetections < _requiredConsecutiveDetections) {
      return _repCount;
    }
    
    // For squats, log the stable detection
    if (exerciseType == ExerciseType.Squats) {
      print('Stable squat state detected: $detectedState');
    }
    
    // If this is the first state detected
    if (_currentState == null) {
      _currentState = detectedState;
      return _repCount;
    }
    
    // Check if we've completed a rep
    if (_currentState != detectedState) {
      // Check if this is a valid transition
      if (_nextStates[_currentState] == detectedState) {
        // We've transitioned to the next expected state
        _currentState = detectedState;
        
        // If we've completed the full cycle, increment the rep count
        if (_isRepComplete(detectedState)) {
          _repCount++;
          
          // For squats, log when a rep is completed
          if (exerciseType == ExerciseType.Squats) {
            print('Squat rep completed! Count: $_repCount');
          }
        }
      } else {
        // This is an unexpected transition, but we'll still update the state
        _currentState = detectedState;
        
        // For squats, log state transitions
        if (exerciseType == ExerciseType.Squats) {
          print('Squat state transition (unexpected): $_currentState -> $detectedState');
          print('Expected next state would be: ${_nextStates[_currentState]}');
        }
      }
    }
    
    return _repCount;
  }
  
  /// Check if the current state completes a repetition
  bool _isRepComplete(String state) {
    switch (exerciseType) {
      case ExerciseType.PushUps:
        return state == 'push_up_up';
      case ExerciseType.Squats:
        return state == 'squat_up';
      case ExerciseType.DownwardDogPlank:
        return state == 'plank';
      case ExerciseType.JumpingJack:
        return state == 'jumping_jack_closed';
      default:
        return false;
    }
  }
  
  /// Reset the rep counter
  void resetCount() {
    _repCount = 0;
    _currentState = null;
    _consecutiveDetections = 0;
    _lastDetectedState = null;
  }
  
  /// Get the current rep count
  int getRepCount() {
    return _repCount;
  }
  
  /// Initialize push-up states and transitions
  void _initializePushUpStates() {
    // Define the states for push-ups
    _nextStates['push_up_up'] = 'push_up_down';
    _nextStates['push_up_down'] = 'push_up_up';
  }
  
  /// Initialize squat states and transitions
  void _initializeSquatStates() {
    // Define the states for squats
    _nextStates['squat_up'] = 'squat_down';
    _nextStates['squat_down'] = 'squat_up';
    
    // Print confirmation of squat state initialization
    print('Initialized squat states: ${_nextStates.keys.join(', ')}');
    print('Squat state transitions: ${_nextStates.entries.map((e) => '${e.key} -> ${e.value}').join(', ')}');
  }
  
  /// Initialize plank/downward dog states and transitions
  void _initializePlankDownwardDogStates() {
    _nextStates['plank'] = 'downward_dog';
    _nextStates['downward_dog'] = 'plank';
  }
  
  /// Initialize jumping jack states and transitions
  void _initializeJumpingJackStates() {
    _nextStates['jumping_jack_closed'] = 'jumping_jack_open';
    _nextStates['jumping_jack_open'] = 'jumping_jack_closed';
  }
  
  /// Record reference poses for an exercise
  /// This would be called during a "training" phase where the user demonstrates the poses
  void recordReferencePose(String stateName, Pose pose) {
    final poseVector = _classifier.poseToVector(pose);
    if (poseVector != null) {
      _classifier.addReferenceState(stateName, [poseVector]);
    }
  }
  
  /// Get the current state for debugging
  String? getCurrentState() {
    return _currentState;
  }
  
  /// Get the last detected state for debugging
  String? getLastDetectedState() {
    return _lastDetectedState;
  }
  
  /// Get the last match scores for debugging
  Map<String, double> getLastScores() {
    return _lastScores;
  }
} 