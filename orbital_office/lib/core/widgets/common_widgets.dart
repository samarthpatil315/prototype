import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The ORBITAL "O" mark with orbiting pixel squares — drawn, not copied,
/// matching the parent brand ORBITAL.STUDIO.3.
class OrbitalLogo extends StatelessWidget {
  const OrbitalLogo({super.key, this.size = 64, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.forestGreen;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                border: Border.all(color: c, width: size * 0.11),
                borderRadius: BorderRadius.circular(size * 0.18),
              ),
            ),
          ),
          Positioned(
            right: size * 0.16,
            top: size * 0.08,
            child: _pixel(size * 0.14, c),
          ),
          Positioned(
            right: 0,
            top: size * 0.26,
            child: _pixel(size * 0.11, c),
          ),
          Positioned(
            right: size * 0.04,
            top: 0,
            child: _pixel(size * 0.09, c),
          ),
        ],
      ),
    );
  }

  Widget _pixel(double s, Color c) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(s * 0.2),
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.deepGreen,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: AppTheme.tabular,
                      )),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.deepGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.deepGreen),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.mutedText)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small gold/green pill used for statuses and stages.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.color = AppColors.deepGreen});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.premiumGold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.premiumGold.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: Color(0xFF8A6414)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'DEMO WORKSPACE — sample data, stored on this device only',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A6414)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String label = 'Name',
  String initial = '',
  String submitLabel = 'Save',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(submitLabel),
        ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// The visual creation menu opened by the centre "Create" navigation item.
class CreateAction {
  const CreateAction(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

const List<CreateAction> createActions = [
  CreateAction('Document', Icons.description_outlined, '/create/document'),
  CreateAction('Spreadsheet', Icons.grid_on_outlined, '/create/spreadsheet'),
  CreateAction('Presentation', Icons.slideshow_outlined, '/create/presentation'),
  CreateAction('Invoice', Icons.receipt_long_outlined, '/create/invoice'),
  CreateAction('Quotation', Icons.request_quote_outlined, '/create/quotation'),
  CreateAction('Customer', Icons.person_add_outlined, '/create/customer'),
  CreateAction('Project', Icons.folder_open_outlined, '/create/project'),
  CreateAction('Task', Icons.check_circle_outline, '/create/task'),
  CreateAction('Product', Icons.inventory_2_outlined, '/create/product'),
];
