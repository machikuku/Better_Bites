import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A helper class to manage the SQLite database for the application.
class DBHelper {
  /// Opens the database connection and initializes the database schema.
  ///
  /// - Ensures Flutter bindings are initialized.
  /// - Creates the database if it doesn't exist.
  /// - Defines the schema for various tables and triggers.
  /// - Handles database upgrades when the version changes.
  static Future<Database> open() async {
    WidgetsFlutterBinding.ensureInitialized();

    return openDatabase(
      // Specifies the database file path and name.
      join(await getDatabasesPath(), 'food_analysis.db'),

      // Callback to create the database schema when the database is first created.
      onCreate: (db, version) async {
        Batch batch = db.batch();

        // Creates the `profiling` table to store user profile information.
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

        // Creates the `profile_history` table to store historical user profiles.
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

        // Creates the `food_analysis` table to store food analysis data.
        batch.execute('''
          CREATE TABLE food_analysis (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,  -- Title of the analysis
            image_path TEXT,  -- Image path (if applicable)
            recognized_text TEXT,  -- Recognized text (if applicable)
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Creates the `ingredients_analysis` table to store ingredient analysis data.
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

        // Creates the `allergens` table to store allergen information.
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

        // Creates the `health_tips` table to store health tips related to food analysis.
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

        // Creates a trigger to limit the number of records in the `food_analysis` table to 20.
        batch.execute('''
          CREATE TRIGGER limit_food_analysis
          AFTER INSERT ON food_analysis
          WHEN (SELECT COUNT(*) FROM food_analysis) > 20
          BEGIN
            DELETE FROM food_analysis
            WHERE id = (SELECT id FROM food_analysis ORDER BY created_at ASC LIMIT 1);
          END;
        ''');

        // Creates a trigger to limit the number of records in the `profile_history` table to 20.
        batch.execute('''
          CREATE TRIGGER limit_profile_history
          AFTER INSERT ON profile_history
          WHEN (SELECT COUNT(*) FROM profile_history) > 20
          BEGIN
            DELETE FROM profile_history
            WHERE id = (SELECT id FROM profile_history ORDER BY created_at ASC LIMIT 1);
          END;
        ''');

        // Commits all the batched SQL commands.
        await batch.commit();
      },

      // Callback to handle database upgrades when the version changes.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < newVersion) {
          Batch batch = db.batch();

          // Adds new tables or columns for specific version upgrades.
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

          // Adds the `impact` column to the `allergens` table in version 6.
          if (oldVersion < 6) {
            // Checks if the `impact` column exists in the `allergens` table.
            var columns = await db.rawQuery('PRAGMA table_info(allergens)');
            bool hasImpactColumn =
                columns.any((column) => column['name'] == 'impact');

            if (!hasImpactColumn) {
              debugPrint('Adding impact column to allergens table');
              batch.execute('ALTER TABLE allergens ADD COLUMN impact TEXT');
            }

            // Ensures the `source` column exists in all relevant tables.
            var ingredientColumns =
                await db.rawQuery('PRAGMA table_info(ingredients_analysis)');
            bool hasIngredientSourceColumn =
                ingredientColumns.any((column) => column['name'] == 'source');

            if (!hasIngredientSourceColumn) {
              debugPrint('Adding source column to ingredients_analysis table');
              batch.execute(
                  'ALTER TABLE ingredients_analysis ADD COLUMN source TEXT');
            }

            var allergenColumns =
                await db.rawQuery('PRAGMA table_info(allergens)');
            bool hasAllergenSourceColumn =
                allergenColumns.any((column) => column['name'] == 'source');

            if (!hasAllergenSourceColumn) {
              debugPrint('Adding source column to allergens table');
              batch.execute('ALTER TABLE allergens ADD COLUMN source TEXT');
            }

            var healthTipColumns =
                await db.rawQuery('PRAGMA table_info(health_tips)');
            bool hasHealthTipSourceColumn =
                healthTipColumns.any((column) => column['name'] == 'source');

            if (!hasHealthTipSourceColumn) {
              debugPrint('Adding source column to health_tips table');
              batch.execute('ALTER TABLE health_tips ADD COLUMN source TEXT');
            }
          }

          // Commits all the batched SQL commands for the upgrade.
          await batch.commit();
        }
      },

      // Specifies the current version of the database schema.
      version: 6,
    );
  }
}
