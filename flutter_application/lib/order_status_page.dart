import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'checkout.dart';
import 'mock_payment_gateway_page.dart';

const Color primaryColor = Color.fromARGB(255, 112, 210, 255);

class OrderStatusPage extends StatefulWidget {
  final int initialTab;
  const OrderStatusPage({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> allOrders = [];
  bool isLoading = true;

  final List<String> tabs = [
    'To Pay',
    'To Ship',
    'To Receive',
    'Completed',
    'Return/Refund',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() => isLoading = true);
    final ref = FirebaseDatabase.instance.ref('orders');
    final snap = await ref.get();
    final Map<dynamic, dynamic>? data = snap.value as Map<dynamic, dynamic>?;
    List<Map<String, dynamic>> orders = [];

    if (data != null) {
      data.forEach((orderId, orderData) {
        Map<String, dynamic> od = Map<String, dynamic>.from(orderData);
        od['orderId'] = orderId;
        orders.add(od);
      });
    }
    setState(() {
      allOrders = orders;
      isLoading = false;
    });
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final ref = FirebaseDatabase.instance.ref('orders/$orderId');
    await ref.update({'status': newStatus});
    fetchOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildNoOrderYet() {
    return Container(
      color: const Color(0xFFFCF6FA),
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'No Orders Yet',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(String status) {
    final orders = allOrders.where((o) {
      return (o['status'] ?? '').toString().toLowerCase() == status.toLowerCase();
    }).toList();

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (orders.isEmpty) {
      return _buildNoOrderYet();
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, orderIndex) {
          final order = orders[orderIndex];
          final items = (order['items'] as List<dynamic>).cast<Map<dynamic, dynamic>>();
          DateTime? deliveryDate;
          TimeOfDay? deliveryTime;

          if (order['delivery_datetime'] != null) {
            DateTime deliveryDT = DateTime.tryParse(order['delivery_datetime']) ?? DateTime.now();
            deliveryDate = deliveryDT;
            deliveryTime = TimeOfDay.fromDateTime(deliveryDT);
          }

          String deliveryDateStr = deliveryDate != null
              ? DateFormat('dd MMM yyyy').format(deliveryDate)
              : 'N/A';

          String deliveryTimeStr = 'N/A';
          if (deliveryTime != null) {
            final int totalMinutes = deliveryTime.hour * 60 + deliveryTime.minute;
            final TimeOfDay startRange = TimeOfDay(
              hour: (totalMinutes - 15) ~/ 60,
              minute: (totalMinutes - 15) % 60,
            );
            final TimeOfDay endRange = TimeOfDay(
              hour: (totalMinutes + 15) ~/ 60,
              minute: (totalMinutes + 15) % 60,
            );

            deliveryTimeStr =
                "${startRange.format(context)} - ${endRange.format(context)}";
          }

          String deliveryStr = "Expected delivery: $deliveryDateStr ($deliveryTimeStr)";

          return Card(
            color: Colors.white,
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order['orderId']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Column(
                    children: items.map((item) {
                      return ListTile(
                        leading: (item['model'] != null &&
                                item['model'].toString().isNotEmpty)
                            ? Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.image, color: Colors.grey.shade400),
                              )
                            : null,
                        title: Text(item['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: (item['option'] != null &&
                                item['option'].toString().isNotEmpty)
                            ? Text(item['option'],
                                style: const TextStyle(fontSize: 13))
                            : null,
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("RM${item['price'].toStringAsFixed(2)}"),
                            Text("x${item['quantity']}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 0),
                      );
                    }).toList(),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      deliveryStr,
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total: RM${order['payment_details']?['total_payment']?.toStringAsFixed(2) ?? '--'}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (status == 'To Pay') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                final selectedMethod = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SelectPaymentMethodPage(
                                      currentMethod: order['payment_method'] ?? 'Credit Card',
                                    ),
                                  ),
                                );

                                if (selectedMethod != null) {
                                  final ref = FirebaseDatabase.instance
                                      .ref('orders/${order['orderId']}');
                                  await ref.update({'payment_method': selectedMethod});
                                  fetchOrders();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Change Payment', style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                final selectedMethod = order['payment_method'] ?? 'Credit Card';
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MockPaymentGatewayPage(
                                      orderId: order['orderId'],
                                      totalPayment: double.tryParse(order['payment_details']
                                                  ?['total_payment']
                                              ?.toString() ??
                                          '0')!,
                                      paymentOption: selectedMethod,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Pay', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                      if (status == 'To Ship')
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            updateOrderStatus(order['orderId'], 'To Receive');
                          },
                          child: const Text('Mark as Received',
                              style: TextStyle(color: Colors.white)),
                        ),
                      if (status == 'To Receive')
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            updateOrderStatus(order['orderId'], 'Completed');
                          },
                          child: const Text('Complete Order',
                              style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        title: const Text('My Purchases',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.black),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            alignment: Alignment.centerLeft,
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.black,
              indicatorColor: primaryColor,
              indicatorWeight: 2.2,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal, fontSize: 13),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: tabs.map((e) => Tab(text: e)).toList(),
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: TabBarView(
          controller: _tabController,
          children: tabs.map((status) => _buildOrderList(status)).toList(),
        ),
      ),
    );
  }
}

