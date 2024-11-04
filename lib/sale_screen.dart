import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  List<Map<String, dynamic>> _selectedParts = [];
  double _totalPrice = 0.0;
  String _paymentMethod = 'Cash';
  double _partialPaymentAmount = 0.0;

  List<Map<String, dynamic>> _customers = [];
  List<String> _models = [];
  final TextEditingController _modelSearchController = TextEditingController();
  final TextEditingController _partialPaymentController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadModels();
  }

  void _loadCustomers() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('customers').get();
    setState(() {
      _customers = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc['name'] as String,
                'balance': doc['balance'] as double? ?? 0.0,
              })
          .toList();
    });
  }

  void _loadModels() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('models').get();
    setState(() {
      _models = snapshot.docs
          .map((doc) => '${doc['brand']} ${doc['model']}')
          .toList();
    });
  }

  void _showPartsPopup(String modelName) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('models')
        .where('model', isEqualTo: modelName.split(' ').last)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      List<Map<String, dynamic>> parts =
          List<Map<String, dynamic>>.from(snapshot.docs.first['parts']);
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Available Parts for $modelName'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: parts.length,
                itemBuilder: (context, index) {
                  final part = parts[index];
                  return ListTile(
                    title: Text(part['partType']),
                    subtitle: Text(
                      'Price: ₹${part['price']} | Available: ${part['quantity']}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (part['quantity'] > 0) {
                          _addPart(part, modelName, snapshot.docs.first.id);
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Part out of stock')),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  void _addPart(Map<String, dynamic> part, String modelName, String modelId) {
    setState(() {
      _selectedParts.add({
        ...part,
        'model': modelName,
        'modelId': modelId,
        'quantity': 1,
        'availableQuantity': part['quantity'],
      });
      _updateTotalPrice();
    });
  }

  void _removePart(int index) {
    setState(() {
      _selectedParts.removeAt(index);
      _updateTotalPrice();
    });
  }

  void _updateTotalPrice() {
    _totalPrice = _selectedParts.fold(
        0, (sum, part) => sum + (part['price'] * part['quantity']));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildCustomerDropdown(),
            const SizedBox(height: 16),
            _buildModelSearch(),
            const SizedBox(height: 16),
            _buildSelectedPartsList(),
            const SizedBox(height: 16),
            _buildTotalPriceDisplay(),
            const SizedBox(height: 24),
            _buildPaymentMethodSelector(),
            if (_paymentMethod == 'Partial Payment')
              _buildPartialPaymentField(),
            const SizedBox(height: 24),
            _buildCompleteSaleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCustomerId,
      decoration: InputDecoration(
        labelText: 'Customer',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.person),
      ),
      items: _customers.map((customer) {
        return DropdownMenuItem<String>(
          value: customer['id'],
          child: Text(
              '${customer['name']} (Balance: ₹${customer['balance'].toStringAsFixed(2)})'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCustomerId = value;
          _selectedCustomerName = _customers
              .firstWhere((customer) => customer['id'] == value)['name'];
        });
      },
      validator: (value) => value == null ? 'Please select a customer' : null,
    );
  }

  Widget _buildModelSearch() {
    return TypeAheadFormField(
      textFieldConfiguration: TextFieldConfiguration(
        controller: _modelSearchController,
        decoration: InputDecoration(
          labelText: 'Search Model',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      suggestionsCallback: (pattern) {
        return _models
            .where(
                (model) => model.toLowerCase().contains(pattern.toLowerCase()))
            .toList();
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          title: Text(suggestion),
        );
      },
      onSuggestionSelected: (suggestion) {
        setState(() {
          _modelSearchController.text = suggestion;
        });
        _showPartsPopup(suggestion);
      },
      validator: (value) =>
          value == null || value.isEmpty ? 'Please select a model' : null,
    );
  }

  Widget _buildSelectedPartsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selected Parts', style: Theme.of(context).textTheme.subtitle1),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedParts.length,
          itemBuilder: (context, index) {
            final part = _selectedParts[index];
            return ListTile(
              title: Text(part['partType']),
              subtitle: Text(
                  'Price: ₹${part['price']} | Model: ${part['model']} | Quantity: ${part['quantity']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setState(() {
                        if (part['quantity'] > 1) {
                          part['quantity']--;
                        } else {
                          _removePart(index);
                        }
                        _updateTotalPrice();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        if (part['quantity'] < part['availableQuantity']) {
                          part['quantity']++;
                          _updateTotalPrice();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Maximum quantity reached')),
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTotalPriceDisplay() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Total Price',
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 8),
            Text(
              '₹${_totalPrice.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headline4?.copyWith(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment Method', style: Theme.of(context).textTheme.subtitle1),
        const SizedBox(height: 8),
        ToggleButtons(
          onPressed: (int index) {
            setState(() {
              _paymentMethod = ['Cash', 'Udhaar', 'Partial Payment'][index];
              if (_paymentMethod != 'Partial Payment') {
                _partialPaymentAmount = 0;
                _partialPaymentController.clear();
              }
            });
          },
          isSelected: [
            _paymentMethod == 'Cash',
            _paymentMethod == 'Udhaar',
            _paymentMethod == 'Partial Payment'
          ],
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Cash'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Udhaar'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Partial Payment'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPartialPaymentField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _partialPaymentController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Partial Payment Amount',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.payments),
        ),
        onChanged: (value) {
          setState(() {
            _partialPaymentAmount = double.tryParse(value) ?? 0;
          });
        },
        validator: (value) {
          if (_paymentMethod == 'Partial Payment') {
            if (value == null || value.isEmpty) {
              return 'Please enter the partial payment amount';
            }
            double amount = double.tryParse(value) ?? 0;
            if (amount <= 0 || amount >= _totalPrice) {
              return 'Invalid partial payment amount';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCompleteSaleButton() {
    return ElevatedButton(
      onPressed: _showConfirmationDialog,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Complete Sale', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  void _showConfirmationDialog() {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Sale'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: $_selectedCustomerName'),
                Text('Total Price: ₹${_totalPrice.toStringAsFixed(2)}'),
                Text('Payment Method: $_paymentMethod'),
                if (_paymentMethod == 'Partial Payment')
                  Text(
                      'Partial Payment: ₹${_partialPaymentAmount.toStringAsFixed(2)}'),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Confirm'),
                onPressed: () async {
                  await _completeSale();
                  Navigator.of(context).pop(); // Close dialog
                  _clearForm();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Sale completed successfully!')),
                  );
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> updateQuantitiesInTransaction({
    required Transaction transaction,
    required String modelId,
    required String partType,
    required int quantityToReduce,
  }) async {
    // First, collect all models that need to be updated
    Set<Map<String, dynamic>> modelsToUpdate = await _collectModelsToUpdate(
      transaction: transaction,
      modelId: modelId,
      partType: partType,
      quantityToReduce: quantityToReduce,
      visitedModels: {},
    );

    // Now perform all updates
    for (var modelData in modelsToUpdate) {
      DocumentReference modelRef = FirebaseFirestore.instance
          .collection('models')
          .doc(modelData['modelId']);

      List<dynamic> parts = modelData['parts'];
      int partIndex = parts.indexWhere((p) => p['partType'] == partType);

      if (partIndex != -1) {
        parts[partIndex]['quantity'] =
            parts[partIndex]['quantity'] - quantityToReduce;
        transaction.update(modelRef, {'parts': parts});
      }
    }
  }

  Future<Set<Map<String, dynamic>>> _collectModelsToUpdate({
    required Transaction transaction,
    required String modelId,
    required String partType,
    required int quantityToReduce,
    required Set<String> visitedModels,
  }) async {
    // Prevent infinite loops in circular references
    if (visitedModels.contains(modelId)) {
      return {};
    }
    visitedModels.add(modelId);

    Set<Map<String, dynamic>> modelsToUpdate = {};

    // Get the current model
    DocumentReference modelRef =
        FirebaseFirestore.instance.collection('models').doc(modelId);
    DocumentSnapshot modelSnapshot = await transaction.get(modelRef);

    if (!modelSnapshot.exists) {
      throw Exception('Model not found');
    }

    // Get the parts array
    Map<String, dynamic> modelData =
        modelSnapshot.data() as Map<String, dynamic>;
    List<dynamic> parts = List<dynamic>.from(modelData['parts']);

    // Find the specific part
    int partIndex = parts.indexWhere((p) => p['partType'] == partType);

    if (partIndex == -1) {
      throw Exception('Part not found in model');
    }

    // Check if there's enough quantity
    int currentQuantity = parts[partIndex]['quantity'];
    if (currentQuantity < quantityToReduce) {
      throw Exception(
          'Insufficient quantity in model ${modelData['model']} for part ${parts[partIndex]['partType']}');
    }

    // Add this model to the update set
    modelsToUpdate.add({
      'modelId': modelId,
      'parts': parts,
    });

    // Recursively collect linked models
    if (parts[partIndex]['linkedModels'] != null) {
      for (var linkedModel in parts[partIndex]['linkedModels']) {
        String linkedModelId = linkedModel['modelId'];

        Set<Map<String, dynamic>> linkedModelsToUpdate =
            await _collectModelsToUpdate(
          transaction: transaction,
          modelId: linkedModelId,
          partType: partType,
          quantityToReduce: quantityToReduce,
          visitedModels: visitedModels,
        );

        modelsToUpdate.addAll(linkedModelsToUpdate);
      }
    }

    return modelsToUpdate;
  }

  Future<void> _completeSale() async {
    try {
      // Create sale record first
      DocumentReference saleRef =
          await FirebaseFirestore.instance.collection('sales').add({
        'customerId': _selectedCustomerId,
        'customerName': _selectedCustomerName,
        'parts': _selectedParts,
        'totalPrice': _totalPrice,
        'paymentMethod': _paymentMethod,
        'partialPaymentAmount': _partialPaymentAmount,
        'date': Timestamp.now(),
      });

      // Update stock quantities with linked models support
      for (var part in _selectedParts) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          await updateQuantitiesInTransaction(
            transaction: transaction,
            modelId: part['modelId'],
            partType: part['partType'],
            quantityToReduce: part['quantity'],
          );
        });
      }

      // Update customer balance if needed
      if (_paymentMethod == 'Udhaar' || _paymentMethod == 'Partial Payment') {
        double balanceToAdd = _paymentMethod == 'Udhaar'
            ? _totalPrice
            : _totalPrice - _partialPaymentAmount;

        DocumentReference customerRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(_selectedCustomerId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot customerSnapshot =
              await transaction.get(customerRef);
          if (customerSnapshot.exists) {
            double currentBalance =
                (customerSnapshot['balance'] as num).toDouble();
            transaction.update(
                customerRef, {'balance': currentBalance + balanceToAdd});
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  void _clearForm() {
    setState(() {
      _selectedCustomerId = null;
      _selectedCustomerName = null;
      _selectedParts.clear();
      _totalPrice = 0.0;
      _paymentMethod = 'Cash';
      _partialPaymentAmount = 0.0;
      _modelSearchController.clear();
      _partialPaymentController.clear();
    });
  }
}
