  import 'package:flutter/widgets.dart';
  import 'package:betterbitees/helpers/db.dart';
  import 'package:betterbitees/models/food_analysis.dart';
  import 'package:sqflite/sqflite.dart';
  import 'package:sqflite/sqlite_api.dart';

  class FoodAnalysisRepo {
    Future<List<FoodAnalysis>> getAll() async {
      final db = await DBHelper.open();
      final foods = await db.query('food_analysis', orderBy: 'created_at DESC', distinct: true);

      final foodList = await Future.wait(
        foods.map((food) async {
          final foodId = int.parse(food['id'].toString());
          final ingredientsAnalysis = await _getIngredientsAnalysis(foodId);
          final allergens = await _getAllergens(foodId);
          final healthTips = await _getHealthTips(foodId);

          debugPrint('Food ID: $foodId, Ingredients Analysis: ${ingredientsAnalysis.length}');
          return FoodAnalysis.fromJson({
            ...food,
            'ingredients_analysis': ingredientsAnalysis,
            'allergens': allergens,
            'health_tips': healthTips,
          });
        }),
      );

      debugPrint('Retrieved ${foodList.length} unique food analyses');
      return foodList;
    }

    Future<FoodAnalysis> getFoodAnalysis(int foodId) async {
      final db = await DBHelper.open();
      final food = await db.query(
        'food_analysis',
        where: 'id = ?',
        whereArgs: [foodId],
      );

      if (food.isEmpty) {
        throw Exception('Food not found');
      }

      final ingredientsAnalysis = await _getIngredientsAnalysis(foodId);
      final allergens = await _getAllergens(foodId);
      final healthTips = await _getHealthTips(foodId);

      return FoodAnalysis.fromJson({
        'id': food.first['id'],
        'title': food.first['title'],
        'image_path': food.first['image_path'],
        'recognized_text': food.first['recognized_text'],
        'created_at': food.first['created_at'],
        'ingredients_analysis': ingredientsAnalysis,
        'allergens': allergens,
        'health_tips': healthTips,
      });
    }

    Future<List<Map<String, dynamic>>> _getIngredientsAnalysis(int foodId) async {
      final db = await DBHelper.open();
      final results = await db.query(
        'ingredients_analysis',
        where: 'food_analysis_id = ?',
        whereArgs: [foodId],
        distinct: true,
      );

      // Map database column names to model field names
      return results.map((item) => {
        'name': item['name'],
        'impact': item['impact'],
        'consumption_guidance': item['consumption_guidance'],
        'alternatives': item['alternatives'],
        'source': item['source'], // Added source field
      }).toList();
    }

    Future<List<Map<String, dynamic>>> _getAllergens(int foodId) async {
      final db = await DBHelper.open();
      final results = await db.query(
        'allergens',
        where: 'food_analysis_id = ?',
        whereArgs: [foodId],
        distinct: true,
      );

      // Map database column names to model field names
      return results.map((item) => {
        'name': item['name'],
        'description': item['description'],
        'impact': item['impact'],
        'potential_reaction': item['potential_reaction'],
        'source': item['source'], // Added source field
      }).toList();
    }

    Future<List<Map<String, dynamic>>> _getHealthTips(int foodId) async {
      final db = await DBHelper.open();
      final results = await db.query(
        'health_tips',
        where: 'food_analysis_id = ?',
        whereArgs: [foodId],
        distinct: true,
      );

      // Map database column names to model field names
      return results.map((item) => {
        'name': item['name'],
        'description': item['description'],
        'suggestion': item['suggestion'],
        'source': item['source'], // Added source field
      }).toList();
    }

    Future<int> create(FoodAnalysis food) async {
      final db = await DBHelper.open();
      Batch batch = db.batch();

      debugPrint('Creating food analysis with timestamp: ${food.createdAt.toIso8601String()}');

      final foodAnalysisId = await db.insert(
        'food_analysis',
        {
          'title': food.title,
          'image_path': food.imagePath,
          'recognized_text': food.recognizedText,
          'created_at': food.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Insert ingredients with source field
      for (final item in food.ingredientsAnalysis) {
        batch.insert('ingredients_analysis', {
          'food_analysis_id': foodAnalysisId,
          'name': item.name,
          'impact': item.impact,
          'consumption_guidance': item.consumptionGuidance,
          'alternatives': item.alternatives,
          'source': item.source, // Added source field
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // Insert allergens with source field
      for (final item in food.allergens) {
        batch.insert('allergens', {
          'food_analysis_id': foodAnalysisId,
          'name': item.name,
          'description': item.description,
          'impact': item.impact,
          'potential_reaction': item.potentialReaction,
          'source': item.source, // Added source field
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // Insert health tips with source field
      for (final item in food.healthTips) {
        batch.insert('health_tips', {
          'food_analysis_id': foodAnalysisId,
          'name': item.name,
          'description': item.description,
          'suggestion': item.suggestion,
          'source': item.source, // Added source field
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      final batchResults = await batch.commit();
      debugPrint('Batch insert results: $batchResults');

      return foodAnalysisId;
    }
  }
