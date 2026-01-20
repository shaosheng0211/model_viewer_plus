import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'cart.dart';
import 'mock_payment_gateway_page.dart';

const primaryColor = Color.fromARGB(255, 112, 210, 255);

class CheckoutPage extends StatefulWidget {
  final Map<String, Map<String, dynamic>> selectedItems;
  final Map<String, dynamic> allProducts;

  CheckoutPage({required this.selectedItems, required this.allProducts});

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String shippingMethod = 'Normal';
  String paymentMethod = 'Select payment option';
  String address = '';

  List<Map<String, dynamic>> availableVouchers = [];
  bool isLoadingVouchers = true;

  DateTime? selectedDeliveryDate;
  TimeOfDay? selectedDeliveryTime;
  final TimeOfDay deliveryStart = TimeOfDay(hour: 9, minute: 0);
  final TimeOfDay deliveryEnd = TimeOfDay(hour: 18, minute: 0);
  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    fetchVouchersFromFirebase();
    _loadSelectedAddress();
  }

  Future<void> _loadSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      address = prefs.getString('selected_address') ?? '';
    });
  }

  Future<void> fetchVouchersFromFirebase() async {
    final ref = FirebaseDatabase.instance.ref('vouchers');
    final event = await ref.once();
    final data = event.snapshot.value as Map<dynamic, dynamic>?;

    availableVouchers = [];
    if (data != null) {
      data.forEach((key, value) {
        availableVouchers.add({
          'id': value['id'],
          'type': value['type'],
          'desc': value['desc'],
          'discount': (value['discount'] as num).toDouble(),
          'minSpend': (value['minSpend'] as num).toDouble(),
          'validTill': DateTime.parse(value['validTill']),
        });
      });
    }
    setState(() {
      isLoadingVouchers = false;
    });
  }

  List<Map<String, dynamic>> selectedVouchers = [];

  double get merchandiseSubtotal {
    return widget.selectedItems.values.fold(
      0.0,
      (sum, item) =>
          sum +
          (item['price'] is int
              ? (item['price'] as int).toDouble()
              : item['price'] as double) *
          (item['quantity'] as int),
    );
  }

  double get shippingSubtotal {
    switch (shippingMethod) {
      case 'Urgent':
        return 5.0;
      case 'Pickup':
        return 0.0;
      default:
        return 3.0;
    }
  }

  double get shippingSST => shippingSubtotal * 0.06;

  double get voucherDiscount =>
      selectedVouchers.fold(0.0, (sum, v) => sum + (v['discount'] as double));

  double get totalPayment =>
      merchandiseSubtotal + shippingSubtotal + shippingSST - voucherDiscount;

  String _getSelectedVoucherText() {
    if (selectedVouchers.isEmpty) return "No voucher applied";
    return selectedVouchers.map((v) => v['type']).join(', ');
  }

  int get totalItemQuantity {
    return widget.selectedItems.values
        .fold<int>(0, (sum, item) => sum + (item['quantity'] as int));
  }

  Future<String> _saveOrderToFirebase({required String status}) async {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    List<Map<String, dynamic>> itemsList = widget.selectedItems.entries.map((e) {
      final item = e.value;
      final product = widget.allProducts[e.key] ?? {};
      return {
        'name': item['name'] ?? '',
        'model': item['model'] ?? product['model'] ?? '',
        'description': item['description'] ?? product['description'] ?? '',
        'option': item['option'] ?? '',
        'quantity': item['quantity'] ?? 0,
        'price': item['price'] ?? 0.0,
      };
    }).toList();

    // Convert validTill to string
    final selectedVouchersJson = selectedVouchers.map((voucher) {
      return {
        ...voucher,
        'validTill': (voucher['validTill'] is DateTime)
            ? (voucher['validTill'] as DateTime).toIso8601String()
            : voucher['validTill'],
      };
    }).toList();

    final orderData = {
      'shipping_address': address,
      'items': itemsList,
      'shipping_option': shippingMethod,
      'selected_vouchers': selectedVouchersJson,
      'delivery_datetime': selectedDeliveryDate != null && selectedDeliveryTime != null
          ? DateTime(
              selectedDeliveryDate!.year,
              selectedDeliveryDate!.month,
              selectedDeliveryDate!.day,
              selectedDeliveryTime!.hour,
              selectedDeliveryTime!.minute,
            ).toIso8601String()
          : null,
      'voucher_discount': voucherDiscount,
      'payment_option': paymentMethod,
      'payment_details': {
        'merchandise_subtotal': merchandiseSubtotal,
        'shipping_subtotal': shippingSubtotal,
        'shipping_sst': shippingSST,
        'voucher_discount': voucherDiscount,
        'total_payment': totalPayment,
      },
      'order_time': DateTime.now().toIso8601String(),
      'status': status, // Use the parameter here
    };

    final database = FirebaseDatabase.instance.ref();
    await database.child('orders').child(orderId).set(orderData);

    return orderId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text('Checkout'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Shipping Address"),
            ListTile(
              title: Text("Shipping Address"),
              subtitle: Text(address.isEmpty ? "No address selected" : address),
              trailing: Icon(Icons.chevron_right),
              onTap: () async {
                final selectedAddress = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SelectAddressPage(currentAddress: address),
                  ),
                );
                if (selectedAddress != null && selectedAddress.isNotEmpty) {
                  setState(() {
                    address = selectedAddress;
                  });

                  final prefs = await SharedPreferences.getInstance();
                  prefs.setString('selected_address', selectedAddress); // Save it here
                }
              },
            ),
            Divider(),

            _sectionTitle("Items"),
            ...widget.selectedItems.entries.map((entry) {
              final item = entry.value;
              final productId = entry.key;
              final product = widget.allProducts[productId] ?? {};
              final modelUrl = item['model'] ?? product['model'] ?? '';
              final optionText = item['option'] ?? '';

              return ListTile(
                leading: modelUrl.isNotEmpty
                    ? SizedBox(
                        height: 60,
                        width: 60,
                        child: ModelViewer(
                          src: modelUrl,
                          alt: item['name'],
                          ar: false,
                          autoRotate: true,
                          cameraControls: false,
                        ),
                      )
                    : null,
                title: Text(item['name']),
                subtitle: optionText.isNotEmpty
                    ? Text(
                        optionText,
                        style: TextStyle(fontSize: 12),
                      )
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "RM${item['price'].toStringAsFixed(2)}",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "x${item['quantity']}",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
            Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total ($totalItemQuantity) Item(s)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "RM${merchandiseSubtotal.toStringAsFixed(2)}",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Divider(),

            _sectionTitle("Shipping Option"),
            ListTile(
              title: Text("Shipping Option"),
              subtitle: Text(shippingMethod),
              trailing: Icon(Icons.chevron_right),
              onTap: () async {
                final selected = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SelectShippingMethodPage(
                      currentMethod: shippingMethod,
                    ),
                  ),
                );
                if (selected != null) {
                  setState(() {
                    shippingMethod = selected;
                  });
                }
              },
            ),
            Divider(),

            _sectionTitle("Delivery Date & Time"),
            ListTile(
              tileColor: selectedDeliveryDate != null
                  ? primaryColor.withOpacity(0.1)
                  : null,
              title: Text(
                "Delivery Date",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                selectedDeliveryDate != null
                    ? "${selectedDeliveryDate!.day.toString().padLeft(2, '0')}-${selectedDeliveryDate!.month.toString().padLeft(2, '0')}-${selectedDeliveryDate!.year}"
                    : shippingMethod == 'Urgent'
                        ? "Auto-set to tomorrow"
                        : "Select delivery date",
                style: TextStyle(
                  color: selectedDeliveryDate != null
                      ? Colors.black
                      : Colors.grey[600],
                ),
              ),
              trailing: Icon(
                Icons.calendar_today,
                color: primaryColor,
              ),
              onTap: shippingMethod == 'Urgent'
                  ? () {
                      final tomorrow = DateTime.now().add(Duration(days: 1));
                      setState(() {
                        selectedDeliveryDate = tomorrow;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Urgent delivery is set to tomorrow.")),
                      );
                    }
                  : () async {
                      final DateTime today = DateTime.now();
                      final DateTime tomorrow = today.add(Duration(days: 1));

                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDeliveryDate ?? today,
                        firstDate: today,
                        lastDate: today.add(Duration(days: 30)),
                        selectableDayPredicate: (day) {
                          if (shippingMethod == 'Normal') {
                            return !isSameDate(day, tomorrow);
                          }
                          return true;
                        },
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Color.fromARGB(255, 112, 210, 255), // Selected date, header
                                onPrimary: Colors.white, // Text on selected date
                                onSurface: Colors.black, // Default text
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Color.fromARGB(255, 112, 210, 255), // OK/Cancel
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        setState(() {
                          selectedDeliveryDate = picked;
                        });
                      }
                    },
            ),

            ListTile(
              tileColor: selectedDeliveryTime != null
                  ? primaryColor.withOpacity(0.1)
                  : null,
              title: Text(
                "Delivery Time",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                selectedDeliveryTime != null
                    ? "${selectedDeliveryTime!.format(context)}"
                    : "Select delivery time (between 9:00 AM and 6:00 PM)",
                style: TextStyle(
                  color: selectedDeliveryTime != null
                      ? Colors.black
                      : Colors.grey[600],
                ),
              ),
              trailing: Icon(Icons.access_time, color: primaryColor),
              onTap: () async {
                final TimeOfDay now = TimeOfDay.now();
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: selectedDeliveryTime ?? now,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Color.fromARGB(255, 112, 210, 255), // Dial & selected hour
                          onPrimary: Colors.white,
                          onSurface: Colors.black,
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: Color.fromARGB(255, 112, 210, 255),
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (picked != null) {
                  final int pickedMinutes = picked.hour * 60 + picked.minute;
                  final int start = 9 * 60;
                  final int end = 18 * 60;

                  if (pickedMinutes < start || pickedMinutes > end) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Please choose a time between 9:00 AM and 6:00 PM")),
                    );
                    return;
                  }

                  setState(() {
                    selectedDeliveryTime = picked;
                  });
                }
              },
            ),

            Divider(),

            _sectionTitle("Voucher"),
            isLoadingVouchers
              ? Center(child: CircularProgressIndicator())
              : ListTile(
                  title: Text("Voucher"),
                  subtitle: Text(_getSelectedVoucherText()),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await Navigator.push<List<Map<String, dynamic>>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectVoucherPage(
                          selectedVouchers: selectedVouchers,
                          availableVouchers: availableVouchers,
                          merchandiseSubtotal: merchandiseSubtotal,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        selectedVouchers = result;
                      });
                    }
                  },
                ),
            Divider(),


            _sectionTitle("Payment Option"),
            ListTile(
              title: Text("Payment Option"),
              subtitle: Text(paymentMethod),
              trailing: Icon(Icons.chevron_right),
              onTap: () async {
                final selectedMethod = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SelectPaymentMethodPage(currentMethod: paymentMethod),
                  ),
                );
                if (selectedMethod != null) {
                  setState(() {
                    paymentMethod = selectedMethod;
                  });
                }
              },
            ),
            Divider(),

            _sectionTitle("Payment Details"),
            _paymentDetailRow("Merchandise Subtotal", merchandiseSubtotal),
            _paymentDetailRow("Shipping (Excl. SST)", shippingSubtotal),
            _paymentDetailRow("Shipping SST (6%)", shippingSST),
            _paymentDetailRow("Voucher Discount", -voucherDiscount),
            Divider(),
            _paymentDetailRow("Total Payment", totalPayment, bold: true),
            SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                if (selectedDeliveryDate == null || selectedDeliveryTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please select a delivery date and time.")),
                  );
                  return;
                }

                // 1. Save order to Firebase with status "To Pay"
                final orderId = await _saveOrderToFirebase(status: "To Pay");

                // 2. Remove selected items from cart immediately
                final cart = Provider.of<Cart>(context, listen: false);
                cart.removeSelectedItems();

                // 3. Navigate to mock payment gateway page with all required arguments
                final paymentSuccess = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MockPaymentGatewayPage(
                      orderId: orderId,
                      totalPayment: totalPayment, // <-- from your CheckoutPage getter
                      paymentOption: paymentMethod, // <-- from your selected payment option
                    ),
                  ),
                );

                final database = FirebaseDatabase.instance.ref();

                if (paymentSuccess == true) {
                  // 4. If payment is successful, update order status to "To Ship"
                  await database.child('orders').child(orderId).update({'status': 'To Ship'});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Order Placed & Paid Successfully!")),
                  );
                  Navigator.pop(context); // Return to cart or main page
                } else {
                  // 5. If payment failed/cancelled, order stays in "To Pay"
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Payment not completed. Order is in 'To Pay'.")),
                  );
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Place Order", style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _paymentDetailRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text("RM${value.toStringAsFixed(2)}",
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class SelectAddressPage extends StatefulWidget {
  final String currentAddress;

  SelectAddressPage({required this.currentAddress});

  @override
  _SelectAddressPageState createState() => _SelectAddressPageState();
}

class _SelectAddressPageState extends State<SelectAddressPage> {
  List<String> addressList = [];

  late String selectedAddress;
  String? defaultAddress;

  @override
  void initState() {
    super.initState();
    selectedAddress = widget.currentAddress;
    _loadAddressFromFirebase();
  }

  void _loadAddressFromFirebase() async {
    final userId = "demo_user"; // Replace with real user ID
    final dbRef = FirebaseDatabase.instance.ref();

    final snapshot = await dbRef.child('users').child(userId).child('address').get();
    final defaultSnap = await dbRef.child('users').child(userId).child('default_address').get();

    if (snapshot.exists) {
      final newAddress = snapshot.value.toString();
      if (!addressList.contains(newAddress)) {
        addressList.add(newAddress);
      }
      selectedAddress = newAddress;
    }

    if (defaultSnap.exists) {
      setState(() {
        defaultAddress = defaultSnap.value.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text('Select Shipping Address'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: addressList.length,
              itemBuilder: (context, index) {
                final addr = addressList[index];
                return ListTile(
                  title: Row(
                    children: [
                      Expanded(child: Text(addr)),
                      if (addr == defaultAddress)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text('[Default]',
                              style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                        ),
                    ],
                  ),
                  leading: Radio<String>(
                    value: addr,
                    groupValue: selectedAddress,
                    activeColor: primaryColor,
                    onChanged: (value) {
                      setState(() {
                        selectedAddress = value!;
                      });
                      Navigator.pop(context, selectedAddress);
                    },
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async  {
                          setState(() {
                            if (addr == selectedAddress) {
                              selectedAddress = '';
                            }
                            addressList.removeAt(index);
                          });

                          final prefs = await SharedPreferences.getInstance();
                          prefs.setStringList('address_list', addressList);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Address deleted")),
                          );
                        },
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    final editedAddress = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditAddressPage(currentAddress: addr),
                      ),
                    );
                    if (editedAddress != null && editedAddress.isNotEmpty) {
                      setState(() {
                        addressList[index] = editedAddress;
                        selectedAddress = editedAddress;
                      });
                      Navigator.pop(context, selectedAddress);
                    }
                  },
                  onLongPress: () async {
                    final userId = "demo_user"; // Replace with actual user ID
                    final dbRef = FirebaseDatabase.instance.ref();
                    await dbRef.child('users').child(userId).child('default_address').set(addr);

                    setState(() {
                      defaultAddress = addr;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Set as default address")),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        final controller = TextEditingController();
                        return AlertDialog(
                          backgroundColor: Colors.white,
                          title: Text("Enter New Address"),
                          content: TextField(
                            controller: controller,
                            maxLines: 2,
                            decoration: InputDecoration(hintText: "Enter address here"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(foregroundColor: primaryColor),
                              child: Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, controller.text),
                              style: TextButton.styleFrom(foregroundColor: primaryColor),
                              child: Text("Add"),
                            ),
                          ],
                        );
                      },
                    );

                    if (result != null && result.trim().isNotEmpty) {
                      setState(() {
                        addressList.add(result.trim());
                        selectedAddress = result.trim();
                      });

                      final prefs = await SharedPreferences.getInstance();
                      prefs.setStringList('address_list', addressList);
                      Navigator.pop(context, selectedAddress);
                    }
                  },
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text("Add New Address", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 112, 210, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pickedAddress = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectAddressMapPage(
                          initialAddress: selectedAddress,
                        ),
                      ),
                    );
                    if (pickedAddress != null && pickedAddress.isNotEmpty) {
                      setState(() {
                        addressList.add(pickedAddress);
                        selectedAddress = pickedAddress;
                      });
                      Navigator.pop(context, selectedAddress);
                    }
                  },
                  icon: Icon(Icons.map, color: Colors.white),
                  label: Text("Pick Address on Map", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 112, 210, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditAddressPage extends StatefulWidget {
  final String currentAddress;

  EditAddressPage({required this.currentAddress});

  @override
  _EditAddressPageState createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentAddress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text('Edit Address'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _controller,
              decoration: InputDecoration(labelText: "Address"),
              maxLines: 2,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _controller.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromARGB(255, 112, 210, 255),
                shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Save",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectShippingMethodPage extends StatelessWidget {
  final String currentMethod;

  SelectShippingMethodPage({required this.currentMethod});

  final List<Map<String, String>> shippingOptions = [
    {
      'title': 'Normal',
      'desc': 'RM3.00 • Arrives in 2–3 working days\nPick any delivery date (except tomorrow)'
    },
    {
      'title': 'Urgent',
      'desc': 'RM5.00 • Arrives next working day\nDelivery date auto-set to tomorrow, only time is selectable'
    },
    {
      'title': 'Pickup',
      'desc': 'RM0.00 • Self-collect from store\nChoose pickup date and time'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text('Select Shipping Method'),
      ),
      body: ListView.builder(
        itemCount: shippingOptions.length,
        itemBuilder: (context, index) {
          final option = shippingOptions[index];
          return RadioListTile<String>(
            title: Text(option['title']!),
            subtitle: Text(option['desc']!),
            value: option['title']!,
            groupValue: currentMethod,
            activeColor: primaryColor,
            onChanged: (value) {
              Navigator.pop(context, value);
            },
          );
        },
      ),
    );
  }
}

class SelectPaymentMethodPage extends StatelessWidget {
  final String currentMethod;

  SelectPaymentMethodPage({required this.currentMethod});

  final List<Map<String, dynamic>> paymentOptions = [
    {
      'label': 'Pay with Card',
      'value': 'Credit Card',
      'icon': Icons.credit_card,
    },
    {
      'label': 'Bank Transfer',
      'value': 'Bank Transfer',
      'icon': Icons.account_balance_wallet,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text("Select your payment option"),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: paymentOptions.map((option) {
            return GestureDetector(
              onTap: () => Navigator.pop(context, option['value']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(option['icon'], size: 24, color: Colors.black87),
                    const SizedBox(width: 12),
                    Text(
                      option['label'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class VoucherCard extends StatelessWidget {
  final Map<String, dynamic> voucher;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const VoucherCard({
    required this.voucher,
    required this.selected,
    required this.onTap,
    required this.color,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Set blockColor and blockLabel with consistency and default
    Color blockColor = Colors.tealAccent.shade700;
    String blockLabel = "VOUCHER";
    String typeLower = (voucher['type'] as String).toLowerCase();

    if (typeLower.contains('shipping')) {
      blockColor = Colors.blue.shade400;
      blockLabel = "SHIPPING DISCOUNT";
    } else if (typeLower.contains('cashback')) {
      blockColor = Colors.purple.shade400;
      blockLabel = "CASHBACK";
    } else if (typeLower.contains('storewide discount')) {
      blockColor = Colors.orange.shade400;
      blockLabel = "STOREWIDE";
    } else if (typeLower.contains('promo')) {
      blockColor = Colors.pink.shade400;
      blockLabel = "PROMO";
    } else if (typeLower.contains('new user special')) {
      blockColor = Colors.green.shade400;
      blockLabel = "NEW USER";
    }

    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? Color.fromARGB(255, 112, 210, 255) : Colors.transparent,
            width: 2,
          ),
        ),
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        elevation: selected ? 6 : 1,
        child: Row(
          children: [
            // Colored block
            Container(
              width: 70,
              height: 90,
              decoration: BoxDecoration(
                color: blockColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
              child: Center(
                child: Text(
                  blockLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher['desc'],
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Min. Spend RM${voucher['minSpend'].toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Valid Till: ${voucher['validTill'].day.toString().padLeft(2, '0')}.${voucher['validTill'].month.toString().padLeft(2, '0')}.${voucher['validTill'].year}",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            // Tick/circle for selection
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Icon(
                selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
                color: selected
                  ? Color.fromARGB(255, 112, 210, 255)
                  : Colors.grey[400],
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// Voucher selection page with circular checkbox and summary at the bottom
class SelectVoucherPage extends StatefulWidget {
  final List<Map<String, dynamic>> selectedVouchers;
  final List<Map<String, dynamic>> availableVouchers;
  final double merchandiseSubtotal;

  SelectVoucherPage({
    required this.selectedVouchers,
    required this.availableVouchers,
    required this.merchandiseSubtotal,
  });

  @override
  _SelectVoucherPageState createState() => _SelectVoucherPageState();
}

class _SelectVoucherPageState extends State<SelectVoucherPage> {
  late List<Map<String, dynamic>> selected;

  @override
  void initState() {
    super.initState();
    selected = List.from(widget.selectedVouchers);
  }

  bool isSelected(Map<String, dynamic> voucher) {
    return selected.any((v) => v['id'] == voucher['id']);
  }
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    double totalDiscount =
        selected.fold(0.0, (sum, v) => sum + (v['discount'] as double));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text('Select Voucher'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: widget.availableVouchers
                  .where((voucher) => voucher['validTill'].isAfter(DateTime.now()) || _isSameDay(voucher['validTill'], DateTime.now()))
                  .map((voucher) {
                    return VoucherCard(
                      voucher: voucher,
                      selected: isSelected(voucher),
                      onTap: () {
                        bool isAlreadySelected = isSelected(voucher);

                        if (!isAlreadySelected) {
                          if (selected.length >= 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("You can only select up to 2 vouchers.")),
                            );
                            return;
                          }
                          if ((voucher['type'] as String).toLowerCase().contains('shipping')) {
                            bool hasShipping = selected.any((v) =>
                              (v['type'] as String).toLowerCase().contains('shipping'));
                            if (hasShipping) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("You can only select one shipping discount voucher.")),
                              );
                              return;
                            }
                          }
                          if (widget.merchandiseSubtotal < voucher['minSpend']) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Minimum spend RM${voucher['minSpend'].toStringAsFixed(2)} required!")),
                            );
                            return;
                          }
                          setState(() {
                            selected.add(voucher);
                          });
                        } else {
                          setState(() {
                            selected.removeWhere((v) => v['id'] == voucher['id']);
                          });
                        }
                      },
                      color: isSelected(voucher) ? Color.fromARGB(255, 112, 210, 255) : Colors.white,
                    );
                  }).toList(),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${selected.length} voucher(s) selected\nTotal Discount: RM${totalDiscount.toStringAsFixed(2)}",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, selected);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 112, 210, 255),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text("OK",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Map Address Picker Page ---

class SelectAddressMapPage extends StatefulWidget {
  final String initialAddress;

  SelectAddressMapPage({required this.initialAddress});

  @override
  _SelectAddressMapPageState createState() => _SelectAddressMapPageState();
}

class _SelectAddressMapPageState extends State<SelectAddressMapPage> {
  GoogleMapController? _mapController;
  LatLng? _pickedLatLng;
  String _address = '';
  bool _loadingAddress = false;

  final LatLng _defaultLatLng = LatLng(3.1390, 101.6869);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _initFromAddress();
  }

  Future<void> _initFromAddress() async {
    try {
      List<Location> locations = await locationFromAddress(widget.initialAddress);
      if (locations.isNotEmpty) {
        setState(() {
          _pickedLatLng = LatLng(locations[0].latitude, locations[0].longitude);
          _address = widget.initialAddress;
        });
      } else {
        _pickedLatLng = _defaultLatLng;
      }
    } catch (e) {
      _pickedLatLng = _defaultLatLng;
    }
  }

  Future<void> _onMapTap(LatLng latLng) async {
    setState(() {
      _pickedLatLng = latLng;
      _loadingAddress = true;
      _address = "Loading...";
    });

    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks[0];
        final addr = "${p.street}, ${p.locality}, ${p.country}";
        setState(() {
          _address = addr;
        });
      } else {
        setState(() {
          _address = "No address found";
        });
      }
    } catch (e) {
      setState(() {
        _address = "Failed to get address";
      });
    }

    setState(() {
      _loadingAddress = false;
    });
  }

  Future<void> _searchAndNavigate() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    setState(() {
      _loadingAddress = true;
      _address = "Searching...";
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final latLng = LatLng(locations[0].latitude, locations[0].longitude);

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );

        setState(() {
          _pickedLatLng = latLng;
        });

        await _onMapTap(latLng); // trigger reverse geocoding
      } else {
        setState(() {
          _address = "Address not found";
        });
      }
    } catch (e) {
      setState(() {
        _address = "Search failed";
      });
    }

    setState(() {
      _loadingAddress = false;
    });

    _searchFocus.unfocus(); // dismiss keyboard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text('Pick Address on Map'),
      ),
      body: _pickedLatLng == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          decoration: InputDecoration(
                            hintText: 'Search place or address...',
                            prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                          ),
                          onSubmitted: (value) => _searchAndNavigate(),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _searchAndNavigate,
                        child: Icon(Icons.search, color: primaryColor),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.all(14),
                          shape: CircleBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _pickedLatLng!,
                      zoom: 15,
                    ),
                    onTap: _onMapTap,
                    markers: _pickedLatLng != null
                        ? {
                            Marker(
                              markerId: MarkerId('selected'),
                              position: _pickedLatLng!,
                            ),
                          }
                        : {},
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                ),
                Container(
                  color: Colors.grey[200],
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  width: double.infinity,
                  child: _loadingAddress
                      ? Row(
                          children: [
                            CircularProgressIndicator(strokeWidth: 2),
                            SizedBox(width: 10),
                            Text("Getting address..."),
                          ],
                        )
                      : Text(
                          _address.isEmpty
                              ? "Tap on map to pick location"
                              : "Address: $_address",
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _address.isNotEmpty &&
                              _address != "Loading..." &&
                              _address != "No address found" &&
                              _address != "Failed to get address" &&
                              _address != "Searching..." &&
                              _address != "Search failed" &&
                              _address != "Address not found"
                          ? () async {
                              final userId = "demo_user"; // Replace with actual user ID
                              final dbRef = FirebaseDatabase.instance.ref();

                              await dbRef
                                  .child('users')
                                  .child(userId)
                                  .child('address')
                                  .set(_address);

                              Navigator.pop(context, _address);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text("Confirm Address",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

