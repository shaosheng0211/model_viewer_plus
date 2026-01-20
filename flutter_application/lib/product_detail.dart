import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'cart.dart';

const Color primaryColor = Color.fromARGB(255, 112, 210, 255);

class ProductDetailPage extends StatefulWidget {
  final Map product;
  final String productId;

  const ProductDetailPage({
    required this.product,
    required this.productId,
    Key? key,
  }) : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int currentStock = 0;

  @override
  void initState() {
    super.initState();
    _listenToStock();
  }

  void _listenToStock() {
    final stockRef = FirebaseDatabase.instance.ref('products/${widget.productId}/stock');
    stockRef.onValue.listen((event) {
      final stock = event.snapshot.value;
      if (stock != null) {
        setState(() {
          currentStock = int.tryParse(stock.toString()) ?? 0;
        });
      }
    });
  }

  void _showAddToCartBottomSheet() {
    final options = widget.product['options'] as List<dynamic>;
    String selectedOption = options.first;
    int quantity = 1;

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
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
                  Text("Available Stock: $currentStock", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                  SizedBox(height: 12),
                  Text("Select Option", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Wrap(
                    spacing: 8,
                    children: options.map<Widget>((option) {
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
                  Text("Quantity", style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: quantity > 1 ? () => setModalState(() => quantity--) : null,
                      ),
                      Text('$quantity', style: TextStyle(fontSize: 18)),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: quantity < currentStock ? () => setModalState(() => quantity++) : null,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (quantity > currentStock) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Not enough stock! Please reduce quantity.')),
                        );
                        return;
                      }

                      final cart = Provider.of<Cart>(context, listen: false);
                      await cart.addToCart(
                        widget.productId,
                        widget.product['name'],
                        double.parse(widget.product['price'].toString()),
                        selectedOption,
                        quantity,
                      );

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added $quantity x $selectedOption to cart!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Add to Cart', style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(product['name'], style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ModelViewer(
                src: product['model'],
                alt: product['name'],
                ar: true,
                autoRotate: true,
                cameraControls: true,
              ),
            ),
            SizedBox(height: 16),
            Text(product['name'], style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('\$${product['price']}', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            SizedBox(height: 8),
            Text('Category: ${product['category']}', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text(
              'Stock: $currentStock',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: currentStock > 0 ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: currentStock > 0 ? _showAddToCartBottomSheet : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Add to Cart', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

