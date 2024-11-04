import 'package:flutter/material.dart';

class AddCustomerScreen extends StatefulWidget {
  @override
  _AddCustomerScreenState createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  double _balance = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Customer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Balance'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _balance = double.tryParse(value) ?? 0.0;
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveCustomer,
              child: Text('Save Customer'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomer() {
    final String name = _nameController.text;
    final String phone = _phoneController.text;

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // You can replace this part with saving to Firestore
    final newCustomer = Customer(
      id: UniqueKey().toString(), // Replace with actual ID from Firestore
      name: name,
      phone: phone,
      balance: _balance,
    );

    Navigator.pop(context, newCustomer); // Return the new customer
  }
}

// Assume this Customer class is defined in your model
class Customer {
  final String id;
  final String name;
  final String phone;
  final double balance;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
  });
}
