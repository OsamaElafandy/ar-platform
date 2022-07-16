import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:image/image.dart' as image_lib;
import 'package:ratering_gen_zero/core/utils/image_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';



class Hands {
  static const String MODEL_FILE_NAME = 'models/full.tflite';
  // SendPort sendToIsolatePort;

  /// model input
  static const int INPUT_SIZE = 224;

  //224;
  static const double EXIST_THRESHOLD = 0.1;
  static const double SCORE_THRESHOLD = 0.25;

  Interpreter _interpreter;

  /// model output
  final _outputShapes = <List<int>>[];
  final _outputTypes = <TfLiteType>[];

  Interpreter get interpreter => _interpreter;
  int get getAddress => _interpreter.address;

  Hands({Interpreter interpreter}) {
    _loadModel(interpreter: interpreter);
  }

  void _loadModel({Interpreter interpreter}) async {
    try {
      final interpreterOptions = InterpreterOptions();

      _interpreter = interpreter ??
          await Interpreter.fromAsset(MODEL_FILE_NAME,
              options: interpreterOptions);

      final outputTensors = _interpreter.getOutputTensors();

      outputTensors.forEach((tensor) {
        _outputShapes.add(tensor.shape);
        _outputTypes.add(tensor.type);
      });
    } catch (e) {
      print('Error while creating interpreter: $e');
    }
  }

  TensorImage _getProcessedImage(TensorImage inputImage) {
    final imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(INPUT_SIZE, INPUT_SIZE, ResizeMethod.BILINEAR))
        .add(NormalizeOp(0, 255))
        .build();

    inputImage = imageProcessor.process(inputImage);
    return inputImage;
  }

  Map<String, dynamic> _predict(image_lib.Image image) {
    if (_interpreter == null) {
      print('Interpreter not initialized');
      return null;
    }

    if (Platform.isAndroid) {
      image = image_lib.copyRotate(image, -90);
      image = image_lib.flipVertical(image);
      image = image_lib.flipHorizontal(image);
    }
    final tensorImage = TensorImage(TfLiteType.float32);
    tensorImage.loadImage(image);
    final inputImage = _getProcessedImage(tensorImage);

    TensorBuffer outputLandmarks = TensorBufferFloat(_outputShapes[0]);
    TensorBuffer outputExist = TensorBufferFloat(_outputShapes[1]);
    TensorBuffer outputScores = TensorBufferFloat(_outputShapes[2]);
    TensorBuffer outputX = TensorBufferFloat(_outputShapes[3]);
    final inputs = <Object>[inputImage.buffer];

    final outputs = <int, Object>{
      0: outputLandmarks.buffer,
      1: outputExist.buffer,
      2: outputScores.buffer,
      3: outputX.buffer,
    };

    _interpreter.runForMultipleInputs(inputs, outputs);

    if (outputExist.getDoubleValue(0) < EXIST_THRESHOLD) {
      return null;
    }

    final landmarkPoints = outputLandmarks.getDoubleList().reshape([21, 3]);
    final landmarkResults = <Offset>[];
    for (var point in landmarkPoints) {
      landmarkResults.add(Offset(
        (point[0] / INPUT_SIZE * image.width) /2,
        (point[1] / INPUT_SIZE * image.height) / 1.55,
      ));
    }

 //   print("444444444444444" + landmarkResults[4].toString());
  //  print("88888888888888" + landmarkResults[8].toString());

    return {
      'point': landmarkResults
    };
  }
}

Map<String, dynamic> runHandDetector(Map<String, dynamic> params) {
  final handDetection =
      Hands(interpreter: Interpreter.fromAddress(params['detectorAddress']));

  final image = ImageUtils.convertCameraImage(params['cameraImage']);
  final result = handDetection._predict(image);

  return result;
}
