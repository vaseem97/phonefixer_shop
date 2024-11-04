import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddModelScreen extends StatefulWidget {
  const AddModelScreen({super.key});

  @override
  _AddModelScreenState createState() => _AddModelScreenState();
}

class _AddModelScreenState extends State<AddModelScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBrand;
  String _modelName = '';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> brands = [
    'Samsung',
    'Vivo',
    'Oppo',
    'Realme',
    'Mi',
    'OnePlus',
    'iPhone',
  ];

  final _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set default brand
    _selectedBrand = brands[0];
  }

  @override
  void dispose() {
    _modelController.dispose();
    super.dispose();
  }

  // Custom text capitalization formatter
  final capitalizeFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  });

  // Check if model already exists (case-insensitive)
  Future<bool> _checkModelExists() async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('models')
        .where('brand', isEqualTo: _selectedBrand)
        .get();

    final String modelToCheckLower = _modelName.toLowerCase().trim();

    for (var doc in result.docs) {
      final String existingModel = (doc.data() as Map<String, dynamic>)['model']
          .toString()
          .toLowerCase()
          .trim();
      if (existingModel == modelToCheckLower) {
        return true;
      }
    }

    return false;
  }

  // Normalize and capitalize model name
  String _normalizeModelName(String modelName) {
    // Remove extra spaces and convert to uppercase
    return modelName.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  // Save model to Firebase
  Future<void> _saveModel() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Normalize and capitalize model name
      _modelName = _normalizeModelName(_modelName);

      // Check for duplicates
      bool exists = await _checkModelExists();
      if (exists) {
        setState(() {
          _errorMessage = 'This model already exists for the selected brand';
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> predefinedParts =
          await _initializePredefinedParts();

      await FirebaseFirestore.instance.collection('models').add({
        'brand': _selectedBrand,
        'model': _modelName,
        'modelLower': _modelName.toLowerCase(),
        'parts': predefinedParts,
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _modelController.clear();
        _modelName = '';
        _errorMessage = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added: $_selectedBrand $_modelName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      });

      // Keep focus on the model input field for quick consecutive entries
      FocusScope.of(context).requestFocus(FocusNode());
    } catch (e) {
      setState(() {
        _errorMessage = 'Error adding model: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _initializePredefinedParts() async {
    if (_selectedBrand != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('predefinedParts')
          .doc(_selectedBrand)
          .get();

      if (snapshot.exists) {
        return List<Map<String, dynamic>>.from(snapshot['parts']);
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Model'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Select Brand',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<String>(
                            selected: {_selectedBrand ?? brands[0]},
                            onSelectionChanged: (Set<String> selection) {
                              setState(() {
                                _selectedBrand = selection.first;
                              });
                            },
                            segments: brands
                                .map((brand) => ButtonSegment(
                                      value: brand,
                                      label: Text(brand),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _modelController,
                          decoration: InputDecoration(
                            labelText: 'Model Name',
                            border: const OutlineInputBorder(),
                            filled: true,
                            hintText: 'Will be saved in CAPS',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _modelController.clear();
                                setState(() {
                                  _modelName = '';
                                });
                              },
                            ),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [capitalizeFormatter],
                          onChanged: (value) {
                            setState(() {
                              _modelName = value;
                            });
                          },
                          validator: (value) =>
                              value!.isEmpty ? 'Enter model name' : null,
                          onFieldSubmitted: (_) {
                            if (_formKey.currentState!.validate()) {
                              _saveModel();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _saveModel();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Model'),
                ),
                const SizedBox(height: 16),
                // Quick reference for currently selected brand
                Text(
                  'Selected Brand: $_selectedBrand',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
