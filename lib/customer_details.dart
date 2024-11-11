import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerDetailsScreen extends StatelessWidget {
  final String customerId;
  final String customerName;

  const CustomerDetailsScreen({
    Key? key,
    required this.customerId,
    required this.customerName,
  }) : super(key: key);

  Color _getPaymentMethodColor(String paymentMethod) {
    switch (paymentMethod) {
      case 'Cash':
        return Colors.green.shade100;
      case 'Udhaar':
        return Colors.red.shade100;
      case 'Partial Payment':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug print to verify customerId
    print('Loading customer details for ID: $customerId');

    return Scaffold(
      appBar: AppBar(
        title: Text('$customerName Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info Card
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final customerData =
                      snapshot.data!.data() as Map<String, dynamic>? ?? {};

                  return Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customer Information',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Chip(
                                label: Text(
                                  '₹${(customerData['balance'] ?? 0.0).toStringAsFixed(2)}',
                                ),
                                backgroundColor:
                                    (customerData['balance'] ?? 0.0) > 0
                                        ? Colors.red.shade100
                                        : Colors.green.shade100,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Name: ${customerData['name'] ?? 'N/A'}'),
                          Text('Phone: ${customerData['phone'] ?? 'N/A'}'),
                          Text('Address: ${customerData['address'] ?? 'N/A'}'),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Sales History
              Text(
                'Purchase History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sales')
                    .where('customerId', isEqualTo: customerId)
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Debug print to check query results
                  print(
                      'Sales snapshot: ${snapshot.hasData ? snapshot.data!.docs.length : 'no data'} documents');

                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                            'Error loading purchase history: ${snapshot.error}'),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final sales = snapshot.data!.docs;

                  if (sales.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No purchase history found'),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index].data() as Map<String, dynamic>;
                      final date = (sale['date'] as Timestamp).toDate();

                      // Safely access the parts list
                      final List<dynamic> rawParts = sale['parts'] ?? [];
                      final parts = List<Map<String, dynamic>>.from(rawParts);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ExpansionTile(
                          title: Text(
                            'Purchase on ${DateFormat('MMM dd, yyyy').format(date)}',
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                'Total: ₹${(sale['totalPrice'] ?? 0.0).toStringAsFixed(2)}',
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(sale['paymentMethod'] ?? 'Unknown'),
                                backgroundColor: _getPaymentMethodColor(
                                  sale['paymentMethod'] ?? '',
                                ),
                                labelStyle: const TextStyle(fontSize: 12),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Parts Purchased:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  ...parts.map((part) {
                                    final double price =
                                        (part['price'] ?? 0.0).toDouble();
                                    final int quantity =
                                        (part['quantity'] ?? 0) as int;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${part['partType']}${part['color'] != null ? ' (${part['color']})' : ''}',
                                            ),
                                          ),
                                          Text(
                                            '$quantity x ₹${price.toStringAsFixed(2)} = ₹${(quantity * price).toStringAsFixed(2)}',
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  const Divider(),
                                  if (sale['paymentMethod'] ==
                                      'Partial Payment') ...[
                                    Text(
                                      'Partial Payment: ₹${(sale['partialPaymentAmount'] ?? 0.0).toStringAsFixed(2)}',
                                    ),
                                    Text(
                                      'Remaining: ₹${((sale['totalPrice'] ?? 0.0) - (sale['partialPaymentAmount'] ?? 0.0)).toStringAsFixed(2)}',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
