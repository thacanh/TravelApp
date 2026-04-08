import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';

class ItineraryListScreen extends StatefulWidget {
  const ItineraryListScreen({super.key});

  @override
  State<ItineraryListScreen> createState() => _ItineraryListScreenState();
}

class _ItineraryListScreenState extends State<ItineraryListScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _itineraries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItineraries();
  }

  Future<void> _loadItineraries() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getItineraries();
      if (response.statusCode == 200) {
        setState(() {
          _itineraries = response.data as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Tạo lịch trình mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Tên lịch trình'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(startDate != null
                          ? 'Bắt đầu: ${startDate!.day}/${startDate!.month}/${startDate!.year}'
                          : 'Chọn ngày bắt đầu'),
                      trailing: const Icon(LucideIcons.calendar, size: 18),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setDialogState(() => startDate = date);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(endDate != null
                          ? 'Kết thúc: ${endDate!.day}/${endDate!.month}/${endDate!.year}'
                          : 'Chọn ngày kết thúc'),
                      trailing: const Icon(LucideIcons.calendar, size: 18),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setDialogState(() => endDate = date);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;
                    try {
                      await _apiService.createItinerary({
                        'title': titleController.text,
                        'description': descController.text,
                        'start_date': startDate?.toIso8601String(),
                        'end_date': endDate?.toIso8601String(),
                      });
                      if (mounted) Navigator.pop(ctx);
                      _loadItineraries();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Tạo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItinerary(int id) async {
    try {
      await _apiService.deleteItinerary(id);
      _loadItineraries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa lịch trình')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch trình của tôi')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _itineraries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Chưa có lịch trình nào'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showCreateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo lịch trình'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadItineraries,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.paddingM),
                    itemCount: _itineraries.length,
                    itemBuilder: (context, index) {
                      final item = _itineraries[index];
                      return _ItineraryCard(
                        itinerary: item,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.itineraryDetail,
                            arguments: item,
                          );
                        },
                        onDelete: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xóa lịch trình?'),
                              content: Text('Bạn có chắc muốn xóa "${item['title']}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _deleteItinerary(item['id']);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  final Map<String, dynamic> itinerary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ItineraryCard({required this.itinerary, required this.onTap, required this.onDelete});

  String _statusLabel(String? status) {
    switch (status) {
      case 'planned': return 'Đã lên kế hoạch';
      case 'ongoing': return 'Đang diễn ra';
      case 'completed': return 'Hoàn thành';
      default: return 'Nháp';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'planned': return Colors.blue;
      case 'ongoing': return AppTheme.accentColor;
      case 'completed': return AppTheme.successColor;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = itinerary['status'] as String?;
    final days = itinerary['days'] as List? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      itinerary['title'] ?? 'Không tên',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) { if (v == 'delete') onDelete(); },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              if (itinerary['description'] != null && itinerary['description'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(itinerary['description'], style: TextStyle(color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(LucideIcons.calendar, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDates(itinerary['start_date'], itinerary['end_date']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Icon(LucideIcons.calendarDays, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('${days.length} ngày', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDates(String? start, String? end) {
    if (start == null) return 'Chưa xác định';
    try {
      final s = DateTime.parse(start);
      final dateStr = '${s.day}/${s.month}/${s.year}';
      if (end != null) {
        final e = DateTime.parse(end);
        return '$dateStr - ${e.day}/${e.month}/${e.year}';
      }
      return dateStr;
    } catch (_) {
      return 'Chưa xác định';
    }
  }
}
