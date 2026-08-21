import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../booking_provider.dart';
import '../models/customer_profile_models.dart';
import '../theme.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  void _openAddAddressModal(BuildContext context, [CustomerAddress? editAddress]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAddressBottomSheet(editingAddress: editAddress),
    );
  }

  void _confirmDeleteAddress(BuildContext context, WidgetRef ref, CustomerAddress addr, int totalCount) {
    if (totalCount <= 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Text('Last Service Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Deleting your only service address will cause your profile completion score to drop to 75% and prevent technician dispatch. Are you sure you want to delete it?',
            style: TextStyle(fontSize: 13, color: kSecondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Address', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRedError),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(bookingProvider.notifier).deleteCustomerAddress(addr.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address deleted. Profile is now incomplete.')),
                );
              },
              child: const Text('Delete Anyway'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "${addr.formattedAddress}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRedError),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(bookingProvider.notifier).deleteCustomerAddress(addr.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address removed.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(bookingProvider);
    final addresses = appState.profile.addresses;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Saved Addresses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: kPrimaryText,
        elevation: 0,
      ),
      body: addresses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEEF3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_off_outlined, size: 40, color: kBrandPrimary),
                    ),
                    const SizedBox(height: 20),
                    const Text('No Addresses Saved', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Please add at least one service location for verified technician dispatch.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: kSecondaryText),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _openAddAddressModal(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Service Address'),
                      style: ElevatedButton.styleFrom(backgroundColor: kBlack, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length + 1,
              separatorBuilder: (context, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == addresses.length) {
                  return OutlinedButton.icon(
                    onPressed: () => _openAddAddressModal(context),
                    icon: const Icon(Icons.add_location_alt_outlined, color: kBrandPrimary),
                    label: const Text('+ Add New Service Address', style: TextStyle(fontWeight: FontWeight.bold, color: kBrandPrimary)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: kBrandPrimary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }

                final addr = addresses[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: addr.isPrimary ? kBrandPrimary : const Color(0xFFD9E2F2),
                      width: addr.isPrimary ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                addr.addressType == AddressType.home
                                    ? Icons.home_rounded
                                    : addr.addressType == AddressType.work
                                        ? Icons.work_rounded
                                        : Icons.location_on_rounded,
                                color: kBrandPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                addr.typeLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: kPrimaryText),
                              ),
                            ],
                          ),
                          if (addr.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                              ),
                            )
                          else
                            InkWell(
                              onTap: () => ref.read(bookingProvider.notifier).setPrimaryAddress(addr.id),
                              child: const Text(
                                'Set as Primary',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBrandPrimary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        addr.formattedAddress,
                        style: const TextStyle(fontSize: 13, color: kSecondaryText, height: 1.35),
                      ),
                      if (addr.landmark.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Landmark: ${addr.landmark}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _openAddAddressModal(context, addr),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit', style: TextStyle(fontSize: 12.5)),
                            style: TextButton.styleFrom(foregroundColor: kBrandPrimary),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => _confirmDeleteAddress(context, ref, addr, addresses.length),
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Delete', style: TextStyle(fontSize: 12.5)),
                            style: TextButton.styleFrom(foregroundColor: kRedError),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─── ADD / EDIT ADDRESS MODAL ───

class AddAddressBottomSheet extends ConsumerStatefulWidget {
  final CustomerAddress? editingAddress;
  const AddAddressBottomSheet({super.key, this.editingAddress});

  @override
  ConsumerState<AddAddressBottomSheet> createState() => _AddAddressBottomSheetState();
}

class _AddAddressBottomSheetState extends ConsumerState<AddAddressBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _houseCtrl;
  late TextEditingController _streetCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _pinCtrl;
  late TextEditingController _landmarkCtrl;
  AddressType _type = AddressType.home;
  bool _isPrimary = true;
  bool _isLocating = false;
  double? _acquiredLat;
  double? _acquiredLng;

  @override
  void initState() {
    super.initState();
    final edit = widget.editingAddress;
    _houseCtrl = TextEditingController(text: edit?.houseFlat ?? '');
    _streetCtrl = TextEditingController(text: edit?.street ?? '');
    _areaCtrl = TextEditingController(text: edit?.area ?? '');
    _cityCtrl = TextEditingController(text: edit?.city ?? 'Bengaluru');
    _stateCtrl = TextEditingController(text: edit?.state ?? 'Karnataka');
    _pinCtrl = TextEditingController(text: edit?.postalCode ?? '560024');
    _landmarkCtrl = TextEditingController(text: edit?.landmark ?? '');
    _type = edit?.addressType ?? AddressType.home;
    _isPrimary = edit?.isPrimary ?? true;
    _acquiredLat = edit?.latitude;
    _acquiredLng = edit?.longitude;
  }

  @override
  void dispose() {
    _houseCtrl.dispose();
    _streetCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _landmarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _autofillViaGPS() async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable device GPS / Location services.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied.')),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions permanently denied in settings.')),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      _acquiredLat = pos.latitude;
      _acquiredLng = pos.longitude;

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=18&addressdetails=1',
        );
        final response = await http.get(url, headers: {
          'User-Agent': 'BookUrTechnician/1.0 (contact@bookurtechnician.com)',
        }).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final addressObj = data['address'] as Map<String, dynamic>?;

          final road = addressObj?['road'] ?? addressObj?['street'] ?? '';
          final houseNumber = addressObj?['house_number'] ?? addressObj?['building'] ?? '';
          final suburb = addressObj?['suburb'] ?? addressObj?['neighbourhood'] ?? addressObj?['residential'] ?? addressObj?['subdistrict'] ?? '';
          final city = addressObj?['city'] ?? addressObj?['town'] ?? addressObj?['county'] ?? 'Bengaluru';
          final state = addressObj?['state'] ?? 'Karnataka';
          final postcode = addressObj?['postcode'] ?? '560001';

          if (mounted) {
            setState(() {
              if (houseNumber.toString().isNotEmpty) {
                _houseCtrl.text = 'Premises $houseNumber';
              } else if (_houseCtrl.text.isEmpty) {
                _houseCtrl.text = 'Flat / House 101';
              }
              if (road.toString().isNotEmpty) {
                _streetCtrl.text = road.toString();
              }
              if (suburb.toString().isNotEmpty) {
                _areaCtrl.text = suburb.toString();
              }
              _cityCtrl.text = city.toString();
              _stateCtrl.text = state.toString();
              _pinCtrl.text = postcode.toString();
            });
          }
        }
      } catch (geocodingErr) {
        debugPrint('Geocoding fallback: $geocodingErr');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Live GPS coordinates & address acquired!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS acquisition warning: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(bookingProvider).profile;
    final now = DateTime.now();

    final address = CustomerAddress(
      id: widget.editingAddress?.id ?? 'addr_${now.millisecondsSinceEpoch}',
      customerId: profile.customerId,
      addressType: _type,
      houseFlat: _houseCtrl.text.trim(),
      street: _streetCtrl.text.trim(),
      area: _areaCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      postalCode: _pinCtrl.text.trim(),
      landmark: _landmarkCtrl.text.trim(),
      latitude: _acquiredLat ?? 12.9716,
      longitude: _acquiredLng ?? 77.5946,
      isPrimary: _isPrimary,
      createdAt: widget.editingAddress?.createdAt ?? now,
      updatedAt: now,
    );

    if (widget.editingAddress != null) {
      ref.read(bookingProvider.notifier).updateCustomerAddress(address);
    } else {
      ref.read(bookingProvider.notifier).addCustomerAddress(address);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.editingAddress != null ? 'Address updated!' : 'New address saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
      margin: EdgeInsets.only(top: mediaQuery.padding.top),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFD9E2F2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.editingAddress != null ? 'Edit Service Address' : 'Add Service Address',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryText),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Body Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardHeight + 20),
                children: [
                  // Fast Location Action
                  InkWell(
                    onTap: _isLocating ? null : _autofillViaGPS,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF3FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD9E2F2)),
                      ),
                      child: Row(
                        children: [
                          if (_isLocating)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kBrandPrimary),
                            )
                          else
                            const Icon(Icons.my_location_rounded, color: kBrandPrimary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _isLocating ? 'Acquiring GPS Location...' : 'Use Current GPS Location',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kBrandPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text('Address Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTypeChoice(AddressType.home, 'Home 🏠'),
                      const SizedBox(width: 10),
                      _buildTypeChoice(AddressType.work, 'Work 💼'),
                      const SizedBox(width: 10),
                      _buildTypeChoice(AddressType.other, 'Other 📍'),
                    ],
                  ),

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _houseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'House / Flat / Building No. *',
                      hintText: 'e.g. Flat 402, Block A',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _streetCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Street / Road *',
                      hintText: 'e.g. 14th Main, Bellary Road',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _areaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Area / Locality *',
                      hintText: 'e.g. Hebbal',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),

                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(labelText: 'City *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _pinCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(labelText: 'PIN Code *', counterText: ''),
                          validator: (v) => (v == null || v.trim().length != 6) ? '6 digits required' : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _landmarkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Landmark (Optional)',
                      hintText: 'e.g. Near Metro Station / Flyover',
                    ),
                  ),

                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as Primary Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('Use as default destination for technician bookings', style: TextStyle(fontSize: 11.5)),
                    value: _isPrimary,
                    activeThumbColor: kBrandPrimary,
                    onChanged: (val) => setState(() => _isPrimary = val),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBlack,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        widget.editingAddress != null ? 'Update Address' : 'Save Address',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChoice(AddressType type, String label) {
    final isSelected = _type == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _type = type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kBrandPrimary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? kBrandPrimary : const Color(0xFFD9E2F2)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : kPrimaryText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
