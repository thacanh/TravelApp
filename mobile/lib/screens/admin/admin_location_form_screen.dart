import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import 'map_picker_screen.dart';

class AdminLocationFormScreen extends StatefulWidget {
  const AdminLocationFormScreen({super.key});

  @override
  State<AdminLocationFormScreen> createState() => _AdminLocationFormScreenState();
}

class _AdminLocationFormScreenState extends State<AdminLocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Vietnam');
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _imgUrlCtrl = TextEditingController();

  List<Map<String, String>> _selectedCategories = []; // [{slug, name}]
  List<String> _images = []; // danh sách URL cuối cùng
  final Map<int, bool> _uploadingIndex = {}; // index → đang upload?
  bool _isSaving = false;
  bool _initialized = false;
  Map<String, dynamic>? _editData;

  bool get _isEditMode => _editData != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _editData = args;
        _prefillForm(args);
      }
    }
  }

  void _prefillForm(Map<String, dynamic> data) {
    _nameCtrl.text = data['name'] ?? '';
    _descCtrl.text = data['description'] ?? '';
    _addressCtrl.text = data['address'] ?? '';
    _cityCtrl.text = data['city'] ?? '';
    _countryCtrl.text = data['country'] ?? 'Vietnam';
    _latCtrl.text = (data['latitude'] ?? '').toString();
    _lngCtrl.text = (data['longitude'] ?? '').toString();
    _images = List<String>.from(data['images'] ?? []);
    // N-N: đọc từ categories list
    final cats = data['categories'] as List?;
    if (cats != null) {
      _selectedCategories = cats
          .map((c) => {'slug': c['slug'] as String, 'name': c['name'] as String})
          .toList();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _addressCtrl.dispose();
    _cityCtrl.dispose(); _countryCtrl.dispose(); _latCtrl.dispose();
    _lngCtrl.dispose(); _imgUrlCtrl.dispose();
    super.dispose();
  }

  // ── Image from gallery ────────────────────────────────────────────────────
  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;

    for (final xfile in picked) {
      final insertIdx = _images.length;
      setState(() {
        _images.add(''); // placeholder
        _uploadingIndex[insertIdx] = true;
      });

      try {
        final mime = _mimeFromPath(xfile.path);
        final res = await _api.uploadLocationMedia(xfile.path, mime);
        if (res.statusCode == 200) {
          final url = res.data['url'] as String;
          if (mounted) {
            setState(() {
              _images[insertIdx] = url;
              _uploadingIndex.remove(insertIdx);
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _images.removeAt(insertIdx);
              _uploadingIndex.remove(insertIdx);
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _images.removeAt(insertIdx);
            _uploadingIndex.remove(insertIdx);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload lỗi: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    }
  }

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      default: return 'image/jpeg';
    }
  }

  void _addImageUrl() {
    final url = _imgUrlCtrl.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL phải bắt đầu bằng http/https')),
      );
      return;
    }
    setState(() {
      _images.add(url);
      _imgUrlCtrl.clear();
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      // Rebuild uploadingIndex map
      final newMap = <int, bool>{};
      _uploadingIndex.forEach((k, v) {
        if (k < index) newMap[k] = v;
        else if (k > index) newMap[k - 1] = v;
      });
      _uploadingIndex
        ..clear()
        ..addAll(newMap);
    });
  }

  Future<void> _pickFromMap() async {
    final result = await Navigator.push<Map<String, double>>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _latCtrl.text = result['lat']!.toStringAsFixed(6);
        _lngCtrl.text = result['lng']!.toStringAsFixed(6);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng chọn ít nhất 1 danh mục'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final validImages = _images.where((u) => u.isNotEmpty).toList();

    setState(() => _isSaving = true);
    final payload = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'categories_input': _selectedCategories
          .map((c) => {'slug': c['slug'], 'name': c['name']})
          .toList(),
      'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'country': _countryCtrl.text.trim().isEmpty ? 'Vietnam' : _countryCtrl.text.trim(),
      'latitude': double.tryParse(_latCtrl.text),
      'longitude': double.tryParse(_lngCtrl.text),
      'images': validImages,
      'thumbnail': validImages.isNotEmpty ? validImages.first : null,
    };

    try {
      if (_isEditMode) {
        await _api.updateLocation(_editData!['id'], payload);
      } else {
        await _api.createLocation(payload);
      }
      if (mounted) {
        await context.read<LocationProvider>().fetchLocations(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Đã cập nhật địa điểm!' : 'Đã thêm địa điểm mới!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final msg = e.toString().contains('403')
            ? 'Không đủ quyền Admin'
            : e.toString().contains('422')
                ? 'Dữ liệu không hợp lệ'
                : 'Lỗi: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<LocationProvider>().categories;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Chỉnh sửa địa điểm' : 'Thêm địa điểm'),
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(LucideIcons.save, size: 18),
              label: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Thông tin cơ bản ─────────────────────────────────────────
            _SectionHeader(title: 'Thông tin cơ bản', icon: LucideIcons.info),
            const SizedBox(height: 12),
            _buildField(controller: _nameCtrl, label: 'Tên địa điểm *',
              hint: 'VD: Vịnh Hạ Long', icon: LucideIcons.mapPin,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tên địa điểm' : null),
            const SizedBox(height: 12),
            _buildField(controller: _descCtrl, label: 'Mô tả',
              hint: 'Giới thiệu về địa điểm...', icon: LucideIcons.fileText, maxLines: 4),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildField(controller: _cityCtrl, label: 'Tỉnh/Thành phố *',
                hint: 'VD: Hà Nội', icon: LucideIcons.building2,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập nơi' : null)),
              const SizedBox(width: 12),
              Expanded(child: _buildField(controller: _countryCtrl, label: 'Quốc gia',
                hint: 'Vietnam', icon: LucideIcons.flag)),
            ]),
            const SizedBox(height: 12),
            _buildField(controller: _addressCtrl, label: 'Địa chỉ chi tiết',
              hint: 'VD: 19C Hoàng Diệu, Ba Đình, Hà Nội', icon: LucideIcons.navigation),

            // ── Danh mục (N-N) ─────────────────────────────────────────────
            const SizedBox(height: 24),
            _SectionHeader(title: 'Danh mục', icon: LucideIcons.tag),
            const SizedBox(height: 4),
            const Text('Chọn một hoặc nhiều danh mục',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            categories.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildCategoryPicker(categories),

            // ── Toạ độ ─────────────────────────────────────────────────────
            const SizedBox(height: 24),
            _SectionHeader(title: 'Vị trí trên bản đồ', icon: LucideIcons.map),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildField(controller: _latCtrl, label: 'Vĩ độ (Latitude)',
                hint: '21.0285', icon: LucideIcons.crosshair,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 12),
              Expanded(child: _buildField(controller: _lngCtrl, label: 'Kinh độ (Longitude)',
                hint: '105.8521', icon: LucideIcons.crosshair,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickFromMap,
              icon: const Icon(LucideIcons.locateFixed, size: 18),
              label: const Text('Chọn toạ độ từ bản đồ'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppTheme.primaryColor.withAlpha(100)),
                foregroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            // ── Hình ảnh ─────────────────────────────────────────────────
            const SizedBox(height: 24),
            _SectionHeader(title: 'Hình ảnh', icon: LucideIcons.image),
            const SizedBox(height: 8),

            // Nút chọn ảnh từ gallery + nhập URL
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickAndUpload,
                  icon: const Icon(LucideIcons.imagePlus, size: 18),
                  label: const Text('Chọn từ thư viện'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primaryColor.withAlpha(100)),
                    foregroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // URL input row
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _imgUrlCtrl,
                  decoration: InputDecoration(
                    labelText: 'Hoặc dán URL ảnh',
                    hintText: 'https://...',
                    prefixIcon: const Icon(LucideIcons.link, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  keyboardType: TextInputType.url,
                  onFieldSubmitted: (_) => _addImageUrl(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addImageUrl,
                icon: const Icon(LucideIcons.plus),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Images grid
            if (_images.isNotEmpty)
              SizedBox(
                height: 115,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (_, i) => _buildImageThumb(i),
                ),
              )
            else
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.imageOff, color: Colors.grey, size: 24),
                      SizedBox(height: 6),
                      Text('Chưa có hình ảnh', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),
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
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.save, size: 20),
                  label: Text(
                    _isEditMode ? 'Cập nhật địa điểm' : 'Thêm địa điểm',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
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

  // ── Category picker & new category dialog ───────────────────────────────────────────
  Widget _buildCategoryPicker(List<Category> categories) {
    // Gom category đã chọn + các category mới do user tạo không có trong list cũ
    final existingSlugs = categories.map((c) => c.slug).toSet();
    final customCats = _selectedCategories
        .where((c) => !existingSlugs.contains(c['slug']))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Existing categories from DB
            ...categories.map((cat) {
              final selected = _selectedCategories.any((c) => c['slug'] == cat.slug);
              return FilterChip(
                label: Text(cat.name),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedCategories.add({'slug': cat.slug, 'name': cat.name});
                  } else {
                    _selectedCategories.removeWhere((c) => c['slug'] == cat.slug);
                  }
                }),
                selectedColor: AppTheme.primaryColor.withAlpha(30),
                checkmarkColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: selected ? AppTheme.primaryColor : Colors.grey[300]!,
                  width: selected ? 1.5 : 1,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              );
            }),
            // Custom (newly created) categories
            ...customCats.map((cat) {
              return Chip(
                label: Text(cat['name']!),
                backgroundColor: Colors.purple.withAlpha(20),
                side: const BorderSide(color: Colors.purple, width: 1.2),
                labelStyle: const TextStyle(color: Colors.purple, fontWeight: FontWeight.w600),
                avatar: const Icon(Icons.new_releases, size: 14, color: Colors.purple),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() {
                  _selectedCategories.removeWhere((c) => c['slug'] == cat['slug']);
                }),
              );
            }),
            // Nút tạo category mới
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Thêm mới', style: TextStyle(color: Colors.white, fontSize: 12.5)),
              backgroundColor: AppTheme.primaryColor,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onPressed: _showAddCategoryDialog,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final slugCtrl = TextEditingController();
    bool autoSlug = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tạo danh mục mới', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Tên danh mục *',
                  hintText: 'VD: Hang động',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) {
                  if (autoSlug) {
                    final slug = v.toLowerCase().trim()
                        .replaceAll(RegExp(r'\s+'), '-')
                        .replaceAll(RegExp(r'[^\w\u00C0-\u024F-]'), '');
                    setStateDialog(() => slugCtrl.text = slug);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: slugCtrl,
                decoration: InputDecoration(
                  labelText: 'Slug (ID dũ) *',
                  hintText: 'VD: hang-dong',
                  helperText: 'Chỉ gồm chữ thường, số, gạch nối',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setStateDialog(() => autoSlug = false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final slug = slugCtrl.text.trim();
                if (name.isEmpty || slug.isEmpty) return;
                // Kiểm tra trùng slug
                final exists = _selectedCategories.any((c) => c['slug'] == slug);
                if (!exists) {
                  setState(() {
                    _selectedCategories.add({'slug': slug, 'name': name});
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumb(int i) {
    final url = _images[i];
    final isFirst = i == 0;
    final isUploading = _uploadingIndex[i] == true;

    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFirst ? AppTheme.primaryColor : Colors.grey[300]!,
              width: isFirst ? 2 : 1,
            ),
            color: Colors.grey[100],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: isUploading
                ? const Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      SizedBox(height: 6),
                      Text('Đang tải...', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ))
                : url.isEmpty
                    ? const Icon(LucideIcons.image, color: Colors.grey)
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(LucideIcons.imageOff, color: Colors.grey),
                      ),
          ),
        ),
        // Cover badge
        if (isFirst && !isUploading && url.isNotEmpty)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        // Remove button
        if (!isUploading)
          Positioned(
            top: 2,
            right: 10,
            child: GestureDetector(
              onTap: () => _removeImage(i),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
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
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha(18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
