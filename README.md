### BetterBites

BetterBites is a Flutter mobile application that helps users make informed dietary choices by analyzing food package ingredients based on their unique health profile. The app uses OCR (Optical Character Recognition) to scan ingredient labels and provides personalized recommendations, allergen alerts, and health tips.

## Features

### User Profiling

- Create a personalized health profile with age, sex, height, weight, and health conditions
- BMI calculation and categorization (underweight, normal, overweight, obese)
- Profile history tracking to see changes over time


### Food Analysis

- Scan food package ingredient labels using your device's camera
- Upload existing food label images from your gallery
- Receive detailed analysis of ingredients and their health impacts
- View allergen warnings specific to your health profile
- Get personalized health tips and recommendations


### Ingredient Analysis

- Detailed breakdown of each ingredient and its health impact
- Personalized consumption guidance based on your health profile
- Suggested healthier alternatives for concerning ingredients
- Information on ingredient quantities and recommended limits


### Allergen Detection

- Identification of common allergens in food products
- Detailed explanation of potential reactions
- Personalized impact assessment based on your health conditions


### History Tracking

- Save all your food scans for future reference
- Review past analyses with detailed information
- Edit and organize your scan history


### Reanalysis

- Reanalyze previously scanned items with your updated health profile
- Compare how changes in your health profile affect food recommendations


## Technology Stack

- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **SQLite (sqflite)**: Local database for storing user profiles and food analyses
- **Google ML Kit**: Text recognition from images
- **Camera**: Device camera integration for scanning
- **Image Picker**: Gallery access for uploading images


## Installation

### Prerequisites

- Flutter SDK (version 3.5.3 or higher)
- Dart SDK (version 3.5.3 or higher)


### Steps

1. Clone the repository:

```plaintext
git clone https://github.com/yourusername/betterbitees.git
```


2. Navigate to the project directory:

```plaintext
cd betterbitees
```


3. Install dependencies:

```plaintext
flutter pub get
```


4. Run the app:

```plaintext
flutter run
```


## Usage

1. **First Launch**: Create your health profile by providing your age, sex, height, weight, and any health conditions.
2. **Scanning Food**: Tap the "SCAN" button on the home screen to access the camera. Point your camera at a food ingredient label and take a photo.
3. **Viewing Analysis**: After scanning, the app will analyze the ingredients and provide:

1. Ingredient breakdown with health impacts
2. Allergen warnings
3. Personalized health tips
4. **History**: Access your scan history by tapping the "HISTORY" button on the home screen.
5. **Profile Updates**: Update your health profile by tapping the "PROFILE" button to ensure recommendations stay relevant to your current health status.


## Dependencies

Major dependencies include:

- `camera`: ^0.11.0+2
- `image_picker`: ^1.1.2
- `path_provider`: ^2.0.13
- `sqflite`: ^2.4.1
- `google_mlkit_text_recognition`: ^0.14.0
- `google_generative_ai`: ^0.4.7
- `http`: ^1.2.2
- `flutter_svg`: ^2.0.15
- `lottie`: ^3.2.0
- `animated_notch_bottom_bar`: ^1.0.1
- `flutter_expandable_fab`: ^2.3.0
- `typewritertext`: ^3.0.9
- `shared_preferences`: ^2.5.2


For a complete list of dependencies, see the `pubspec.yaml` file.

## Key Features Implementation

## Privacy

BetterBites respects user privacy:

- All data is stored locally on your device
- No personal health information is transmitted to external servers
- Food analysis is performed using secure API calls
- No user tracking or analytics are implemented


## Troubleshooting

### Common Installation Issues

1. **Flutter SDK not found**

1. Ensure Flutter is properly installed and added to your PATH
2. Run `flutter doctor` to verify your installation



2. **Dependency conflicts**

1. Run `flutter clean` followed by `flutter pub get`
2. Check for outdated dependencies in pubspec.yaml



3. **Camera permission issues**

1. Ensure your app has the proper permissions in AndroidManifest.xml and Info.plist
2. For Android: Add `<uses-permission android:name="android.permission.CAMERA" />`
3. For iOS: Add `NSCameraUsageDescription` in Info.plist



4. **Google ML Kit issues**

1. Ensure you have the latest version of Google ML Kit dependencies
2. Check for compatibility issues with your Flutter version
