import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PredefinedPartsScreen extends StatefulWidget {
  const PredefinedPartsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PredefinedPartsScreenState createState() => _PredefinedPartsScreenState();
}

class _PredefinedPartsScreenState extends State<PredefinedPartsScreen> {
  List<String> brands = [
    'Samsung',
    'Vivo',
    'Oppo',
    'Realme',
    'Mi',
    'OnePlus',
    'iPhone',
  ];
  List<String> partTypes = [
    'Display',
    'Battery',
    'Back Panel',
    'Front Camera',
    'Rear Camera',
    'Charging Port',
    'Speaker',
    'Power Button',
    'Volume Button',
    'Motherboard',
  ];

  String? selectedBrand;
  List<Map<String, dynamic>> parts = [];
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Predefined Parts'),
        actions: [
          if (selectedBrand != null && parts.isNotEmpty)
            isSaving
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _savePredefinedParts,
                    tooltip: 'Save Parts',
                  ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand Dropdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  value: selectedBrand,
                  decoration: const InputDecoration(
                    labelText: 'Select Brand',
                    border: OutlineInputBorder(),
                  ),
                  items: brands.map((String brand) {
                    return DropdownMenuItem<String>(
                      value: brand,
                      child: Text(brand),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedBrand = value;
                      _loadPredefinedParts();
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Parts List
            Expanded(
              child: parts.isEmpty
                  ? Center(
                      child: Text(
                        selectedBrand == null
                            ? 'Please select a brand'
                            : 'No parts available',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: parts.length,
                      itemBuilder: (context, index) {
                        var part = parts[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(part['partType']),
                            subtitle: part['color'] != null
                                ? Text('Color: ${part['color']}')
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  parts.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: selectedBrand == null ? null : _addNewPart,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addNewPart() {
    String? selectedPartType;
    String newColor = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Part'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Part Type Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Part Type',
                border: OutlineInputBorder(),
              ),
              items: partTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                selectedPartType = value;
              },
            ),
            const SizedBox(height: 16),
            // Color TextField
            TextField(
              decoration: const InputDecoration(
                labelText: 'Color (Optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                newColor = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (selectedPartType != null) {
                setState(() {
                  parts.add({
                    'partType': selectedPartType,
                    'color': newColor.isNotEmpty ? newColor : null,
                    'price': 0,
                    'quantity': 0,
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Part added. Don\'t forget to save your changes!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPredefinedParts() async {
    if (selectedBrand != null) {
      setState(() => parts = []);
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('predefinedParts')
          .doc(selectedBrand)
          .get();

      if (snapshot.exists) {
        setState(() {
          parts = List<Map<String, dynamic>>.from(snapshot['parts']);
        });
      }
    }
  }

  Future<void> _savePredefinedParts() async {
    if (selectedBrand != null) {
      setState(() => isSaving = true);

      try {
        await FirebaseFirestore.instance
            .collection('predefinedParts')
            .doc(selectedBrand)
            .set({'parts': parts});

        await _updateExistingModels();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parts saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving parts'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _updateExistingModels() async {
    if (selectedBrand == null) return;

    QuerySnapshot modelsSnapshot = await FirebaseFirestore.instance
        .collection('models')
        .where('brand', isEqualTo: selectedBrand)
        .get();

    for (var modelDoc in modelsSnapshot.docs) {
      List<dynamic> modelParts = List.from(modelDoc['parts']);

      for (var predefinedPart in parts) {
        bool partExists = modelParts.any(
          (modelPart) =>
              modelPart['partType'] == predefinedPart['partType'] &&
              modelPart['color'] == predefinedPart['color'],
        );

        if (!partExists) {
          modelParts.add({
            'partType': predefinedPart['partType'],
            'color': predefinedPart['color'],
            'price': predefinedPart['price'],
            'quantity': predefinedPart['quantity'],
          });
        }
      }

      modelParts.removeWhere((modelPart) => !parts.any(
            (predefinedPart) =>
                predefinedPart['partType'] == modelPart['partType'] &&
                predefinedPart['color'] == modelPart['color'],
          ));

      await FirebaseFirestore.instance
          .collection('models')
          .doc(modelDoc.id)
          .update({'parts': modelParts});
    }
  }
}
