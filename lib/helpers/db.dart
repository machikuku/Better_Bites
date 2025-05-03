  // ignore_for_file: avoid_print

  import 'dart:async';
  import 'package:flutter/widgets.dart';
  import 'package:path/path.dart';
  import 'package:sqflite/sqflite.dart';

  class DBHelper {
    static Future<Database> open() async {
      WidgetsFlutterBinding.ensureInitialized();

      return openDatabase(
        join(await getDatabasesPath(), 'food_analysis.db'),
        onCreate: (db, version) async {
          Batch batch = db.batch();

          batch.execute(''' 
            CREATE TABLE profiling (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              age INTEGER,
              sex TEXT,
              height TEXT,  -- Store height as a string (e.g., "175cm")
              weight TEXT,  -- Store weight as a string (e.g., "70kg")
              health_conditions TEXT,  -- List stored as a string (e.g., "None")
              bmi TEXT,  -- Store BMI value
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          batch.execute(''' 
            CREATE TABLE profile_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              age INTEGER,
              sex TEXT,
              height TEXT,  -- Store height as a string
              weight TEXT,  -- Store weight as a string
              health_conditions TEXT,  -- List stored as a string
              bmi TEXT,  -- Store BMI value
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          batch.execute(''' 
            CREATE TABLE food_analysis (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,  -- Title of the analysis
              image_path TEXT,  -- Image path (if applicable)
              recognized_text TEXT,  -- Recognized text (if applicable)
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          batch.execute(''' 
            CREATE TABLE ingredients_analysis (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              food_analysis_id INTEGER,
              name TEXT,
              impact TEXT,  -- Impact of the ingredient based on user profile
              consumption_guidance TEXT,  -- Suggested consumption guidance
              alternatives TEXT,  -- Optional substitutes
              source TEXT,  -- Trusted health source URL
              FOREIGN KEY (food_analysis_id) REFERENCES food_analysis(id) ON DELETE CASCADE,
              UNIQUE (food_analysis_id, name)
            )
          ''');

          batch.execute(''' 
            CREATE TABLE allergens (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              food_analysis_id INTEGER,
              name TEXT,  -- Name of the allergen
              description TEXT,  -- Description of why it's an allergen
              impact TEXT,  -- Health impact of the allergen
              potential_reaction TEXT,  -- Expected symptoms or reactions
              source TEXT,  -- Trusted health source URL
              FOREIGN KEY (food_analysis_id) REFERENCES food_analysis(id) ON DELETE CASCADE,
              UNIQUE (food_analysis_id, name)
            )
          ''');

          batch.execute(''' 
            CREATE TABLE health_tips (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              food_analysis_id INTEGER,
              name TEXT,  -- Name of the health tip
              description TEXT,  -- Explanation of why it matters
              suggestion TEXT,  -- Actionable advice for the user
              source TEXT,  -- Trusted health source URL
              FOREIGN KEY (food_analysis_id) REFERENCES food_analysis(id) ON DELETE CASCADE,
              UNIQUE (food_analysis_id, name)
            )
          ''');

          // Creating triggers to limit the number of records
          batch.execute(''' 
            CREATE TRIGGER limit_food_analysis
            AFTER INSERT ON food_analysis
            WHEN (SELECT COUNT(*) FROM food_analysis) > 20
            BEGIN
              DELETE FROM food_analysis
              WHERE id = (SELECT id FROM food_analysis ORDER BY created_at ASC LIMIT 1);
            END;
          ''');

          batch.execute(''' 
            CREATE TRIGGER limit_profile_history
            AFTER INSERT ON profile_history
            WHEN (SELECT COUNT(*) FROM profile_history) > 20
            BEGIN
              DELETE FROM profile_history
              WHERE id = (SELECT id FROM profile_history ORDER BY created_at ASC LIMIT 1);
            END;
          ''');

          await batch.commit();
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < newVersion) {
            Batch batch = db.batch();

            if (oldVersion < 2) {
              batch.execute(''' 
                CREATE TABLE IF NOT EXISTS allergens (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  food_analysis_id INTEGER,
                  name TEXT,
                  description TEXT,
                  potential_reaction TEXT,
                  source TEXT,
                  FOREIGN KEY (food_analysis_id) REFERENCES food_analysis(id) ON DELETE CASCADE,
                  UNIQUE (food_analysis_id, name)
                )
              ''');

              batch.execute(''' 
                CREATE TABLE IF NOT EXISTS health_tips (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  food_analysis_id INTEGER,
                  name TEXT,
                  description TEXT,
                  suggestion TEXT,
                  source TEXT,
                  FOREIGN KEY (food_analysis_id) REFERENCES food_analysis(id) ON DELETE CASCADE,
                  UNIQUE (food_analysis_id, name)
                )
              ''');
            }

            // Add migration for version 6 to add impact field to allergens table
            if (oldVersion < 6) {
              // Check if impact column exists in allergens table
              var columns = await db.rawQuery('PRAGMA table_info(allergens)');
              bool hasImpactColumn = columns.any((column) => column['name'] == 'impact');

              if (!hasImpactColumn) {
                debugPrint('Adding impact column to allergens table');
                batch.execute('ALTER TABLE allergens ADD COLUMN impact TEXT');
              }

              // Check if source columns exist in all tables and add them if they don't
              var ingredientColumns = await db.rawQuery('PRAGMA table_info(ingredients_analysis)');
              bool hasIngredientSourceColumn = ingredientColumns.any((column) => column['name'] == 'source');

              if (!hasIngredientSourceColumn) {
                debugPrint('Adding source column to ingredients_analysis table');
                batch.execute('ALTER TABLE ingredients_analysis ADD COLUMN source TEXT');
              }

              var allergenColumns = await db.rawQuery('PRAGMA table_info(allergens)');
              bool hasAllergenSourceColumn = allergenColumns.any((column) => column['name'] == 'source');

              if (!hasAllergenSourceColumn) {
                debugPrint('Adding source column to allergens table');
                batch.execute('ALTER TABLE allergens ADD COLUMN source TEXT');
              }

              var healthTipColumns = await db.rawQuery('PRAGMA table_info(health_tips)');
              bool hasHealthTipSourceColumn = healthTipColumns.any((column) => column['name'] == 'source');

              if (!hasHealthTipSourceColumn) {
                debugPrint('Adding source column to health_tips table');
                batch.execute('ALTER TABLE health_tips ADD COLUMN source TEXT');
              }
            }

            await batch.commit();
          }
        },
        version: 6, // Increment version to trigger migration
      );
    }
  }
