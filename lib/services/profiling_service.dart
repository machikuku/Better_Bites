import 'package:betterbitees/models/profiling.dart';
import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfilingService {
  final ProfilingRepo profilingRepo;

  ProfilingService({required this.profilingRepo});

  // Save the profile data in the local database and add to history
  Future<void> saveProfile(Profiling profiling) async {
    try {
      // Add a timestamp to the profiling data
      final profilingWithTimestamp = profiling.copyWith(
        createdAt: DateTime.now().toIso8601String(),
      );
      await profilingRepo.upsert(profilingWithTimestamp);  // Upsert to save current profile and add to history
    } catch (e) {
      throw Exception('Failed to save profile: $e');
    }
  }

  // Get the most recent profile
  Future<Profiling?> getProfile() async {
    try {
      return await profilingRepo.getLatest();  // Retrieve the current profile from DB
    } catch (e) {
      throw Exception('Failed to retrieve profile: $e');
    }
  }

  // Get the profile that was active at the given timestamp
  Future<Profiling?> getProfileAtTimestamp(DateTime timestamp) async {
    try {
      // Fetch the most recent profile before or at the timestamp from history
      return await profilingRepo.getProfileAtTimestamp(timestamp);
    } catch (e) {
      throw Exception('Failed to retrieve profile at timestamp $timestamp: $e');
    }
  }

  // Send the profile data to the backend
  Future<void> sendProfileToBackend(Profiling profiling) async {
    final url = Uri.parse('https://your-backend-api.com/profile');  // Example endpoint
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode(profiling.toUserProfile());

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        print('Profile saved to backend successfully');
      } else {
        throw Exception('Failed to send profile to backend: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error sending profile to backend: $e');
    }
  }
}