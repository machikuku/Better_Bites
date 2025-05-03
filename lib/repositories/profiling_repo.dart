import 'package:sqflite/sqflite.dart';
import 'package:betterbitees/helpers/db.dart';
import 'package:betterbitees/models/profiling.dart';

class ProfilingRepo {
  // Fetch the database instance
  Future<Database> _getDb() async {
    return await DBHelper.open();
  }

  // Upsert (save or update) the profile
  Future<void> upsert(Profiling profile) async {
    final db = await _getDb();
    final profileJson = profile.toJson();

    // Ensure created_at is set for the profiling table
    profileJson['created_at'] = profile.createdAt ?? DateTime.now().toIso8601String();

    // If no id or id is -1, let SQLite auto-generate the id
    if (profile.id == null || profile.id == -1) {
      profileJson.remove('id'); // Let SQLite auto-generate the id
      final id = await db.insert('profiling', profileJson, conflictAlgorithm: ConflictAlgorithm.replace);
      profileJson['id'] = id; // After insert, update the id in the profile
    } else {
      await db.update(
        'profiling',
        profileJson,
        where: 'id = ?',
        whereArgs: [profile.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Save to profile_history table
    await db.insert('profile_history', {
      'age': profile.age,
      'sex': profile.sex,
      'height': profile.height,
      'weight': profile.weight,
      'health_conditions': profile.healthConditions.join(','),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Retrieve the most recent profile
  Future<Profiling?> getLatest() async {
    final db = await _getDb();
    final List<Map<String, dynamic>> maps = await db.query('profiling', limit: 1);
    if (maps.isEmpty) return null;
    return Profiling.fromJson(maps.first);
  }

  // Retrieve profile at a specific timestamp from profile_history
  Future<Profiling?> getProfileAtTimestamp(DateTime timestamp) async {
    final db = await _getDb();
    final historyMaps = await db.query(
      'profile_history',
      where: 'created_at <= ?',
      whereArgs: [timestamp.toIso8601String()],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (historyMaps.isNotEmpty) {
      final historyData = historyMaps.first;
      final healthConditionsString = historyData['health_conditions'] as String?;
      return Profiling(
        id: null, // profile_history doesn't store an id
        age: historyData['age'] as int? ?? 0,
        sex: historyData['sex'] as String? ?? '',
        height: double.tryParse(historyData['height']?.toString() ?? '0.0') ?? 0.0,
        weight: double.tryParse(historyData['weight']?.toString() ?? '0.0') ?? 0.0,
        healthConditions: healthConditionsString != null ? healthConditionsString.split(',').map((e) => e.trim()).toList() : [],
        createdAt: historyData['created_at'] as String? ?? DateTime.now().toIso8601String(),
      );
    }
    return null;
  }
}