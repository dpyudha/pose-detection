import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/PoseClassifier.dart';

/// A class to load predefined pose vectors from JSON assets
class PredefinedPoseLoader {
  /// Load predefined poses for a specific exercise type
  static Future<Map<String, List<PoseVector>>> loadPredefinedPoses(ExerciseType exerciseType) async {
    try {
      String assetPath;
      
      // Select the appropriate asset file based on exercise type
      switch (exerciseType) {
        case ExerciseType.Squats:
          assetPath = 'assets/squat_poses.json';
          break;
        // Add other exercise types here if needed
        default:
          return {};
      }
      
      // Load the JSON file
      final String jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      final Map<String, List<PoseVector>> loadedPoses = {};
      
      // Parse the JSON data into PoseVector objects
      data.forEach((state, vectorsData) {
        loadedPoses[state] = [];
        
        for (final vectorData in vectorsData) {
          final Map<PoseLandmarkType, Vector2D> vectors = {};
          
          final Map<String, dynamic> serializedVectors = vectorData['vectors'];
          serializedVectors.forEach((keyString, value) {
            final int keyIndex = int.parse(keyString);
            final type = PoseLandmarkType.values[keyIndex];
            
            vectors[type] = Vector2D(
              value['x'].toDouble(),
              value['y'].toDouble(),
            );
          });
          
          loadedPoses[state]!.add(PoseVector(vectors));
        }
      });
      
      print('Loaded predefined poses for ${exerciseType.toString()}');
      return loadedPoses;
    } catch (e) {
      print('Error loading predefined poses: $e');
      return {};
    }
  }
} 