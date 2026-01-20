import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'custom_app_bar.dart';
import 'cart.dart';
import 'product_detail.dart';

const Color primaryColor = Color.fromARGB(255, 112, 210, 255);

class FavouritePage extends StatelessWidget {
  final Map<String, dynamic> allProducts;

  const FavouritePage({required this.allProducts});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);
    final favorites = cart.favorites;

    final favoriteProducts = allProducts.entries
        .where((entry) => favorites.contains(entry.key))
        .toList();

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(title: 'Favourite'),
            Expanded(
              child: favoriteProducts.isEmpty
                  ? Center(child: Text('No favorites yet.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: favoriteProducts.length,
                      itemBuilder: (context, index) {
                        final productId = favoriteProducts[index].key;
                        final product = favoriteProducts[index].value;
                        final stock = product['stock'] ?? 0;

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailPage(
                                  product: product,
                                  productId: productId,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        ModelViewer(
                                          src: product['model'],
                                          alt: product['name'],
                                          ar: true,
                                          autoRotate: true,
                                          cameraControls: true,
                                        ),
                                        Positioned(
                                          right: 0,
                                          child: IconButton(
                                            icon: Icon(Icons.favorite,
                                                color: Colors.red),
                                            onPressed: () {
                                              cart.removeFavorite(productId);
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product['name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '\$${product['price']}',
                                    style:
                                        const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    'Stock: $stock',
                                    style: TextStyle(
                                      color: stock > 0
                                          ? Colors.green.shade600
                                          : Colors.red.shade400,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

