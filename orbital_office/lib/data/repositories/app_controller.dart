import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/invoice_calculator.dart';
import '../../core/services/local_database.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/sync_service.dart';
import '../models/models.dart';
import 'template_catalog.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

class AppState {
  const AppState({
    this.booted = false,
    this.user,
    this.isDemo = false,
    this.documents = const [],
    this.spreadsheets = const [],
    this.presentations = const [],
    this.invoices = const [],
    this.quotations = const [],
    this.customers = const [],
    this.products = const [],
    this.movements = const [],
    this.projects = const [],
    this.tasks = const [],
    this.files = const [],
    this.folders = const [],
    this.notifications = const [],
    this.chat = const [],
    this.favoriteTemplates = const {},
    this.recentTemplates = const [],
    this.themeMode = ThemeMode.system,
    this.dashboardOrder = const ['documents', 'spreadsheets', 'projects', 'tasks'],
  });

  final bool booted;
  final UserProfile? user;
  final bool isDemo;
  final List<OrbitalDocument> documents;
  final List<SpreadsheetDoc> spreadsheets;
  final List<PresentationDoc> presentations;
  final List<InvoiceDoc> invoices;
  final List<InvoiceDoc> quotations;
  final List<Customer> customers;
  final List<Product> products;
  final List<InventoryMovement> movements;
  final List<Project> projects;
  final List<TaskItem> tasks;
  final List<OfficeFile> files;
  final List<FolderItem> folders;
  final List<AppNotification> notifications;
  final List<ChatMessage> chat;
  final Set<String> favoriteTemplates;
  final List<String> recentTemplates;
  final ThemeMode themeMode;
  final List<String> dashboardOrder;

  bool get isSignedIn => user != null;
  int get unreadNotifications => notifications.where((n) => !n.read).length;
  List<Product> get lowStockProducts => products.where((p) => p.isLowStock).toList();
  List<TaskItem> get pendingTasks =>
      tasks.where((t) => t.status != TaskStatus.completed).toList();

  double get revenueCollected =>
      invoices.fold(0, (sum, i) => sum + i.totals.amountPaid);
  double get revenueOutstanding =>
      invoices.fold(0, (sum, i) => sum + (i.totals.balanceDue > 0 ? i.totals.balanceDue : 0));

  AppState copyWith({
    bool? booted,
    UserProfile? user,
    bool clearUser = false,
    bool? isDemo,
    List<OrbitalDocument>? documents,
    List<SpreadsheetDoc>? spreadsheets,
    List<PresentationDoc>? presentations,
    List<InvoiceDoc>? invoices,
    List<InvoiceDoc>? quotations,
    List<Customer>? customers,
    List<Product>? products,
    List<InventoryMovement>? movements,
    List<Project>? projects,
    List<TaskItem>? tasks,
    List<OfficeFile>? files,
    List<FolderItem>? folders,
    List<AppNotification>? notifications,
    List<ChatMessage>? chat,
    Set<String>? favoriteTemplates,
    List<String>? recentTemplates,
    ThemeMode? themeMode,
    List<String>? dashboardOrder,
  }) {
    return AppState(
      booted: booted ?? this.booted,
      user: clearUser ? null : (user ?? this.user),
      isDemo: isDemo ?? this.isDemo,
      documents: documents ?? this.documents,
      spreadsheets: spreadsheets ?? this.spreadsheets,
      presentations: presentations ?? this.presentations,
      invoices: invoices ?? this.invoices,
      quotations: quotations ?? this.quotations,
      customers: customers ?? this.customers,
      products: products ?? this.products,
      movements: movements ?? this.movements,
      projects: projects ?? this.projects,
      tasks: tasks ?? this.tasks,
      files: files ?? this.files,
      folders: folders ?? this.folders,
      notifications: notifications ?? this.notifications,
      chat: chat ?? this.chat,
      favoriteTemplates: favoriteTemplates ?? this.favoriteTemplates,
      recentTemplates: recentTemplates ?? this.recentTemplates,
      themeMode: themeMode ?? this.themeMode,
      dashboardOrder: dashboardOrder ?? this.dashboardOrder,
    );
  }
}

/// Single source of truth for the app.
///
/// Persistence strategy: every mutation is written to the on-device SQLite
/// store (offline-first) and marked `pending`; SyncService pushes pending
/// records to Supabase when a backend is configured. Demo mode seeds
/// clearly-labelled fictional sample data.
class AppController extends StateNotifier<AppState> {
  AppController() : super(const AppState());

  final _db = LocalDatabase.instance;

  // ------------------------------------------------------------- bootstrap
  Future<void> bootstrap() async {
    await SupabaseService.instance.init();

    final themeRaw = await _db.getPreference('theme_mode');
    final theme = switch (themeRaw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final userRaw = await _db.getPreference('session_user');
    UserProfile? user;
    var isDemo = false;
    if (userRaw != null) {
      try {
        user = UserProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(userRaw) as Map));
        isDemo = user.isGuest;
      } catch (_) {}
    }
    if (user == null && SupabaseService.instance.isSignedIn) {
      final su = SupabaseService.instance.currentUser!;
      user = UserProfile(
        id: su.id,
        name: (su.userMetadata?['full_name'] ?? 'Orbital User').toString(),
        email: su.email ?? '',
      );
    }

    Future<List<T>> load<T>(
        String type, T Function(Map<String, dynamic>) fromJson) async {
      final rows = await _db.loadCollection(type);
      return rows.map(fromJson).toList();
    }

    var documents = await load('documents', OrbitalDocument.fromJson);
    var spreadsheets = await load('spreadsheets', SpreadsheetDoc.fromJson);
    var presentations = await load('presentations', PresentationDoc.fromJson);
    var invoicesRaw = await load('invoices', InvoiceDoc.fromJson);
    final storedQuotations = await load('quotations', InvoiceDoc.fromJson);
    invoicesRaw = [...invoicesRaw, ...storedQuotations];
    var folders = await load('folders', FolderItem.fromJson);
    var customers = await load('customers', Customer.fromJson);
    var products = await load('products', Product.fromJson);
    var movements = await load('movements', InventoryMovement.fromJson);
    var projects = await load('projects', Project.fromJson);
    var tasks = await load('tasks', TaskItem.fromJson);
    var files = await load('files', OfficeFile.fromJson);
    var notifications = await load('notifications', AppNotification.fromJson);

    Set<String> favoriteTemplates = {};
    List<String> recentTemplates = [];
    List<String> dashboardOrder = state.dashboardOrder;
    try {
      final favRaw = await _db.getPreference('favorite_templates');
      if (favRaw != null && favRaw.isNotEmpty) {
        favoriteTemplates =
            (jsonDecode(favRaw) as List).map((e) => e.toString()).toSet();
      }
      final recentRaw = await _db.getPreference('recent_templates');
      if (recentRaw != null && recentRaw.isNotEmpty) {
        recentTemplates =
            (jsonDecode(recentRaw) as List).map((e) => e.toString()).toList();
      }
      final orderRaw = await _db.getPreference('dashboard_order');
      if (orderRaw != null && orderRaw.isNotEmpty) {
        dashboardOrder =
            (jsonDecode(orderRaw) as List).map((e) => e.toString()).toList();
      }
    } catch (_) {}

    final hasAny = documents.isNotEmpty ||
        spreadsheets.isNotEmpty ||
        customers.isNotEmpty ||
        products.isNotEmpty;
    if (!hasAny) {
      final seed = _seedDemo(DateTime.now());
      documents = seed.documents;
      spreadsheets = seed.spreadsheets;
      presentations = seed.presentations;
      invoicesRaw = [...seed.invoices, ...seed.quotations];
      customers = seed.customers;
      products = seed.products;
      movements = seed.movements;
      projects = seed.projects;
      tasks = seed.tasks;
      notifications = seed.notifications;
      files = _deriveFiles(documents, spreadsheets, presentations, invoicesRaw);
      for (final d in documents) { _persist('documents', d.id, d.toJson()); }
      for (final s in spreadsheets) { _persist('spreadsheets', s.id, s.toJson()); }
      for (final p in presentations) { _persist('presentations', p.id, p.toJson()); }
      for (final i in invoicesRaw) {
        _persist(i.kind == BillingKind.invoice ? 'invoices' : 'quotations', i.id, i.toJson());
      }
      for (final c in customers) { _persist('customers', c.id, c.toJson()); }
      for (final p in products) { _persist('products', p.id, p.toJson()); }
      for (final pr in projects) { _persist('projects', pr.id, pr.toJson()); }
      for (final t in tasks) { _persist('tasks', t.id, t.toJson()); }
    } else {
      files = _deriveFiles(documents, spreadsheets, presentations, invoicesRaw);
    }

    int byUpdated(DateTime a, DateTime b) => b.compareTo(a);
    documents.sort((a, b) => byUpdated(a.updatedAt, b.updatedAt));
    spreadsheets.sort((a, b) => byUpdated(a.updatedAt, b.updatedAt));
    presentations.sort((a, b) => byUpdated(a.updatedAt, b.updatedAt));

    state = state.copyWith(
      booted: true,
      user: user,
      isDemo: isDemo,
      documents: documents,
      spreadsheets: spreadsheets,
      presentations: presentations,
      invoices: invoicesRaw.where((i) => i.kind == BillingKind.invoice).toList(),
      quotations: invoicesRaw.where((i) => i.kind == BillingKind.quotation).toList(),
      customers: customers,
      products: products,
      movements: movements,
      projects: projects,
      tasks: tasks,
      files: files,
      notifications: notifications,
      folders: folders,
      favoriteTemplates: favoriteTemplates,
      recentTemplates: recentTemplates,
      dashboardOrder: dashboardOrder,
      themeMode: theme,
    );
    // Fire-and-forget background sync attempt.
    SyncService.instance.syncNow();
  }

  List<OfficeFile> _deriveFiles(
    List<OrbitalDocument> docs,
    List<SpreadsheetDoc> sheets,
    List<PresentationDoc> decks,
    List<InvoiceDoc> bills,
  ) {
    return [
      for (final d in docs)
        OfficeFile(id: 'file-${d.id}', name: '${d.title}.docx', kind: OfficeFileKind.document, updatedAt: d.updatedAt, favorite: d.favorite, linkedId: d.id, sizeBytes: 12000 + d.wordCount * 6),
      for (final s in sheets)
        OfficeFile(id: 'file-${s.id}', name: '${s.title}.xlsx', kind: OfficeFileKind.spreadsheet, updatedAt: s.updatedAt, favorite: s.favorite, linkedId: s.id, sizeBytes: 8000 + s.cells.length * 24),
      for (final p in decks)
        OfficeFile(id: 'file-${p.id}', name: '${p.title}.pptx', kind: OfficeFileKind.presentation, updatedAt: p.updatedAt, favorite: p.favorite, linkedId: p.id, sizeBytes: 24000 + p.slides.length * 9000),
      for (final i in bills)
        OfficeFile(id: 'file-${i.id}', name: '${i.number}.pdf', kind: i.kind == BillingKind.invoice ? OfficeFileKind.invoice : OfficeFileKind.quotation, updatedAt: i.updatedAt, linkedId: i.id, sizeBytes: 15000),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void _refreshFiles() {
    state = state.copyWith(
      files: _deriveFiles(state.documents, state.spreadsheets,
          state.presentations, [...state.invoices, ...state.quotations]),
    );
  }

  void _persist(String type, String id, Map<String, dynamic> json) {
    _db.upsert(type, id, json);
  }

  void _notify(String title, String body, {String? route}) {
    final n = AppNotification(
      id: newId(),
      title: title,
      body: body,
      at: DateTime.now(),
      route: route,
    );
    state = state.copyWith(notifications: [n, ...state.notifications]);
    _persist('notifications', n.id, n.toJson());
  }

  // ------------------------------------------------------------------ auth
  Future<String?> signInDemo() async {
    final user = UserProfile(
      id: 'demo-user',
      name: 'Demo User',
      email: 'demo@orbital.studio',
      businessName: 'ORBITAL.STUDIO.3 (Demo)',
      isGuest: true,
    );
    await _db.setPreference('session_user', jsonEncode(user.toJson()));
    state = state.copyWith(user: user, isDemo: true);
    return null;
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (SupabaseService.instance.isReady) {
      final err = await SupabaseService.instance
          .signUp(email: email, password: password, name: name);
      if (err != null) return err;
      final su = SupabaseService.instance.currentUser;
      final user = UserProfile(
        id: su?.id ?? newId(),
        name: name,
        email: email,
      );
      await _db.setPreference('session_user', jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isDemo: false);
      return null;
    }
    // Local-only account (honest offline behaviour, no fake server).
    final user = UserProfile(id: newId(), name: name, email: email);
    await _db.setPreference('session_user', jsonEncode(user.toJson()));
    await _db.setPreference('local_account_email', email);
    state = state.copyWith(user: user, isDemo: false);
    return null;
  }

  Future<String?> signIn({required String email, required String password}) async {
    if (SupabaseService.instance.isReady) {
      final err =
          await SupabaseService.instance.signIn(email: email, password: password);
      if (err != null) return err;
      final su = SupabaseService.instance.currentUser;
      final user = UserProfile(
        id: su?.id ?? newId(),
        name: (su?.userMetadata?['full_name'] ?? 'Orbital User').toString(),
        email: email,
      );
      await _db.setPreference('session_user', jsonEncode(user.toJson()));
      state = state.copyWith(user: user, isDemo: false);
      return null;
    }
    final saved = await _db.getPreference('local_account_email');
    if (saved != null && saved.toLowerCase() == email.trim().toLowerCase()) {
      final raw = await _db.getPreference('session_user');
      if (raw != null) {
        final user = UserProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
        state = state.copyWith(user: user, isDemo: false);
        return null;
      }
    }
    return 'No local account found for this email. Register first, or continue in demo mode.';
  }

  Future<String?> resetPassword(String email) =>
      SupabaseService.instance.resetPassword(email);

  Future<void> signOut() async {
    await SupabaseService.instance.signOut();
    await _db.setPreference('session_user', '');
    state = state.copyWith(clearUser: true, isDemo: false);
  }

  Future<String?> deleteAccount() async {
    final err = await SupabaseService.instance.deleteAccount();
    if (err != null) return err;
    await _db.setPreference('session_user', '');
    await _db.setPreference('local_account_email', '');
    state = state.copyWith(clearUser: true, isDemo: false);
    return null;
  }

  void updateProfile({String? name, String? businessName, String? phone}) {
    final u = state.user;
    if (u == null) return;
    final updated =
        u.copyWith(name: name, businessName: businessName, phone: phone);
    state = state.copyWith(user: updated);
    _db.setPreference('session_user', jsonEncode(updated.toJson()));
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _db.setPreference('theme_mode', mode.name);
  }

  // -------------------------------------------------------------- documents
  OrbitalDocument createDocument({String title = 'Untitled Document', List<DocBlock>? blocks}) {
    final now = DateTime.now();
    final doc = OrbitalDocument(
      id: newId(),
      title: title,
      blocks: blocks ??
          [DocBlock(type: DocBlockType.heading, text: title), DocBlock(type: DocBlockType.paragraph, text: '')],
      createdAt: now,
      updatedAt: now,
    );
    state = state.copyWith(documents: [doc, ...state.documents]);
    _persist('documents', doc.id, doc.toJson());
    _refreshFiles();
    return doc;
  }

  OrbitalDocument? documentById(String id) {
    for (final d in state.documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  void saveDocument(OrbitalDocument doc) {
    doc.updatedAt = DateTime.now();
    state = state.copyWith(
      documents: [for (final d in state.documents) if (d.id == doc.id) doc else d]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
    _persist('documents', doc.id, doc.toJson());
    _refreshFiles();
  }

  OrbitalDocument duplicateDocument(OrbitalDocument doc) {
    final now = DateTime.now();
    final copy = OrbitalDocument(
      id: newId(),
      title: '${doc.title} (Copy)',
      blocks: doc.blocks
          .map((b) => DocBlock(type: b.type, text: b.text, table: b.table.map((r) => List<String>.of(r)).toList()))
          .toList(),
      createdAt: now,
      updatedAt: now,
      favorite: doc.favorite,
    );
    state = state.copyWith(documents: [copy, ...state.documents]);
    _persist('documents', copy.id, copy.toJson());
    _refreshFiles();
    return copy;
  }

  void deleteDocument(String id) {
    state = state.copyWith(
        documents: state.documents.where((d) => d.id != id).toList());
    _db.delete('documents', id);
    _refreshFiles();
  }

  void toggleDocumentFavorite(String id) {
    final doc = documentById(id);
    if (doc == null) return;
    doc.favorite = !doc.favorite;
    saveDocument(doc);
  }

  // ------------------------------------------------------------ spreadsheets
  SpreadsheetDoc createSpreadsheet({String title = 'Untitled Spreadsheet', Map<String, String>? cells}) {
    final now = DateTime.now();
    final sheet = SpreadsheetDoc(
      id: newId(), title: title, cells: cells ?? {}, createdAt: now, updatedAt: now);
    state = state.copyWith(spreadsheets: [sheet, ...state.spreadsheets]);
    _persist('spreadsheets', sheet.id, sheet.toJson());
    _refreshFiles();
    return sheet;
  }

  SpreadsheetDoc? spreadsheetById(String id) {
    for (final s in state.spreadsheets) {
      if (s.id == id) return s;
    }
    return null;
  }

  void saveSpreadsheet(SpreadsheetDoc sheet) {
    sheet.updatedAt = DateTime.now();
    state = state.copyWith(spreadsheets: [
      for (final s in state.spreadsheets) if (s.id == sheet.id) sheet else s
    ]);
    _persist('spreadsheets', sheet.id, sheet.toJson());
    _refreshFiles();
  }

  void deleteSpreadsheet(String id) {
    state = state.copyWith(
        spreadsheets: state.spreadsheets.where((s) => s.id != id).toList());
    _db.delete('spreadsheets', id);
    _refreshFiles();
  }

  // ------------------------------------------------------------ presentations
  PresentationDoc createPresentation({String title = 'Untitled Presentation', List<Slide>? slides}) {
    final now = DateTime.now();
    final deck = PresentationDoc(
      id: newId(),
      title: title,
      slides: slides ?? [Slide(id: newId(), title: title, body: 'Tap to edit this slide')],
      createdAt: now,
      updatedAt: now,
    );
    state = state.copyWith(presentations: [deck, ...state.presentations]);
    _persist('presentations', deck.id, deck.toJson());
    _refreshFiles();
    return deck;
  }

  PresentationDoc? presentationById(String id) {
    for (final p in state.presentations) {
      if (p.id == id) return p;
    }
    return null;
  }

  void savePresentation(PresentationDoc deck) {
    deck.updatedAt = DateTime.now();
    state = state.copyWith(presentations: [
      for (final p in state.presentations) if (p.id == deck.id) deck else p
    ]);
    _persist('presentations', deck.id, deck.toJson());
    _refreshFiles();
  }

  void deletePresentation(String id) {
    state = state.copyWith(
        presentations: state.presentations.where((p) => p.id != id).toList());
    _db.delete('presentations', id);
    _refreshFiles();
  }

  // ---------------------------------------------------------------- billing
  String _nextNumber(BillingKind kind) {
    final list = kind == BillingKind.invoice ? state.invoices : state.quotations;
    final prefix = kind == BillingKind.invoice ? 'INV' : 'QUO';
    return '$prefix-${(1001 + list.length).toString()}';
  }

  InvoiceDoc createBilling(BillingKind kind) {
    final now = DateTime.now();
    final doc = InvoiceDoc(
      id: newId(),
      kind: kind,
      number: _nextNumber(kind),
      items: [InvoiceItem(description: 'Service', quantity: 1, unitPrice: 0)],
      businessName: state.user?.businessName ?? '',
      createdAt: now,
      updatedAt: now,
    );
    if (kind == BillingKind.invoice) {
      state = state.copyWith(invoices: [doc, ...state.invoices]);
    } else {
      state = state.copyWith(quotations: [doc, ...state.quotations]);
    }
    _persist(kind == BillingKind.invoice ? 'invoices' : 'quotations', doc.id, doc.toJson());
    _refreshFiles();
    return doc;
  }

  InvoiceDoc? billingById(String id) {
    for (final i in [...state.invoices, ...state.quotations]) {
      if (i.id == id) return i;
    }
    return null;
  }

  void saveBilling(InvoiceDoc doc) {
    doc.updatedAt = DateTime.now();
    if (doc.kind == BillingKind.invoice) {
      state = state.copyWith(invoices: [
        for (final i in state.invoices) if (i.id == doc.id) doc else i
      ]);
      _persist('invoices', doc.id, doc.toJson());
    } else {
      state = state.copyWith(quotations: [
        for (final i in state.quotations) if (i.id == doc.id) doc else i
      ]);
      _persist('quotations', doc.id, doc.toJson());
    }
    _refreshFiles();
  }

  void deleteBilling(InvoiceDoc doc) {
    if (doc.kind == BillingKind.invoice) {
      state = state.copyWith(
          invoices: state.invoices.where((i) => i.id != doc.id).toList());
      _db.delete('invoices', doc.id);
    } else {
      state = state.copyWith(
          quotations: state.quotations.where((i) => i.id != doc.id).toList());
      _db.delete('quotations', doc.id);
    }
    _refreshFiles();
  }

  InvoiceDoc convertQuotationToInvoice(InvoiceDoc q) {
    final inv = createBilling(BillingKind.invoice);
    inv.customerId = q.customerId;
    inv.customerName = q.customerName;
    inv.customerAddress = q.customerAddress;
    inv.businessName = q.businessName;
    inv.businessAddress = q.businessAddress;
    inv.items = q.items
        .map((i) => InvoiceItem(description: i.description, quantity: i.quantity, unitPrice: i.unitPrice, discountPercent: i.discountPercent))
        .toList();
    inv.discountPercent = q.discountPercent;
    inv.taxPercent = q.taxPercent;
    inv.taxLabel = q.taxLabel;
    saveBilling(inv);
    _notify('Quotation converted', '${q.number} is now invoice ${inv.number}.', route: '/invoices');
    return inv;
  }

  // -------------------------------------------------------------------- CRM
  Customer createCustomer(String name) {
    final now = DateTime.now();
    final c = Customer(id: newId(), name: name, createdAt: now, updatedAt: now);
    state = state.copyWith(customers: [c, ...state.customers]);
    _persist('customers', c.id, c.toJson());
    return c;
  }

  Customer? customerById(String id) {
    for (final c in state.customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  void saveCustomer(Customer c) {
    c.updatedAt = DateTime.now();
    state = state.copyWith(customers: [
      for (final x in state.customers) if (x.id == c.id) c else x
    ]);
    _persist('customers', c.id, c.toJson());
  }

  void deleteCustomer(String id) {
    state = state.copyWith(
        customers: state.customers.where((c) => c.id != id).toList());
    _db.delete('customers', id);
  }

  // --------------------------------------------------------------- inventory
  Product createProduct(String name) {
    final now = DateTime.now();
    final p = Product(
        id: newId(), name: name, createdAt: now, updatedAt: now, sku: 'SKU-${1000 + state.products.length}');
    state = state.copyWith(products: [p, ...state.products]);
    _persist('products', p.id, p.toJson());
    return p;
  }

  Product? productById(String id) {
    for (final p in state.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void saveProduct(Product p, {int? stockChange, String reason = 'Manual adjustment'}) {
    p.updatedAt = DateTime.now();
    if (stockChange != null && stockChange != 0) {
      p.stock += stockChange;
      final m = InventoryMovement(
          id: newId(), productId: p.id, change: stockChange, reason: reason, at: DateTime.now());
      state = state.copyWith(movements: [m, ...state.movements]);
      _persist('movements', m.id, m.toJson());
      if (p.isLowStock) {
        _notify('Low stock alert', '${p.name} has only ${p.stock} unit(s) left.', route: '/business/inventory');
      }
    }
    state = state.copyWith(products: [
      for (final x in state.products) if (x.id == p.id) p else x
    ]);
    _persist('products', p.id, p.toJson());
  }

  void deleteProduct(String id) {
    state = state.copyWith(
        products: state.products.where((p) => p.id != id).toList());
    _db.delete('products', id);
  }

  // ---------------------------------------------------------- projects/tasks
  Project createProject(String title) {
    final now = DateTime.now();
    final p = Project(id: newId(), title: title, createdAt: now, updatedAt: now);
    state = state.copyWith(projects: [p, ...state.projects]);
    _persist('projects', p.id, p.toJson());
    return p;
  }

  void saveProject(Project p) {
    p.updatedAt = DateTime.now();
    state = state.copyWith(projects: [
      for (final x in state.projects) if (x.id == p.id) p else x
    ]);
    _persist('projects', p.id, p.toJson());
  }

  void deleteProject(String id) {
    state = state.copyWith(
      projects: state.projects.where((p) => p.id != id).toList(),
      tasks: state.tasks.where((t) => t.projectId != id).toList(),
    );
    _db.delete('projects', id);
  }

  double projectProgress(String projectId) {
    final list = state.tasks.where((t) => t.projectId == projectId).toList();
    if (list.isEmpty) return 0;
    final done = list.where((t) => t.status == TaskStatus.completed).length;
    return done / list.length;
  }

  TaskItem createTask(String title, {String? projectId}) {
    final now = DateTime.now();
    final t = TaskItem(id: newId(), title: title, projectId: projectId, createdAt: now, updatedAt: now);
    state = state.copyWith(tasks: [t, ...state.tasks]);
    _persist('tasks', t.id, t.toJson());
    return t;
  }

  void saveTask(TaskItem t) {
    t.updatedAt = DateTime.now();
    state = state.copyWith(tasks: [
      for (final x in state.tasks) if (x.id == t.id) t else x
    ]);
    _persist('tasks', t.id, t.toJson());
  }

  void deleteTask(String id) {
    state = state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList());
    _db.delete('tasks', id);
  }

  // ------------------------------------------------------------------- misc
  void addFolder(String name) {
    final f = FolderItem(id: newId(), name: name);
    state = state.copyWith(folders: [...state.folders, f]);
    _persist('folders', f.id, f.toJson());
  }

  void renameFile(String fileId, String name) {
    final file = _firstOrNull(state.files.where((f) => f.id == fileId));
    if (file == null || file.linkedId == null) return;
    switch (file.kind) {
      case OfficeFileKind.document:
        final d = documentById(file.linkedId!);
        if (d != null) { d.title = name; saveDocument(d); }
      case OfficeFileKind.spreadsheet:
        final s = spreadsheetById(file.linkedId!);
        if (s != null) { s.title = name; saveSpreadsheet(s); }
      case OfficeFileKind.presentation:
        final p = presentationById(file.linkedId!);
        if (p != null) { p.title = name; savePresentation(p); }
      default:
        break;
    }
  }

  void deleteFile(String fileId) {
    final file = _firstOrNull(state.files.where((f) => f.id == fileId));
    if (file == null || file.linkedId == null) return;
    switch (file.kind) {
      case OfficeFileKind.document:
        deleteDocument(file.linkedId!);
      case OfficeFileKind.spreadsheet:
        deleteSpreadsheet(file.linkedId!);
      case OfficeFileKind.presentation:
        deletePresentation(file.linkedId!);
      case OfficeFileKind.invoice:
        final inv = billingById(file.linkedId!);
        if (inv != null) deleteBilling(inv);
      case OfficeFileKind.quotation:
        final q = billingById(file.linkedId!);
        if (q != null) deleteBilling(q);
      default:
        break;
    }
  }

  void markAllNotificationsRead() {
    for (final n in state.notifications) {
      n.read = true;
      _persist('notifications', n.id, n.toJson());
    }
    state = state.copyWith(notifications: [...state.notifications]);
  }

  void markNotificationRead(String id) {
    for (final n in state.notifications) {
      if (n.id == id) {
        n.read = true;
        _persist('notifications', n.id, n.toJson());
      }
    }
    state = state.copyWith(notifications: [...state.notifications]);
  }

  void addChatMessage(ChatMessage m) {
    state = state.copyWith(chat: [...state.chat, m]);
  }

  void clearChat() => state = state.copyWith(chat: []);

  void toggleTemplateFavorite(String templateId) {
    final favs = {...state.favoriteTemplates};
    if (!favs.add(templateId)) favs.remove(templateId);
    state = state.copyWith(favoriteTemplates: favs);
    _db.setPreference('favorite_templates', jsonEncode(favs.toList()));
  }

  void markTemplateUsed(String templateId) {
    final recent = [templateId, ...state.recentTemplates.where((t) => t != templateId)].take(8).toList();
    state = state.copyWith(recentTemplates: recent);
    _db.setPreference('recent_templates', jsonEncode(recent));
  }

  void setDashboardOrder(List<String> order) {
    state = state.copyWith(dashboardOrder: order);
    _db.setPreference('dashboard_order', jsonEncode(order));
  }

  Future<String> syncNow() => SyncService.instance.syncNow();

  // ------------------------------------------------------------------- seed
  _Seed _seedDemo(DateTime now) {
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));
    final docs = [
      OrbitalDocument(
        id: 'demo-doc-1', title: 'Welcome to ORBITAL OFFICE', createdAt: daysAgo(2), updatedAt: daysAgo(0),
        blocks: [
          DocBlock(type: DocBlockType.heading, text: 'Ideas Into Impact.'),
          DocBlock(type: DocBlockType.paragraph, text: 'This is sample demo content. Create documents, spreadsheets, presentations, invoices and more — everything works offline.'),
          DocBlock(type: DocBlockType.heading, text: 'What you can do'),
          DocBlock(type: DocBlockType.bulletList, text: 'Write proposals, reports and letters'),
          DocBlock(type: DocBlockType.bulletList, text: 'Track sales with live spreadsheet formulas'),
          DocBlock(type: DocBlockType.bulletList, text: 'Send professional invoices in INR'),
        ],
      ),
      OrbitalDocument(
        id: 'demo-doc-2', title: 'Client Proposal — Sharma Retail', createdAt: daysAgo(5), updatedAt: daysAgo(1),
        blocks: [
          DocBlock(type: DocBlockType.heading, text: 'Proposal: Store Branding'),
          DocBlock(type: DocBlockType.paragraph, text: 'Prepared by ORBITAL.STUDIO.3 for Sharma Retail.'),
          DocBlock(type: DocBlockType.bulletList, text: 'Shop advertisement creatives'),
          DocBlock(type: DocBlockType.bulletList, text: 'Festive promotional posters'),
        ],
      ),
    ];
    final sheets = [
      SpreadsheetDoc(
        id: 'demo-sheet-1', title: 'Sales Tracker (Demo)', createdAt: daysAgo(4), updatedAt: daysAgo(0),
        cells: {
          'A1': 'Date', 'B1': 'Product', 'C1': 'Units', 'D1': 'Unit Price (₹)', 'E1': 'Revenue (₹)',
          'A2': '01 Nov', 'B2': 'Branding Package', 'C2': '2', 'D2': '15000', 'E2': '=C2*D2',
          'A3': '02 Nov', 'B3': 'Social Media Kit', 'C3': '5', 'D3': '4999', 'E3': '=C3*D3',
          'A4': '03 Nov', 'B4': 'Website Design', 'C4': '1', 'D4': '35000', 'E4': '=C4*D4',
          'D6': 'TOTAL', 'E6': '=SUM(E2:E4)', 'D7': 'AVERAGE', 'E7': '=AVERAGE(E2:E4)',
        },
      ),
    ];
    final decks = [
      PresentationDoc(
        id: 'demo-deck-1', title: 'ORBITAL Pitch Deck (Demo)', createdAt: daysAgo(3), updatedAt: daysAgo(1),
        slides: [
          Slide(id: 'demo-slide-1', title: 'IDEAS INTO IMPACT.', body: 'Creative Design. Smart Digital Solutions.', background: 0xFF073D2D),
          Slide(id: 'demo-slide-2', title: 'Our Services', bullets: ['Graphic Design & Branding', 'Product Advertising', 'AI Video Creation', 'Website Design', 'Digital Office Solutions']),
          Slide(id: 'demo-slide-3', title: 'Let\'s Create Something Exceptional', body: 'Your Vision. Our Creativity.', background: 0xFFD5A044),
        ],
      ),
    ];
    final invoices = [
      InvoiceDoc(
        id: 'demo-inv-1', kind: BillingKind.invoice, number: 'INV-1001', createdAt: daysAgo(6), updatedAt: daysAgo(2),
        customerName: 'Priya Sharma Retail', businessName: 'ORBITAL.STUDIO.3',
        items: [InvoiceItem(description: 'Shop branding package', quantity: 1, unitPrice: 18000), InvoiceItem(description: 'Festive poster set (10 creatives)', quantity: 10, unitPrice: 800)],
        taxLabel: 'GST', taxPercent: 18, amountPaid: 10000,
      ),
      InvoiceDoc(
        id: 'demo-inv-2', kind: BillingKind.invoice, number: 'INV-1002', createdAt: daysAgo(1), updatedAt: daysAgo(0),
        customerName: 'Deshmukh Electronics', businessName: 'ORBITAL.STUDIO.3',
        items: [InvoiceItem(description: 'Product promotional video', quantity: 1, unitPrice: 12000)],
        dueDate: daysAgo(-3),
      ),
    ];
    final quotations = [
      InvoiceDoc(
        id: 'demo-quo-1', kind: BillingKind.quotation, number: 'QUO-1001', createdAt: daysAgo(2), updatedAt: daysAgo(2),
        customerName: 'FreshMart Stores', businessName: 'ORBITAL.STUDIO.3',
        items: [InvoiceItem(description: 'Website design — 6 pages', quantity: 1, unitPrice: 35000)],
      ),
    ];
    final customers = [
      Customer(id: 'demo-cust-1', name: 'Priya Sharma', businessName: 'Priya Sharma Retail', email: 'Priya Sharma@example.com', phone: '+91 98220 00001', stage: LeadStage.converted, createdAt: daysAgo(20), updatedAt: daysAgo(2), leadSource: 'Instagram', requirements: 'Store branding and festive creatives'),
      Customer(id: 'demo-cust-2', name: 'Imran Sheikh Imran Sheikh', businessName: 'Deshmukh Electronics', email: 'Deshmukh@example.com', phone: '+91 98220 00002', stage: LeadStage.quotationSent, createdAt: daysAgo(12), updatedAt: daysAgo(1), leadSource: 'Referral', followUpDate: daysAgo(-1)),
      Customer(id: 'demo-cust-3', name: 'Sunita Rani', businessName: 'FreshMart Stores', email: 'hello@freshmart.example', phone: '+91 98220 00003', stage: LeadStage.interested, createdAt: daysAgo(6), updatedAt: daysAgo(2), leadSource: 'Website'),
      Customer(id: 'demo-cust-4', name: 'Rahul Verma', businessName: 'Verma Fitness', email: 'Rahul Verma@example.com', phone: '+91 98220 00004', stage: LeadStage.newLead, createdAt: daysAgo(1), updatedAt: daysAgo(1), leadSource: 'Walk-in'),
    ];
    final products = [
      Product(id: 'demo-prod-1', name: 'Branding Package', sku: 'SRV-001', category: 'Services', purchasePrice: 6000, sellingPrice: 15000, stock: 12, createdAt: daysAgo(30), updatedAt: daysAgo(1)),
      Product(id: 'demo-prod-2', name: 'Social Media Kit (Monthly)', sku: 'SRV-002', category: 'Services', purchasePrice: 1800, sellingPrice: 4999, stock: 25, createdAt: daysAgo(30), updatedAt: daysAgo(0)),
      Product(id: 'demo-prod-3', name: 'A5 Brand Notebooks (Pack of 10)', sku: 'PRD-101', category: 'Print', purchasePrice: 420, sellingPrice: 899, stock: 4, lowStockThreshold: 5, createdAt: daysAgo(25), updatedAt: daysAgo(3)),
      Product(id: 'demo-prod-4', name: 'Product Promo Video', sku: 'SRV-003', category: 'Services', purchasePrice: 4500, sellingPrice: 12000, stock: 8, createdAt: daysAgo(20), updatedAt: daysAgo(2)),
    ];
    final projects = [
      Project(id: 'demo-proj-1', title: 'Priya Sharma Retail — Festive Campaign', description: 'Posters, shop ads and reels for the festive season.', deadline: daysAgo(-9), createdAt: daysAgo(10), updatedAt: daysAgo(0)),
      Project(id: 'demo-proj-2', title: 'FreshMart Website', description: 'Business website with product showcase.', deadline: daysAgo(-21), createdAt: daysAgo(4), updatedAt: daysAgo(1)),
    ];
    final tasks = [
      TaskItem(id: 'demo-task-1', title: 'Design Diwali poster set', projectId: 'demo-proj-1', priority: TaskPriority.high, status: TaskStatus.inProgress, dueDate: daysAgo(-2), createdAt: daysAgo(3), updatedAt: daysAgo(0)),
      TaskItem(id: 'demo-task-2', title: 'Client approval on logo options', projectId: 'demo-proj-1', priority: TaskPriority.medium, status: TaskStatus.toDo, dueDate: daysAgo(-4), createdAt: daysAgo(2), updatedAt: daysAgo(1)),
      TaskItem(id: 'demo-task-3', title: 'Homepage wireframe', projectId: 'demo-proj-2', priority: TaskPriority.high, status: TaskStatus.toDo, dueDate: daysAgo(-5), createdAt: daysAgo(1), updatedAt: daysAgo(1)),
      TaskItem(id: 'demo-task-4', title: 'Collect product photos', projectId: 'demo-proj-2', priority: TaskPriority.low, status: TaskStatus.completed, createdAt: daysAgo(2), updatedAt: daysAgo(0)),
      TaskItem(id: 'demo-task-5', title: 'Send INV-1001 payment reminder', priority: TaskPriority.medium, status: TaskStatus.toDo, dueDate: daysAgo(0), createdAt: daysAgo(1), updatedAt: daysAgo(0)),
    ];
    final notifications = [
      AppNotification(id: 'demo-notif-1', title: 'Welcome to ORBITAL OFFICE', body: 'You are exploring the demo workspace with sample data. Everything works offline.', at: daysAgo(0)),
      AppNotification(id: 'demo-notif-2', title: 'Low stock alert', body: 'A5 Brand Notebooks (Pack of 10) has only 4 unit(s) left.', at: daysAgo(1), route: '/business/inventory'),
    ];
    return _Seed(
      documents: docs, spreadsheets: sheets, presentations: decks,
      invoices: invoices, quotations: quotations, customers: customers,
      products: products, movements: const [], projects: projects,
      tasks: tasks, notifications: notifications,
    );
  }
}

class _Seed {
  const _Seed({
    required this.documents,
    required this.spreadsheets,
    required this.presentations,
    required this.invoices,
    required this.quotations,
    required this.customers,
    required this.products,
    required this.movements,
    required this.projects,
    required this.tasks,
    required this.notifications,
  });

  final List<OrbitalDocument> documents;
  final List<SpreadsheetDoc> spreadsheets;
  final List<PresentationDoc> presentations;
  final List<InvoiceDoc> invoices;
  final List<InvoiceDoc> quotations;
  final List<Customer> customers;
  final List<Product> products;
  final List<InventoryMovement> movements;
  final List<Project> projects;
  final List<TaskItem> tasks;
  final List<AppNotification> notifications;
}

T? _firstOrNull<T>(Iterable<T> items) => items.isEmpty ? null : items.first;

final appControllerProvider =
    StateNotifierProvider<AppController, AppState>((ref) => AppController());
