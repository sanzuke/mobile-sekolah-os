import 'package:flutter/material.dart';

import '../models/rpp_models.dart';
import '../services/attachment_picker.dart';
import '../services/teacher_service.dart';
import '../widgets/async_view.dart';
import '../widgets/date_format.dart';
import '../widgets/rpp_widgets.dart';
import '../widgets/surface_cards.dart';
import 'rpp_form_screen.dart';

/// "RPP saya": last, this and next week (each can be filled in), then older weeks.
/// One RPP per week; the head of school reviews it.
class RppScreen extends StatefulWidget {
  const RppScreen({
    super.key,
    required this.service,
    required this.onUnauthorized,
    this.picker = const RppFilePicker(),
  });

  final TeacherService service;
  final VoidCallback onUnauthorized;
  final AttachmentPicker picker;

  @override
  State<RppScreen> createState() => _RppScreenState();
}

class _RppScreenState extends State<RppScreen> {
  final _view = GlobalKey<AsyncViewState<RppPage>>();

  Future<void> _open(RppWeek week, int maxBytes) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RppFormScreen(
          service: widget.service,
          onUnauthorized: widget.onUnauthorized,
          picker: widget.picker,
          week: week,
          maxBytes: maxBytes,
        ),
      ),
    );
    if (changed == true) await _view.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RPP saya')),
      body: AsyncView<RppPage>(
        key: _view,
        load: widget.service.rppWeeks,
        onUnauthorized: widget.onUnauthorized,
        builder: (context, page) => RefreshIndicator(
          onRefresh: () async => _view.currentState?.reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                'Satu RPP per pekan, batas unggah hari Minggu pekan itu. '
                'RPP ditinjau kepala sekolah.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (page.weeks.isEmpty)
                const Surface(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Belum ada pekan untuk diisi.'),
                  ),
                )
              else
                for (final w in page.weeks)
                  _WeekCard(week: w, onTap: () => _open(w, page.maxBytes)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, required this.onTap});

  final RppWeek week;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final action = week.canSubmit
        ? (week.hasFile ? 'Ganti berkas' : 'Unggah RPP')
        : 'Lihat';
    return Surface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatRange(week.weekStart, week.weekEnd),
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (week.isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      'Pekan ini',
                      style: text.labelSmall?.copyWith(
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                RppStatusChip(state: week.state, overdue: week.overdue),
              ],
            ),
            if (week.title != null) ...[
              const SizedBox(height: 6),
              Text(
                week.title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium,
              ),
            ],
            if (week.state == 'rejected' &&
                (week.reviewNotes ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Catatan: ${week.reviewNotes}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: const Color(0xFFB91C1C)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Batas ${formatDate(week.due)}',
                    style: text.bodySmall,
                  ),
                ),
                Text(
                  action,
                  style: text.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
