import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive with robust crash protection
  try {
    await Hive.initFlutter();
  } catch (e) {
    debugPrint('Hive initialization failed: $e');
  }

  // Helper to open Hive boxes safely and re-create them if corrupted
  Future<Box?> safeOpenBox(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (e) {
      debugPrint('Error opening Hive box "$name": $e. Attempting to repair/recreate box.');
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox(name);
      } catch (innerErr) {
        debugPrint('Failed to recreate Hive box "$name": $innerErr');
        return null;
      }
    }
  }

  // Open required cache boxes
  await safeOpenBox('customers_box');
  await safeOpenBox('orders_box');
  await safeOpenBox('measurements_box');
  await safeOpenBox('offline_queue_box');
  await safeOpenBox('settings_box');
  await safeOpenBox('license_box');

  // Initialize Supabase safely
  try {
    await Supabase.initialize(
      url: 'https://ztxrkijwfnegvquoblne.supabase.co',
      publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0eHJraWp3Zm5lZ3ZxdW9ibG5lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExNjU4NjcsImV4cCI6MjA5Njc0MTg2N30.wN5GHerEc4XHUmRlUvq-g-X4TpJoBDFD7Ov-Q51Zql0',
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: DarziProApp(),
    ),
  );
}


