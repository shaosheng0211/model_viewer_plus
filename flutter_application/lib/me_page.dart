import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'custom_app_bar.dart';
import 'order_status_page.dart';

const Color primaryColor = Color.fromARGB(255, 112, 210, 255);

class MePage extends StatefulWidget {
  @override
  _MePageState createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  // Profile data
  String username = "Username";
  String gender = "";
  String birthday = "";
  String phone = "";
  String email = "";

  // Controllers for editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Replace with your real logic to get the user ID!
  final String userId = "demo_user";

  @override
  void dispose() {
    _nameController.dispose();
    _genderController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    _nameController.text = username;
    _genderController.text = gender;
    _birthdayController.text = birthday;
    _phoneController.text = phone;
    _emailController.text = email;

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text("Edit Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: _genderController,
                decoration: InputDecoration(labelText: "Gender"),
              ),
              TextField(
                controller: _birthdayController,
                decoration: InputDecoration(labelText: "Birthday"),
                onTap: () async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(birthday) ?? DateTime(2000),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _birthdayController.text = picked.toIso8601String().split("T").first;
                  }
                },
              ),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: "Phone"),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text("Save", style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    DatabaseReference userRef = FirebaseDatabase.instance.ref("users/$userId");
    await userRef.set({
      "username": _nameController.text,
      "gender": _genderController.text,
      "birthday": _birthdayController.text,
      "phone": _phoneController.text,
      "email": _emailController.text,
    });

    setState(() {
      username = _nameController.text;
      gender = _genderController.text;
      birthday = _birthdayController.text;
      phone = _phoneController.text;
      email = _emailController.text;
    });

    Navigator.pop(context); // Close bottom sheet
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Profile updated!")));
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundImage: AssetImage('assets/avatar.png'), // Replace if you have user avatars
            child: Icon(Icons.person, size: 36, color: Colors.white),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showEditProfileDialog,
                      child: Icon(Icons.edit, size: 18, color: primaryColor),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text("My Profile", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusButton(
    IconData icon,
    String label,
    int index,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderStatusPage(initialTab: index),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(10), // smaller
            child: Icon(icon, color: color, size: 22), // smaller icon
          ),
          SizedBox(height: 7),
          Text(label, style: TextStyle(fontSize: 12)), // smaller font
        ],
      ),
    );
  }

  Widget _buildMyOrdersSection() {
    // REMOVE "History" entry here:
    List<Map<String, dynamic>> sections = [
      {"icon": Icons.payment, "label": "To Pay", "color": Colors.deepOrange},
      {"icon": Icons.local_shipping, "label": "To Ship", "color": Colors.blueAccent},
      {"icon": Icons.inventory_2, "label": "To Receive", "color": Colors.green},
      {"icon": Icons.check_circle_outline, "label": "Completed", "color": Colors.purple},
      {"icon": Icons.assignment_return, "label": "Return/Refund", "color": Colors.redAccent},
      // {"icon": Icons.history, "label": "History", "color": Colors.teal}, // <--- removed
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text("My Orders", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: sections.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, i) {
              return _buildOrderStatusButton(
                sections[i]["icon"],
                sections[i]["label"],
                i,
                sections[i]["color"],
              );
            },
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // <-- Apply background color
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(title: 'Me'),
            _buildProfileSection(),
            Divider(),
            _buildMyOrdersSection(),
            Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}

