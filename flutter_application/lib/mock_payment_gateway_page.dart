import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'order_status_page.dart';

class MockPaymentGatewayPage extends StatefulWidget {
  final String orderId;
  final double totalPayment;
  final String paymentOption;

  const MockPaymentGatewayPage({
    required this.orderId,
    required this.totalPayment,
    required this.paymentOption,
    Key? key,
  }) : super(key: key);

  @override
  State<MockPaymentGatewayPage> createState() => _MockPaymentGatewayPageState();
}

class _MockPaymentGatewayPageState extends State<MockPaymentGatewayPage> {
  final _formKey = GlobalKey<FormState>();

  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();

  bool saveCard = false;
  String accountNumber = "";
  String? bankName;
  late DateTime expiryTime;
  late Timer _timer;
  Duration _timeLeft = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _resetExpiryTimer();
    _startTimer();
  }

  Future<void> _saveCardToDatabase() async {
    final userId = "demo_user"; // Replace with the actual logged-in user ID
    final ref = FirebaseDatabase.instance.ref("users/$userId/saved_cards");
    final newCard = {
      "name": _cardNameController.text.trim(),
      "number": _cardNumberController.text.trim(),
      "expiry": _expiryController.text.trim(),
      "cvv": _cvvController.text.trim(),
      "timestamp": DateTime.now().toIso8601String(),
    };
    await ref.push().set(newCard);
  }

  Future<void> _markOrderAsPaid() async {
    final ref = FirebaseDatabase.instance.ref('orders/${widget.orderId}');
    await ref.update({'status': 'To Ship'});
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      final remaining = expiryTime.difference(DateTime.now());
      if (remaining.isNegative) {
        _timer.cancel();
        setState(() {
          _timeLeft = Duration.zero;
        });
      } else {
        setState(() {
          _timeLeft = remaining;
        });
      }
    });
  }

  void _resetExpiryTimer() {
    _timeLeft = Duration(minutes: 30);
    expiryTime = DateTime.now().add(_timeLeft);

    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      final remaining = expiryTime.difference(DateTime.now());
      if (remaining.isNegative) {
        _timer.cancel();
        setState(() => _timeLeft = Duration.zero);
      } else {
        setState(() => _timeLeft = remaining);
      }
    });
  }

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _accountNumberController.dispose();
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    return "${duration.inMinutes.remainder(60)} Mins";
  }

  @override
  Widget build(BuildContext context) {
    final isCard = widget.paymentOption == 'Credit Card';

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, false), // ❗ return false
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: isCard ? _buildCardPaymentUI() : _buildBankTransferUI(),
      ),
    );
  }

  Widget _buildCardPaymentUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.credit_card, size: 20),
            SizedBox(width: 8),
            Text('Pay with Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 24),
        _buildTextField(
          _cardNameController, "Name on card", "Add card Holder Full Name",
          keyboardType: TextInputType.name,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _cardNumberController, "Card Number", "Credit or Debit Card",
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(20)],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _expiryController, "Expire Date", "MM/YY",
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  LengthLimitingTextInputFormatter(5),
                  _ExpiryDateFormatter(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                _cvvController, "Security Code", "***",
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Pay securely with"),
            Row(
              children: [
                Checkbox(
                  value: saveCard,
                  onChanged: (val) => setState(() => saveCard = val ?? false),
                ),
                const Text("Save Card"),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Image.asset("assets/visa.png", height: 24),
            const SizedBox(width: 12),
            Image.asset("assets/mastercard.png", height: 24),
            const SizedBox(width: 12),
            Image.asset("assets/amex.jpg", height: 24),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            if (saveCard) await _saveCardToDatabase();
            await _markOrderAsPaid();

            if (!mounted) return;
            Navigator.pop(context, true); // ✅ tell caller “paid”
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment Successful! Redirecting to Order Status...'),
                duration: Duration(seconds: 2),
              ),
            );

            Future.delayed(const Duration(seconds: 2), () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderStatusPage(initialTab: 1),
                ),
              );
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 112, 210, 255),
            minimumSize: Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Proceed", style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Change Payment Method", style: TextStyle(color: Colors.black)),
          ),
        ),
      ],
    );
  }

  Widget _buildBankTransferUI() {
    final List<String> bankList = [
      'Maybank', 'CIMB Bank', 'Public Bank', 'RHB Bank', 'HSBC Bank',
      'Bank Islam', 'AmBank', 'UOB', 'OCBC Bank', 'Hong Leong Bank', 'Wema Bank',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.account_balance_wallet, size: 20),
            SizedBox(width: 8),
            Text('Bank Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Bank Name", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: bankName,
                items: bankList.map((bank) {
                  return DropdownMenuItem(value: bank, child: Text(bank));
                }).toList(),
                onChanged: (value) => setState(() => bankName = value),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                hint: Text("Select your bank"),
              ),
              const SizedBox(height: 12),
              const Text("Account Number", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _accountNumberController,
                decoration: InputDecoration(
                  hintText: "Enter your bank account",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => accountNumber = val,
              ),
              const SizedBox(height: 12),
              const Text("Amount", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("RM${widget.totalPayment.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Account number expires in ${_formatDuration(_timeLeft)}",
          style: const TextStyle(color: Colors.black),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            await _markOrderAsPaid();

            if (!mounted) return;
            Navigator.pop(context, true); // ✅ tell caller “paid”

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Payment Successful! Redirecting to Order Status...'),
                duration: Duration(seconds: 2),
              ),
            );

            Future.delayed(const Duration(seconds: 2), () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderStatusPage(initialTab: 1),
                ),
              );
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color.fromARGB(255, 112, 210, 255),
            minimumSize: Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("Proceed", style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Change Payment Method", style: TextStyle(color: Colors.black)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (text.length == 2 && !text.contains('/')) {
      text += '/';
    }
    if (text.length > 5) {
      text = text.substring(0, 5);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
