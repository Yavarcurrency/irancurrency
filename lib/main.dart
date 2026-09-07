import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

void main() => runApp(const App());

enum Audience { retail, partner }
enum AdminSection { cash, remittance, regional, gold, partner, methods, currencies, settings }
enum MarketTab { cash, remittance, regional }

class CurrencyDef {
  CurrencyDef(
    this.code,
    this.title,
    this.flag,
    this.country, {
    this.cash = false,
    this.remittance = false,
    this.cashOrder = 999,
    this.remitOrder = 999,
  });

  final String code;
  String title, flag, country;
  bool cash, remittance;
  int cashOrder, remitOrder;
}

class MethodDef {
  MethodDef(this.id, this.country, this.flag, this.currency, this.title, this.order);

  final int id;
  final String country, flag, currency;
  String title;
  int order;
}

class Rate {
  Rate(this.kind, this.key, this.audience, this.buy, this.sell);
  final String kind, key;
  final Audience audience;
  double buy, sell;
}

class RegionalRate {
  RegionalRate(this.from, this.to, this.currency, this.audience, this.base, this.dest);
  final String from, to, currency;
  final Audience audience;
  double base, dest;
  double? get aed => to == 'دبی' && currency == 'USD' ? dest * 3.67 : null;
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = const Color(0xFF4F67A8);

  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('themeMode');
    final color = prefs.getInt('seedColor');
    if (!mounted) return;
    setState(() {
      if (mode == 'light') _themeMode = ThemeMode.light;
      if (mode == 'dark') _themeMode = ThemeMode.dark;
      if (mode == 'system') _themeMode = ThemeMode.system;
      if (color != null) _seedColor = Color(color);
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> _setSeedColor(Color color) async {
    setState(() => _seedColor = color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', color.value);
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF7F8FC)
          : const Color(0xFF101216),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0.7,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: Home(
        themeMode: _themeMode,
        seedColor: _seedColor,
        onThemeModeChanged: _setThemeMode,
        onSeedColorChanged: _setSeedColor,
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.themeMode,
    required this.seedColor,
    required this.onThemeModeChanged,
    required this.onSeedColorChanged,
  });

  final ThemeMode themeMode;
  final Color seedColor;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Color> onSeedColorChanged;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final ApiService api = ApiService();
  bool admin = false, partnerMode = false;
  bool serverOnline = false;
  bool syncing = false;
  String? serverMessage;
  Timer? _refreshTimer;
  String partnerCode = '1234';
  AdminSection section = AdminSection.cash;
  MarketTab market = MarketTab.cash;

  final currencies = <CurrencyDef>[
    CurrencyDef('USD', 'دلار آمریکا', '🇺🇸', 'آمریکا', cash: true, remittance: true, cashOrder: 1, remitOrder: 1),
    CurrencyDef('EUR', 'یورو', '🇪🇺', 'اروپا', cash: true, cashOrder: 2),
    CurrencyDef('AED', 'درهم امارات', '🇦🇪', 'امارات', cash: true, cashOrder: 3),
    CurrencyDef('GBP', 'پوند انگلیس', '🇬🇧', 'انگلیس', cash: true, remittance: true, cashOrder: 4, remitOrder: 3),
    CurrencyDef('TRY', 'لیر ترکیه', '🇹🇷', 'ترکیه', cash: true, cashOrder: 5),
    CurrencyDef('CAD', 'دلار کانادا', '🇨🇦', 'کانادا', remittance: true, remitOrder: 2),
  ];

  final catalog = const <String, List<String>>{
    'USD': ['دلار آمریکا', '🇺🇸', 'آمریکا'],
    'EUR': ['یورو', '🇪🇺', 'اروپا'],
    'AED': ['درهم امارات', '🇦🇪', 'امارات'],
    'GBP': ['پوند انگلیس', '🇬🇧', 'انگلیس'],
    'TRY': ['لیر ترکیه', '🇹🇷', 'ترکیه'],
    'CAD': ['دلار کانادا', '🇨🇦', 'کانادا'],
    'CHF': ['فرانک سوئیس', '🇨🇭', 'سوئیس'],
    'AUD': ['دلار استرالیا', '🇦🇺', 'استرالیا'],
    'CNY': ['یوان چین', '🇨🇳', 'چین'],
    'JPY': ['ین ژاپن', '🇯🇵', 'ژاپن'],
  };

  final methods = <MethodDef>[
    MethodDef(1, 'آمریکا', '🇺🇸', 'USD', 'واریز به حساب', 1),
    MethodDef(2, 'آمریکا', '🇺🇸', 'USD', 'Cash', 2),
    MethodDef(3, 'آمریکا', '🇺🇸', 'USD', 'Money Order', 3),
    MethodDef(4, 'آمریکا', '🇺🇸', 'USD', 'Zelle', 4),
    MethodDef(5, 'آمریکا', '🇺🇸', 'USD', 'Wire', 5),
    MethodDef(6, 'کانادا', '🇨🇦', 'CAD', 'Cash Toronto', 1),
    MethodDef(7, 'کانادا', '🇨🇦', 'CAD', 'Cash Vancouver', 2),
    MethodDef(8, 'کانادا', '🇨🇦', 'CAD', 'حواله ایمیلی', 3),
    MethodDef(9, 'کانادا', '🇨🇦', 'CAD', 'واریز به حساب', 4),
    MethodDef(10, 'کانادا', '🇨🇦', 'CAD', 'Wire', 5),
    MethodDef(11, 'انگلیس', '🇬🇧', 'GBP', 'Cash London', 1),
    MethodDef(12, 'انگلیس', '🇬🇧', 'GBP', 'واریز به حساب', 2),
    MethodDef(13, 'انگلیس', '🇬🇧', 'GBP', 'FCA', 3),
  ];

  final rates = <Rate>[
    Rate('cash', 'USD', Audience.retail, 103000, 104000),
    Rate('cash', 'EUR', Audience.retail, 112000, 113200),
    Rate('cash', 'AED', Audience.retail, 28050, 28300),
    Rate('cash', 'GBP', Audience.retail, 131000, 132500),
    Rate('cash', 'USD', Audience.partner, 103500, 103800),
    Rate('remittance', '4', Audience.retail, 103400, 104400),
    Rate('remittance', '6', Audience.retail, 75400, 76200),
    Rate('remittance', '4', Audience.partner, 103600, 103900),
    Rate('remittance', '6', Audience.partner, 75800, 76000),
  ];

  final regional = <RegionalRate>[
    RegionalRate('تهران', 'ترکیه', 'USD', Audience.retail, 10000, 9980),
    RegionalRate('تهران', 'دبی', 'USD', Audience.retail, 10000, 9980),
    RegionalRate('سلیمانیه', 'تهران', 'USD', Audience.retail, 10000, 10020),
    RegionalRate('تهران', 'دبی', 'USD', Audience.partner, 10000, 9975),
  ];

  String lastCash = 'USD', lastRegionalCur = 'USD', lastFrom = 'تهران', lastTo = 'دبی';
  Audience lastCashAud = Audience.retail, lastRemitAud = Audience.retail, lastRegAud = Audience.retail;
  int lastMethod = 1;

  final buy = TextEditingController();
  final sell = TextEditingController();
  final rBuy = TextEditingController();
  final rSell = TextEditingController();
  final base = TextEditingController(text: '10000');
  final dest = TextEditingController();
  final codeCtl = TextEditingController();
  final titleCtl = TextEditingController();
  final methodCtl = TextEditingController();

  static const adminLabels = <String>[
    'نقدی',
    'حواله',
    'تبدیل منطقه‌ای',
    'طلا و سکه',
    'کد همکار',
    'روش‌های حواله',
    'مدیریت ارزها',
    'ظاهر و تنظیمات',
  ];

  @override
  void initState() {
    super.initState();
    _loadRemoteState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!admin) {
        _loadRemoteState(token: partnerMode ? api.partnerToken : null);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    buy.dispose();
    sell.dispose();
    rBuy.dispose();
    rSell.dispose();
    base.dispose();
    dest.dispose();
    codeCtl.dispose();
    titleCtl.dispose();
    methodCtl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _exportState() => {
        'partner_code': partnerCode,
        'currencies': currencies
            .map((c) => {
                  'code': c.code,
                  'title': c.title,
                  'flag': c.flag,
                  'country': c.country,
                  'cash': c.cash,
                  'remittance': c.remittance,
                  'cashOrder': c.cashOrder,
                  'remitOrder': c.remitOrder,
                })
            .toList(),
        'methods': methods
            .map((m) => {
                  'id': m.id,
                  'country': m.country,
                  'flag': m.flag,
                  'currency': m.currency,
                  'title': m.title,
                  'order': m.order,
                })
            .toList(),
        'rates': rates
            .map((r) => {
                  'kind': r.kind,
                  'key': r.key,
                  'audience': r.audience.name,
                  'buy': r.buy,
                  'sell': r.sell,
                })
            .toList(),
        'regional': regional
            .map((r) => {
                  'from': r.from,
                  'to': r.to,
                  'currency': r.currency,
                  'audience': r.audience.name,
                  'base': r.base,
                  'dest': r.dest,
                })
            .toList(),
        'meta': {'valid_minutes': 15},
      };

  void _importState(Map<String, dynamic> data, {bool adminPayload = false}) {
    final cs = (data['currencies'] as List? ?? const []);
    if (cs.isNotEmpty) {
      currencies
        ..clear()
        ..addAll(cs.map((x) {
          final m = Map<String, dynamic>.from(x as Map);
          return CurrencyDef(
            m['code'].toString(),
            m['title'].toString(),
            m['flag'].toString(),
            m['country'].toString(),
            cash: m['cash'] == true,
            remittance: m['remittance'] == true,
            cashOrder: (m['cashOrder'] as num?)?.toInt() ?? 999,
            remitOrder: (m['remitOrder'] as num?)?.toInt() ?? 999,
          );
        }));
    }
    final ms = (data['methods'] as List? ?? const []);
    if (ms.isNotEmpty) {
      methods
        ..clear()
        ..addAll(ms.map((x) {
          final m = Map<String, dynamic>.from(x as Map);
          return MethodDef(
            (m['id'] as num).toInt(),
            m['country'].toString(),
            m['flag'].toString(),
            m['currency'].toString(),
            m['title'].toString(),
            (m['order'] as num).toInt(),
          );
        }));
    }
    final rs = (data['rates'] as List? ?? const []);
    if (rs.isNotEmpty || data.containsKey('rates')) {
      rates
        ..clear()
        ..addAll(rs.map((x) {
          final m = Map<String, dynamic>.from(x as Map);
          return Rate(
            m['kind'].toString(),
            m['key'].toString(),
            m['audience'] == 'partner' ? Audience.partner : Audience.retail,
            (m['buy'] as num).toDouble(),
            (m['sell'] as num).toDouble(),
          );
        }));
    }
    final rr = (data['regional'] as List? ?? const []);
    if (rr.isNotEmpty || data.containsKey('regional')) {
      regional
        ..clear()
        ..addAll(rr.map((x) {
          final m = Map<String, dynamic>.from(x as Map);
          return RegionalRate(
            m['from'].toString(),
            m['to'].toString(),
            m['currency'].toString(),
            m['audience'] == 'partner' ? Audience.partner : Audience.retail,
            (m['base'] as num).toDouble(),
            (m['dest'] as num).toDouble(),
          );
        }));
    }
    if (adminPayload && data['partner_code'] != null) {
      partnerCode = data['partner_code'].toString();
    }
  }

  Future<void> _loadRemoteState({String? token, bool adminPayload = false}) async {
    try {
      final data = await api.getState(token: token);
      if (!mounted) return;
      setState(() {
        _importState(data, adminPayload: adminPayload);
        serverOnline = true;
        serverMessage = 'متصل به سرور';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        serverOnline = false;
        serverMessage = 'حالت آفلاین - اطلاعات داخلی برنامه';
      });
    }
  }

  Future<void> _saveRemoteState() async {
    if (api.adminToken == null) {
      _snack('ابتدا وارد پنل مدیریت شوید.');
      return;
    }
    setState(() => syncing = true);
    try {
      await api.saveState(_exportState());
      if (!mounted) return;
      setState(() {
        syncing = false;
        serverOnline = true;
        serverMessage = 'ذخیره شد';
      });
      _snack('تغییرات روی سرور ذخیره شد.');
    } catch (e) {
      if (!mounted) return;
      setState(() => syncing = false);
      _snack('خطا در ذخیره روی سرور: $e');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _adminLoginDialog() async {
    if (api.adminToken != null) return true;
    final ctl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ورود مدیر'),
          content: TextField(
            controller: ctl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'رمز مدیریت سرور'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لغو')),
            FilledButton(
              onPressed: () async {
                try {
                  final token = await api.adminLogin(ctl.text);
                  await _loadRemoteState(token: token, adminPayload: true);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('ورود مدیر ناموفق بود.')));
                  }
                }
              },
              child: const Text('ورود'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Rate? findRate(String kind, String key, Audience audience) {
    for (final r in rates) {
      if (r.kind == kind && r.key == key && r.audience == audience) return r;
    }
    return null;
  }

  void upsert(String kind, String key, Audience audience, double b, double s) {
    final r = findRate(kind, key, audience);
    if (r != null) {
      r.buy = b;
      r.sell = s;
    } else {
      rates.add(Rate(kind, key, audience, b, s));
    }
    _saveRemoteState();
  }

  String fmt(num n) => n
      .toStringAsFixed(n % 1 == 0 ? 0 : 2)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '٬');

  Audience get appAudience => partnerMode ? Audience.partner : Audience.retail;

  void normalize(bool cash) {
    final list = currencies.where((c) => cash ? c.cash : c.remittance).toList()
      ..sort((a, b) => (cash ? a.cashOrder : a.remitOrder)
          .compareTo(cash ? b.cashOrder : b.remitOrder));
    for (var i = 0; i < list.length; i++) {
      if (cash) {
        list[i].cashOrder = i + 1;
      } else {
        list[i].remitOrder = i + 1;
      }
    }
  }

  void moveCurrency(CurrencyDef c, bool cash, int d) {
    final list = currencies.where((x) => cash ? x.cash : x.remittance).toList()
      ..sort((a, b) => (cash ? a.cashOrder : a.remitOrder)
          .compareTo(cash ? b.cashOrder : b.remitOrder));
    final i = list.indexOf(c), j = i + d;
    if (i < 0 || j < 0 || j >= list.length) return;
    final x = cash ? list[i].cashOrder : list[i].remitOrder;
    final y = cash ? list[j].cashOrder : list[j].remitOrder;
    if (cash) {
      list[i].cashOrder = y;
      list[j].cashOrder = x;
    } else {
      list[i].remitOrder = y;
      list[j].remitOrder = x;
    }
    normalize(cash);
    setState(() {});
    _saveRemoteState();
  }

  void ensureMethod(String code) {
    if (methods.any((m) => m.currency == code)) return;
    final c = currencies.firstWhere((x) => x.code == code);
    final id = methods.isEmpty ? 1 : methods.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1;
    methods.add(MethodDef(id, c.country, c.flag, c.code, 'حواله', 1));
  }

  void moveMethod(MethodDef m, int d) {
    final group = methods.where((x) => x.currency == m.currency && x.country == m.country).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final i = group.indexOf(m), j = i + d;
    if (i < 0 || j < 0 || j >= group.length) return;
    final t = group[i].order;
    group[i].order = group[j].order;
    group[j].order = t;
    setState(() {});
    _saveRemoteState();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Irancurrency', maxLines: 1),
          actions: [
            IconButton(
              tooltip: 'ظاهر و تنظیمات',
              onPressed: () {
                if (admin) {
                  setState(() => section = AdminSection.settings);
                } else {
                  _showSettingsSheet();
                }
              },
              icon: const Icon(Icons.palette_outlined),
            ),
            if (admin)
              IconButton(
                tooltip: 'ذخیره روی سرور',
                onPressed: syncing ? null : _saveRemoteState,
                icon: syncing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('پنل')),
                  ButtonSegment(value: false, label: Text('اپ')),
                ],
                selected: {admin},
                onSelectionChanged: (v) async {
                  final wantsAdmin = v.first;
                  if (wantsAdmin) {
                    if (await _adminLoginDialog()) setState(() => admin = true);
                  } else {
                    setState(() => admin = false);
                    await _loadRemoteState();
                  }
                },
              ),
            ),
          ],
        ),
        body: admin ? adminView() : appView(),
      ),
    );
  }

  Widget adminView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 720;
        if (mobile) {
          return Column(
            children: [
              SizedBox(height: 58, child: _horizontalAdminMenu()),
              const Divider(height: 1),
              _serverStatusBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  child: adminContent(),
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 210, child: _verticalAdminMenu()),
            const VerticalDivider(width: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: adminContent(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _horizontalAdminMenu() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: AdminSection.values.length,
      separatorBuilder: (_, __) => const SizedBox(width: 7),
      itemBuilder: (context, index) {
        final item = AdminSection.values[index];
        return ChoiceChip(
          selected: section == item,
          label: Text(adminLabels[index], maxLines: 1),
          onSelected: (_) => setState(() => section = item),
        );
      },
    );
  }

  Widget _verticalAdminMenu() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        for (final item in AdminSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                alignment: Alignment.centerRight,
                backgroundColor: section == item
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : null,
              ),
              onPressed: () => setState(() => section = item),
              child: Text(adminLabels[item.index]),
            ),
          ),
      ],
    );
  }

  Widget _serverStatusBar() {
    final color = serverOnline ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(serverOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(serverMessage ?? 'در حال بررسی اتصال سرور…', style: const TextStyle(fontSize: 12))),
          Text(api.baseUrl, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget adminContent() {
    switch (section) {
      case AdminSection.cash:
        return cashAdmin();
      case AdminSection.remittance:
        return remitAdmin();
      case AdminSection.regional:
        return regAdmin();
      case AdminSection.methods:
        return methodsAdmin();
      case AdminSection.currencies:
        return currenciesAdmin();
      case AdminSection.partner:
        return partnerAdmin();
      case AdminSection.gold:
        return _emptyAdminCard('طلا و سکه', 'این بخش آماده اتصال به Backend واقعی است.');
      case AdminSection.settings:
        return settingsView();
    }
  }

  Widget _emptyAdminCard(String heading, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title(heading, text),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Icon(Icons.construction, size: 48, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget title(String a, String b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(a, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(b, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget audience(Audience v, ValueChanged<Audience> f) {
    return DropdownButtonFormField<Audience>(
      value: v,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'نمایش برای'),
      items: const [
        DropdownMenuItem(value: Audience.retail, child: Text('مشتری')),
        DropdownMenuItem(value: Audience.partner, child: Text('همکار')),
      ],
      onChanged: (x) {
        if (x != null) f(x);
      },
    );
  }

  Widget numfield(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _reorderCard({
    required String heading,
    String? subtitle,
    required VoidCallback up,
    required VoidCallback down,
    VoidCallback? delete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(heading, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(onPressed: up, icon: const Icon(Icons.arrow_upward), tooltip: 'بالا'),
                  IconButton(onPressed: down, icon: const Icon(Icons.arrow_downward), tooltip: 'پایین'),
                  if (delete != null)
                    IconButton(onPressed: delete, icon: const Icon(Icons.delete_outline), tooltip: 'حذف'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget cashAdmin() {
    final list = currencies.where((c) => c.cash).toList()..sort((a, b) => a.cashOrder.compareTo(b.cashOrder));
    if (!list.any((c) => c.code == lastCash) && list.isNotEmpty) lastCash = list.first.code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title('ثبت نرخ نقدی', 'انتخاب‌های آخر حفظ می‌شوند و نرخ جدید جای نرخ قبلی را می‌گیرد.'),
        DropdownButtonFormField<String>(
          value: lastCash,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'ارز'),
          items: list
              .map((c) => DropdownMenuItem(value: c.code, child: Text('${c.flag}  ${c.title}  (${c.code})', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => lastCash = v ?? lastCash),
        ),
        const SizedBox(height: 10),
        audience(lastCashAud, (v) => setState(() => lastCashAud = v)),
        const SizedBox(height: 10),
        numfield(buy, 'خرید'),
        const SizedBox(height: 10),
        numfield(sell, 'فروش'),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            final b = double.tryParse(buy.text), s = double.tryParse(sell.text);
            if (b != null && s != null) {
              upsert('cash', lastCash, lastCashAud, b, s);
              setState(() {});
            }
          },
          child: const Text('ثبت'),
        ),
        const SizedBox(height: 22),
        ...list.map((c) {
          final r = findRate('cash', c.code, Audience.retail);
          return _reorderCard(
            heading: '${c.flag}  ${c.title}  (${c.code})',
            subtitle: 'مشتری: ${r == null ? '—' : '${fmt(r.buy)} / ${fmt(r.sell)}'}',
            up: () => moveCurrency(c, true, -1),
            down: () => moveCurrency(c, true, 1),
          );
        }),
      ],
    );
  }

  Widget remitAdmin() {
    final cs = currencies.where((c) => c.remittance).toList()..sort((a, b) => a.remitOrder.compareTo(b.remitOrder));
    if (cs.isNotEmpty) {
      ensureMethod(cs.first.code);
      final valid = methods.any((m) => m.id == lastMethod && cs.any((c) => c.code == m.currency));
      if (!valid) lastMethod = methods.firstWhere((m) => cs.any((c) => c.code == m.currency)).id;
    }
    final availableMethods = methods.where((m) => cs.any((c) => c.code == m.currency)).toList()
      ..sort((a, b) {
        final ca = cs.indexWhere((c) => c.code == a.currency);
        final cb = cs.indexWhere((c) => c.code == b.currency);
        return ca == cb ? a.order.compareTo(b.order) : ca.compareTo(cb);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title('ثبت نرخ حواله', 'روش حواله را انتخاب کن؛ نرخ جدید جای نرخ قبلی همان روش می‌نشیند.'),
        DropdownButtonFormField<int>(
          value: availableMethods.any((m) => m.id == lastMethod) ? lastMethod : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'روش حواله'),
          items: availableMethods
              .map((m) => DropdownMenuItem(value: m.id, child: Text('${m.flag} ${m.country} — ${m.title}', overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => lastMethod = v ?? lastMethod),
        ),
        const SizedBox(height: 10),
        audience(lastRemitAud, (v) => setState(() => lastRemitAud = v)),
        const SizedBox(height: 10),
        numfield(rBuy, 'خرید'),
        const SizedBox(height: 10),
        numfield(rSell, 'فروش'),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            final b = double.tryParse(rBuy.text), s = double.tryParse(rSell.text);
            if (b != null && s != null) {
              upsert('remittance', '$lastMethod', lastRemitAud, b, s);
              setState(() {});
            }
          },
          child: const Text('ثبت نرخ حواله'),
        ),
        const SizedBox(height: 22),
        const Text('ترتیب دسته‌های اصلی', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 10),
        ...cs.map((c) {
          final names = (methods.where((m) => m.currency == c.code).toList()..sort((a, b) => a.order.compareTo(b.order)))
              .map((m) => m.title)
              .join('، ');
          return _reorderCard(
            heading: '${c.flag}  ${c.country}  (${c.code})',
            subtitle: names,
            up: () => moveCurrency(c, false, -1),
            down: () => moveCurrency(c, false, 1),
          );
        }),
      ],
    );
  }

  Widget regAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title('تبدیل منطقه‌ای', 'نرخ را به‌صورت بسته‌ای ثبت کن؛ مقصد دبی برای USD معادل درهم را هم نشان می‌دهد.'),
        DropdownButtonFormField<String>(
          value: lastRegionalCur,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'ارز'),
          items: ['USD', 'EUR', 'AED'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => lastRegionalCur = v ?? lastRegionalCur),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: lastFrom,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'مبدأ'),
          items: ['تهران', 'دبی', 'ترکیه', 'سلیمانیه', 'هرات', 'تتر'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => lastFrom = v ?? lastFrom),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: lastTo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'مقصد'),
          items: ['تهران', 'دبی', 'ترکیه', 'سلیمانیه', 'هرات', 'تتر'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => lastTo = v ?? lastTo),
        ),
        const SizedBox(height: 10),
        audience(lastRegAud, (v) => setState(() => lastRegAud = v)),
        const SizedBox(height: 10),
        numfield(base, 'بسته مبدأ'),
        const SizedBox(height: 10),
        numfield(dest, 'مبلغ مقصد'),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            final b = double.tryParse(base.text), d = double.tryParse(dest.text);
            if (b == null || d == null || lastFrom == lastTo) return;
            final found = regional.where((r) =>
                r.from == lastFrom &&
                r.to == lastTo &&
                r.currency == lastRegionalCur &&
                r.audience == lastRegAud).toList();
            if (found.isNotEmpty) {
              found.first.base = b;
              found.first.dest = d;
            } else {
              regional.add(RegionalRate(lastFrom, lastTo, lastRegionalCur, lastRegAud, b, d));
            }
            setState(() {});
            _saveRemoteState();
          },
          child: const Text('ثبت بسته‌ای'),
        ),
      ],
    );
  }

  Widget methodsAdmin() {
    final cs = currencies.where((c) => c.remittance).toList()..sort((a, b) => a.remitOrder.compareTo(b.remitOrder));
    String selected = cs.isEmpty ? '' : cs.first.code;
    return StatefulBuilder(
      builder: (context, local) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title('روش‌های حواله', 'نام روش را وارد کن؛ ترتیب روش‌ها را با دکمه‌های بالا و پایین تغییر بده.'),
          DropdownButtonFormField<String>(
            value: selected.isEmpty ? null : selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'ارز / مقصد'),
            items: cs
                .map((c) => DropdownMenuItem(value: c.code, child: Text('${c.flag} ${c.country} / ${c.code}', overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => local(() => selected = v ?? selected),
          ),
          const SizedBox(height: 10),
          TextField(controller: methodCtl, decoration: const InputDecoration(labelText: 'نام روش')),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              if (selected.isEmpty || methodCtl.text.trim().isEmpty) return;
              final c = currencies.firstWhere((x) => x.code == selected);
              final group = methods.where((m) => m.currency == selected).toList();
              final o = group.isEmpty ? 1 : group.map((m) => m.order).reduce((a, b) => a > b ? a : b) + 1;
              final id = methods.isEmpty ? 1 : methods.map((m) => m.id).reduce((a, b) => a > b ? a : b) + 1;
              methods.add(MethodDef(id, c.country, c.flag, c.code, methodCtl.text.trim(), o));
              methodCtl.clear();
              setState(() {});
              _saveRemoteState();
            },
            child: const Text('اضافه کردن'),
          ),
          const SizedBox(height: 18),
          ...methods.where((m) => cs.any((c) => c.code == m.currency)).map(
                (m) => _reorderCard(
                  heading: '${m.flag}  ${m.country} / ${m.currency}',
                  subtitle: '${m.order}. ${m.title}',
                  up: () => moveMethod(m, -1),
                  down: () => moveMethod(m, 1),
                  delete: () { setState(() => methods.remove(m)); _saveRemoteState(); },
                ),
              ),
        ],
      ),
    );
  }

  Widget currenciesAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title('مدیریت ارزها', 'کد ارز را وارد کن؛ نام و پرچم به‌صورت خودکار پیشنهاد می‌شود.'),
        TextField(
          controller: codeCtl,
          textCapitalization: TextCapitalization.characters,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'کد ارز، مثلاً CHF'),
          onChanged: (v) {
            final d = catalog[v.trim().toUpperCase()];
            if (d != null) {
              titleCtl.text = d[0];
              setState(() {});
            }
          },
        ),
        const SizedBox(height: 10),
        TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'نام ارز')),
        const SizedBox(height: 10),
        Builder(builder: (context) {
          final d = catalog[codeCtl.text.trim().toUpperCase()];
          return Text('پرچم پیشنهادی: ${d == null ? '🏳️' : d[1]}');
        }),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: () {
            final code = codeCtl.text.trim().toUpperCase();
            final d = catalog[code];
            final currencyTitle = titleCtl.text.trim();
            if (code.isEmpty || currencyTitle.isEmpty || currencies.any((c) => c.code == code)) return;
            currencies.add(CurrencyDef(
              code,
              currencyTitle,
              d?[1] ?? '🏳️',
              d?[2] ?? currencyTitle,
              cash: true,
              remittance: true,
              cashOrder: currencies.where((c) => c.cash).length + 1,
              remitOrder: currencies.where((c) => c.remittance).length + 1,
            ));
            ensureMethod(code);
            codeCtl.clear();
            titleCtl.clear();
            setState(() {});
            _saveRemoteState();
          },
          child: const Text('اضافه کردن ارز'),
        ),
        const SizedBox(height: 18),
        ...currencies.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${c.flag}  ${c.title}  (${c.code})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('نقدی: ${c.cash ? 'فعال' : 'خاموش'}  •  حواله: ${c.remittance ? 'فعال' : 'خاموش'}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TextButton(
                          onPressed: () {
                            c.cash = !c.cash;
                            normalize(true);
                            setState(() {});
                            _saveRemoteState();
                          },
                          child: Text(c.cash ? 'حذف از نقدی' : 'افزودن به نقدی'),
                        ),
                        TextButton(
                          onPressed: () {
                            c.remittance = !c.remittance;
                            if (c.remittance) ensureMethod(c.code);
                            normalize(false);
                            setState(() {});
                            _saveRemoteState();
                          },
                          child: Text(c.remittance ? 'حذف از حواله' : 'افزودن به حواله'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget partnerAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title('کد همکار', 'کد تست فعلی: $partnerCode'),
        TextField(
          onChanged: (v) => partnerCode = v,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: InputDecoration(labelText: 'کد جدید', hintText: partnerCode),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _saveRemoteState,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('ذخیره کد روی سرور'),
        ),
      ],
    );
  }

  Widget settingsView() {
    const colors = <Color>[
      Color(0xFF4F67A8),
      Color(0xFF1565C0),
      Color(0xFF00897B),
      Color(0xFF6D4C41),
      Color(0xFF7B1FA2),
      Color(0xFFC62828),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title('ظاهر و تنظیمات', 'حالت نمایش و رنگ اصلی برنامه را انتخاب کن. تغییرات همان لحظه روی اپ و پنل اعمال می‌شوند.'),
        const Text('حالت برنامه', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('سیستم'), icon: Icon(Icons.phone_android)),
            ButtonSegment(value: ThemeMode.light, label: Text('روشن'), icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: ThemeMode.dark, label: Text('تیره'), icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {widget.themeMode},
          onSelectionChanged: (v) => widget.onThemeModeChanged(v.first),
        ),
        const SizedBox(height: 24),
        const Text('رنگ اصلی', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final selected = color.value == widget.seedColor.value;
            return InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => widget.onSeedColorChanged(color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: selected ? const Icon(Icons.check, color: Colors.white) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('تنظیمات ظاهر روی دستگاه ذخیره می‌شود و پس از باز کردن دوباره برنامه حفظ خواهد شد.'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: settingsView(),
          ),
        ),
      ),
    );
  }

  Widget appView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  partnerMode ? 'حالت همکار' : 'نرخ مشتری',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              TextButton(
                onPressed: _partnerDialog,
                child: const Text('ورود همکار'),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: _marketTabs()),
        Expanded(
          child: switch (market) {
            MarketTab.cash => cashApp(),
            MarketTab.remittance => remitApp(),
            MarketTab.regional => regApp(),
          },
        ),
      ],
    );
  }

  void _partnerDialog() {
    final ctl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ورود همکار'),
          content: TextField(
            controller: ctl,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'کد همکار'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => partnerMode = false);
                _loadRemoteState();
                Navigator.pop(dialogContext);
              },
              child: const Text('مشتری'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final token = await api.partnerLogin(ctl.text);
                  await _loadRemoteState(token: token);
                  if (!mounted) return;
                  setState(() => partnerMode = true);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('کد همکار صحیح نیست.')));
                  }
                }
              },
              child: const Text('ورود'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marketTabs() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _marketTab(MarketTab.cash, 'نقدی'),
          _marketTab(MarketTab.remittance, 'حواله'),
          _marketTab(MarketTab.regional, 'تبدیل منطقه‌ای'),
        ],
      ),
    );
  }

  Widget _marketTab(MarketTab value, String label) {
    final selected = market == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => market = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.secondaryContainer : Colors.transparent,
            border: BorderDirectional(
              start: value == MarketTab.cash
                  ? BorderSide.none
                  : BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.onSecondaryContainer),
                  const SizedBox(width: 4),
                ],
                Text(label, maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget cashApp() {
    final list = currencies.where((c) => c.cash).toList()..sort((a, b) => a.cashOrder.compareTo(b.cashOrder));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: list.map((c) {
        final r = findRate('cash', c.code, appAudience);
        if (r == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${c.title} (${c.code})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: Text('خرید  ${fmt(r.buy)}', style: const TextStyle(fontSize: 16))),
                      Expanded(child: Text('فروش  ${fmt(r.sell)}', style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget remitApp() {
    final cs = currencies.where((c) => c.remittance).toList()..sort((a, b) => a.remitOrder.compareTo(b.remitOrder));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: cs.map((c) {
        ensureMethod(c.code);
        final ms = methods.where((m) => m.currency == c.code).toList()..sort((a, b) => a.order.compareTo(b.order));
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${c.country} (${c.code})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...ms.map((m) => _remittanceRateRow(m)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _remittanceRateRow(MethodDef m) {
    final r = findRate('remittance', '${m.id}', appAudience);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        if (compact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(child: Text('خرید  ${r == null ? '—' : fmt(r.buy)}')),
                    Expanded(child: Text('فروش  ${r == null ? '—' : fmt(r.sell)}')),
                  ],
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Expanded(child: Text(m.title)),
              Text('خرید ${r == null ? '—' : fmt(r.buy)}'),
              const SizedBox(width: 14),
              Text('فروش ${r == null ? '—' : fmt(r.sell)}'),
            ],
          ),
        );
      },
    );
  }

  Widget regApp() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: regional.where((r) => r.audience == appAudience).map((r) {
        final d = r.dest - r.base;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${r.from} ← ${r.to}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 10),
                  Text('${r.from}: ${fmt(r.base)} ${r.currency}'),
                  Text('${r.to}: ${fmt(r.dest)} ${r.currency}'),
                  if (r.aed != null)
                    Text(
                      'معادل درهم: ${fmt(r.aed!)} AED',
                      style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.w800),
                    ),
                  Text(
                    '${d > 0 ? '+' : ''}${fmt(d)} ${r.currency}',
                    style: TextStyle(
                      color: d >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
