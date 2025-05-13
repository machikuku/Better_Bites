import 'package:sqflite/sqflite.dart';
import 'package:betterbitees/helpers/db.dart';
import 'package:betterbitees/models/profiling.dart';

class ProfilingRepo {
  /// Fetches the database instance.
  /// This function ensures that the SQLite database is opened and ready for operations.
  Future<Database> _getDb() async {
    return await DBHelper.open();
  }

  /// Saves or updates a user profile in the database.
  /// - If the profile doesn't have an ID, it inserts a new record into the `profiling` table.
  /// - If the profile has an ID, it updates the existing record.
  /// - Additionally, it saves a copy of the profile to the `profile_history` table for historical tracking.
  Future<void> upsert(Profiling profile) async {
    final db = await _getDb();
    final profileJson = profile.toJson();

    // Ensure `created_at` is set for the profiling table
    profileJson['created_at'] =
        profile.createdAt ?? DateTime.now().toIso8601String();

    // Insert a new profile if no ID is provided or ID is -1
    if (profile.id == null || profile.id == -1) {
      profileJson.remove('id'); // Let SQLite auto-generate the ID
      final id = await db.insert(
        'profiling',
        profileJson,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      profileJson['id'] = id; // Update the profile with the generated ID
    } else {
      // Update the existing profile if an ID is provided
      await db.update(
        'profiling',
        profileJson,
        where: 'id = ?',
        whereArgs: [profile.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Save the profile to the `profile_history` table
    await db.insert('profile_history', {
      'age': profile.age,
      'sex': profile.sex,
      'height': profile.height,
      'weight': profile.weight,
      'health_conditions': profile.healthConditions
          .join(','), // Store health conditions as a comma-separated string
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Retrieves the most recent user profile from the `profiling` table.
  /// - Returns the latest profile as a `Profiling` object.
  /// - If no profile exists, it returns `null`.
  Future<Profiling?> getLatest() async {
    final db = await _getDb();
    final List<Map<String, dynamic>> maps =
        await db.query('profiling', limit: 1);
    if (maps.isEmpty) return null; // Return null if no profile is found
    return Profiling.fromJson(
        maps.first); // Convert the database record to a `Profiling` object
  }

  /// Retrieves a user profile from the `profile_history` table based on a specific timestamp.
  /// - Finds the most recent profile created before or at the given timestamp.
  /// - Returns the profile as a `Profiling` object or `null` if no matching profile is found.
  Future<Profiling?> getProfileAtTimestamp(DateTime timestamp) async {
    final db = await _getDb();
    final historyMaps = await db.query(
      'profile_history',
      where:
          'created_at <= ?', // Filter profiles created before or at the timestamp
      whereArgs: [timestamp.toIso8601String()],
      orderBy: 'created_at DESC', // Order by creation date in descending order
      limit: 1, // Limit to the most recent profile
    );

    if (historyMaps.isNotEmpty) {
      final historyData = historyMaps.first;
      final healthConditionsString =
          historyData['health_conditions'] as String?;

      // Convert the database record to a `Profiling` object
      return Profiling(
        id: null, // `profile_history` doesn't store an ID
        age: historyData['age'] as int? ?? 0,
        sex: historyData['sex'] as String? ?? '',
        height:
            double.tryParse(historyData['height']?.toString() ?? '0.0') ?? 0.0,
        weight:
            double.tryParse(historyData['weight']?.toString() ?? '0.0') ?? 0.0,
        healthConditions: healthConditionsString != null
            ? healthConditionsString.split(',').map((e) => e.trim()).toList()
            : [],
        createdAt: historyData['created_at'] as String? ??
            DateTime.now().toIso8601String(),
      );
    }
    return null; // Return null if no matching profile is found
  }
}
