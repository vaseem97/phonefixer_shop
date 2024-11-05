import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ModelPartsLinking {
  Future<void> linkPartToModel(
    BuildContext context,
    Map<String, dynamic> part,
    Map<String, dynamic> modelData,
    String modelId,
    String currentModelId,
    VoidCallback setState, // Changed Function to VoidCallback
  ) async {
    try {
      Set<String> allLinkedModelIds = {currentModelId};
      List<Map<String, dynamic>> allLinkedModelsInfo = [];

      if (part['linkedModels'] != null) {
        for (var linked in (part['linkedModels'] as List)) {
          allLinkedModelIds.add(linked['modelId']);
          allLinkedModelsInfo.add(Map<String, dynamic>.from(linked));
        }
      }

      allLinkedModelIds.add(modelId);

      Map<String, DocumentSnapshot> modelDocs = {};
      for (String id in allLinkedModelIds) {
        DocumentSnapshot doc =
            await FirebaseFirestore.instance.collection('models').doc(id).get();
        modelDocs[id] = doc;
      }

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

            Map<String, dynamic> updatedPart = {
              'partType': part['partType'],
              'color': part['color'],
              'price': part['price'],
              'quantity': part['quantity'],
              'threshold': part['threshold'],
              'linkedModels':
                  allLinkedModelsInfo.where((m) => m['modelId'] != id).toList(),
            };

            if (existingIndex >= 0) {
              modelParts[existingIndex] = updatedPart;
            } else {
              modelParts.add(updatedPart);
            }

            await FirebaseFirestore.instance
                .collection('models')
                .doc(id)
                .update({'parts': modelParts});
          }
        }
      }

      setState(); // Call setState directly
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating linked models: $e')),
      );
    }
  }

  Future<void> unlinkModel(
    BuildContext context,
    Map<String, dynamic> part,
    Map<String, dynamic> modelInfo,
    String currentModelId,
    VoidCallback setState,
  ) async {
    try {
      Set<String> allLinkedModelIds = {};
      for (var linked in (part['linkedModels'] as List)) {
        allLinkedModelIds.add(linked['modelId']);
      }

      allLinkedModelIds.remove(modelInfo['modelId']);
      allLinkedModelIds.add(currentModelId);

      Map<String, DocumentSnapshot> modelDocs = {};
      for (String id in allLinkedModelIds) {
        DocumentSnapshot doc =
            await FirebaseFirestore.instance.collection('models').doc(id).get();
        modelDocs[id] = doc;
      }

      List<Map<String, dynamic>> updatedLinkedModelsInfo = [];
      for (String id in allLinkedModelIds) {
        if (id != modelInfo['modelId']) {
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

      setState(); // Call setState directly
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unlinking models: $e')),
      );
    }
  }

  Future<void> savePartsToFirestore(
    BuildContext context,
    String currentModelId,
    List<Map<String, dynamic>> parts,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('models')
          .doc(currentModelId)
          .update({
        'parts': parts,
      });

      for (var part in parts) {
        if (part['linkedModels'] != null) {
          for (var linkedModel in (part['linkedModels'] as List)) {
            String modelId = linkedModel['modelId'];

            if (modelId == currentModelId) continue;

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

                int existingIndex = linkedParts.indexWhere((p) =>
                    p['partType'] == part['partType'] &&
                    p['color'] == part['color']);

                Map<String, dynamic> updatedPart = {
                  'partType': part['partType'],
                  'color': part['color'],
                  'price': part['price'],
                  'quantity': part['quantity'],
                  'threshold': part['threshold'],
                  'linkedModels': [
                    {
                      'modelId': currentModelId,
                      'model': linkedModelData['model'],
                    }
                  ],
                };

                if (existingIndex >= 0) {
                  linkedParts[existingIndex] = updatedPart;
                } else {
                  linkedParts.add(updatedPart);
                }

                await FirebaseFirestore.instance
                    .collection('models')
                    .doc(modelId)
                    .update({'parts': linkedParts});
              }
            }
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to save parts: $e');
    }
  }
}
