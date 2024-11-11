import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phonefixer_shop/model_parts_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _searchQuery = '';
  String _selectedBrand = 'All Brands';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  List<QueryDocumentSnapshot> _models = [];
  DocumentSnapshot? _lastDocument;
  bool _isSearching = false;

  final List<String> _brands = [
    'All Brands',
    'Samsung',
    'Vivo',
    'Oppo',
    'Realme',
    'Mi',
    'OnePlus',
    'iPhone',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Query _createQuery() {
    Query query = FirebaseFirestore.instance.collection('models');

    if (_selectedBrand != 'All Brands') {
      query = query.where('brand', isEqualTo: _selectedBrand);
    }

    return query;
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingMore = true;
      _models = [];
      _lastDocument = null;
    });

    try {
      final QuerySnapshot snapshot =
          await _createQuery().limit(_pageSize).get();

      setState(() {
        _models = snapshot.docs;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      print('Error loading initial data: $e');
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData || _isSearching) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final QuerySnapshot snapshot = await _createQuery()
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      setState(() {
        _models.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMoreData = snapshot.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      print('Error loading more data: $e');
    }
  }

  Future<List<QueryDocumentSnapshot>> _searchModels(String query) async {
    Query searchQuery = FirebaseFirestore.instance.collection('models');

    if (_selectedBrand != 'All Brands') {
      searchQuery = searchQuery.where('brand', isEqualTo: _selectedBrand);
    }

    final QuerySnapshot snapshot = await searchQuery.get();
    return snapshot.docs.where((doc) {
      final modelData = doc.data() as Map<String, dynamic>;
      final brand = (modelData['brand'] ?? '').toString().toLowerCase();
      final modelName = (modelData['model'] ?? '').toString().toLowerCase();

      return modelName.contains(query.toLowerCase()) ||
          brand.contains(query.toLowerCase());
    }).toList();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  void _onSearchChanged(String value) async {
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });

    if (value.isNotEmpty) {
      final searchResults = await _searchModels(value);
      setState(() {
        _models = searchResults;
        _hasMoreData = false;
      });
    } else {
      _refreshData();
    }
  }

  void _refreshData() {
    setState(() {
      _models = [];
      _lastDocument = null;
      _hasMoreData = true;
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadInitialData();
  }

  void _onBrandChanged(String? value) {
    setState(() {
      _selectedBrand = value!;
      _models = [];
      _lastDocument = null;
      _hasMoreData = true;
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhoneFixer'),
      ),
      body: Column(
        children: [
          _buildSearchAndFilterRow(),
          Expanded(
            child: _buildModelsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by Model or Brand',
                  labelStyle: const TextStyle(fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _onSearchChanged('');
                          },
                        )
                      : const Icon(Icons.search, color: Colors.grey),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 130,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedBrand,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              items: _brands.map((brand) {
                return DropdownMenuItem<String>(
                  value: brand,
                  child: Text(
                    brand,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: _onBrandChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelsList() {
    if (_models.isEmpty && !_isLoadingMore) {
      return const Center(
        child: Text(
          'No models found. Please adjust your search.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _refreshData();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _models.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _models.length) {
            return _buildLoadingIndicator();
          }
          return _buildModelCard(_models[index]);
        },
      ),
    );
  }

  // ... rest of the code remains the same (_buildLoadingIndicator, _buildModelCard, _showDeleteConfirmationDialog)

  Widget _buildLoadingIndicator() {
    return _isLoadingMore
        ? const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          )
        : const SizedBox();
  }

  Widget _buildModelCard(QueryDocumentSnapshot model) {
    final modelData = model.data() as Map<String, dynamic>;
    final brand = (modelData['brand'] ?? '').toString();
    final modelName = (modelData['model'] ?? '').toString();
    final parts = List.from(modelData['parts'] ?? []);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
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
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            ...parts.map<Widget>((part) {
              final quantity = (part['quantity'] ?? 0) as int;
              final threshold = (part['threshold'] ?? 0) as int;
              final partColor = (part['color'] ?? '').toString();
              final partType = (part['partType'] ?? '').toString();
              final price = (part['price'] ?? 0.0).toDouble();
              final isThresholdExceeded = quantity < threshold;

              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$partType',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (partColor.isNotEmpty)
                          Text(
                            'Color: $partColor',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blueGrey),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                isThresholdExceeded ? Colors.red : Colors.black,
                          ),
                        ),
                        Text(
                          'Qty: $quantity',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isThresholdExceeded ? Colors.red : Colors.green,
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
                modelId: model.id,
                brand: brand,
                modelName: model['model'], // Pass the actual model name
              ),
            ),
          );
        },
        onLongPress: () {
          _showDeleteConfirmationDialog(context, model);
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('models')
                    .doc(model.id)
                    .delete()
                    .then((_) => Navigator.pop(context))
                    .catchError((error) => print("Failed to delete: $error"));
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
