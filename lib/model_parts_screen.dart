import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
                                // Display linked models
                                if (part['linkedModels'] != null &&
                                    (part['linkedModels'] as List)
                                        .isNotEmpty) ...[
                                  const Text(
                                    'Linked Models:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: (part['linkedModels'] as List)
                                        .map((modelInfo) => Chip(
                                              label: Text(modelInfo['model']),
                                              onDeleted: () =>
                                                  _unlinkModel(part, modelInfo),
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

  void _showModelSearchDialog(Map<String, dynamic> part) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredModels = allModels.where((doc) {
              final modelData = doc.data() as Map<String, dynamic>?;
              if (modelData == null) return false;

              // Exclude current model and already linked models
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
                        setState(() {
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
                            onTap: () {
                              _linkPartToModel(part, modelData, modelDoc.id);
                              Navigator.pop(context);
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _linkPartToModel(Map<String, dynamic> part,
      Map<String, dynamic> modelData, String modelId) async {
    try {
      // Get all existing linked models including the current one
      Set<String> allLinkedModelIds = {widget.modelId};
      List<Map<String, dynamic>> allLinkedModelsInfo = [];

      // Add existing linked models
      if (part['linkedModels'] != null) {
        for (var linked in (part['linkedModels'] as List)) {
          allLinkedModelIds.add(linked['modelId']);
          allLinkedModelsInfo.add(Map<String, dynamic>.from(linked));
        }
      }

      // Add the new model
      allLinkedModelIds.add(modelId);

      // Fetch all linked models' data
      Map<String, DocumentSnapshot> modelDocs = {};
      for (String id in allLinkedModelIds) {
        DocumentSnapshot doc =
            await FirebaseFirestore.instance.collection('models').doc(id).get();
        modelDocs[id] = doc;
      }

      // Create complete linked models info list
      for (String id in allLinkedModelIds) {
        var doc = modelDocs[id];
        if (doc != null && doc.exists) {
          var data = doc.data() as Map<String, dynamic>?;
          if (data != null &&
              !allLinkedModelsInfo.any((m) => m['modelId'] == id)) {
            allLinkedModelsInfo.add({
              'modelId': id,
              'model': data['model'],
            });
          }
        }
      }

      // Update all models with the complete list of links
      for (String id in allLinkedModelIds) {
        var doc = modelDocs[id];
        if (doc != null && doc.exists) {
          var modelData = doc.data() as Map<String, dynamic>?;
          if (modelData != null) {
            List<Map<String, dynamic>> modelParts =
                List<Map<String, dynamic>>.from(modelData['parts'] ?? []);

            // Find or create the part in the current model
            int existingIndex = modelParts.indexWhere((p) =>
                p['partType'] == part['partType'] &&
                p['color'] == part['color']);

            // Create updated part with all links
            Map<String, dynamic> updatedPart = {
              'partType': part['partType'],
              'color': part['color'],
              'price': part['price'],
              'quantity': part['quantity'],
              'threshold': part['threshold'],
              'linkedModels': allLinkedModelsInfo
                  .where((m) => m['modelId'] != id) // Exclude self from links
                  .toList(),
            };

            if (existingIndex >= 0) {
              modelParts[existingIndex] = updatedPart;
            } else {
              modelParts.add(updatedPart);
            }

            // Update the model in Firestore
            await FirebaseFirestore.instance
                .collection('models')
                .doc(id)
                .update({'parts': modelParts});
          }
        }
      }

      // Update local state for current model
      setState(() {
        part['linkedModels'] = allLinkedModelsInfo
            .where((m) => m['modelId'] != widget.modelId)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating linked models: $e')),
        );
      }
    }
  }

  // Update _unlinkModel method to handle recursive unlinking
  void _unlinkModel(
      Map<String, dynamic> part, Map<String, dynamic> modelInfo) async {
    try {
      // Get all currently linked models
      Set<String> allLinkedModelIds = {};
      for (var linked in (part['linkedModels'] as List)) {
        allLinkedModelIds.add(linked['modelId']);
      }
      // Remove the model being unlinked
      allLinkedModelIds.remove(modelInfo['modelId']);
      allLinkedModelIds.add(widget.modelId);

      // Fetch all remaining linked models' data
      Map<String, DocumentSnapshot> modelDocs = {};
      for (String id in allLinkedModelIds) {
        DocumentSnapshot doc =
            await FirebaseFirestore.instance.collection('models').doc(id).get();
        modelDocs[id] = doc;
      }

      // Create updated linked models info list
      List<Map<String, dynamic>> updatedLinkedModelsInfo = [];
      for (String id in allLinkedModelIds) {
        if (id != modelInfo['modelId']) {
          // Exclude the unlinked model
          var doc = modelDocs[id];
          if (doc != null && doc.exists) {
            var data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              updatedLinkedModelsInfo.add({
                'modelId': id,
                'model': data['model'],
              });
            }
          }
        }
      }

      // Update all remaining linked models
      for (String id in allLinkedModelIds) {
        var doc = modelDocs[id];
        if (doc != null && doc.exists) {
          var modelData = doc.data() as Map<String, dynamic>?;
          if (modelData != null) {
            List<Map<String, dynamic>> modelParts =
                List<Map<String, dynamic>>.from(modelData['parts'] ?? []);

            int existingIndex = modelParts.indexWhere((p) =>
                p['partType'] == part['partType'] &&
                p['color'] == part['color']);

            if (existingIndex >= 0) {
              modelParts[existingIndex]['linkedModels'] =
                  updatedLinkedModelsInfo
                      .where((m) => m['modelId'] != id)
                      .toList();
            }

            await FirebaseFirestore.instance
                .collection('models')
                .doc(id)
                .update({'parts': modelParts});
          }
        }
      }

      // Remove the part from the unlinked model
      DocumentSnapshot unlinkModelDoc = await FirebaseFirestore.instance
          .collection('models')
          .doc(modelInfo['modelId'])
          .get();

      if (unlinkModelDoc.exists) {
        var unlinkModelData = unlinkModelDoc.data() as Map<String, dynamic>?;
        if (unlinkModelData != null) {
          List<Map<String, dynamic>> modelParts =
              List<Map<String, dynamic>>.from(unlinkModelData['parts'] ?? []);

          modelParts.removeWhere((p) =>
              p['partType'] == part['partType'] && p['color'] == part['color']);

          await FirebaseFirestore.instance
              .collection('models')
              .doc(modelInfo['modelId'])
              .update({'parts': modelParts});
        }
      }

      // Update local state
      setState(() {
        part['linkedModels'] = updatedLinkedModelsInfo
            .where((m) => m['modelId'] != widget.modelId)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unlinking models: $e')),
        );
      }
    }
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
        'linkedModels': [], // Initialize empty linkedModels array for new parts
      });
    });
    _saveParts();
  }

  Future<void> _saveParts() async {
    try {
      // Update current model
      await FirebaseFirestore.instance
          .collection('models')
          .doc(widget.modelId)
          .update({
        'parts': parts,
      });

      // Update all linked models
      for (var part in parts) {
        if (part['linkedModels'] != null) {
          for (var linkedModel in (part['linkedModels'] as List)) {
            String modelId = linkedModel['modelId'];

            // Skip if it's the current model
            if (modelId == widget.modelId) continue;

            // Get the linked model's current data
            DocumentSnapshot linkedModelDoc = await FirebaseFirestore.instance
                .collection('models')
                .doc(modelId)
                .get();

            if (linkedModelDoc.exists) {
              final linkedModelData =
                  linkedModelDoc.data() as Map<String, dynamic>?;
              if (linkedModelData != null) {
                List<Map<String, dynamic>> linkedParts =
                    List<Map<String, dynamic>>.from(
                        linkedModelData['parts'] ?? []);

                // Find matching part in linked model
                int existingIndex = linkedParts.indexWhere((p) =>
                    p['partType'] == part['partType'] &&
                    p['color'] == part['color']);

                // Create updated part data
                Map<String, dynamic> updatedPart = {
                  'partType': part['partType'],
                  'color': part['color'],
                  'price': part['price'],
                  'quantity': part['quantity'],
                  'threshold': part['threshold'],
                  'linkedModels': [
                    {
                      'modelId': widget.modelId,
                      'model': linkedModelData['model'],
                    }
                  ],
                };

                // Update existing part or add new one
                if (existingIndex >= 0) {
                  linkedParts[existingIndex] = updatedPart;
                } else {
                  linkedParts.add(updatedPart);
                }

                // Update the linked model
                await FirebaseFirestore.instance
                    .collection('models')
                    .doc(modelId)
                    .update({'parts': linkedParts});
              }
            }
          }
        }
      }

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
}
