# Real-Time Squat Detection

A Flutter application that performs real-time squat detection using ML Kit's pose detection.

## How Squat Detection Works

### 1. Predefined Poses in JSON

The application uses predefined squat poses stored in a JSON file (`assets/squat_poses.json`). Each pose is represented as a normalized vector of key body landmarks:

```json
{
  "squat_up": [
    {
      "landmarks": [
        {"x": 0.5, "y": 0.2, "z": 0.0, "visibility": 0.9},
        ...
      ]
    }
  ],
  "squat_down": [
    {
      "landmarks": [
        {"x": 0.5, "y": 0.4, "z": 0.0, "visibility": 0.9},
        ...
      ]
    }
  ]
}
```

The JSON structure contains:
- **Pose categories**: "squat_up" and "squat_down"
- **Multiple variations** of each pose for better detection
- **Landmark coordinates**:
  - `x`, `y`: Normalized coordinates (0-1) representing position in the frame
  - `z`: Depth information (when available)
  - `visibility`: Confidence score for landmark detection (0-1)

### 2. ML Kit Pose Detection

1. The camera feed is processed frame-by-frame using ML Kit's pose detection
2. ML Kit identifies 33 key body landmarks (joints) in each frame
3. These landmarks include ankles, knees, hips, shoulders, etc.
4. Each landmark has x, y coordinates and a confidence score

### 3. Pose Classification

1. The detected pose landmarks are normalized to make them scale and position invariant
2. The normalized pose is compared against the predefined poses in the JSON file
3. Cosine similarity is calculated between the current pose vector and each reference pose
4. The pose with the highest similarity score above a threshold is selected
5. To prevent false positives, the system requires multiple consecutive detections of the same pose

### 4. Squat Counter

1. The application tracks transitions between "squat_up" and "squat_down" poses
2. A complete squat is counted when the user moves from "squat_up" to "squat_down" and back to "squat_up"
3. The counter increments only when the full motion is completed

### 5. Debug Mode

The application includes a debug mode that displays:
- Current pose classification
- Similarity scores
- Landmark positions
- Detection confidence

## Getting Started

1. Ensure you have Flutter installed on your machine
2. Clone the repository
3. Run `flutter pub get` to install dependencies
4. Connect a device and run `flutter run`

## Requirements

- Flutter 2.0 or higher
- Camera-enabled device
- ML Kit dependencies
