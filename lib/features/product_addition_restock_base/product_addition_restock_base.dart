import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants.dart';
import '../connectivityBase/local_db_base.dart';
import '../invoiceBase/invoice_and_printing_base.dart';
import '../main_navigation/main_navigation_base.dart';
import '../product_selling/product_selling_base.dart';

class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int count;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.count,
    this.imageUrl,
  });

  factory Category.fromFirestore(Map<String, dynamic> data, String id) {
    return Category(
      id: id,
      name: data['name']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      description: data['description']?.toString(),
      count: data['count'] ?? 0,
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'count': count,
      'imageUrl': imageUrl,
    };
  }
}
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  _CategoryManagementScreenState createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _posService.getCategories();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      print('Failed to load categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load categories: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Category Name *',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter category name')),
                );
                return;
              }

              try {
                final category = Category(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  slug: nameController.text.trim().toLowerCase().replaceAll(
                    ' ',
                    '-',
                  ),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  count: 0,
                );

                await _posService.addCategory(category);
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Category "${category.name}" added successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to add category: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              'No Categories Yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              'Add categories to organize your products',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddCategoryDialog,
              icon: Icon(Icons.add),
              label: Text('Add First Category'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.category, color: Colors.blue),
            ),
            title: Text(
              category.name,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (category.description != null) Text(category.description!),
                SizedBox(height: 4),
                Text(
                  '${category.count} products',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(category),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Note: You'll need to implement deleteCategory in your POS service
                // await _posService.deleteCategory(category.id);
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete category: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Categories'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddCategoryDialog,
            tooltip: 'Add Category',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildCategoryList(),
    );
  }
}
class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  _ProductManagementScreenState createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<Product> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  // In ProductManagementScreen - UPDATE the _loadProducts method
  Future<void> _loadProducts() async {
    final LocalDatabase localDb = LocalDatabase();
    try {
      List<Product> products;

      if (_posService.isOnline) {
        // Load from online source
        products = await _posService.fetchProducts(limit: 100);
      } else {
        // Load ALL products from local database, not just limited ones
        products = await localDb.getAllProducts();
      }

      setState(() {
        _products.clear();
        _products.addAll(products);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddProductScreen()),
    ).then((_) => _loadProducts());
  }

  void _navigateToRestockProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RestockProductScreen()),
    ).then((_) => _loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text('Error: $_errorMessage'))
          : Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToAddProduct,
                    icon: Icon(Icons.add),
                    label: Text('Add New Product'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToRestockProduct,
                    icon: Icon(Icons.inventory),
                    label: Text('Restock Product'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ProductManagementCard(
                  product: product,
                  onEdit: () {
                    // Navigate to edit product screen
                  },
                  onDelete: () {
                    _deleteProduct(product.id);
                  },
                  onRestock: () {
                    _showRestockDialog(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Product'),
        content: Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _posService.deleteProduct(productId);
        _loadProducts();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Product deleted')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete product: $e')));
      }
    }
  }

  void _showRestockDialog(Product product) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${product.stockQuantity}'),
            SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity to add',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                try {
                  await _posService.restockProduct(product.id, quantity);
                  Navigator.of(context).pop();
                  _loadProducts();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Product restocked')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to restock: $e')),
                  );
                }
              }
            },
            child: Text('Restock'),
          ),
        ],
      ),
    );
  }
}

// Product Management Card
class ProductManagementCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestock;

  const ProductManagementCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onRestock,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                image: product.imageUrl != null
                    ? DecorationImage(
                  image: NetworkImage(product.imageUrl!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'SKU: ${product.sku}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(0)} • Stock: ${product.stockQuantity}',
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'restock', child: Text('Restock')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'restock':
                    onRestock();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Add Product Screen
class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final List<Category> _categories = [];
  final List<String> _selectedCategoryIds = [];
  bool _isLoading = false;
  bool _isCheckingBarcode = false;
  String? _barcodeError;
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _posService.getCategories();
      setState(() {
        _categories.clear();
        _categories.addAll(categories);
      });
    } catch (e) {
      print('Failed to load categories: $e');
    } finally {
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<bool> _isBarcodeDuplicate(String barcode) async {
    if (barcode.isEmpty) return false;
    setState(() {
      _isCheckingBarcode = true;
      _barcodeError = null;
    });
    try {
      if (_posService.isOnline) {
        final onlineProducts = await _posService.searchProductsBySKU(barcode);
        if (onlineProducts.isNotEmpty) {
          return true;
        }
      }
      final LocalDatabase localDb = LocalDatabase();
      final localProduct = await localDb.getProductBySku(barcode);
      return localProduct != null;
    } catch (e) {
      print('Error checking barcode duplicate: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _isCheckingBarcode = false);
      }
    }
  }

  Future<void> _scanAndSetBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'add',
    );
    if (barcode != null && barcode.isNotEmpty) {
      setState(() {
        _skuController.text = barcode;
        _barcodeError = null;
      });
      Future.delayed(Duration(milliseconds: 500), () {
        _validateBarcodeUniqueness(barcode);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode scanned: $barcode'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _validateBarcodeUniqueness(String barcode) async {
    if (barcode.isEmpty) return;
    final isDuplicate = await _isBarcodeDuplicate(barcode);
    if (mounted) {
      setState(() {
        if (isDuplicate) {
          _barcodeError = 'This barcode is already used by another product';
        } else {
          _barcodeError = null;
        }
      });
    }
  }

  Future<bool> _validateForm() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    final barcode = _skuController.text.trim();
    if (barcode.isNotEmpty) {
      final isDuplicate = await _isBarcodeDuplicate(barcode);
      if (isDuplicate) {
        setState(() {
          _barcodeError = 'This barcode is already used by another product';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please use a unique barcode'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      setState(() {
        _selectedImages.addAll(images);
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick images: $e')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitProduct() async {
    if (!await _validateForm()) return;
    setState(() => _isLoading = true);
    try {
      final selectedCategories = _categories
          .where((cat) => _selectedCategoryIds.contains(cat.id))
          .toList();

      final product = Product(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        sku: _skuController.text.trim(),
        price: double.parse(_priceController.text),
        stockQuantity: int.parse(_stockController.text),
        inStock: true,
        stockStatus: 'instock',
        description: _descriptionController.text,
        status: 'publish',
        categories: selectedCategories,
      );

      await _posService.addProduct(product, _selectedImages);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _selectedImages.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  size: 50,
                  color: Colors.grey,
                ),
                Text('Tap to add product images'),
                SizedBox(height: 4),
                Text(
                  'Max 5 images',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            )
                : Stack(
              children: [
                PageView.builder(
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Image.file(
                          File(_selectedImages[index].path),
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => _removeImage(index),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_selectedImages.length < 5)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FloatingActionButton.small(
                      onPressed: _pickImages,
                      child: Icon(Icons.add),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '${_selectedImages.length}/5 images selected. Tap image to remove.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        _isLoadingCategories
            ? CircularProgressIndicator()
            : _categories.isEmpty
            ? Text(
          'No categories available. Add categories in settings.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        )
            : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategoryIds.contains(category.id);
            return FilterChip(
              label: Text(category.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategoryIds.add(category.id);
                  } else {
                    _selectedCategoryIds.remove(category.id);
                  }
                });
              },
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[800],
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        if (_selectedCategoryIds.isNotEmpty)
          Text(
            'Selected: ${_selectedCategoryIds.length} categor${_selectedCategoryIds.length == 1 ? 'y' : 'ies'}',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _skuController,
          decoration: InputDecoration(
            labelText: 'SKU/Barcode',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.qr_code),
            suffixIcon: _isCheckingBarcode
                ? Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
                : IconButton(
              icon: Icon(Icons.qr_code_scanner),
              onPressed: _scanAndSetBarcode,
              tooltip: 'Scan Barcode',
            ),
            errorText: _barcodeError,
          ),
          onChanged: (value) {
            if (_barcodeError != null && value != _skuController.text) {
              setState(() => _barcodeError = null);
            }
            if (value.isNotEmpty && value.length >= 3) {
              Future.delayed(Duration(milliseconds: 1000), () {
                if (mounted && value == _skuController.text) {
                  _validateBarcodeUniqueness(value);
                }
              });
            }
          },
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Please enter SKU or scan barcode';
            }
            if (_barcodeError != null) {
              return _barcodeError;
            }
            return null;
          },
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Barcode must be unique. We\'ll check for duplicates automatically.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        if (_barcodeError != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _barcodeError!,
                    style: TextStyle(color: Colors.red[800]),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: _isLoading
              ? ElevatedButton(
            onPressed: null,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          )
              : ElevatedButton(
            onPressed: _submitProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: _barcodeError != null ? Colors.grey : null,
            ),
            child: Text(
              'ADD PRODUCT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New Product')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildImagePickerSection(),
              SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) =>
                value?.isEmpty ?? true ? 'Please enter product name' : null,
              ),
              SizedBox(height: 16),
              _buildCategorySelection(),
              SizedBox(height: 16),
              _buildBarcodeField(),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: Constants.CURRENCY_NAME,
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter price';
                  if (double.tryParse(value!) == null)
                    return 'Please enter valid price';
                  if (double.parse(value) <= 0)
                    return 'Price must be greater than 0';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true)
                    return 'Please enter stock quantity';
                  if (int.tryParse(value!) == null)
                    return 'Please enter valid quantity';
                  if (int.parse(value) < 0) return 'Stock cannot be negative';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Restock Product Screen
class RestockProductScreen extends StatefulWidget {
  const RestockProductScreen({super.key});

  @override
  _RestockProductScreenState createState() => _RestockProductScreenState();
}

class _RestockProductScreenState extends State<RestockProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final List<Product> _allProducts = [];
  Product? _selectedProduct;
  final bool _isScanning = false;
  bool _isLoading = false;
  bool _isLoadingProducts = false;
  final FocusNode _quantityFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
    _loadAllProducts();
  }

  @override
  void dispose() {
    _quantityFocusNode.dispose();
    super.dispose();
  }

  // In RestockProductScreen - UPDATE the _loadAllProducts method
  Future<void> _loadAllProducts() async {
    setState(() => _isLoadingProducts = true);
    final LocalDatabase localDb = LocalDatabase();
    try {
      List<Product> products;

      if (_posService.isOnline) {
        products = await _posService.fetchProducts(limit: 1000);
      } else {
        // Load ALL products when offline
        products = await localDb.getAllProducts();
      }

      setState(() {
        _allProducts.clear();
        _allProducts.addAll(products);
      });
    } catch (e) {
      print('Failed to load products: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'restock',
    );
    if (barcode != null && barcode.isNotEmpty) {
      _barcodeController.text = barcode;
      await _searchProductByBarcode(barcode);
    }
  }

  Future<void> _searchProductByBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      List<Product> products = await _posService.searchProductsBySKU(barcode);

      if (products.isEmpty) {
        print('Primary search failed, trying local search...');
        products = _allProducts.where((p) => p.sku == barcode).toList();
      }

      if (products.isNotEmpty) {
        final product = products.first;
        setState(() {
          _selectedProduct = product;
        });

        _quantityController.text = '1';
        FocusScope.of(context).requestFocus(_quantityFocusNode);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product found: ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _selectedProduct = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No product found with barcode: $barcode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _selectedProduct = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restockProduct() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a product first')));
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter valid quantity')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _posService.restockProduct(_selectedProduct!.id, quantity);

      // Show appropriate message based on online status
      if (_posService.isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedProduct!.name} restocked with $quantity items!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadAllProducts();
      Navigator.of(context).pop();
    } catch (e) {
      // Even if there's an error, it might be because we're saving offline
      final errorMessage = e.toString();
      if (errorMessage.contains('offline') ||
          errorMessage.contains('Saved offline')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock saved offline. Will sync when online.'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadAllProducts();
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restock failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProduct = null;
      _barcodeController.clear();
      _quantityController.text = '1';
    });
  }

  int get _newStockQuantity {
    final currentStock = _selectedProduct?.stockQuantity ?? 0;
    final addedQuantity = int.tryParse(_quantityController.text) ?? 0;
    return currentStock + addedQuantity;
  }

  bool get _canRestock {
    return _selectedProduct != null &&
        _quantityController.text.isNotEmpty &&
        (int.tryParse(_quantityController.text) ?? 0) > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Restock Product'),
        actions: [
          if (_selectedProduct != null)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear Selection',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllProducts,
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: _isLoadingProducts
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          shrinkWrap: true,
          children: [
            // Manual Product Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.list, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Select Product Manually',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<Product>(
                      initialValue: _selectedProduct,
                      decoration: InputDecoration(
                        labelText: 'Choose Product',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      items: _allProducts.map((product) {
                        return DropdownMenuItem(
                          value: product,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'SKU: ${product.sku} | Stock: ${product.stockQuantity}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (product) {
                        setState(() {
                          _selectedProduct = product;
                          if (product != null) {
                            _barcodeController.text = product.sku;
                            _quantityController.text = '1';
                            FocusScope.of(
                              context,
                            ).requestFocus(_quantityFocusNode);
                          }
                        });
                      },
                      isExpanded: true,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // OR Divider
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            SizedBox(height: 16),

            // Barcode Input Section
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Scan Barcode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _barcodeController,
                            decoration: InputDecoration(
                              labelText: 'Barcode/SKU',
                              border: OutlineInputBorder(),
                              suffixIcon: _isLoading
                                  ? Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : _barcodeController.text.isNotEmpty
                                  ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _barcodeController.clear();
                                  setState(() {});
                                },
                              )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {});
                              if (value.length >= 3) {
                                _searchProductByBarcode(value);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        _isScanning
                            ? CircularProgressIndicator()
                            : IconButton(
                          icon: Icon(
                            Icons.qr_code_scanner,
                            size: 32,
                          ),
                          onPressed: _scanBarcode,
                          tooltip: 'Scan Barcode',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            padding: EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ),
                    if (_barcodeController.text.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Press scan button or enter to search',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Product Info Section
            if (_selectedProduct != null) ...[
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Selected Product',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              image: _selectedProduct!.imageUrl != null
                                  ? DecorationImage(
                                image: NetworkImage(
                                  _selectedProduct!.imageUrl!,
                                ),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                            child: _selectedProduct!.imageUrl == null
                                ? Icon(
                              Icons.inventory,
                              color: Colors.grey[400],
                            )
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedProduct!.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'SKU: ${_selectedProduct!.sku}',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Current Stock: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _selectedProduct!.stockQuantity
                                          .toString(),
                                      style: TextStyle(
                                        color: _selectedProduct!.inStock
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Price: ${Constants.CURRENCY_NAME}${_selectedProduct!.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Quantity Input Section
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.add_circle, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Restock Quantity',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: _quantityController,
                        focusNode: _quantityFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Quantity to Add',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.add),
                          hintText: 'Enter quantity',
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _quantityController.text = '1';
                              setState(() {});
                            },
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {});
                        },
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'New Total Stock:',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$_newStockQuantity',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],

            Spacer(),

            // Restock Button
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isLoading
                        ? ElevatedButton(
                      onPressed: null,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                        : ElevatedButton(
                      onPressed: _canRestock
                          ? _restockProduct
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canRestock
                            ? Colors.green
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'RESTOCK PRODUCT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
