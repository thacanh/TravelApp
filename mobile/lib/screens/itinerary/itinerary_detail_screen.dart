import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import 'itinerary_route_map_screen.dart';

class ItineraryDetailScreen extends StatefulWidget {
  const ItineraryDetailScreen({super.key});

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _itinerary;
  bool _isLoading = false;
  bool _isEditing = false;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map<String, dynamic> && _itinerary == null) {
      _itinerary = Map<String, dynamic>.from(arg);
      _titleController.text = _itinerary?['title'] ?? '';
      _descController.text = _itinerary?['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.updateItinerary(
        _itinerary!['id'],
        {'title': _titleController.text, 'description': _descController.text},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _itinerary = response.data;
          _isEditing = false;
        });
        _showSnackBar('Đã lưu thay đổi', AppTheme.successColor);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi: $e', AppTheme.errorColor);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      final response = await _apiService.updateItinerary(_itinerary!['id'], {'status': status});
      if (response.statusCode == 200 && mounted) {
        setState(() => _itinerary = response.data);
      }
    } catch (_) {}
  }

  // ── Add Day ─────────────────────────────────────────────────
  void _showAddDayDialog() {
    final titleCtrl = TextEditingController();
    final days = (_itinerary!['days'] as List? ?? []);
    final nextDay = days.length + 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Thêm Ngày $nextDay', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề ngày (VD: Khám phá đảo)',
                  prefixIcon: Icon(LucideIcons.calendar, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _addDay(nextDay, titleCtrl.text);
                  },
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Thêm ngày'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addDay(int dayNumber, String title) async {
    try {
      final response = await _apiService.post(
        '/api/itineraries/${_itinerary!['id']}/days',
        {
          'day_number': dayNumber,
          'title': title.isEmpty ? 'Ngày $dayNumber' : title,
          'activities': [],
        },
      );
      if (response.statusCode == 201 && mounted) {
        final days = List<dynamic>.from(_itinerary!['days'] ?? []);
        days.add(response.data);
        setState(() => _itinerary!['days'] = days);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi: $e', AppTheme.errorColor);
    }
  }

  // ── Add Location/Activity ────────────────────────────────────
  void _showAddActivitySheet(Map<String, dynamic> day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddActivitySheet(
        day: day,
        itineraryId: _itinerary!['id'],
        apiService: _apiService,
        onAdded: (newActivity) {
          final days = List<dynamic>.from(_itinerary!['days'] ?? []);
          final idx = days.indexWhere((d) => d['id'] == day['id']);
          if (idx != -1) {
            final acts = List<dynamic>.from(days[idx]['activities'] ?? []);
            acts.add(newActivity);
            days[idx]['activities'] = acts;
            setState(() => _itinerary!['days'] = days);
          }
        },
      ),
    );
  }

  Future<void> _deleteDay(Map<String, dynamic> day) async {
    final confirmed = await _confirmDialog('Xóa ngày?',
        'Xóa Ngày ${day['day_number']} và toàn bộ hoạt động trong ngày?');
    if (!confirmed) return;
    try {
      await _apiService.delete('/api/itineraries/${_itinerary!['id']}/days/${day['id']}');
      if (mounted) {
        final days = List<dynamic>.from(_itinerary!['days'] ?? []);
        days.removeWhere((d) => d['id'] == day['id']);
        setState(() => _itinerary!['days'] = days);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi: $e', AppTheme.errorColor);
    }
  }

  Future<void> _deleteActivity(Map<String, dynamic> day, Map<String, dynamic> activity) async {
    try {
      await _apiService.delete(
          '/api/itineraries/${_itinerary!['id']}/days/${day['id']}/activities/${activity['id']}');
      if (mounted) {
        final days = List<dynamic>.from(_itinerary!['days'] ?? []);
        final idx = days.indexWhere((d) => d['id'] == day['id']);
        if (idx != -1) {
          final acts = List<dynamic>.from(days[idx]['activities'] ?? []);
          acts.removeWhere((a) => a['id'] == activity['id']);
          days[idx]['activities'] = acts;
          setState(() => _itinerary!['days'] = days);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi: $e', AppTheme.errorColor);
    }
  }

  void _openRouteMap(Map<String, dynamic> day) {
    final acts = (day['activities'] as List? ?? [])
        .map((a) => Map<String, dynamic>.from(a))
        .toList();
    Navigator.pushNamed(
      context,
      '/itinerary-route-map',
      arguments: ItineraryRouteArgs(
        itineraryId: _itinerary!['id'],
        dayId: day['id'],
        dayTitle: day['title'] ?? 'Ngày ${day['day_number']}',
        activities: acts,
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────
  Future<bool> _confirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'planned': return 'Đã lên kế hoạch';
      case 'ongoing': return 'Đang diễn ra';
      case 'completed': return 'Hoàn thành';
      default: return 'Nháp';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'planned': return Colors.blue;
      case 'ongoing': return AppTheme.accentColor;
      case 'completed': return AppTheme.successColor;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_itinerary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết lịch trình')),
        body: const Center(child: Text('Không tìm thấy lịch trình')),
      );
    }

    final days = _itinerary!['days'] as List? ?? [];
    final status = _itinerary!['status'] as String? ?? 'draft';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Chi tiết lịch trình'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 20),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.save, size: 20),
              onPressed: _isLoading ? null : _saveChanges,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDayDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(LucideIcons.calendarPlus, color: Colors.white, size: 20),
        label: const Text('Thêm ngày', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_isEditing)
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(labelText: 'Tên lịch trình'),
                  )
                else
                  Text(_itinerary!['title'] ?? 'Không tên',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Status
                Wrap(
                  spacing: 8,
                  children: ['draft', 'planned', 'ongoing', 'completed'].map((s) {
                    final isSelected = status == s;
                    return GestureDetector(
                      onTap: () => _updateStatus(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? _statusColor(s) : _statusColor(s).withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _statusLabel(s),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : _statusColor(s),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                if (_isEditing)
                  TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines: 3)
                else if ((_itinerary!['description'] as String? ?? '').isNotEmpty)
                  Text(_itinerary!['description'],
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),

                const SizedBox(height: 8),
                Row(children: [
                  const Icon(LucideIcons.calendar, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text(_formatDates(_itinerary!['start_date'], _itinerary!['end_date']),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ]),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Days section ────────────────────────────────────
            Row(children: [
              const Text('Lịch trình theo ngày',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${days.length} ngày',
                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),

            if (days.isEmpty)
              _buildEmptyDays()
            else
              ...days.map((day) => _buildDayCard(Map<String, dynamic>.from(day))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDays() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withAlpha(15),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.mapPin, size: 28, color: AppTheme.primaryColor),
        ),
        const SizedBox(height: 12),
        const Text('Chưa có ngày nào', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Nhấn "Thêm ngày" để bắt đầu lên lịch trình',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ]),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final activities = (day['activities'] as List? ?? []);
    final dayNum = day['day_number'] ?? 1;
    final dayTitle = day['title'] as String? ?? 'Ngày $dayNum';
    final hasGeoActs = activities.any((a) => a['location_lat'] != null && a['location_lng'] != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Day header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor.withAlpha(20), AppTheme.secondaryColor.withAlpha(10)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.buttonShadow,
              ),
              child: Text('$dayNum',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(dayTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            // Route map button
            if (hasGeoActs)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.navigation, size: 16, color: AppTheme.secondaryColor),
                ),
                tooltip: 'Xem lộ trình',
                onPressed: () => _openRouteMap(day),
              ),
            // Add activity button
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.mapPin, size: 16, color: AppTheme.primaryColor),
              ),
              tooltip: 'Thêm địa điểm',
              onPressed: () => _showAddActivitySheet(day),
            ),
            // Delete day button
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 18, color: AppTheme.errorColor),
              tooltip: 'Xóa ngày',
              onPressed: () => _deleteDay(day),
            ),
          ]),
        ),

        // Activities
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(LucideIcons.plusCircle, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text('Chưa có địa điểm. Nhấn + để thêm.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ]),
          )
        else
          ...activities.asMap().entries.map((e) => _buildActivityTile(day, Map<String, dynamic>.from(e.value), e.key)),

        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> day, Map<String, dynamic> act, int idx) {
    final startTime = act['start_time'] as String?;
    final endTime = act['end_time'] as String?;
    final timeStr = startTime != null
        ? (endTime != null ? '$startTime – $endTime' : startTime)
        : '';
    final locationImage = act['location_image'] as String?;
    final hasLocation = act['location_id'] != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Image or number
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: locationImage != null
                ? CachedNetworkImage(
                    imageUrl: locationImage,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                    errorWidget: (_, __, ___) => _indexBadge(idx),
                  )
                : _indexBadge(idx),
          ),
        ),
        const SizedBox(width: 10),
        // Info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (hasLocation)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.mapPin, size: 10, color: AppTheme.primaryColor),
                      SizedBox(width: 3),
                      Text('Địa điểm', style: TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              Expanded(
                child: Text(act['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
            if (act['location_name'] != null && act['location_name'] != act['title'])
              Text(act['location_name'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if ((act['description'] as String? ?? '').isNotEmpty)
              Text(act['description'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 2),
            if (timeStr.isNotEmpty)
              Row(children: [
                const Icon(LucideIcons.clock, size: 12, color: AppTheme.primaryColor),
                const SizedBox(width: 3),
                Text(timeStr, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
              ]),
            if ((act['note'] as String? ?? '').isNotEmpty)
              Text('📝 ${act['note']}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
          ]),
        ),
        IconButton(
          icon: const Icon(LucideIcons.x, size: 16, color: AppTheme.errorColor),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: () => _deleteActivity(day, act),
        ),
      ]),
    );
  }

  Widget _indexBadge(int idx) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('${idx + 1}',
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }

  String _formatDates(String? start, String? end) {
    if (start == null) return 'Chưa xác định ngày';
    try {
      final s = DateTime.parse(start);
      final dateStr = '${s.day}/${s.month}/${s.year}';
      if (end != null) {
        final e = DateTime.parse(end);
        return '$dateStr → ${e.day}/${e.month}/${e.year}';
      }
      return dateStr;
    } catch (_) {
      return 'Chưa xác định ngày';
    }
  }
}

// ── Add Activity Bottom Sheet ─────────────────────────────────────────────────
class _AddActivitySheet extends StatefulWidget {
  final Map<String, dynamic> day;
  final int itineraryId;
  final ApiService apiService;
  final void Function(Map<String, dynamic>) onAdded;

  const _AddActivitySheet({
    required this.day,
    required this.itineraryId,
    required this.apiService,
    required this.onAdded,
  });

  @override
  State<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<_AddActivitySheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // Tab 0: Pick from DB
  List<dynamic> _locations = [];
  bool _loadingLocs = true;
  final _locSearchCtrl = TextEditingController();
  String? _selectedCat;

  // Tab 1: Manual
  final _manualTitleCtrl = TextEditingController();
  final _manualDescCtrl = TextEditingController();
  final _manualNoteCtrl = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadLocations();
  }

  Future<void> _loadLocations({String? search, String? category}) async {
    setState(() => _loadingLocs = true);
    try {
      final res = await widget.apiService.getLocations(limit: 50, search: search, category: category);
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _locations = res.data as List;
          _loadingLocs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocs = false);
    }
  }

  Future<void> _addLocationActivity(Map<String, dynamic> loc) async {
    setState(() => _saving = true);
    try {
      final images = (loc['images'] as List?) ?? [];
      final res = await widget.apiService.post(
        '/api/itineraries/${widget.itineraryId}/days/${widget.day['id']}/activities',
        {
          'title': loc['name'],
          'description': loc['description'],
          'location_id': loc['id'],
          'location_name': loc['name'],
          'location_lat': loc['latitude'],
          'location_lng': loc['longitude'],
          'location_image': images.isNotEmpty ? images.first : null,
          'order_index': (widget.day['activities'] as List? ?? []).length,
        },
      );
      if (res.statusCode == 201 && mounted) {
        widget.onAdded(res.data as Map<String, dynamic>);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addManualActivity() async {
    if (_manualTitleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    String? fmt(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    try {
      final res = await widget.apiService.post(
        '/api/itineraries/${widget.itineraryId}/days/${widget.day['id']}/activities',
        {
          'title': _manualTitleCtrl.text.trim(),
          'description': _manualDescCtrl.text.trim().isEmpty ? null : _manualDescCtrl.text.trim(),
          'note': _manualNoteCtrl.text.trim().isEmpty ? null : _manualNoteCtrl.text.trim(),
          'start_time': fmt(_startTime),
          'end_time': fmt(_endTime),
          'order_index': (widget.day['activities'] as List? ?? []).length,
        },
      );
      if (res.statusCode == 201 && mounted) {
        widget.onAdded(res.data as Map<String, dynamic>);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _locSearchCtrl.dispose();
    _manualTitleCtrl.dispose();
    _manualDescCtrl.dispose();
    _manualNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
              child: const Icon(LucideIcons.mapPin, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Thêm vào Ngày ${widget.day['day_number']}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Chọn địa điểm'),
            Tab(text: 'Nhập tay'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildLocationPicker(),
              _buildManualForm(),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildLocationPicker() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _locSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm địa điểm...',
            prefixIcon: const Icon(LucideIcons.search, size: 18),
            suffixIcon: _locSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () {
                      _locSearchCtrl.clear();
                      _loadLocations();
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            setState(() {});
            if (v.length >= 2 || v.isEmpty) {
              _loadLocations(search: v.isEmpty ? null : v, category: _selectedCat);
            }
          },
        ),
      ),
      if (_loadingLocs)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_locations.isEmpty)
        const Expanded(child: Center(child: Text('Không tìm thấy địa điểm')))
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _locations.length,
            itemBuilder: (ctx, i) {
              final loc = _locations[i];
              final images = (loc['images'] as List?) ?? [];
              final cat = loc['category'] as String?;
              return GestureDetector(
                onTap: _saving ? null : () => _addLocationActivity(loc),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: images.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: images.first as String,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _catPlaceholder(cat),
                              )
                            : _catPlaceholder(cat),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(loc['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Row(children: [
                          const Icon(LucideIcons.mapPin, size: 11, color: AppTheme.textSecondary),
                          const SizedBox(width: 3),
                          Text(loc['city'] ?? '', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                        ]),
                        if ((loc['rating_avg'] as num? ?? 0) > 0)
                          Row(children: [
                            const Icon(LucideIcons.star, size: 11, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text('${(loc['rating_avg'] as num).toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 11)),
                          ]),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
    ]);
  }

  Widget _catPlaceholder(String? cat) {
    Color c;
    switch (cat) {
      case 'beach': c = const Color(0xFF00BCD4); break;
      case 'mountain': c = const Color(0xFF4CAF50); break;
      case 'city': c = const Color(0xFFFF9800); break;
      case 'cultural': c = const Color(0xFF9C27B0); break;
      default: c = AppTheme.primaryColor;
    }
    return Container(color: c.withAlpha(30), child: Icon(LucideIcons.mapPin, color: c, size: 22));
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          controller: _manualTitleCtrl,
          decoration: const InputDecoration(
            labelText: 'Tên hoạt động *',
            prefixIcon: Icon(LucideIcons.activity, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _manualDescCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Mô tả',
            prefixIcon: Icon(LucideIcons.alignLeft, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (t != null) setState(() => _startTime = t);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.clock, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(_startTime?.format(context) ?? 'Giờ bắt đầu',
                      style: TextStyle(color: _startTime != null ? AppTheme.textPrimary : AppTheme.textHint)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                if (t != null) setState(() => _endTime = t);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.timer, size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(_endTime?.format(context) ?? 'Giờ kết thúc',
                      style: TextStyle(color: _endTime != null ? AppTheme.textPrimary : AppTheme.textHint)),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _manualNoteCtrl,
          decoration: const InputDecoration(
            labelText: 'Ghi chú thêm',
            prefixIcon: Icon(LucideIcons.fileEdit, size: 18),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving || _manualTitleCtrl.text.trim().isEmpty ? null : _addManualActivity,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.plus, size: 18),
            label: const Text('Thêm hoạt động'),
          ),
        ),
      ]),
    );
  }
}
