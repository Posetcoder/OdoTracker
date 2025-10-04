import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'db_helper.dart';
import 'expenses_page.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';


class _PieDataExpense {
  final String type;
  final double amount;
  _PieDataExpense(this.type, this.amount);
}

class ReportsPage extends StatefulWidget {
  final int carId;
  const ReportsPage({super.key, required this.carId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Trip> trips = [];
  List<Expense> expenses = [];
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int? _odoFilterFrom;
  int? _odoFilterTo;

  // Expense Pie Chart Data Helper
  List<_PieDataExpense> _getExpensePieData() {
    final Map<String, double> typeTotals = {};
    for (final e in _filteredExpenses) {
      typeTotals[e.type] = (typeTotals[e.type] ?? 0) + e.amount;
    }
    return typeTotals.entries.map((e) => _PieDataExpense(e.key, e.value)).toList();
  }
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final loadedTrips = await DatabaseHelper.instance.getTrips(carId: widget.carId);
      // Ensure expenses table exists, then load for this car
      await ExpenseDbHelper.instance.createTable();
      final loadedExpenses = await ExpenseDbHelper.instance.getExpenses(carId: widget.carId);
      if (mounted) {
        setState(() {
          trips = loadedTrips;
          expenses = loadedExpenses;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reports data: $e')),
      );
    }
  }

  List<Expense> get _filteredExpenses {
    List<Expense> currentExpenses = expenses;
    if (_filterStartDate != null && _filterEndDate != null) {
      // Strictly include only expenses within the selected date range (inclusive)
      currentExpenses = expenses.where((e) {
        final expenseDate = DateTime.tryParse(_normalizeDate(e.date));
        return expenseDate != null &&
            !expenseDate.isBefore(_filterStartDate!) &&
            !expenseDate.isAfter(_filterEndDate!);
      }).toList();
    } else if (_odoFilterFrom != null && _odoFilterTo != null) {
      // Show expenses whose date matches trips overlapping with the filter range
      // Normalize both trip and expense dates for consistent comparison
      final validTripDates = trips
          .where((t) => t.odoEnd >= _odoFilterFrom! && t.odoStart <= _odoFilterTo!)
          .map((t) => _normalizeDate(t.date))
          .toSet();
      currentExpenses = expenses
          .where((e) => validTripDates.contains(_normalizeDate(e.date)))
          .toList();
    }
    return currentExpenses;
  }

  List<Trip> get _filteredTrips {
    if (_filterStartDate != null && _filterEndDate != null) {
      // Strictly include only trips within the selected date range (inclusive)
      return trips.where((t) {
        final tripDate = DateTime.tryParse(_normalizeDate(t.date));
        return tripDate != null &&
            !tripDate.isBefore(_filterStartDate!) &&
            !tripDate.isAfter(_filterEndDate!);
      }).toList();
    } else if (_odoFilterFrom != null && _odoFilterTo != null) {
      // Show trips that overlap with the filter range
      return trips
          .where((t) => t.odoEnd >= _odoFilterFrom! && t.odoStart <= _odoFilterTo!)
          .toList();
    }
    return trips;
  }

  String _normalizeDate(String date) {
    // Handles both dd/MM/yyyy and yyyy-MM-dd formats
    if (date.contains('/')) {
      final parts = date.split('/');
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return date.substring(0, 10);
  }

  int get totalKm => _filteredTrips.fold(0, (sum, t) => sum + t.km);
  int get businessKm => _filteredTrips.where((t) => t.category == 'Business').fold(0, (sum, t) => sum + t.km);
  double get businessPercent => totalKm > 0 ? (businessKm / totalKm) * 100 : 0;

  Future<void> _requestPermissionAndExport(Function exportFunction) async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }

    if (status.isGranted) {
      try {
        await exportFunction();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied. Cannot export file.')),
      );
    }
  }

  Future<String> _getDocumentsPath() async {
    if (Platform.isAndroid) {
      // Save to Downloads folder on Android
      return '/storage/emulated/0/Download';
    } else {
      // Fallback for other platforms
      return (await getApplicationDocumentsDirectory()).path;
    }
  }

  Future<void> _exportCSV() async {
    List<List<dynamic>> rows = [
      ['Date', 'Odo Start', 'Odo End', 'KM', 'Purpose', 'Category'],
      ..._filteredTrips.map((t) => [t.date, t.odoStart, t.odoEnd, t.km, t.purpose, t.category]),
    ];
    String csvData = const ListToCsvConverter().convert(rows);
    final documentsPath = await _getDocumentsPath();
    final filePath = '$documentsPath/odotracker_trips_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(filePath);
    await file.writeAsString(csvData);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV exported to: $filePath')),
    );
  }

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('OdoTracker Trip Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Business Use: ${businessPercent.toStringAsFixed(1)}% (${businessKm}km / ${totalKm}km total)'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headers: ['Date', 'Odo Start', 'Odo End', 'KM', 'Purpose', 'Category'],
                data: _filteredTrips.map((t) => [t.date, t.odoStart, t.odoEnd, t.km, t.purpose, t.category]).toList(),
              ),
            ],
          );
        },
      ),
    );
    final documentsPath = await _getDocumentsPath();
    final filePath = '$documentsPath/odotracker_trips_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF exported to: $filePath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFF5D2), Color(0xFFC6D870)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8FA31E),
                      foregroundColor: Color(0xFF556B2F),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF556B2F), width: 1.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                      minimumSize: const Size(0, 38),
                    ),
                    onPressed: () => _requestPermissionAndExport(_exportCSV),
                    icon: const Icon(Icons.file_download, size: 24),
                    label: const Text('Export CSV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF556B2F),
                      foregroundColor: Color(0xFFEFF5D2),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF8FA31E), width: 1.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                      minimumSize: const Size(0, 38),
                    ),
                    onPressed: () => _requestPermissionAndExport(_exportPDF),
                    icon: const Icon(Icons.picture_as_pdf, size: 24),
                    label: const Text('Export PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC6D870), Color(0xFF8FA31E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Color(0xFF556B2F), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.8),
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _filterStartDate = picked.start;
                                    _filterEndDate = picked.end;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_month),
                              label: Text(
                                _filterStartDate != null && _filterEndDate != null
                                    ? 'Date: ${_filterStartDate!.toIso8601String().substring(0,10)} to ${_filterEndDate!.toIso8601String().substring(0,10)}'
                                    : 'Filter by Date Range',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.8),
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                int? odoFrom;
                                int? odoTo;
                                await showDialog(
                                  context: context,
                                  builder: (context) {
                                    final odoFromController = TextEditingController();
                                    final odoToController = TextEditingController();
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      title: const Text('Filter by Odometer'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: odoFromController,
                                            decoration: const InputDecoration(labelText: 'Odometer From'),
                                            keyboardType: TextInputType.number,
                                          ),
                                          TextField(
                                            controller: odoToController,
                                            decoration: const InputDecoration(labelText: 'Odometer To'),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF556B2F),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {
                                            odoFrom = int.tryParse(odoFromController.text);
                                            odoTo = int.tryParse(odoToController.text);
                                            Navigator.pop(context);
                                          },
                                          child: const Text('Apply'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (odoFrom != null && odoTo != null) {
                                  setState(() {
                                    _filterStartDate = null;
                                    _filterEndDate = null;
                                    _odoFilterFrom = odoFrom;
                                    _odoFilterTo = odoTo;
                                  });
                                }
                              },
                              icon: const Icon(Icons.speed),
                              label: Text((_odoFilterFrom != null && _odoFilterTo != null)
                                  ? 'Odo: $_odoFilterFrom to $_odoFilterTo'
                                  : 'Filter by Odometer', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          if (_filterStartDate != null || _odoFilterFrom != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _filterStartDate = null;
                                  _filterEndDate = null;
                                  _odoFilterFrom = null;
                                  _odoFilterTo = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEFF5D2), Color(0xFFC6D870)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Color(0xFF556B2F), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Business Use %: ${businessPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
                          SizedBox(
                            height: 180,
                            child: totalKm == 0
                                ? const Center(
                                    child: Text('No trip data in range', style: TextStyle(color: Color(0xFF556B2F))),
                                  )
                                : SfCircularChart(
                                    legend: Legend(isVisible: true),
                                    series: <PieSeries<_PieData, String>>[
                                      PieSeries<_PieData, String>(
                                        dataSource: [
                                          _PieData('Business', businessKm),
                                          _PieData('Private', totalKm - businessKm),
                                        ],
                                        xValueMapper: (_PieData data, _) => data.label,
                                        yValueMapper: (_PieData data, _) => data.value,
                                        dataLabelMapper: (_PieData data, _) => '${data.label}: ${data.value}',
                                        dataLabelSettings: const DataLabelSettings(isVisible: true),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFC6D870), Color(0xFF8FA31E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Color(0xFF556B2F), blurRadius: 16, offset: Offset(0, 8))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Expenses Breakdown', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
                          SizedBox(
                            height: 180,
                            child: _getExpensePieData().isEmpty
                                ? const Center(
                                    child: Text('No expense data in range', style: TextStyle(color: Color(0xFF556B2F))),
                                  )
                                : SfCircularChart(
                                    legend: Legend(isVisible: true),
                                    series: <PieSeries<_PieDataExpense, String>>[
                                      PieSeries<_PieDataExpense, String>(
                                        dataSource: _getExpensePieData(),
                                        xValueMapper: (_PieDataExpense data, _) => data.type,
                                        yValueMapper: (_PieDataExpense data, _) => data.amount,
                                        dataLabelMapper: (_PieDataExpense data, _) => '${data.type}: ${data.amount.toStringAsFixed(2)}',
                                        dataLabelSettings: const DataLabelSettings(isVisible: true),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Trip Entries', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
                  if (_filteredTrips.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No trips to show for selected filters', style: TextStyle(color: Color(0xFF556B2F))),
                    ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _filteredTrips[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC6D870), Color(0xFFEFF5D2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Color(0xFF556B2F), blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF8FA31E),
                            child: const Icon(Icons.directions_car, color: Color(0xFF556B2F)),
                          ),
                          title: Text('${trip.date} - ${trip.purpose}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF556B2F))),
                          subtitle: Text('KM: ${trip.km}, Category: ${trip.category}', style: const TextStyle(color: Color(0xFF8FA31E))),
                          trailing: Text('Odo: ${trip.odoStart} → ${trip.odoEnd}', style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF8FA31E))),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  title: const Text('Trip Details'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Date: ${trip.date}'),
                                      Text('Odometer Start: ${trip.odoStart}'),
                                      Text('Odometer End: ${trip.odoEnd}'),
                                      Text('KM: ${trip.km}'),
                                      Text('Purpose: ${trip.purpose}'),
                                      Text('Category: ${trip.category}'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const Text('Expense Entries', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
                  if (_filteredExpenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No expenses to show for selected filters', style: TextStyle(color: Color(0xFF556B2F))),
                    ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = _filteredExpenses[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEFF5D2), Color(0xFFC6D870)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(color: Color(0xFF556B2F), blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF8FA31E),
                            child: const Icon(Icons.receipt_long, color: Color(0xFF556B2F)),
                          ),
                          title: Text('${expense.type}: ${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF556B2F))),
                          subtitle: Text('Date: ${expense.date}', style: const TextStyle(color: Color(0xFF8FA31E))),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  title: const Text('Expense Details'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Type: ${expense.type}'),
                                      Text('Amount: ${expense.amount.toStringAsFixed(2)}'),
                                      Text('Date: ${expense.date}'),
                                      if (expense.imagePath != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: expense.imagePath!.endsWith('.pdf')
                                              ? const Icon(Icons.picture_as_pdf, size: 32, color: Colors.red)
                                              : ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.file(File(expense.imagePath!), width: 100, height: 100),
                                                ),
                                        ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PieData {
  final String label;
  final int value;
  _PieData(this.label, this.value);
}

