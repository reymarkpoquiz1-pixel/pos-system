import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:pos/core/services/api_service.dart';
import 'package:pos/core/constants/config.dart';

class AdminUserManagementForm extends StatefulWidget {
  final VoidCallback? onAccountCreated;
  final Map<String, dynamic>? employeeData;

  const AdminUserManagementForm({super.key, this.onAccountCreated, this.employeeData});

  static void show(BuildContext context, {VoidCallback? onAccountCreated, Map<String, dynamic>? employeeData}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: AdminUserManagementForm(
            onAccountCreated: onAccountCreated,
            employeeData: employeeData,
          ),
        ),
      ),
    );
  }

  @override
  State<AdminUserManagementForm> createState() => _AdminUserManagementFormState();
}

class _AdminUserManagementFormState extends State<AdminUserManagementForm> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _terminalController;
  String _selectedRole = 'Staff';
  String _selectedGender = 'Male';
  bool _isLoading = false;
  bool _obscurePassword = true;

  Uint8List? _imageBytes;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final String initialName = widget.employeeData != null 
        ? '${widget.employeeData!['first_name'] ?? ''} ${widget.employeeData!['last_name'] ?? ''}'.trim() 
        : '';
    _fullNameController = TextEditingController(text: initialName);
    _emailController = TextEditingController(text: widget.employeeData?['email']?.toString() ?? '');
    _usernameController = TextEditingController(text: widget.employeeData?['username']?.toString() ?? '');
    _passwordController = TextEditingController();
    _terminalController = TextEditingController(text: widget.employeeData?['terminal_id']?.toString() ?? '');
    _selectedRole = widget.employeeData?['role']?.toString() ?? 'Staff';
    _selectedGender = widget.employeeData?['gender']?.toString() ?? 'Male';
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  void _saveAccount() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final terminalId = _terminalController.text.trim();

    final isEditing = widget.employeeData != null;

    if (email.isEmpty || fullName.isEmpty || username.isEmpty || terminalId.isEmpty || (!isEditing && password.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields!'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Validation for Full Name (must contain at least one space)
    if (!fullName.trim().contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mangyaring ilagay ang buong pangalan (hal: Juan Dela Cruz) na may space sa gitna.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? base64Image;
      if (_imageBytes != null) {
        base64Image = base64Encode(_imageBytes!);
      }

      final Map<String, dynamic> body = {
        'name': fullName,
        'email': email,
        'username': username,
        'role': _selectedRole,
        'gender': _selectedGender,
        'terminal_id': terminalId,
        'admin_name': 'Admin',
      };

      if (base64Image != null) {
        if (isEditing) {
          body['profile_image_base64'] = base64Image;
        } else {
          body['image'] = base64Image;
        }
      }

      if (password.isNotEmpty) body['password'] = password;
      if (isEditing) body['user_id'] = widget.employeeData!['user_id'];

      final endpoint = isEditing ? 'employees/update_staff' : 'register';
      
      final response = await ApiService.post(
        endpoint,
        body,
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved Successfully!'), backgroundColor: Colors.green));
        widget.onAccountCreated?.call();
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Error'), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employeeData != null;
    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? 'Edit Staff Account' : 'Staff Registration', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _imageBytes != null 
                        ? MemoryImage(_imageBytes!) 
                        : (widget.employeeData?['profile_image'] != null 
                            ? NetworkImage(widget.employeeData!['profile_image'].toString().startsWith('http')
                                ? widget.employeeData!['profile_image']
                                : (widget.employeeData!['profile_image'].toString().startsWith('uploads/')
                                    ? '$baseUrl/${widget.employeeData!['profile_image']}'
                                    : '$baseUrl/uploads/${widget.employeeData!['profile_image']}')) as ImageProvider
                            : null),
                    onBackgroundImageError: (widget.employeeData?['profile_image'] != null || _imageBytes != null)
                        ? (exception, stackTrace) {
                            debugPrint('Staff register profile image error: $exception');
                          }
                        : null,
                    child: (_imageBytes == null && widget.employeeData?['profile_image'] == null) 
                        ? const Icon(Icons.person, size: 40, color: Colors.grey) 
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickImage,
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.purple,
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            _buildTextField(_fullNameController, 'Full Name', Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField(_emailController, 'Email Address', Icons.email_outlined),
            const SizedBox(height: 16),
            _buildTextField(_usernameController, 'Username', Icons.alternate_email),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField('Role', _selectedRole, ['Staff', 'Admin'], (v) => setState(() => _selectedRole = v!)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField('Gender', _selectedGender, ['Male', 'Female'], (v) => setState(() => _selectedGender = v!)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: isEditing ? 'New password (optional)' : 'Enter password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(_terminalController, 'Terminal / Counter No.', Icons.computer),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveAccount,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                      child: Text(isEditing ? 'Update Account' : 'Create Account', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: label,
            prefixIcon: Icon(icon, size: 18),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
