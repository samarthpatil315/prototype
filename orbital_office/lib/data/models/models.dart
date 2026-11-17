import '../../core/services/invoice_calculator.dart';

String _str(Object? v, [String fallback = '']) => v?.toString() ?? fallback;
double _dbl(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
bool _bool(Object? v) => v == true || v == 'true';
DateTime _date(Object? v) =>
    DateTime.tryParse('${v ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
List<String> _strList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

// ---------------------------------------------------------------------------

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.businessName = '',
    this.phone = '',
    this.isGuest = false,
  });

  final String id;
  final String name;
  final String email;
  final String businessName;
  final String phone;
  final bool isGuest;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'O';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  UserProfile copyWith({String? name, String? businessName, String? phone}) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        email: email,
        businessName: businessName ?? this.businessName,
        phone: phone ?? this.phone,
        isGuest: isGuest,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'businessName': businessName,
        'phone': phone,
        'isGuest': isGuest,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: _str(j['id']),
        name: _str(j['name'], 'Orbital User'),
        email: _str(j['email']),
        businessName: _str(j['businessName']),
        phone: _str(j['phone']),
        isGuest: _bool(j['isGuest']),
      );
}

// ---------------------------------------------------------------------------

enum DocBlockType { heading, paragraph, bulletList, numberedList, table, image, divider }

class DocBlock {
  DocBlock({required this.type, this.text = '', List<List<String>>? table})
      : table = table ?? [];

  DocBlockType type;
  String text;
  List<List<String>> table; // rows x cells for table blocks

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'text': text,
        'table': table,
      };

  factory DocBlock.fromJson(Map<String, dynamic> j) => DocBlock(
        type: DocBlockType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => DocBlockType.paragraph,
        ),
        text: _str(j['text']),
        table: (j['table'] as List? ?? [])
            .map((r) => (r as List).map((c) => c.toString()).toList())
            .toList(),
      );
}

class OrbitalDocument {
  OrbitalDocument({
    required this.id,
    required this.title,
    required this.blocks,
    required this.createdAt,
    required this.updatedAt,
    this.favorite = false,
    this.folderId,
  });

  final String id;
  String title;
  List<DocBlock> blocks;
  final DateTime createdAt;
  DateTime updatedAt;
  bool favorite;
  String? folderId;

  String get plainText => blocks.map((b) => b.text).join('\n');
  int get wordCount =>
      plainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'favorite': favorite,
        'folderId': folderId,
      };

  factory OrbitalDocument.fromJson(Map<String, dynamic> j) => OrbitalDocument(
        id: _str(j['id']),
        title: _str(j['title'], 'Untitled Document'),
        blocks: (j['blocks'] as List? ?? [])
            .map((b) => DocBlock.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList(),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        favorite: _bool(j['favorite']),
        folderId: j['folderId']?.toString(),
      );
}

// ---------------------------------------------------------------------------

class SpreadsheetDoc {
  SpreadsheetDoc({
    required this.id,
    required this.title,
    required this.cells,
    required this.createdAt,
    required this.updatedAt,
    this.favorite = false,
    this.rows = 30,
    this.columns = 12,
    this.frozenRows = 0,
  });

  final String id;
  String title;
  Map<String, String> cells; // "A1" -> raw input (formula or literal)
  final DateTime createdAt;
  DateTime updatedAt;
  bool favorite;
  int rows;
  int columns;
  int frozenRows;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cells': cells,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'favorite': favorite,
        'rows': rows,
        'columns': columns,
        'frozenRows': frozenRows,
      };

  factory SpreadsheetDoc.fromJson(Map<String, dynamic> j) => SpreadsheetDoc(
        id: _str(j['id']),
        title: _str(j['title'], 'Untitled Spreadsheet'),
        cells: (j['cells'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString().toUpperCase(), v.toString())),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        favorite: _bool(j['favorite']),
        rows: _int(j['rows']) == 0 ? 30 : _int(j['rows']),
        columns: _int(j['columns']) == 0 ? 12 : _int(j['columns']),
        frozenRows: _int(j['frozenRows']),
      );
}

// ---------------------------------------------------------------------------

class Slide {
  Slide({
    required this.id,
    this.title = '',
    this.body = '',
    this.background = 0xFFF5F0E5,
    this.imageUrl,
    this.bullets = const [],
  });

  final String id;
  String title;
  String body;
  int background; // ARGB
  String? imageUrl;
  List<String> bullets;

  Slide copy() => Slide(
        id: id,
        title: title,
        body: body,
        background: background,
        imageUrl: imageUrl,
        bullets: List.of(bullets),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'background': background,
        'imageUrl': imageUrl,
        'bullets': bullets,
      };

  factory Slide.fromJson(Map<String, dynamic> j) => Slide(
        id: _str(j['id']),
        title: _str(j['title']),
        body: _str(j['body']),
        background: _int(j['background']) == 0 ? 0xFFF5F0E5 : _int(j['background']),
        imageUrl: j['imageUrl']?.toString(),
        bullets: _strList(j['bullets']),
      );
}

class PresentationDoc {
  PresentationDoc({
    required this.id,
    required this.title,
    required this.slides,
    required this.createdAt,
    required this.updatedAt,
    this.favorite = false,
  });

  final String id;
  String title;
  List<Slide> slides;
  final DateTime createdAt;
  DateTime updatedAt;
  bool favorite;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'slides': slides.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'favorite': favorite,
      };

  factory PresentationDoc.fromJson(Map<String, dynamic> j) => PresentationDoc(
        id: _str(j['id']),
        title: _str(j['title'], 'Untitled Presentation'),
        slides: (j['slides'] as List? ?? [])
            .map((s) => Slide.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList(),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        favorite: _bool(j['favorite']),
      );
}

// ---------------------------------------------------------------------------

enum BillingKind { invoice, quotation }

class InvoiceItem {
  InvoiceItem({
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountPercent = 0,
  });

  String description;
  double quantity;
  double unitPrice;
  double discountPercent;

  InvoiceLineInput get asInput => InvoiceLineInput(
        description: description,
        quantity: quantity,
        unitPrice: unitPrice,
        discountPercent: discountPercent,
      );

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountPercent': discountPercent,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        description: _str(j['description']),
        quantity: _dbl(j['quantity']) == 0 ? 1 : _dbl(j['quantity']),
        unitPrice: _dbl(j['unitPrice']),
        discountPercent: _dbl(j['discountPercent']),
      );
}

class InvoiceDoc {
  InvoiceDoc({
    required this.id,
    required this.kind,
    required this.number,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.customerId,
    this.customerName = '',
    this.businessName = '',
    this.businessAddress = '',
    this.customerAddress = '',
    DateTime? issueDate,
    DateTime? dueDate,
    this.discountPercent = 0,
    this.taxPercent = 0,
    this.taxLabel = '',
    this.amountPaid = 0,
    this.currencySymbol = '₹',
    this.notes = '',
  })  : issueDate = issueDate ?? createdAt,
        dueDate = dueDate ?? createdAt.add(const Duration(days: 7));

  final String id;
  final BillingKind kind;
  String number;
  List<InvoiceItem> items;
  final DateTime createdAt;
  DateTime updatedAt;
  String? customerId;
  String customerName;
  String businessName;
  String businessAddress;
  String customerAddress;
  DateTime issueDate;
  DateTime dueDate;
  double discountPercent;
  double taxPercent;
  String taxLabel; // configurable — never assume a tax regime
  double amountPaid;
  String currencySymbol;
  String notes;

  InvoiceTotals get totals => InvoiceCalculator.calculate(
        items: items.map((i) => i.asInput).toList(),
        invoiceDiscountPercent: discountPercent,
        taxPercent: taxPercent,
        amountPaid: amountPaid,
      );

  PaymentStatus get paymentStatus => paymentStatusFor(totals);
  bool get isOverdue =>
      kind == BillingKind.invoice &&
      paymentStatus != PaymentStatus.paid &&
      dueDate.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'number': number,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'customerId': customerId,
        'customerName': customerName,
        'businessName': businessName,
        'businessAddress': businessAddress,
        'customerAddress': customerAddress,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'discountPercent': discountPercent,
        'taxPercent': taxPercent,
        'taxLabel': taxLabel,
        'amountPaid': amountPaid,
        'currencySymbol': currencySymbol,
        'notes': notes,
      };

  factory InvoiceDoc.fromJson(Map<String, dynamic> j) => InvoiceDoc(
        id: _str(j['id']),
        kind: j['kind'] == 'quotation' ? BillingKind.quotation : BillingKind.invoice,
        number: _str(j['number']),
        items: (j['items'] as List? ?? [])
            .map((i) => InvoiceItem.fromJson(Map<String, dynamic>.from(i as Map)))
            .toList(),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        customerId: j['customerId']?.toString(),
        customerName: _str(j['customerName']),
        businessName: _str(j['businessName']),
        businessAddress: _str(j['businessAddress']),
        customerAddress: _str(j['customerAddress']),
        issueDate: _date(j['issueDate']),
        dueDate: _date(j['dueDate']),
        discountPercent: _dbl(j['discountPercent']),
        taxPercent: _dbl(j['taxPercent']),
        taxLabel: _str(j['taxLabel']),
        amountPaid: _dbl(j['amountPaid']),
        currencySymbol: _str(j['currencySymbol'], '₹'),
        notes: _str(j['notes']),
      );
}

// ---------------------------------------------------------------------------

class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.businessName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.requirements = '',
    this.notes = '',
    this.leadSource = '',
    this.stage = LeadStage.newLead,
    this.followUpDate,
  });

  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  String businessName;
  String email;
  String phone;
  String address;
  String requirements;
  String notes;
  String leadSource;
  LeadStage stage;
  DateTime? followUpDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'businessName': businessName,
        'email': email,
        'phone': phone,
        'address': address,
        'requirements': requirements,
        'notes': notes,
        'leadSource': leadSource,
        'stage': stage.code,
        'followUpDate': followUpDate?.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: _str(j['id']),
        name: _str(j['name'], 'Unnamed Customer'),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        businessName: _str(j['businessName']),
        email: _str(j['email']),
        phone: _str(j['phone']),
        address: _str(j['address']),
        requirements: _str(j['requirements']),
        notes: _str(j['notes']),
        leadSource: _str(j['leadSource']),
        stage: LeadStage.fromCode(j['stage']?.toString()),
        followUpDate: DateTime.tryParse('${j['followUpDate'] ?? ''}'),
      );
}

// ---------------------------------------------------------------------------

class Product {
  Product({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.sku = '',
    this.category = 'General',
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.stock = 0,
    this.lowStockThreshold = 5,
  });

  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  String sku;
  String category;
  double purchasePrice;
  double sellingPrice;
  int stock;
  int lowStockThreshold;

  bool get isLowStock => stock <= lowStockThreshold;
  double get margin => sellingPrice - purchasePrice;
  double get stockValue => stock * purchasePrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'sku': sku,
        'category': category,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'stock': stock,
        'lowStockThreshold': lowStockThreshold,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _str(j['id']),
        name: _str(j['name'], 'Unnamed Product'),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        sku: _str(j['sku']),
        category: _str(j['category'], 'General'),
        purchasePrice: _dbl(j['purchasePrice']),
        sellingPrice: _dbl(j['sellingPrice']),
        stock: _int(j['stock']),
        lowStockThreshold: _int(j['lowStockThreshold']) == 0
            ? 5
            : _int(j['lowStockThreshold']),
      );
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.change,
    required this.reason,
    required this.at,
  });

  final String id;
  final String productId;
  final int change;
  final String reason;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'change': change,
        'reason': reason,
        'at': at.toIso8601String(),
      };

  factory InventoryMovement.fromJson(Map<String, dynamic> j) =>
      InventoryMovement(
        id: _str(j['id']),
        productId: _str(j['productId']),
        change: _int(j['change']),
        reason: _str(j['reason']),
        at: _date(j['at']),
      );
}

// ---------------------------------------------------------------------------

class Project {
  Project({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.deadline,
    this.customerId,
    this.colorValue = 0xFF0B513B,
  });

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  String description;
  DateTime? deadline;
  String? customerId;
  int colorValue;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'description': description,
        'deadline': deadline?.toIso8601String(),
        'customerId': customerId,
        'colorValue': colorValue,
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: _str(j['id']),
        title: _str(j['title'], 'Untitled Project'),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        description: _str(j['description']),
        deadline: DateTime.tryParse('${j['deadline'] ?? ''}'),
        customerId: j['customerId']?.toString(),
        colorValue:
            _int(j['colorValue']) == 0 ? 0xFF0B513B : _int(j['colorValue']),
      );
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.toDo,
    this.dueDate,
    this.assignee = '',
  });

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  String? projectId;
  String description;
  TaskPriority priority;
  TaskStatus status;
  DateTime? dueDate;
  String assignee;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'projectId': projectId,
        'description': description,
        'priority': priority.code,
        'status': status.code,
        'dueDate': dueDate?.toIso8601String(),
        'assignee': assignee,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: _str(j['id']),
        title: _str(j['title'], 'Untitled Task'),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        projectId: j['projectId']?.toString(),
        description: _str(j['description']),
        priority: TaskPriority.fromCode(j['priority']?.toString()),
        status: TaskStatus.fromCode(j['status']?.toString()),
        dueDate: DateTime.tryParse('${j['dueDate'] ?? ''}'),
        assignee: _str(j['assignee']),
      );
}

// ---------------------------------------------------------------------------

enum OfficeFileKind { document, spreadsheet, presentation, invoice, quotation, pdf, image, csv, other }

class OfficeFile {
  OfficeFile({
    required this.id,
    required this.name,
    required this.kind,
    required this.updatedAt,
    this.sizeBytes = 0,
    this.favorite = false,
    this.folderId,
    this.linkedId,
    this.localPath,
  });

  final String id;
  String name;
  final OfficeFileKind kind;
  DateTime updatedAt;
  int sizeBytes;
  bool favorite;
  String? folderId;
  String? linkedId; // id of the backing document/sheet/deck/invoice
  String? localPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'updatedAt': updatedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
        'favorite': favorite,
        'folderId': folderId,
        'linkedId': linkedId,
        'localPath': localPath,
      };

  factory OfficeFile.fromJson(Map<String, dynamic> j) => OfficeFile(
        id: _str(j['id']),
        name: _str(j['name'], 'Untitled File'),
        kind: OfficeFileKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => OfficeFileKind.other,
        ),
        updatedAt: _date(j['updatedAt']),
        sizeBytes: _int(j['sizeBytes']),
        favorite: _bool(j['favorite']),
        folderId: j['folderId']?.toString(),
        linkedId: j['linkedId']?.toString(),
        localPath: j['localPath']?.toString(),
      );
}

class FolderItem {
  const FolderItem({required this.id, required this.name});
  final String id;
  final String name;
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory FolderItem.fromJson(Map<String, dynamic> j) =>
      FolderItem(id: _str(j['id']), name: _str(j['name'], 'Folder'));
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
    this.route,
  });

  final String id;
  final String title;
  final String body;
  final DateTime at;
  bool read;
  final String? route;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'read': read,
        'route': route,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _str(j['id']),
        title: _str(j['title']),
        body: _str(j['body']),
        at: _date(j['at']),
        read: _bool(j['read']),
        route: j['route']?.toString(),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.fromUser,
    required this.at,
  });

  final String id;
  final String text;
  final bool fromUser;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'fromUser': fromUser,
        'at': at.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _str(j['id']),
        text: _str(j['text']),
        fromUser: _bool(j['fromUser']),
        at: _date(j['at']),
      );
}

enum TemplateKind { document, spreadsheet, presentation }

class TemplateItem {
  const TemplateItem({
    required this.id,
    required this.title,
    required this.category,
    required this.kind,
    required this.description,
    this.favorite = false,
  });

  final String id;
  final String title;
  final String category;
  final TemplateKind kind;
  final String description;
  final bool favorite;

  TemplateItem copyWith({bool? favorite}) => TemplateItem(
        id: id,
        title: title,
        category: category,
        kind: kind,
        description: description,
        favorite: favorite ?? this.favorite,
      );
}
