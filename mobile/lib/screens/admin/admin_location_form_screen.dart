import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';

class AdminLocationFormScreen extends StatefulWidget {
  const AdminLocationFormScreen({super.key});

  @override
  State<AdminLocationFormScreen> createState() => _AdminLocationFormScreenState();
}

class _AdminLocationFormScreenState extends State<AdminLocationFormScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Vietnam');
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();

  String? _selectedCategory;
  List<Category> _categories = [];
  List<String> _images = [];
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _editData; // non-null if editing

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map<String, dynamic> && _editData == null) {
      _editData = arg;
      _nameCtrl.text = arg['name'] ?? '';
      _descCtrl.text = arg['description'] ?? '';
      _cityCtrl.text = arg['city'] ?? '';
      _countryCtrl.text = arg['country'] ?? 'Vietnam';
      _addressCtrl.text = arg['address'] ?? '';
      _latCtrl.text = arg['latitude']?.toString() ?? '';
      _lngCtrl.text = arg['longitude']?.toString() ?? '';
      _selectedCategory = arg['category'];
      _images = List<String>.from(arg['images'] ?? []);
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.getCategories();
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _categories = (res.data as List).map((c) => Category.fromJson(c)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    setState(() => _isSaving = true);

    final payload = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'category': _selectedCategory,
      'city': _cityCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'latitude': _latCtrl.text.trim().isEmpty ? null : double.tryParse(_latCtrl.text.trim()),
      'longitude': _lngCtrl.text.trim().isEmpty ? null : double.tryParse(_lngCtrl.text.trim()),
      'images': _images,
    };

    try {
      if (_editData != null) {
        await _api.updateLocation(_editData!['id'], payload);
      } else {
        await _api.createLocation(payload);
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editData != null ? 'Đã cập nhật địa điểm' : 'Đã thêm địa điểm mới'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.errorColor),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  void _addImage() {
    final url = _imageCtrl.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL ảnh phải bắt đầu bằng http')),
      );
      return;
    }
    setState(() {
      _images.add(url);
      _imageCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _editData != null;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(isEdit ? 'Chỉnh sửa địa điểm' : 'Thêm địa điểm mới'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(LucideIcons.save, size: 18),
                    label: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Section(title: 'Thông tin cơ bản', icon: LucideIcons.info),
                  const SizedBox(height: 12),

                  _buildField(
                    controller: _nameCtrl,
                    label: 'Tên địa điểm *',
                    icon: LucideIcons.mapPin,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Không được để trống' : null,
                  ),
                  const SizedBox(height: 12),

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Danh mục *',
                      prefixIcon: const Icon(LucideIcons.tag, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F8),
                    ),
                    hint: const Text('Chọn danh mục'),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c.slug, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                    validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _cityCtrl,
                          label: 'Thành phố *',
                          icon: LucideIcons.building2,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _countryCtrl,
                          label: 'Quốc gia',
                          icon: LucideIcons.globe,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildField(
                    controller: _addressCtrl,
                    label: 'Địa chỉ',
                    icon: LucideIcons.navigation,
                  ),
                  const SizedBox(height: 12),

                  _buildField(
                    controller: _descCtrl,
                    label: 'Mô tả',
                    icon: LucideIcons.alignLeft,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 24),
                  _Section(title: 'Tọa độ GPS', icon: LucideIcons.locateFixed),
                  const SizedBox(height: 4),
                  const Text('  (lat/lng để bật tính năng bản đồ và lịch trình)',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          controller: _latCtrl,
                          label: 'Vĩ độ (Latitude)',
                          icon: LucideIcons.arrowUpDown,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final d = double.tryParse(v);
                            if (d == null || d < -90 || d > 90) return 'Không hợp lệ';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          controller: _lngCtrl,
                          label: 'Kinh độ (Longitude)',
                          icon: LucideIcons.arrowLeftRight,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final d = double.tryParse(v);
                            if (d == null || d < -180 || d > 180) return 'Không hợp lệ';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _Section(title: 'Hình ảnh', icon: LucideIcons.image),
                  const SizedBox(height: 12),

                  // Image URL input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _imageCtrl,
                          decoration: InputDecoration(
                            hintText: 'Dán URL ảnh (https://...)',
                            prefixIcon: const Icon(LucideIcons.link, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: const Color(0xFFF3F4F8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addImage,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                        child: const Icon(LucideIcons.plus, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Image list
                  if (_images.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (ctx, i) => Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _images[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(LucideIcons.imageOff, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.removeAt(i)),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.x, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppTheme.buttonShadow,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(isEdit ? LucideIcons.save : LucideIcons.plusCircle, size: 20),
                        label: Text(isEdit ? 'Cập nhật địa điểm' : 'Thêm địa điểm',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        filled: true,
        fillColor: const Color(0xFFF3F4F8),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  const _Section({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
