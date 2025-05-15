import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pose_detection_realtime/DetectionScreen.dart';
import 'package:pose_detection_realtime/Model/ExerciseDataModel.dart';
import 'package:pose_detection_realtime/PoseRecordingScreen.dart';

class ExerciseListingScreen extends StatefulWidget {
  const ExerciseListingScreen({super.key});

  @override
  State<ExerciseListingScreen> createState() => _ExerciseListingScreenState();
}

class _ExerciseListingScreenState extends State<ExerciseListingScreen> {
  List<ExerciseDataModel> exerciseList = [];

  loadData() {
    // exerciseList.add(
    //   ExerciseDataModel("Push Ups", "pushup.gif", Color(0xff005F9c), ExerciseType.PushUps),
    // );
    exerciseList.add(
      ExerciseDataModel("Squats", "squat.gif", Color(0xffDF5089), ExerciseType.Squats),
    );
    // exerciseList.add(
    //   ExerciseDataModel(
    //     "Plank to downward Dog",
    //     "plank.gif",
    //     Color(0xffFD8636),
    //     ExerciseType.DownwardDogPlank,
    //   ),
    // );
    // exerciseList.add(
    //   ExerciseDataModel("Jumping jack", "jumping.gif", Color(0xff000000), ExerciseType.JumpingJack),
    // );
    setState(() {
      exerciseList;
    });
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI Exercises"),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text("About Pose Classification"),
                  content: Text(
                    "For best results, record reference poses for each exercise before using them.\n\n"
                    "Each exercise needs at least 5 reference poses for each state (e.g., 'up' and 'down' positions)."
                  ),
                  actions: [
                    TextButton(
                      child: Text("OK"),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        child: ListView.builder(
          itemBuilder: (context, index) {
            return Container(
              height: 150,
              decoration: BoxDecoration(
                color: exerciseList[index].color,
                borderRadius: BorderRadius.circular(20),
              ),
              margin: EdgeInsets.all(10),
              padding: EdgeInsets.all(15),
              child: Column(
                children: [
                  // Exercise info
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                exerciseList[index].title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Image.asset('assets/${exerciseList[index].image}'),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.videocam),
                          label: Text("Practice"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (context) => DetectionScreen(
                                  exerciseDataModel: exerciseList[index],
                                )
                              )
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 10),
                      // Expanded(
                      //   child: ElevatedButton.icon(
                      //     icon: Icon(Icons.camera_alt),
                      //     label: Text("Record Poses"),
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: Colors.white.withOpacity(0.2),
                      //       foregroundColor: Colors.white,
                      //     ),
                      //     onPressed: () {
                      //       Navigator.push(
                      //         context, 
                      //         MaterialPageRoute(
                      //           builder: (context) => PoseRecordingScreen(
                      //             exerciseDataModel: exerciseList[index],
                      //           )
                      //         )
                      //       );
                      //     },
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            );
          },
          itemCount: exerciseList.length,
        ),
      ),
    );
  }
}
