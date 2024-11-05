import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phonefixer_shop/linking_parts.dart';

class ModelPartsScreen extends StatefulWidget {
  final String modelId;
  final String brand;

  const ModelPartsScreen({
    required this.modelId,
    required this.brand,
    super.key,
  });

  @override
  _ModelPartsScreenState createState() => _ModelPartsScreenState();
}

class _ModelPartsScreenState extends State<ModelPartsScreen> {
  List<Map<String, dynamic>> parts = [];
  List<Map<String, dynamic>> predefinedParts = [];
  List<DocumentSnapshot> allModels = [];
  final ModelPartsLinking _linking = ModelPartsLinking();
  String searchQuery = '';

  final List<String> partTypes = [
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

  @override
  void initState() {
    super.initState();
    _loadModelParts();
    _loadPredefinedParts();
    _loadAllModels();
  }

  Future<void> _loadModelParts() async {
    DocumentSnapshot modelDoc = await FirebaseFirestore.instance
        .collection('models')
        .doc(widget.modelId)
        .get();

    if (mounted) {
      setState(() {
        final modelData = modelDoc.data() as Map<String, dynamic>?;
        parts = List<Map<String, dynamic>>.from(modelData?['parts'] ?? []);
      });
    }
  }

  Future<void> _loadPredefinedParts() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('predefinedParts')
        .doc(widget.brand)
        .get();

    if (snapshot.exists && mounted) {
      setState(() {
        final data = snapshot.data() as Map<String, dynamic>?;
        predefinedParts = List<Map<String, dynamic>>.from(data?['parts'] ?? []);
      });
    }
  }

  Future<void> _loadAllModels() async {
    QuerySnapshot querySnapshot =
        await FirebaseFirestore.instance.collection('models').get();

    if (mounted) {
      setState(() {
        allModels = querySnapshot.docs;
      });
    }
  }

  void _showModelSearchDialog(Map<String, dynamic> part) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            final filteredModels = allModels.where((doc) {
              final modelData = doc.data() as Map<String, dynamic>?;
              if (modelData == null) return false;

              if (doc.id == widget.modelId) return false;

              final linkedModels = part['linkedModels'] as List? ?? [];
              if (linkedModels.any((linked) => linked['modelId'] == doc.id))
                return false;

              final modelName =
                  modelData['model']?.toString().toLowerCase() ?? '';
              return searchQuery.isEmpty ||
                  modelName.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: const Text('Search Model'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Model by Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredModels.length,
                        itemBuilder: (context, index) {
                          final modelDoc = filteredModels[index];
                          final modelData =
                              modelDoc.data() as Map<String, dynamic>?;
                          if (modelData == null) return const SizedBox.shrink();

                          final modelName =
                              modelData['model']?.toString() ?? 'Unknown Model';

                          return ListTile(
                            title: Text(modelName),
                            onTap: () async {
                              await _linking.linkPartToModel(
                                context,
                                part,
                                modelData,
                                modelDoc.id,
                                widget.modelId,
                                () async {
                                  await _loadModelParts(); // Reload parts after linking
                                },
                              );
                              Navigator.pop(dialogContext);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPartDialog() {
    String? selectedPartType;
    String selectedColor = '';
    int selectedQuantity = 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Part'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Part Type',
                    border: OutlineInputBorder(),
                  ),
                  items: partTypes.map((partType) {
                    return DropdownMenuItem<String>(
                      value: partType,
                      child: Text(partType),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedPartType = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Color (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    selectedColor = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    selectedQuantity = int.tryParse(value) ?? 0;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (selectedPartType != null) {
                  _addPartToModel(
                      selectedPartType!, selectedColor, selectedQuantity);
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addPartToModel(String partType, String color, int quantity) {
    setState(() {
      parts.add({
        'partType': partType,
        'color': color.isNotEmpty ? color : null,
        'price': 0,
        'quantity': quantity,
        'threshold': 0,
        'linkedModels': [],
      });
    });
    _saveParts();
  }

  Future<void> _saveParts() async {
    try {
      await _linking.savePartsToFirestore(
        context,
        widget.modelId,
        parts,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parts updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating parts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Parts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveParts,
          ),
        ],
      ),
      body: parts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var part = parts[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  part['partType'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            part['price']?.toString() ?? '0',
                                        decoration: const InputDecoration(
                                          labelText: 'Price',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            part['price'] =
                                                double.tryParse(value) ?? 0;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            part['quantity']?.toString() ?? '0',
                                        decoration: const InputDecoration(
                                          labelText: 'Quantity',
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          setState(() {
                                            part['quantity'] =
                                                int.tryParse(value) ?? 0;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue:
                                      part['threshold']?.toString() ?? '0',
                                  decoration: const InputDecoration(
                                    labelText: 'Threshold',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      part['threshold'] =
                                          int.tryParse(value) ?? 0;
                                    });
                                  },
                                ),
                                if (part['color'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text('Color: ${part['color']}'),
                                ],
                                const SizedBox(height: 16),
                                if (part['linkedModels'] != null &&
                                    (part['linkedModels'] as List)
                                        .isNotEmpty) ...[
                                  const Text(
                                    'Linked Models:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: (part['linkedModels'] as List)
                                        .map((modelInfo) => Chip(
                                              label: Text(modelInfo['model']),
                                              onDeleted: () async {
                                                await _linking.unlinkModel(
                                                  context,
                                                  part,
                                                  modelInfo,
                                                  widget.modelId,
                                                  () async {
                                                    await _loadModelParts(); // Reload parts after unlinking
                                                  },
                                                );
                                              },
                                            ))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _showModelSearchDialog(part),
                                    child: const Text('Link New Model'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: parts.length,
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPartDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
