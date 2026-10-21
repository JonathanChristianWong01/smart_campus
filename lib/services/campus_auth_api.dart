import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Demo lokal satu perangkat, BUKAN batas keamanan untuk data kampus produksi.
/// Nama kelas dipertahankan agar UI lama kompatibel; tidak ada HTTP/URL.
class CampusAuthApi {
  static const storageKey = 'smart_campus_local_accounts_v1';
  static const _iterations = 210000;
  Map<String, dynamic>? _data;
  SharedPreferences? _prefs;
  Map<String, dynamic>? user;
  DateTime? _expires;
  void Function()? onExpired;
  Future<void> _tail = Future<void>.value();
  bool get hasAdmin => _users.any((u) => u['role'] == 'admin');
  List<dynamic> get _users => _data?['users'] as List<dynamic>? ?? <dynamic>[];
  List<dynamic> get _materials => _data!['materials'] as List<dynamic>;

  Future<void> initialize() async {
    if (_data != null) return;
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs!.getString(storageKey);
    if (saved == null) {
      _data = {
        'version': 1,
        'nextUser': 1,
        'nextMaterial': 1,
        'users': <dynamic>[],
        'materials': <dynamic>[]
      };
      return;
    }
    try {
      final value = jsonDecode(saved) as Map<String, dynamic>;
      if (value['version'] != 1 ||
          value['users'] is! List ||
          value['materials'] is! List ||
          value['nextUser'] is! int ||
          value['nextMaterial'] is! int) {
        throw const FormatException();
      }
      _data = value;
    } catch (_) {
      throw Exception(
          'Data akun lokal tidak dapat dibaca. Jangan hapus data sebelum membuat cadangan.');
    }
  }

  Future<dynamic> _serial(Future<dynamic> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> _save() async {
    if (!await _prefs!.setString(storageKey, jsonEncode(_data))) {
      throw Exception('Data lokal gagal disimpan. Periksa ruang penyimpanan.');
    }
  }

  String _username(dynamic value) {
    final name = (value as String? ?? '').trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_.-]{3,40}$').hasMatch(name)) {
      throw Exception('Username 3–40 karakter tanpa spasi.');
    }
    return name;
  }

  void _password(String password) {
    if (password.length < 12 || password.length > 128) {
      throw Exception('Password harus 12–128 karakter.');
    }
  }

  Future<String> _derive(String password, String salt) async {
    final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(), iterations: _iterations, bits: 256)
        .deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: base64Decode(salt));
    return base64Encode(await key.extractBytes());
  }

  Future<Map<String, String>> _hash(String password) async {
    _password(password);
    final random = Random.secure();
    final salt =
    base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
    return {'salt': salt, 'hash': await _derive(password, salt)};
  }

  Future<bool> _verify(Map actor, String password) async {
    final actual =
    base64Decode(await _derive(password, actor['salt'] as String));
    final expected = base64Decode(actor['hash'] as String);
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Map<String, dynamic> _public(Map u) => {
    'id': u['id'],
    'username': u['username'],
    'role': u['role'],
    'active': u['active'],
    'approved': u['approved'],
  };
  Map<String, dynamic>? _find(int id) {
    for (final item in _users) {
      if (item['id'] == id) return item as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic> _actor() {
    final actor = user == null ? null : _find(user!['id'] as int);
    if (actor == null ||
        actor['active'] != 1 ||
        actor['approved'] != 1 ||
        _expires == null ||
        !DateTime.now().isBefore(_expires!)) {
      forget();
      onExpired?.call();
      throw Exception('Silakan login kembali.');
    }
    user = _public(actor);
    return actor;
  }

  void _admin(Map actor) {
    if (actor['role'] != 'admin') throw Exception('Hanya Admin lokal.');
  }

  void _role(String role) {
    if (!['admin', 'Mahasiswa', 'Dosen'].contains(role)) {
      throw Exception('Role tidak valid.');
    }
  }

  Future<Map<String, dynamic>> _create(Map<String, dynamic> body,
      {required bool pending}) async {
    final name = _username(body['username']);
    final role = body['role'] as String? ?? '';
    _role(role);
    if (_users.any((u) => u['username'] == name)) {
      throw Exception('Username sudah digunakan di perangkat ini.');
    }
    final hashed = await _hash(body['password'] as String? ?? '');
    final row = <String, dynamic>{
      'id': _data!['nextUser'],
      'username': name,
      'role': role,
      'active': pending ? 0 : 1,
      'approved': pending ? 0 : 1,
      ...hashed
    };
    _data!['nextUser'] = (_data!['nextUser'] as int) + 1;
    _users.add(row);
    return _public(row);
  }

  Future<void> bootstrapAdmin(String username, String password) async {
    await request('POST', '/local/bootstrap',
        {'username': username, 'password': password});
  }

  Future<void> login(String username, String password) async {
    await request(
        'POST', '/auth/login', {'username': username, 'password': password});
  }

  Future<void> logout() async {
    forget();
  }

  void forget() {
    user = null;
    _expires = null;
  }

  void dispose() {
    forget();
  }

  Future<dynamic> request(String method, String path,
      [Map<String, dynamic>? body]) =>
      _serial(() async {
        await initialize();
        final before = jsonEncode(_data);
        final b = body ?? <String, dynamic>{};
        try {
          if (method == 'POST' && path == '/local/bootstrap') {
            if (hasAdmin) throw Exception('Admin lokal sudah tersedia.');
            final result =
            await _create({...b, 'role': 'admin'}, pending: false);
            await _save();
            return result;
          }
          if (method == 'POST' && path == '/auth/register') {
            if (!hasAdmin) throw Exception('Buat Admin lokal pertama dahulu.');
            if (!['Mahasiswa', 'Dosen'].contains(b['role'])) {
              throw Exception('Tidak boleh mendaftar sebagai Admin.');
            }
            await _create(b, pending: true);
            await _save();
            return {'message': 'Menunggu persetujuan Admin di perangkat ini.'};
          }
          if (method == 'POST' && path == '/auth/login') {
            final name = _username(b['username']);
            Map<String, dynamic>? account;
            for (final item in _users) {
              if (item['username'] == name) {
                account = item as Map<String, dynamic>;
              }
            }
            if (account == null ||
                !await _verify(account, b['password'] as String? ?? '')) {
              throw Exception('Username atau password salah.');
            }
            if (account['approved'] != 1 || account['active'] != 1) {
              throw Exception(
                  'Akun belum disetujui Admin lokal atau sedang dinonaktifkan.');
            }
            user = _public(account);
            _expires = DateTime.now().add(const Duration(hours: 8));
            return {'user': user};
          }
          final actor = _actor();
          if (method == 'GET' && path == '/auth/me') return _public(actor);
          if (method == 'POST' && path == '/auth/logout') {
            forget();
            return null;
          }
          if (path == '/users' && method == 'GET') {
            _admin(actor);
            return _users.map((u) => _public(u as Map)).toList();
          }
          if (path == '/users' && method == 'POST') {
            _admin(actor);
            final result = await _create(b, pending: false);
            await _save();
            return result;
          }
          if ((path.startsWith('/users/') && method == 'DELETE') ||
              (path == '/auth/account' && method == 'DELETE')) {
            final own = path == '/auth/account';
            if (!own) _admin(actor);
            final id =
            own ? actor['id'] as int : int.parse(path.split('/').last);
            final target = _find(id);
            if (target == null) throw Exception('Akun tidak ditemukan.');
            if (target['role'] == 'admin') {
              throw Exception('Akun Admin tidak dapat dihapus.');
            }
            if (b['confirm_username'].toString().trim().toLowerCase() !=
                target['username']) {
              throw Exception('Konfirmasi username tidak sesuai.');
            }
            if (!await _verify(actor, b['password'] as String? ?? '')) {
              throw Exception('Password konfirmasi salah.');
            }
            for (final material in _materials) {
              if (material['owner_id'] == id) material['owner_id'] = null;
            }
            _users.removeWhere((u) => u['id'] == id);
            await _save();
            if (own) forget();
            return null;
          }
          if (path.startsWith('/users/') && method == 'PATCH') {
            _admin(actor);
            final target = _find(int.parse(path.split('/').last));
            if (target == null) throw Exception('Akun tidak ditemukan.');
            final role = b['role'] as String? ?? target['role'] as String;
            _role(role);
            final active = b['active'] == null
                ? target['active'] as int
                : (b['active'] == true ? 1 : 0);
            if (target['id'] == actor['id'] && (role != 'admin' || active != 1)) {
              throw Exception(
                  'Admin tidak boleh menonaktifkan/menurunkan role sendiri.');
            }
            if (target['role'] == 'admin' &&
                target['active'] == 1 &&
                (role != 'admin' || active != 1) &&
                _users
                    .where((u) => u['role'] == 'admin' && u['active'] == 1)
                    .length <=
                    1) {
              throw Exception('Admin aktif terakhir harus dipertahankan.');
            }
            if ((b['password'] as String? ?? '').isNotEmpty) {
              target.addAll(await _hash(b['password'] as String));
            }
            target['role'] = role;
            target['active'] = active;
            if (active == 1) target['approved'] = 1;
            await _save();
            return _public(target);
          }
          if (path == '/materials' && method == 'GET') {
            return _materials.reversed
                .map((m) => <String, dynamic>{
              ...m as Map<String, dynamic>,
              'owner': m['owner_id'] == null
                  ? 'Akun dihapus'
                  : _find(m['owner_id'] as int)?['username'] ??
                  'Akun dihapus'
            })
                .toList();
          }
          if (path == '/materials' || path.startsWith('/materials/')) {
            if (!['admin', 'Dosen'].contains(actor['role'])) {
              throw Exception('Mahasiswa hanya boleh membaca materi lokal.');
            }
            Map<String, dynamic>? material;
            if (path != '/materials') {
              final id = int.parse(path.split('/').last);
              for (final m in _materials) {
                if (m['id'] == id) material = m as Map<String, dynamic>;
              }
              if (material == null) throw Exception('Materi tidak ditemukan.');
              if (actor['role'] != 'admin' &&
                  material['owner_id'] != actor['id']) {
                throw Exception('Dosen hanya boleh mengelola materi miliknya.');
              }
            }
            if (method == 'DELETE' && material != null) {
              _materials.remove(material);
              await _save();
              return null;
            }
            if ((method == 'POST' && path == '/materials') ||
                (method == 'PUT' && material != null)) {
              final code = (b['course_code'] as String? ?? '').trim();
              final title = (b['title'] as String? ?? '').trim();
              final content = b['content'] as String? ?? '';
              if (code.isEmpty ||
                  code.length > 30 ||
                  title.isEmpty ||
                  title.length > 160 ||
                  content.trim().isEmpty ||
                  content.length > 20000) {
                throw Exception(
                    'Kode MK, judul dan isi materi wajib diisi sesuai batas panjang.');
              }
              if (material == null) {
                material = {
                  'id': _data!['nextMaterial'],
                  'owner_id': actor['id']
                };
                _data!['nextMaterial'] = (_data!['nextMaterial'] as int) + 1;
                _materials.add(material);
              }
              material.addAll(
                  {'course_code': code, 'title': title, 'content': content});
              await _save();
              return {'id': material['id']};
            }
          }
          throw Exception('Fungsi lokal tidak tersedia.');
        } catch (_) {
          _data = jsonDecode(before) as Map<String, dynamic>;
          rethrow;
        }
      });
}
