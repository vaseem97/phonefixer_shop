import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phonefixer_shop/add_parts_screen.dart';
import 'package:phonefixer_shop/model_parts_screen.dart';
import 'package:phonefixer_shop/predfined_screen.dart'; // Firebase Firestore

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _filteredModels = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchQuery = ''; // Clear search on button press
                _searchController.clear(); // Clear text in the search bar
                FocusScope.of(context)
                    .unfocus(); // Remove focus from the search bar
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('models').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final models = snapshot.data!.docs;

                // Filter models based on the search query for both brand and model
                _filteredModels = models.where((model) {
                  var modelData = model.data() as Map<String, dynamic>;
                  String brand = modelData['brand'].toLowerCase();
                  String modelName = modelData['model'].toLowerCase();
                  return modelName.contains(_searchQuery.toLowerCase()) ||
                      brand.contains(_searchQuery.toLowerCase());
                }).toList();

                if (_filteredModels.isEmpty) {
                  return const Center(
                    child: Text(
                      'No models found. Please adjust your search.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: _filteredModels.length,
                  itemBuilder: (context, index) {
                    var modelData =
                        _filteredModels[index].data() as Map<String, dynamic>;
                    String brand = modelData['brand'];
                    String modelName = modelData['model'];
                    List parts = modelData['parts'];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 16),
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          '$brand $modelName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Total Parts: ${parts.length}',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            const Divider(),
                            ...parts.map<Widget>((part) {
                              // Safely get quantity and threshold, defaulting to 0 if null
                              int quantity = part['quantity'] ?? 0;
                              int threshold = part['threshold'] ?? 0;
                              String? partColor = part['color'];
                              String partType = part['partType'];
                              double price = (part['price'] ?? 0).toDouble();

                              // Determine if the part price should be red based on threshold
                              bool isThresholdExceeded = quantity < threshold;

                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$partType',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (partColor != null) ...[
                                          Text(
                                            'Color: $partColor',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueGrey),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isThresholdExceeded
                                                ? Colors.red
                                                : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Qty: $quantity',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isThresholdExceeded
                                                ? Colors.red
                                                : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ModelPartsScreen(
                                modelId: _filteredModels[index].id,
                                brand: '',
                              ),
                            ),
                          );
                        },
                        onLongPress: () {
                          _showDeleteConfirmationDialog(
                              context, _filteredModels[index]);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddModelScreen()),
              );
            },
            child: const Icon(Icons.add),
            tooltip: 'Add Model',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => PredefinedPartsScreen()),
              );
            },
            child: const Icon(Icons.build),
            tooltip: 'Manage Predefined Parts',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller:
            _searchController, // Attach the controller to the search bar
        decoration: const InputDecoration(
          labelText: 'Search by Model or Brand',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.search),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value; // Update search query
          });
        },
      ),
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, QueryDocumentSnapshot model) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this model?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Call the delete method here
                FirebaseFirestore.instance
                    .collection('models')
                    .doc(model.id)
                    .delete();
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
