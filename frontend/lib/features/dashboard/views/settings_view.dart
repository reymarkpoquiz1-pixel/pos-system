import 'package:flutter/material.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:pos/core/constants/config.dart';
import 'package:pos/core/widgets/dashboard_widgets.dart';

class SettingsView extends StatefulWidget {
  final VoidCallback onUpdate;
  final int userId;

  const SettingsView({
    super.key,
    required this.onUpdate,
    required this.userId,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  String? _logoUrl;
  bool _is2faEnabled = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('settings/get_store_settings?user_id=${widget.userId}');
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final s = data['settings'];
          final u = data['user_settings'];
          setState(() {
            _nameController.text = (s != null ? s['store_name'] : '') ?? '';
            _addressController.text = (s != null ? s['address'] : '') ?? '';
            _phoneController.text = (s != null ? s['phone'] : '') ?? '';
            _emailController.text = (s != null ? s['email'] : '') ?? '';
            _taxController.text = (s != null ? s['tax_rate'].toString() : '0.00');
            _logoUrl = s != null ? s['logo_url'] : null;
            _is2faEnabled = u != null ? u['is_2fa_enabled'].toString() == '1' : false;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server Error: ${data['message'] ?? 'Settings table missing or empty'}'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _fetchSettings),
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        String errorMsg = 'Failed to connect to server (Status: ${response.statusCode})';
        if (response.statusCode == 403) errorMsg = 'Forbidden: Admin access only.';
        if (response.statusCode == 401) errorMsg = 'Session expired. Please login again.';
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Settings Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final response = await ApiService.post(
        'settings/update_store_settings',
        {
          'store_name': _nameController.text,
          'address': _addressController.text,
          'phone': _phoneController.text,
          'email': _emailController.text,
          'tax_rate': double.tryParse(_taxController.text) ?? 0.0,
        },
      );

      final data = json.decode(response.body);
      if (data['success']) {
        if (mounted) {
          widget.onUpdate();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings updated!'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadLogo() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      final response = await ApiService.upload('settings/upload_logo', image, 'logo');
      final data = json.decode(response.body);
      
      if (data['success']) {
        setState(() {
          _logoUrl = data['logo_url'];
        });
        widget.onUpdate(); // Refresh dashboard
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store logo updated!'), backgroundColor: Colors.green));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${data['message']}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggle2fa(bool value) async {
    setState(() => _is2faEnabled = value);
    try {
      await ApiService.post('settings/update_user_security', {
        'is_2fa_enabled': value ? 1 : 0,
        'user_id': widget.userId,
      });
    } catch (e) {
      debugPrint('2FA Error: $e');
    }
  }

  Future<void> _runBackup() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting database backup...')));
    try {
      final response = await ApiService.get('settings/backup_db');
      final data = json.decode(response.body);
      if (data['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Backup Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color vibrantPink = Color(0xFFD68A96);
    const Color lightPinkBg = Color(0xFFFBECEF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7E6E9),
      body: buildThemedBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚙️ System Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1C1B1F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: vibrantPink))
                    : SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: lightPinkBg.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: vibrantPink.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT COLUMN: STORE CONFIGURATION
                                  Expanded(
                                    flex: 5,
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Store Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
                                          const SizedBox(height: 24),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildLogoUploader(vibrantPink),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    _buildModernField(_nameController, 'Store Name', Icons.storefront_outlined, vibrantPink),
                                                    const SizedBox(height: 12),
                                                    _buildModernField(_addressController, 'Address', Icons.location_on_outlined, vibrantPink),
                                                    const SizedBox(height: 12),
                                                    _buildModernField(_phoneController, 'Phone Number', Icons.phone_outlined, vibrantPink),
                                                    const SizedBox(height: 12),
                                                    _buildModernField(_emailController, 'Email', Icons.email_outlined, vibrantPink),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 40),
                                          const Text('Ibahagi ang Detalye', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5C5C5C))),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              _buildSocialIcon(Icons.facebook, vibrantPink),
                                              const SizedBox(width: 16),
                                              _buildSocialIcon(Icons.alternate_email, vibrantPink),
                                              const SizedBox(width: 16),
                                              _buildSocialIcon(Icons.share, vibrantPink),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 48),

                                  // RIGHT COLUMN: SHORTCUTS AND OTHER SETTINGS
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Mabilis na Shortcuts (AI)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F))),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildShortcutItem(Icons.sync, 'Update\nTax Rate', vibrantPink),
                                            _buildShortcutItem(Icons.assignment_outlined, 'View\nOrders', vibrantPink),
                                            _buildShortcutItem(Icons.edit_outlined, 'Edit\nProducts', vibrantPink),
                                            _buildShortcutItem(Icons.bar_chart_outlined, 'Store\nAnalytics', vibrantPink),
                                          ],
                                        ),
                                        const SizedBox(height: 40),
                                        _buildModernField(_taxController, 'Tax Rate (%)', Icons.percent, vibrantPink, isNumber: true),
                                        const SizedBox(height: 32),
                                        const Text('Security (2FA)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5C5C5C))),
                                        const SizedBox(height: 8),
                                        Material(
                                          color: Colors.transparent,
                                          child: SwitchListTile(
                                            title: const Text('Email OTP Verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                            subtitle: const Text('Require a code sent to your email when logging in.', style: TextStyle(fontSize: 11)),
                                            value: _is2faEnabled,
                                            activeThumbColor: vibrantPink,
                                            onChanged: _toggle2fa,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        const Text('Maintenance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5C5C5C))),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: _runBackup,
                                          icon: const Icon(Icons.backup_outlined),
                                          label: const Text('Manual Database Backup'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueGrey,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size.fromHeight(45),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        const Text('Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5C5C5C))),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(color: vibrantPink.withValues(alpha: 0.4)),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: 'Light Mode',
                                              isExpanded: true,
                                              icon: const Icon(Icons.keyboard_arrow_down, color: vibrantPink),
                                              items: ['Light Mode', 'Dark Mode'].map((String value) {
                                                return DropdownMenuItem<String>(
                                                  value: value,
                                                  child: Row(
                                                    children: [
                                                      Icon(value == 'Light Mode' ? Icons.wb_sunny_outlined : Icons.nightlight_outlined, size: 18, color: vibrantPink),
                                                      const SizedBox(width: 12),
                                                      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (_) {},
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 40),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 55,
                                          child: ElevatedButton(
                                            onPressed: _isSaving ? null : _saveSettings,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: vibrantPink,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                            ),
                                            child: _isSaving 
                                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                              : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoUploader(Color themeColor) {
    return Column(
      children: [
        GestureDetector(
          onTap: _uploadLogo,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: themeColor.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(color: themeColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  if (_logoUrl != null)
                    Image.network(
                      '$baseUrl/$_logoUrl',
                      fit: BoxFit.contain,
                      width: 140,
                      height: 140,
                      errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.storefront_outlined, size: 48, color: themeColor.withValues(alpha: 0.5))),
                    )
                  else
                    Center(child: Icon(Icons.storefront_outlined, size: 48, color: themeColor.withValues(alpha: 0.5))),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.white.withValues(alpha: 0.9),
                      child: Text(
                        _nameController.text.isEmpty ? 'Store Name' : _nameController.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, Color themeColor, {bool isNumber = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C1B1F)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: themeColor.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w700),
          prefixIcon: Icon(icon, color: themeColor, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: themeColor.withValues(alpha: 0.4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: themeColor.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: themeColor, width: 1.5)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildShortcutItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1C1B1F)),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: themeColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: themeColor.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Icon(icon, size: 18, color: themeColor),
    );
  }

}
