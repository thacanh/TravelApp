import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAdminUsers(search: _searchQuery.isEmpty ? null : _searchQuery);
      if (response.statusCode == 200) {
        setState(() {
          _users = response.data as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _toggleUserActive(int userId) async {
    try {
      final response = await _apiService.toggleUserActive(userId);
      if (response.statusCode == 200) {
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.data['message'])),
          );
        }
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
      appBar: AppBar(
        title: const Text('Quản lý người dùng'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingM),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadUsers();
                        },
                      )
                    : null,
              ),
              onSubmitted: (value) {
                setState(() => _searchQuery = value);
                _loadUsers();
              },
            ),
          ),
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('Không tìm thấy người dùng'))
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _UserTile(
                              user: user,
                              onToggleActive: () => _toggleUserActive(user['id']),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleActive;

  const _UserTile({
    required this.user,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] ?? true;
    final role = user['role'] ?? 'user';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: role == 'admin' 
              ? AppTheme.secondaryColor 
              : AppTheme.primaryColor,
          child: Text(
            (user['full_name'] ?? 'U')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['full_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (role == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.block,
                  size: 14,
                  color: isActive ? AppTheme.successColor : AppTheme.errorColor,
                ),
                const SizedBox(width: 4),
                Text(
                  isActive ? 'Hoạt động' : 'Bị khóa',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppTheme.successColor : AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: role != 'admin'
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'toggle') {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(isActive ? 'Khóa tài khoản?' : 'Mở khóa tài khoản?'),
                        content: Text(
                          isActive
                              ? 'Người dùng "${user['full_name']}" sẽ không thể đăng nhập.'
                              : 'Người dùng "${user['full_name']}" sẽ có thể đăng nhập lại.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Hủy'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onToggleActive();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isActive ? AppTheme.errorColor : AppTheme.successColor,
                            ),
                            child: Text(isActive ? 'Khóa' : 'Mở khóa'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.lock_outline : Icons.lock_open,
                          size: 18,
                          color: isActive ? AppTheme.errorColor : AppTheme.successColor,
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Khóa tài khoản' : 'Mở khóa'),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
