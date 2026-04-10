import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../models/location.dart';
import '../../services/api_service.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final ApiService _apiService = ApiService();
  final _commentController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  Location? _selectedLocation;
  double _rating = 4.0;
  bool _isSubmitting = false;
  List<Location> _locations = [];
  bool _isLoadingLocations = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Location && _selectedLocation == null) {
      _selectedLocation = args;
      // Thêm ngay vào _locations để dropdown có item hợp lệ trước khi load xong
      if (!_locations.any((l) => l.id == args.id)) {
        setState(() => _locations = [args, ..._locations]);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final response = await _apiService.getLocations(limit: 100);
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = response.data;
        final loaded = data.map((json) => Location.fromJson(json)).toList();
        setState(() {
          // Giữ _selectedLocation ở đầu nếu chưa nằm trong danh sách load về
          final ids = loaded.map((l) => l.id).toSet();
          _locations = [
            if (_selectedLocation != null && !ids.contains(_selectedLocation!.id))
              _selectedLocation!,
            ...loaded,
          ];
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(maxWidth: 1200, imageQuality: 85);
    if (images.isNotEmpty) {
      setState(() => _selectedPhotos.addAll(images));
    }
  }

  Future<void> _submit() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa điểm')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      // 1. Upload ảnh nếu có
      List<String> photoUrls = [];
      if (_selectedPhotos.isNotEmpty) {
        final uploadResponse = await _apiService.uploadReviewPhotos(
          _selectedPhotos.map((x) => x.path).toList(),
        );
        if (uploadResponse.statusCode == 200) {
          photoUrls = List<String>.from(uploadResponse.data['photos'] ?? []);
        }
      }

      // 2. Tạo review (kết hợp check-in)
      final response = await _apiService.createReview({
        'location_id': _selectedLocation!.id,
        'rating': _rating,
        'comment': _commentController.text.isEmpty ? null : _commentController.text,
        'photos': photoUrls,
      });

      if (response.statusCode == 201 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã ghi lại chuyến ghé thăm!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ghé thăm & Đánh giá')),
      body: _isLoadingLocations
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Location picker ─────────────────────────────
                  Text('Địa điểm ghé thăm', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Location>(
                    value: _selectedLocation,
                    decoration: const InputDecoration(
                      hintText: 'Chọn địa điểm...',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    isExpanded: true,
                    items: _locations.map((loc) {
                      return DropdownMenuItem(
                        value: loc,
                        child: Text(loc.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (loc) => setState(() => _selectedLocation = loc),
                    // If _selectedLocation exists but is not in _locations yet (still loading), we should handle it
                    // The simplest way is to ensure _locations contains _selectedLocation
                  ),

                  const SizedBox(height: 24),

                  // ── Rating stars ─────────────────────────────────
                  Text('Đánh giá', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final star = i + 1;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = star.toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 40,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        _ratingLabel(_rating),
                        style: TextStyle(
                          color: Colors.amber[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Photos ───────────────────────────────────────
                  Text('Ảnh chuyến đi', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        GestureDetector(
                          onTap: _pickPhotos,
                          child: Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.primaryColor, width: 2),
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: AppTheme.primaryColor, size: 28),
                                SizedBox(height: 4),
                                Text('Thêm ảnh', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                              ],
                            ),
                          ),
                        ),
                        ..._selectedPhotos.asMap().entries.map((entry) {
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                                  image: DecorationImage(
                                    image: FileImage(File(entry.value.path)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 10,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedPhotos.removeAt(entry.key)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Comment ──────────────────────────────────────
                  Text('Chia sẻ cảm nhận', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Viết cảm nhận của bạn về địa điểm này...',
                      prefixIcon: Icon(Icons.edit_note),
                    ),
                    maxLines: 4,
                  ),

                  const SizedBox(height: 32),

                  // ── Submit ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(_isSubmitting ? 'Đang lưu...' : 'Lưu chuyến ghé thăm'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  String _ratingLabel(double r) {
    if (r >= 5) return 'Tuyệt vời!';
    if (r >= 4) return 'Rất tốt';
    if (r >= 3) return 'Bình thường';
    if (r >= 2) return 'Không hay';
    return 'Tệ';
  }
}
