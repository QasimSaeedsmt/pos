import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mpcm/constants.dart';
import 'package:mpcm/theme_utils.dart';
import 'package:provider/provider.dart';
import '../analytics_screen.dart';
import '../modules/auth/providers/auth_provider.dart';

class ExpenseManagementScreen extends StatefulWidget {
  final AnalyticsService analyticsService;

  const ExpenseManagementScreen({super.key, required this.analyticsService});

  @override
  _ExpenseManagementScreenState createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  List<BusinessExpense> _expenses = [];
  bool _isLoading = true;
  TimePeriod _selectedPeriod = TimePeriods.thisMonth;
  double _totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      print('🔄 [ExpenseManagement] Loading expenses for period: ${_selectedPeriod.label}');
      print('📅 [ExpenseManagement] Period range: ${_selectedPeriod.startDate} to ${_selectedPeriod.endDate}');

      final expenses = await widget.analyticsService.getBusinessExpenses(_selectedPeriod);

      print('📊 [ExpenseManagement] Raw expenses loaded: ${expenses.length}');

      // Debug each expense
      for (var expense in expenses) {
        print('   💰 Expense: ${expense.description} - ${Constants.CURRENCY_NAME}${expense.amount} - ${expense.date} - Category: ${expense.category}');
      }

      if (mounted) {
        setState(() {
          _expenses = expenses;
          _totalExpenses = expenses.fold(0.0, (sum, expense) => sum + expense.amount);
        });
      }

      print('💰 [ExpenseManagement] Final _expenses list length: ${_expenses.length}');
      print('💰 [ExpenseManagement] Total expenses: ${Constants.CURRENCY_NAME}$_totalExpenses');

    } catch (e) {
      print('❌ [ExpenseManagement] Error loading expenses: $e');
      print('❌ [ExpenseManagement] Error stack: ${e.toString()}');
      if (mounted) {
        _showErrorSnackBar('Failed to load expenses: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkExpensesCollection() async {
    try {
      final snapshot = await widget.analyticsService.expensesRef.limit(1).get();
      print('📁 [ExpenseManagement] Expenses collection exists: ${snapshot.docs.isNotEmpty}');
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ [ExpenseManagement] Error checking expenses collection: $e');
      return false;
    }
  }

  void _showAddExpenseDialog({BusinessExpense? existingExpense}) {
    final isEditing = existingExpense != null;

    final categoryController = TextEditingController(text: existingExpense?.category ?? 'Other');
    final descriptionController = TextEditingController(text: existingExpense?.description ?? '');
    final amountController = TextEditingController(text: existingExpense?.amount.toStringAsFixed(2) ?? '');
    final notesController = TextEditingController(text: existingExpense?.notes ?? '');
    DateTime selectedDate = existingExpense?.date ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: ThemeUtils.surface(context),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(ThemeUtils.radius(context) * 2),
              topRight: Radius.circular(ThemeUtils.radius(context) * 2),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Expense' : 'Add New Expense',
                        style: ThemeUtils.headlineMedium(context),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: ThemeUtils.textSecondary(context)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
              
                  // Form
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Category Dropdown
                          Container(
                            decoration: ThemeUtils.cardDecoration(context),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: DropdownButtonFormField<String>(
                                value: categoryController.text,
                                items: expenseCategories.map((category) {
                                  return DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      category,
                                      style: ThemeUtils.bodyLarge(context),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    categoryController.text = value!;
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  labelStyle: ThemeUtils.bodyMedium(context),
                                  border: InputBorder.none,
                                  floatingLabelBehavior: FloatingLabelBehavior.always,
                                ),
                                dropdownColor: ThemeUtils.surface(context),
                                style: ThemeUtils.bodyLarge(context),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
              
                          // Description
                          Container(
                            decoration: ThemeUtils.cardDecoration(context),
                            child: TextField(
                              controller: descriptionController,
                              style: ThemeUtils.bodyLarge(context),
                              decoration: InputDecoration(
                                labelText: 'Description',
                                labelStyle: ThemeUtils.bodyMedium(context),
                                hintText: 'e.g., Office rent, Marketing ads, etc.',
                                hintStyle: ThemeUtils.bodyMedium(context)?.copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
              
                          // Amount
                          Container(
                            decoration: ThemeUtils.cardDecoration(context),
                            child: TextField(
                              controller: amountController,
                              style: ThemeUtils.bodyLarge(context),
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                labelStyle: ThemeUtils.bodyMedium(context),
                                prefixText: Constants.CURRENCY_NAME,
                                prefixStyle: ThemeUtils.bodyLarge(context)?.copyWith(fontWeight: FontWeight.bold),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          SizedBox(height: 16),
              
                          // Date Picker
                          Container(
                            decoration: ThemeUtils.cardDecoration(context),
                            child: InkWell(
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: ThemeUtils.primary(context),
                                        onPrimary: ThemeUtils.textOnPrimary(context),
                                        surface: ThemeUtils.surface(context),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (pickedDate != null) {
                                  setDialogState(() {
                                    selectedDate = pickedDate;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Date',
                                          style: ThemeUtils.bodyMedium(context).copyWith(
                                            color: ThemeUtils.textSecondary(context).withOpacity(0.8),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(selectedDate),
                                          style: ThemeUtils.bodyLarge(context),
                                        ),
                                      ],
                                    ),
                                    Icon(Icons.calendar_today, color: ThemeUtils.primary(context)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
              
                          // Notes
                          Container(
                            decoration: ThemeUtils.cardDecoration(context),
                            child: TextField(
                              controller: notesController,
                              style: ThemeUtils.bodyLarge(context),
                              decoration: InputDecoration(
                                labelText: 'Notes (Optional)',
                                labelStyle: ThemeUtils.bodyMedium(context),
                                hintText: 'Additional details...',
                                hintStyle: ThemeUtils.bodyMedium(context)?.copyWith(color: ThemeUtils.textSecondary(context).withOpacity(0.6)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                              ),
                              maxLines: 3,
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
              
                  // Actions
                  Row(
                    children: [
                      if (isEditing)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _deleteExpense(existingExpense!),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                              ),
                              side: BorderSide(color: ThemeUtils.error(context)),
                            ),
                            child: Text(
                              'Delete',
                              style: ThemeUtils.buttonText(context)?.copyWith(color: ThemeUtils.error(context)),
                            ),
                          ),
                        ),
                      if (isEditing) SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: ThemeUtils.buttonDecoration(context),
                          child: ElevatedButton(
                            onPressed: () async {
                              final amount = double.tryParse(amountController.text);
              
                              // Enhanced validation
                              if (descriptionController.text.isEmpty) {
                                _showErrorSnackBar('Please enter a description');
                                return;
                              }
              
                              if (amount == null || amount <= 0) {
                                _showErrorSnackBar('Please enter a valid amount greater than 0');
                                return;
                              }
              
                              if (selectedDate.isAfter(DateTime.now())) {
                                _showErrorSnackBar('Expense date cannot be in the future');
                                return;
                              }
              
                              final expense = BusinessExpense(
                                id: isEditing ? existingExpense!.id : DateTime.now().millisecondsSinceEpoch.toString(),
                                category: categoryController.text,
                                description: descriptionController.text,
                                amount: amount,
                                date: selectedDate,
                                notes: notesController.text.isEmpty ? null : notesController.text,
                              );
              
                              try {
                                if (isEditing) {
                                  await widget.analyticsService.addBusinessExpense(expense);
                                  _showSuccessSnackBar('Expense updated successfully');
                                } else {
                                  await widget.analyticsService.addBusinessExpense(expense);
                                  _showSuccessSnackBar('Expense added successfully');
                                }
                                Navigator.pop(context);
                                _loadExpenses();
                              } catch (e) {
                                _showErrorSnackBar('Failed to save expense: $e');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                              ),
                            ),
                            child: Text(
                              isEditing ? 'Update Expense' : 'Add Expense',
                              style: ThemeUtils.buttonText(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteExpense(BusinessExpense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeUtils.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
        title: Text(
          'Delete Expense?',
          style: ThemeUtils.headlineMedium(context),
        ),
        content: Text(
          'Are you sure you want to delete "${expense.description}"?',
          style: ThemeUtils.bodyLarge(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: ThemeUtils.bodyLarge(context)?.copyWith(color: ThemeUtils.textSecondary(context)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ThemeUtils.error(context), Colors.red[700]!],
              ),
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            ),
            child: TextButton(
              onPressed: () async {
                try {
                  await widget.analyticsService.deleteExpense(expense.id);
                  Navigator.pop(context);
                  _showSuccessSnackBar('Expense deleted successfully');
                  _loadExpenses();
                } catch (e) {
                  Navigator.pop(context);
                  _showErrorSnackBar('Failed to delete expense: $e');
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
              ),
              child: Text(
                'Delete',
                style: ThemeUtils.buttonText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ThemeUtils.accent(context),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.receipt_long, size: 50, color: ThemeUtils.textOnPrimary(context)),
            ),
            SizedBox(height: 24),
            Text(
              'No Expenses Recorded',
              style: ThemeUtils.headlineMedium(context),
            ),
            SizedBox(height: 12),
            Text(
              _isLoading
                  ? 'Loading expenses...'
                  : 'Add your first business expense to see\naccurate profit calculations',
              textAlign: TextAlign.center,
              style: ThemeUtils.bodyMedium(context),
            ),
            SizedBox(height: 24),
            if (!_isLoading)
              Container(
                decoration: ThemeUtils.buttonDecoration(context),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddExpenseDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                    ),
                  ),
                  icon: Icon(Icons.add, color: ThemeUtils.textOnPrimary(context)),
                  label: Text(
                    'Add First Expense',
                    style: ThemeUtils.buttonText(context),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: _expenses.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return _buildExpenseCard(expense);
      },
    );
  }

  Widget _buildExpenseCard(BusinessExpense expense) {
    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddExpenseDialog(existingExpense: expense),
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getCategoryGradient(expense.category),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  ),
                  child: Icon(Icons.receipt, color: Colors.white, size: 24),
                ),
                SizedBox(width: 16),

                // Expense Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        style: ThemeUtils.bodyLarge(context)?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(expense.category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(ThemeUtils.radius(context) / 2),
                            ),
                            child: Text(
                              expense.category,
                              style: ThemeUtils.bodySmall(context)?.copyWith(
                                color: _getCategoryColor(expense.category),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(expense.date),
                            style: ThemeUtils.bodySmall(context)?.copyWith(
                              color: ThemeUtils.textSecondary(context).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          expense.notes!,
                          style: ThemeUtils.bodySmall(context)?.copyWith(
                            color: ThemeUtils.textSecondary(context).withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Amount and Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${Constants.CURRENCY_NAME}${expense.amount.toStringAsFixed(0)}',
                      style: ThemeUtils.headlineMedium(context)?.copyWith(
                        color: ThemeUtils.error(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ThemeUtils.backgroundSolid(context).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(ThemeUtils.radius(context) / 2),
                      ),
                      child: Text(
                        _getPeriodLabel(expense.date),
                        style: ThemeUtils.bodySmall(context)?.copyWith(
                          color: ThemeUtils.textSecondary(context).withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getCategoryGradient(String category) {
    final color = _getCategoryColor(category);
    return [color, Color.lerp(color, Colors.black, 0.2)!];
  }

  Color _getCategoryColor(String category) {
    final colors = {
      'Rent': Colors.blue,
      'Utilities': Colors.green,
      'Salaries': Colors.orange,
      'Marketing': Colors.purple,
      'Supplies': Colors.brown,
      'Equipment': Colors.teal,
      'Maintenance': Colors.red,
      'Insurance': Colors.indigo,
      'Taxes': Colors.deepOrange,
      'Shipping': Colors.cyan,
      'Professional Fees': Colors.pink,
      'Other': Colors.grey,
    };
    return colors[category] ?? ThemeUtils.primary(context);
  }

  String _getPeriodLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month) return 'This Month';
    if (date.year == now.year && date.month == now.month - 1) return 'Last Month';
    return DateFormat('MMM yyyy').format(date);
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: ThemeUtils.success(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: ThemeUtils.error(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    if (!authProvider.currentUser!.canManageUsers) {
      return Scaffold(
        backgroundColor: ThemeUtils.backgroundSolid(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: ThemeUtils.accent(context),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.admin_panel_settings, size: 40, color: ThemeUtils.textOnPrimary(context)),
              ),
              SizedBox(height: 24),
              Text(
                'Admin Access Required',
                style: ThemeUtils.headlineLarge(context),
              ),
              SizedBox(height: 12),
              Text(
                'Expense management is only available for administrators.',
                textAlign: TextAlign.center,
                style: ThemeUtils.bodyMedium(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeUtils.backgroundSolid(context),
      body: Column(
        children: [
          // Header with Stats
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ThemeUtils.appBar(context),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Expense Management',
                        style: ThemeUtils.headlineLarge(context)?.copyWith(color: ThemeUtils.textOnPrimary(context)),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.bug_report, color: ThemeUtils.textOnPrimary(context)),
                            onPressed: () {
                              print('🐛 [DEBUG] Testing all periods...');
                              for (var period in TimePeriods.allPeriods) {
                                print('   📅 ${period.label}: ${period.startDate} to ${period.endDate}');
                              }
                              _checkExpensesCollection();
                            },
                            tooltip: 'Debug Info',
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, color: ThemeUtils.textOnPrimary(context)),
                            onPressed: _loadExpenses,
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Stats Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Expenses',
                              style: ThemeUtils.bodyMedium(context)?.copyWith(
                                color: ThemeUtils.textOnPrimary(context).withOpacity(0.8),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${Constants.CURRENCY_NAME}${_totalExpenses.toStringAsFixed(0)}',
                              style: ThemeUtils.headlineLarge(context)?.copyWith(
                                color: ThemeUtils.textOnPrimary(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_expenses.length} ${_expenses.length == 1 ? 'Expense' : 'Expenses'}',
                              style: ThemeUtils.bodyMedium(context)?.copyWith(
                                color: ThemeUtils.textOnPrimary(context).withOpacity(0.8),
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: ThemeUtils.primary(context),
                                borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                              ),
                              child: DropdownButton<TimePeriod>(
                                value: _selectedPeriod,
                                items: TimePeriods.allPeriods.map((period) {
                                  return DropdownMenuItem(
                                    value: period,
                                    child: Text(
                                      period.label,
                                      style: ThemeUtils.bodySmall(context)?.copyWith(color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (period) {
                                  print('🔄 [ExpenseManagement] Period changed to: ${period?.label}');
                                  setState(() => _selectedPeriod = period!);
                                  _loadExpenses();
                                },
                                dropdownColor: ThemeUtils.primary(context),
                                underline: SizedBox(),
                                icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                                style: ThemeUtils.bodySmall(context)?.copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expense List
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: ThemeUtils.primary(context),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading Expenses...',
                    style: ThemeUtils.bodyMedium(context),
                  ),
                ],
              ),
            )
                : _buildExpenseList(),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: ThemeUtils.buttonDecoration(context).gradient,
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddExpenseDialog(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Icon(Icons.add, color: ThemeUtils.textOnPrimary(context)),
        ),
      ),
    );
  }
}