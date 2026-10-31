part of 'admin_panel_page.dart';

extension _AdminMonetizationPart on _AdminPanelPageState {
  // ============================================================
  // BUY NOVA MONETIZATION
  // ============================================================

  Widget _monetizationTab() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.doc(_AdminPanelPageState._monetizationPath).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error.toString());
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final data = snapshot.data?.data() ?? {};

        final sellerFee = _toDouble(
          data['sellerMembershipFee'],
        );

        final resellerFee = _toDouble(
          data['resellerMembershipFee'],
        );

        final commission = _toDouble(
          data['commissionPercent'],
        );

        final serviceFeeEnabled =
            data['buyerServiceFeeEnabled'] == true;

        final serviceFeePercent = _toDouble(
          data['buyerServiceFeePercent'],
        );

        final serviceFeeMax = _toDouble(
          data['buyerServiceFeeMax'],
        );

        final freeCampaignEnabled =
            data['freeCampaignEnabled'] == true;

        final campaignStart =
            _dateFromValue(data['freeCampaignStart']);

        final campaignEnd =
            _dateFromValue(data['freeCampaignEnd']);

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.10),
                      ),
                      child: Icon(
                        Icons.monetization_on_outlined,
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BuyNova Monetization',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Control membership fees, sales commissions and free campaigns.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ======================================================
            // MEMBERSHIP FEES
            // ======================================================

            _detailCard(
              title: 'Membership Fees',
              icon: Icons.card_membership_outlined,
              children: [
                _monetizationSettingTile(
                  icon: Icons.storefront_outlined,
                  title: 'Seller Membership Fee',
                  subtitle:
                      'Amount required when a user joins as a Seller.',
                  value: '৳${sellerFee.toStringAsFixed(2)}',
                  onTap: () => _editMonetizationNumber(
                    field: 'sellerMembershipFee',
                    title: 'Seller Membership Fee',
                    currentValue: sellerFee,
                    min: 0,
                    max: 1000000,
                    isPercent: false,
                  ),
                ),
                const Divider(height: 1),
                _monetizationSettingTile(
                  icon: Icons.business_center_outlined,
                  title: 'Reseller Membership Fee',
                  subtitle:
                      'Amount required when a user joins as a Reseller.',
                  value: '৳${resellerFee.toStringAsFixed(2)}',
                  onTap: () => _editMonetizationNumber(
                    field: 'resellerMembershipFee',
                    title: 'Reseller Membership Fee',
                    currentValue: resellerFee,
                    min: 0,
                    max: 1000000,
                    isPercent: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ======================================================
            // COMMISSION (one percentage for every sale)
            // ======================================================

            _detailCard(
              title: 'BuyNova Commission',
              icon: Icons.percent_outlined,
              children: [
                _commissionStepper(commission),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.06),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'BuyNova takes this percentage from whoever sells: '
                          'the seller\'s earning on their own products, or the '
                          'reseller\'s profit on reseller products. It is taken '
                          'when an order is delivered, using the rate set at that time. '
                          'The commission is credited to the admin wallet '
                          '(see Profile → BuyNova Income).',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ======================================================
            // BUYER SERVICE FEE (charged to the buyer on every order)
            // ======================================================

            _detailCard(
              title: 'Buyer Service Fee',
              icon: Icons.receipt_long_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Charge buyers a service fee',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    serviceFeeEnabled
                        ? 'Added to the total of every NEW order.'
                        : 'No service fee is charged.',
                  ),
                  value: serviceFeeEnabled,
                  onChanged: (value) async {
                    await _updateMonetizationSettings({
                      'buyerServiceFeeEnabled': value,
                    });
                  },
                ),
                const Divider(height: 1),
                _monetizationSettingTile(
                  icon: Icons.percent_outlined,
                  title: 'Service Fee Percentage',
                  subtitle:
                      'Taken from what the buyer pays for the goods (after coupon). Not on delivery fee.',
                  value: '${serviceFeePercent.toStringAsFixed(2)}%',
                  onTap: () => _editMonetizationNumber(
                    field: 'buyerServiceFeePercent',
                    title: 'Buyer Service Fee',
                    currentValue: serviceFeePercent,
                    min: 0,
                    max: 100,
                    isPercent: true,
                  ),
                ),
                const Divider(height: 1),
                _monetizationSettingTile(
                  icon: Icons.vertical_align_top_outlined,
                  title: 'Maximum Fee Per Order',
                  subtitle: 'Cap for one order. Set 0 for no cap.',
                  value: serviceFeeMax > 0
                      ? '৳${serviceFeeMax.toStringAsFixed(0)}'
                      : 'No cap',
                  onTap: () => _editMonetizationNumber(
                    field: 'buyerServiceFeeMax',
                    title: 'Maximum Service Fee Per Order',
                    currentValue: serviceFeeMax,
                    min: 0,
                    max: 1000000,
                    isPercent: false,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.06),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The fee is shown to the buyer at checkout and added '
                          'to the order total. BuyNova receives it in the admin '
                          'wallet when the order is delivered. If the order is '
                          'cancelled, the fee is refunded to the buyer.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ======================================================
            // FREE CAMPAIGN
            // ======================================================

            _detailCard(
              title: 'Free Membership Campaign',
              icon: Icons.campaign_outlined,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Free Membership',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    freeCampaignEnabled
                        ? 'Users can join without paying the membership fee during the campaign.'
                        : 'Normal membership fees are active.',
                  ),
                  value: freeCampaignEnabled,
                  onChanged: (value) async {
                    await _updateMonetizationSettings({
                      'freeCampaignEnabled': value,
                    });
                  },
                ),

                const Divider(height: 1),

                _monetizationSettingTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Campaign Start',
                  subtitle: campaignStart.millisecondsSinceEpoch == 0
                      ? 'Not set'
                      : _formatDate(campaignStart),
                  value: 'Change',
                  onTap: () => _selectCampaignDate(
                    field: 'freeCampaignStart',
                    currentDate:
                        campaignStart.millisecondsSinceEpoch == 0
                            ? DateTime.now()
                            : campaignStart,
                  ),
                ),

                const Divider(height: 1),

                _monetizationSettingTile(
                  icon: Icons.event_outlined,
                  title: 'Campaign End',
                  subtitle: campaignEnd.millisecondsSinceEpoch == 0
                      ? 'Not set'
                      : _formatDate(campaignEnd),
                  value: 'Change',
                  onTap: () => _selectCampaignDate(
                    field: 'freeCampaignEnd',
                    currentDate:
                        campaignEnd.millisecondsSinceEpoch == 0
                            ? DateTime.now()
                            : campaignEnd,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.06),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Free campaign affects membership registration only. '
                          'Sales commission settings remain separate.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ======================================================
            // CURRENT CONFIGURATION
            // ======================================================

            _detailCard(
              title: 'Current Configuration',
              icon: Icons.fact_check_outlined,
              children: [
                _summaryRow(
                  'Seller Fee',
                  '৳${sellerFee.toStringAsFixed(2)}',
                ),
                _summaryRow(
                  'Reseller Fee',
                  '৳${resellerFee.toStringAsFixed(2)}',
                ),
                _summaryRow(
                  'BuyNova Commission',
                  '${commission.toStringAsFixed(2)}%',
                ),
                _summaryRow(
                  'Buyer Service Fee',
                  serviceFeeEnabled
                      ? '${serviceFeePercent.toStringAsFixed(2)}%'
                          '${serviceFeeMax > 0 ? ' (max ৳${serviceFeeMax.toStringAsFixed(0)})' : ''}'
                      : 'Off',
                ),
                _summaryRow(
                  'Free Campaign',
                  freeCampaignEnabled
                      ? 'Enabled'
                      : 'Disabled',
                ),
                _summaryRow(
                  'Campaign Start',
                  campaignStart.millisecondsSinceEpoch == 0
                      ? 'Not set'
                      : _formatDate(campaignStart),
                ),
                _summaryRow(
                  'Campaign End',
                  campaignEnd.millisecondsSinceEpoch == 0
                      ? 'Not set'
                      : _formatDate(campaignEnd),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _monetizationSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.08),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _commissionStepper(double value) {
    Future<void> change(double next) async {
      await _updateMonetizationSettings({
        'commissionPercent': next.clamp(0.0, 100.0).toDouble(),
      });
    }

    final primary = Theme.of(context).colorScheme.primary;

    final label = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);

    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Decrease by 1%',
          onPressed: value <= 0 ? null : () => change(value - 1),
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _editMonetizationNumber(
              field: 'commissionPercent',
              title: 'BuyNova Commission',
              currentValue: value,
              min: 0,
              max: 100,
              isPercent: true,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(
                    '$label%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap the number to type an exact value',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Increase by 1%',
          onPressed: value >= 100 ? null : () => change(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Future<void> _editMonetizationNumber({
    required String field,
    required String title,
    required double currentValue,
    required double min,
    required double max,
    required bool isPercent,
  }) async {
    final controller = TextEditingController(
      text: isPercent
          ? currentValue.toStringAsFixed(2)
          : currentValue.toStringAsFixed(0),
    );

    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: isPercent
                  ? 'Percentage'
                  : 'Amount in BDT',
              prefixText: isPercent ? null : '৳ ',
              suffixText: isPercent ? '%' : null,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed =
                    double.tryParse(controller.text.trim());

                if (parsed == null ||
                    parsed < min ||
                    parsed > max) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isPercent
                            ? 'Enter a value between $min% and $max%.'
                            : 'Enter a value between ৳$min and ৳$max.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(context, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (value == null) return;

    await _updateMonetizationSettings({
      field: value,
    });
  }

  Future<void> _selectCampaignDate({
    required String field,
    required DateTime currentDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2026),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    final selectedDate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      field == 'freeCampaignStart' ? 0 : 23,
      field == 'freeCampaignStart' ? 0 : 59,
      field == 'freeCampaignStart' ? 0 : 59,
    );

    await _updateMonetizationSettings({
      field: Timestamp.fromDate(selectedDate),
    });
  }

  Future<void> _updateMonetizationSettings(
    Map<String, dynamic> updates,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null ||
          (user.email ?? '').toLowerCase() !=
              kAdminEmail.toLowerCase()) {
        throw Exception(
          'Only the BuyNova admin can change monetization settings.',
        );
      }

      await _db.doc(_AdminPanelPageState._monetizationPath).set(
        {
          ...updates,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
          'updatedByEmail': user.email,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'BuyNova monetization settings updated.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update settings: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}
