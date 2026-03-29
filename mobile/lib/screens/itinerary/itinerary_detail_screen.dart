import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu thay đổi'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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

  // ── Add day dialog ──────────────────────────────────────
  void _showAddDayDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final days = (_itinerary!['days'] as List? ?? []);
    final nextDay = days.length + 1;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm Ngày $nextDay'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(hintText: 'Tiêu đề ngày (VD: Khám phá đảo)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(hintText: 'Mô tả ngắn'),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _addDayToItinerary(nextDay, titleCtrl.text, descCtrl.text);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDayToItinerary(int dayNumber, String title, String desc) async {
    try {
      final response = await _apiService.post(
        '/api/itineraries/${_itinerary!['id']}/days',
        {
          'day_number': dayNumber,
          'title': title.isEmpty ? 'Ngày $dayNumber' : title,
          'description': desc.isEmpty ? null : desc,
          'activities': [],
        },
      );
      if (response.statusCode == 201 && mounted) {
        final days = List<dynamic>.from(_itinerary!['days'] ?? []);
        days.add(response.data);
        setState(() => _itinerary!['days'] = days);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // ── Add activity dialog ─────────────────────────────────
  void _showAddActivityDialog(Map<String, dynamic> day) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Thêm hoạt động – ${day['title'] ?? 'Ngày ${day['day_number']}'}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Tên hoạt động *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(startTime != null ? startTime!.format(ctx) : 'Giờ bắt đầu',
                        style: const TextStyle(fontSize: 13)),
                    leading: const Icon(Icons.access_time, size: 18),
                    onTap: () async {
                      final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                      if (t != null) setS(() => startTime = t);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(endTime != null ? endTime!.format(ctx) : 'Giờ kết thúc',
                        style: const TextStyle(fontSize: 13)),
                    leading: const Icon(Icons.access_time_filled, size: 18),
                    onTap: () async {
                      final t = await showTimePicker(context: ctx, initialTime: startTime ?? TimeOfDay.now());
                      if (t != null) setS(() => endTime = t);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Ghi chú thêm'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                await _addActivity(day, titleCtrl.text, descCtrl.text, noteCtrl.text, startTime, endTime);
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addActivity(
    Map<String, dynamic> day,
    String title,
    String desc,
    String note,
    TimeOfDay? start,
    TimeOfDay? end,
  ) async {
    String? fmt(TimeOfDay? t) => t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
    try {
      final response = await _apiService.post(
        '/api/itineraries/${_itinerary!['id']}/days/${day['id']}/activities',
        {
          'title': title,
          'description': desc.isEmpty ? null : desc,
          'note': note.isEmpty ? null : note,
          'start_time': fmt(start),
          'end_time': fmt(end),
          'order_index': (day['activities'] as List? ?? []).length,
        },
      );
      if (response.statusCode == 201 && mounted) {
        final days = List<dynamic>.from(_itinerary!['days'] ?? []);
        final idx = days.indexWhere((d) => d['id'] == day['id']);
        if (idx != -1) {
          final activities = List<dynamic>.from(days[idx]['activities'] ?? []);
          activities.add(response.data);
          days[idx]['activities'] = activities;
          setState(() => _itinerary!['days'] = days);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteDay(Map<String, dynamic> day) async {
    try {
      await _apiService.delete('/api/itineraries/${_itinerary!['id']}/days/${day['id']}');
      if (mounted) {
        final days = List<dynamic>.from(_itinerary!['days'] ?? []);
        days.removeWhere((d) => d['id'] == day['id']);
        setState(() => _itinerary!['days'] = days);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
          final activities = List<dynamic>.from(days[idx]['activities'] ?? []);
          activities.removeWhere((a) => a['id'] == activity['id']);
          days[idx]['activities'] = activities;
          setState(() => _itinerary!['days'] = days);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
      appBar: AppBar(
        title: const Text('Chi tiết lịch trình'),
        actions: [
          if (!_isEditing)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _isEditing = true))
          else
            IconButton(
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveChanges,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDayDialog,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Thêm ngày', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            if (_isEditing)
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tên lịch trình'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              )
            else
              Text(_itinerary!['title'] ?? 'Không tên',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),

            // Status
            Row(children: [
              const Text('Trạng thái: ', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: status,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Nháp')),
                  DropdownMenuItem(value: 'planned', child: Text('Đã lên kế hoạch')),
                  DropdownMenuItem(value: 'ongoing', child: Text('Đang diễn ra')),
                  DropdownMenuItem(value: 'completed', child: Text('Hoàn thành')),
                ],
                onChanged: (v) { if (v != null) _updateStatus(v); },
              ),
            ]),

            const SizedBox(height: 8),

            // Description
            if (_isEditing)
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 3,
              )
            else if ((_itinerary!['description'] as String? ?? '').isNotEmpty)
              Text(_itinerary!['description'],
                  style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5)),

            const SizedBox(height: 12),

            // Dates
            Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(_formatDates(_itinerary!['start_date'], _itinerary!['end_date']),
                  style: const TextStyle(fontSize: 14)),
            ]),

            const SizedBox(height: 24),

            // ── Days section ──────────────────────────────────────
            Row(children: [
              Text('Lịch trình theo ngày (${days.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),

            if (days.isEmpty)
              _emptyDaysPlaceholder()
            else
              ...days.asMap().entries.map((entry) => _buildDayCard(entry.value)),

            const SizedBox(height: 80), // padding for FAB
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ───────────────────────────────────────

  Widget _emptyDaysPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text('Chưa có ngày nào', style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text('Nhấn "Thêm ngày" để bắt đầu lên lịch trình',
            style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      ]),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final activities = day['activities'] as List? ?? [];
    final dayNum = day['day_number'] ?? 1;
    final dayTitle = day['title'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Day header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
              child: Text('$dayNum', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  dayTitle.isNotEmpty ? dayTitle : 'Ngày $dayNum',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if ((day['description'] as String? ?? '').isNotEmpty)
                  Text(day['description'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ]),
            ),
            // Add activity button
            IconButton(
              icon: const Icon(Icons.add_location_alt, color: AppTheme.primaryColor),
              tooltip: 'Thêm hoạt động',
              onPressed: () => _showAddActivityDialog(day),
            ),
            // Delete day button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Xóa ngày',
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xóa ngày?'),
                  content: Text('Xóa Ngày $dayNum và toàn bộ hoạt động trong ngày này?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () { Navigator.pop(ctx); _deleteDay(day); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),

        // Activities list
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.add_circle_outline, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text('Chưa có hoạt động. Nhấn + để thêm.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ]),
          )
        else
          ...activities.asMap().entries.map((e) => _buildActivityTile(day, e.value, e.key)),

        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> day, Map<String, dynamic> act, int idx) {
    final startTime = act['start_time'] as String?;
    final endTime = act['end_time'] as String?;
    String timeStr = '';
    if (startTime != null) {
      timeStr = startTime.substring(0, 5);
      if (endTime != null) timeStr += ' – ${endTime.substring(0, 5)}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Order badge
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text('${idx + 1}',
              style: TextStyle(fontSize: 11, color: AppTheme.accentColor, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(act['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            if ((act['description'] as String? ?? '').isNotEmpty)
              Text(act['description'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (timeStr.isNotEmpty)
              Row(children: [
                const Icon(Icons.access_time, size: 12, color: AppTheme.primaryColor),
                const SizedBox(width: 4),
                Text(timeStr, style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
              ]),
            if ((act['note'] as String? ?? '').isNotEmpty)
              Text('📝 ${act['note']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _deleteActivity(day, act),
        ),
      ]),
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
