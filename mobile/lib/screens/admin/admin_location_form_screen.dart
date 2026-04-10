import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import 'map_picker_screen.dart';

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
  final _categoryCtrl = TextEditingController();
  List<String> _images = [];          // URL danh sách ảnh/video đã upload
  List<bool> _uploadingFlags = [];    // true = item đang upload
  String? _thumbnailUrl;              // Ảnh đại diện được người dùng chọn
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, dynamic>? _editData; // non-null if editing

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _imageCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

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
      // Khởi tạo flags cho ảnh đã có sẵn (không đang upload)
      _uploadingFlags = List.filled(_images.length, false);
      _thumbnailUrl = arg['thumbnail'] as String?;
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
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
    // Nếu đang edit, điền sẵn giá trị vào ô danh mục
    if (_selectedCategory != null && _categoryCtrl.text.isEmpty) {
      final match = _categories.where((c) => c.slug == _selectedCategory).firstOrNull;
      _categoryCtrl.text = match?.name ?? _selectedCategory!;
    }
  }

  Future<void> _save() async {
    // Nếu user đang gõ tự do, dùng text đó làm slug
    if (_categoryCtrl.text.trim().isNotEmpty && _selectedCategory == null) {
      _selectedCategory = _categoryCtrl.text.trim().toLowerCase().replaceAll(' ', '_');
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn hoặc nhập danh mục'), backgroundColor: AppTheme.errorColor),
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
      'thumbnail': _thumbnailUrl,   // null = dùng images[0] làm fallback
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
      _uploadingFlags.add(false);
      _imageCtrl.clear();
    });
  }

  /// Pick ảnh hoặc video từ thiết bị và upload lên server
  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      if (isVideo) {
        file = await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 5));
      } else {
        file = await picker.pickImage(source: source, imageQuality: 85);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở thư viện ảnh: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }
    if (file == null) return;

    // Thêm placeholder đang upload
    setState(() {
      _images.add('');
      _uploadingFlags.add(true);
    });
    final idx = _images.length - 1;

    try {
      // Xác định MIME type
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = isVideo
          ? (ext == 'mov' ? 'video/quicktime' : 'video/mp4')
          : (ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg');

      final res = await _api.uploadLocationMedia(file.path, mimeType);
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _images[idx] = res.data['url'] as String;
          _uploadingFlags[idx] = false;
        });
      } else {
        throw Exception('Upload thất bại (${res.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _images.removeAt(idx);
          _uploadingFlags.removeAt(idx);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi upload: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _showPickMediaSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primaryColor.withAlpha(30), shape: BoxShape.circle),
                child: Icon(LucideIcons.image, color: AppTheme.primaryColor, size: 20)),
              title: const Text('Chọn ảnh từ thiết bị'),
              onTap: () { Navigator.pop(context); _pickMedia(ImageSource.gallery); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withAlpha(30), shape: BoxShape.circle),
                child: const Icon(LucideIcons.video, color: Colors.orange, size: 20)),
              title: const Text('Chọn video từ thiết bị'),
              onTap: () { Navigator.pop(context); _pickMedia(ImageSource.gallery, isVideo: true); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withAlpha(30), shape: BoxShape.circle),
                child: const Icon(LucideIcons.camera, color: Colors.teal, size: 20)),
              title: const Text('Chụp ảnh bằng camera'),
              onTap: () { Navigator.pop(context); _pickMedia(ImageSource.camera); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.withAlpha(30), shape: BoxShape.circle),
                child: const Icon(LucideIcons.link, color: Colors.grey, size: 20)),
              title: const Text('Dán link URL'),
              onTap: () { Navigator.pop(context); _showUrlDialog(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showUrlDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập URL ảnh'),
        content: TextField(
          controller: _imageCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://...', prefixIcon: Icon(LucideIcons.link)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () { _addImage(); Navigator.pop(ctx); },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  /// Xóa media khỏi danh sách và dọn file trên server (nếu do ta upload).
  void _removeMedia(int index) {
    final url = _images[index];
    // Merge vào 1 setState để tránh rebuild 2 lần
    setState(() {
      _images.removeAt(index);
      if (index < _uploadingFlags.length) _uploadingFlags.removeAt(index);
      if (url == _thumbnailUrl) _thumbnailUrl = null;
    });

    // Nếu URL do server ta tạo ra → xóa file vật lý
    if (url.contains('/media/')) {
      final filename = url.split('/media/').last;
      _api.deleteLocationMedia(filename).catchError((e) {
        debugPrint('Could not delete media file: $e');
      });
    }
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') ||
        lower.endsWith('.avi') || lower.endsWith('.webm');
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

                  // Category combobox — tap để mở danh sách, gõ để lọc, hoặc nhập mới
                  _CategoryComboBox(
                    controller: _categoryCtrl,
                    categories: _categories,
                    isLoading: _isLoading,
                    onSelected: (cat) => setState(() {
                      _selectedCategory = cat.slug;
                      _categoryCtrl.text = cat.name;
                    }),
                    onTextChanged: (v) {
                      final match = _categories.where(
                        (c) => c.name.toLowerCase() == v.toLowerCase(),
                      ).firstOrNull;
                      setState(() => _selectedCategory = match?.slug);
                    },
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Vui lòng nhập danh mục' : null,
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
                  const Text('  (Dùng để bật bản đồ và tính năng gần đây)',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),

                  // Nút chọn trên bản đồ
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Lấy tọa độ hiện tại nếu đã nhập
                        LatLng? initial;
                        final lat = double.tryParse(_latCtrl.text);
                        final lng = double.tryParse(_lngCtrl.text);
                        if (lat != null && lng != null) initial = LatLng(lat, lng);

                        final result = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(builder: (_) => MapPickerScreen(initialLatLng: initial)),
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _latCtrl.text = result.latitude.toStringAsFixed(6);
                            _lngCtrl.text = result.longitude.toStringAsFixed(6);
                          });
                        }
                      },
                      icon: const Icon(LucideIcons.map, size: 18),
                      label: Text(
                        (_latCtrl.text.isNotEmpty && _lngCtrl.text.isNotEmpty)
                            ? '📍 ${double.tryParse(_latCtrl.text)?.toStringAsFixed(4)}, ${double.tryParse(_lngCtrl.text)?.toStringAsFixed(4)} — Đổi vị trí'
                            : 'Chọn trên bản đồ',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor.withAlpha(120)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Nhập tay (optional — vẫn giữ để người dùng tinh chỉnh)
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
                  _Section(title: 'Hình ảnh & Video', icon: LucideIcons.image),
                  const SizedBox(height: 4),
                  const Text('  Ảnh (JPG/PNG/WEBP ≤ 10MB) • Video (MP4/MOV ≤ 100MB)',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  if (_images.where((u) => !_isVideoUrl(u) && u.isNotEmpty).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text('  Nhấn vào ảnh để chọn làm ảnh đại diện ⭐',
                        style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                  ],
                  const SizedBox(height: 12),

                  // Media grid — tap image to pick as thumbnail
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < _images.length; i++) ...[
                        final url = _images[i];
                        final isUploading = i < _uploadingFlags.length ? _uploadingFlags[i] : false;
                        final isThumb = url.isNotEmpty && url == _thumbnailUrl;
                        final canBeThumb = !_isVideoUrl(url) && url.isNotEmpty && !isUploading;
                        GestureDetector(
                          onTap: canBeThumb
                              ? () => setState(() => _thumbnailUrl = isThumb ? null : url)
                              : null,
                          child: _MediaThumb(
                            url: url,
                            isUploading: isUploading,
                            isThumbnail: isThumb,
                            onRemove: () => _removeMedia(i),
                          ),
                        ),
                      ],
                      // Add button
                      GestureDetector(
                        onTap: _showPickMediaSheet,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryColor.withAlpha(80), width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.plus, color: AppTheme.primaryColor, size: 28),
                              const SizedBox(height: 4),
                              Text('Thêm media', style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ── Category Combo Box ─────────────────────────────────────────────────────────
/// TextField + dropdown overlay hiện danh sách category khi focus,
/// lọc khi gõ, cho phép nhập tự do nếu muốn tạo danh mục mới.
class _CategoryComboBox extends StatefulWidget {
  final TextEditingController controller;
  final List<Category> categories;
  final bool isLoading;
  final void Function(Category) onSelected;
  final void Function(String) onTextChanged;
  final String? Function(String?)? validator;

  const _CategoryComboBox({
    required this.controller,
    required this.categories,
    required this.isLoading,
    required this.onSelected,
    required this.onTextChanged,
    this.validator,
  });

  @override
  State<_CategoryComboBox> createState() => _CategoryComboBoxState();
}

class _CategoryComboBoxState extends State<_CategoryComboBox> {
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlay;
  final LayerLink _layerLink = LayerLink();
  List<Category> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.categories;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _filter(widget.controller.text);
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  @override
  void didUpdateWidget(_CategoryComboBox old) {
    super.didUpdateWidget(old);
    if (old.categories != widget.categories) {
      _filter(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.categories
          : widget.categories
              .where((c) => c.name.toLowerCase().contains(q) || c.slug.contains(q))
              .toList();
    });
    _overlay?.markNeedsBuild();
  }

  void _showOverlay() {
    _removeOverlay();
    if (widget.categories.isEmpty) return;
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: 0, height: 0,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 200),
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Không tìm thấy — nhập để tạo mới',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final cat = _filtered[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            widget.onSelected(cat);
                            _focusNode.unfocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(cat.name,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                ),
                                Text('(${cat.slug})',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: (v) {
          _filter(v);
          widget.onTextChanged(v);
        },
        decoration: InputDecoration(
          labelText: 'Danh mục *',
          hintText: widget.isLoading
              ? 'Đang tải...'
              : widget.categories.isEmpty
                  ? 'Nhập tên danh mục mới'
                  : 'Chọn hoặc nhập danh mục',
          prefixIcon: const Icon(LucideIcons.tag, size: 18),
          suffixIcon: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
              : widget.categories.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _focusNode.hasFocus ? _focusNode.unfocus() : _focusNode.requestFocus(),
                      child: const Icon(LucideIcons.chevronsUpDown, size: 16),
                    )
                  : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          filled: true,
          fillColor: const Color(0xFFF3F4F8),
        ),
        validator: widget.validator,
      ),
    );
  }
}

// ── Media Thumbnail widget ─────────────────────────────────────────────────────
class _MediaThumb extends StatelessWidget {
  final String url;
  final bool isUploading;
  final bool isThumbnail;
  final VoidCallback onRemove;

  const _MediaThumb({
    required this.url,
    required this.isUploading,
    this.isThumbnail = false,
    required this.onRemove,
  });

  bool get _isVideo {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') ||
        lower.endsWith('.avi') || lower.endsWith('.webm');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Border highlight khi là thumbnail
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isThumbnail
                  ? Border.all(color: const Color(0xFFFFC107), width: 2.5)
                  : null,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(isThumbnail ? 10 : 12),
            child: isUploading
                ? Container(
                    color: const Color(0xFFF3F4F8),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _isVideo
                    ? Container(
                        color: Colors.black87,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.play, color: Colors.white, size: 32),
                            SizedBox(height: 4),
                            Text('Video', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      )
                    : url.isEmpty
                        ? Container(color: const Color(0xFFF3F4F8), child: const Icon(LucideIcons.imageOff, color: Colors.grey))
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF3F4F8),
                              child: const Icon(LucideIcons.imageOff, color: Colors.grey),
                            ),
                          ),
          ),
          // Nút xóa (top-right)
          if (!isUploading)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.x, color: Colors.white, size: 12),
                ),
              ),
            ),
          // Video icon (bottom-left)
          if (_isVideo && !isUploading)
            const Positioned(
              bottom: 6,
              left: 6,
              child: Icon(LucideIcons.video, color: Colors.white, size: 14),
            ),
          // Thumbnail star badge (bottom-left, chỉ hiện khi là avatar)
          if (isThumbnail && !isUploading)
            Positioned(
              bottom: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('⭐ Avatar', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black87)),
              ),
            ),
        ],
      ),
    );
  }
}
