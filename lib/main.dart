// app.dart - Complete Multi-Tenant SaaS System
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mpcm/app.dart';
import 'package:mpcm/theme_provider.dart';
import 'package:mpcm/theme_selector_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'firebase_options.dart';


// =============================
// ENHANCED USER MANAGEMENT SCREENS
// =============================
class EnhancedUsersScreen extends StatelessWidget {
  const EnhancedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('User Management'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Activity Log'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UsersListTab(),
            _ActivityLogTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddUserDialog(context),
          child: Icon(Icons.person_add),
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => EnhancedAddUserDialog(
        onSave: (userData) async {
          final authProvider = context.read<MyAuthProvider>();
          await FirebaseService.createUserWithDetails(
            tenantId: authProvider.currentUser!.tenantId,
            email: userData['email'],
            password: userData['password'],
            displayName: userData['displayName'],
            role: userData['role'],
            createdBy: authProvider.currentUser!.uid,
            phoneNumber: userData['phoneNumber'],
          );
        },
      ),
    );
  }
}

class _UsersListTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenants')
          .doc(authProvider.currentUser!.tenantId)
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Users Found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Add your first user to get started',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>? ?? {};
            final user = AppUser.fromFirestore(userDoc);

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(user.role),
                  child: Text(
                    user.formattedName[0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  user.formattedName,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            user.role.toString().split('.').last,
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: _getRoleColor(user.role),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (user.phoneNumber != null) ...[
                          SizedBox(width: 8),
                          Icon(Icons.phone, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            user.phoneNumber!,
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                    if (user.lastLogin != null)
                      Text(
                        'Last login: ${DateFormat('MMM dd, yyyy HH:mm').format(user.lastLogin!)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: user.isActive,
                      onChanged: (value) => _toggleUserStatus(context, user, value),
                    ),
                    PopupMenuButton(
                      icon: Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit User'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'activity',
                          child: Row(
                            children: [
                              Icon(Icons.history, size: 18),
                              SizedBox(width: 8),
                              Text('View Activity'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'password',
                          child: Row(
                            children: [
                              Icon(Icons.lock_reset, size: 18),
                              SizedBox(width: 8),
                              Text('Reset Password'),
                            ],
                          ),
                        ),
                        if (!user.isActive) PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete User', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editUser(context, user);
                            break;
                          case 'activity':
                            _viewUserActivity(context, user);
                            break;
                          case 'password':
                            _resetPassword(context, user);
                            break;
                          case 'delete':
                            _deleteUser(context, user);
                            break;
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.red;
      case UserRole.clientAdmin:
        return Colors.blue;
      case UserRole.salesInventoryManager:
        return Colors.purple;
      case UserRole.cashier:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _toggleUserStatus(BuildContext context, AppUser user, bool isActive) async {
    final authProvider = context.read<MyAuthProvider>();

    try {
      await FirebaseService.updateUserStatus(
        tenantId: authProvider.currentUser!.tenantId,
        userId: user.uid,
        isActive: isActive,
        updatedBy: authProvider.currentUser!.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ${isActive ? 'activated' : 'deactivated'} successfully'),
          backgroundColor: isActive ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editUser(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => EditUserDialog(user: user),
    );
  }

  void _viewUserActivity(BuildContext context, AppUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserActivityScreen(user: user),
      ),
    );
  }

  void _resetPassword(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => ResetPasswordDialog(user: user),
    );
  }

  void _deleteUser(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.formattedName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = context.read<MyAuthProvider>();
                await FirebaseFirestore.instance
                    .collection('tenants')
                    .doc(authProvider.currentUser!.tenantId)
                    .collection('users')
                    .doc(user.uid)
                    .delete();

                // Also delete the auth user
                // Note: In production, you might want to disable instead of delete
                // await FirebaseAuth.instance.currentUser?.delete();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('User deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.getUserActivities(
        authProvider.currentUser!.tenantId,
        limit: 100,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final activities = snapshot.data!.docs;

        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No Activities Yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'User activities will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = UserActivity.fromFirestore(activities[index]);

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activity.moduleColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activity.moduleIcon,
                    color: activity.moduleColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  activity.description,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activity.userDisplayName} • ${DateFormat('MMM dd, yyyy HH:mm').format(activity.timestamp)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (activity.metadata.isNotEmpty) ...[
                      SizedBox(height: 4),
                      ..._buildMetadataWidgets(activity.metadata),
                    ],
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    activity.action.toString().split('.').last.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: _getActivityColor(activity.action),
                ),
                onTap: () => _showActivityDetails(context, activity),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildMetadataWidgets(Map<String, dynamic> metadata) {
    return metadata.entries.map((entry) {
      return Text(
        '${entry.key}: ${entry.value}',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      );
    }).toList();
  }

  void _showActivityDetails(BuildContext context, UserActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(activity.moduleIcon, color: activity.moduleColor),
            SizedBox(width: 8),
            Text('Activity Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Action', activity.action.toString().split('.').last.replaceAll('_', ' ')),
              _buildDetailRow('Description', activity.description),
              _buildDetailRow('User', '${activity.userDisplayName} (${activity.userEmail})'),
              _buildDetailRow('Role', activity.userRole),
              _buildDetailRow('Module', activity.module),
              _buildDetailRow('Time', DateFormat('MMM dd, yyyy HH:mm:ss').format(activity.timestamp)),

              if (activity.metadata.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...activity.metadata.entries.map((entry) =>
                    _buildDetailRow(entry.key, entry.value.toString())
                ),
              ],

              if (activity.ipAddress.isNotEmpty)
                _buildDetailRow('IP Address', activity.ipAddress),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(ActivityType action) {
    switch (action) {
      case ActivityType.user_login:
      case ActivityType.sale_created:
      case ActivityType.payment_processed:
        return Colors.green;
      case ActivityType.user_created:
      case ActivityType.product_created:
        return Colors.blue;
      case ActivityType.user_deactivated:
      case ActivityType.sale_deleted:
      case ActivityType.payment_failed:
        return Colors.red;
      case ActivityType.user_updated:
      case ActivityType.product_updated:
      case ActivityType.sale_updated:
        return Colors.orange;
      case ActivityType.low_stock_alert:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

// Placeholder dialogs for edit and reset password
class EditUserDialog extends StatelessWidget {
  final AppUser user;
  const EditUserDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit User'),
      content: Text('Edit user functionality to be implemented'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class ResetPasswordDialog extends StatelessWidget {
  final AppUser user;
  const ResetPasswordDialog({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset Password'),
      content: Text('Password reset functionality to be implemented'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}




class EnhancedAddUserDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const EnhancedAddUserDialog({super.key, required this.onSave});

  @override
  _EnhancedAddUserDialogState createState() => _EnhancedAddUserDialogState();
}

class _EnhancedAddUserDialogState extends State<EnhancedAddUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'cashier';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue),
          SizedBox(width: 8),
          Text('Add New User'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: 'Display Name *',
                  hintText: 'Enter full name',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter display name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'user@company.com',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!AppUtils.isEmailValid(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1234567890',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Enter temporary password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField(
                value: _selectedRole,
                items: [
                  DropdownMenuItem(
                    value: 'cashier',
                    child: Text('Cashier'),
                  ),
                  DropdownMenuItem(
                    value: 'salesInventoryManager',
                    child: Text('Sales & Inventory Manager'),
                  ),
                  DropdownMenuItem(
                    value: 'clientAdmin',
                    child: Text('Client Admin'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value.toString();
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.assignment_ind),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveUser,
          child: Text('Create User'),
        ),
      ],
    );
  }

  void _saveUser() {
    if (_formKey.currentState!.validate()) {
      final userData = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'displayName': _displayNameController.text.trim(),
        'role': _selectedRole,
        'phoneNumber': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      };

      widget.onSave(userData);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class UserActivityScreen extends StatefulWidget {
  final AppUser user;
  const UserActivityScreen({super.key, required this.user});

  @override
  _UserActivityScreenState createState() => _UserActivityScreenState();
}

class _UserActivityScreenState extends State<UserActivityScreen> {
  String _selectedFilter = 'all';
  final List<String> _filters = [
    'all',
    'user',
    'product',
    'sale',
    'inventory',
    'ticket',
    'report',
    'system'
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.formattedName} - Activity'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (BuildContext context) {
              return _filters.map((String filter) {
                return PopupMenuItem<String>(
                  value: filter,
                  child: Row(
                    children: [
                      Icon(
                        _getFilterIcon(filter),
                        color: _getFilterColor(filter),
                      ),
                      SizedBox(width: 8),
                      Text(filter.toUpperCase()),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filters.map((filter) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(filter.toUpperCase()),
                    selected: _selectedFilter == filter,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedFilter = selected ? filter : 'all';
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: _getFilterColor(filter),
                    labelStyle: TextStyle(
                      color: _selectedFilter == filter ? Colors.white : Colors.black,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.getUserActivities(
                authProvider.currentUser!.tenantId,
                userId: widget.user.uid,
                limit: 100,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final activities = snapshot.data!.docs;

                // Filter activities
                final filteredActivities = activities.where((doc) {
                  if (_selectedFilter == 'all') return true;
                  final activity = UserActivity.fromFirestore(doc);
                  return activity.module == _selectedFilter;
                }).toList();

                if (filteredActivities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No activities found'),
                        Text(
                          _selectedFilter == 'all'
                              ? 'This user has no activities yet'
                              : 'No ${_selectedFilter} activities found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredActivities.length,
                  itemBuilder: (context, index) {
                    final activity = UserActivity.fromFirestore(filteredActivities[index]);

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: activity.moduleColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            activity.moduleIcon,
                            color: activity.moduleColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          activity.description,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'By ${activity.userDisplayName} • ${DateFormat('MMM dd, yyyy HH:mm').format(activity.timestamp)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (activity.metadata.isNotEmpty) ...[
                              SizedBox(height: 4),
                              ..._buildMetadataWidgets(activity.metadata),
                            ],
                          ],
                        ),
                        trailing: Chip(
                          label: Text(
                            activity.action.toString().split('.').last.replaceAll('_', ' '),
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                          backgroundColor: _getActivityColor(activity.action),
                        ),
                        onTap: () => _showActivityDetails(context, activity),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMetadataWidgets(Map<String, dynamic> metadata) {
    return metadata.entries.map((entry) {
      return Text(
        '${entry.key}: ${entry.value}',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      );
    }).toList();
  }

  void _showActivityDetails(BuildContext context, UserActivity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(activity.moduleIcon, color: activity.moduleColor),
            SizedBox(width: 8),
            Text('Activity Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Action', activity.action.toString().split('.').last.replaceAll('_', ' ')),
              _buildDetailRow('Description', activity.description),
              _buildDetailRow('User', '${activity.userDisplayName} (${activity.userEmail})'),
              _buildDetailRow('Role', activity.userRole),
              _buildDetailRow('Module', activity.module),
              _buildDetailRow('Time', DateFormat('MMM dd, yyyy HH:mm:ss').format(activity.timestamp)),

              if (activity.metadata.isNotEmpty) ...[
                SizedBox(height: 16),
                Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...activity.metadata.entries.map((entry) =>
                    _buildDetailRow(entry.key, entry.value.toString())
                ),
              ],

              if (activity.ipAddress.isNotEmpty)
                _buildDetailRow('IP Address', activity.ipAddress),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'user':
        return Icons.person;
      case 'product':
        return Icons.inventory;
      case 'sale':
        return Icons.point_of_sale;
      case 'inventory':
        return Icons.warehouse;
      case 'ticket':
        return Icons.support;
      case 'report':
        return Icons.analytics;
      case 'system':
        return Icons.settings;
      default:
        return Icons.all_inclusive;
    }
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'user':
        return Colors.blue;
      case 'product':
        return Colors.purple;
      case 'sale':
        return Colors.green;
      case 'inventory':
        return Colors.orange;
      case 'ticket':
        return Colors.red;
      case 'report':
        return Colors.indigo;
      case 'system':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getActivityColor(ActivityType action) {
    switch (action) {
      case ActivityType.user_login:
      case ActivityType.sale_created:
      case ActivityType.payment_processed:
        return Colors.green;
      case ActivityType.user_created:
      case ActivityType.product_created:
        return Colors.blue;
      case ActivityType.user_deactivated:
      case ActivityType.sale_deleted:
      case ActivityType.payment_failed:
        return Colors.red;
      case ActivityType.user_updated:
      case ActivityType.product_updated:
      case ActivityType.sale_updated:
        return Colors.orange;
      case ActivityType.low_stock_alert:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
// Placeholder dialogs for edit and reset password

class EnhancedProfileScreen extends StatelessWidget {
  const EnhancedProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final user = authProvider.currentUser!;
    final tenant = authProvider.currentTenant!;

    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Text(
                        user.formattedName[0].toUpperCase(),
                        style: TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      user.formattedName,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(user.email),
                    if (user.phoneNumber != null) Text(user.phoneNumber!),
                    SizedBox(height: 8),
                    Chip(
                      label: Text(
                        user.role.toString().split('.').last,
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                    SizedBox(height: 16),
                    if (user.lastLogin != null)
                      Text(
                        'Last login: ${DateFormat('MMM dd, yyyy HH:mm').format(user.lastLogin!)}',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: Icon(Icons.business),
                    title: Text('Business'),
                    subtitle: Text(tenant.businessName),
                  ),
                  ListTile(
                    leading: Icon(Icons.credit_card),
                    title: Text('Subscription'),
                    subtitle: Text('${tenant.subscriptionPlan} - ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry)}'),
                  ),
                  ListTile(
                    leading: Icon(Icons.history),
                    title: Text('View My Activity'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserActivityScreen(user: user),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                    onTap: () => authProvider.logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }}

enum ActivityType {
  // Keep all existing types
  user_login,
  user_logout,
  user_created,
  user_updated,
  user_deactivated,
  sale_created,
  sale_updated,
  sale_deleted,
  product_created,
  product_updated,
  product_deleted,
  stock_updated,
  tenant_created,
  tenant_updated,
  subscription_updated,
  ticket_created,
  ticket_updated,
  payment_processed,
  report_generated,

  // Add new types for comprehensive tracking
  user_password_changed,
  user_profile_updated,
  product_stock_updated,
  product_category_created,
  product_category_updated,
  sale_refunded,
  sale_cancelled,
  inventory_checked,
  inventory_adjusted,
  low_stock_alert,
  customer_created,
  customer_updated,
  customer_deleted,
  report_exported,
  settings_updated,
  branding_updated,
  ticket_closed,
  ticket_replied,
  payment_failed,
  payment_refunded,
}
class Tenant {
  final String id;
  final String businessName;
  final String subscriptionPlan;
  final DateTime subscriptionExpiry;
  final bool isActive;
  final Map<String, dynamic> branding;

  Tenant({
    required this.id,
    required this.businessName,
    required this.subscriptionPlan,
    required this.subscriptionExpiry,
    required this.isActive,
    required this.branding,
  });

  factory Tenant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Calculate expiry date with fallback
    final subscriptionExpiry = data['subscriptionExpiry'] != null
        ? (data['subscriptionExpiry'] as Timestamp).toDate()
        : DateTime.now().add(Duration(days: 30)); // Default 30 days

    return Tenant(
      id: doc.id,
      businessName: data['businessName']?.toString() ?? 'Unknown Business',
      subscriptionPlan: data['subscriptionPlan']?.toString() ?? 'monthly',
      subscriptionExpiry: subscriptionExpiry,
      isActive: data['isActive'] ?? false,
      branding: data['branding'] is Map
          ? Map<String, dynamic>.from(data['branding'] as Map)
          : {},
    );
  }

  bool get isSubscriptionActive {
    return isActive && subscriptionExpiry.isAfter(DateTime.now());
  }
}


class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final UserRole role;
  final String tenantId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String createdBy;
  final Map<String, dynamic> profile;
  final List<String> permissions;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    required this.role,
    required this.tenantId,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
    required this.createdBy,
    this.profile = const {},
    this.permissions = const [],
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Extract email with fallback
    final email = data['email']?.toString() ?? 'unknown@email.com';

    // Extract display name with fallback
    final displayName = data['displayName']?.toString() ??
        email.split('@').first ??
        'User';

    // Parse role with fallback
    final roleString = data['role']?.toString() ?? 'cashier';
    final role = _parseUserRole(roleString);

    // Extract tenant ID with fallback
    final tenantId = data['tenantId']?.toString() ?? 'unknown_tenant';

    // Parse dates with fallbacks
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final lastLogin = data['lastLogin'] != null
        ? (data['lastLogin'] as Timestamp).toDate()
        : null;

    return AppUser(
      uid: doc.id,
      email: email,
      displayName: displayName,
      phoneNumber: data['phoneNumber']?.toString(),
      role: role,
      tenantId: tenantId,
      isActive: data['isActive'] ?? false,
      createdAt: createdAt,
      lastLogin: lastLogin,
      createdBy: data['createdBy']?.toString() ?? 'system',
      profile: data['profile'] is Map ? Map<String, dynamic>.from(data['profile'] as Map) : {},
      permissions: data['permissions'] is List
          ? List<String>.from(data['permissions'] as List)
          : [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role.toString().split('.').last,
      'tenantId': tenantId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdBy': createdBy,
      'profile': profile,
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static UserRole _parseUserRole(String roleString) {
    switch (roleString) {
      case 'superAdmin':
        return UserRole.superAdmin;
      case 'clientAdmin':
        return UserRole.clientAdmin;
      case 'cashier':
        return UserRole.cashier;
      case 'salesInventoryManager':
        return UserRole.salesInventoryManager;
      default:
        return UserRole.cashier; // Default fallback
    }
  }

  bool get canManageProducts =>
      role == UserRole.clientAdmin || role == UserRole.salesInventoryManager;
  bool get canProcessSales =>
      role == UserRole.clientAdmin ||
          role == UserRole.cashier ||
          role == UserRole.salesInventoryManager;
  bool get canManageUsers => role == UserRole.clientAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;

  String get formattedName => displayName.isNotEmpty ? displayName : email.split('@').first;
}
class UserActivity {
  final String id;
  final String tenantId;
  final String userId;
  final String userEmail;
  final String userDisplayName;
  final String userRole;
  final ActivityType action;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String ipAddress;
  final String userAgent;
  final String module; // New field to categorize activities

  UserActivity({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.userEmail,
    required this.userDisplayName,
    required this.userRole,
    required this.action,
    required this.description,
    this.metadata = const {},
    required this.timestamp,
    this.ipAddress = '',
    this.userAgent = '',
    required this.module,
  });

  factory UserActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return UserActivity(
      id: doc.id,
      tenantId: data['tenantId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      userDisplayName: data['userDisplayName']?.toString() ?? '',
      userRole: data['userRole']?.toString() ?? '',
      action: _parseActivityType(data['action']?.toString() ?? ''),
      description: data['description']?.toString() ?? '',
      metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata'] as Map) : {},
      timestamp: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now(),
      ipAddress: data['ipAddress']?.toString() ?? '',
      userAgent: data['userAgent']?.toString() ?? '',
      module: data['module']?.toString() ?? _getModuleFromAction(data['action']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'userId': userId,
      'userEmail': userEmail,
      'userDisplayName': userDisplayName,
      'userRole': userRole,
      'action': action.toString().split('.').last,
      'description': description,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'module': module,
    };
  }

  static ActivityType _parseActivityType(String type) {
    try {
      return ActivityType.values.firstWhere(
            (e) => e.toString().split('.').last == type,
        orElse: () => ActivityType.user_login,
      );
    } catch (e) {
      return ActivityType.user_login;
    }
  }

  static String _getModuleFromAction(String action) {
    if (action.contains('user_')) return 'user';
    if (action.contains('product_')) return 'product';
    if (action.contains('sale_')) return 'sale';
    if (action.contains('stock_') || action.contains('inventory_')) return 'inventory';
    if (action.contains('customer_')) return 'customer';
    if (action.contains('ticket_')) return 'ticket';
    if (action.contains('payment_')) return 'payment';
    if (action.contains('report_')) return 'report';
    if (action.contains('tenant_') || action.contains('subscription_')) return 'system';
    return 'system';
  }

  // Helper method to get module icon
  IconData get moduleIcon {
    switch (module) {
      case 'user':
        return Icons.person;
      case 'product':
        return Icons.inventory;
      case 'sale':
        return Icons.point_of_sale;
      case 'inventory':
        return Icons.warehouse;
      case 'customer':
        return Icons.people;
      case 'report':
        return Icons.analytics;
      case 'ticket':
        return Icons.support;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.settings;
    }
  }

  // Helper method to get module color
  Color get moduleColor {
    switch (module) {
      case 'user':
        return Colors.blue;
      case 'product':
        return Colors.purple;
      case 'sale':
        return Colors.green;
      case 'inventory':
        return Colors.orange;
      case 'customer':
        return Colors.teal;
      case 'report':
        return Colors.indigo;
      case 'ticket':
        return Colors.red;
      case 'payment':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
class SuperAdminHome extends StatelessWidget {
  const SuperAdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // System Overview
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                'Total Tenants',
                tenantProvider.tenants.length.toString(),
                Icons.business,
                Colors.blue,
              ),
              _StatCard(
                'Active Tenants',
                tenantProvider.tenants
                    .where((t) => t.isSubscriptionActive)
                    .length
                    .toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _StatCard(
                'Expired Tenants',
                tenantProvider.tenants
                    .where((t) => !t.isSubscriptionActive)
                    .length
                    .toString(),
                Icons.error,
                Colors.red,
              ),
            ],
          ),

          SizedBox(height: 20),

          // Quick Actions
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    childAspectRatio: 3,
                    children: [
                      _ActionCard(
                        'Create Tenant',
                        Icons.add_business,
                        Colors.blue,
                        () {
                          showDialog(
                            context: context,
                            builder: (context) => CreateTenantDialog(),
                          );
                        },
                      ),
                      _ActionCard(
                        'View All Tenants',
                        Icons.list_alt,
                        Colors.green,
                        () {
                          // Navigate to tenants management
                          final superAdminState = context
                              .findAncestorStateOfType<
                                _SuperAdminDashboardState
                              >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                                1; // Tenants tab index
                          });
                        },
                      ),
                      _ActionCard(
                        'System Analytics',
                        Icons.analytics,
                        Colors.orange,
                        () {
                          final superAdminState = context
                              .findAncestorStateOfType<
                                _SuperAdminDashboardState
                              >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                                2; // Analytics tab index
                          });
                        },
                      ),
                      _ActionCard(
                        'Support Tickets',
                        Icons.support,
                        Colors.purple,
                        () {
                          final superAdminState = context
                              .findAncestorStateOfType<
                                _SuperAdminDashboardState
                              >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                                3; // Support tab index
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Recent Tenants
          Expanded(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Tenants',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: () {
                            final superAdminState = context
                                .findAncestorStateOfType<
                                  _SuperAdminDashboardState
                                >();
                            superAdminState?.setState(() {
                              superAdminState._currentIndex =
                                  1; // Tenants tab index
                            });
                          },
                          child: Text('View All'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: tenantProvider.tenants.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No Tenants Yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            CreateTenantDialog(),
                                      );
                                    },
                                    icon: Icon(Icons.add_business),
                                    label: Text('Create First Tenant'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: tenantProvider.tenants.take(5).length,
                              itemBuilder: (context, index) {
                                final tenant = tenantProvider.tenants[index];
                                return ListTile(
                                  leading: Icon(
                                    Icons.business,
                                    color: tenant.isSubscriptionActive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: Text(tenant.businessName),
                                  subtitle: Text(
                                    '${tenant.subscriptionPlan} - ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry)}',
                                  ),
                                  trailing: tenant.isSubscriptionActive
                                      ? Chip(
                                          label: Text(
                                            'Active',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                        )
                                      : Chip(
                                          label: Text(
                                            'Expired',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                  onTap: () {
                                    // Show tenant details
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          TenantDetailsDialog(tenant: tenant),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class SuperAdminAnalyticsScreen extends StatefulWidget {
  const SuperAdminAnalyticsScreen({super.key});

  @override
  _SuperAdminAnalyticsScreenState createState() => _SuperAdminAnalyticsScreenState();
}

class _SuperAdminAnalyticsScreenState extends State<SuperAdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<TenantAnalytics> _tenantsAnalytics = [];
  OverallAnalytics _overallAnalytics = OverallAnalytics.empty();
  bool _isLoading = true;
  String _timeFilter = '7days'; // 7days, 30days, 90days, 1year

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSuperAdminAnalytics();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  Future<void> _loadSuperAdminAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final overall = await _fetchOverallAnalytics();
      final tenants = await _fetchTenantsAnalytics();

      if (mounted) {
        setState(() {
          _overallAnalytics = overall;
          _tenantsAnalytics = tenants;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading super admin analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<OverallAnalytics> _fetchOverallAnalytics() async {
    try {
      // Get all tenants
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      final allTenants = tenantsSnapshot.docs;

      DateTime startDate;
      final now = DateTime.now();
      switch (_timeFilter) {
        case '7days':
          startDate = now.subtract(Duration(days: 7));
          break;
        case '30days':
          startDate = now.subtract(Duration(days: 30));
          break;
        case '90days':
          startDate = now.subtract(Duration(days: 90));
          break;
        case '1year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          startDate = now.subtract(Duration(days: 7));
      }

      double totalRevenue = 0.0;
      int totalOrders = 0;
      int totalProducts = 0;
      int totalCustomers = 0;
      int activeTenants = 0;
      int expiredTenants = 0;

      // Aggregate data from all tenants
      for (final tenant in allTenants) {
        final tenantId = tenant.id;
        final tenantData = tenant.data();

        // Check tenant subscription status
        final subscriptionExpiry = tenantData['subscriptionExpiry'];
        if (subscriptionExpiry is Timestamp) {
          if (subscriptionExpiry.toDate().isAfter(now)) {
            activeTenants++;
          } else {
            expiredTenants++;
          }
        }

        // Get tenant orders
        final ordersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();

        // Get tenant products
        final productsSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .where('status', isEqualTo: 'publish')
            .get();

        // Get tenant customers
        final customersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('customers')
            .get();

        // Calculate tenant metrics
        double tenantRevenue = 0.0;
        for (final order in ordersSnapshot.docs) {
          final orderData = order.data();
          tenantRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
        }

        totalRevenue += tenantRevenue;
        totalOrders += ordersSnapshot.docs.length;
        totalProducts += productsSnapshot.docs.length;
        totalCustomers += customersSnapshot.docs.length;
      }

      return OverallAnalytics(
        totalRevenue: totalRevenue,
        totalOrders: totalOrders,
        totalProducts: totalProducts,
        totalCustomers: totalCustomers,
        activeTenants: activeTenants,
        expiredTenants: expiredTenants,
        totalTenants: allTenants.length,
        averageRevenuePerTenant: allTenants.isNotEmpty ? totalRevenue / allTenants.length : 0.0,
        timePeriod: _timeFilter,
      );
    } catch (e) {
      print('Error fetching overall analytics: $e');
      return OverallAnalytics.empty();
    }
  }

  Future<List<TenantAnalytics>> _fetchTenantsAnalytics() async {
    try {
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      final List<TenantAnalytics> tenantsAnalytics = [];

      for (final tenant in tenantsSnapshot.docs) {
        final tenantId = tenant.id;
        final tenantData = tenant.data();

        // Get time range based on filter
        DateTime startDate;
        final now = DateTime.now();
        switch (_timeFilter) {
          case '7days':
            startDate = now.subtract(Duration(days: 7));
            break;
          case '30days':
            startDate = now.subtract(Duration(days: 30));
            break;
          case '90days':
            startDate = now.subtract(Duration(days: 90));
            break;
          case '1year':
            startDate = DateTime(now.year - 1, now.month, now.day);
            break;
          default:
            startDate = now.subtract(Duration(days: 7));
        }

        // Fetch tenant-specific data
        final ordersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();

        final productsSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .where('status', isEqualTo: 'publish')
            .get();

        final customersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('customers')
            .get();

        // Calculate metrics
        double revenue = 0.0;
        for (final order in ordersSnapshot.docs) {
          final orderData = order.data();
          revenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
        }

        // Check subscription status
        final subscriptionExpiry = tenantData['subscriptionExpiry'];
        final bool isActive = subscriptionExpiry is Timestamp &&
            subscriptionExpiry.toDate().isAfter(now);

        final analytics = TenantAnalytics(
          tenantId: tenantId,
          businessName: tenantData['businessName']?.toString() ?? 'Unknown Business',
          subscriptionPlan: tenantData['subscriptionPlan']?.toString() ?? 'Unknown',
          isActive: isActive,
          revenue: revenue,
          ordersCount: ordersSnapshot.docs.length,
          productsCount: productsSnapshot.docs.length,
          customersCount: customersSnapshot.docs.length,
          subscriptionExpiry: subscriptionExpiry is Timestamp ?
          subscriptionExpiry.toDate() : null,
        );

        tenantsAnalytics.add(analytics);
      }

      // Sort by revenue descending
      tenantsAnalytics.sort((a, b) => b.revenue.compareTo(a.revenue));
      return tenantsAnalytics;
    } catch (e) {
      print('Error fetching tenants analytics: $e');
      return [];
    }
  }

  void _onTimeFilterChanged(String? filter) {
    if (filter != null) {
      setState(() {
        _timeFilter = filter;
        _loadSuperAdminAnalytics();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Super Admin Analytics'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: _onTimeFilterChanged,
            itemBuilder: (context) => [
              PopupMenuItem(value: '7days', child: Text('Last 7 Days')),
              PopupMenuItem(value: '30days', child: Text('Last 30 Days')),
              PopupMenuItem(value: '90days', child: Text('Last 90 Days')),
              PopupMenuItem(value: '1year', child: Text('Last 1 Year')),
            ],
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(_getTimeFilterDisplayName()),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSuperAdminAnalytics,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: CustomScrollView(
              slivers: [
                _buildOverallStats(),
                _buildTenantsList(),
                SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.purple[700]!),
          ),
          SizedBox(height: 16),
          Text(
            'Loading Super Admin Analytics...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Overall Platform Analytics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  'Total Revenue',
                  '${Constants.CURRENCY_NAME}${_overallAnalytics.totalRevenue.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.green,
                  'Across all tenants',
                ),
                _buildStatCard(
                  'Total Orders',
                  _overallAnalytics.totalOrders.toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                  'Completed orders',
                ),
                _buildStatCard(
                  'Active Tenants',
                  '${_overallAnalytics.activeTenants}/${_overallAnalytics.totalTenants}',
                  Icons.business,
                  _overallAnalytics.activeTenants > 0 ? Colors.green : Colors.orange,
                  'Active subscriptions',
                ),
                _buildStatCard(
                  'Platform Customers',
                  _overallAnalytics.totalCustomers.toString(),
                  Icons.people,
                  Colors.purple,
                  'Total customers',
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(
                  'Total Products',
                  _overallAnalytics.totalProducts.toString(),
                  Icons.inventory_2,
                  Colors.orange,
                  'Across platform',
                ),
                _buildStatCard(
                  'Avg Revenue/Tenant',
                  '${Constants.CURRENCY_NAME}${_overallAnalytics.averageRevenuePerTenant.toStringAsFixed(0)}',
                  Icons.trending_up,
                  Colors.teal,
                  'Average performance',
                ),
                _buildStatCard(
                  'Subscription Health',
                  '${((_overallAnalytics.activeTenants / _overallAnalytics.totalTenants) * 100).toStringAsFixed(1)}%',
                  Icons.health_and_safety,
                  _overallAnalytics.activeTenants / _overallAnalytics.totalTenants > 0.7
                      ? Colors.green : Colors.orange,
                  'Active rate',
                ),
                _buildStatCard(
                  'Time Period',
                  _getTimeFilterDisplayName(),
                  Icons.calendar_today,
                  Colors.indigo,
                  'Analysis period',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantsList() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tenant Performance Ranking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Sorted by revenue (${_getTimeFilterDisplayName()})',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            ..._tenantsAnalytics.asMap().entries.map((entry) {
              final index = entry.key;
              final tenant = entry.value;
              return _buildTenantCard(tenant, index + 1);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantCard(TenantAnalytics tenant, int rank) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank <= 3 ? Colors.amber : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Tenant Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tenant.businessName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tenant.isActive ? Colors.green[100] : Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tenant.isActive ? 'Active' : 'Expired',
                          style: TextStyle(
                            color: tenant.isActive ? Colors.green[800] : Colors.red[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Plan: ${tenant.subscriptionPlan}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (tenant.subscriptionExpiry != null)
                    Text(
                      'Expires: ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry!)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                ],
              ),
            ),
            SizedBox(width: 12),
            // Performance Metrics
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${Constants.CURRENCY_NAME}${tenant.revenue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  '${tenant.ordersCount} orders',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${tenant.productsCount} products',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${tenant.customersCount} customers',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeFilterDisplayName() {
    switch (_timeFilter) {
      case '7days': return 'Last 7 Days';
      case '30days': return 'Last 30 Days';
      case '90days': return 'Last 90 Days';
      case '1year': return 'Last 1 Year';
      default: return 'Last 7 Days';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// Analytics Data Models
class OverallAnalytics {
  final double totalRevenue;
  final int totalOrders;
  final int totalProducts;
  final int totalCustomers;
  final int activeTenants;
  final int expiredTenants;
  final int totalTenants;
  final double averageRevenuePerTenant;
  final String timePeriod;

  const OverallAnalytics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalProducts,
    required this.totalCustomers,
    required this.activeTenants,
    required this.expiredTenants,
    required this.totalTenants,
    required this.averageRevenuePerTenant,
    required this.timePeriod,
  });

  factory OverallAnalytics.empty() {
    return OverallAnalytics(
      totalRevenue: 0.0,
      totalOrders: 0,
      totalProducts: 0,
      totalCustomers: 0,
      activeTenants: 0,
      expiredTenants: 0,
      totalTenants: 0,
      averageRevenuePerTenant: 0.0,
      timePeriod: '7days',
    );
  }
}

class TenantAnalytics {
  final String tenantId;
  final String businessName;
  final String subscriptionPlan;
  final bool isActive;
  final double revenue;
  final int ordersCount;
  final int productsCount;
  final int customersCount;
  final DateTime? subscriptionExpiry;

  const TenantAnalytics({
    required this.tenantId,
    required this.businessName,
    required this.subscriptionPlan,
    required this.isActive,
    required this.revenue,
    required this.ordersCount,
    required this.productsCount,
    required this.customersCount,
    this.subscriptionExpiry,
  });
}
// Update the _ActionCard widget for better styling
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard(this.title, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Hive for offline storage
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    await Hive.openBox('app_cache');
    await Hive.openBox('offline_data');

    runApp(MultiTenantSaaSApp());
  } catch (e) {
    print('Firebase initialization error: $e');
    runApp(ErrorApp(error: e));
  }
}

class ErrorApp extends StatelessWidget {
  final dynamic error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Failed to initialize app: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                ElevatedButton(onPressed: () => main(), child: Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================
// FIREBASE SERVICE LAYER
// =============================
class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
// Add to FirebaseService class
  static Stream<QuerySnapshot> getSalesStream(String tenantId, {int limit = 100}) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  static Stream<QuerySnapshot> getSalesByDateRange(
      String tenantId, {
        required DateTime startDate,
        required DateTime endDate,
      }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<Map<String, dynamic>> getSalesStats(String tenantId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get today's sales
      final todaySales = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: todayStart)
          .where('createdAt', isLessThanOrEqualTo: todayEnd)
          .get();

      // Get all sales for total stats
      final allSales = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .get();

      double todayRevenue = 0;
      int todaySalesCount = todaySales.docs.length;

      for (final doc in todaySales.docs) {
        final data = doc.data() as Map<String, dynamic>;
        todayRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
      }

      double totalRevenue = 0;
      int totalSalesCount = allSales.docs.length;

      for (final doc in allSales.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'todayRevenue': todayRevenue,
        'todaySalesCount': todaySalesCount,
        'totalRevenue': totalRevenue,
        'totalSalesCount': totalSalesCount,
        'averageOrderValue': totalSalesCount > 0 ? totalRevenue / totalSalesCount : 0,
      };
    } catch (e) {
      print('Error getting sales stats: $e');
      return {
        'todayRevenue': 0.0,
        'todaySalesCount': 0,
        'totalRevenue': 0.0,
        'totalSalesCount': 0,
        'averageOrderValue': 0.0,
      };
    }
  }
  // In FirebaseService class - Fix the loginWithActivity method
  static Future<UserCredential> loginWithActivity({
    required String email,
    required String password,
    String ipAddress = '',
    String userAgent = '',
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last login
    await _updateLastLogin(userCredential.user!.uid);

    // Log login activity
    final userDoc = await _getUserDocument(userCredential.user!.uid);
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      await _logUserActivity(
        tenantId: userData['tenantId']?.toString() ?? 'unknown_tenant',
        userId: userCredential.user!.uid,
        userEmail: email,
        userDisplayName: userData['displayName']?.toString() ?? email.split('@').first,
        action: ActivityType.user_login,
        description: 'User logged in successfully',
        metadata: {
          'loginMethod': 'email_password',
          'ipAddress': ipAddress,
        },
        ipAddress: ipAddress,
        userAgent: userAgent,
      );
    }

    return userCredential;
  }

// Fix the _updateLastLogin method
  static Future<void> _updateLastLogin(String uid) async {
    final userDoc = await _getUserDocument(uid);
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final tenantId = userData['tenantId']?.toString() ?? 'unknown_tenant';
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(uid)
          .update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }

// Fix the createSaleWithUserTracking method
  static Future<void> createSaleWithUserTracking({
    required String tenantId,
    required String cashierId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double taxAmount,
    required String paymentMethod,
    String? customerEmail,
    String? customerName,
  }) async {
    return await _handleFirebaseCall(() async {
      final saleRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .doc();

      // Get cashier details
      final cashierDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(cashierId)
          .get();

      final cashierData = cashierDoc.data() as Map<String, dynamic>? ?? {};

      // Start a batch write for transaction
      final batch = _firestore.batch();

      // Create enhanced sale document
      batch.set(saleRef, {
        'id': saleRef.id,
        'cashierId': cashierId,
        'cashierName': cashierData['displayName']?.toString() ?? 'Unknown Cashier',
        'cashierEmail': cashierData['email']?.toString() ?? 'unknown@email.com',
        'items': items,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
        'paymentMethod': paymentMethod,
        'customerEmail': customerEmail,
        'customerName': customerName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Update product stock
      for (final item in items) {
        final productRef = _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .doc(item['productId']?.toString() ?? '');

        batch.update(productRef, {
          'stock': FieldValue.increment(-(item['quantity'] as int? ?? 0)),
        });
      }

      // Create notification for new sale
      batch.set(
        _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('notifications')
            .doc(),
        {
          'type': 'new_sale',
          'title': 'New Sale Completed',
          'message':
          'Sale #${saleRef.id} for \$${totalAmount.toStringAsFixed(2)}',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      // Log sale activity
      await _logUserActivity(
        tenantId: tenantId,
        userId: cashierId,
        userEmail: cashierData['email']?.toString() ?? 'unknown@email.com',
        userDisplayName: cashierData['displayName']?.toString() ?? 'Unknown User',
        action: ActivityType.sale_created,
        description: 'Sale #${saleRef.id} completed for \$${totalAmount.toStringAsFixed(2)}',
        metadata: {
          'saleId': saleRef.id,
          'totalAmount': totalAmount,
          'itemsCount': items.length,
          'paymentMethod': paymentMethod,
        },
      );

      return;
    });
  }
// In FirebaseService class - Fix the _logUserActivity method calls
  static Future<void> _logUserActivity({
    required String tenantId,
    required String userId,
    required String userEmail,
    required String userDisplayName,
    required ActivityType action,
    required String description,
    Map<String, dynamic> metadata = const {},
    String ipAddress = '',
    String userAgent = '',
  }) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('user_activities')
          .add({
        'tenantId': tenantId,
        'userId': userId,
        'userEmail': userEmail,
        'userDisplayName': userDisplayName,
        'action': action.toString().split('.').last,
        'description': description,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': ipAddress,
        'userAgent': userAgent,
      });
    } catch (e) {
      print('Failed to log activity: $e');
      // Don't throw error for failed activity logging
    }
  }

// Enhanced Login with Activity Tracking - FIXED




// Update User Status with Activity Logging - FIXED
  static Future<void> updateUserStatus({
    required String tenantId,
    required String userId,
    required bool isActive,
    required String updatedBy,
  }) async {
    return await _handleFirebaseCall(() async {
      // Get user details before update
      final userDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(userId)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>; // CAST HERE

      // Update user status
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(userId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log the activity
      await _logUserActivity(
        tenantId: tenantId,
        userId: updatedBy,
        userEmail: userData['email'], // Use actual user email
        userDisplayName: userData['displayName'], // Use actual display name
        action: isActive ? ActivityType.user_updated : ActivityType.user_deactivated,
        description: 'User ${isActive ? 'activated' : 'deactivated'} by admin',
        metadata: {
          'targetUserId': userId,
          'targetUserEmail': userData['email'],
          'previousStatus': !isActive,
          'newStatus': isActive,
        },
      );

      return;
    });
  }
  // Enhanced User Creation
  static Future<void> createUserWithDetails({
    required String tenantId,
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String createdBy,
    String? phoneNumber,
    Map<String, dynamic>? profile,
    List<String>? permissions,
  }) async {
    return await _handleFirebaseCall(() async {
      // Validate password length
      if (password.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      try {
        // Create user in Firebase Auth
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        // Update display name in Auth
        await userCredential.user!.updateDisplayName(displayName);

        // Create user document in tenant's users collection
        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'email': email.trim(),
          'displayName': displayName,
          'phoneNumber': phoneNumber,
          'role': role,
          'createdBy': createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'tenantId': tenantId,
          'lastLogin': FieldValue.serverTimestamp(),
          'profile': profile ?? {},
          'permissions': permissions ?? _getDefaultPermissions(role),
        });

        // Log user creation activity
        await _logUserActivity(
          tenantId: tenantId,
          userId: userCredential.user!.uid,
          userEmail: email,
          userDisplayName: displayName,
          action: ActivityType.user_created,
          description: 'User account created by $createdBy',
          metadata: {
            'role': role,
            'displayName': displayName,
          },
        );

      } catch (e) {
        // If user creation fails in Firestore, delete the auth user
        if (_auth.currentUser != null &&
            _auth.currentUser!.email == email.trim()) {
          await _auth.currentUser!.delete();
        }
        rethrow;
      }

      return;
    });
  }

  static List<String> _getDefaultPermissions(String role) {
    switch (role) {
      case 'clientAdmin':
        return ['manage_users', 'manage_products', 'view_reports', 'manage_sales'];
      case 'salesInventoryManager':
        return ['manage_products', 'view_reports', 'manage_sales'];
      case 'cashier':
        return ['process_sales', 'view_products'];
      default:
        return ['view_products'];
    }
  }


  static Future<DocumentSnapshot> _getUserDocument(String uid) async {
    // Search across all tenants for the user
    final tenantsSnapshot = await _firestore
        .collection('tenants')
        .where('isActive', isEqualTo: true)
        .get();

    for (final tenantDoc in tenantsSnapshot.docs) {
      final userDoc = await _firestore
          .collection('tenants')
          .doc(tenantDoc.id)
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        return userDoc;
      }
    }

    throw Exception('User document not found');
  }




  // Get User Activities
  static Stream<QuerySnapshot> getUserActivities(
      String tenantId, {
        String? userId,
        int limit = 50,
      }) {
    Query query = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('user_activities')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }

    return query.snapshots();
  }



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
      await createUserWithDetails(
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

  static Future<void> _cacheOfflineData(
      String type,
      Map<String, dynamic> data,
      ) async {
    final offlineBox = Hive.box('offline_data');
    final pendingSync =
    offlineBox.get('pending_sync', defaultValue: []) as List;
    pendingSync.add({'type': type, 'data': data, 'timestamp': DateTime.now()});
    await offlineBox.put('pending_sync', pendingSync);
  }
  // Add to FirebaseService class
  static Future<void> createUserInTenant({
    required String tenantId,
    required String email,
    required String password,
    required String role,
    required String createdBy,
  }) async {
    return await _handleFirebaseCall(() async {
      // Validate password length
      if (password.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      try {
        // Create user in Firebase Auth
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );

        // Create user document in tenant's users collection
        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'email': email.trim(),
              'role': role,
              'createdBy': createdBy,
              'createdAt': FieldValue.serverTimestamp(),
              'isActive': true,
              'tenantId': tenantId,
              'lastLogin': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        // If user creation fails in Firestore, delete the auth user
        if (_auth.currentUser != null &&
            _auth.currentUser!.email == email.trim()) {
          await _auth.currentUser!.delete();
        }
        rethrow;
      }

      return;
    });
  }

  // Add to FirebaseService class
  static Future<void> createSuperAdminUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return await _handleFirebaseCall(() async {
      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Create super admin document
      await _firestore
          .collection('super_admins')
          .doc(userCredential.user!.uid)
          .set({
            'uid': userCredential.user!.uid,
            'email': email,
            'firstName': firstName,
            'lastName': lastName,
            'role': 'super_admin',
            'createdAt': FieldValue.serverTimestamp(),
            'isActive': true,
            'permissions': {
              'manage_tenants': true,
              'manage_system': true,
              'view_analytics': true,
              'manage_tickets': true,
            },
          });

      return;
    });
  }

  static Future<bool> checkSuperAdminExists() async {
    try {
      final snapshot = await _firestore
          .collection('super_admins')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Enhanced error handling wrapper


  // Tenant management
  // Update the createTenant method in FirebaseService



  // Product management
  static Future<void> addProduct({
    required String tenantId,
    required String name,
    required double price,
    required int stock,
    required String category,
    String? description,
  }) async {
    return await _handleFirebaseCall(() async {
      final productRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('products')
          .doc();

      await productRef.set({
        'id': productRef.id,
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
        'description': description ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lowStockAlert': stock <= 10,
      });

      // Check for low stock and trigger notification
      if (stock <= 10) {
        await _createLowStockNotification(tenantId, name, stock);
      }

      return;
    });
  }

  static Future<void> _createLowStockNotification(
    String tenantId,
    String productName,
    int stock,
  ) async {
    await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('notifications')
        .add({
          'type': 'low_stock',
          'title': 'Low Stock Alert',
          'message': '$productName is running low. Current stock: $stock',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // Sales management
  static Future<void> createSale({
    required String tenantId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double taxAmount,
    required String paymentMethod,
  }) async {
    return await _handleFirebaseCall(() async {
      final saleRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .doc();

      // Start a batch write for transaction
      final batch = _firestore.batch();

      // Create sale document
      batch.set(saleRef, {
        'id': saleRef.id,
        'items': items,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Update product stock
      for (final item in items) {
        final productRef = _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .doc(item['productId']);

        batch.update(productRef, {
          'stock': FieldValue.increment(-(item['quantity'] as int)),
        });
      }

      // Create notification for new sale
      batch.set(
        _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('notifications')
            .doc(),
        {
          'type': 'new_sale',
          'title': 'New Sale Completed',
          'message':
              'Sale #${saleRef.id} for \$${totalAmount.toStringAsFixed(2)}',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      // Cache offline data
      await _cacheOfflineData('sales', {
        'tenantId': tenantId,
        'saleId': saleRef.id,
        'totalAmount': totalAmount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      return;
    });
  }

  // Ticket system
  static Future<void> createTicket({
    required String tenantId,
    required String userId,
    required String subject,
    required String message,
    List<String>? attachments,
  }) async {
    return await _handleFirebaseCall(() async {
      await _firestore.collection('tickets').add({
        'tenantId': tenantId,
        'userId': userId,
        'subject': subject,
        'message': message,
        'attachments': attachments ?? [],
        'status': TicketStatus.open.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    });
  }

  static Future<void> updateTicket({
    required String ticketId,
    required String status,
    String? reply,
    String? assignedTo,
  }) async {
    return await _handleFirebaseCall(() async {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (reply != null) {
        updateData['replies'] = FieldValue.arrayUnion([
          {
            'message': reply,
            'userId': FirebaseAuth.instance.currentUser!.uid,
            'timestamp': FieldValue.serverTimestamp(),
          },
        ]);
      }

      if (assignedTo != null) {
        updateData['assignedTo'] = assignedTo;
      }

      await _firestore.collection('tickets').doc(ticketId).update(updateData);
      return;
    });
  }

  // User management
  static Future<void> createUser({
    required String tenantId,
    required String email,
    required String password,
    required String role,
    required String createdBy,
  }) async {
    return await _handleFirebaseCall(() async {
      // Validate password length
      if (password.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      try {
        // Create user in Firebase Auth
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );

        // Create user document in tenant's users collection
        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'email': email.trim(),
              'role': role,
              'createdBy': createdBy,
              'createdAt': FieldValue.serverTimestamp(),
              'isActive': true,
              'tenantId': tenantId,
            });
      } catch (e) {
        // If user creation fails in Firestore, delete the auth user
        if (_auth.currentUser != null &&
            _auth.currentUser!.email == email.trim()) {
          await _auth.currentUser!.delete();
        }
        rethrow;
      }

      return;
    });
  } // Analytics and reporting

  static Stream<QuerySnapshot> getSalesAnalytics(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .snapshots();
  }

  static Future<Map<String, dynamic>> getDashboardStats(String tenantId) async {
    return await _handleFirebaseCall(() async {
      final salesSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .where(
            'createdAt',
            isGreaterThan: DateTime.now().subtract(Duration(days: 30)),
          )
          .get();

      final productsSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('products')
          .get();

      final totalRevenue = salesSnapshot.docs.fold(0.0, (sum, doc) {
        final data = doc.data();
        return sum + (data['totalAmount'] as double);
      });

      final totalSales = salesSnapshot.docs.length;
      final lowStockProducts = productsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['lowStockAlert'] == true;
      }).length;

      return {
        'totalRevenue': totalRevenue,
        'totalSales': totalSales,
        'lowStockProducts': lowStockProducts,
        'totalProducts': productsSnapshot.docs.length,
      };
    });
  }

  // Offline data synchronization

  static Future<void> syncOfflineData(String tenantId) async {
    final offlineBox = Hive.box('offline_data');
    final pendingSync =
        offlineBox.get('pending_sync', defaultValue: []) as List;

    for (final syncItem in pendingSync) {
      try {
        if (syncItem['type'] == 'sales') {
          // Recreate sale with offline data
          await createSale(
            tenantId: tenantId,
            items: [], // You'd reconstruct from cached data
            totalAmount: syncItem['data']['totalAmount'],
            taxAmount: 0.0,
            paymentMethod: 'cash',
          );
        }
      } catch (e) {
        // If sync fails, keep in pending for next attempt
        continue;
      }
    }

    // Clear successfully synced data
    await offlineBox.put('pending_sync', []);
  }


}

// =============================
// ENUMS AND MODELS
// =============================
enum UserRole { superAdmin, clientAdmin, cashier, salesInventoryManager }

enum TicketStatus { open, inProgress, closed }



// =============================
// PROVIDERS (STATE MANAGEMENT)
// =============================
// =============================
// ENHANCED AUTH PROVIDER
// =============================
// Enhanced AuthProvider with proper casting
class MyAuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  Tenant? _currentTenant;
  bool _isLoading = false;
  String? _error;

  AppUser? get currentUser => _currentUser;
  Tenant? get currentTenant => _currentTenant;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      if (!AppUtils.isEmailValid(email)) {
        throw 'Please enter a valid email address';
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _loadUserData(userCredential.user!.uid);

      // Sync any offline data
      if (_currentTenant != null) {
        await FirebaseService.syncOfflineData(_currentTenant!.id);
      }

      // Log successful login
      if (_currentUser != null && !_currentUser!.isSuperAdmin) {
        await FirebaseService._logUserActivity(
          tenantId: _currentUser!.tenantId,
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email,
          userDisplayName: _currentUser!.displayName,
          action: ActivityType.user_login,
          description: 'User logged in successfully',
          metadata: {
            'loginMethod': 'email_password',
          },
        );
      }

    } on FirebaseAuthException catch (e) {
      _error = _handleAuthError(e);
      print('Firebase Auth Error: ${e.code} - ${e.message}');
    } catch (e) {
      _error = 'Login failed: $e';
      print('Login Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Loading user data for UID: $uid');

      // First, check if user is super admin
      final superAdminSnapshot = await FirebaseFirestore.instance
          .collection('super_admins')
          .doc(uid)
          .get();

      if (superAdminSnapshot.exists) {
        final adminData = superAdminSnapshot.data() as Map<String, dynamic>? ?? {};
        print('Super admin data: $adminData');

        _currentUser = AppUser(
          uid: uid,
          email: FirebaseAuth.instance.currentUser?.email ?? 'unknown@email.com',
          displayName: '${adminData['firstName'] ?? 'Admin'} ${adminData['lastName'] ?? ''}'.trim(),
          role: UserRole.superAdmin,
          tenantId: 'super_admin',
          isActive: adminData['isActive'] ?? true,
          createdAt: adminData['createdAt'] != null
              ? (adminData['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
          createdBy: adminData['createdBy'] ?? 'system',
          lastLogin: adminData['lastLogin'] != null
              ? (adminData['lastLogin'] as Timestamp).toDate()
              : null,
        );
        print('Super admin user loaded successfully');
        return;
      }

      // Search for user in tenants
      final tenantsSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .where('isActive', isEqualTo: true)
          .get();

      print('Found ${tenantsSnapshot.docs.length} active tenants');

      bool userFound = false;

      for (final tenantDoc in tenantsSnapshot.docs) {
        final userDoc = await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tenantDoc.id)
            .collection('users')
            .doc(uid)
            .get();

        if (userDoc.exists) {
          print('User found in tenant: ${tenantDoc.id}');
          final userData = userDoc.data() as Map<String, dynamic>? ?? {};

          try {
            _currentUser = AppUser.fromFirestore(userDoc);
            _currentTenant = Tenant.fromFirestore(tenantDoc);
            userFound = true;
            print('User data loaded successfully: ${_currentUser?.email}');
            break;
          } catch (e) {
            print('Error parsing user data: $e');
            throw Exception('Failed to parse user data: $e');
          }
        }
      }

      if (!userFound) {
        print('User not found in any tenant');
        throw Exception('User not found in any active tenant. Please contact administrator.');
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';
      print('Error in _loadUserData: $e');
      await logout();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // Log logout activity if user is logged in
    if (_currentUser != null && !_currentUser!.isSuperAdmin) {
      await FirebaseService._logUserActivity(
        tenantId: _currentUser!.tenantId,
        userId: _currentUser!.uid,
        userEmail: _currentUser!.email,
        userDisplayName: _currentUser!.displayName,
        action: ActivityType.user_logout,
        description: 'User logged out',
      );
    }

    await FirebaseAuth.instance.signOut();
    _currentUser = null;
    _currentTenant = null;
    _error = null;
    notifyListeners();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Login failed: ${e.message}';
    }
  }
}


class TenantProvider with ChangeNotifier {
  final List<Tenant> _tenants = [];
  bool _isLoading = false;
  String? _error;

  List<Tenant> get tenants => _tenants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllTenants() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Loading tenants from Firestore...');

      final snapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .get();

      print('Found ${snapshot.docs.length} tenants');

      _tenants.clear();
      _tenants.addAll(
        snapshot.docs.map((doc) {
          print('Processing tenant: ${doc.id} - ${doc.data()['businessName']}');
          return Tenant.fromFirestore(doc);
        }),
      );

      print('Successfully loaded ${_tenants.length} tenants');
    } catch (e) {
      _error = 'Failed to load tenants: $e';
      print('Error loading tenants: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTenantSubscription(
    String tenantId,
    String plan,
    DateTime expiry,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .update({
            'subscriptionPlan': plan,
            'subscriptionExpiry': expiry,
            'isActive': expiry.isAfter(DateTime.now()),
          });

      // Reload tenants
      await loadAllTenants();
    } catch (e) {
      _error = 'Failed to update subscription: $e';
      notifyListeners();
    }
  }
}

// =============================
// WIDGETS - CORE UI COMPONENTS
// =============================



class MultiTenantSaaSApp extends StatelessWidget {
  const MultiTenantSaaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MyAuthProvider()),
        ChangeNotifierProvider(create: (_) => TenantProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadSavedTheme()),
      ],
      // 👇 Use Builder to get a new context with access to the providers
      child: Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();

          return MaterialApp(
            title: 'Multi-Tenant SaaS',
            theme: ThemeData.light().copyWith(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            darkTheme: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeProvider.useSystemTheme
                ? ThemeMode.system
                : (themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light),
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return FutureBuilder<bool>(
      future: _checkSuperAdminExists(),
      builder: (context, snapshot) {
        // Show loading while checking
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen();
        }

        // If no super admin exists, show setup screen
        if (snapshot.hasData && !snapshot.data!) {
          return SuperAdminSetupScreen();
        }

        // Existing auth logic
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return SplashScreen();
            }

            if (userSnapshot.hasData && authProvider.currentUser != null) {
              if (!authProvider.currentUser!.isActive) {
                return AccountDisabledScreen();
              }

              if (authProvider.currentUser!.isSuperAdmin) {
                return SuperAdminDashboard();
              } else {
                return MainPOSScreen();
              }
            }

            return LoginScreen();
          },
        );
      },
    );
  }

  Future<bool> _checkSuperAdminExists() async {
    try {
      return await FirebaseService.checkSuperAdminExists();
    } catch (e) {
      print('Error checking super admin: $e');
      return false;
    }
  }
}

// =============================
// AUTH SCREENS
// =============================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            Text(
              'Multi-Tenant SaaS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _obscurePassword = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ThemeSelectorBottomSheet(),
    );
  }

  Widget _buildSocialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2D3748)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final gradientColors = themeProvider.getCurrentGradientColors();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                margin: const EdgeInsets.all(20),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    elevation: 24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      onPressed: () => _showThemeSelector(context),
                                      icon: const Icon(
                                        Icons.palette_rounded,
                                        color: Colors.white,
                                      ),
                                      tooltip: 'Change Theme',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to continue your journey',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : const Color(0xFF718096),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 32),
                              if (authProvider.error != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          authProvider.error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        // onTap: () => authProvider.clearError(),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _emailController,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    labelStyle: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF718096),
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(right: 12, left: 16),
                                      child: const Icon(
                                        Icons.email_rounded,
                                        color: Color(0xFF667EEA),
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF2D3748) : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF667EEA),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!AppUtils.isEmailValid(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  controller: _passwordController,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF718096),
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(right: 12, left: 16),
                                      child: const Icon(
                                        Icons.lock_rounded,
                                        color: Color(0xFF667EEA),
                                      ),
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 16),
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          color: const Color(0xFF718096),
                                        ),
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF2D3748) : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF667EEA),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              MouseRegion(
                                onEnter: (_) => setState(() => _isHovering = true),
                                onExit: (_) => setState(() => _isHovering = false),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _isHovering
                                        ? [
                                      BoxShadow(
                                        color: const Color(0xFF667EEA).withOpacity(0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ]
                                        : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : () async {
                                      if (_formKey.currentState!.validate()) {
                                        await authProvider.login(
                                          _emailController.text.trim(),
                                          _passwordController.text,
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'New to our platform?',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF718096),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) => const ClientSignupScreen(),
                                        transitionsBuilder: (_, animation, __, child) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          );
                                        },
                                      ),
                                    ),
                                    child: const Text(
                                      'Create account',
                                      style: TextStyle(
                                        color: Color(0xFF667EEA),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: isDark ? Colors.white24 : Colors.grey[300],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : const Color(0xFF718096),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: isDark ? Colors.white24 : Colors.grey[300],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildSocialButton(
                                    icon: Icons.g_mobiledata_rounded,
                                    color: Colors.red,
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 16),
                                  _buildSocialButton(
                                    icon: Icons.facebook_rounded,
                                    color: Colors.blue,
                                    onTap: () {},
                                  ),
                                  const SizedBox(width: 16),
                                  _buildSocialButton(
                                    icon: Icons.apple_rounded,
                                    color: Colors.black,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountDisabledScreen extends StatelessWidget {
  const AccountDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final gradientColors = themeProvider.getCurrentGradientColors();

    // Handle system theme
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = themeProvider.useSystemTheme
        ? brightness == Brightness.dark
        : themeProvider.isDarkMode;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Account Disabled',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Your account has been disabled. Please contact your administrator or check your subscription status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () =>
                    Provider.of<MyAuthProvider>(context, listen: false).logout(),
                child: Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================
// CLIENT SIGNUP / ONBOARDING
// =============================
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

      await FirebaseService.createTenant(
        tenantId: tenantId,
        businessName: _businessName,
        adminEmail: _adminEmail,
        adminPassword: _adminPassword,
        subscriptionPlan: _subscriptionPlan,
      );

      // Add initial products
      for (final product in _initialProducts) {
        await FirebaseService.addProduct(
          tenantId: tenantId,
          name: product['name'],
          price: product['price'],
          stock: product['stock'],
          category: product['category'],
        );
      }

      // Add initial users
      for (final user in _initialUsers) {
        await FirebaseService.createUser(
          tenantId: tenantId,
          email: user['email'],
          password: 'temp123', // In production, generate secure temp password
          role: user['role'],
          createdBy: 'system',
        );
      }

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

// =============================
// DIALOGS AND MODALS
// =============================

class AddUserDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const AddUserDialog({super.key, required this.onSave});

  @override
  _AddUserDialogState createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final _emailController = TextEditingController();
  String _selectedRole = 'cashier';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add User'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 20),
          DropdownButtonFormField(
            initialValue: _selectedRole,
            items: [
              DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
              DropdownMenuItem(
                value: 'salesInventoryManager',
                child: Text('Sales & Inventory Manager'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _selectedRole = value.toString()),
            decoration: InputDecoration(labelText: 'Role'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(onPressed: _saveUser, child: Text('Save')),
      ],
    );
  }

  void _saveUser() {
    final user = {'email': _emailController.text, 'role': _selectedRole};
    widget.onSave(user);
    Navigator.pop(context);
  }
}



class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(title, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// Create the new screen
class SuperAdminManagementScreen extends StatefulWidget {
  const SuperAdminManagementScreen({super.key});

  @override
  _SuperAdminManagementScreenState createState() =>
      _SuperAdminManagementScreenState();
}

class _SuperAdminManagementScreenState
    extends State<SuperAdminManagementScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  List<Map<String, dynamic>> _superAdmins = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSuperAdmins();
  }

  Future<void> _loadSuperAdmins() async {
    setState(() => _isLoading = true);
    // You'll need to implement this method in SuperAdminSetup class
    _superAdmins = await SuperAdminSetup.getSuperAdmins();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Super Admin Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),

            // Add New Super Admin Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Super Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: InputDecoration(labelText: 'Last Name'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addSuperAdmin,
                      child: Text('Add Super Admin'),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Existing Super Admins
            Text(
              'Existing Super Admins',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),

            _isLoading
                ? Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: _superAdmins.length,
                      itemBuilder: (context, index) {
                        final admin = _superAdmins[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              Icons.admin_panel_settings,
                              color: Colors.blue,
                            ),
                            title: Text(
                              '${admin['firstName']} ${admin['lastName']}',
                            ),
                            subtitle: Text(admin['email']),
                            trailing: Switch(
                              value: admin['isActive'] ?? false,
                              onChanged: (value) {
                                // Implement activate/deactivate
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSuperAdmin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      await FirebaseService.createSuperAdminUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      // Clear form
      _emailController.clear();
      _passwordController.clear();
      _firstNameController.clear();
      _lastNameController.clear();

      // Reload list
      await _loadSuperAdmins();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Super Admin added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenants')
            .doc(authProvider.currentUser!.tenantId)
            .collection('users')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text(user['email']),
                  subtitle: Text(user['role']),
                  trailing: Switch(
                    value: user['isActive'] ?? false,
                    onChanged: (value) {
                      // Update user active status
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (context) => AddUserDialog(
            onSave: (user) => FirebaseService.createUser(
              tenantId: authProvider.currentUser!.tenantId,
              email: user['email'],
              password: 'temp123',
              role: user['role'],
              createdBy: authProvider.currentUser!.uid,
            ),
          ),
        ),
        child: Icon(Icons.person_add),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final tenant = authProvider.currentTenant;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.business, size: 40),
                  ),
                  SizedBox(height: 16),
                  Text(
                    tenant!.businessName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Subscription: ${tenant.subscriptionPlan}'),
                  Text(
                    'Expires: ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry)}',
                  ),
                  SizedBox(height: 16),
                  tenant.isSubscriptionActive
                      ? Chip(
                          label: Text(
                            'Active',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        )
                      : Chip(
                          label: Text(
                            'Expired',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                        ),
                ],
              ),
            ),
          ),

          ElevatedButton(onPressed: (){
            final authProvider = Provider.of<MyAuthProvider>(context,listen: false);
            authProvider.logout();

          }, child: Text("Logout")),
          SizedBox(height: 20),

          // Expanded(
          //   child: ListView(
          //     children: [
          //       ListTile(
          //         leading: Icon(Icons.support),
          //         title: Text('Support Tickets'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => TicketsScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.settings),
          //         title: Text('Branding & Settings'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => BrandingScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.analytics),
          //         title: Text('Analytics & Reports'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => AnalyticsScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.notifications),
          //         title: Text('Notifications'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => NotificationsScreen()),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

// =============================
// SUPER ADMIN DASHBOARD
// =============================

// super_admin_setup.dart
// super_admin_setup_screen.dart

class SuperAdminSetupScreen extends StatefulWidget {
  const SuperAdminSetupScreen({super.key});

  @override
  _SuperAdminSetupScreenState createState() => _SuperAdminSetupScreenState();
}

class _SuperAdminSetupScreenState extends State<SuperAdminSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final authProvider=Provider.of<MyAuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(actions: [       ],),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Icon(
                        Icons.admin_panel_settings,
                        size: 80,
                        color: Colors.blue,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Super Admin Setup',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Create the master administrator account',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      SizedBox(height: 30),

                      // Error Message
                      if (_error != null)
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // First Name
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter first name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Last Name
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter last name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email address';
                          }
                          if (!AppUtils.isEmailValid(value)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 30),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createSuperAdmin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text(
                                  'Create Super Admin',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),

                      SizedBox(height: 20),
                      Divider(),
                      SizedBox(height: 10),

                      // Information
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Super Admin Permissions:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('• Manage all tenants and subscriptions'),
                            Text('• Access system-wide analytics'),
                            Text('• Manage support tickets'),
                            Text('• Configure system settings'),
                            Text('• Create additional super admins'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createSuperAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use the FirebaseService to create super admin
      await FirebaseService.createSuperAdminUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Super Admin created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Auto-login the new super admin
      final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
      await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to create super admin: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class SuperAdminSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to create the first super admin
  static Future<void> createSuperAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      print('Starting super admin creation...');

      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User user = userCredential.user!;
      print('Firebase Auth user created: ${user.uid}');

      // Create super admin document
      await _firestore.collection('super_admins').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': 'super_admin',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'permissions': {
          'manage_tenants': true,
          'manage_system': true,
          'view_analytics': true,
          'manage_tickets': true,
        },
      });

      print('Super admin document created successfully!');
      print('Super Admin Details:');
      print('- Email: $email');
      print('- UID: ${user.uid}');
      print('- Name: $firstName $lastName');
    } catch (e) {
      print('Error creating super admin: $e');
      rethrow;
    }
  }

  // Check if any super admin exists
  static Future<bool> hasSuperAdmin() async {
    try {
      final snapshot = await _firestore
          .collection('super_admins')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking super admin: $e');
      return false;
    }
  }

  // Get all super admins (for management)
  static Future<List<Map<String, dynamic>>> getSuperAdmins() async {
    try {
      final snapshot = await _firestore.collection('super_admins').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting super admins: $e');
      return [];
    }
  }
}

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  _SuperAdminDashboardState createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load tenants when super admin dashboard initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantProvider = Provider.of<TenantProvider>(
        context,
        listen: false,
      );
      tenantProvider.loadAllTenants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> superAdminScreens = [
      /////////
      SuperAdminHome(),
      TenantsManagementScreen(),
SuperAdminAnalyticsScreen(),      SuperAdminTicketsScreen(),
      SuperAdminManagementScreen(), // Make sure this is included
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Super Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Refresh tenants list
              final tenantProvider = Provider.of<TenantProvider>(
                context,
                listen: false,
              );
              tenantProvider.loadAllTenants();
            },
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () =>
                Provider.of<MyAuthProvider>(context, listen: false).logout(),
          ),
        ],
      ),
      body: superAdminScreens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedIconTheme: IconThemeData(color: Colors.black),
        unselectedIconTheme: IconThemeData(color: Colors.grey),
        selectedItemColor: Color(0xff000000),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        unselectedLabelStyle: TextStyle(color: Colors.grey.shade800),
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Tenants'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.support), label: 'Support'),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admins',
          ),
        ],
      ),
    );
  }
}

class TenantsManagementScreen extends StatelessWidget {
  const TenantsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    // Load tenants when this screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tenantProvider.tenants.isEmpty) {
        tenantProvider.loadAllTenants();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Tenants Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => tenantProvider.loadAllTenants(),
          ),
        ],
      ),
      body: tenantProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : tenantProvider.tenants.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No Tenants Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'There are no tenants in the system yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => tenantProvider.loadAllTenants(),
                    child: Text('Refresh'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: tenantProvider.tenants.length,
              itemBuilder: (context, index) {
                final tenant = tenantProvider.tenants[index];
                return TenantManagementCard(tenant: tenant);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTenantDialog(context),
        tooltip: 'Create New Tenant',
        child: Icon(Icons.add_business),
      ),
    );
  }

  void _showCreateTenantDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => CreateTenantDialog());
  }
}

class TenantManagementCard extends StatefulWidget {
  final Tenant tenant;
  const TenantManagementCard({super.key, required this.tenant});

  @override
  _TenantManagementCardState createState() => _TenantManagementCardState();
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _TenantManagementCardState extends State<TenantManagementCard> {
  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 40,
                  color: widget.tenant.isSubscriptionActive
                      ? Colors.green
                      : Colors.red,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tenant.businessName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('ID: ${widget.tenant.id}'),
                      Text('Plan: ${widget.tenant.subscriptionPlan}'),
                      Text(
                        'Expires: ${DateFormat('MMM dd, yyyy').format(widget.tenant.subscriptionExpiry)}',
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: widget.tenant.isActive,
                      onChanged: (value) {
                        _updateTenantStatus(value);
                      },
                    ),
                    SizedBox(height: 4),
                    widget.tenant.isSubscriptionActive
                        ? Chip(
                            label: Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: Colors.green,
                          )
                        : Chip(
                            label: Text(
                              'Expired',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: Colors.red,
                          ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _renewSubscription(context),
                    icon: Icon(Icons.autorenew),
                    label: Text('Renew'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewDetails(context),
                    icon: Icon(Icons.visibility),
                    label: Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewUsers(context),
                    icon: Icon(Icons.people),
                    label: Text('Users'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateTenantStatus(bool isActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenant.id)
          .update({'isActive': isActive});

      // Reload tenants to reflect the change
      final tenantProvider = Provider.of<TenantProvider>(
        context,
        listen: false,
      );
      await tenantProvider.loadAllTenants();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tenant status updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating tenant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _renewSubscription(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RenewSubscriptionDialog(
        tenant: widget.tenant,
        onRenew: (plan, expiry) {
          Provider.of<TenantProvider>(
            context,
            listen: false,
          ).updateTenantSubscription(widget.tenant.id, plan, expiry);
        },
      ),
    );
  }

  void _viewDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TenantDetailsDialog(tenant: widget.tenant),
    );
  }

  void _viewUsers(BuildContext context) {
    // Navigate to tenant users screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.tenant.businessName} - Users'),
        content: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('tenants')
              .doc(widget.tenant.id)
              .collection('users')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error loading users: ${snapshot.error}');
            }

            final users = snapshot.data!.docs;
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(Icons.person),
                    title: Text(user['email']),
                    subtitle: Text(user['role']),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

class RenewSubscriptionDialog extends StatefulWidget {
  final Tenant tenant;
  final Function(String, DateTime) onRenew;
  const RenewSubscriptionDialog({super.key, required this.tenant, required this.onRenew});

  @override
  _RenewSubscriptionDialogState createState() =>
      _RenewSubscriptionDialogState();
}

class _RenewSubscriptionDialogState extends State<RenewSubscriptionDialog> {
  String _selectedPlan = 'monthly';
  DateTime _selectedDate = DateTime.now().add(Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Renew Subscription - ${widget.tenant.businessName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField(
            initialValue: _selectedPlan,
            items: [
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (value) =>
                setState(() => _selectedPlan = value.toString()),
            decoration: InputDecoration(labelText: 'Subscription Plan'),
          ),

          SizedBox(height: 16),

          if (_selectedPlan == 'custom')
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              child: Text(
                'Select Expiry Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final expiry = _selectedPlan == 'monthly'
                ? DateTime.now().add(Duration(days: 30))
                : _selectedPlan == 'yearly'
                ? DateTime.now().add(Duration(days: 365))
                : _selectedDate;

            widget.onRenew(_selectedPlan, expiry);
            Navigator.pop(context);
          },
          child: Text('Renew'),
        ),
      ],
    );
  }
}

class TenantDetailsDialog extends StatelessWidget {
  final Tenant tenant;
  const TenantDetailsDialog({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Tenant Details - ${tenant.businessName}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailRow('Business Name', tenant.businessName),
            _DetailRow('Subscription Plan', tenant.subscriptionPlan),
            _DetailRow(
              'Subscription Expiry',
              DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry),
            ),
            _DetailRow(
              'Status',
              tenant.isSubscriptionActive ? 'Active' : 'Expired',
            ),
            _DetailRow(
              'Primary Color',
              tenant.branding['primaryColor'] ?? 'Not set',
            ),
            _DetailRow('Currency', tenant.branding['currency'] ?? 'USD'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class CreateTenantDialog extends StatefulWidget {
  const CreateTenantDialog({super.key});

  @override
  _CreateTenantDialogState createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<CreateTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedPlan = 'monthly';
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_business, color: Colors.blue),
          SizedBox(width: 10),
          Text('Create New Tenant'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(12),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              Text(
                'Business Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: 'Business Name *',
                  hintText: 'Enter business name',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter business name';
                  }
                  if (value.length < 2) {
                    return 'Business name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              Text(
                'Admin Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _adminEmailController,
                decoration: InputDecoration(
                  labelText: 'Admin Email *',
                  hintText: 'admin@company.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter admin email';
                  }
                  if (!AppUtils.isEmailValid(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _adminPasswordController,
                decoration: InputDecoration(
                  labelText: 'Admin Password *',
                  hintText: 'Enter password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12),

              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  hintText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm password';
                  }
                  if (value != _adminPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              Text(
                'Subscription Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _selectedPlan,
                decoration: InputDecoration(
                  labelText: 'Subscription Plan *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'monthly',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.blue),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$29/month',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'yearly',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_view_month, color: Colors.green),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Yearly',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$299/year (Save 15%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPlan = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a subscription plan';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Plan Features
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan Includes:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildFeature('✓ Unlimited Products'),
                    _buildFeature('✓ Sales Management'),
                    _buildFeature('✓ User Management'),
                    _buildFeature('✓ Analytics Dashboard'),
                    _buildFeature('✓ Support Tickets'),
                    _buildFeature('✓ Custom Branding'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createTenant,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Create Tenant'),
        ),
      ],
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }

  Future<void> _createTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Generate tenant ID
      final tenantId =
          '${_businessNameController.text.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '_',
          )}_${DateTime.now().millisecondsSinceEpoch}';

      print('Creating tenant: $tenantId');

      // Create the tenant using FirebaseService
      await FirebaseService.createTenant(
        tenantId: tenantId,
        businessName: _businessNameController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
        adminPassword: _adminPasswordController.text,
        subscriptionPlan: _selectedPlan,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Tenant created successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Close dialog
      Navigator.pop(context);

      // Reload tenants list
      final tenantProvider = Provider.of<TenantProvider>(
        context,
        listen: false,
      );
      await tenantProvider.loadAllTenants();
    } catch (e) {
      setState(() {
        _error = 'Failed to create tenant: $e';
      });
      print('Error creating tenant: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}

// =============================
// ADDITIONAL FEATURES
// =============================
class TicketsScreen extends StatelessWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Support Tickets')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .where('tenantId', isEqualTo: authProvider.currentUser!.tenantId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: _getStatusIcon(ticket['status']),
                  title: Text(ticket['subject']),
                  subtitle: Text(ticket['message']),
                  trailing: Chip(
                    label: Text(
                      ticket['status'],
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(ticket['status']),
                  ),
                  onTap: () => _viewTicket(context, tickets[index].id, ticket),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createTicket(context),
        child: Icon(Icons.add),
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icon(Icons.mark_email_unread, color: Colors.orange);
      case 'inProgress':
        return Icon(Icons.hourglass_bottom, color: Colors.blue);
      case 'closed':
        return Icon(Icons.check_circle, color: Colors.green);
      default:
        return Icon(Icons.email);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _createTicket(BuildContext context) {
    showDialog(context: context, builder: (context) => CreateTicketDialog());
  }

  void _viewTicket(
    BuildContext context,
    String ticketId,
    Map<String, dynamic> ticket,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          TicketDetailsDialog(ticketId: ticketId, ticket: ticket),
    );
  }
}

class CreateTicketDialog extends StatefulWidget {
  const CreateTicketDialog({super.key});

  @override
  _CreateTicketDialogState createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<CreateTicketDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return AlertDialog(
      title: Text('Create Support Ticket'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(labelText: 'Subject'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(labelText: 'Message'),
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            FirebaseService.createTicket(
              tenantId: authProvider.currentUser!.tenantId,
              userId: authProvider.currentUser!.uid,
              subject: _subjectController.text,
              message: _messageController.text,
            );
            Navigator.pop(context);
          },
          child: Text('Submit'),
        ),
      ],
    );
  }
}

class TicketDetailsDialog extends StatelessWidget {
  final String ticketId;
  final Map<String, dynamic> ticket;
  const TicketDetailsDialog({super.key, required this.ticketId, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(ticket['subject']),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ticket['message'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),
            if (ticket['replies'] != null) ...[
              Text('Replies:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(ticket['replies'] as List)
                  .map(
                    (reply) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('- ${reply['message']}'),
                    ),
                  )
                  ,
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}

class SuperAdminTicketsScreen extends StatelessWidget {
  const SuperAdminTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('All Support Tickets')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final tickets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: _getStatusIcon(ticket['status']),
                  title: Text(ticket['subject']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ticket['message']),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('tenants')
                            .doc(ticket['tenantId'])
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final tenant = Tenant.fromFirestore(snapshot.data!);
                            return Text(
                              'From: ${tenant.businessName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            );
                          }
                          return SizedBox();
                        },
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      ticket['status'],
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: _getStatusColor(ticket['status']),
                  ),
                  onTap: () =>
                      _manageTicket(context, tickets[index].id, ticket),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icon(Icons.mark_email_unread, color: Colors.orange);
      case 'inProgress':
        return Icon(Icons.hourglass_bottom, color: Colors.blue);
      case 'closed':
        return Icon(Icons.check_circle, color: Colors.green);
      default:
        return Icon(Icons.email);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _manageTicket(
    BuildContext context,
    String ticketId,
    Map<String, dynamic> ticket,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          ManageTicketDialog(ticketId: ticketId, ticket: ticket),
    );
  }
}

class ManageTicketDialog extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticket;
  const ManageTicketDialog({super.key, required this.ticketId, required this.ticket});

  @override
  _ManageTicketDialogState createState() => _ManageTicketDialogState();
}

class _ManageTicketDialogState extends State<ManageTicketDialog> {
  final _replyController = TextEditingController();
  String _selectedStatus = 'open';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.ticket['status'];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Manage Ticket - ${widget.ticket['subject']}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.ticket['message'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 16),

            DropdownButtonFormField(
              initialValue: _selectedStatus,
              items: [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(
                  value: 'inProgress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) =>
                  setState(() => _selectedStatus = value.toString()),
              decoration: InputDecoration(labelText: 'Status'),
            ),

            SizedBox(height: 16),

            TextField(
              controller: _replyController,
              decoration: InputDecoration(labelText: 'Reply Message'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(onPressed: _updateTicket, child: Text('Update')),
      ],
    );
  }

  void _updateTicket() {
    FirebaseService.updateTicket(
      ticketId: widget.ticketId,
      status: _selectedStatus,
      reply: _replyController.text.isNotEmpty ? _replyController.text : null,
    );
    Navigator.pop(context);
  }
}

class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  _BrandingScreenState createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _currencyController = TextEditingController();
  final _taxRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final authProvider = context.read<MyAuthProvider>();
    final branding = authProvider.currentTenant?.branding ?? {};

    _primaryColorController.text = branding['primaryColor'] ?? '#2196F3';
    _secondaryColorController.text = branding['secondaryColor'] ?? '#FF9800';
    _currencyController.text = branding['currency'] ?? 'USD';
    _taxRateController.text = (branding['taxRate'] ?? 0.0).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Branding & Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _primaryColorController,
              decoration: InputDecoration(
                labelText: 'Primary Color (Hex)',
                hintText: '#2196F3',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _secondaryColorController,
              decoration: InputDecoration(
                labelText: 'Secondary Color (Hex)',
                hintText: '#FF9800',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _currencyController,
              decoration: InputDecoration(
                labelText: 'Currency',
                hintText: 'USD',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _taxRateController,
              decoration: InputDecoration(
                labelText: 'Tax Rate (%)',
                hintText: '0.0',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() {
    final authProvider = context.read<MyAuthProvider>();

    FirebaseFirestore.instance
        .collection('tenants')
        .doc(authProvider.currentUser!.tenantId)
        .update({
          'branding': {
            'primaryColor': _primaryColorController.text,
            'secondaryColor': _secondaryColorController.text,
            'currency': _currencyController.text,
            'taxRate': double.parse(_taxRateController.text),
          },
        });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Settings updated successfully')));
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Analytics & Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getSalesAnalytics(
          authProvider.currentUser!.tenantId,
          DateTime.now().subtract(Duration(days: 30)),
          DateTime.now(),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final sales = snapshot.data!.docs;
          final salesData = _prepareSalesData(sales);

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Sales Analytics - Last 30 Days',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(),
                    series: <CartesianSeries>[
                      LineSeries<Map<String, dynamic>, String>(
                        dataSource: salesData,
                        xValueMapper: (data, _) => data['date'],
                        yValueMapper: (data, _) => data['amount'],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _prepareSalesData(
    List<QueryDocumentSnapshot> sales,
  ) {
    final Map<String, double> dailySales = {};

    for (final sale in sales) {
      final data = sale.data() as Map<String, dynamic>;
      final date = DateFormat(
        'MMM dd',
      ).format((data['createdAt'] as Timestamp).toDate());
      final amount = data['totalAmount'] as double;

      dailySales[date] = (dailySales[date] ?? 0.0) + amount;
    }

    return dailySales.entries
        .map((e) => {'date': e.key, 'amount': e.value})
        .toList();
  }
}

class SystemAnalyticsScreen extends StatelessWidget {
  const SystemAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'System Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <CartesianSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: _prepareTenantData(tenantProvider.tenants),
                    xValueMapper: (data, _) => data['name'],
                    yValueMapper: (data, _) => data['value'],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _prepareTenantData(List<Tenant> tenants) {
    return tenants
        .map(
          (tenant) => {
            'name': tenant.businessName.length > 10
                ? '${tenant.businessName.substring(0, 10)}...'
                : tenant.businessName,
            'value': tenant.isSubscriptionActive ? 1 : 0,
          },
        )
        .toList();
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenants')
            .doc(authProvider.currentUser!.tenantId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification =
                  notifications[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: _getNotificationIcon(notification['type']),
                  title: Text(notification['title']),
                  subtitle: Text(notification['message']),
                  trailing: notification['isRead']
                      ? null
                      : Chip(
                          label: Text(
                            'New',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                  onTap: () => _markAsRead(notifications[index].id, context),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Icon _getNotificationIcon(String type) {
    switch (type) {
      case 'low_stock':
        return Icon(Icons.warning, color: Colors.orange);
      case 'new_sale':
        return Icon(Icons.attach_money, color: Colors.green);
      case 'subscription_expired':
        return Icon(Icons.error, color: Colors.red);
      case 'subscription_reminder':
        return Icon(Icons.notifications, color: Colors.blue);
      default:
        return Icon(Icons.notifications);
    }
  }

  void _markAsRead(String notificationId, BuildContext context) {
    final authProvider = context.read<MyAuthProvider>();

    FirebaseFirestore.instance
        .collection('tenants')
        .doc(authProvider.currentUser!.tenantId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}

// =============================
// UTILITY FUNCTIONS
// =============================
class AppUtils {
  static String formatCurrency(double amount, String currency) {
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  static bool isEmailValid(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}

// =============================
// OFFLINE SUPPORT & CACHING
// =============================
class OfflineManager {
  static final Box _cache = Hive.box('app_cache');
  static final Box _offlineData = Hive.box('offline_data');

  static Future<void> cacheData(String key, dynamic data) async {
    await _cache.put(key, {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static dynamic getCachedData(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) {
    final cached = _cache.get(key);
    if (cached != null) {
      final timestamp = cached['timestamp'] as int;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
      if (age < maxAge) {
        return cached['data'];
      }
    }
    return null;
  }

  static Future<void> queueOfflineAction(
    String action,
    Map<String, dynamic> data,
  ) async {
    final pending =
        _offlineData.get('pending_actions', defaultValue: []) as List;
    pending.add({'action': action, 'data': data, 'timestamp': DateTime.now()});
    await _offlineData.put('pending_actions', pending);
  }

  static Future<void> processPendingActions(String tenantId) async {
    final pending =
        _offlineData.get('pending_actions', defaultValue: []) as List;
    final failed = [];

    for (final action in pending) {
      try {
        switch (action['action']) {
          case 'create_sale':
            await FirebaseService.createSale(
              tenantId: tenantId,
              items: action['data']['items'],
              totalAmount: action['data']['totalAmount'],
              taxAmount: action['data']['taxAmount'],
              paymentMethod: action['data']['paymentMethod'],
            );
            break;
          case 'update_product':
            // Implement product update
            break;
        }
      } catch (e) {
        failed.add(action);
      }
    }

    await _offlineData.put('pending_actions', failed);
  }
}

// =============================
// ERROR BOUNDARY & EXCEPTION HANDLING
// =============================
class ErrorHandler {
  static String handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'not-found':
        return 'The requested data was not found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'resource-exhausted':
        return 'Service quota exceeded. Please try again later.';
      case 'failed-precondition':
        return 'Operation failed due to precondition not met.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please check your connection.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return 'An unexpected error occurred: ${e.message}';
    }
  }

  static String handleNetworkError() {
    return 'Network connection lost. Please check your internet connection.';
  }

  static String handleGenericError(dynamic error) {
    return 'An unexpected error occurred. Please try again.';
  }
}

class ErrorBoundary extends StatelessWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ErrorWidgetBuilder(child: child);
  }
}

class ErrorWidgetBuilder extends StatefulWidget {
  final Widget child;
  const ErrorWidgetBuilder({super.key, required this.child});

  @override
  _ErrorWidgetBuilderState createState() => _ErrorWidgetBuilderState();
}

class _ErrorWidgetBuilderState extends State<ErrorWidgetBuilder> {
  bool hasError = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 20),
              Text('Something went wrong', style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              Text(errorMessage, textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() {
                  hasError = false;
                  errorMessage = '';
                }),
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

// =============================
// APP CONFIGURATION
// =============================
class AppConfig {
  static const String appName = 'Multi-Tenant SaaS';
  static const String version = '1.0.0';
  static const bool isDebug = true;

  // Firebase collections
  static const String tenantsCollection = 'tenants';
  static const String superAdminsCollection = 'super_admins';
  static const String ticketsCollection = 'tickets';

  // Subscription plans
  static const Map<String, double> subscriptionPlans = {
    'monthly': 29.0,
    'yearly': 299.0,
  };

  // Default settings
  static const Map<String, dynamic> defaultBranding = {
    'primaryColor': '#2196F3',
    'secondaryColor': '#FF9800',
    'currency': 'USD',
    'taxRate': 0.0,
  };
}
