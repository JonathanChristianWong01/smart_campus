import 'dart:async';
import 'package:flutter/material.dart';
import '../services/campus_auth_api.dart';
import '../services/storage_service.dart';
import 'home_shell.dart';
import 'account_actions.dart';

String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
const _roles = <String>['admin', 'Mahasiswa', 'Dosen'];

/// Role pilihan harus cocok dengan role terverifikasi dari penyimpanan lokal.
class LoginGate extends StatefulWidget {
  const LoginGate({super.key, required this.storage, this.api});
  final StorageService storage;
  final CampusAuthApi? api;
  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> with WidgetsBindingObserver {
  Timer? _sessionTimer;
  late final CampusAuthApi _api;
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = true;
  String _selectedRole = 'Mahasiswa';
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? CampusAuthApi();
    WidgetsBinding.instance.addObserver(this);
    _api.initialize().then((_) {
      if (mounted) setState(() => _busy = false);
    }).catchError((Object e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    });
    _api.onExpired = () {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() =>
      _error = 'Sesi berakhir atau akses berubah. Silakan login kembali.');
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _api.onExpired = null;
    _api.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _api.user != null) {
      _api.request('GET', '/auth/me').then((value) {
        if (mounted && _api.user != null) {
          setState(() => _api.user = Map<String, dynamic>.from(value as Map));
        }
      }).catchError((Object e) {
        if (mounted && _api.user != null) {
          _api.forget();
          _api.onExpired?.call();
        }
      });
    }
  }

  Future<void> _setupAdmin() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => RegisterAccountScreen(api: _api, setupAdmin: true)));
    if (mounted) {
      setState(() {
        _selectedRole = 'admin';
        _error = null;
      });
    }
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Username dan password wajib diisi.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]{3,40}$').hasMatch(_username.text.trim())) {
      setState(() => _error =
      'Username 3–40 karakter tanpa spasi. Gunakan username dari Admin, bukan nama lengkap.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.login(_username.text, _password.text);
      if (_api.user?['role'] != _selectedRole) {
        try {
          await _api.logout();
        } catch (_) {
          _api.forget();
        }
        throw Exception(
            'Role pilihan tidak sesuai dengan akun. Pilih role yang diberikan Admin.');
      }
      _sessionTimer?.cancel();
      _sessionTimer = Timer(const Duration(hours: 8), () {
        _api.forget();
        _api.onExpired?.call();
      });
      _password.clear();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteOwnAccount() async {
    final deleted = await confirmDeleteAccount(context, _api);
    if (!deleted || !mounted) return;
    _sessionTimer?.cancel();
    _api.forget();
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _error =
    'Akun berhasil dihapus. Materi tetap tersedia tanpa identitas pembuat.');
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await _api.logout();
    } catch (_) {
      // Sesi lokal tetap dibuang saat keluar.
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() {
      _busy = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _api.user;
    if (user != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${user['username']} • ${user['role']}',
              style: const TextStyle(fontSize: 14)),
          actions: [
            IconButton(
                tooltip: 'Materi lokal',
                icon: const Icon(Icons.library_books),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => OnlineMaterials(api: _api)))),
            if (user['role'] == 'admin')
              IconButton(
                  tooltip: 'Kelola akun',
                  icon: const Icon(Icons.manage_accounts),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => ManageAccounts(api: _api)))),
            if (user['role'] != 'admin')
              IconButton(
                  tooltip: 'Delete akun saya',
                  icon: const Icon(Icons.person_remove),
                  onPressed: _busy ? null : _deleteOwnAccount),
            IconButton(
                tooltip: 'Keluar',
                icon: const Icon(Icons.logout),
                onPressed: _busy ? null : _logout),
          ],
        ),
        body: HomeShell(storage: widget.storage),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('SMART CAMPUS')),
      body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.school, size: 64, color: Color(0xFF143259)),
                const SizedBox(height: 16),
                const Text('Masuk ke Smart Campus',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'Demo lokal satu perangkat. Buat Admin pertama dahulu. Pendaftaran Mahasiswa dan Dosen menunggu persetujuan Admin lokal.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  key: ValueKey('login-role-$_selectedRole'),
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                      labelText: 'Role', border: OutlineInputBorder()),
                  items: _roles
                      .map((r) => DropdownMenuItem(
                      value: r, child: Text(r == 'admin' ? 'Admin' : r)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (role) => setState(() => _selectedRole = role!),
                ),
                const SizedBox(height: 14),
                TextField(
                    key: const ValueKey('login-username'),
                    controller: _username,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Username', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                TextField(
                    key: const ValueKey('login-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _hide,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) {
                      if (!_busy) _login();
                    },
                    decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                            tooltip: _hide
                                ? 'Tampilkan password'
                                : 'Sembunyikan password',
                            onPressed: () => setState(() => _hide = !_hide),
                            icon: Icon(
                                _hide ? Icons.visibility : Icons.visibility_off)))),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                      Text(_error!, style: const TextStyle(color: Colors.red))),
                FilledButton(
                    onPressed: _busy || !_api.hasAdmin ? null : _login,
                    child: Text(_busy ? 'Memproses…' : 'Masuk')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('register-account'),
                  onPressed: _busy
                      ? null
                      : !_api.hasAdmin
                      ? _setupAdmin
                      : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              RegisterAccountScreen(api: _api))),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(!_api.hasAdmin
                      ? 'Buat Admin Lokal Pertama'
                      : 'Buat Akun (Mahasiswa / Dosen)'),
                ),
                const SizedBox(height: 12),
                const Text(
                    'Mode lokal/offline • akun dan materi hanya di perangkat ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 14),
                const Text(
                    'Login tidak memerlukan internet. Persetujuan akun dilakukan Admin pada perangkat yang sama.',
                    textAlign: TextAlign.center),
              ]),
            ),
          )),
    );
  }
}

class ManageAccounts extends StatefulWidget {
  const ManageAccounts({super.key, required this.api});
  final CampusAuthApi api;
  @override
  State<ManageAccounts> createState() => _ManageAccountsState();
}

class _ManageAccountsState extends State<ManageAccounts> {
  List<dynamic>? _items;
  String? _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.request('GET', '/users') as List;
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _approve(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Setujui akun?'),
          content: Text(
              'Aktifkan ${item['username']} sebagai ${item['role']}? Pastikan identitas dan role sudah diverifikasi di luar aplikasi.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Setujui'))
          ],
        ));
    if (yes != true) return;
    try {
      await widget.api
          .request('PATCH', '/users/${item['id']}', {'active': true});
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> item) async {
    final deleted =
    await confirmDeleteAccount(context, widget.api, target: item);
    if (deleted && mounted) await _load();
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final username =
    TextEditingController(text: item?['username'] as String? ?? '');
    final password = TextEditingController();
    String role = item?['role'] as String? ?? 'Mahasiswa';
    bool active = item == null || item['active'] == 1;
    String? error;
    bool saving = false;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(item == null ? 'Buat akun' : 'Ubah akun'),
              content: SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                      child:
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: username,
                            enabled: item == null && !saving,
                            decoration: const InputDecoration(
                                labelText: 'Username (3–40 karakter)')),
                        TextField(
                            controller: password,
                            obscureText: true,
                            enabled: !saving,
                            decoration: InputDecoration(
                                labelText: item == null
                                    ? 'Password (minimal 12 karakter)'
                                    : 'Password baru (kosong = tetap)')),
                        const SizedBox(height: 12),
                        DropdownButton<String>(
                            isExpanded: true,
                            value: role,
                            items: _roles
                                .map((r) =>
                                DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                            onChanged:
                            saving ? null : (r) => update(() => role = r!)),
                        if (item != null)
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Akun aktif'),
                              value: active,
                              onChanged: saving
                                  ? null
                                  : (v) => update(() => active = v)),
                        if (error != null)
                          Text(error!,
                              style: const TextStyle(color: Colors.red)),
                      ]))),
              actions: [
                TextButton(
                    onPressed:
                    saving ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                      if ((item == null ||
                          password.text.isNotEmpty) &&
                          password.text.length < 12) {
                        update(() =>
                        error = 'Password minimal 12 karakter.');
                        return;
                      }
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        final data = <String, dynamic>{'role': role};
                        if (item == null) {
                          data['username'] = username.text.trim();
                        }
                        if (password.text.isNotEmpty) {
                          data['password'] = password.text;
                        }
                        if (item != null) data['active'] = active;
                        await widget.api.request(
                            item == null ? 'POST' : 'PATCH',
                            item == null
                                ? '/users'
                                : '/users/${item['id']}',
                            data);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            error = _message(e);
                            saving = false;
                          });
                        }
                      }
                    },
                    child: Text(saving ? 'Menyimpan…' : 'Simpan')),
              ],
            )));
    // Dialog route animates out before controllers are garbage-collected.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    username.dispose();
    password.dispose();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kelola akun'), actions: [
      IconButton(
          tooltip: 'Muat ulang',
          onPressed: _load,
          icon: const Icon(Icons.refresh))
    ]),
    floatingActionButton: FloatingActionButton(
        tooltip: 'Buat akun',
        onPressed: _busy
            ? null
            : () async {
          setState(() => _busy = true);
          await _edit();
          if (mounted) setState(() => _busy = false);
        },
        child: const Icon(Icons.person_add)),
    body: _error != null
        ? Center(child: Text(_error!))
        : _items == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          const Text(
              'Admin memverifikasi pendaftar sebelum menyetujui. Ketuk akun untuk mengubah role/password. Akun Admin tidak dapat dihapus.'),
          for (final item in _items!)
            Card(
                child: ListTile(
                  title: Text(item['username'] as String),
                  subtitle: Text(
                      '${item['role']} • ${item['approved'] == 0 ? 'Menunggu persetujuan' : item['active'] == 1 ? 'Aktif' : 'Nonaktif'}'),
                  trailing:
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (item['approved'] == 0)
                      IconButton(
                          tooltip: 'Setujui akun',
                          icon: const Icon(Icons.check_circle),
                          onPressed: () => _approve(
                              Map<String, dynamic>.from(
                                  item as Map))),
                    if (item['role'] != 'admin')
                      IconButton(
                          tooltip: 'Delete akun',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteUser(
                              Map<String, dynamic>.from(
                                  item as Map))),
                  ]),
                  onTap: () =>
                      _edit(Map<String, dynamic>.from(item as Map)),
                )),
        ]),
  );
}

class OnlineMaterials extends StatefulWidget {
  const OnlineMaterials({super.key, required this.api});
  final CampusAuthApi api;
  @override
  State<OnlineMaterials> createState() => _OnlineMaterialsState();
}

class _OnlineMaterialsState extends State<OnlineMaterials> {
  List<dynamic>? _items;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _writer => ['admin', 'Dosen'].contains(widget.api.user?['role']);
  Future<void> _load() async {
    try {
      final items = await widget.api.request('GET', '/materials') as List;
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final code =
    TextEditingController(text: item?['course_code'] as String? ?? '');
    final title = TextEditingController(text: item?['title'] as String? ?? '');
    final content =
    TextEditingController(text: item?['content'] as String? ?? '');
    bool saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
              title: Text(item == null ? 'Tambah materi' : 'Ubah materi'),
              content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                      child:
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        TextField(
                            controller: code,
                            maxLength: 30,
                            enabled: !saving,
                            decoration: const InputDecoration(
                                labelText: 'Kode MK (sesuai kurikulum)')),
                        TextField(
                            controller: title,
                            maxLength: 160,
                            enabled: !saving,
                            decoration:
                            const InputDecoration(labelText: 'Judul')),
                        TextField(
                            controller: content,
                            minLines: 4,
                            maxLines: 10,
                            maxLength: 20000,
                            enabled: !saving,
                            decoration: const InputDecoration(
                                labelText: 'Isi materi (teks)')),
                        if (error != null)
                          Text(error!,
                              style: const TextStyle(color: Colors.red)),
                      ]))),
              actions: [
                TextButton(
                    onPressed:
                    saving ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                      if (code.text.trim().isEmpty ||
                          title.text.trim().isEmpty ||
                          content.text.trim().isEmpty) {
                        update(
                                () => error = 'Semua isian wajib diisi.');
                        return;
                      }
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await widget.api.request(
                            item == null ? 'POST' : 'PUT',
                            item == null
                                ? '/materials'
                                : '/materials/${item['id']}',
                            {
                              'course_code': code.text.trim(),
                              'title': title.text.trim(),
                              'content': content.text,
                            });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            error = _message(e);
                            saving = false;
                          });
                        }
                      }
                    },
                    child: Text(saving ? 'Menyimpan…' : 'Simpan')),
              ],
            )));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    code.dispose();
    title.dispose();
    content.dispose();
    if (mounted) await _load();
  }

  Future<void> _delete(Map item) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Hapus materi?'),
          content: Text(item['title'] as String),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Hapus'))
          ],
        ));
    if (yes != true) return;
    try {
      await widget.api.request('DELETE', '/materials/${item['id']}');
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Materi lokal'), actions: [
      IconButton(
          tooltip: 'Muat ulang',
          onPressed: _load,
          icon: const Icon(Icons.refresh))
    ]),
    floatingActionButton: _writer
        ? FloatingActionButton(
        tooltip: 'Tambah materi',
        onPressed: () => _edit(),
        child: const Icon(Icons.add))
        : null,
    body: _error != null
        ? Center(child: Text(_error!))
        : _items == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          const Text(
              'Materi tambahan lokal pada perangkat ini. Data kurikulum inti tidak diubah. Tarik data terbaru lewat tombol muat ulang.'),
          if (_items!.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada materi.')),
          for (final raw in _items!)
            Builder(builder: (context) {
              final item = Map<String, dynamic>.from(raw as Map);
              final own = widget.api.user?['role'] == 'admin' ||
                  (widget.api.user?['role'] == 'Dosen' &&
                      item['owner_id'] == widget.api.user?['id']);
              return Card(
                  child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${item['course_code']} • ${item['title']}',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          Text('Dibuat oleh: ${item['owner']}'),
                          const SizedBox(height: 10),
                          SelectableText(
                              item['content'] as String),
                          if (own)
                            Wrap(children: [
                              TextButton.icon(
                                  onPressed: () => _edit(item),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Ubah')),
                              TextButton.icon(
                                  onPressed: () => _delete(item),
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Hapus')),
                            ]),
                        ],
                      )));
            }),
        ]),
  );
}
