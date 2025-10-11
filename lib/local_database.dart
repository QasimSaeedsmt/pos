// // local_database.dart
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'dart:convert';
//
// import 'app.dart';
//
// class LocalDatabase {
//   static final LocalDatabase _instance = LocalDatabase._internal();
//   factory LocalDatabase() => _instance;
//   LocalDatabase._internal();
//
//   static Database? _database;
//   final String _databaseName = 'pos_database.db';
//   final int _databaseVersion = 3;
//
//   // Table names
//   static const String tableProducts = 'products';
//   static const String tableCart = 'cart';
//   static const String tablePendingOrders = 'pending_orders';
//   static const String tableSyncQueue = 'sync_queue';
//
//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDatabase();
//     return _database!;
//   }
//
//   Future<Database> _initDatabase() async {
//     final String path = join(await getDatabasesPath(), _databaseName);
//     return await openDatabase(
//       path,
//       version: _databaseVersion,
//       onCreate: _createDatabase,
//       onUpgrade: _upgradeDatabase,
//     );
//   }
//
//   Future<void> _createDatabase(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE $tableProducts (
//         id INTEGER PRIMARY KEY,
//         name TEXT NOT NULL,
//         sku TEXT,
//         price REAL NOT NULL,
//         regular_price REAL,
//         sale_price REAL,
//         image_url TEXT,
//         stock_quantity INTEGER DEFAULT 0,
//         in_stock INTEGER DEFAULT 0,
//         stock_status TEXT,
//         description TEXT,
//         short_description TEXT,
//         categories TEXT,
//         attributes TEXT,
//         meta_data TEXT,
//         date_created TEXT,
//         date_modified TEXT,
//         purchasable INTEGER DEFAULT 1,
//         type TEXT,
//         status TEXT,
//         featured INTEGER DEFAULT 0,
//         average_rating REAL,
//         rating_count INTEGER,
//         variations TEXT,
//         weight TEXT,
//         dimensions TEXT,
//         last_synced TEXT,
//         is_dirty INTEGER DEFAULT 0
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE $tableCart (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         product_id INTEGER NOT NULL,
//         quantity INTEGER NOT NULL,
//         added_at TEXT NOT NULL,
//         FOREIGN KEY (product_id) REFERENCES $tableProducts (id)
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE $tablePendingOrders (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         order_data TEXT NOT NULL,
//         created_at TEXT NOT NULL,
//         sync_status TEXT DEFAULT 'pending',
//         sync_attempts INTEGER DEFAULT 0,
//         last_sync_attempt TEXT
//       )
//     ''');
//
//     await db.execute('''
//       CREATE TABLE $tableSyncQueue (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         operation_type TEXT NOT NULL,
//         table_name TEXT NOT NULL,
//         record_id INTEGER,
//         data TEXT NOT NULL,
//         created_at TEXT NOT NULL,
//         sync_status TEXT DEFAULT 'pending',
//         sync_attempts INTEGER DEFAULT 0
//       )
//     ''');
//
//     // Create indexes for better performance
//     await db.execute('CREATE INDEX idx_products_sku ON $tableProducts(sku)');
//     await db.execute('CREATE INDEX idx_products_stock ON $tableProducts(in_stock, stock_quantity)');
//     await db.execute('CREATE INDEX idx_cart_product_id ON $tableCart(product_id)');
//     await db.execute('CREATE INDEX idx_sync_queue_status ON $tableSyncQueue(sync_status)');
//   }
//
//   Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
//     if (oldVersion < 2) {
//       await db.execute('''
//         CREATE TABLE IF NOT EXISTS $tablePendingOrders (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           order_data TEXT NOT NULL,
//           created_at TEXT NOT NULL,
//           sync_status TEXT DEFAULT 'pending',
//           sync_attempts INTEGER DEFAULT 0,
//           last_sync_attempt TEXT
//         )
//       ''');
//     }
//
//     if (oldVersion < 3) {
//       await db.execute('''
//         CREATE TABLE IF NOT EXISTS $tableSyncQueue (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           operation_type TEXT NOT NULL,
//           table_name TEXT NOT NULL,
//           record_id INTEGER,
//           data TEXT NOT NULL,
//           created_at TEXT NOT NULL,
//           sync_status TEXT DEFAULT 'pending',
//           sync_attempts INTEGER DEFAULT 0
//         )
//       ''');
//
//       await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON $tableSyncQueue(sync_status)');
//     }
//   }
//
//   // Product operations
//   Future<void> saveProducts(List<Product> products) async {
//     final db = await database;
//     final batch = db.batch();
//
//     for (final product in products) {
//       batch.insert(
//         tableProducts,
//         _productToMap(product),
//         conflictAlgorithm: ConflictAlgorithm.replace,
//       );
//     }
//
//     await batch.commit();
//   }
//
//   Future<List<Product>> getProducts({
//     int limit = 50,
//     int offset = 0,
//     String searchQuery = '',
//     bool inStockOnly = false,
//     double minPrice = 0,
//     double maxPrice = double.infinity,
//   }) async {
//     final db = await database;
//
//     var whereClause = '1=1';
//     final List<dynamic> whereArgs = [];
//
//     if (searchQuery.isNotEmpty) {
//       whereClause += ' AND (name LIKE ? OR sku LIKE ?)';
//       whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']);
//     }
//
//     if (inStockOnly) {
//       whereClause += ' AND in_stock = 1';
//     }
//
//     if (minPrice > 0) {
//       whereClause += ' AND price >= ?';
//       whereArgs.add(minPrice);
//     }
//
//     if (maxPrice < double.infinity) {
//       whereClause += ' AND price <= ?';
//       whereArgs.add(maxPrice);
//     }
//
//     final List<Map<String, dynamic>> maps = await db.query(
//       tableProducts,
//       where: whereClause,
//       whereArgs: whereArgs,
//       limit: limit,
//       offset: offset,
//       orderBy: 'name ASC',
//     );
//
//     return maps.map((map) => _productFromMap(map)).toList();
//   }
//
//   Future<Product?> getProductById(int id) async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query(
//       tableProducts,
//       where: 'id = ?',
//       whereArgs: [id],
//     );
//
//     if (maps.isNotEmpty) {
//       return _productFromMap(maps.first);
//     }
//     return null;
//   }
//
//   Future<Product?> getProductBySku(String sku) async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query(
//       tableProducts,
//       where: 'sku = ?',
//       whereArgs: [sku],
//     );
//
//     if (maps.isNotEmpty) {
//       return _productFromMap(maps.first);
//     }
//     return null;
//   }
//
//   // Cart operations
//   Future<void> saveCartItem(CartItem item) async {
//     final db = await database;
//     await db.insert(
//       tableCart,
//       {
//         'product_id': item.product.id,
//         'quantity': item.quantity,
//         'added_at': DateTime.now().toIso8601String(),
//       },
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }
//
//   Future<List<CartItem>> getCartItems() async {
//     final db = await database;
//     final List<Map<String, dynamic>> cartMaps = await db.query(
//       tableCart,
//       orderBy: 'added_at DESC',
//     );
//
//     final List<CartItem> cartItems = [];
//
//     for (final cartMap in cartMaps) {
//       final product = await getProductById(cartMap['product_id']);
//       if (product != null) {
//         cartItems.add(CartItem(
//           product: product,
//           quantity: cartMap['quantity'],
//         ));
//       }
//     }
//
//     return cartItems;
//   }
//
//   Future<void> updateCartItemQuantity(int productId, int quantity) async {
//     final db = await database;
//     if (quantity <= 0) {
//       await db.delete(
//         tableCart,
//         where: 'product_id = ?',
//         whereArgs: [productId],
//       );
//     } else {
//       await db.update(
//         tableCart,
//         {'quantity': quantity},
//         where: 'product_id = ?',
//         whereArgs: [productId],
//       );
//     }
//   }
//
//   Future<void> removeCartItem(int productId) async {
//     final db = await database;
//     await db.delete(
//       tableCart,
//       where: 'product_id = ?',
//       whereArgs: [productId],
//     );
//   }
//
//   Future<void> clearCart() async {
//     final db = await database;
//     await db.delete(tableCart);
//   }
//
//   // Pending orders operations
//   Future<int> savePendingOrder(List<CartItem> cartItems) async {
//     final db = await database;
//
//     final orderData = {
//       'line_items': cartItems.map((item) {
//         return {
//           'product_id': item.product.id,
//           'quantity': item.quantity,
//           'price': item.product.price,
//         };
//       }).toList(),
//       'created_at': DateTime.now().toIso8601String(),
//       'total': cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
//     };
//
//     final id = await db.insert(
//       tablePendingOrders,
//       {
//         'order_data': json.encode(orderData),
//         'created_at': DateTime.now().toIso8601String(),
//         'sync_status': 'pending',
//         'sync_attempts': 0,
//       },
//     );
//
//     return id;
//   }
//
//   Future<List<Map<String, dynamic>>> getPendingOrders() async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query(
//       tablePendingOrders,
//       where: 'sync_status = ?',
//       whereArgs: ['pending'],
//       orderBy: 'created_at ASC',
//     );
//
//     return maps.map((map) {
//       return {
//         'id': map['id'],
//         'order_data': json.decode(map['order_data']),
//         'created_at': map['created_at'],
//         'sync_attempts': map['sync_attempts'],
//       };
//     }).toList();
//   }
//
//   Future<void> updatePendingOrderStatus(int orderId, String status, {int attempts = 0}) async {
//     final db = await database;
//     await db.update(
//       tablePendingOrders,
//       {
//         'sync_status': status,
//         'sync_attempts': attempts,
//         'last_sync_attempt': DateTime.now().toIso8601String(),
//       },
//       where: 'id = ?',
//       whereArgs: [orderId],
//     );
//   }
//
//   Future<void> deletePendingOrder(int orderId) async {
//     final db = await database;
//     await db.delete(
//       tablePendingOrders,
//       where: 'id = ?',
//       whereArgs: [orderId],
//     );
//   }
//
//   // Sync queue operations
//   Future<void> addToSyncQueue({
//     required String operationType,
//     required String tableName,
//     required int recordId,
//     required Map<String, dynamic> data,
//   }) async {
//     final db = await database;
//     await db.insert(
//       tableSyncQueue,
//       {
//         'operation_type': operationType,
//         'table_name': tableName,
//         'record_id': recordId,
//         'data': json.encode(data),
//         'created_at': DateTime.now().toIso8601String(),
//         'sync_status': 'pending',
//         'sync_attempts': 0,
//       },
//     );
//   }
//
//   Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
//     final db = await database;
//     final List<Map<String, dynamic>> maps = await db.query(
//       tableSyncQueue,
//       where: 'sync_status = ?',
//       whereArgs: ['pending'],
//       orderBy: 'created_at ASC',
//     );
//
//     return maps.map((map) {
//       return {
//         'id': map['id'],
//         'operation_type': map['operation_type'],
//         'table_name': map['table_name'],
//         'record_id': map['record_id'],
//         'data': json.decode(map['data']),
//         'created_at': map['created_at'],
//         'sync_attempts': map['sync_attempts'],
//       };
//     }).toList();
//   }
//
//   Future<void> updateSyncOperationStatus(int operationId, String status, {int attempts = 0}) async {
//     final db = await database;
//     await db.update(
//       tableSyncQueue,
//       {
//         'sync_status': status,
//         'sync_attempts': attempts,
//       },
//       where: 'id = ?',
//       whereArgs: [operationId],
//     );
//   }
//
//   Future<void> deleteSyncOperation(int operationId) async {
//     final db = await database;
//     await db.delete(
//       tableSyncQueue,
//       where: 'id = ?',
//       whereArgs: [operationId],
//     );
//   }
//
//   // Utility methods
//   Map<String, dynamic> _productToMap(Product product) {
//     return {
//       'id': product.id,
//       'name': product.name,
//       'sku': product.sku,
//       'price': product.price,
//       'regular_price': product.regularPrice,
//       'sale_price': product.salePrice,
//       'image_url': product.imageUrl,
//       'stock_quantity': product.stockQuantity,
//       'in_stock': product.inStock ? 1 : 0,
//       'stock_status': product.stockStatus,
//       'description': product.description,
//       'short_description': product.shortDescription,
//       'categories': json.encode(product.categories.map((c) => c.toJson()).toList()),
//       'attributes': json.encode(product.attributes.map((a) => a.toJson()).toList()),
//       'meta_data': json.encode(product.metaData),
//       'date_created': product.dateCreated?.toIso8601String(),
//       'date_modified': product.dateModified?.toIso8601String(),
//       'purchasable': product.purchasable ? 1 : 0,
//       'type': product.type,
//       'status': product.status,
//       'featured': product.featured ? 1 : 0,
//       'average_rating': product.averageRating,
//       'rating_count': product.ratingCount,
//       'variations': json.encode(product.variations),
//       'weight': product.weight,
//       'dimensions': product.dimensions,
//       'last_synced': DateTime.now().toIso8601String(),
//       'is_dirty': 0,
//     };
//   }
//
//   Product _productFromMap(Map<String, dynamic> map) {
//     return Product(
//       id: map['id'],
//       name: map['name'],
//       sku: map['sku'] ?? '',
//       price: map['price']?.toDouble() ?? 0.0,
//       regularPrice: map['regular_price']?.toDouble(),
//       salePrice: map['sale_price']?.toDouble(),
//       imageUrl: map['image_url'],
//       stockQuantity: map['stock_quantity'] ?? 0,
//       inStock: map['in_stock'] == 1,
//       stockStatus: map['stock_status'] ?? 'instock',
//       description: map['description'],
//       shortDescription: map['short_description'],
//       categories: map['categories'] != null
//           ? (json.decode(map['categories']) as List).map((c) => Category.fromJson(c)).toList()
//           : [],
//       attributes: map['attributes'] != null
//           ? (json.decode(map['attributes']) as List).map((a) => Attribute.fromJson(a)).toList()
//           : [],
//       metaData: map['meta_data'] != null ? json.decode(map['meta_data']) : {},
//       dateCreated: map['date_created'] != null ? DateTime.parse(map['date_created']) : null,
//       dateModified: map['date_modified'] != null ? DateTime.parse(map['date_modified']) : null,
//       purchasable: map['purchasable'] == 1,
//       type: map['type'],
//       status: map['status'],
//       featured: map['featured'] == 1,
//       averageRating: map['average_rating']?.toDouble(),
//       ratingCount: map['rating_count'],
//       variations: map['variations'] != null ? List<int>.from(json.decode(map['variations'])) : [],
//       weight: map['weight'],
//       dimensions: map['dimensions'],
//     );
//   }
//
//   Future<void> close() async {
//     if (_database != null) {
//       await _database!.close();
//       _database = null;
//     }
//   }
// }