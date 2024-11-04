import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phonefixer_shop/customer_add.dart';

class CustomerSelectionDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Customer'),
      content: Container(
        width: double.maxFinite,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('customers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return CircularProgressIndicator();

                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final customer = Customer(
                        id: doc.id,
                        name: data['name'] as String? ?? 'Unknown',
                        phone: data['phone'] as String? ?? 'N/A',
                        balance: data['balance'],
                      );
                      return ListTile(
                        title: Text(customer.name),
                        subtitle: Text(customer.phone),
                        onTap: () => Navigator.of(context).pop(customer),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Navigate to the AddCustomerScreen
                final newCustomer = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddCustomerScreen()),
                );

                // If a new customer is added, close the dialog and return the new customer
                if (newCustomer != null) {
                  Navigator.of(context).pop(newCustomer);
                }
              },
              child: Text('Add New Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
