import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'cart.dart';
import 'product_detail.dart';
import 'cart_page.dart';
import 'favourite_page.dart';
import 'message_page.dart';
import 'me_page.dart';

const Color primaryColor = Color.fromARGB(255, 112, 210, 255);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (_) => Cart(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: primaryColor, //Match app's theme
        ),
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic> allProducts = {}; 

  void updateAllProducts(Map<String, dynamic> products) {
    setState(() {
      allProducts = products;
    });
  }

  @override
  Widget build(BuildContext context) {
    //Move _pages into build so it uses updated allProducts
    final List<Widget> _pages = [
      ProductCatalogPage(onProductsFetched: updateAllProducts),
      FavouritePage(allProducts: allProducts),
      MessagePage(),
      MePage(),
    ];

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favourite'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Message'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}

class ProductCatalogPage extends StatefulWidget {
  @override
  _ProductCatalogPageState createState() => _ProductCatalogPageState();
  final Function(Map<String, dynamic>) onProductsFetched;

  ProductCatalogPage({required this.onProductsFetched});
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  String? selectedCategory;
  Map<String, dynamic> allProducts = {};
  Map<String, int> stockMap = {};
  List<String> categories = [];
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  final Map<String, Widget> _modelViewerCache = {};

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _fetchProducts() async {
    final dbRef = FirebaseDatabase.instance.ref('products');
    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        allProducts = data;
        categories = data.values.map((p) => p['category'] as String).toSet().toList();
        data.forEach((key, product) {
          final stock = product['stock'] ?? 0;
          stockMap[key] = stock;
        });
        isLoading = false;
      });
      widget.onProductsFetched(data);
    } else {
      setState(() {
        isLoading = false;
      }); 
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<Cart>(context);

    final productsCopy = Map<String, dynamic>.from(allProducts); //force refresh
    final productsInCategory = productsCopy.entries.where((entry) {
      final matchesSearch = searchQuery.isEmpty ||
          (entry.value['name'] as String).toLowerCase().contains(searchQuery.toLowerCase());

      final matchesCategory = selectedCategory == null ||
          entry.value['category'].toString().trim().toLowerCase() ==
          selectedCategory!.trim().toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100, //Cleaner and neutral
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CartPage()),
                        );
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(Icons.shopping_cart, size: 28),
                          ),
                          if (cart.items.isNotEmpty)
                            Positioned(
                              right: -2,
                              top: 2,
                              child: Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '${cart.items.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ChoiceChip(
                        label: Text('All'),
                        selected: selectedCategory == null,
                        selectedColor: primaryColor,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: selectedCategory == null ? Colors.white : Colors.black,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedCategory = null;
                            searchQuery = '';
                          });
                        },
                      ),
                    );
                  }
                  final cat = categories[index - 1];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: selectedCategory == cat,
                      selectedColor: primaryColor,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: selectedCategory == cat ? Colors.white : Colors.black,
                      ),
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = cat;
                          searchQuery = '';
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : productsInCategory.isEmpty
                      ? Center(
                          child: Text(
                            searchQuery.isEmpty && selectedCategory == null
                                ? 'No products found.'
                                : searchQuery.isNotEmpty
                                    ? 'No products found for "$searchQuery"'
                                    : 'No products found in $selectedCategory',
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(8.0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: productsInCategory.length,
                          itemBuilder: (context, index) {
                            final productEntry = productsInCategory[index];
                            final productId = productEntry.key;
                            final product = productEntry.value;
                            final stock = stockMap[productId] ?? 0;

                            return GestureDetector(
                              onTap: stock > 0
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailPage(
                                            product: product,
                                            productId: productId,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: _buildProductCard(productId, product, stock),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(String productId, Map product, int stock) {
    final cart = Provider.of<Cart>(context, listen: false);

    // If already cached, use it
    Widget modelViewer = _modelViewerCache[productId] ??
        ModelViewer(
          key: ValueKey(product['model']), // still use key to prevent mismatch
          src: product['model'],
          alt: product['name'],
          ar: true,
          autoRotate: true,
          cameraControls: true,
        );

    // Cache it if not already stored
    _modelViewerCache.putIfAbsent(productId, () => modelViewer);

                                                                                      return Card(
                                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                                        elevation: 2,
                                                                                        color: Colors.white,
                                                                                        child: Padding(
                                                                                          padding: const EdgeInsets.all(8.0),
                                                                                          child: Column(
                                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                                            children: [
                                                                                              Expanded(child: modelViewer),
                                                                                              const SizedBox(height: 8),
                                                                                              Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                                              const SizedBox(height: 4),
                                                                                              Text('\$${product['price']}', style: const TextStyle(color: Colors.grey)),
                                                                                              const SizedBox(height: 4),
                                                                                              Row(
                                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                children: [
                                                                                                  Text(
                                                                                                    'Stock: $stock',
                                                                                                    style: TextStyle(
                                                                                                      color: stock > 0 ? Colors.green.shade600 : Colors.red.shade400,
                                                                                                      fontWeight: FontWeight.bold,
                                                                                                    ),
                                                                                                  ),
                                                                                                  Container(
                                                                                                    width: 28,
                                                                                                    height: 28,
                                                                                                    decoration: BoxDecoration(
                                                                                                      color: Colors.white,
                                                                                                      shape: BoxShape.circle,
                                                                                                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                                                                                                    ),
                                                                                                    child: IconButton(
                                                                                                      padding: EdgeInsets.zero,
                                                                                                      icon: Icon(
                                                                                                        cart.isFavorite(productId)
                                                                                                            ? Icons.favorite
                                                                                                            : Icons.favorite_border,
                                                                                                        color: Colors.red,
                                                                                                        size: 16,
                                                                                                      ),
                                                                                                      onPressed: () {
                                                                                                        if (cart.isFavorite(productId)) {
                                                                                                          cart.removeFavorite(productId);
                                                                                                        } else {
                                                                                                          cart.addFavorite(productId);
                                                                                                        }
                                                                                                      },
                                                                                                    ),
                                                                                                  ),
                                                                                                ],
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      );
  }

}

