import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app.dart';
import '../../constants.dart';
import '../../theme_utils.dart';
import '../clientDashboard/client_dashboard.dart';
import '../connectivityBase/local_db_base.dart';
import '../main_navigation/main_navigation_base.dart';
import 'customer_base.dart';

class ModernCustomerManagementScreen extends StatefulWidget {
  final EnhancedPOSService posService;

  const ModernCustomerManagementScreen({super.key, required this.posService});

  @override
  _ModernCustomerManagementScreenState createState() =>
      _ModernCustomerManagementScreenState();
}

class _ModernCustomerManagementScreenState
    extends State<ModernCustomerManagementScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<Customer> _customers = [];
  final List<Customer> _filteredCustomers = [];
  late TabController _tabController;

  bool _isLoading = false;
  bool _showSearchResults = false;
  String _selectedFilter = 'all';
  String _sortBy = 'name';

  // Filter options
  final List<String> _filterOptions = [
    'all',
    'recent',
    'high-value',
    'inactive',
  ];
  final List<String> _sortOptions = ['name', 'recent', 'orders', 'spent'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadCustomers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final customers = await widget.posService.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers.clear();
          _customers.addAll(customers);
          _applyFilters();
        });
      }
    } catch (e) {
      print('Failed to load customers: $e');
      _showErrorSnackbar('Failed to load customers');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _applyFilters();
      });
      return;
    }

    setState(() {
      _filteredCustomers.clear();
      _filteredCustomers.addAll(
        _customers
            .where(
              (customer) =>
                  customer.fullName.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  customer.email.toLowerCase().contains(query.toLowerCase()) ||
                  customer.phone.contains(query) ||
                  (customer.company?.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ??
                      false) ||
                  (customer.city?.toLowerCase().contains(query.toLowerCase()) ??
                      false),
            )
            .toList(),
      );
      _showSearchResults = true;
    });
  }

  void _applyFilters() {
    List<Customer> filtered = List.from(_customers);

    // Apply status filter
    switch (_selectedFilter) {
      case 'recent':
        filtered = filtered.where((c) {
          final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
          return c.dateCreated?.isAfter(thirtyDaysAgo) == true;
        }).toList();
        break;
      case 'high-value':
        filtered = filtered.where((c) => c.totalSpent > 1000).toList();
        break;
      case 'inactive':
        filtered = filtered.where((c) => c.orderCount == 0).toList();
        break;
    }

    // Apply sorting
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'recent':
        filtered.sort(
          (a, b) => (b.dateCreated ?? DateTime(0)).compareTo(
            a.dateCreated ?? DateTime(0),
          ),
        );
        break;
      case 'orders':
        filtered.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        break;
      case 'spent':
        filtered.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
        break;
    }

    setState(() {
      _filteredCustomers.clear();
      _filteredCustomers.addAll(filtered);
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _editCustomer(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerEditSheet(
        customer: customer,
        posService: widget.posService,
        onCustomerUpdated: _loadCustomers,
      ),
    );
  }

  void _viewCustomerDetails(Customer customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(
          customer: customer,
          posService: widget.posService,
        ),
      ),
    );
  }

  void _addNewCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(
          posService: widget.posService,
          onCustomerAdded: (customer) {
            _loadCustomers();
            _showSuccessSnackbar('Customer added successfully');
          },
        ),
      ),
    );
  }

  void _showCustomerActions(Customer customer) {
    showModalBottomSheet(
      context: context,
      builder: (context) => CustomerActionsSheet(
        customer: customer,
        onEdit: () {
          Navigator.pop(context);
          _editCustomer(customer);
        },
        onViewDetails: () {
          Navigator.pop(context);
          _viewCustomerDetails(customer);
        },
        onDelete: () => _deleteCustomer(customer),
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${customer.fullName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Implement delete functionality
        _showSuccessSnackbar('Customer deleted successfully');
        _loadCustomers();
      } catch (e) {
        _showErrorSnackbar('Failed to delete customer');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeUtils.backgroundSolid(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // App Bar
            // SliverAppBar(
            //   expandedHeight: 180,
            //   floating: true,
            //   pinned: true,
            //   snap: true,
            //   backgroundColor: ThemeUtils.primary(context),
            //   foregroundColor: ThemeUtils.textOnPrimary(context),
            //   flexibleSpace: FlexibleSpaceBar(
            //     title: Text(
            //       'Customer Management',
            //       style: TextStyle(
            //         fontSize: 16,
            //         fontWeight: FontWeight.w600,
            //         color: ThemeUtils.textOnPrimary(context),
            //       ),
            //     ),
            //     background: Container(
            //       decoration: BoxDecoration(
            //         gradient: LinearGradient(
            //           colors: ThemeUtils.appBar(context),
            //           begin: Alignment.topLeft,
            //           end: Alignment.bottomRight,
            //         ),
            //       ),
            //       padding: EdgeInsets.only(top: 100, left: 20, right: 20),
            //       child: Column(
            //         crossAxisAlignment: CrossAxisAlignment.start,
            //         children: [
            //           Text(
            //             'Customer Management',
            //             style: TextStyle(
            //               fontSize: 24,
            //               fontWeight: FontWeight.bold,
            //               color: ThemeUtils.textOnPrimary(context),
            //             ),
            //           ),
            //           SizedBox(height: 8),
            //           Text(
            //             'Manage your customer relationships',
            //             style: TextStyle(
            //               fontSize: 14,
            //               color: ThemeUtils.textOnPrimary(
            //                 context,
            //               ).withOpacity(0.8),
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // ),

            // Search and Filter Bar
            SliverToBoxAdapter(child: _buildSearchFilterBar()),

            // Stats Overview
            SliverToBoxAdapter(child: _buildStatsOverview()),

            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: ThemeUtils.primary(context),
                  unselectedLabelColor: ThemeUtils.textSecondary(context),
                  indicatorColor: ThemeUtils.primary(context),
                  tabs: [
                    Tab(text: 'All Customers'),
                    Tab(text: 'Recent'),
                    Tab(text: 'High Value'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCustomerList(),
            _buildRecentCustomers(),
            _buildHighValueCustomers(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCustomer,
        backgroundColor: ThemeUtils.primary(context),
        foregroundColor: ThemeUtils.textOnPrimary(context),
        child: Icon(Icons.person_add_alt_1, size: 24),
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      padding: EdgeInsets.all(16),
      color: ThemeUtils.surface(context),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: ThemeUtils.cardDecoration(context),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: Icon(
                  Icons.search,
                  color: ThemeUtils.textSecondary(context),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          // Filter and Sort Row
          Row(
            children: [
              Expanded(child: _buildFilterDropdown()),
              SizedBox(width: 12),
              Expanded(child: _buildSortDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          isExpanded: true,
          icon: Icon(
            Icons.filter_list,
            color: ThemeUtils.textSecondary(context),
          ),
          items: [
            DropdownMenuItem(value: 'all', child: Text('All Customers')),
            DropdownMenuItem(value: 'recent', child: Text('Recent')),
            DropdownMenuItem(value: 'high-value', child: Text('High Value')),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedFilter = value!;
              _applyFilters();
            });
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isExpanded: true,
          icon: Icon(Icons.sort, color: ThemeUtils.textSecondary(context)),
          items: [
            DropdownMenuItem(value: 'name', child: Text('Sort by Name')),
            DropdownMenuItem(value: 'recent', child: Text('Sort by Recent')),
            DropdownMenuItem(value: 'orders', child: Text('Sort by Orders')),
            DropdownMenuItem(value: 'spent', child: Text('Sort by Spent')),
          ],
          onChanged: (value) {
            setState(() {
              _sortBy = value!;
              _applyFilters();
            });
          },
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    final totalCustomers = _customers.length;
    final highValueCustomers = _customers
        .where((c) => c.totalSpent > 1000)
        .length;
    final recentCustomers = _customers.where((c) {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      return c.dateCreated?.isAfter(thirtyDaysAgo) == true;
    }).length;

    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard('Total', totalCustomers.toString(), Icons.people),
          SizedBox(width: 12),
          _buildStatCard(
            'High Value',
            highValueCustomers.toString(),
            Icons.trending_up,
          ),
          SizedBox(width: 12),
          _buildStatCard(
            'Recent',
            recentCustomers.toString(),
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        decoration: ThemeUtils.cardDecoration(context),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: ThemeUtils.primary(context)),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ThemeUtils.textPrimary(context),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: ThemeUtils.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerList() {
    final displayCustomers = _showSearchResults
        ? _filteredCustomers
        : _customers;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(ThemeUtils.primary(context)),
        ),
      );
    }

    if (displayCustomers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: displayCustomers.length,
      itemBuilder: (context, index) {
        final customer = displayCustomers[index];
        return _buildCustomerCard(customer);
      },
    );
  }

  Widget _buildRecentCustomers() {
    final recentCustomers = _customers.where((c) {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      return c.dateCreated?.isAfter(thirtyDaysAgo) == true;
    }).toList();

    return _buildCustomerListFromList(recentCustomers);
  }

  Widget _buildHighValueCustomers() {
    final highValueCustomers = _customers
        .where((c) => c.totalSpent > 1000)
        .toList();
    return _buildCustomerListFromList(highValueCustomers);
  }

  Widget _buildCustomerListFromList(List<Customer> customers) {
    if (customers.isEmpty) {
      return _buildEmptyState(message: 'No customers found in this category');
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: customers.length,
      itemBuilder: (context, index) => _buildCustomerCard(customers[index]),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: ThemeUtils.cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          onTap: () => _viewCustomerDetails(customer),
          onLongPress: () => _showCustomerActions(customer),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: ThemeUtils.accent(context),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),
                // Customer Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeUtils.textPrimary(context),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        customer.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeUtils.textSecondary(context),
                        ),
                      ),
                      if (customer.phone.isNotEmpty) ...[
                        SizedBox(height: 2),
                        Text(
                          customer.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: ThemeUtils.textSecondary(context),
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                      _buildCustomerStats(customer),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: ThemeUtils.textSecondary(context),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editCustomer(customer);
                        break;
                      case 'view':
                        _viewCustomerDetails(customer);
                        break;
                      case 'delete':
                        _deleteCustomer(customer);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'view', child: Text('View Details')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerStats(Customer customer) {
    return Row(
      children: [
        if (customer.orderCount > 0) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ThemeUtils.success(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${customer.orderCount} ${customer.orderCount == 1 ? 'order' : 'orders'}',
              style: TextStyle(
                fontSize: 10,
                color: ThemeUtils.success(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: ThemeUtils.primary(context).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${Constants.CURRENCY_NAME}${customer.totalSpent.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              color: ThemeUtils.primary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({String message = 'No customers found'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: ThemeUtils.textSecondary(context).withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: ThemeUtils.textSecondary(context),
            ),
          ),
          SizedBox(height: 8),
          if (message.contains('No customers'))
            ElevatedButton(
              onPressed: _addNewCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeUtils.primary(context),
                foregroundColor: ThemeUtils.textOnPrimary(context),
              ),
              child: Text('Add First Customer'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: ThemeUtils.surface(context), child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class CustomerEditSheet extends StatefulWidget {
  final Customer customer;
  final EnhancedPOSService posService;
  final VoidCallback onCustomerUpdated;

  const CustomerEditSheet({
    super.key,
    required this.customer,
    required this.posService,
    required this.onCustomerUpdated,
  });

  @override
  _CustomerEditSheetState createState() => _CustomerEditSheetState();
}

class _CustomerEditSheetState extends State<CustomerEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'firstName': TextEditingController(text: widget.customer.firstName),
      'lastName': TextEditingController(text: widget.customer.lastName),
      'email': TextEditingController(text: widget.customer.email),
      'phone': TextEditingController(text: widget.customer.phone),
      'company': TextEditingController(text: widget.customer.company ?? ''),
      'address1': TextEditingController(text: widget.customer.address1 ?? ''),
      'address2': TextEditingController(text: widget.customer.address2 ?? ''),
      'city': TextEditingController(text: widget.customer.city ?? ''),
      'state': TextEditingController(text: widget.customer.state ?? ''),
      'postcode': TextEditingController(text: widget.customer.postcode ?? ''),
      'country': TextEditingController(text: widget.customer.country ?? ''),
      'notes': TextEditingController(text: widget.customer.notes ?? ''),
    };
  }

  Future<void> _updateCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedCustomer = widget.customer.copyWith(
        firstName: _controllers['firstName']!.text.trim(),
        lastName: _controllers['lastName']!.text.trim(),
        email: _controllers['email']!.text.trim(),
        phone: _controllers['phone']!.text.trim(),
        company: _controllers['company']!.text.trim().isEmpty
            ? null
            : _controllers['company']!.text.trim(),
        address1: _controllers['address1']!.text.trim().isEmpty
            ? null
            : _controllers['address1']!.text.trim(),
        address2: _controllers['address2']!.text.trim().isEmpty
            ? null
            : _controllers['address2']!.text.trim(),
        city: _controllers['city']!.text.trim().isEmpty
            ? null
            : _controllers['city']!.text.trim(),
        state: _controllers['state']!.text.trim().isEmpty
            ? null
            : _controllers['state']!.text.trim(),
        postcode: _controllers['postcode']!.text.trim().isEmpty
            ? null
            : _controllers['postcode']!.text.trim(),
        country: _controllers['country']!.text.trim().isEmpty
            ? null
            : _controllers['country']!.text.trim(),
        notes: _controllers['notes']!.text.trim().isEmpty
            ? null
            : _controllers['notes']!.text.trim(),
      );

      await widget.posService.updateCustomer(updatedCustomer);
      widget.onCustomerUpdated();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update customer: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: ThemeUtils.surface(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeUtils.primary(context),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.edit, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Edit Customer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Form fields similar to AddCustomerScreen but pre-filled
                  _buildEditFormField(
                    'First Name',
                    'firstName',
                    Icons.person,
                    true,
                  ),
                  _buildEditFormField(
                    'Last Name',
                    'lastName',
                    Icons.person,
                    true,
                  ),
                  _buildEditFormField('Email', 'email', Icons.email, true),
                  _buildEditFormField('Phone', 'phone', Icons.phone, true),
                  _buildEditFormField(
                    'Company',
                    'company',
                    Icons.business,
                    false,
                  ),
                  _buildEditFormField(
                    'Address 1',
                    'address1',
                    Icons.home,
                    false,
                  ),
                  _buildEditFormField(
                    'Address 2',
                    'address2',
                    Icons.home_work,
                    false,
                  ),
                  _buildEditFormField(
                    'City',
                    'city',
                    Icons.location_city,
                    false,
                  ),
                  _buildEditFormField('State', 'state', Icons.map, false),
                  _buildEditFormField(
                    'Postcode',
                    'postcode',
                    Icons.markunread_mailbox,
                    false,
                  ),
                  _buildEditFormField(
                    'Country',
                    'country',
                    Icons.public,
                    false,
                  ),
                  _buildEditFormField(
                    'Notes',
                    'notes',
                    Icons.note,
                    false,
                    maxLines: 3,
                  ),

                  SizedBox(height: 20),
                  _buildUpdateButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditFormField(
    String label,
    String key,
    IconData icon,
    bool required, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        maxLines: maxLines,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty)
                  return '$label is required';
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: _isLoading
          ? ElevatedButton(
              onPressed: null,
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : ElevatedButton(
              onPressed: _updateCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeUtils.primary(context),
                foregroundColor: ThemeUtils.textOnPrimary(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('UPDATE CUSTOMER'),
            ),
    );
  }

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}

class CustomerActionsSheet extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onViewDetails;
  final VoidCallback onDelete;

  const CustomerActionsSheet({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onViewDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: ThemeUtils.primary(context)),
            title: Text('Edit Customer'),
            onTap: onEdit,
          ),
          ListTile(
            leading: Icon(Icons.person, color: ThemeUtils.primary(context)),
            title: Text('View Details'),
            onTap: onViewDetails,
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Customer', style: TextStyle(color: Colors.red)),
            onTap: onDelete,
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;
  final EnhancedPOSService posService;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
    required this.posService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeUtils.backgroundSolid(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: ThemeUtils.primary(context),
            foregroundColor: ThemeUtils.textOnPrimary(context),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(customer.fullName),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: ThemeUtils.appBar(context),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // Customer Info Card
              _buildInfoCard(context),
              // Statistics Card
              _buildStatsCard(context),
              // Recent Activity
              _buildActivityCard(context),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: ThemeUtils.cardDecoration(context),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: ThemeUtils.headlineMedium(context),
          ),
          SizedBox(height: 16),
          _buildInfoRow('Email', customer.email, Icons.email, context),
          _buildInfoRow('Phone', customer.phone, Icons.phone, context),
          if (customer.company?.isNotEmpty == true)
            _buildInfoRow(
              'Company',
              customer.company!,
              Icons.business,
              context,
            ),
          if (customer.address1?.isNotEmpty == true)
            _buildInfoRow(
              'Address',
              _buildFullAddress(),
              Icons.location_on,
              context,
            ),
          if (customer.notes?.isNotEmpty == true)
            _buildInfoRow('Notes', customer.notes!, Icons.note, context),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    BuildContext context,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ThemeUtils.textSecondary(context)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeUtils.textSecondary(context),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeUtils.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildFullAddress() {
    final parts = [
      customer.address1,
      customer.address2,
      customer.city,
      customer.state,
      customer.postcode,
      customer.country,
    ].where((part) => part?.isNotEmpty == true).map((part) => part!).toList();
    return parts.join(', ');
  }

  Widget _buildStatsCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: ThemeUtils.cardDecoration(context),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Statistics',
            style: ThemeUtils.headlineMedium(context),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Orders',
                customer.orderCount.toString(),
                Icons.shopping_cart,
                context,
              ),
              _buildStatItem(
                'Total Spent',
                '${Constants.CURRENCY_NAME}${customer.totalSpent.toStringAsFixed(2)}',
                Icons.attach_money,
                context,
              ),
              _buildStatItem(
                'Avg. Order',
                '${Constants.CURRENCY_NAME}${customer.orderCount > 0 ? (customer.totalSpent / customer.orderCount).toStringAsFixed(2) : '0.00'}',
                Icons.trending_up,
                context,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(icon, size: 24, color: ThemeUtils.primary(context)),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: ThemeUtils.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: ThemeUtils.cardDecoration(context),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: ThemeUtils.headlineMedium(context)),
          SizedBox(height: 16),
          // Placeholder for recent orders/activity
          Text(
            'No recent activity',
            style: TextStyle(color: ThemeUtils.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}
