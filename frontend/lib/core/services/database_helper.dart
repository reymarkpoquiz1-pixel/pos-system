import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Local Products Cache
    await db.execute('''
      CREATE TABLE local_products (
        id INTEGER PRIMARY KEY,
        category_id INTEGER,
        barcode TEXT,
        name TEXT,
        selling_price REAL,
        stock_quantity INTEGER,
        reorder_level INTEGER,
        image_url TEXT,
        variants TEXT
      )
    ''');

    // 2. Offline Sales
    await db.execute('''
      CREATE TABLE offline_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total_amount REAL,
        discount REAL,
        amount_paid REAL,
        change REAL,
        payment_method TEXT,
        customer_id INTEGER,
        created_at TEXT,
        sync_status INTEGER DEFAULT 0 -- 0: Pending, 1: Synced
      )
    ''');

    // 3. Offline Sale Items
    await db.execute('''
      CREATE TABLE offline_sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        unit_price REAL,
        FOREIGN KEY (sale_id) REFERENCES offline_sales (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- PRODUCT OPERATIONS ---
  Future<void> cacheProducts(List<dynamic> products) async {
    final db = await instance.database;
    await db.delete('local_products'); // Clear old cache
    for (var p in products) {
      await db.insert('local_products', {
        'id': p['id'],
        'category_id': p['category_id'],
        'barcode': p['barcode'],
        'name': p['name'],
        'selling_price': double.tryParse(p['selling_price'].toString()) ?? 0.0,
        'stock_quantity': int.tryParse(p['stock_quantity'].toString()) ?? 0,
        'reorder_level': int.tryParse(p['reorder_level'].toString()) ?? 0,
        'image_url': p['image_url'],
        'variants': p['variants'] is String ? p['variants'] : jsonEncode(p['variants']),
      });
    }
  }

  Future<List<Map<String, dynamic>>> getLocalProducts() async {
    final db = await instance.database;
    return await db.query('local_products');
  }

  // --- SALE OPERATIONS ---
  Future<int> saveOfflineSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      int id = await txn.insert('offline_sales', {
        'total_amount': sale['total_amount'],
        'discount': sale['discount'],
        'amount_paid': sale['amount_paid'],
        'change': sale['change'],
        'payment_method': sale['payment_method'],
        'customer_id': sale['customer_id'],
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var item in items) {
        await txn.insert('offline_sale_items', {
          'sale_id': id,
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
        });
      }
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSales() async {
    final db = await instance.database;
    final sales = await db.query('offline_sales', where: 'sync_status = 0');
    
    List<Map<String, dynamic>> fullSales = [];
    for (var s in sales) {
      final items = await db.query('offline_sale_items', where: 'sale_id = ?', whereArgs: [s['id']]);
      var saleMap = Map<String, dynamic>.from(s);
      saleMap['items'] = items;
      fullSales.add(saleMap);
    }
    return fullSales;
  }

  Future<void> markAsSynced(int id) async {
    final db = await instance.database;
    await db.update('offline_sales', {'sync_status': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSyncedSales() async {
    final db = await instance.database;
    await db.delete('offline_sales', where: 'sync_status = 1');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
