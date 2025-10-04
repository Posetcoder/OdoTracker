import 'package:flutter/material.dart';
import 'trips_page.dart';
import 'expenses_page.dart';
import 'reports_page.dart';
import 'db_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OdoTracker',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF556B2F),
          onPrimary: Color(0xFFEFF5D2),
          secondary: Color(0xFF8FA31E),
          onSecondary: Color(0xFF556B2F),
          background: Color(0xFFEFF5D2),
          onBackground: Color(0xFF556B2F),
          surface: Color(0xFFC6D870),
          onSurface: Color(0xFF556B2F),
          error: Colors.red,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Color(0xFFEFF5D2),
        cardColor: Color(0xFFC6D870),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF556B2F),
          foregroundColor: Color(0xFFEFF5D2),
          elevation: 4,
        ),
        iconTheme: IconThemeData(color: Color(0xFF8FA31E)),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF556B2F)),
          bodyMedium: TextStyle(color: Color(0xFF556B2F)),
          titleLarge: TextStyle(color: Color(0xFF556B2F)),
        ),
      ),
      home: const OdoTrackerHome(),
    );
  }
}

class OdoTrackerHome extends StatefulWidget {
  const OdoTrackerHome({super.key});

  @override
  State<OdoTrackerHome> createState() => _OdoTrackerHomeState();
}

class _OdoTrackerHomeState extends State<OdoTrackerHome> {
  int? _selectedCarId;
  int _selectedIndex = 0;
  List<Car> _cars = [];

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    _cars = await DatabaseHelper.instance.getCars();
    setState(() {});
  }

  void _onCarSelected(int carId) {
    setState(() {
      _selectedCarId = carId;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCarId == null) {
      // Car selection dashboard
      return Scaffold(
        appBar: AppBar(
          title: const Text('Select Car', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEFF5D2), Color(0xFFC6D870)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              ..._cars.map((car) => Card(
                elevation: 3,
                color: Color(0xFFC6D870),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF8FA31E),
                    child: Icon(Icons.directions_car, color: Color(0xFF556B2F)),
                  ),
                  title: Text(car.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF556B2F))),
                  subtitle: Text(car.rego, style: const TextStyle(color: Color(0xFF8FA31E))),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF556B2F)),
                  onTap: () => _onCarSelected(car.id!),
                ),
              )),
              Card(
                elevation: 2,
                color: Color(0xFFC6D870),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.add, color: Color(0xFF8FA31E), size: 28),
                  title: const Text('Add Car', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
                  onTap: () async {
                    final nameController = TextEditingController();
                    final regoController = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          title: const Text('Add Car'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(labelText: 'Car Name'),
                                ),
                                TextField(
                                  controller: regoController,
                                  decoration: const InputDecoration(labelText: 'Rego'),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final rego = regoController.text.trim();
                                if (name.isNotEmpty && rego.isNotEmpty) {
                                  try {
                                    await DatabaseHelper.instance.insertCar(Car(name: name, rego: rego));
                                    await _loadCars();
                                    Navigator.pop(context);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to add car: $e')),
                                      );
                                    }
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter both car name and rego.')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Car dashboard: show tabs for selected car
    final pages = [
      TripsPage(carId: _selectedCarId!),
      ExpensesPage(carId: _selectedCarId!),
      ReportsPage(carId: _selectedCarId!),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_cars.firstWhere((c) => c.id == _selectedCarId).name),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            tooltip: 'Switch Car',
            onPressed: () => setState(() => _selectedCarId = null),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.directions_car,
              color: _selectedIndex == 0 ? Color(0xFF556B2F) : Color(0xFF8FA31E),
            ),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.receipt_long,
              color: _selectedIndex == 1 ? Color(0xFF556B2F) : Color(0xFF8FA31E),
            ),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.bar_chart,
              color: _selectedIndex == 2 ? Color(0xFF556B2F) : Color(0xFF8FA31E),
            ),
            label: 'Reports',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF556B2F),
        unselectedItemColor: Color(0xFF222222),
        backgroundColor: Color(0xFFC6D870),
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }
}
