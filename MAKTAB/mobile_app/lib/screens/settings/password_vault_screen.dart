import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:maktab_app/services/database_helper.dart';

class VaultEntry {
  final int? id;
  final String label;
  final String? username;
  final String password;
  final String category;
  final String? url;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  VaultEntry({
    this.id,
    required this.label,
    this.username,
    required this.password,
    this.category = 'General',
    this.url,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultEntry.fromMap(Map<String, dynamic> m) => VaultEntry(
        id: m['id'],
        label: m['label'] ?? '',
        username: m['username'],
        password: m['password'] ?? '',
        category: m['category'] ?? 'General',
        url: m['url'],
        notes: m['notes'],
        createdAt: m['created_at'] ?? '',
        updatedAt: m['updated_at'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'username': username,
        'password': password,
        'category': category,
        'url': url,
        'notes': notes,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class PasswordVaultScreen extends StatefulWidget {
  const PasswordVaultScreen({super.key});

  @override
  State<PasswordVaultScreen> createState() => _PasswordVaultScreenState();
}

class _PasswordVaultScreenState extends State<PasswordVaultScreen>
    with SingleTickerProviderStateMixin {
  List<VaultEntry> _entries = [];
  List<VaultEntry> _filtered = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  late TabController _tabController;

  static const _categories = ['All', 'Users & PINs', 'General', 'School', 'Social', 'Email', 'Bank', 'Other'];
  static const _teal = Color(0xFF004D40);
  static const _tealLight = Color(0xFF00796B);

  final Map<int, bool> _revealed = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _categories[_tabController.index];
          _applyFilter();
        });
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('password_vault', orderBy: 'updated_at DESC');
    final customEntries = rows.map(VaultEntry.fromMap).toList();

    // Auto-fetch all system users (Admin & Teachers) and sync their PINs into the vault view
    final userRows = await db.query('users', orderBy: 'role ASC, name ASC');
    final systemUserEntries = userRows.map((u) {
      final id = u['id'] as int? ?? 0;
      final name = u['name'] as String? ?? 'User';
      final role = (u['role'] as String? ?? 'User').toUpperCase();
      final mobile = u['mobile'] as String?;
      final dob = u['dob'] as String?;
      final pinHash = u['pin_hash'] as String? ?? '';
      final createdAt = u['created_at'] as String? ?? '';
      
      return VaultEntry(
        id: -id, // negative virtual ID so it doesn't conflict with custom entries
        label: '$name ($role PIN)',
        username: mobile != null && mobile.isNotEmpty ? mobile : '$role Account',
        password: pinHash,
        category: 'Users & PINs',
        url: null,
        notes: 'System User | Role: $role | Mobile: ${mobile ?? "N/A"} | DOB: ${dob ?? "N/A"}',
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    }).toList();

    setState(() {
      _entries = [...systemUserEntries, ...customEntries];
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    final cat = _selectedCategory;
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filtered = _entries.where((e) {
        final matchCat = cat == 'All' || e.category == cat;
        final matchQ = q.isEmpty ||
            e.label.toLowerCase().contains(q) ||
            (e.username?.toLowerCase().contains(q) ?? false) ||
            (e.notes?.toLowerCase().contains(q) ?? false);
        return matchCat && matchQ;
      }).toList();
    });
  }

  Future<void> _save(VaultEntry entry) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    if (entry.id == null) {
      await db.insert('password_vault', {
        ...entry.toMap(),
        'created_at': now,
        'updated_at': now,
      });
    } else {
      await db.update(
        'password_vault',
        {...entry.toMap(), 'updated_at': now},
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    }
    await _load();
  }

  Future<void> _delete(VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Entry'),
        content: Text('Delete "${entry.label}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('password_vault', where: 'id = ?', whereArgs: [entry.id]);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${entry.label}" deleted'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text('$label copied'),
      ]),
      backgroundColor: _teal,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showAddEditDialog([VaultEntry? existing]) {
    final labelCtrl = TextEditingController(text: existing?.label);
    final userCtrl = TextEditingController(text: existing?.username);
    final passCtrl = TextEditingController(text: existing?.password);
    final urlCtrl = TextEditingController(text: existing?.url);
    final notesCtrl = TextEditingController(text: existing?.notes);
    String category = existing?.category ?? 'General';
    bool obscure = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(existing == null ? Icons.add_circle_outline : Icons.edit_outlined, color: _teal, size: 22),
            ),
            const SizedBox(width: 12),
            Text(existing == null ? 'New Credential' : 'Edit Credential',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _field(labelCtrl, 'Label / Service name', Icons.label_outline,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                  const SizedBox(height: 12),
                  _field(userCtrl, 'Username / Email (optional)', Icons.person_outline),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setS(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: _categories
                        .where((c) => c != 'All')
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setS(() => category = v!),
                  ),
                  const SizedBox(height: 12),
                  _field(urlCtrl, 'URL / Website (optional)', Icons.link_outlined),
                  const SizedBox(height: 12),
                  _field(notesCtrl, 'Notes (optional)', Icons.notes_outlined, maxLines: 2),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(existing == null ? Icons.save_outlined : Icons.check_rounded, size: 18),
              label: Text(existing == null ? 'Save' : 'Update'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
                final entry = VaultEntry(
                  id: existing?.id,
                  label: labelCtrl.text.trim(),
                  username: userCtrl.text.trim().isEmpty ? null : userCtrl.text.trim(),
                  password: passCtrl.text,
                  category: category,
                  url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                );
                Navigator.pop(ctx);
                await _save(entry);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(existing == null ? '"${entry.label}" saved!' : '"${entry.label}" updated!'),
                    backgroundColor: _teal,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'Users & PINs': return const Color(0xFFD81B60);
      case 'School': return const Color(0xFF1565C0);
      case 'Social': return const Color(0xFFE91E63);
      case 'Email': return const Color(0xFFE65100);
      case 'Bank': return const Color(0xFF2E7D32);
      case 'Other': return const Color(0xFF6A1B9A);
      default: return _teal;
    }
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'Users & PINs': return Icons.badge_rounded;
      case 'School': return Icons.school_rounded;
      case 'Social': return Icons.people_rounded;
      case 'Email': return Icons.email_rounded;
      case 'Bank': return Icons.account_balance_rounded;
      case 'Other': return Icons.more_horiz_rounded;
      default: return Icons.lock_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.security_rounded, size: 22),
          SizedBox(width: 8),
          Text('Password Vault', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(90),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                onChanged: (v) { _searchQuery = v; _applyFilter(); },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search credentials…',
                  hintStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.15),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            ),
          ]),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: _tealLight,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Credential', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 4,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 100),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildCard(_filtered[i]),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: _teal.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.lock_outline_rounded, size: 64, color: _teal.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 20),
        Text(
          _searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No credentials saved yet',
          style: const TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text('Tap + to add your first credential',
            style: TextStyle(fontSize: 13, color: Colors.black38)),
        const SizedBox(height: 100),
      ]),
    );
  }

  Widget _buildCard(VaultEntry e) {
    final isRevealed = _revealed[e.id] ?? false;
    final catColor = _catColor(e.category);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _showAddEditDialog(e),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_catIcon(e.category), color: catColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (e.username != null && e.username!.isNotEmpty)
                    Text(e.username!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(e.category, style: TextStyle(fontSize: 10, color: catColor, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('PASSWORD', style: TextStyle(fontSize: 10, color: Colors.black38, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    isRevealed ? e.password : '•' * e.password.length.clamp(6, 12),
                    style: TextStyle(
                      fontSize: isRevealed ? 14 : 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: isRevealed ? 0.5 : 4,
                      color: Colors.black87,
                    ),
                  ),
                ])),
                _actionBtn(
                  icon: isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.blueGrey,
                  tooltip: isRevealed ? 'Hide' : 'Reveal',
                  onTap: () => setState(() => _revealed[e.id!] = !isRevealed),
                ),
                const SizedBox(width: 4),
                _actionBtn(icon: Icons.copy_rounded, color: _teal, tooltip: 'Copy password',
                    onTap: () => _copyToClipboard(e.password, 'Password')),
              ]),
              if (e.username != null && e.username!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('USERNAME', style: TextStyle(fontSize: 10, color: Colors.black38, letterSpacing: 0.8, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(e.username!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ])),
                  _actionBtn(icon: Icons.copy_rounded, color: Colors.blueGrey, tooltip: 'Copy username',
                      onTap: () => _copyToClipboard(e.username!, 'Username')),
                ]),
              ],
              if (e.url != null && e.url!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.link_rounded, size: 14, color: Colors.black38),
                  const SizedBox(width: 4),
                  Expanded(child: Text(e.url!, style: const TextStyle(fontSize: 12, color: Colors.blueAccent), overflow: TextOverflow.ellipsis)),
                ]),
              ],
              if (e.notes != null && e.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(e.notes!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 12, color: Colors.black26),
                const SizedBox(width: 4),
                Text('Updated: ${e.updatedAt.length >= 16 ? e.updatedAt.substring(0, 16) : e.updatedAt}',
                    style: const TextStyle(fontSize: 10, color: Colors.black38)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAddEditDialog(e),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: _teal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: const Size(50, 28)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _delete(e),
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('Delete', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: const Size(60, 28)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({required IconData icon, required Color color, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
