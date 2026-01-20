import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'cart.dart';
import 'checkout.dart';

const primaryColor = Color.fromARGB(255, 112, 210, 255);

class CartPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);
    final cartItems = cart.items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Text('My Cart'),
      ),
      body: cartItems.isEmpty
          ? Center(child: Text('Your cart is empty'))
          : ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final productId = cartItems.keys.elementAt(index);
                final item = cartItems[productId]!;
                final isSelected = cart.selectedItems.contains(productId);

                return Dismissible(
                  key: Key(productId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    color: Colors.red,
                    padding: EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    cart.removeFromCart(productId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item['name']} removed from cart')),
                    );
                  },
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      activeColor: primaryColor,
                      onChanged: (_) => cart.toggleSelection(productId),
                    ),
                    title: Text(item['name']),
                    subtitle: Text('Option: ${item['option']} - Quantity: ${item['quantity']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.edit, color: primaryColor),
                      onPressed: () => _showEditBottomSheet(context, productId, item),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: \$${cart.selectedTotal.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: cart.selectedItems.isEmpty
                  ? null
                  : () async {
                      final dbRef = FirebaseDatabase.instance.ref('products');
                      final snapshot = await dbRef.get();
                      final allProductsFromDb = snapshot.exists
                          ? Map<String, dynamic>.from(snapshot.value as Map)
                          : <String, dynamic>{};

                      final selectedCartItems = {
                        for (var id in cart.selectedItems)
                          if (cart.items.containsKey(id)) id: cart.items[id]!
                      };

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CheckoutPage(
                            selectedItems: selectedCartItems,
                            allProducts: allProductsFromDb,
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
              child: Text('Checkout (${cart.selectedItems.length})',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBottomSheet(
      BuildContext context, String productId, Map<String, dynamic> item) {
    final cart = Provider.of<Cart>(context, listen: false);
    final productRef = FirebaseDatabase.instance.ref('products/$productId');

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder(
          future: productRef.get(),
          builder: (context, AsyncSnapshot<DataSnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return SizedBox(
                height: 200,
                child: Center(child: Text('Error loading product details')),
              );
            } else if (!snapshot.hasData || !snapshot.data!.exists) {
              return SizedBox(
                height: 200,
                child: Center(child: Text('Product not found')),
              );
            } else {
              final product =
                  Map<String, dynamic>.from(snapshot.data!.value as Map);
              final options = List<String>.from(product['options']);
              int currentStock = product['stock'] ?? 0;

              String selectedOption = item['option'];
              int quantity = item['quantity'];

              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 16,
                      right: 16,
                      top: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Modify Item",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: options.map((option) {
                            return ChoiceChip(
                              label: Text(option),
                              selectedColor: primaryColor,
                              backgroundColor: Colors.grey.shade100,
                              labelStyle: TextStyle(
                                color: selectedOption == option ? Colors.white : Colors.black,
                              ),
                              selected: selectedOption == option,
                              onSelected: (_) {
                                setModalState(() {
                                  selectedOption = option;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: quantity > 1
                                  ? () => setModalState(() => quantity--)
                                  : null,
                            ),
                            Text('$quantity',
                                style: TextStyle(fontSize: 18)),
                            Tooltip(
                              message: quantity >= currentStock
                                  ? 'Max stock reached'
                                  : 'Add one more',
                              child: IconButton(
                                icon: Icon(Icons.add),
                                onPressed: quantity < currentStock
                                    ? () => setModalState(() => quantity++)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            cart.updateItem(
                              productId: productId,
                              newOption: selectedOption,
                              newQuantity: quantity,
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Item updated')),
                            );
                          },
                          child: Text("Update", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              );
            }
          },
        );
      },
    );
  }
}

