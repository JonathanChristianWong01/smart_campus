import 'package:flutter/material.dart';
import '../services/campus_auth_api.dart';

String _errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen(
      {super.key, required this.api, this.setupAdmin = false});
  final CampusAuthApi api;
  final bool setupAdmin;
  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _role = 'Mahasiswa';
  String? _error;
  bool _busy = false;
  bool _success = false;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!RegExp(r'^[a-zA-Z0-9_.-]{3,40}$').hasMatch(_username.text.trim())) {
      setState(() => _error = 'Username 3–40 karakter tanpa spasi.');
      return;
    }
    if (_password.text.length < 12 || _password.text.length > 128) {
      setState(() => _error = 'Password harus 12–128 karakter.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.setupAdmin) {
        await widget.api.bootstrapAdmin(_username.text, _password.text);
      } else {
        await widget.api.request('POST', '/auth/register', {
          'username': _username.text.trim(),
          'password': _password.text,
          'role': _role,
        });
      }
      _password.clear();
      _confirm.clear();
      if (mounted) setState(() => _success = true);
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
        title: Text(widget.setupAdmin
            ? 'Buat Admin Lokal Pertama'
            : 'Buat Akun Lokal')),
    body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: _success
                ? Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_top, size: 56),
              const SizedBox(height: 16),
              Text(
                  widget.setupAdmin
                      ? 'Admin lokal berhasil dibuat. Silakan login sebagai Admin.'
                      : 'Pendaftaran berhasil. Menunggu persetujuan Admin pada perangkat ini.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                  'Mahasiswa/Dosen harus disetujui Admin di HP yang sama. Jika baru membuat Admin, kembali dan login sebagai Admin.'),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kembali ke Login')),
            ])
                : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.setupAdmin
                      ? 'Buat username dan password Admin lokal Anda. Tidak ada akun bawaan. Simpan password dengan aman.'
                      : 'Daftar sebagai Mahasiswa atau Dosen. Keduanya memerlukan persetujuan Admin di perangkat ini.'),
                  const SizedBox(height: 8),
                  const Text(
                      'Mode lokal: data tidak tersinkron ke HP lain.'),
                  const SizedBox(height: 18),
                  if (!widget.setupAdmin)
                    DropdownButtonFormField<String>(
                        key: const ValueKey('register-role'),
                        initialValue: _role,
                        decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'Mahasiswa',
                              child: Text('Mahasiswa')),
                          DropdownMenuItem(
                              value: 'Dosen', child: Text('Dosen'))
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _role = v!)),
                  const SizedBox(height: 14),
                  TextField(
                      key: const ValueKey('register-username'),
                      controller: _username,
                      enabled: !_busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 40,
                      decoration: const InputDecoration(
                          labelText: 'Username (tanpa spasi)',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      key: const ValueKey('register-password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 128,
                      decoration: const InputDecoration(
                          labelText: 'Password (minimal 12 karakter)',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                      key: const ValueKey('register-confirm'),
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 128,
                      decoration: const InputDecoration(
                          labelText: 'Ulangi password',
                          border: OutlineInputBorder())),
                  if (_error != null)
                    Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy
                          ? 'Menyimpan…'
                          : widget.setupAdmin
                          ? 'Simpan Admin Lokal'
                          : 'Daftar & Tunggu Persetujuan')),
                ]),
          ),
        )),
  );
}

/// Returns true only after local storage confirms deletion. Admin must enter own password.
Future<bool> confirmDeleteAccount(BuildContext context, CampusAuthApi api,
    {Map<String, dynamic>? target}) async {
  final username =
      target?['username'] as String? ?? api.user?['username'] as String? ?? '';
  final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(
          api: api, username: username, targetId: target?['id'] as int?));
  final deleted = await Navigator.of(context).push(route);
  await route.completed;
  return deleted == true;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog(
      {required this.api, required this.username, this.targetId});
  final CampusAuthApi api;
  final String username;
  final int? targetId;
  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty ||
        _confirm.text.trim().toLowerCase() != widget.username.toLowerCase()) {
      setState(() => _error =
      'Masukkan password Anda dan ketik username akun yang akan dihapus.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.request(
          'DELETE',
          widget.targetId == null
              ? '/auth/account'
              : '/users/${widget.targetId}',
          {
            'password': _password.text,
            'confirm_username': _confirm.text.trim(),
          });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Delete Akun Permanen'),
    content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Hapus akun ${widget.username}? Akun dan seluruh sesinya dihapus permanen. '
                        'Materi tetap tersedia dengan nama pembuat “Akun dihapus”. Tindakan ini tidak dapat dibatalkan.'),
                const SizedBox(height: 12),
                TextField(
                    key: const ValueKey('delete-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                        labelText: widget.targetId == null
                            ? 'Password akun Anda'
                            : 'Password Admin Anda')),
                TextField(
                    key: const ValueKey('delete-confirm'),
                    controller: _confirm,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                        labelText: 'Ketik: ${widget.username}')),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ))),
    actions: [
      TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Batal')),
      FilledButton(
          onPressed: _busy ? null : _delete,
          child: Text(_busy ? 'Menghapus…' : 'Hapus Permanen')),
    ],
  );
}
