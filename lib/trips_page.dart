import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class TripsPage extends StatefulWidget {
  final int carId;
  const TripsPage({super.key, required this.carId});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  Trip? _incompleteTrip;
  bool get hasIncompleteTrip => _incompleteTrip != null;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _odoStartController = TextEditingController();
  final TextEditingController _odoEndController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final FocusNode _odoEndFocusNode = FocusNode();
  String _category = 'Business';
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _loadTrips();
    _autofillStartOdoOnInit();
  }

  Future<void> _loadTrips() async {
    _trips = await DatabaseHelper.instance.getTrips(carId: widget.carId);
    _trips.sort((a, b) => b.date.compareTo(a.date));
    final found = _trips.where((t) => t.odoEnd == 0 || t.odoEnd <= t.odoStart);
    _incompleteTrip = found.isNotEmpty ? found.first : null;
    if (mounted) setState(() {});
  }

  Future<void> _autofillStartOdoOnInit() async {
    final trips = await DatabaseHelper.instance.getTrips(carId: widget.carId);
    if (trips.isNotEmpty) {
      trips.sort((a, b) => b.odoEnd.compareTo(a.odoEnd));
      if (mounted) {
        setState(() {
          _odoStartController.text = trips.first.odoEnd.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _odoStartController.dispose();
    _odoEndController.dispose();
    _purposeController.dispose();
    _odoEndFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF5D2),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEFF5D2), Color(0xFFC6D870)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF5D2),
                    borderRadius: BorderRadius.circular(18),
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hasIncompleteTrip) ...[
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
                                  _dateController.text =
                                      DateFormat('dd/MM/yyyy').format(picked);
                                }
                              },
                            ),
                            TextFormField(
                              controller: _odoStartController,
                              decoration: const InputDecoration(
                                  labelText: 'Odometer Start'),
                              keyboardType: TextInputType.number,
                              onTap: () {
                                _odoStartController.clear();
                              },
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8FA31E),
                                foregroundColor: const Color(0xFF556B2F),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFF556B2F),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 18,
                                ),
                                minimumSize: const Size(0, 38),
                              ),
                              onPressed: () async {
                                if (_odoStartController.text.isNotEmpty) {
                                  int odoStart = int.tryParse(_odoStartController.text) ?? 0;
                                  Trip tempTrip = Trip(
                                    carId: widget.carId,
                                    date: _dateController.text,
                                    odoStart: odoStart,
                                    odoEnd: 0,
                                    km: 0,
                                    purpose: '',
                                    category: 'Business',
                                  );
                                  await DatabaseHelper.instance.insertTrip(tempTrip);
                                  // Autofill start odometer instantly from last trip before reload
                                  final trips = await DatabaseHelper.instance.getTrips(carId: widget.carId);
                                  String newStart = _odoStartController.text;
                                  if (trips.isNotEmpty) {
                                    trips.sort((a, b) => b.odoEnd.compareTo(a.odoEnd));
                                    newStart = trips.first.odoEnd.toString();
                                  }
                                  setState(() {
                                    _odoStartController.text = newStart;
                                    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
                                    _category = 'Business';
                                  });
                                  await _loadTrips();
                                }
                              },
                              child: const Text(
                                'Save Temporary',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _odoEndController,
                              focusNode: _odoEndFocusNode,
                              decoration: const InputDecoration(
                                  labelText: 'Odometer End'),
                              keyboardType: TextInputType.number,
                            ),
                            TextFormField(
                              controller: _purposeController,
                              decoration: const InputDecoration(
                                  labelText: 'Purpose'),
                            ),
                            DropdownButtonFormField<String>(
                              value: _category,
                              items: ['Business', 'Personal']
                                  .map((cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Text(cat),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _category = val!;
                                });
                              },
                              decoration: const InputDecoration(
                                  labelText: 'Category'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8FA31E),
                                foregroundColor: const Color(0xFF556B2F),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFF556B2F),
                                    width: 1.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 18,
                                ),
                                minimumSize: const Size(0, 38),
                              ),
                              onPressed: () async {
                                if (_odoEndController.text.isNotEmpty) {
                                  int odoEnd = int.tryParse(_odoEndController.text) ?? 0;
                                  int odoStart = _incompleteTrip!.odoStart;
                                  if (odoEnd <= odoStart) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Odometer Finish must be greater than Odometer Start.')),
                                    );
                                    return;
                                  }
                                  final km = odoEnd - odoStart;
                                  Trip completed = Trip(
                                    id: _incompleteTrip!.id,
                                    carId: widget.carId,
                                    date: _incompleteTrip!.date,
                                    odoStart: odoStart,
                                    odoEnd: odoEnd,
                                    km: km,
                                    purpose: _purposeController.text,
                                    category: _category,
                                  );
                                  await DatabaseHelper.instance.updateTrip(completed);
                                  // Autofill start odometer instantly from last trip
                                  final trips = await DatabaseHelper.instance.getTrips(carId: widget.carId);
                                  String newStart = _odoStartController.text;
                                  if (trips.isNotEmpty) {
                                    trips.sort((a, b) => b.odoEnd.compareTo(a.odoEnd));
                                    newStart = trips.first.odoEnd.toString();
                                  }
                                  _odoEndController.clear();
                                  _purposeController.clear();
                                  setState(() {
                                    _incompleteTrip = null;
                                    _category = 'Business';
                                    _odoStartController.text = newStart;
                                  });
                                  await _loadTrips();
                                }
                              },
                              child: const Text(
                                'Complete Trip',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Trip Entries',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF556B2F),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC6D870), Color(0xFFEFF5D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF556B2F),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF8FA31E),
                          child: Icon(Icons.directions_car,
                              color: Color(0xFF556B2F)),
                        ),
                        title: Text(
                          '${trip.date} - ${trip.purpose}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF556B2F),
                          ),
                        ),
                        subtitle: Text(
                          'Odometer: ${trip.odoStart} → ${trip.odoEnd}, Category: ${trip.category}',
                          style: const TextStyle(color: Color(0xFF8FA31E)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Color(0xFF556B2F)),
                              onPressed: () async {
                                final updatedTrip =
                                    await showDialog<Trip>(
                                  context: context,
                                  builder: (context) => EditTripDialog(trip),
                                );
                                if (updatedTrip != null) {
                                  await DatabaseHelper.instance
                                      .updateTrip(updatedTrip);
                                  await _loadTrips();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () async {
                                await DatabaseHelper.instance
                                    .deleteTrip(trip.id!);
                                await _loadTrips();
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
        ],
      ),
    );
  }
}

class EditTripDialog extends StatefulWidget {
  final Trip trip;
  const EditTripDialog(this.trip, {super.key});

  @override
  State<EditTripDialog> createState() => _EditTripDialogState();
}

class _EditTripDialogState extends State<EditTripDialog> {
  late TextEditingController _purposeController;
  late TextEditingController _odoEndController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _purposeController = TextEditingController(text: widget.trip.purpose);
    _odoEndController =
        TextEditingController(text: widget.trip.odoEnd.toString());
    _category = widget.trip.category;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Trip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _purposeController,
            decoration: const InputDecoration(labelText: 'Purpose'),
          ),
          TextField(
            controller: _odoEndController,
            decoration: const InputDecoration(labelText: 'Odometer End'),
            keyboardType: TextInputType.number,
          ),
          DropdownButtonFormField<String>(
            value: _category,
            items: ['Business', 'Personal']
                .map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    ))
                .toList(),
            onChanged: (val) {
              setState(() {
                _category = val!;
              });
            },
            decoration: const InputDecoration(labelText: 'Category'),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text('Save'),
          onPressed: () {
            final updatedTrip = Trip(
              id: widget.trip.id,
              carId: widget.trip.carId,
              date: widget.trip.date,
              odoStart: widget.trip.odoStart,
              odoEnd: int.tryParse(_odoEndController.text) ?? widget.trip.odoEnd,
              km: (int.tryParse(_odoEndController.text) ??
                      widget.trip.odoEnd) -
                  widget.trip.odoStart,
              purpose: _purposeController.text,
              category: _category,
            );
            Navigator.pop(context, updatedTrip);
          },
        ),
      ],
    );
  }
}
