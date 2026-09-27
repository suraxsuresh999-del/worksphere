import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/viewmodels/auth_viewmodel.dart';

class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiController = TextEditingController();
  final _accountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSaving = false;
  bool _isRemoving = false;
  PlatformFile? _qrFile;
  late Future<Map<String, dynamic>?> _currentMethod;

  @override
  void initState() {
    super.initState();
    _currentMethod = _loadPaymentMethod();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _accountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadPaymentMethod() async {
    // The authenticated Supabase session is available before the profile
    // stream necessarily finishes its initial load.
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final row = await Supabase.instance.client
        .from('freelancer_payment_methods')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    final data = row == null ? null : Map<String, dynamic>.from(row as Map);
    if (data != null) {
      _upiController.text = data['upi_id'] as String? ?? '';
      _accountController.text = data['account_holder_name'] as String? ?? '';
      _noteController.text = data['payment_note'] as String? ?? '';
    }
    return data;
  }

  void _refresh() => setState(() => _currentMethod = _loadPaymentMethod());

  Future<void> _pickQrCode() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    if (result.isEmpty) return;
    final file = result.single;
    if (await file.length() > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR image must be 5 MB or smaller.')),
        );
      }
      return;
    }
    setState(() => _qrFile = file);
  }

  String? _validateUpi(String? value) {
    final upi = value?.trim() ?? '';
    if (upi.isEmpty) return 'UPI ID is required';
    final regex = RegExp(
      r'^[A-Za-z0-9._-]+@(upi|okaxis|oksbi|ybl|paytm|axl|ibl|idbi|kotak|unionbank)$',
      caseSensitive: false,
    );
    if (!regex.hasMatch(upi)) return 'Enter a valid UPI ID';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);
    String? newlyUploadedQrPath;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('You must be signed in.');

      String? qrPath;
      final previousQrPath = (await _currentMethod)?['qr_code_path'] as String?;
      if (_qrFile != null) {
        final bytes = await _qrFile!.readAsBytes();
        final contentType = _qrFile!.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        // Storage policies and client reads scope files by their first folder,
        // which must be the freelancer's auth user ID.
        qrPath =
            '${user.id}/payment-methods/qr-${DateTime.now().millisecondsSinceEpoch}.${contentType == 'image/png' ? 'png' : 'jpg'}';
        newlyUploadedQrPath = qrPath;
        await client.storage
            .from('freelancer-payment-assets')
            .uploadBinary(
              qrPath,
              Uint8List.fromList(bytes),
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );
      } else {
        final current = await _currentMethod;
        qrPath = current?['qr_code_path'] as String?;
      }

      await client.rpc(
        'upsert_freelancer_payment_method',
        params: {
          'upi_id_input': _upiController.text.trim(),
          'account_holder_name_input': _accountController.text.trim(),
          'qr_code_path_input': qrPath,
          'payment_note_input': _noteController.text.trim(),
        },
      );

      if (previousQrPath != null && previousQrPath != qrPath) {
        await _deleteQr(previousQrPath);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment details saved.')));
      _refresh();
    } catch (_) {
      if (newlyUploadedQrPath != null) {
        await _deleteQr(newlyUploadedQrPath);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save payment details. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _remove() async {
    if (_isRemoving) return;
    setState(() => _isRemoving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final current = await _currentMethod;
      await client
          .from('freelancer_payment_methods')
          .delete()
          .eq('user_id', user.id);
      final qrPath = current?['qr_code_path'] as String?;
      if (qrPath != null) await _deleteQr(qrPath);
      if (!mounted) return;
      _upiController.clear();
      _accountController.clear();
      _noteController.clear();
      setState(() => _qrFile = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment details removed.')));
      _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to remove payment details.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  Future<void> _deleteQr(String path) async {
    try {
      await Supabase.instance.client.storage
          .from('freelancer-payment-assets')
          .remove([path]);
    } catch (_) {
      // Don't block payment method changes if storage cleanup fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(currentUserProvider);
    if (userState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Methods')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final user = userState.valueOrNull;
    if (user?.type.name != 'freelancer') {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Methods')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Payout details are available for freelancer accounts only. Client payments are managed when paying for a project.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Methods')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _currentMethod,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load payment details.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final current = snapshot.data;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Add your UPI payment details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'These details stay private and are only shown to a client when they are paying for a project.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                if (user?.verificationStatus.isVerified != true)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Verification required'),
                      subtitle: Text(
                        'Approve identity verification before saving payout details.',
                      ),
                    ),
                  ),
                if (user?.verificationStatus.isVerified != true)
                  const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _upiController,
                          decoration: const InputDecoration(
                            labelText: 'UPI ID',
                          ),
                          validator: _validateUpi,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _accountController,
                          decoration: const InputDecoration(
                            labelText: 'Account holder name',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Account holder name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'Optional payment note',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('UPI QR code'),
                          subtitle: Text(
                            _qrFile?.name ??
                                (current?['qr_code_path'] as String? ??
                                    'No QR code uploaded'),
                          ),
                          trailing: OutlinedButton(
                            onPressed: _pickQrCode,
                            child: const Text('Upload QR'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    _isSaving ||
                                        user?.verificationStatus.isVerified !=
                                            true
                                    ? null
                                    : _save,
                                child: Text(
                                  _isSaving
                                      ? 'Saving...'
                                      : 'Save Payment Details',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _isRemoving ? null : _remove,
                              child: Text(
                                _isRemoving ? 'Removing...' : 'Remove',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: const Text('Payment status'),
                    subtitle: Text(
                      (current?['status'] as String?) ?? 'Not Added',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
