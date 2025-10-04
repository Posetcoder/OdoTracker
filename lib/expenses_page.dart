import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class Expense {
  final int? id;
  final int carId;
  final String type;
  final double amount;
  final String? imagePath;
  final String date;

  Expense({this.id, required this.carId, required this.type, required this.amount, this.imagePath, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'carId': carId,
      'type': type,
      'amount': amount,
      'imagePath': imagePath,
      'date': date,
    };
  }
}

class ExpenseDbHelper {
  Future<int> deleteExpense(int id) async {
    await createTable();
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  static final ExpenseDbHelper instance = ExpenseDbHelper._init();
  static Database? _database;

  ExpenseDbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await DatabaseHelper.instance.database;
    return _database!;
  }

  Future<void> createTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carId INTEGER,
        type TEXT,
        amount REAL,
        imagePath TEXT,
        date TEXT,
        FOREIGN KEY(carId) REFERENCES cars(id)
      )
    ''');
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<List<Expense>> getExpenses({int? carId}) async {
    await createTable();
    final db = await database;
    final result = carId != null
        ? await db.query('expenses', where: 'carId = ?', whereArgs: [carId])
        : await db.query('expenses');
    return result.map((json) => Expense(
      id: json['id'] as int?,
      carId: json['carId'] as int,
      type: json['type'] as String,
      amount: json['amount'] as double,
      imagePath: json['imagePath'] as String?,
      date: json['date'] as String,
    )).toList();
  }
}

class ExpensesPage extends StatefulWidget {
  final int carId;
  const ExpensesPage({super.key, required this.carId});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String _type = 'Fuel';
  // ignore: unused_field
  File? _image;
  String? _filePath;
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().substring(0,10);
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    _expenses = await ExpenseDbHelper.instance.getExpenses(carId: widget.carId);
    _expenses.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _getAttachmentDirectory(String type, String date) async {
    final directory = await getApplicationDocumentsDirectory();
    final folderName = '${type}_${date.replaceAll(':', '').replaceAll('-', '').replaceAll('/', '')}';
    final folder = Directory('${directory.path}/attachments/$folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final saveDir = await _getAttachmentDirectory(_type, _dateController.text);
      final fileName = pickedFile.name;
      final savedFile = await File(pickedFile.path).copy('$saveDir/$fileName');
      setState(() {
        _image = savedFile;
        _filePath = savedFile.path;
      });
    }
    // TODO: Add file_picker logic for PDF
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final saveDir = await _getAttachmentDirectory(_type, _dateController.text);
      final fileName = pickedFile.name;
      final savedFile = await File(pickedFile.path).copy('$saveDir/$fileName');
      setState(() {
        _image = savedFile;
        _filePath = savedFile.path;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      Expense expense = Expense(
        carId: widget.carId,
        type: _type,
        amount: double.parse(_amountController.text),
        imagePath: _filePath,
        date: _dateController.text,
      );
      await ExpenseDbHelper.instance.insertExpense(expense);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved!')),
      );
      _amountController.clear();
      _dateController.text = DateTime.now().toIso8601String().substring(0,10);
      setState(() {
        _image = null;
        _filePath = null;
      });
      await _loadExpenses();
    }
  }

  double get _totalForSelectedType {
    return _expenses
        .where((e) => e.type == _type)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEFF5D2), Color(0xFFC6D870)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total & Form Container
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC6D870), Color(0xFF8FA31E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF556B2F),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total for $_type: ${_totalForSelectedType.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF556B2F),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _type,
                                    decoration: const InputDecoration(labelText: 'Expense Type'),
                                    items: const [
                                      DropdownMenuItem(value: 'Fuel', child: Text('Fuel')),
                                      DropdownMenuItem(value: 'Insurance', child: Text('Insurance')),
                                      DropdownMenuItem(value: 'Rego', child: Text('Rego')),
                                      DropdownMenuItem(value: 'Repairs', child: Text('Repairs')),
                                      DropdownMenuItem(value: 'Loan Interest', child: Text('Loan Interest')),
                                      DropdownMenuItem(value: 'Depreciation', child: Text('Depreciation')),
                                      DropdownMenuItem(value: 'Purchase Cost', child: Text('Purchase Cost')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _type = value!;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _amountController,
                                    decoration: const InputDecoration(labelText: 'Amount'),
                                    keyboardType: TextInputType.number,
                                    validator: (value) =>
                                        value == null || value.isEmpty ? 'Enter amount' : null,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _dateController,
                                    decoration: const InputDecoration(labelText: 'Date'),
                                    readOnly: true,
                                    onTap: () async {
                                      DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        _dateController.text = picked.toIso8601String().substring(0,10);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF556B2F),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _takePhoto,
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text('Take Photo'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF8FA31E),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _pickFile,
                                        icon: const Icon(Icons.attach_file),
                                        label: const Text('Gallery/PDF'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC6D870),
                                      foregroundColor: const Color(0xFF556B2F),
                                    ),
                                    onPressed: _saveExpense,
                                    child: const Text('Save Expense'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF556B2F),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _expenses.length,
                      itemBuilder: (context, index) {
                        final expense = _expenses[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF8FA31E),
                              child: const Icon(Icons.receipt_long, color: Color(0xFF556B2F)),
                            ),
                            title: Text('${expense.type}: ${expense.amount.toStringAsFixed(2)}'),
                            subtitle: Text('Date: ${expense.date}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    final amountController = TextEditingController(text: expense.amount.toString());
                                    final dateController = TextEditingController(text: expense.date);
                                    await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Edit Expense'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextFormField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount')),
                                            TextFormField(controller: dateController, decoration: const InputDecoration(labelText: 'Date'), readOnly: true,
                                              onTap: () async {
                                                DateTime? picked = await showDatePicker(
                                                  context: context,
                                                  initialDate: DateTime.now(),
                                                  firstDate: DateTime(2000),
                                                  lastDate: DateTime(2100),
                                                );
                                                if (picked != null) {
                                                  dateController.text = picked.toIso8601String().substring(0,10);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                                          TextButton(
                                            onPressed: () async {
                                              double? newAmount = double.tryParse(amountController.text);
                                              if (newAmount != null) {
                                                Expense updated = Expense(
                                                  id: expense.id,
                                                  carId: expense.carId,
                                                  type: expense.type,
                                                  amount: newAmount,
                                                  imagePath: expense.imagePath,
                                                  date: dateController.text,
                                                );
                                                await ExpenseDbHelper.instance.updateExpense(updated);
                                                await _loadExpenses();
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () async {
                                    await ExpenseDbHelper.instance.deleteExpense(expense.id!);
                                    setState(() {
                                      _expenses.removeWhere((e) => e.id == expense.id);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}