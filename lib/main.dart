// import 'dart:async';
// import 'dart:convert';
// // ignore: unused_import
// import 'dart:developer';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:gallery_saver/gallery_saver.dart';
// import 'package:image/image.dart' as img;
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:uni_links/uni_links.dart';

// import 'constants.dart';

// void main() {
//   runApp(const App());
// }

// class App extends StatelessWidget {
//   const App({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       theme: ThemeData(
//         useMaterial3: true,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.orange,
//         ),
//       ),
//       home: const Home(),
//     );
//   }
// }

// class Home extends StatefulWidget {
//   const Home({Key? key}) : super(key: key);

//   @override
//   State<Home> createState() => _HomeState();
// }

// class _HomeState extends State<Home> {
//   static const labelsPath = 'assets/models/label.txt';
//   static const modelPath = 'assets/models/model.tflite';

//   late final Interpreter interpreter;
//   late final List<String> labels;

//   Tensor? inputTensor;
//   Tensor? outputTensor;
//   List<String>? parsedLabels = [];
//   List<double> scores = [];

//   StreamSubscription? _sub;

//   String? encodedImage;

// Future<void> initUniLink() async {
//   _sub = linkStream.listen((String? link) {
//     if (link != null) {
//       var uri = Uri.parse(link);

//       encodedImage = uri.queryParameters['encodedImage'];

//       final String? thresholdStr = uri.queryParameters['threshold'];

//       print('Received link: $thresholdStr');
//       print('Received link: $encodedImage');

//       if (encodedImage != null) {
//         final decodedBytes = base64Decode(encodedImage!);
//         final imageMatrix = img.decodeImage(decodedBytes);

//         if (imageMatrix != null) {
//           runInference(convertImageMatrix(imageMatrix));
//         }
//       }
//     }
//   }, onError: (err) {});
// }

// List<List<List<int>>> convertImageMatrix(img.Image imageMatrix) {
//   final convertedMatrix = imageMatrix.data!.buffer.asUint8List().toList();
//   final width = imageMatrix.width;
//   final height = imageMatrix.height;

//   return List.generate(
//     height,
//     (y) => List.generate(
//       width,
//       (x) {
//         final index = (y * width + x) * 4;
//         final r = convertedMatrix[index];
//         final g = convertedMatrix[index + 1];
//         final b = convertedMatrix[index + 2];
//         return [r, g, b];
//       },
//     ),
//   );
// }

//   final imagePicker = ImagePicker();
//   String? imagePath;
//   img.Image? image;
//   File? imag;

//   Map<String, int>? classification;

//   @override
//   void initState() {
//     super.initState();

//     //This exits to make the app able to be called from a cold boot
//     initUniLink();

//     // Load model and labels from assets
//     loadModel();
//     loadLabels();
//   }

//   Map<String, int> classCount = {};

//   @override
//   void dispose() {
//     super.dispose();
//     _sub!.cancel();
//   }

//   Future getImage() async {
//     final ImagePicker picker = ImagePicker();

//     XFile? selectedImage = await picker.pickImage(source: ImageSource.gallery);

//     final imageTemporary =
//         img.decodeImage(File(selectedImage!.path).readAsBytesSync());

//     setState(() {
//       image = imageTemporary;
//       imag = File(selectedImage.path);
//     });
//   }

//   void classifyImage() async {
//     if (image == null) {
//       return;
//     }

//     // Resize image for model input ([320, 320])
//     final imageInput = img.copyResize(
//       image!,
//       width: WIDTH,
//       height: HEIGHT,
//     );

//     // Get image matrix representation [320, 320, 3]
//     final imageMatrix = List.generate(
//       imageInput.height,
//       (y) => List.generate(
//         imageInput.width,
//         (x) {
//           final pixel = imageInput.getPixel(x, y);
//           return [pixel.r, pixel.g, pixel.b]
//               .map((value) => value.toInt())
//               .toList();
//         },
//       ),
//     );

//     // Run model inference
//     runInference(imageMatrix);
//   }

//   Future<void> loadModel() async {
//     try {
//       interpreter = await Interpreter.fromAsset(modelPath);
//       final inputTensors = interpreter.getInputTensors();
//       final outputTensors = interpreter.getOutputTensors();

//       if (inputTensors.length != 1 || outputTensors.length != 1) {
//         throw Exception('Unexpected number of Tensors');
//       }

//       inputTensor = inputTensors[0];
//       outputTensor = outputTensors[0];
//     } catch (e) {
//       print('Error initializing tflite interpreter: $e');
//     }
//   }

//   Future<void> loadLabels() async {
//     try {
//       final labelsData = await rootBundle.loadString(labelsPath);
//       labels = labelsData.split('\n');
//       labels.removeLast();

//       parsedLabels = labels;
//     } catch (e) {
//       print('Error loading labels: $e');
//     }
//   }

//   Future<void> runInference(List<List<List<int>>> imageMatrix) async {
//     // ignore: unnecessary_null_comparison
//     if (interpreter == null) {
//       return;
//     }

//     // Prepare input data
//     final inputShape = interpreter.getInputTensor(0).shape;
//     final inputData = Float32List(inputShape.reduce((a, b) => a * b));

//     var pixelIndex = 0;
//     for (var i = 0; i < inputShape[0]; i++) {
//       for (var j = 0; j < inputShape[1]; j++) {
//         for (var k = 0; k < inputShape[2]; k++) {
//           final pixel = imageMatrix[i][j][k];
//           inputData[pixelIndex++] = pixel / 255.0;
//         }
//       }
//     }

//     // Prepare output data
//     final outputShape = interpreter.getOutputTensor(0).shape;
//     final outputData = Float32List(outputShape.reduce((a, b) => a * b));

//     // Run inference
//     interpreter.run(inputData.buffer, outputData.buffer);

//     // Post-process the output data
//     scores = outputData.sublist(0, outputShape[1]);

//     final Map<String, double> results = {};

//     for (var i = 0; i < scores.length; i++) {
//       final label = parsedLabels![i];
//       final score = scores[i];

//       results[label] = score;
//     }

//     setState(() {
//       classification = sortProb(results);
//     });
//   }

//   Map<String, int> sortProb(Map<String, double> prob) {
//     classCount.clear();
//     for (var element in prob.entries) {
//       classCount[element.key] = (element.value * 100).round();
//     }
//     return classCount;
//   }

//   Future<void> saveImage() async {
//     final time = DateTime.now().millisecondsSinceEpoch;

//     final Directory? appDirectory = await getExternalStorageDirectory();
//     final String imagePath = '${appDirectory!.path}/$time.jpg';

//     final File imageFile = File(imagePath);
//     await imageFile.writeAsBytes(img.encodeJpg(image!));

//     final bool result = await GallerySaver.saveImage(imagePath) ?? false;

//     if (result) {
//       print('Image saved to gallery');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Image Classification'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             if (image != null)
//               Container(
//                 margin: const EdgeInsets.all(16),
//                 child: Image.memory(
//                   img.encodeJpg(image!),
//                   fit: BoxFit.cover,
//                   height: 300,
//                 ),
//               ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: getImage,
//               child: const Text('Select Image'),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: classifyImage,
//               child: const Text('Classify Image'),
//             ),
//             const SizedBox(height: 16),
//             if (classification != null)
//               Column(
//                 children: [
//                   const Text(
//                     'Classification Results:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 8),
//                   ListView.builder(
//                     shrinkWrap: true,
//                     itemCount: classification!.length,
//                     itemBuilder: (BuildContext context, int index) {
//                       final className = classification!.keys.elementAt(index);
//                       final classCount =
//                           classification!.values.elementAt(index);
//                       return ListTile(
//                         title: Text(
//                           '$className: $classCount%',
//                           style: const TextStyle(fontSize: 16),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  //static const modelPath = 'assets/mobilenet/mobilenet_v1_1.0_224_quant.tflite';
  static const labelsPath = 'assets/models/label.txt';

  static const modelPath = 'assets/models/model.tflite';

  late final Interpreter interpreter;
  late final List<String> labels;

  Tensor? inputTensor;
  Tensor? outputTensor;
  List<String>? parsedLabels = [];
  List<double> scores = [];

  StreamSubscription? _sub;

  String? encodedImage;
  String? thresholdStr;

  Future<void> initUniLink() async {
    _sub = linkStream.listen((String? link) async {
      if (link != null) {
        var uri = Uri.parse(link);

        encodedImage = uri.queryParameters['encodedImage'];

        thresholdStr = uri.queryParameters['threshold'];

        if (encodedImage != null) {
          print('Received link: $thresholdStr');
          print('Received link: $encodedImage');
          final decodedBytes = base64Decode(encodedImage!);
          final directory = await getTemporaryDirectory();
          imag = File('${directory.path}/image.jpeg');
          imagePath = imag!.path;
          imag!.writeAsBytesSync(List.from(decodedBytes));
          setState(() {});
          final imageMatrix = img.decodeImage(decodedBytes);

          if (imageMatrix != null) {
            // await runInference(convertImageMatrix(imag!));
            processImage();
            setState(() {});
          }
        }
      }
    }, onError: (err) {
      print(err);
    });
  }

  void launchFilemaker(List<String> strings) async {
    final link = 'fmp://\$/GTMAI.fmp12?script=Receivetext&param= $strings';
    Uri uri = Uri.parse(link);

    launch(uri);
  }

  void launch(Uri url) async {
    await launchUrl(url);
  }

  List<List<List<num>>> convertImageMatrix(File image) {
    final imageData = File(image.path).readAsBytesSync();

    final convertImage = img.decodeImage(imageData);

    final imageInput =
        img.copyResize(convertImage!, width: WIDTH, height: HEIGHT);

    final imageMtrx = List.generate(
        imageInput.height,
        (y) => List.generate(imageInput.width, (x) {
              final pixel = imageInput.getPixel(x, y);
              return [pixel.r, pixel.g, pixel.b];
            }));

    return imageMtrx;
  }

  final imagePicker = ImagePicker();
  String? imagePath;
  img.Image? image;
  File? imag;

  Map<String, int>? classification;

  @override
  void initState() {
    super.initState();

    //This exits to make the app able to be called from a cold boot
    initUniLink();

    // Load model and labels from assets
    loadModel();
    loadLabels();
  }

  Map<String, int> classCount = {};

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _sub!.cancel();
  }

  Future getImage() async {
    final ImagePicker picker = ImagePicker();

    XFile? selectedImage = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imag = File(selectedImage!.path);
      Uint8List bytes = imag!.readAsBytesSync();
      image = img.decodeImage(bytes);
      imagePath = selectedImage.path;
      processImage(); // Run detection after image upload
    });
  }

  // Load model
  Future<void> loadModel() async {
    final options = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      options.addDelegate(XNNPackDelegate());
    }

    // Use Metal Delegate
    if (Platform.isIOS) {
      options.addDelegate(GpuDelegate());
    }

    // Load model from assets
    interpreter = await Interpreter.fromAsset(modelPath, options: options);
    // Get tensor input shape [1, 320, 320, 3]
    inputTensor = interpreter.getInputTensors().first;

    // Get tensor output shape [1, 25, 4]
    outputTensor = interpreter.getOutputTensors().first;

    setState(() {});

    log('Interpreter loaded successfully');
  }

  // Load labels from assets
  Future<void> loadLabels() async {
    final labelTxt = await rootBundle.loadString(labelsPath);
    labels = labelTxt.split('\n');
  }

  // Process picked image
  Future<void> processImage() async {
    scores.clear();
    parsedLabels!.clear();
    classCount.clear(); // Clear the class count

    if (imagePath != null) {
      // Read image bytes from file
      final imageData = File(imagePath!).readAsBytesSync();
      print(imageData);

      // Decode image using package:image/image.dart (https://pub.dev/image)
      image = img.decodeImage(imageData);

      setState(() {});

      // Resize image for model input ( [320, 320])
      final imageInput = img.copyResize(
        image!,
        width: WIDTH,
        height: HEIGHT,
      );

      // Get image matrix representation [320, 320, 3]
      final imageMatrix = List.generate(
        imageInput.height,
        (y) => List.generate(
          imageInput.width,
          (x) {
            final pixel = imageInput.getPixel(x, y);
            return [pixel.r, pixel.g, pixel.b];
          },
        ),
      );

      // Run model inference
      await runInference(imageMatrix);

      // Save labels and image
      if (parsedLabels!.isNotEmpty && scores.isNotEmpty) {
        print("here");
        double threshold = double.parse(thresholdStr!);

        final List<String> labelsAboveThreshold = [];
        final List<String> labelsBelowThreshold = [];

        for (int i = 0; i < parsedLabels!.length; i++) {
          final double score = scores[i];

          if (score > threshold) {
            labelsAboveThreshold.add(parsedLabels![i]);
          } else {
            labelsBelowThreshold.add(parsedLabels![i]);
          }
        }

        if (labelsBelowThreshold.length > labelsAboveThreshold.length) {
          // Save labels and image

          // saveLabels(labelsBelowThreshold);
          // saveImage(imagePath!);
          saveData(labelsBelowThreshold, scores, classCount);
        } else {
          // saveLabels(labelsAboveThreshold);
          saveData(labelsAboveThreshold, scores, classCount);
        }

        setState(() {});
      }
    }
  }

  void saveLabels(List<String> labels) async {
    // get the App's directory

    final docPath = await getApplicationDocumentsDirectory();

    // Create a path for labels

    final labelsPath = '${docPath.path}/labels';

    //Create the directory

    await Directory(labelsPath).create(recursive: true);

    //Create the directory for the file

    final file = File(labelsPath + '/labels.txt');

    //file.copy(newPath)

    String text = "sds";

//Write the file

    await file.writeAsString(labels.toString());
  }

  void saveImage(String imagePath) async {
    // Save the image file or perform desired operation
    // Example: Copying the image to a new location
    await GallerySaver.saveImage(imagePath!, albumName: 'trainingpics');
  }

  void saveData(
      List<String> labels, List<double> scores, Map<String, int> counts) async {
    // Save labels and counts to a file or perform desired operation
    // Example: Saving to a text file
    final StringBuffer data = StringBuffer();

    List<String> strings = [];

    for (int x = 0; x < labels.length; x++) {
      strings.add('${labels[x]}----${scores[x]}\n');
    }

    // get the App's directory

    final docPath = await getApplicationDocumentsDirectory();

    // Create a path for labels

    final labelsPath = '${docPath.path}/labels';

    //Create the directory

    await Directory(labelsPath).create(recursive: true);

    //Create the directory for the file

    String fileString = '$strings\n\n\n\n\n$counts';

    final file = File(labelsPath + '/labels.txt');

    //file.copy(newPath)

//Write the file

    await file.writeAsString(fileString);

    launchFilemaker(strings);
  }

  // Run inference
  Future<void> runInference(
    List<List<List<num>>> imageMatrix,
  ) async {
    // Set tensor input [1, 320, 320, 3]
    final input = [imageMatrix];

    // Set tensor output [1, 25]
    final output = List.filled(25, 0.0);

    // Run inference
    var res = interpreter.run(input, output);

    // Get result

    for (var i = 0; i < res[3][0].length; i++) {
      if (res[3][0][i] != 0 &&
          res[0][0][i] * 100 > double.parse(thresholdStr!)) {
        final label = labels[res[3][0][i].round()];
        final score = res[0][0][i] * 100;
        parsedLabels!.add(label);
        scores.add(score);

        // Update class count
        classCount[label] =
            classCount.containsKey(label) ? classCount[label]! + 1 : 1;
      }
    }

    // _isLoaded = true;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome to GTM-AI"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Image(
              image: AssetImage('assets/models/MicrosoftTeams-image.png'),
              width: 200,
              height: 200,
            ),
          ],
        ),
      ),
    );
  }
}
