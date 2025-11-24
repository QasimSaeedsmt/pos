import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// import '../../app.dart';
import '../../app.dart';
import '../../constants.dart';
import '../clientDashboard/client_dashboard.dart';
import '../connectivityBase/local_db_base.dart';
import '../main_navigation/main_navigation_base.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? company;
  final String? address1;
  final String? address2;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final int orderCount;
  final double totalSpent;
  final String? notes;
  final Map<String, dynamic> metaData;

  // Enhanced Credit Fields
  final double creditLimit;
  final double currentBalance;
  final double totalCreditGiven;
  final double totalCreditPaid;
  final DateTime? lastCreditDate;
  final DateTime? lastPaymentDate;
  final Map<String, dynamic> creditTerms;
  final double overdueAmount;
  final int overdueCount;

  Customer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.postcode,
    this.country,
    this.dateCreated,
    this.dateModified,
    this.orderCount = 0,
    this.totalSpent = 0.0,
    this.notes,
    this.metaData = const {},
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
    this.totalCreditGiven = 0.0,
    this.totalCreditPaid = 0.0,
    this.lastCreditDate,
    this.lastPaymentDate,
    this.creditTerms = const {},
    this.overdueAmount = 0.0,
    this.overdueCount = 0,
  });

  String get fullName => '$firstName $lastName';
  String get displayName =>
      company?.isNotEmpty == true ? '$fullName ($company)' : fullName;

  // Enhanced credit helper methods
  bool get hasCreditLimit => creditLimit > 0;
  bool get isOverLimit => currentBalance > creditLimit;
  double get availableCredit => creditLimit - currentBalance;
  double get creditUtilization => creditLimit > 0 ? (currentBalance / creditLimit) * 100 : 0;
  bool get hasOverdue => overdueAmount > 0;
  bool get canMakeCreditSale => hasCreditLimit ? !isOverLimit : true;

  factory Customer.fromFirestore(Map<String, dynamic> data, String id) {
    return Customer(
      id: id,
      firstName: data['firstName']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      company: data['company']?.toString(),
      address1: data['address1']?.toString(),
      address2: data['address2']?.toString(),
      city: data['city']?.toString(),
      state: data['state']?.toString(),
      postcode: data['postcode']?.toString(),
      country: data['country']?.toString(),
      dateCreated: data['dateCreated'] is Timestamp
          ? (data['dateCreated'] as Timestamp).toDate()
          : data['dateCreated'] is String
          ? DateTime.tryParse(data['dateCreated'])
          : null,
      dateModified: data['dateModified'] is Timestamp
          ? (data['dateModified'] as Timestamp).toDate()
          : data['dateModified'] is String
          ? DateTime.tryParse(data['dateModified'])
          : null,
      orderCount: (data['orderCount'] as num?)?.toInt() ?? 0,
      totalSpent: (data['totalSpent'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes']?.toString(),
      metaData: data['metaData'] is Map
          ? Map<String, dynamic>.from(data['metaData'])
          : {},
      creditLimit: (data['creditLimit'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (data['currentBalance'] as num?)?.toDouble() ?? 0.0,
      totalCreditGiven: (data['totalCreditGiven'] as num?)?.toDouble() ?? 0.0,
      totalCreditPaid: (data['totalCreditPaid'] as num?)?.toDouble() ?? 0.0,
      lastCreditDate: data['lastCreditDate'] is Timestamp
          ? (data['lastCreditDate'] as Timestamp).toDate()
          : data['lastCreditDate'] is String
          ? DateTime.tryParse(data['lastCreditDate'])
          : null,
      lastPaymentDate: data['lastPaymentDate'] is Timestamp
          ? (data['lastPaymentDate'] as Timestamp).toDate()
          : data['lastPaymentDate'] is String
          ? DateTime.tryParse(data['lastPaymentDate'])
          : null,
      creditTerms: data['creditTerms'] is Map
          ? Map<String, dynamic>.from(data['creditTerms'])
          : {},
      overdueAmount: (data['overdueAmount'] as num?)?.toDouble() ?? 0.0,
      overdueCount: (data['overdueCount'] as num?)?.toInt() ?? 0,
    );
  }

  // Enhanced copyWith method for credit operations
  Customer copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postcode,
    String? country,
    String? notes,
    double? creditLimit,
    double? currentBalance,
    double? totalCreditGiven,
    double? totalCreditPaid,
    DateTime? lastCreditDate,
    DateTime? lastPaymentDate,
    Map<String, dynamic>? creditTerms,
    double? overdueAmount,
    int? overdueCount,
  }) {
    return Customer(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      postcode: postcode ?? this.postcode,
      country: country ?? this.country,
      dateCreated: dateCreated,
      dateModified: DateTime.now(),
      orderCount: orderCount,
      totalSpent: totalSpent,
      notes: notes ?? this.notes,
      metaData: metaData,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      totalCreditGiven: totalCreditGiven ?? this.totalCreditGiven,
      totalCreditPaid: totalCreditPaid ?? this.totalCreditPaid,
      lastCreditDate: lastCreditDate ?? this.lastCreditDate,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      creditTerms: creditTerms ?? this.creditTerms,
      overdueAmount: overdueAmount ?? this.overdueAmount,
      overdueCount: overdueCount ?? this.overdueCount,
    );
  }

  // Specific credit copy method
  Customer copyWithCredit({
    double? creditLimit,
    double? currentBalance,
    double? totalCreditGiven,
    double? totalCreditPaid,
    DateTime? lastCreditDate,
    DateTime? lastPaymentDate,
    Map<String, dynamic>? creditTerms,
    double? overdueAmount,
    int? overdueCount,
  }) {
    return copyWith(
      creditLimit: creditLimit,
      currentBalance: currentBalance,
      totalCreditGiven: totalCreditGiven,
      totalCreditPaid: totalCreditPaid,
      lastCreditDate: lastCreditDate,
      lastPaymentDate: lastPaymentDate,
      creditTerms: creditTerms,
      overdueAmount: overdueAmount,
      overdueCount: overdueCount,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'company': company,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
      'dateCreated': dateCreated?.toIso8601String(),
      'dateModified': dateModified?.toIso8601String(),
      'orderCount': orderCount,
      'totalSpent': totalSpent,
      'notes': notes,
      'metaData': metaData,
      'searchKeywords': _generateSearchKeywords(),
      // Credit fields
      'creditLimit': creditLimit,
      'currentBalance': currentBalance,
      'totalCreditGiven': totalCreditGiven,
      'totalCreditPaid': totalCreditPaid,
      'lastCreditDate': lastCreditDate?.toIso8601String(),
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      'creditTerms': creditTerms,
      'overdueAmount': overdueAmount,
      'overdueCount': overdueCount,
    };
  }

  List<String> _generateSearchKeywords() {
    final keywords = <String>[];
    keywords.addAll(fullName.toLowerCase().split(' '));
    keywords.addAll(email.toLowerCase().split('@'));
    keywords.add(phone);
    if (company != null) {
      keywords.addAll(company!.toLowerCase().split(' '));
    }
    return keywords.where((k) => k.length > 1).toSet().toList();
  }
}
class CustomerSelection {
  final Customer? customer;
  final bool createNew;
  final bool useDefault;

  CustomerSelection({
    this.customer,
    this.createNew = false,
    this.useDefault = false,
  });

  bool get hasCustomer => customer != null && !useDefault;
}
class AddCustomerScreen extends StatefulWidget {
  final EnhancedPOSService posService;
  final Function(Customer)? onCustomerAdded;

  const AddCustomerScreen({
    super.key,
    required this.posService,
    this.onCustomerAdded,
  });

  @override
  _AddCustomerScreenState createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  bool _isLoading = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers and focus nodes
    final fields = [
      'firstName',
      'lastName',
      'email',
      'phone',
      'company',
      'address1',
      'address2',
      'city',
      'state',
      'postcode',
      'country',
      'notes',
    ];

    for (final field in fields) {
      _controllers[field] = TextEditingController();
      _focusNodes[field] = FocusNode();
    }

    // Add listeners for real-time validation
    for (final controller in _controllers.values) {
      controller.addListener(_validateForm);
    }
  }

  void _validateForm() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (_isFormValid != isValid) {
      setState(() => _isFormValid = isValid);
    }
  }

  Future<void> _submitCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final customer = Customer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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
        dateCreated: DateTime.now(),
      );

      // Check if customer already exists
      final existingCustomers = await widget.posService.searchCustomers(
        customer.email,
      );
      final emailExists = existingCustomers.any(
            (c) => c.email.toLowerCase() == customer.email.toLowerCase(),
      );

      if (emailExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer with this email already exists'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await widget.posService.addCustomer(customer);

      if (widget.onCustomerAdded != null) {
        widget.onCustomerAdded!(customer);
      } else {
        Navigator.pop(context, customer);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add customer: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _requiredValidator(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add New Customer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    // Personal Information
                    _buildSectionHeader(
                      'Personal Information',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['firstName'],
                            focusNode: _focusNodes['firstName'],
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              hintText: 'Enter first name',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                _requiredValidator(value, 'First name'),
                            onFieldSubmitted: (_) =>
                                _focusNodes['lastName']?.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['lastName'],
                            focusNode: _focusNodes['lastName'],
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              hintText: 'Enter last name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) =>
                                _requiredValidator(value, 'Last name'),
                            onFieldSubmitted: (_) =>
                                _focusNodes['email']?.requestFocus(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['email'],
                      focusNode: _focusNodes['email'],
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'customer@example.com',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _emailValidator,
                      onFieldSubmitted: (_) =>
                          _focusNodes['phone']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['phone'],
                      focusNode: _focusNodes['phone'],
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+1 (555) 123-4567',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          _requiredValidator(value, 'Phone number'),
                      onFieldSubmitted: (_) =>
                          _focusNodes['company']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['company'],
                      focusNode: _focusNodes['company'],
                      decoration: InputDecoration(
                        labelText: 'Company',
                        hintText: 'Enter company name',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _focusNodes['address1']?.requestFocus(),
                    ),

                    // Address Information
                    _buildSectionHeader(
                      'Address Information',
                      Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['address1'],
                      focusNode: _focusNodes['address1'],
                      decoration: InputDecoration(
                        labelText: 'Address Line 1',
                        hintText: 'Street address, P.O. box',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _focusNodes['address2']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['address2'],
                      focusNode: _focusNodes['address2'],
                      decoration: InputDecoration(
                        labelText: 'Address Line 2',
                        hintText:
                        'Apartment, suite, unit, building, floor, etc.',
                        prefixIcon: Icon(Icons.home_work),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _focusNodes['city']?.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['city'],
                            focusNode: _focusNodes['city'],
                            decoration: InputDecoration(
                              labelText: 'City',
                              hintText: 'Enter city',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['state']?.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['state'],
                            focusNode: _focusNodes['state'],
                            decoration: InputDecoration(
                              labelText: 'State/Province',
                              hintText: 'Enter state',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['postcode']?.requestFocus(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['postcode'],
                            focusNode: _focusNodes['postcode'],
                            decoration: InputDecoration(
                              labelText: 'Postal Code',
                              hintText: 'Enter postal code',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['country']?.requestFocus(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _controllers['country'],
                            focusNode: _focusNodes['country'],
                            decoration: InputDecoration(
                              labelText: 'Country',
                              hintText: 'Enter country',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _focusNodes['notes']?.requestFocus(),
                          ),
                        ),
                      ],
                    ),

                    // Additional Information
                    _buildSectionHeader(
                      'Additional Information',
                      Icons.note_outlined,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _controllers['notes'],
                      focusNode: _focusNodes['notes'],
                      decoration: InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Any additional notes about the customer...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isLoading
          ? ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      )
          : ElevatedButton(
        onPressed: _isFormValid ? _submitCustomer : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFormValid
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
          foregroundColor: _isFormValid
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Text(
          'ADD CUSTOMER',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }
}

class CustomerSelectionScreen extends StatefulWidget {
  final EnhancedPOSService posService;
  final CustomerSelection? initialSelection;

  const CustomerSelectionScreen({
    super.key,
    required this.posService,
    this.initialSelection,
  });

  @override
  _CustomerSelectionScreenState createState() =>
      _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Customer> _customers = [];
  final List<Customer> _searchResults = [];
  bool _isLoading = false;
  bool _showSearchResults = false;
  CustomerSelection _selectedCustomer = CustomerSelection(useDefault: true);
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelection != null) {
      _selectedCustomer = widget.initialSelection!;
    }
    _loadCustomers();
  }

  // Add this method to get all customers
  Future<void> _loadCustomers() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final customers = await widget.posService.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers.clear();
          _customers.addAll(customers);
        });
      }
    } catch (e) {
      print('Failed to load customers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load customers'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchTextChanged(String query) {
    // Debounce search to avoid too many API calls
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _searchResults.clear();
      _searchResults.addAll(
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
                  false),
        )
            .toList(),
      );
      _showSearchResults = true;
    });
  }

  void _selectCustomer(Customer? customer) {
    setState(() {
      _selectedCustomer = CustomerSelection(
        customer: customer,
        useDefault: customer == null,
      );
    });
  }

  void _createNewCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(
          posService: widget.posService,
          onCustomerAdded: (customer) {
            _loadCustomers(); // Refresh the list
            _selectCustomer(customer);
            Navigator.pop(context, _selectedCustomer);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Customer',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1),
            onPressed: _createNewCustomer,
            tooltip: 'Add New Customer',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search customers by name, email, or phone...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                ),
                onChanged: _onSearchTextChanged,
              ),
            ),
        
            // Default Customer Option
            _buildDefaultCustomerOption(),
        
            // Results Header
            if (_showSearchResults && _searchResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Search Results (${_searchResults.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
        
            // Customer List
            Expanded(
              child: _isLoading ? _buildLoadingState() : _buildCustomerList(),
            ),
        
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCustomerOption() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _selectedCustomer.useDefault
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person_outline, color: Colors.grey[600]),
        ),
        title: Text(
          'Walk-in Customer',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('Use for anonymous sales'),
        trailing: _selectedCustomer.useDefault
            ? Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
        )
            : null,
        onTap: () => _selectCustomer(null),
      ),
    );
  }

  Widget _buildLoadingState() {
    final _posService = EnhancedPOSService();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.blue[700]!),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Loading Real Business Data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fetching live data from Firestore',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          SizedBox(height: 16),
          StreamBuilder<bool>(
            stream: _posService.onlineStatusStream,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      size: 14,
                      color: isOnline ? Colors.green : Colors.orange,
                    ),
                    SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online - Live Data' : 'Offline - Local Data',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerList() {
    final displayCustomers = _showSearchResults ? _searchResults : _customers;

    if (displayCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _showSearchResults
                  ? 'No customers found'
                  : 'No customers available',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showSearchResults
                  ? 'Try a different search term'
                  : 'Add your first customer to get started',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            if (!_showSearchResults) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _createNewCustomer,
                icon: Icon(Icons.person_add),
                label: Text('Add First Customer'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: displayCustomers.length,
      itemBuilder: (context, index) {
        final customer = displayCustomers[index];
        final isSelected = _selectedCustomer.customer?.id == customer.id;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              customer.displayName,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.email),
                if (customer.phone.isNotEmpty) Text(customer.phone),
                if (customer.orderCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${customer.orderCount} ${customer.orderCount == 1 ? 'order' : 'orders'} • ${Constants.CURRENCY_NAME}${customer.totalSpent.toStringAsFixed(2)} spent',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: isSelected
                ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
                : null,
            onTap: () => _selectCustomer(customer),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _selectedCustomer),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Select Customer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }
}


class CustomersService{
  String? _currentTenantId;
  final LocalDatabase _localDb = LocalDatabase();

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }

  CollectionReference get customersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customers');

  final bool _isOnline = false;
   final _firestore = FirebaseFirestore.instance;
  Future<List<Customer>> getAllCustomers() async {
    try {
      if (_isOnline) {
        // Get all customers from Firestore
        final snapshot = await customersRef
            .orderBy('firstName')
            .get();

        final customers = snapshot.docs
            .map(
              (doc) => Customer.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
            .toList();

        // Save to local cache for offline use
        await _localDb.saveCustomers(customers);
        return customers;
      } else {
        // Get customers from local database when offline
        return await _localDb.getCustomers();
      }
    } catch (e) {
      print('Error getting all customers: $e');
      // Fallback to local data if online fetch fails
      return await _localDb.getCustomers();
    }
  }

}