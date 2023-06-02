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

  @override
  void initState() {
    super.initState();

    //This exits to make the app able to be called from a cold boot
    initUniLink();

    // Load model and labels from assets
    loadModel();
    loadLabels();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _sub!.cancel();
  }

  Future getImage() async {
    final ImagePicker picker = ImagePicker();

    XFile? selectedImage =
        (await picker.pickImage(source: ImageSource.gallery));
    setState(() {
      imag = File(selectedImage!.path);
      Uint8List bytes = imag!.readAsBytesSync();
      image = img.decodeImage(bytes);
      imagePath = selectedImage.path;
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
    final output = List.filled(25, 0.0);

    // Run inference
    var res = interpreter.run(input, output);

    // Get result

    for (var i = 0; i < res[3][0].length; i++) {
      if (res[3][0][i] != 0) {
        // Set label: points
        parsedLabels!.add(labels[res[3][0][i].round()]);
        scores.add(res[0][0][i] * 100);
      }
    }

    // _isLoaded = true;

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
