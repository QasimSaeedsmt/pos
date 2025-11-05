
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../modules/auth/models/activity_type.dart';
import '../users/users_base.dart';

class ClientSignupScreen extends StatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  _ClientSignupScreenState createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends State<ClientSignupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Form data
  String _businessName = '';
  String _adminEmail = '';
  String _adminPassword = '';
  String _subscriptionPlan = 'monthly';
  final List<Map<String, dynamic>> _initialProducts = [];
  final List<Map<String, dynamic>> _initialUsers = [];

  final List<Widget> _steps = [];

  @override
  void initState() {
    super.initState();
    _steps.addAll([
      _BusinessInfoStep(_updateBusinessInfo),
      _AdminAccountStep(_updateAdminAccount),
      _SubscriptionStep(_updateSubscription),
      // _InitialSetupStep(_updateInitialSetup),
      _ConfirmationStep(_completeSignup),
    ]);
  }

  void _updateBusinessInfo(String businessName) {
    setState(() => _businessName = businessName);
    _nextStep();
  }

  void _updateAdminAccount(String email, String password) {
    setState(() {
      _adminEmail = email;
      _adminPassword = password;
    });
    _nextStep();
  }

  void _updateSubscription(String plan) {
    setState(() => _subscriptionPlan = plan);
    _nextStep();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeSignup(BuildContext context) async {
    try {
      final tenantId =
          '${_businessName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

      await TenantSignupService.createTenant(
        tenantId: tenantId,
        businessName: _businessName,
        adminEmail: _adminEmail,
        adminPassword: _adminPassword,
        subscriptionPlan: _subscriptionPlan,
      );


      // Add initial users
      // for (final user in _initialUsers) {
      //   await TenantUsersService.createUserWithDetails(
      //     tenantId: tenantId,
      //     email: user['email'],
      //     password: 'temp123', // In production, generate secure temp password
      //     role: user['role'],
      //     createdBy: 'system',
      //   );
      // }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tenant created successfully! You can now login.'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating tenant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Client Signup'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentStep + 1) / _steps.length),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: _steps,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessInfoStep extends StatefulWidget {
  final Function(String) onComplete;
  const _BusinessInfoStep(this.onComplete);

  @override
  __BusinessInfoStepState createState() => __BusinessInfoStepState();
}

class __BusinessInfoStepState extends State<_BusinessInfoStep> {
  final _businessNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 80, color: Colors.blue),
          SizedBox(height: 20),
          Text(
            'Business Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Tell us about your business',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),
          TextField(
            onChanged: (v) {
              setState(() {});
            },
            controller: _businessNameController,
            decoration: InputDecoration(
              labelText: 'Business Name',
              prefixIcon: Icon(Icons.business_center),
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: _businessNameController.text.isEmpty
                ? null
                : () {
              widget.onComplete(_businessNameController.text);
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountStep extends StatefulWidget {
  final Function(String, String) onComplete;
  const _AdminAccountStep(this.onComplete);

  @override
  __AdminAccountStepState createState() => __AdminAccountStepState();
}

class __AdminAccountStepState extends State<_AdminAccountStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings, size: 80, color: Colors.green),
          SizedBox(height: 20),
          Text(
            'Admin Account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Create your administrator account',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Admin Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          SizedBox(height: 20),
          TextField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: _canProceed()
                ? () {
              widget.onComplete(
                _emailController.text,
                _passwordController.text,
              );
            }
                : null,
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    return _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text &&
        _passwordController.text.length >= 6;
  }
}
class _ConfirmationStep extends StatelessWidget {
  final Function(BuildContext) onComplete;
  const _ConfirmationStep(this.onComplete);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green),
          SizedBox(height: 20),
          Text(
            'Ready to Go!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Your tenant will be created with the selected configuration.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => onComplete(context),
            child: Text('Create Tenant'),
          ),
        ],
      ),
    );
  }
}
class _SubscriptionStep extends StatefulWidget {
  final Function(String) onComplete;
  const _SubscriptionStep(this.onComplete);

  @override
  __SubscriptionStepState createState() => __SubscriptionStepState();
}

class __SubscriptionStepState extends State<_SubscriptionStep> {
  String _selectedPlan = 'monthly';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card, size: 80, color: Colors.orange),
          SizedBox(height: 20),
          Text(
            'Subscription Plan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Choose your subscription plan',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),

          _buildPlanCard(
            'Monthly',
            '\$29/month',
            'monthly',
            Icons.calendar_today,
          ),
          SizedBox(height: 15),
          _buildPlanCard(
            'Yearly',
            '\$299/year',
            'yearly',
            Icons.calendar_view_month,
          ),
          SizedBox(height: 15),
          _buildPlanCard(
            'Custom',
            'Contact sales',
            'custom',
            Icons.business_center,
          ),

          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => widget.onComplete(_selectedPlan),
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
      String title,
      String price,
      String plan,
      IconData icon,
      ) {
    return Card(
      color: _selectedPlan == plan ? Colors.blue[50] : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: _selectedPlan == plan ? Colors.blue : Colors.grey,
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(price),
        trailing: _selectedPlan == plan
            ? Icon(Icons.check_circle, color: Colors.blue)
            : null,
        onTap: () => setState(() => _selectedPlan = plan),
      ),
    );
  }
}
class TenantSignupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;


  // Existing methods remain the same but enhanced with activity logging...
  static Future<void> createTenant({
    required String tenantId,
    required String businessName,
    required String adminEmail,
    required String adminPassword,
    required String subscriptionPlan,
  }) async {
    return await _handleFirebaseCall(() async {
      // Validate inputs
      if (adminPassword.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      if (!_isEmailValid(adminEmail)) {
        throw 'Please enter a valid email address';
      }

      // Create tenant document
      await _firestore.collection('tenants').doc(tenantId).set({
        'businessName': businessName,
        'subscriptionPlan': subscriptionPlan,
        'subscriptionExpiry': _calculateExpiryDate(subscriptionPlan),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'branding': {
          'primaryColor': '#2196F3',
          'secondaryColor': '#FF9800',
          'logoUrl': '',
          'currency': 'USD',
          'taxRate': 0.0,
        },
      });

      // Create admin user using the enhanced method
      await TenantUsersService.createUserWithDetails(
        tenantId: tenantId,
        email: adminEmail,
        password: adminPassword,
        displayName: 'Admin',
        role: 'clientAdmin',
        createdBy: 'system',
      );

      return;
    });
  }

  // ... Rest of the existing FirebaseService methods remain the same

  static DateTime _calculateExpiryDate(String plan) {
    final now = DateTime.now();
    switch (plan) {
      case 'monthly':
        return now.add(Duration(days: 30));
      case 'yearly':
        return now.add(Duration(days: 365));
      default:
        return now.add(Duration(days: 30));
    }
  }

  static bool _isEmailValid(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  static Future<T> _handleFirebaseCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  static String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }

  static String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied. Please check your permissions.';
      case 'not-found':
        return 'Requested data not found.';
      case 'already-exists':
        return 'Item already exists.';
      case 'resource-exhausted':
        return 'Quota exceeded. Please try again later.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please check your connection.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }





}
