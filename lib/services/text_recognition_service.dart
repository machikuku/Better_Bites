import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRecognitionService {
  void recognizeText(BuildContext context, File imageFile,
      Future<void> Function(String?, Object?) callback) async {
    // Show the loading dialog

    try {
      // Initialize the TextRecognizer
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      // Process the image using ML Kit
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      textRecognizer.close();

      debugPrint('Recognized text: ${recognizedText.text}');

      if (recognizedText.text.trim().isEmpty) {
        throw 'Error processing image: No text found in the image';
      }

      if (context.mounted) {
        // Perform the callback
        await callback(recognizedText.text, null);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      callback(null, e);
    }
  }
}
