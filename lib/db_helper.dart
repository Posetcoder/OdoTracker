import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Car {
  final int? id;
  final String name;
  final String rego;

  Car({this.id, required this.name, required this.rego});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rego': rego,
    };
  }
}

class Trip {
  final int? id;
  final int carId;
  final String date;
  final int odoStart;
  final int odoEnd;
  final int km;
  final String purpose;
  final String category;

  Trip({this.id, required this.carId, required this.date, required this.odoStart, required this.odoEnd, required this.km, required this.purpose, required this.category});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'carId': carId,
      'date': date,
      'odoStart': odoStart,
      'odoEnd': odoEnd,
      'km': km,
      'purpose': purpose,
      'category': category,
    };
  }
}

class DatabaseHelper {
  Future<int> updateTrip(Trip trip) async {
    final db = await instance.database;
    return await db.update(
      'trips',
      trip.toMap(),
      where: 'id = ?',
      whereArgs: [trip.id],
    );
  }
  Future<int> deleteTrip(int id) async {
    final db = await instance.database;
    return await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('odotracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        rego TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carId INTEGER,
        date TEXT,
        odoStart INTEGER,
        odoEnd INTEGER,
        km INTEGER,
        purpose TEXT,
        category TEXT,
        FOREIGN KEY(carId) REFERENCES cars(id)
      )
    ''');
  }

  Future<int> insertCar(Car car) async {
    final db = await instance.database;
    return await db.insert('cars', car.toMap());
  }

  Future<List<Car>> getCars() async {
    final db = await instance.database;
    final result = await db.query('cars');
    return result.map((json) => Car(
      id: json['id'] as int?,
      name: json['name'] as String,
      rego: json['rego'] as String,
    )).toList();
  }

  Future<int> insertTrip(Trip trip) async {
    final db = await instance.database;
    return await db.insert('trips', trip.toMap());
  }

  Future<List<Trip>> getTrips({int? carId}) async {
    final db = await instance.database;
    final result = carId != null
        ? await db.query('trips', where: 'carId = ?', whereArgs: [carId])
        : await db.query('trips');
    return result.map((json) => Trip(
      id: json['id'] as int?,
      carId: json['carId'] as int,
      date: json['date'] as String,
      odoStart: json['odoStart'] as int,
      odoEnd: json['odoEnd'] as int,
      km: json['km'] as int,
      purpose: json['purpose'] as String,
      category: json['category'] as String,
    )).toList();
  }
}
