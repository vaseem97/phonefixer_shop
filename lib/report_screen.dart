import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:phonefixer_shop/customer_details.dart';

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
    final parts = saleData['parts'] as List;
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: Icon(Icons.receipt_long, color: theme.colorScheme.primary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First Row: Customer Name and Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Customer Name Section with Icon
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerDetailsScreen(
                            customerId: saleData['customerId'],
                            customerName: saleData['customerName'],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(Icons.person,
                            size: 16, color: theme.colorScheme.secondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            saleData['customerName'],
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Total Amount
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '₹${saleData['totalPrice'].toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Second Row: Date and Payment Method
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Date
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: theme.colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, y')
                          .format((saleData['date'] as Timestamp).toDate()),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                // Payment Method
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPaymentIcon(saleData['paymentMethod']),
                        size: 14,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        saleData['paymentMethod'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Parts Summary
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var part in parts.take(2))
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Icon(Icons.build_circle,
                              size: 14, color: theme.colorScheme.secondary),
                          const SizedBox(width: 8),
                          // Part Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  part['partType'],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Model: ${part['model'] ?? 'N/A'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Price Details
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${part['quantity']}x ₹${part['price'].toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              Text(
                                '₹${(part['quantity'] * part['price']).toStringAsFixed(2)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (parts.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(left: 30, bottom: 8),
                      child: Text(
                        '+ ${parts.length - 2} more items',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        // Expanded Content
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment Details for Partial Payment
                if (saleData['paymentMethod'] == 'Partial Payment')
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        _buildPaymentRow(
                          'Paid Amount:',
                          '₹${saleData['partialPaymentAmount'].toStringAsFixed(2)}',
                          theme,
                        ),
                        const SizedBox(height: 4),
                        _buildPaymentRow(
                          'Remaining:',
                          '₹${(saleData['totalPrice'] - saleData['partialPaymentAmount']).toStringAsFixed(2)}',
                          theme,
                          isError: true,
                        ),
                      ],
                    ),
                  ),

                // Historical Balance
                if (saleData['paymentMethod'] == 'Udhaar' ||
                    saleData['paymentMethod'] == 'Partial Payment') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        _buildPaymentRow(
                          'Previous Balance:',
                          '₹${(saleData['balanceAtSale'] ?? 0.0).toStringAsFixed(2)}',
                          theme,
                          isError: (saleData['balanceAtSale'] ?? 0.0) > 0,
                        ),
                        const SizedBox(height: 4),
                        _buildPaymentRow(
                          'New Balance:',
                          '₹${((saleData['balanceAtSale'] ?? 0.0) + (saleData['paymentMethod'] == 'Udhaar' ? saleData['totalPrice'] : (saleData['totalPrice'] - (saleData['partialPaymentAmount'] ?? 0.0)))).toStringAsFixed(2)}',
                          theme,
                          isError: true,
                        ),
                      ],
                    ),
                  ),
                ],

                // All Parts Details
                const SizedBox(height: 16),
                Text(
                  'Parts Details',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: parts.length,
                  itemBuilder: (context, index) {
                    final part = parts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    part['partType'],
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Model: ${part['model'] ?? 'N/A'}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (part['color'] != null)
                                    Text(
                                      'Color: ${part['color']}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${part['quantity']} x ₹${part['price'].toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  '₹${(part['quantity'] * part['price']).toStringAsFixed(2)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Helper method for payment rows
  Widget _buildPaymentRow(String label, String amount, ThemeData theme,
      {bool isError = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          amount,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: isError ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }

// Payment icon helper method remains the same
  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod) {
      case 'Cash':
        return Icons.payments;
      case 'UPI':
        return Icons.phone_android;
      case 'Card':
        return Icons.credit_card;
      case 'Udhaar':
        return Icons.access_time;
      case 'Partial Payment':
        return Icons.pending;
      default:
        return Icons.payment;
    }
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
