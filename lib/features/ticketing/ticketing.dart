import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../theme_utils.dart';
import '../../../modules/auth/providers/auth_provider.dart';

class SuperAdminTicketsScreen extends StatefulWidget {
  const SuperAdminTicketsScreen({super.key});

  @override
  State<SuperAdminTicketsScreen> createState() => _SuperAdminTicketsScreenState();
}

class _SuperAdminTicketsScreenState extends State<SuperAdminTicketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _priorityFilter = 'all';
  final String _categoryFilter = 'all';
  bool _showStatistics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeUtils.backgroundSolid(context),
      appBar: AppBar(
        title: Text('Support Tickets', style: ThemeUtils.headlineMedium(context)),
        backgroundColor: ThemeUtils.surface(context),
        foregroundColor: ThemeUtils.textPrimary(context),
        elevation: ThemeUtils.cardElevation(context),
        actions: [
          IconButton(
            icon: Icon(_showStatistics ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showStatistics = !_showStatistics),
            tooltip: _showStatistics ? 'Hide Statistics' : 'Show Statistics',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: ThemeUtils.accentColor(context),
          labelColor: ThemeUtils.textPrimary(context),
          unselectedLabelColor: ThemeUtils.textSecondary(context),
          tabs: const [
            Tab(text: 'All Tickets'),
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
            Tab(text: 'Urgent'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_showStatistics) _buildStatisticsCard(),
          _buildSearchFilterBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTicketsList(status: 'all'),
                _buildTicketsList(status: 'open'),
                _buildTicketsList(status: 'inProgress'),
                _buildTicketsList(status: 'resolved'),
                _buildTicketsList(status: 'urgent', priority: 'urgent'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTicketDialog,
        backgroundColor: ThemeUtils.primary(context),
        foregroundColor: ThemeUtils.textOnPrimary(context),
        tooltip: 'Create New Ticket',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('tickets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeUtils.surface(context),
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final tickets = snapshot.data!.docs.map((doc) {
          try {
            return Ticket.fromFirestore(doc);
          } catch (e) {
           debugPrint('Error parsing ticket: $e');
            return null;
          }
        }).where((ticket) => ticket != null).cast<Ticket>().toList();

        final openTickets = tickets.where((t) => t.status == TicketStatus.open).length;
        final inProgressTickets = tickets.where((t) => t.status == TicketStatus.inProgress).length;
        final urgentTickets = tickets.where((t) => t.priority == TicketPriority.urgent).length;
        final resolvedTickets = tickets.where((t) => t.status == TicketStatus.resolved).length;

        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThemeUtils.surface(context),
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', tickets.length.toString(), Icons.support_agent, ThemeUtils.primary(context)),
              _buildStatItem('Open', openTickets.toString(), Icons.mark_email_unread, Colors.orange),
              _buildStatItem('In Progress', inProgressTickets.toString(), Icons.autorenew, Colors.blue),
              _buildStatItem('Urgent', urgentTickets.toString(), Icons.warning, Colors.red),
              _buildStatItem('Resolved', resolvedTickets.toString(), Icons.check_circle, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 8),
        Text(value, style: ThemeUtils.headlineMedium(context).copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context))),
      ],
    );
  }

  Widget _buildSearchFilterBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeUtils.surface(context),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeUtils.backgroundSolid(context),
                    borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                    border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search tickets by subject, description, or email...',
                      hintStyle: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context)),
                      prefixIcon: Icon(Icons.search, color: ThemeUtils.textSecondary(context)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: ThemeUtils.bodyMedium(context),
                  ),
                ),
              ),
              SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: Icon(Icons.filter_alt, color: ThemeUtils.textSecondary(context)),
                onSelected: (value) {},
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'export', child: Text('Export Tickets')),
                  PopupMenuItem(value: 'bulk', child: Text('Bulk Actions')),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Status', _statusFilter == 'all', () => setState(() => _statusFilter = 'all')),
                _buildFilterChip('Open', _statusFilter == 'open', () => setState(() => _statusFilter = 'open')),
                _buildFilterChip('In Progress', _statusFilter == 'inProgress', () => setState(() => _statusFilter = 'inProgress')),
                _buildFilterChip('Resolved', _statusFilter == 'resolved', () => setState(() => _statusFilter = 'resolved')),
                _buildFilterChip('Urgent', _priorityFilter == 'urgent', () => setState(() => _priorityFilter = _priorityFilter == 'urgent' ? 'all' : 'urgent')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: ThemeUtils.backgroundSolid(context),
        selectedColor: ThemeUtils.primary(context).withOpacity(0.2),
        labelStyle: ThemeUtils.bodyMedium(context).copyWith(
          color: selected ? ThemeUtils.primary(context) : ThemeUtils.textSecondary(context),
        ),
        checkmarkColor: ThemeUtils.primary(context),
      ),
    );
  }

  Widget _buildTicketsList({String? status, String? priority}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTicketsQuery(status: status, priority: priority).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
         debugPrint('Error loading tickets: ${snapshot.error}');
          return _buildErrorState('Error loading tickets: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(status ?? 'all');
        }

        final tickets = snapshot.data!.docs.map((doc) {
          try {
            return Ticket.fromFirestore(doc);
          } catch (e) {
           debugPrint('Error parsing ticket ${doc.id}: $e');
            return null;
          }
        }).where((ticket) => ticket != null).cast<Ticket>().toList();

        final filteredTickets = _filterTickets(tickets, _searchQuery);

        if (filteredTickets.isEmpty) {
          return _buildEmptyState(status ?? 'all');
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredTickets.length,
          itemBuilder: (context, index) {
            final ticket = filteredTickets[index];
            return _buildModernTicketCard(context, ticket);
          },
        );
      },
    );
  }

  Query _getTicketsQuery({String? status, String? priority}) {
    Query query = FirebaseFirestore.instance.collection('tickets').orderBy('createdAt', descending: true);

    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    if (priority != null && priority != 'all') {
      query = query.where('priority', isEqualTo: priority);
    }

    return query;
  }

  List<Ticket> _filterTickets(List<Ticket> tickets, String query) {
    if (query.isEmpty) return tickets;
    final searchLower = query.toLowerCase();
    return tickets.where((ticket) {
      return ticket.subject.toLowerCase().contains(searchLower) ||
          ticket.description.toLowerCase().contains(searchLower) ||
          ticket.userEmail.toLowerCase().contains(searchLower);
    }).toList();
  }

  Widget _buildModernTicketCard(BuildContext context, Ticket ticket) {
    final bool isUrgent = ticket.priority == TicketPriority.urgent;
    final bool hasUnreadReplies = _hasUnreadReplies(ticket);
    final bool isAssignedToMe = ticket.assignedTo == FirebaseAuth.instance.currentUser?.uid;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: ThemeUtils.cardElevation(context) * 2, offset: Offset(0, ThemeUtils.cardElevation(context)))],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        color: ThemeUtils.surface(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          onTap: () => _viewTicketDetails(context, ticket),
          splashColor: ThemeUtils.accentColor(context).withOpacity(0.1),
          highlightColor: ThemeUtils.accentColor(context).withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_getStatusColor(ticket.status).withOpacity(0.2), _getStatusColor(ticket.status).withOpacity(0.1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: _getStatusIcon(ticket.status),
                        ),
                        if (isAssignedToMe)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: ThemeUtils.primary(context),
                                shape: BoxShape.circle,
                                border: Border.all(color: ThemeUtils.surface(context), width: 2),
                              ),
                              child: Icon(Icons.person, size: 8, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ticket.subject,
                                  style: ThemeUtils.headlineMedium(context).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isUrgent) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ThemeUtils.error(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: ThemeUtils.error(context).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning, size: 12, color: ThemeUtils.error(context)),
                                      SizedBox(width: 4),
                                      Text('URGENT', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.error(context), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            ticket.description.length > 100
                                ? '${ticket.description.substring(0, 100)}...'
                                : ticket.description,
                            style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person, size: 12, color: ThemeUtils.textSecondary(context)),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ticket.userEmail,
                                  style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeUtils.backgroundSolid(context),
                        borderRadius: BorderRadius.circular(ThemeUtils.radius(context) * 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getCategoryIcon(ticket.category), size: 12, color: ThemeUtils.textSecondary(context)),
                          SizedBox(width: 4),
                          Text(_formatCategory(ticket.category), style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    if (ticket.priority != TicketPriority.medium)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(ticket.priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getPriorityColor(ticket.priority).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getPriorityIcon(ticket.priority), size: 12, color: _getPriorityColor(ticket.priority)),
                            SizedBox(width: 4),
                            Text(_formatPriority(ticket.priority).toUpperCase(), style: ThemeUtils.bodySmall(context).copyWith(color: _getPriorityColor(ticket.priority), fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                    Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_getStatusColor(ticket.status), _getStatusColor(ticket.status).withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(ThemeUtils.radius(context) * 2),
                        boxShadow: [BoxShadow(color: _getStatusColor(ticket.status).withOpacity(0.3), blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(
                          _formatStatus(ticket.status).toUpperCase(),
                          style: ThemeUtils.bodySmall(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    if (hasUnreadReplies) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(color: ThemeUtils.accentColor(context), shape: BoxShape.circle),
                        child: Text('!', style: ThemeUtils.bodySmall(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                if (ticket.assignedToEmail != null || ticket.createdAt != null) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      if (ticket.assignedToEmail != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: ThemeUtils.primary(context).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text('Assigned to ${ticket.assignedToEmail!.split('@').first}', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.primary(context), fontSize: 10)),
                        ),
                        SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text('Created ${_formatTimestamp(ticket.createdAt)}', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6), fontSize: 10)),
                      ),
                      if (ticket.replies.isNotEmpty)
                        Text('${ticket.replies.length} ${ticket.replies.length == 1 ? 'reply' : 'replies'}', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6), fontSize: 10)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(ThemeUtils.primary(context))),
          SizedBox(height: 16),
          Text('Loading tickets...', style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent, size: 64, color: ThemeUtils.textSecondary(context).withOpacity(0.5)),
          SizedBox(height: 16),
          Text(status == 'all' ? 'No tickets found' : 'No $status tickets', style: ThemeUtils.headlineMedium(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.7))),
          SizedBox(height: 8),
          Text(
            status == 'all' ? 'There are no support tickets in the system yet.' : 'There are no $status tickets at the moment.',
            style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showCreateTicketDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeUtils.primary(context),
              foregroundColor: ThemeUtils.textOnPrimary(context),
            ),
            child: Text('Create First Ticket'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: ThemeUtils.error(context)),
          SizedBox(height: 16),
          Text('Unable to load tickets', style: ThemeUtils.headlineMedium(context).copyWith(color: ThemeUtils.error(context))),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(error, style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context)), textAlign: TextAlign.center),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(backgroundColor: ThemeUtils.error(context), foregroundColor: Colors.white),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  bool _hasUnreadReplies(Ticket ticket) {
    if (ticket.replies.isEmpty) return false;
    final lastReply = ticket.replies.last;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return lastReply.userId != currentUserId && !lastReply.isInternalNote;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'unknown time';
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM dd, yyyy').format(timestamp);
  }

  String _formatStatus(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return 'Open';
      case TicketStatus.inProgress: return 'In Progress';
      case TicketStatus.resolved: return 'Resolved';
      case TicketStatus.closed: return 'Closed';
      case TicketStatus.onHold: return 'On Hold';
    }
  }

  String _formatPriority(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return 'Low';
      case TicketPriority.medium: return 'Medium';
      case TicketPriority.high: return 'High';
      case TicketPriority.urgent: return 'Urgent';
    }
  }

  String _formatCategory(TicketCategory category) {
    switch (category) {
      case TicketCategory.technical: return 'Technical';
      case TicketCategory.billing: return 'Billing';
      case TicketCategory.featureRequest: return 'Feature Request';
      case TicketCategory.general: return 'General';
      case TicketCategory.bugReport: return 'Bug Report';
      case TicketCategory.account: return 'Account';
    }
  }

  Icon _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Icon(Icons.mark_email_unread, size: 20, color: Colors.orange);
      case TicketStatus.inProgress: return Icon(Icons.autorenew, size: 20, color: Colors.blue);
      case TicketStatus.resolved: return Icon(Icons.check_circle, size: 20, color: Colors.green);
      case TicketStatus.closed: return Icon(Icons.verified, size: 20, color: Colors.grey);
      case TicketStatus.onHold: return Icon(Icons.pause_circle, size: 20, color: Colors.amber);
    }
  }

  IconData _getCategoryIcon(TicketCategory category) {
    switch (category) {
      case TicketCategory.technical: return Icons.computer;
      case TicketCategory.billing: return Icons.payment;
      case TicketCategory.featureRequest: return Icons.lightbulb;
      case TicketCategory.general: return Icons.chat;
      case TicketCategory.bugReport: return Icons.bug_report;
      case TicketCategory.account: return Icons.person;
    }
  }

  IconData _getPriorityIcon(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return Icons.arrow_downward;
      case TicketPriority.medium: return Icons.remove;
      case TicketPriority.high: return Icons.arrow_upward;
      case TicketPriority.urgent: return Icons.warning;
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Colors.orange;
      case TicketStatus.inProgress: return Colors.blue;
      case TicketStatus.resolved: return Colors.green;
      case TicketStatus.closed: return Colors.grey;
      case TicketStatus.onHold: return Colors.amber;
    }
  }

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return Colors.green;
      case TicketPriority.medium: return Colors.blue;
      case TicketPriority.high: return Colors.orange;
      case TicketPriority.urgent: return Colors.red;
    }
  }

  void _viewTicketDetails(BuildContext context, Ticket ticket) {
    showDialog(
      context: context,
      builder: (context) => AdvancedTicketDetailsDialog(ticket: ticket),
      barrierDismissible: false,
    );
  }

  void _showCreateTicketDialog() {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please log in to create tickets'), backgroundColor: ThemeUtils.error(context)));
      return;
    }

    String? tenantId = currentUser.tenantId;

    if (tenantId.isEmpty) {
      _showTenantSelectionDialog();
      return;
    }

    showDialog(context: context, builder: (context) => CreateTicketDialog(tenantId: tenantId, isAdmin: true));
  }

  void _showTenantSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Tenant'),
        content: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('tenants').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Text('Error loading tenants');
            }
            final tenants = snapshot.data!.docs;
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tenants.length,
                itemBuilder: (context, index) {
                  final tenant = tenants[index];
                  final tenantData = tenant.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(tenantData['businessName'] ?? 'Unknown Business'),
                    subtitle: Text(tenantData['email'] ?? 'No email'),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(context: context, builder: (context) => CreateTicketDialog(tenantId: tenant.id, isAdmin: true));
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'))],
      ),
    );
  }
}

class TicketService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<Ticket> createTicket({
    required String tenantId,
    required String subject,
    required String description,
    required TicketCategory category,
    TicketPriority priority = TicketPriority.medium,
    List<String> attachments = const [],
    Map<String, dynamic>? customFields,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final ticketRef = _firestore.collection('tickets').doc();
      final ticket = Ticket(
        id: ticketRef.id,
        tenantId: tenantId,
        userId: user.uid,
        userEmail: user.email ?? 'unknown@email.com',
        subject: subject,
        description: description,
        status: TicketStatus.open,
        priority: priority,
        category: category,
        attachments: attachments,
        customFields: customFields,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ticketRef.set(ticket.toFirestore());
      await _logTicketActivity(ticketId: ticketRef.id, action: 'created', description: 'Ticket created by ${user.email}');
      return ticket;
    } catch (e) {
      throw 'Failed to create ticket: $e';
    }
  }

  static Stream<List<Ticket>> getTicketsForTenant(String tenantId, {String? status}) {
    Query query = _firestore.collection('tickets').where('tenantId', isEqualTo: tenantId).orderBy('createdAt', descending: true);
    if (status != null && status != 'all') query = query.where('status', isEqualTo: status);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Ticket.fromFirestore(doc)).toList();
    });
  }

  static Stream<List<Ticket>> getAllTickets({String? status, String? priority, String? category}) {
    Query query = _firestore.collection('tickets').orderBy('createdAt', descending: true);
    if (status != null && status != 'all') query = query.where('status', isEqualTo: status);
    if (priority != null && priority != 'all') query = query.where('priority', isEqualTo: priority);
    if (category != null && category != 'all') query = query.where('category', isEqualTo: category);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Ticket.fromFirestore(doc)).toList();
    });
  }

  static Future<void> updateTicketStatus({required String ticketId, required TicketStatus status, String? internalNote}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final updateData = <String, dynamic>{
        'status': _statusToString(status),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == TicketStatus.resolved || status == TicketStatus.closed) {
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('tickets').doc(ticketId).update(updateData);
      await _logTicketActivity(ticketId: ticketId, action: 'status_changed', description: 'Ticket status changed to ${_statusToString(status)} by ${user.email}');

      if (internalNote != null && internalNote.isNotEmpty) {
        await addReply(
          ticketId: ticketId,
          message: '**Status changed to ${_statusToString(status)}**\n$internalNote',
          isInternalNote: true,
        );
      }
    } catch (e) {
      throw 'Failed to update ticket status: $e';
    }
  }

  static Future<void> updateTicket({
    required String ticketId,
    TicketStatus? status,
    TicketPriority? priority,
    String? assignedTo,
    String? assignedToEmail,
    String? internalNote,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status != null) {
        updateData['status'] = _statusToString(status);

        if (status == TicketStatus.resolved || status == TicketStatus.closed) {
          updateData['resolvedAt'] = FieldValue.serverTimestamp();
        }
      }

      if (priority != null) {
        updateData['priority'] = _priorityToString(priority);
      }

      if (assignedTo != null) {
        updateData['assignedTo'] = assignedTo;
        updateData['assignedToEmail'] = assignedToEmail;
      }

      await _firestore.collection('tickets').doc(ticketId).update(updateData);

      String action = 'updated';
      String description = 'Ticket updated by ${user.email}';

      if (status != null) {
        action = 'status_changed';
        description = 'Ticket status changed to ${_statusToString(status)} by ${user.email}';
      } else if (priority != null) {
        action = 'priority_changed';
        description = 'Ticket priority changed to ${_priorityToString(priority)} by ${user.email}';
      } else if (assignedTo != null) {
        action = 'assigned';
        description = 'Ticket assigned to $assignedToEmail by ${user.email}';
      }

      await _logTicketActivity(
        ticketId: ticketId,
        action: action,
        description: description,
      );

      if (internalNote != null && internalNote.isNotEmpty) {
        await addReply(
          ticketId: ticketId,
          message: internalNote,
          isInternalNote: true,
        );
      }
    } catch (e) {
      throw 'Failed to update ticket: $e';
    }
  }

  static Future<void> assignTicket({required String ticketId, required String assignedTo, required String assignedToEmail}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      await _firestore.collection('tickets').doc(ticketId).update({
        'assignedTo': assignedTo,
        'assignedToEmail': assignedToEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logTicketActivity(ticketId: ticketId, action: 'assigned', description: 'Ticket assigned to $assignedToEmail by ${user.email}');
    } catch (e) {
      throw 'Failed to assign ticket: $e';
    }
  }

  static Future<void> addReply({
    required String ticketId,
    required String message,
    bool isInternalNote = false,
    List<String> attachments = const [],
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';

      final userRole = await _getUserRole(user.uid);

      final reply = TicketReply(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: message,
        userId: user.uid,
        userEmail: user.email ?? 'unknown@email.com',
        userRole: userRole,
        timestamp: DateTime.now(),
        attachments: attachments,
        isInternalNote: isInternalNote,
      );

      // Get current ticket to update replies array
      final ticketDoc = await FirebaseFirestore.instance.collection('tickets').doc(ticketId).get();
      if (!ticketDoc.exists) {
        throw 'Ticket not found';
      }

      final ticketData = ticketDoc.data() as Map<String, dynamic>;
      List<dynamic> existingReplies = ticketData['replies'] ?? [];

      // Convert reply to map and add to existing replies
      existingReplies.add(reply.toMap());

      // Update the ticket with new replies array
      await FirebaseFirestore.instance.collection('tickets').doc(ticketId).update({
        'replies': existingReplies,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastReplyAt': FieldValue.serverTimestamp(),
      });

      // Auto-update status when admin replies
      if (userRole == 'admin' && !isInternalNote) {
        final currentStatus = ticketData['status']?.toString() ?? 'open';
        if (currentStatus == 'open') {
          await updateTicketStatus(
            ticketId: ticketId,
            status: TicketStatus.inProgress,
          );
        }
      }

      await _logTicketActivity(
        ticketId: ticketId,
        action: 'replied',
        description: '${isInternalNote ? 'Internal note added' : 'Reply sent'} by ${user.email}',
      );
    } catch (e) {
      throw 'Failed to add reply: $e';
    }
  }

  static Future<String> uploadAttachment({required String ticketId, required String fileName, required List<int> fileBytes}) async {
    try {
      final Uint8List uint8List = Uint8List.fromList(fileBytes);
      final ref = _storage.ref().child('tickets/$ticketId/attachments/$fileName');
      final uploadTask = ref.putData(uint8List);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload attachment: $e';
    }
  }

  static Future<void> addSatisfactionRating({required String ticketId, required int rating, String? feedback}) async {
    try {
      await _firestore.collection('tickets').doc(ticketId).update({
        'satisfactionRating': rating,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (feedback != null && feedback.isNotEmpty) {
        await _firestore.collection('ticket_feedback').add({
          'ticketId': ticketId,
          'rating': rating,
          'feedback': feedback,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _logTicketActivity(ticketId: ticketId, action: 'rated', description: 'Ticket rated $rating stars');
    } catch (e) {
      throw 'Failed to add rating: $e';
    }
  }

  static Future<Map<String, dynamic>> getTicketStatistics(String tenantId) async {
    try {
      final snapshot = await _firestore.collection('tickets').where('tenantId', isEqualTo: tenantId).get();
      final tickets = snapshot.docs.map((doc) => Ticket.fromFirestore(doc)).toList();

      final openTickets = tickets.where((t) => t.status == TicketStatus.open).length;
      final inProgressTickets = tickets.where((t) => t.status == TicketStatus.inProgress).length;
      final resolvedTickets = tickets.where((t) => t.status == TicketStatus.resolved).length;
      final closedTickets = tickets.where((t) => t.status == TicketStatus.closed).length;
      final urgentTickets = tickets.where((t) => t.priority == TicketPriority.urgent).length;

      return {
        'total': tickets.length,
        'open': openTickets,
        'inProgress': inProgressTickets,
        'resolved': resolvedTickets,
        'closed': closedTickets,
        'urgent': urgentTickets,
        'averageResolutionTime': _calculateAverageResolutionTime(tickets),
        'satisfactionRate': _calculateSatisfactionRate(tickets),
      };
    } catch (e) {
      throw 'Failed to get statistics: $e';
    }
  }

  static Future<String> _getUserRole(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['role'] ?? 'user';
    } catch (e) {
      return 'user';
    }
  }

  static Future<void> _logTicketActivity({required String ticketId, required String action, required String description, Map<String, dynamic> metadata = const {}}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('ticket_activities').add({
        'ticketId': ticketId,
        'action': action,
        'description': description,
        'userId': user.uid,
        'userEmail': user.email ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
     debugPrint('Failed to log ticket activity: $e');
    }
  }

  static double _calculateAverageResolutionTime(List<Ticket> tickets) {
    final resolvedTickets = tickets.where((t) => t.resolvedAt != null).toList();
    if (resolvedTickets.isEmpty) return 0;
    final totalDuration = resolvedTickets.map((t) => t.resolvedAt!.difference(t.createdAt).inHours).reduce((a, b) => a + b);
    return totalDuration / resolvedTickets.length;
  }

  static double _calculateSatisfactionRate(List<Ticket> tickets) {
    final ratedTickets = tickets.where((t) => t.satisfactionRating > 0).toList();
    if (ratedTickets.isEmpty) return 0;
    final totalRating = ratedTickets.map((t) => t.satisfactionRating).reduce((a, b) => a + b);
    return totalRating / ratedTickets.length;
  }

  static Stream<List<Ticket>> searchTickets(String query, {String? tenantId, bool isAdmin = false}) {
    Query collectionQuery = _firestore.collection('tickets');
    if (!isAdmin && tenantId != null) collectionQuery = collectionQuery.where('tenantId', isEqualTo: tenantId);

    return collectionQuery.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Ticket.fromFirestore(doc)).where((ticket) =>
      ticket.subject.toLowerCase().contains(query.toLowerCase()) ||
          ticket.description.toLowerCase().contains(query.toLowerCase()) ||
          ticket.userEmail.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  static Future<void> escalateTicket(String ticketId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'User not authenticated';

      await _firestore.collection('tickets').doc(ticketId).update({
        'isEscalated': true,
        'priority': _priorityToString(TicketPriority.urgent),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logTicketActivity(ticketId: ticketId, action: 'escalated', description: 'Ticket escalated to urgent by ${user.email}');
    } catch (e) {
      throw 'Failed to escalate ticket: $e';
    }
  }

  static String _statusToString(TicketStatus status) {
    return status.toString().split('.').last;
  }

  static String _priorityToString(TicketPriority priority) {
    return priority.toString().split('.').last;
  }
}

enum TicketStatus { open, inProgress, resolved, closed, onHold }
enum TicketPriority { low, medium, high, urgent }
enum TicketCategory { technical, billing, featureRequest, general, bugReport, account }

class Ticket {
  final String id;
  final String tenantId;
  final String userId;
  final String userEmail;
  final String subject;
  final String description;
  final TicketStatus status;
  final TicketPriority priority;
  final TicketCategory category;
  final List<String> attachments;
  final List<TicketReply> replies;
  final String? assignedTo;
  final String? assignedToEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final bool isEscalated;
  final int satisfactionRating;
  final Map<String, dynamic>? customFields;

  Ticket({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.userEmail,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.category,
    this.attachments = const [],
    this.replies = const [],
    this.assignedTo,
    this.assignedToEmail,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.isEscalated = false,
    this.satisfactionRating = 0,
    this.customFields,
  });

  factory Ticket.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    String safeString(String key, String fallback) => data[key]?.toString() ?? fallback;

    List<TicketReply> replies = [];
    try {
      final repliesData = data['replies'] as List<dynamic>?;
      if (repliesData != null) {
        replies = repliesData.map((replyData) {
          if (replyData is Map<String, dynamic>) {
            return TicketReply.fromMap(replyData);
          }
          return TicketReply(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            message: 'Invalid reply format',
            userId: '',
            userEmail: 'unknown',
            userRole: 'user',
            timestamp: DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
     debugPrint('Error parsing replies: $e');
      replies = [];
    }

    return Ticket(
      id: doc.id,
      tenantId: safeString('tenantId', ''),
      userId: safeString('userId', ''),
      userEmail: safeString('userEmail', 'unknown@email.com'),
      subject: safeString('subject', 'No Subject'),
      description: safeString('description', 'No Description'),
      status: _parseStatus(data['status']?.toString() ?? 'open'),
      priority: _parsePriority(data['priority']?.toString() ?? 'medium'),
      category: _parseCategory(data['category']?.toString() ?? 'general'),
      attachments: List<String>.from(data['attachments'] ?? []),
      replies: replies,
      assignedTo: data['assignedTo']?.toString(),
      assignedToEmail: data['assignedToEmail']?.toString(),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      resolvedAt: data['resolvedAt'] != null ? (data['resolvedAt'] as Timestamp).toDate() : null,
      isEscalated: data['isEscalated'] ?? false,
      satisfactionRating: (data['satisfactionRating'] as int?) ?? 0,
      customFields: data['customFields'] != null ? Map<String, dynamic>.from(data['customFields']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tenantId': tenantId,
      'userId': userId,
      'userEmail': userEmail,
      'subject': subject,
      'description': description,
      'status': _statusToString(status),
      'priority': _priorityToString(priority),
      'category': _categoryToString(category),
      'attachments': attachments,
      'replies': replies.map((reply) => reply.toMap()).toList(),
      'assignedTo': assignedTo,
      'assignedToEmail': assignedToEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'isEscalated': isEscalated,
      'satisfactionRating': satisfactionRating,
      'customFields': customFields,
    };
  }

  static TicketStatus _parseStatus(String status) {
    switch (status) {
      case 'open': return TicketStatus.open;
      case 'inProgress': return TicketStatus.inProgress;
      case 'resolved': return TicketStatus.resolved;
      case 'closed': return TicketStatus.closed;
      case 'onHold': return TicketStatus.onHold;
      default: return TicketStatus.open;
    }
  }

  static TicketPriority _parsePriority(String priority) {
    switch (priority) {
      case 'low': return TicketPriority.low;
      case 'medium': return TicketPriority.medium;
      case 'high': return TicketPriority.high;
      case 'urgent': return TicketPriority.urgent;
      default: return TicketPriority.medium;
    }
  }

  static TicketCategory _parseCategory(String category) {
    switch (category) {
      case 'technical': return TicketCategory.technical;
      case 'billing': return TicketCategory.billing;
      case 'featureRequest': return TicketCategory.featureRequest;
      case 'general': return TicketCategory.general;
      case 'bugReport': return TicketCategory.bugReport;
      case 'account': return TicketCategory.account;
      default: return TicketCategory.general;
    }
  }

  static String _statusToString(TicketStatus status) {
    return status.toString().split('.').last;
  }

  static String _priorityToString(TicketPriority priority) {
    return priority.toString().split('.').last;
  }

  static String _categoryToString(TicketCategory category) {
    return category.toString().split('.').last;
  }

  Ticket copyWith({
    String? id,
    String? tenantId,
    String? userId,
    String? userEmail,
    String? subject,
    String? description,
    TicketStatus? status,
    TicketPriority? priority,
    TicketCategory? category,
    List<String>? attachments,
    List<TicketReply>? replies,
    String? assignedTo,
    String? assignedToEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    bool? isEscalated,
    int? satisfactionRating,
    Map<String, dynamic>? customFields,
  }) {
    return Ticket(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      attachments: attachments ?? this.attachments,
      replies: replies ?? this.replies,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      isEscalated: isEscalated ?? this.isEscalated,
      satisfactionRating: satisfactionRating ?? this.satisfactionRating,
      customFields: customFields ?? this.customFields,
    );
  }
}

class TicketReply {
  final String id;
  final String message;
  final String userId;
  final String userEmail;
  final String userRole;
  final DateTime timestamp;
  final List<String> attachments;
  final bool isInternalNote;

  TicketReply({
    required this.id,
    required this.message,
    required this.userId,
    required this.userEmail,
    required this.userRole,
    required this.timestamp,
    this.attachments = const [],
    this.isInternalNote = false,
  });

  factory TicketReply.fromMap(Map<String, dynamic> map) {
    return TicketReply(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: map['message']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userEmail: map['userEmail']?.toString() ?? 'unknown@email.com',
      userRole: map['userRole']?.toString() ?? 'user',
      timestamp: map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : DateTime.now(),
      attachments: List<String>.from(map['attachments'] ?? []),
      isInternalNote: map['isInternalNote'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'userId': userId,
      'userEmail': userEmail,
      'userRole': userRole,
      'timestamp': Timestamp.fromDate(timestamp),
      'attachments': attachments,
      'isInternalNote': isInternalNote,
    };
  }
}

class TicketActivity {
  final String id;
  final String ticketId;
  final String action;
  final String description;
  final String userId;
  final String userEmail;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  TicketActivity({
    required this.id,
    required this.ticketId,
    required this.action,
    required this.description,
    required this.userId,
    required this.userEmail,
    required this.timestamp,
    this.metadata = const {},
  });

  factory TicketActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TicketActivity(
      id: doc.id,
      ticketId: data['ticketId']?.toString() ?? '',
      action: data['action']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? '',
      timestamp: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ticketId': ticketId,
      'action': action,
      'description': description,
      'userId': userId,
      'userEmail': userEmail,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

class AdvancedTicketDetailsDialog extends StatefulWidget {
  final Ticket ticket;

  const AdvancedTicketDetailsDialog({super.key, required this.ticket});

  @override
  State<AdvancedTicketDetailsDialog> createState() => _AdvancedTicketDetailsDialogState();
}

class _AdvancedTicketDetailsDialogState extends State<AdvancedTicketDetailsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _replyController = TextEditingController();
  final TextEditingController _internalNoteController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  TicketStatus _selectedStatus = TicketStatus.open;
  TicketPriority _selectedPriority = TicketPriority.medium;
  String? _assignedTo;
  bool _isSubmitting = false;
  bool _showInternalNote = false;
  late Ticket _currentTicket;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentTicket = widget.ticket;
    _selectedStatus = _currentTicket.status;
    _selectedPriority = _currentTicket.priority;
    _assignedTo = _currentTicket.assignedTo;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final isAdmin = authProvider.currentUser?.role == 'admin';

    return Dialog(
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeUtils.radius(context))),
      backgroundColor: ThemeUtils.surface(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(_currentTicket),

            if (isAdmin) _buildControlsBar(_currentTicket),

            _buildTabBar(isAdmin),

            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tickets')
                    .doc(_currentTicket.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final updatedTicket = Ticket.fromFirestore(snapshot.data!);
                    _currentTicket = updatedTicket;

                    final publicReplies = updatedTicket.replies.where((reply) => !reply.isInternalNote).toList();
                    final internalNotes = updatedTicket.replies.where((reply) => reply.isInternalNote).toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _buildConversationTab(updatedTicket, publicReplies),
                        if (isAdmin) _buildInternalNotesTab(internalNotes),
                      ],
                    );
                  }
                  return Center(child: CircularProgressIndicator());
                },
              ),
            ),

            if (!_showInternalNote) _buildReplyInput(_currentTicket.id),

            if (_showInternalNote && isAdmin) _buildInternalNoteInput(_currentTicket.id),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Ticket ticket) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeUtils.backgroundSolid(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ThemeUtils.radius(context)),
          topRight: Radius.circular(ThemeUtils.radius(context)),
        ),
        border: Border(bottom: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(ticket.status).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: _getStatusIcon(ticket.status),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject,
                  style: ThemeUtils.headlineMedium(context).copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'From: ${ticket.userEmail} • ${_formatDetailedTimestamp(ticket.createdAt)}',
                  style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: ThemeUtils.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsBar(Ticket ticket) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeUtils.backgroundSolid(context).withOpacity(0.5),
        border: Border(bottom: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: ThemeUtils.surface(context),
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
              border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TicketStatus>(
                value: _selectedStatus,
                items: [
                  _buildStatusDropdownItem(TicketStatus.open, 'Open', 'New ticket waiting for agent response'),
                  _buildStatusDropdownItem(TicketStatus.inProgress, 'In Progress', 'Agent is working on the issue'),
                  _buildStatusDropdownItem(TicketStatus.onHold, 'On Hold', 'Waiting for customer response or external factor'),
                  _buildStatusDropdownItem(TicketStatus.resolved, 'Resolved', 'Issue has been resolved'),
                  _buildStatusDropdownItem(TicketStatus.closed, 'Closed', 'Ticket completed and archived'),
                ],
                onChanged: (value) => _showStatusChangeConfirmation(value!),
                padding: EdgeInsets.symmetric(horizontal: 16),
                style: ThemeUtils.bodyMedium(context),
              ),
            ),
          ),
          SizedBox(width: 12),

          Container(
            decoration: BoxDecoration(
              color: ThemeUtils.surface(context),
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
              border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TicketPriority>(
                value: _selectedPriority,
                items: TicketPriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(_getPriorityIcon(priority), size: 16, color: _getPriorityColor(priority)),
                          SizedBox(width: 8),
                          Text(_formatPriority(priority), style: ThemeUtils.bodyMedium(context)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPriority = value!),
                padding: EdgeInsets.symmetric(horizontal: 16),
                style: ThemeUtils.bodyMedium(context),
              ),
            ),
          ),
          Spacer(),

          if (ticket.priority != TicketPriority.urgent)
            OutlinedButton.icon(
              onPressed: () => _escalateTicket(ticket.id),
              icon: Icon(Icons.warning, size: 16),
              label: Text('Escalate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red),
              ),
            ),

          SizedBox(width: 8),

          if (ticket.assignedTo != FirebaseAuth.instance.currentUser?.uid)
            OutlinedButton.icon(
              onPressed: () => _assignToMe(ticket.id),
              icon: Icon(Icons.person_add, size: 16),
              label: Text('Assign to Me'),
            ),

          SizedBox(width: 8),

          OutlinedButton.icon(
            onPressed: () => setState(() => _showInternalNote = !_showInternalNote),
            icon: Icon(_showInternalNote ? Icons.chat : Icons.note, size: 16),
            label: Text(_showInternalNote ? 'Write Reply' : 'Internal Note'),
          ),

          SizedBox(width: 8),

          ElevatedButton(
            onPressed: () => _saveChanges(ticket.id),
            child: Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  DropdownMenuItem<TicketStatus> _buildStatusDropdownItem(TicketStatus status, String label, String description) {
    return DropdownMenuItem(
      value: status,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Text(label, style: ThemeUtils.bodyMedium(context).copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(left: 20),
              child: Text(
                description,
                style: ThemeUtils.bodySmall(context).copyWith(
                  color: ThemeUtils.textSecondary(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeUtils.backgroundSolid(context).withOpacity(0.5),
        border: Border(bottom: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.1))),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: ThemeUtils.primary(context),
        unselectedLabelColor: ThemeUtils.textSecondary(context),
        indicatorColor: ThemeUtils.primary(context),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat, size: 16),
                SizedBox(width: 8),
                Text('Conversation'),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('tickets').doc(_currentTicket.id).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final ticket = Ticket.fromFirestore(snapshot.data!);
                      final publicReplies = ticket.replies.where((reply) => !reply.isInternalNote).length;
                      return Container(
                        margin: EdgeInsets.only(left: 8),
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThemeUtils.primary(context).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${publicReplies + 1}',
                          style: ThemeUtils.bodySmall(context).copyWith(
                            color: ThemeUtils.primary(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }
                    return SizedBox();
                  },
                ),
              ],
            ),
          ),
          if (isAdmin)
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note, size: 16),
                  SizedBox(width: 8),
                  Text('Internal Notes'),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('tickets').doc(_currentTicket.id).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final ticket = Ticket.fromFirestore(snapshot.data!);
                        final internalNotes = ticket.replies.where((reply) => reply.isInternalNote).length;
                        if (internalNotes > 0) {
                          return Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$internalNotes',
                              style: ThemeUtils.bodySmall(context).copyWith(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                      }
                      return SizedBox();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationTab(Ticket ticket, List<TicketReply> replies) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMessageBubble(
            message: ticket.description,
            isCurrentUser: false,
            timestamp: ticket.createdAt,
            isOriginal: true,
            userEmail: ticket.userEmail,
          ),
          SizedBox(height: 16),

          if (replies.isNotEmpty) ...[
            Text(
              'Replies (${replies.length})',
              style: ThemeUtils.bodyMedium(context).copyWith(
                fontWeight: FontWeight.w600,
                color: ThemeUtils.textSecondary(context),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                itemCount: replies.length,
                itemBuilder: (context, index) {
                  final reply = replies[index];
                  final isCurrentUser = reply.userId == FirebaseAuth.instance.currentUser?.uid;

                  return _buildMessageBubble(
                    message: reply.message,
                    isCurrentUser: isCurrentUser,
                    timestamp: reply.timestamp,
                    isOriginal: false,
                    userEmail: reply.userEmail,
                    userRole: reply.userRole,
                  );
                },
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.forum,
                      size: 64,
                      color: ThemeUtils.textSecondary(context).withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No replies yet',
                      style: ThemeUtils.bodyMedium(context).copyWith(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.6),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Be the first to respond to this ticket',
                      style: ThemeUtils.bodySmall(context).copyWith(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInternalNotesTab(List<TicketReply> internalNotes) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          if (internalNotes.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: internalNotes.length,
                itemBuilder: (context, index) => _buildInternalNoteBubble(internalNotes[index]),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.note_add,
                      size: 64,
                      color: ThemeUtils.textSecondary(context).withOpacity(0.5),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No internal notes',
                      style: ThemeUtils.bodyMedium(context).copyWith(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.6),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add internal notes for team collaboration',
                      style: ThemeUtils.bodySmall(context).copyWith(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyInput(String ticketId) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeUtils.backgroundSolid(context),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(ThemeUtils.radius(context)),
          bottomRight: Radius.circular(ThemeUtils.radius(context)),
        ),
        border: Border(
          top: BorderSide(
            color: ThemeUtils.secondary(context).withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type your reply...',
                hintStyle: ThemeUtils.bodyMedium(context).copyWith(
                  color: ThemeUtils.textSecondary(context),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  borderSide: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.3)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: ThemeUtils.bodyMedium(context),
            ),
          ),
          SizedBox(width: 12),
          _isSubmitting
              ? CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(ThemeUtils.primary(context)),
          )
              : FloatingActionButton(
            onPressed: _replyController.text.trim().isEmpty ? null : () => _submitReply(ticketId),
            backgroundColor: ThemeUtils.primary(context),
            foregroundColor: ThemeUtils.textOnPrimary(context),
            mini: true,
            child: Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Widget _buildInternalNoteInput(String ticketId) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeUtils.backgroundSolid(context),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(ThemeUtils.radius(context)),
          bottomRight: Radius.circular(ThemeUtils.radius(context)),
        ),
        border: Border(
          top: BorderSide(
            color: ThemeUtils.secondary(context).withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _internalNoteController,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Add internal note for the team...',
                hintStyle: ThemeUtils.bodyMedium(context).copyWith(
                  color: ThemeUtils.textSecondary(context),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  borderSide: BorderSide(color: Colors.orange.withOpacity(0.3)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: ThemeUtils.bodyMedium(context),
            ),
          ),
          SizedBox(width: 12),
          _isSubmitting
              ? CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          )
              : FloatingActionButton(
            onPressed: _internalNoteController.text.trim().isEmpty ? null : () => _submitInternalNote(ticketId),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            mini: true,
            child: Icon(Icons.note_add),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isCurrentUser,
    required DateTime timestamp,
    required bool isOriginal,
    required String userEmail,
    String? userRole,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isOriginal ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOriginal ? Icons.person : Icons.support_agent,
                size: 20,
                color: isOriginal ? Colors.orange : Colors.blue,
              ),
            ),
            SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? ThemeUtils.primary(context).withOpacity(0.1)
                        : ThemeUtils.backgroundSolid(context),
                    borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                    border: Border.all(
                      color: isCurrentUser
                          ? ThemeUtils.primary(context).withOpacity(0.3)
                          : ThemeUtils.secondary(context).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isCurrentUser && userRole != null)
                        Text(
                          userRole == 'admin' ? 'Support Agent' : 'Customer',
                          style: ThemeUtils.bodySmall(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: ThemeUtils.textSecondary(context),
                          ),
                        ),
                      Text(
                        message,
                        style: ThemeUtils.bodyMedium(context),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Text(
                      userEmail,
                      style: ThemeUtils.bodySmall(context).copyWith(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatDetailedTimestamp(timestamp),
                      style: ThemeUtils.bodySmall(context).copyWith(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ThemeUtils.primary(context).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.admin_panel_settings,
                size: 20,
                color: ThemeUtils.primary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInternalNoteBubble(TicketReply note) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Internal Note',
                style: ThemeUtils.bodySmall(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              Spacer(),
              Text(
                _formatDetailedTimestamp(note.timestamp),
                style: ThemeUtils.bodySmall(context).copyWith(
                  color: ThemeUtils.textSecondary(context).withOpacity(0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            note.message,
            style: ThemeUtils.bodyMedium(context),
          ),
          SizedBox(height: 4),
          Text(
            'By ${note.userEmail}',
            style: ThemeUtils.bodySmall(context).copyWith(
              color: ThemeUtils.textSecondary(context).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReply(String ticketId) async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await TicketService.addReply(
        ticketId: ticketId,
        message: _replyController.text.trim(),
      );

      _replyController.clear();
      setState(() {});
      _scrollToBottom();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply sent successfully'),
          backgroundColor: ThemeUtils.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reply: $e'),
          backgroundColor: ThemeUtils.error(context),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitInternalNote(String ticketId) async {
    if (_internalNoteController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await TicketService.addReply(
        ticketId: ticketId,
        message: _internalNoteController.text.trim(),
        isInternalNote: true,
      );

      _internalNoteController.clear();
      setState(() => _showInternalNote = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Internal note added successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add internal note: $e'),
          backgroundColor: ThemeUtils.error(context),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveChanges(String ticketId) async {
    try {
      await TicketService.updateTicket(
        ticketId: ticketId,
        status: _selectedStatus,
        priority: _selectedPriority,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket updated successfully'),
          backgroundColor: ThemeUtils.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update ticket: $e'),
          backgroundColor: ThemeUtils.error(context),
        ),
      );
    }
  }

  Future<void> _escalateTicket(String ticketId) async {
    try {
      await TicketService.escalateTicket(ticketId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket escalated to urgent'),
          backgroundColor: Colors.orange,
        ),
      );

      setState(() {
        _selectedPriority = TicketPriority.urgent;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to escalate ticket: $e'),
          backgroundColor: ThemeUtils.error(context),
        ),
      );
    }
  }

  Future<void> _assignToMe(String ticketId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await TicketService.assignTicket(
        ticketId: ticketId,
        assignedTo: user.uid,
        assignedToEmail: user.email ?? 'Unknown User',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket assigned to you'),
          backgroundColor: ThemeUtils.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign ticket: $e'),
          backgroundColor: ThemeUtils.error(context),
        ),
      );
    }
  }

  Future<void> _showStatusChangeConfirmation(TicketStatus newStatus) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Ticket Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to change the status from ${_formatStatus(_selectedStatus)} to ${_formatStatus(newStatus)}?'),
            SizedBox(height: 16),
            if (newStatus == TicketStatus.resolved || newStatus == TicketStatus.closed)
              Text(
                'This will mark the ticket as completed and notify the customer.',
                style: ThemeUtils.bodySmall(context).copyWith(color: Colors.green),
              ),
            if (newStatus == TicketStatus.onHold)
              Text(
                'The ticket will be put on hold waiting for additional information.',
                style: ThemeUtils.bodySmall(context).copyWith(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _selectedStatus = newStatus);
      await _saveChanges(_currentTicket.id);
    }
  }

  String _formatStatus(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return 'Open';
      case TicketStatus.inProgress: return 'In Progress';
      case TicketStatus.resolved: return 'Resolved';
      case TicketStatus.closed: return 'Closed';
      case TicketStatus.onHold: return 'On Hold';
    }
  }

  String _formatPriority(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return 'Low';
      case TicketPriority.medium: return 'Medium';
      case TicketPriority.high: return 'High';
      case TicketPriority.urgent: return 'Urgent';
    }
  }

  String _formatDetailedTimestamp(DateTime timestamp) {
    return DateFormat('MMM dd, yyyy • HH:mm').format(timestamp);
  }

  Icon _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Icon(Icons.mark_email_unread, size: 20, color: Colors.orange);
      case TicketStatus.inProgress: return Icon(Icons.autorenew, size: 20, color: Colors.blue);
      case TicketStatus.resolved: return Icon(Icons.check_circle, size: 20, color: Colors.green);
      case TicketStatus.closed: return Icon(Icons.verified, size: 20, color: Colors.grey);
      case TicketStatus.onHold: return Icon(Icons.pause_circle, size: 20, color: Colors.amber);
    }
  }

  IconData _getPriorityIcon(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return Icons.arrow_downward;
      case TicketPriority.medium: return Icons.remove;
      case TicketPriority.high: return Icons.arrow_upward;
      case TicketPriority.urgent: return Icons.warning;
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Colors.orange;
      case TicketStatus.inProgress: return Colors.blue;
      case TicketStatus.resolved: return Colors.green;
      case TicketStatus.closed: return Colors.grey;
      case TicketStatus.onHold: return Colors.amber;
    }
  }

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return Colors.green;
      case TicketPriority.medium: return Colors.blue;
      case TicketPriority.high: return Colors.orange;
      case TicketPriority.urgent: return Colors.red;
    }
  }
}

class ClientTicketsScreen extends StatefulWidget {
  const ClientTicketsScreen({super.key});

  @override
  State<ClientTicketsScreen> createState() => _ClientTicketsScreenState();
}

class _ClientTicketsScreenState extends State<ClientTicketsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _statusFilter = 'all';
  bool _showStatistics = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final tenantId = authProvider.currentUser?.tenantId;

    if (tenantId == null) {
      return Scaffold(
        body: Center(
          child: Text('Unable to load tenant information', style: ThemeUtils.bodyMedium(context)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeUtils.backgroundSolid(context),
      appBar: AppBar(
        title: Text('My Support Tickets', style: ThemeUtils.headlineMedium(context)),
        backgroundColor: ThemeUtils.surface(context),
        foregroundColor: ThemeUtils.textPrimary(context),
        elevation: ThemeUtils.cardElevation(context),
        actions: [
          IconButton(
            icon: Icon(_showStatistics ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showStatistics = !_showStatistics),
            tooltip: _showStatistics ? 'Hide Statistics' : 'Show Statistics',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: ThemeUtils.accentColor(context),
          labelColor: ThemeUtils.textPrimary(context),
          unselectedLabelColor: ThemeUtils.textSecondary(context),
          tabs: const [Tab(text: 'All Tickets'), Tab(text: 'Open'), Tab(text: 'In Progress'), Tab(text: 'Resolved')],
        ),
      ),
      body: Column(
        children: [
          if (_showStatistics) _buildStatisticsCard(tenantId),
          _buildSearchBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTicketsList(tenantId, status: 'all'),
                _buildTicketsList(tenantId, status: 'open'),
                _buildTicketsList(tenantId, status: 'inProgress'),
                _buildTicketsList(tenantId, status: 'resolved'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTicketDialog(),
        backgroundColor: ThemeUtils.primary(context),
        foregroundColor: ThemeUtils.textOnPrimary(context),
        tooltip: 'Create New Ticket',
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatisticsCard(String tenantId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: TicketService.getTicketStatistics(tenantId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeUtils.surface(context),
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final stats = snapshot.data!;
        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThemeUtils.surface(context),
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total', stats['total'].toString(), Icons.support_agent, ThemeUtils.primary(context)),
              _buildStatItem('Open', stats['open'].toString(), Icons.mark_email_unread, Colors.orange),
              _buildStatItem('In Progress', stats['inProgress'].toString(), Icons.autorenew, Colors.blue),
              _buildStatItem('Resolved', stats['resolved'].toString(), Icons.check_circle, Colors.green),
              _buildStatItem('Satisfaction', '${stats['satisfactionRate'].toStringAsFixed(1)}/5', Icons.star, Colors.amber),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 20, color: color)),
        SizedBox(height: 8),
        Text(value, style: ThemeUtils.headlineMedium(context).copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context))),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ThemeUtils.surface(context), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))]),
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeUtils.backgroundSolid(context),
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search your tickets...',
            hintStyle: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context)),
            prefixIcon: Icon(Icons.search, color: ThemeUtils.textSecondary(context)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: ThemeUtils.bodyMedium(context),
        ),
      ),
    );
  }

  Widget _buildTicketsList(String tenantId, {String? status}) {
    return StreamBuilder<List<Ticket>>(
      stream: TicketService.getTicketsForTenant(tenantId, status: status == 'all' ? null : status),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
         debugPrint('Error loading tickets: ${snapshot.error}');
          return _buildErrorState('Error loading tickets: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) return _buildLoadingState();
        final tickets = snapshot.data ?? [];
        final filteredTickets = _filterTickets(tickets, _searchQuery);
        if (filteredTickets.isEmpty) return _buildEmptyState(status ?? 'all');
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredTickets.length,
          itemBuilder: (context, index) => _buildClientTicketCard(context, filteredTickets[index]),
        );
      },
    );
  }

  Widget _buildClientTicketCard(BuildContext context, Ticket ticket) {
    final bool isUrgent = ticket.priority == TicketPriority.urgent;
    final bool hasNewReply = _hasNewReply(ticket);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: ThemeUtils.cardElevation(context) * 2, offset: Offset(0, ThemeUtils.cardElevation(context)))],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        color: ThemeUtils.surface(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          onTap: () => _viewTicketDetails(context, ticket),
          splashColor: ThemeUtils.accentColor(context).withOpacity(0.1),
          highlightColor: ThemeUtils.accentColor(context).withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_getStatusColor(ticket.status).withOpacity(0.2), _getStatusColor(ticket.status).withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: _getStatusIcon(ticket.status),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(ticket.subject, style: ThemeUtils.headlineMedium(context).copyWith(fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              if (isUrgent) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ThemeUtils.error(context).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: ThemeUtils.error(context).withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning, size: 12, color: ThemeUtils.error(context)),
                                      SizedBox(width: 4),
                                      Text('URGENT', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.error(context), fontWeight: FontWeight.bold, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                              if (hasNewReply) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: ThemeUtils.accentColor(context), shape: BoxShape.circle),
                                  child: Icon(Icons.chat, size: 12, color: Colors.white),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                              ticket.description.length > 100
                                  ? '${ticket.description.substring(0, 100)}...'
                                  : ticket.description,
                              style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeUtils.backgroundSolid(context),
                        borderRadius: BorderRadius.circular(ThemeUtils.radius(context) * 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getCategoryIcon(ticket.category), size: 12, color: ThemeUtils.textSecondary(context)),
                          SizedBox(width: 4),
                          Text(_formatCategory(ticket.category), style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_getStatusColor(ticket.status), _getStatusColor(ticket.status).withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(ThemeUtils.radius(context) * 2),
                        boxShadow: [BoxShadow(color: _getStatusColor(ticket.status).withOpacity(0.3), blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(_formatStatus(ticket.status).toUpperCase(), style: ThemeUtils.bodySmall(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
                ...[
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text('Created ${_formatTimestamp(ticket.createdAt)}', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6), fontSize: 10))),
                    if (ticket.replies.isNotEmpty)
                      Text('${ticket.replies.length} ${ticket.replies.length == 1 ? 'reply' : 'replies'}', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6), fontSize: 10)),
                    if (ticket.assignedToEmail != null) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: ThemeUtils.primary(context).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('Assigned', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.primary(context), fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(ThemeUtils.primary(context))),
          SizedBox(height: 16),
          Text('Loading your tickets...', style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.support_agent, size: 64, color: ThemeUtils.textSecondary(context).withOpacity(0.5)),
          SizedBox(height: 16),
          Text(status == 'all' ? 'No tickets found' : 'No $status tickets', style: ThemeUtils.headlineMedium(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.7))),
          SizedBox(height: 8),
          Text(
            status == 'all' ? 'You haven\'t created any support tickets yet.' : 'You don\'t have any $status tickets at the moment.',
            style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showCreateTicketDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeUtils.primary(context),
              foregroundColor: ThemeUtils.textOnPrimary(context),
            ),
            child: Text('Create Your First Ticket'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: ThemeUtils.error(context)),
          SizedBox(height: 16),
          Text('Unable to load tickets', style: ThemeUtils.headlineMedium(context).copyWith(color: ThemeUtils.error(context))),
          SizedBox(height: 8),
          Padding(padding: EdgeInsets.symmetric(horizontal: 32), child: Text(error, style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.textSecondary(context)), textAlign: TextAlign.center)),
          SizedBox(height: 16),
          ElevatedButton(onPressed: () => setState(() {}), style: ElevatedButton.styleFrom(backgroundColor: ThemeUtils.error(context), foregroundColor: Colors.white), child: Text('Retry')),
        ],
      ),
    );
  }

  List<Ticket> _filterTickets(List<Ticket> tickets, String query) {
    if (query.isEmpty) return tickets;
    final searchLower = query.toLowerCase();
    return tickets.where((ticket) => ticket.subject.toLowerCase().contains(searchLower) || ticket.description.toLowerCase().contains(searchLower)).toList();
  }

  bool _hasNewReply(Ticket ticket) {
    if (ticket.replies.isEmpty) return false;
    final lastReply = ticket.replies.last;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return lastReply.userId != currentUserId;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'unknown time';
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM dd, yyyy').format(timestamp);
  }

  String _formatStatus(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return 'Open';
      case TicketStatus.inProgress: return 'In Progress';
      case TicketStatus.resolved: return 'Resolved';
      case TicketStatus.closed: return 'Closed';
      case TicketStatus.onHold: return 'On Hold';
    }
  }

  String _formatCategory(TicketCategory category) {
    switch (category) {
      case TicketCategory.technical: return 'Technical';
      case TicketCategory.billing: return 'Billing';
      case TicketCategory.featureRequest: return 'Feature Request';
      case TicketCategory.general: return 'General';
      case TicketCategory.bugReport: return 'Bug Report';
      case TicketCategory.account: return 'Account';
    }
  }

  Icon _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Icon(Icons.mark_email_unread, size: 20, color: Colors.orange);
      case TicketStatus.inProgress: return Icon(Icons.autorenew, size: 20, color: Colors.blue);
      case TicketStatus.resolved: return Icon(Icons.check_circle, size: 20, color: Colors.green);
      case TicketStatus.closed: return Icon(Icons.verified, size: 20, color: Colors.grey);
      case TicketStatus.onHold: return Icon(Icons.pause_circle, size: 20, color: Colors.amber);
    }
  }

  IconData _getCategoryIcon(TicketCategory category) {
    switch (category) {
      case TicketCategory.technical: return Icons.computer;
      case TicketCategory.billing: return Icons.payment;
      case TicketCategory.featureRequest: return Icons.lightbulb;
      case TicketCategory.general: return Icons.chat;
      case TicketCategory.bugReport: return Icons.bug_report;
      case TicketCategory.account: return Icons.person;
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open: return Colors.orange;
      case TicketStatus.inProgress: return Colors.blue;
      case TicketStatus.resolved: return Colors.green;
      case TicketStatus.closed: return Colors.grey;
      case TicketStatus.onHold: return Colors.amber;
    }
  }

  void _viewTicketDetails(BuildContext context, Ticket ticket) {
    showDialog(
      context: context,
      builder: (context) => AdvancedTicketDetailsDialog(ticket: ticket),
      barrierDismissible: false,
    );
  }

  void _showCreateTicketDialog() {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please log in to create tickets'), backgroundColor: ThemeUtils.error(context)));
      return;
    }

    String? tenantId = currentUser.tenantId;

    if (tenantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to determine tenant information'), backgroundColor: ThemeUtils.error(context)));
      return;
    }

    showDialog(context: context, builder: (context) => CreateTicketDialog(tenantId: tenantId, isAdmin: false));
  }
}

class CreateTicketDialog extends StatefulWidget {
  final String tenantId;
  final bool isAdmin;

  const CreateTicketDialog({super.key, required this.tenantId, this.isAdmin = false});

  @override
  State<CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<CreateTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  TicketCategory _selectedCategory = TicketCategory.general;
  TicketPriority _selectedPriority = TicketPriority.medium;

  final List<File> _attachments = [];
  bool _isSubmitting = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThemeUtils.radius(context))),
      backgroundColor: ThemeUtils.surface(context),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600, maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeUtils.backgroundSolid(context),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(ThemeUtils.radius(context)), topRight: Radius.circular(ThemeUtils.radius(context))),
                    border: Border(bottom: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.2))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, color: ThemeUtils.primary(context)),
                      SizedBox(width: 12),
                      Text('Create Support Ticket', style: ThemeUtils.headlineMedium(context).copyWith(fontWeight: FontWeight.bold)),
                      Spacer(),
                      IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: ThemeUtils.textSecondary(context))),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category', style: ThemeUtils.bodyMedium(context).copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ThemeUtils.backgroundSolid(context),
                          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                          border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<TicketCategory>(
                            value: _selectedCategory,
                            items: TicketCategory.values.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Icon(_getCategoryIcon(category), size: 20, color: ThemeUtils.textPrimary(context)),
                                      SizedBox(width: 12),
                                      Text(_formatCategory(category), style: ThemeUtils.bodyMedium(context)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCategory = value!),
                            padding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Priority', style: ThemeUtils.bodyMedium(context).copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ThemeUtils.backgroundSolid(context),
                          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                          border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<TicketPriority>(
                            value: _selectedPriority,
                            items: TicketPriority.values.map((priority) {
                              return DropdownMenuItem(
                                value: priority,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Icon(_getPriorityIcon(priority), size: 20, color: _getPriorityColor(priority)),
                                      SizedBox(width: 12),
                                      Text(_formatPriority(priority), style: ThemeUtils.bodyMedium(context)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedPriority = value!),
                            padding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text('Subject', style: ThemeUtils.bodyMedium(context).copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          hintText: 'Brief description of your issue',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeUtils.radius(context)), borderSide: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.3))),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: ThemeUtils.bodyMedium(context),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a subject';
                          if (value.length < 5) return 'Subject must be at least 5 characters long';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      Text('Description', style: ThemeUtils.bodyMedium(context).copyWith(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Please provide detailed information about your issue...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThemeUtils.radius(context)), borderSide: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.3))),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: ThemeUtils.bodyMedium(context),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a description';
                          if (value.length < 10) return 'Description must be at least 10 characters long';
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // Text('Attachments', style: ThemeUtils.bodyMedium(context).copyWith(fontWeight: FontWeight.w600)),
                      // SizedBox(height: 8),
                      // Wrap(
                      //   spacing: 8,
                      //   runSpacing: 8,
                      //   children: [
                      //     GestureDetector(
                      //       onTap: _addAttachment,
                      //       child: Container(
                      //         width: 80,
                      //         height: 80,
                      //         decoration: BoxDecoration(
                      //           color: ThemeUtils.backgroundSolid(context),
                      //           borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                      //           border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3), style: BorderStyle.solid),
                      //         ),
                      //         child: Column(
                      //           mainAxisAlignment: MainAxisAlignment.center,
                      //           children: [
                      //             Icon(Icons.add, color: ThemeUtils.textSecondary(context)),
                      //             SizedBox(height: 4),
                      //             Text('Add', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context))),
                      //           ],
                      //         ),
                      //       ),
                      //     ),
                      //     ..._attachments.asMap().entries.map((entry) {
                      //       final index = entry.key;
                      //       final file = entry.value;
                      //       return Stack(
                      //         children: [
                      //           Container(
                      //               width: 80,
                      //               height: 80,
                      //               decoration: BoxDecoration(
                      //                   borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                      //                   image: DecorationImage(
                      //                       image: FileImage(file),
                      //                       fit: BoxFit.cover
                      //                   )
                      //               )
                      //           ),
                      //           Positioned(
                      //             top: 4,
                      //             right: 4,
                      //             child: GestureDetector(
                      //               onTap: () => _removeAttachment(index),
                      //               child: Container(
                      //                   padding: EdgeInsets.all(4),
                      //                   decoration: BoxDecoration(
                      //                       color: Colors.black.withOpacity(0.5),
                      //                       shape: BoxShape.circle
                      //                   ),
                      //                   child: Icon(Icons.close, size: 12, color: Colors.white)
                      //               ),
                      //             ),
                      //           )
                      //         ],
                      //       );
                      //     }),
                      //   ],
                      // ),
                      if (_attachments.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text('${_attachments.length} file${_attachments.length == 1 ? '' : 's'} attached', style: ThemeUtils.bodySmall(context).copyWith(color: ThemeUtils.textSecondary(context))),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ThemeUtils.backgroundSolid(context),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(ThemeUtils.radius(context)), bottomRight: Radius.circular(ThemeUtils.radius(context))),
                    border: Border(top: BorderSide(color: ThemeUtils.secondary(context).withOpacity(0.2))),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'))),
                      SizedBox(width: 12),
                      Expanded(child: _isSubmitting ? Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _submitTicket, child: Text('Create Ticket'))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addAttachment() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      if (image != null) setState(() => _attachments.add(File(image.path)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: ThemeUtils.error(context)));
    }
  }

  void _removeAttachment(int index) => setState(() => _attachments.removeAt(index));

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      List<String> attachmentUrls = [];
      for (final file in _attachments) {
        final bytes = await file.readAsBytes();
        final fileName = 'attachment_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final url = await TicketService.uploadAttachment(ticketId: 'temp', fileName: fileName, fileBytes: bytes);
        attachmentUrls.add(url);
      }

      await TicketService.createTicket(
        tenantId: widget.tenantId,
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
        attachments: attachmentUrls,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ticket created successfully!'), backgroundColor: ThemeUtils.success(context)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create ticket: $e'), backgroundColor: ThemeUtils.error(context)));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  String _formatCategory(TicketCategory category) {
    switch (category) {
      case TicketCategory.technical: return 'Technical';
      case TicketCategory.billing: return 'Billing';
      case TicketCategory.featureRequest: return 'Feature Request';
      case TicketCategory.general: return 'General';
      case TicketCategory.bugReport: return 'Bug Report';
      case TicketCategory.account: return 'Account';
    }
  }

  String _formatPriority(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return 'Low';
      case TicketPriority.medium: return 'Medium';
      case TicketPriority.high: return 'High';
      case TicketPriority.urgent: return 'Urgent';
    }
  }

  IconData _getCategoryIcon(TicketCategory category) {
    switch (category) {
      case TicketCategory.technical: return Icons.computer;
      case TicketCategory.billing: return Icons.payment;
      case TicketCategory.featureRequest: return Icons.lightbulb;
      case TicketCategory.general: return Icons.chat;
      case TicketCategory.bugReport: return Icons.bug_report;
      case TicketCategory.account: return Icons.person;
    }
  }

  IconData _getPriorityIcon(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return Icons.arrow_downward;
      case TicketPriority.medium: return Icons.remove;
      case TicketPriority.high: return Icons.arrow_upward;
      case TicketPriority.urgent: return Icons.warning;
    }
  }

  Color _getPriorityColor(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low: return Colors.green;
      case TicketPriority.medium: return Colors.blue;
      case TicketPriority.high: return Colors.orange;
      case TicketPriority.urgent: return Colors.red;
    }
  }
}