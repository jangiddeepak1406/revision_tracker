import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DBHelper {
  // Centralized database getter with error handling
  static Future<Database> database() async {
    try {
      return await openDatabase(
        join(await getDatabasesPath(), 'revision_database.db'),
        onCreate: (db, version) async {
          // Define all tables exactly once to prevent mismatches
          await db.execute(
            'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, date TEXT, step INTEGER, subject TEXT, panel TEXT)',
          );
          await db.execute(
            'CREATE TABLE revision_history(id INTEGER PRIMARY KEY AUTOINCREMENT, task_id INTEGER, revision_date TEXT, target_date TEXT)',
          );
          await db.execute(
            'CREATE TABLE subjects(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)',
          );
          await db.execute(
            'CREATE TABLE panels(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)',
          );
        },
        version: 2,
      );
    } catch (e) {
      _handleCriticalError("Database initialization failed: $e");
      rethrow;
    }
  }

  // Private helper to exit app on critical failure
  static void _handleCriticalError(String error) {
    debugPrint(error);
    // Exit app immediately to prevent "Not Responding" dialogs
    SystemNavigator.pop();
  }

  // Wrapped operations to handle potential exceptions
  static Future<void> insertPanel(String name) async {
    try {
      final db = await database();
      await db.insert('panels', {'name': name}, 
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      _handleCriticalError("Failed to insert panel: $e");
    }
  }

  static Future<List<String>> getPanels() async {
    try {
      final db = await database();
      final List<Map<String, dynamic>> maps = await db.query('panels');
      return maps.map((m) => m['name'] as String).toList();
    } catch (e) {
      _handleCriticalError("Failed to fetch panels: $e");
      return [];
    }
  }

  static Future<void> insertSubject(String name) async {
    try {
      final db = await database();
      await db.insert('subjects', {'name': name}, 
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (e) {
      _handleCriticalError("Failed to insert subject: $e");
    }
  }

  static Future<List<String>> getSubjects() async {
    try {
      final db = await database();
      final List<Map<String, dynamic>> maps = await db.query('subjects');
      return List.generate(maps.length, (i) => maps[i]['name'] as String);
    } catch (e) {
      _handleCriticalError("Failed to fetch subjects: $e");
      return [];
    }
  }

  static Future<void> insertTask(String name, String date, int step, String subject, String panel) async {
    try {
      final db = await database();
      await db.insert(
        'tasks',
        {
          'name': name,
          'date': date,
          'step': step,
          'subject': subject,
          'panel': panel
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      _handleCriticalError("Failed to save task: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final db = await database();
      return await db.query('tasks');
    } catch (e) {
      _handleCriticalError("Failed to fetch tasks: $e");
      return [];
    }
  }

  static Future<void> updateTaskStep(int id, int newStep, String targetDate) async {
    try {
      final db = await database();
      await db.transaction((txn) async {
        await txn.update('tasks', {'step': newStep}, where: 'id = ?', whereArgs: [id]);
        await txn.insert('revision_history', {
          'task_id': id,
          'revision_date': DateTime.now().toIso8601String(),
          'target_date': targetDate,
        });
      });
    } catch (e) {
      _handleCriticalError("Failed to update revision step: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getRevisionHistory(int taskId) async {
    try {
      final db = await database();
      return await db.query('revision_history',
          where: 'task_id = ?',
          whereArgs: [taskId],
          orderBy: 'revision_date DESC');
    } catch (e) {
      _handleCriticalError("Failed to fetch history: $e");
      return [];
    }
  }

  static Future<void> deleteTask(int id) async {
    try {
      final db = await database();
      await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      _handleCriticalError("Failed to delete task: $e");
    }
  }
}