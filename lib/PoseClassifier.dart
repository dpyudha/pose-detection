import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// A class that handles pose classification based on vector representation of landmarks
class PoseClassifier {
  // Constants for classification thresholds
  static const double _poseMatchThreshold = 0.35; // Lowered for better matching
  static const double _confidenceThreshold = 0.3; // Lowered for better detection

  // Map of exercise states with their reference pose vectors
  final Map<String, List<PoseVector>> _referenceStates = {};
  
  // Store the last match scores for debugging
  Map<String, double> _lastScores = {};

  /// Constructor with optional reference states
  PoseClassifier({Map<String, List<PoseVector>>? referenceStates}) {
    if (referenceStates != null) {
      _referenceStates.addAll(referenceStates);
    }
  }

  /// Add a reference pose state for an exercise
  void addReferenceState(String exerciseState, List<PoseVector> poseVectors) {
    _referenceStates[exerciseState] = poseVectors;
  }

  /// Classify a pose against reference states
  /// Returns the name of the matching state or null if no match
  String? classifyPose(Pose pose) {
    if (_referenceStates.isEmpty) {
      return null;
    }

    // Convert pose to vector representation
    final poseVector = poseToVector(pose);
    if (poseVector == null) {
      print('Not enough landmarks detected with sufficient confidence');
      return null; // Not enough landmarks detected
    }

    // Find the best matching state
    String? bestMatch;
    double bestScore = 0;
    Map<String, double> allScores = {};

    for (final entry in _referenceStates.entries) {
      final stateName = entry.key;
      final referenceVectors = entry.value;

      // Compare with each reference vector for this state
      double bestStateScore = 0;
      for (final referenceVector in referenceVectors) {
        final similarity = _calculateCosineSimilarity(poseVector, referenceVector);
        if (similarity > bestStateScore) {
          bestStateScore = similarity;
        }
      }
      
      // Store the best score for this state
      allScores[stateName] = bestStateScore;
      
      // Check if this is the best match overall
      if (bestStateScore > _poseMatchThreshold && bestStateScore > bestScore) {
        bestScore = bestStateScore;
        bestMatch = stateName;
      }
    }
    
    // Store the scores for debugging
    _lastScores = allScores;
    
    // Print detailed matching information
    if (allScores.isNotEmpty) {
      final scoresLog = allScores.entries
          .map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}')
          .join(', ');
      print('Pose match scores: $scoresLog');
      
      if (bestMatch != null) {
        print('Best match: $bestMatch (${bestScore.toStringAsFixed(2)})');
      } else {
        print('No match above threshold (${_poseMatchThreshold})');
      }
    }

    return bestMatch;
  }

  /// Get the last match scores for debugging
  Map<String, double> getLastScores() {
    return _lastScores;
  }

  /// Convert a pose to a normalized vector representation
  /// Returns null if not enough landmarks are detected with sufficient confidence
  PoseVector? poseToVector(Pose pose) {
    // Filter landmarks with sufficient confidence
    final validLandmarks = pose.landmarks.entries
        .where((entry) => entry.value.likelihood >= _confidenceThreshold)
        .toList();

    // Need a minimum number of landmarks for reliable classification
    // Reduced for better detection
    if (validLandmarks.length < 8) {
      return null;
    }

    // Find center of the pose (average of hips and shoulders)
    final centerLandmarks = [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ];

    final centerPoints = centerLandmarks
        .map((type) => pose.landmarks[type])
        .where((landmark) => landmark != null)
        .toList();

    if (centerPoints.isEmpty) {
      return null;
    }

    double centerX = 0, centerY = 0;
    for (final point in centerPoints) {
      centerX += point!.x;
      centerY += point.y;
    }
    centerX /= centerPoints.length;
    centerY /= centerPoints.length;

    // Calculate scale based on the distance between shoulders
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    double scale = 1.0;

    if (leftShoulder != null && rightShoulder != null) {
      final shoulderDistance = sqrt(
        pow(leftShoulder.x - rightShoulder.x, 2) +
        pow(leftShoulder.y - rightShoulder.y, 2),
      );
      scale = shoulderDistance > 0 ? 1.0 / shoulderDistance : 1.0;
    }

    // Create normalized vectors for each landmark relative to center
    final Map<PoseLandmarkType, Vector2D> vectors = {};
    for (final entry in pose.landmarks.entries) {
      final type = entry.key;
      final landmark = entry.value;

      if (landmark.likelihood >= _confidenceThreshold) {
        // Normalize position relative to center and scale
        final normalizedX = (landmark.x - centerX) * scale;
        final normalizedY = (landmark.y - centerY) * scale;
        
        vectors[type] = Vector2D(normalizedX, normalizedY);
      }
    }

    return PoseVector(vectors);
  }

  /// Calculate cosine similarity between two pose vectors
  double _calculateCosineSimilarity(PoseVector vector1, PoseVector vector2) {
    // Find common landmark types between the vectors
    final commonTypes = vector1.vectors.keys
        .where((type) => vector2.vectors.containsKey(type))
        .toList();

    if (commonTypes.isEmpty) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    // Calculate dot product and magnitudes
    for (final type in commonTypes) {
      final v1 = vector1.vectors[type]!;
      final v2 = vector2.vectors[type]!;

      // Dot product of position vectors
      dotProduct += (v1.x * v2.x) + (v1.y * v2.y);
      
      // Magnitudes
      magnitude1 += v1.x * v1.x + v1.y * v1.y;
      magnitude2 += v2.x * v2.x + v2.y * v2.y;
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    // Avoid division by zero
    if (magnitude1 == 0 || magnitude2 == 0) {
      return 0.0;
    }

    return dotProduct / (magnitude1 * magnitude2);
  }
}

/// Represents a 2D vector (x,y coordinates)
class Vector2D {
  final double x;
  final double y;

  Vector2D(this.x, this.y);
}

/// Represents a pose as a collection of normalized vectors
class PoseVector {
  final Map<PoseLandmarkType, Vector2D> vectors;

  PoseVector(this.vectors);
} 