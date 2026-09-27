import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkCalendarScreen extends StatefulWidget {
  const WorkCalendarScreen({super.key});
  @override
  State<WorkCalendarScreen> createState() => _WorkCalendarScreenState();
}

class _WorkCalendarScreenState extends State<WorkCalendarScreen> {
  late Future<List<_CalendarEvent>> _events;
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _events = _loadEvents();
  }

  Future<List<_CalendarEvent>> _loadEvents() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final projectsResponse = await client
        .from('projects')
        .select('id, title, deadline')
        .or('client_id.eq.$userId,freelancer_id.eq.$userId');
    final projects = (projectsResponse as List).cast<Map>();
    final projectIds = projects
        .map((row) => row['id'])
        .whereType<String>()
        .toList();
    final events = <_CalendarEvent>[];
    for (final project in projects) {
      final deadline = DateTime.tryParse(project['deadline']?.toString() ?? '');
      if (deadline != null)
        events.add(
          _CalendarEvent(
            date: deadline,
            title: 'Project deadline',
            detail: project['title']?.toString() ?? 'Project',
            icon: Icons.work_outline,
            route: '/project/${project['id']}',
          ),
        );
    }
    if (projectIds.isNotEmpty) {
      final rows = await Future.wait([
        client
            .from('milestones')
            .select('id, project_id, title, deadline')
            .inFilter('project_id', projectIds)
            .not('deadline', 'is', null),
        client
            .from('project_tasks')
            .select('id, project_id, title, due_date')
            .inFilter('project_id', projectIds)
            .not('due_date', 'is', null),
      ]);
      final titles = {
        for (final project in projects)
          project['id'].toString(): project['title']?.toString() ?? 'Project',
      };
      for (final row in (rows[0] as List).cast<Map>()) {
        final date = DateTime.tryParse(row['deadline']?.toString() ?? '');
        if (date != null)
          events.add(
            _CalendarEvent(
              date: date,
              title: 'Milestone deadline',
              detail: '${row['title']} · ${titles[row['project_id']]}',
              icon: Icons.flag_outlined,
              route: '/project/${row['project_id']}',
            ),
          );
      }
      for (final row in (rows[1] as List).cast<Map>()) {
        final date = DateTime.tryParse(row['due_date']?.toString() ?? '');
        if (date != null)
          events.add(
            _CalendarEvent(
              date: date,
              title: 'Task due',
              detail: '${row['title']} · ${titles[row['project_id']]}',
              icon: Icons.checklist_outlined,
              route: '/project/${row['project_id']}',
            ),
          );
      }
    }
    final interviewResponse = await client
        .from('job_interviews')
        .select('id, job_id, scheduled_at, notes, jobs(title)')
        .eq('status', 'scheduled')
        .or('client_id.eq.$userId,freelancer_id.eq.$userId');
    for (final row in (interviewResponse as List).cast<Map>()) {
      final date = DateTime.tryParse(row['scheduled_at']?.toString() ?? '');
      final job = row['jobs'] as Map?;
      if (date != null)
        events.add(
          _CalendarEvent(
            date: date,
            title: 'Job interview',
            detail:
                '${job?['title'] ?? 'Job'}${(row['notes']?.toString() ?? '').isEmpty ? '' : ' · ${row['notes']}'}',
            icon: Icons.event_outlined,
            route: '/applications',
          ),
        );
    }
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  Future<void> _refresh() async {
    final request = _loadEvents();
    setState(() => _events = request);
    await request;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Work calendar'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Refresh calendar',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<_CalendarEvent>>(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry calendar'),
            ),
          );
        final events = snapshot.data ?? const [];
        final selected = events
            .where(
              (event) =>
                  DateUtils.isSameDay(event.date.toLocal(), _selectedDay),
            )
            .toList();
        return ListView(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: CalendarDatePicker(
                initialDate: _selectedDay,
                firstDate: DateTime(DateTime.now().year - 2),
                lastDate: DateTime(DateTime.now().year + 5),
                onDateChanged: (value) =>
                    setState(() => _selectedDay = DateUtils.dateOnly(value)),
                selectableDayPredicate: (_) => true,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                _heading(_selectedDay),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (selected.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    events.isEmpty
                        ? 'Your project deadlines, task dates, and interviews will appear here.'
                        : 'No scheduled work for this day.',
                  ),
                ),
              ),
            ...selected.map(
              (event) => Card(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ListTile(
                  leading: Icon(event.icon),
                  title: Text(event.title),
                  subtitle: Text(
                    '${event.detail}\n${_time(event.date.toLocal())}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(event.route),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  String _heading(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _CalendarEvent {
  const _CalendarEvent({
    required this.date,
    required this.title,
    required this.detail,
    required this.icon,
    required this.route,
  });
  final DateTime date;
  final String title;
  final String detail;
  final IconData icon;
  final String route;
}
