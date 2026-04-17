---
name: database-migration
description: Update SQLite database schema when adding new tables. Covers version increment, migration in database_service.dart, and the CREATE TABLE IF NOT EXISTS rule.
---

# Database Migration

Update database schema when adding new tables.

## Steps

1. **Update version** in `lib/services/database_service.dart`:
   ```dart
   static const int _databaseVersion = 9;  // increment by 1
   ```

2. **Add migration** in `_upgradeDatabase()` method at the end:
   ```dart
   if (oldVersion < 9) {
     await db.execute('''
       CREATE TABLE IF NOT EXISTS new_table (
         id TEXT PRIMARY KEY,
         -- your columns
         created_at INTEGER NOT NULL
       )
     ''');
   }
   ```

## Key Rule

- Always use `CREATE TABLE IF NOT EXISTS` - works for both fresh install and upgrades
- Never modify `onCreate()` for new tables