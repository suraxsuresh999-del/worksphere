import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<List<Map<String, dynamic>>> _invoices;
  @override
  void initState() {
    super.initState();
    _invoices = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('project_invoices')
        .select()
        .order('issued_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _refresh() async {
    final request = _load();
    setState(() => _invoices = request);
    await request;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Invoices')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _invoices,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry loading invoices'),
            ),
          );
        final invoices = snapshot.data ?? const [];
        if (invoices.isEmpty)
          return const Center(
            child: Text(
              'Invoices appear here after a project is completed and payment is verified.',
            ),
          );
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    invoice['invoice_number']?.toString() ?? 'Invoice',
                  ),
                  subtitle: Text(
                    '${invoice['project_title']} · ₹${invoice['amount']}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/invoice/${invoice['id']}'),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final String invoiceId;
  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Future<Map<String, dynamic>?> _invoice;
  @override
  void initState() {
    super.initState();
    _invoice = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final row = await Supabase.instance.client
        .from('project_invoices')
        .select()
        .eq('id', widget.invoiceId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  String _invoiceText(Map<String, dynamic> invoice) => [
    'WorkSphere invoice ${invoice['invoice_number']}',
    'Issued: ${invoice['issued_at']}',
    'Project: ${invoice['project_title']}',
    'Client: ${invoice['client_name']}',
    'Freelancer: ${invoice['freelancer_name']}',
    'Total: ${invoice['currency']} ${invoice['amount']}',
  ].join('\n');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Invoice'),
      actions: [
        FutureBuilder<Map<String, dynamic>?>(
          future: _invoice,
          builder: (context, snapshot) {
            final invoice = snapshot.data;
            return IconButton(
              tooltip: 'Share invoice',
              onPressed: invoice == null
                  ? null
                  : () => SharePlus.instance.share(
                      ShareParams(text: _invoiceText(invoice)),
                    ),
              icon: const Icon(Icons.share_outlined),
            );
          },
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: _invoice,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null)
          return const Center(child: Text('Invoice is unavailable.'));
        final invoice = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WorkSphere',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      invoice['invoice_number']?.toString() ?? '',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('Issued ${_date(invoice['issued_at'])}'),
                    const Divider(height: 32),
                    Text(
                      'Project',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(invoice['project_title']?.toString() ?? ''),
                    const SizedBox(height: 16),
                    Text(
                      'Client',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(invoice['client_name']?.toString() ?? ''),
                    const SizedBox(height: 16),
                    Text(
                      'Freelancer',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(invoice['freelancer_name']?.toString() ?? ''),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total paid',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${invoice['currency']} ${invoice['amount']}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Payment was verified by WorkSphere.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(text: _invoiceText(invoice)),
              ),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share invoice details'),
            ),
          ],
        );
      },
    ),
  );

  String _date(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
