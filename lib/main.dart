import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:uni_links/uni_links.dart';

import 'constants.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  static const labelsPath = 'assets/models/label.txt';

  static const modelPath = 'assets/models/model.tflite';

  late final Interpreter interpreter;
  late final List<String> labels;

  Tensor? inputTensor;
  Tensor? outputTensor;
  List<String>? parsedLabels = [];
  List<double> scores = [];

  StreamSubscription? _sub;

  Future<void> initUniLink() async {
    _sub = linkStream.listen((String? link) {
      if (link != null) {
        var uri = Uri.parse(link);
      }
    }, onError: (err) {});
  }

  final imagePicker = ImagePicker();
  String? imagePath;
  img.Image? image;
  File? imag;

  Map<String, int>? classification;

//The initState function is called once this page is loaded
  @override
  void initState() {
    super.initState();

    //This exits to make the app able to be called from a cold boot
    initUniLink();

    // Load model and labels from assets once the page loads
    loadModel();
    loadLabels();
  }

  ///Release resources used once we leave the page to prevent performace issues
  ///(more relevant in a multipage application)
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();

    //Cancel the listening stream
    _sub!.cancel();
  }

  ///Function to get the image from the gallery using the ImagePicker package
  Future getImage() async {
    final ImagePicker picker = ImagePicker();

    XFile? selectedImage =
        //this will  get from gallery. Use ImageSource.camera for the camera
        (await picker.pickImage(source: ImageSource.gallery));

    ///Setstate is called to refresh the page once an event happens. In this case,
    ///we call setstate to load the picture onto the page once the use has selected a picture
    setState(() {
      imag = File(selectedImage!.path);
      Uint8List bytes = imag!.readAsBytesSync();
      image = img.decodeImage(bytes);
      imagePath = selectedImage.path;
    });
  }

  // Load model using the modified tflite_flutter package
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

    // Get tensor output shape
    outputTensor = interpreter.getOutputTensors().first;

    setState(() {});

    log('Interpreter loaded successfully');
  }

  // Load labels from assets
  Future<void> loadLabels() async {
    final labelTxt = await rootBundle.loadString(labelsPath);
    //Split each label with the newline character
    labels = labelTxt.split('\n');
  }

  // Process picked image to be able to pass it into the model
  //the Image package is used here to allow for image manipulation
  Future<void> processImage() async {
    ///Clear the Lists that contain the scores and labels
    scores.clear();
    parsedLabels!.clear();
    if (imagePath != null) {
      // Read image bytes from file
      final imageData = File(imagePath!).readAsBytesSync();

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
            // img.Pixel pixel;
            final pixel = imageInput.getPixel(x, y);
            return [pixel.r, pixel.g, pixel.b];
          },
        ),
      );

      // Run model inference
      runInference(imageMatrix);
    }
  }

  // Run inference
  Future<void> runInference(
    List<List<List<num>>> imageMatrix,
  ) async {
    // Set tensor input [1, 320, 320, 3]
    final input = [imageMatrix];

    // Set tensor output [1, 25]
    ///Since the Interpreter was modified specifically for this model, the output format does not matter
    ///But this is the expected output from the model.
    final output = List.filled(25, 0.0);

    // Run inference and store the results in a variable
    var res = interpreter.run(input, output);

    // Get results and put them in lists by score and label index

    for (var i = 0; i < res[3][0].length; i++) {
      if (res[3][0][i] != 0) {
        // Set labels: the model returns the indices of the labels as doubles
        //so they are rounded
        parsedLabels!.add(labels[res[3][0][i].round()]);
        scores.add(res[0][0][i] * 100);
      }
    }

//SetState is called once again to rebuild the widget tree now that we have the data in the lists
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Recognition"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              child: imag != null
                  ? Column(
                      children: [
                        Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(image: FileImage(imag!))),
                        ),
                        ElevatedButton(
                            onPressed: () {
                              processImage();
                            },
                            child: const Text("Process Image"))
                      ],
                    )
                  : Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text("SELECT IMAGE")),
                    ),
              onTap: () {
                getImage();
              },
            ),
            parsedLabels == [] || scores == []
                ? const Text("data")
                : Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (int x = 0; x < parsedLabels!.length; x++)
                            Container(
                              padding: const EdgeInsets.all(8),
                              child: ListTile(
                                title: Text(parsedLabels![x]),
                                subtitle: Text(scores[x].toString()),
                              ),
                            )
                        ],
                      ),
                    ),
                  )
          ],
        ),
      ),
    );
  }
}
