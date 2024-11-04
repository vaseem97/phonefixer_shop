import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({Key? key}) : super(key: key);

  @override
  _SalesListScreenState createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  late Stream<QuerySnapshot> _salesStream;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCustomerId;
  List<Map<String, dynamic>> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _initSalesStream();
  }

  void _loadCustomers() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('customers').get();
    setState(() {
      _customers = snapshot.docs
          .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
          .toList();
    });
  }

  void _initSalesStream() {
    _salesStream = FirebaseFirestore.instance
        .collection('sales')
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots();
  }

  void _applyFilters() {
    Query query = FirebaseFirestore.instance.collection('sales');

    if (_startDate != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!));
    }

    if (_endDate != null) {
      query = query.where('date',
          isLessThanOrEqualTo:
              Timestamp.fromDate(_endDate!.add(Duration(days: 1))));
    }

    if (_selectedCustomerId != null) {
      query = query.where('customerId', isEqualTo: _selectedCustomerId);
    }

    setState(() {
      _salesStream =
          query.orderBy('date', descending: true).limit(50).snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _salesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No sales found'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var sale = snapshot.data!.docs[index];
                    return _buildSaleCard(sale);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to SalesScreen for creating a new sale
          Navigator.pushNamed(context, '/new-sale');
        },
        child: const Icon(Icons.add),
        tooltip: 'New Sale',
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0,
        children: [
          if (_startDate != null)
            Chip(
              label:
                  Text('From: ${DateFormat('MMM d, y').format(_startDate!)}'),
              onDeleted: () {
                setState(() {
                  _startDate = null;
                  _applyFilters();
                });
              },
            ),
          if (_endDate != null)
            Chip(
              label: Text('To: ${DateFormat('MMM d, y').format(_endDate!)}'),
              onDeleted: () {
                setState(() {
                  _endDate = null;
                  _applyFilters();
                });
              },
            ),
          if (_selectedCustomerId != null)
            Chip(
              label: Text(
                  'Customer: ${_customers.firstWhere((c) => c['id'] == _selectedCustomerId)['name']}'),
              onDeleted: () {
                setState(() {
                  _selectedCustomerId = null;
                  _applyFilters();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(DocumentSnapshot sale) {
    var saleData = sale.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text('Sale #${sale.id.substring(0, 8)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${saleData['customerName']}'),
            Text(
                'Date: ${DateFormat('MMM d, y HH:mm').format((saleData['date'] as Timestamp).toDate())}'),
            Text('Total: ₹${saleData['totalPrice'].toStringAsFixed(2)}'),
          ],
        ),
        trailing: Chip(
          label: Text(saleData['paymentMethod']),
          backgroundColor: _getPaymentMethodColor(saleData['paymentMethod']),
        ),
        onTap: () => _showSaleDetails(sale),
      ),
    );
  }

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

  void _showSaleDetails(DocumentSnapshot sale) {
    var saleData = sale.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sale Details #${sale.id.substring(0, 8)}'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Customer: ${saleData['customerName']}'),
                Text(
                    'Date: ${DateFormat('MMM d, y HH:mm').format((saleData['date'] as Timestamp).toDate())}'),
                Text('Total: ₹${saleData['totalPrice'].toStringAsFixed(2)}'),
                Text('Payment Method: ${saleData['paymentMethod']}'),
                if (saleData['paymentMethod'] == 'Partial Payment')
                  Text(
                      'Partial Payment: ₹${saleData['partialPaymentAmount'].toStringAsFixed(2)}'),
                const Divider(),
                const Text('Parts:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...(saleData['parts'] as List).map((part) {
                  return ListTile(
                    title: Text(part['partType']),
                    subtitle: Text(
                        '${part['quantity']} x ₹${part['price'].toStringAsFixed(2)}'),
                    trailing: Text(
                        '₹${(part['quantity'] * part['price']).toStringAsFixed(2)}'),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Filter Sales'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: [
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(_startDate == null
                          ? 'Not set'
                          : DateFormat('MMM d, y').format(_startDate!)),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(_endDate == null
                          ? 'Not set'
                          : DateFormat('MMM d, y').format(_endDate!)),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _endDate = picked);
                        }
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedCustomerId,
                      decoration: const InputDecoration(labelText: 'Customer'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Customers'),
                        ),
                        ..._customers.map((customer) {
                          return DropdownMenuItem<String>(
                            value: customer['id'],
                            child: Text(customer['name']),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCustomerId = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Clear'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _selectedCustomerId = null;
                    });
                    _applyFilters();
                  },
                ),
                TextButton(
                  child: const Text('Apply'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _applyFilters();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
