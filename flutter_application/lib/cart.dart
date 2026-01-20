import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class Cart with ChangeNotifier {
  final Map<String, Map<String, dynamic>> _items = {};
  final Set<String> _selectedItems = {};
  final Set<String> _favorites = {}; // for local-only favorites

  final DatabaseReference _cartRef = FirebaseDatabase.instance.ref('cart');

  final String userId = 'demo_user'; // Replace with actual auth user ID if you have login
  final DatabaseReference _favRef = FirebaseDatabase.instance.ref('favorites');

  Map<String, Map<String, dynamic>> get items => _items;
  Set<String> get selectedItems => _selectedItems;
  Set<String> get favorites => _favorites;

  Cart() {
    startListening();
    loadFavorites();
  }

  // ---------- FAVORITE MANAGEMENT ----------
  void addFavorite(String productId) {
    _favorites.add(productId);
    _favRef.child(userId).child(productId).set(true);
    notifyListeners();
  }

  void removeFavorite(String productId) {
    _favorites.remove(productId);
    _favRef.child(userId).child(productId).remove();
    notifyListeners();
  }

  bool isFavorite(String productId) => _favorites.contains(productId);

  Future<void> loadFavorites() async {
    final snapshot = await _favRef.child(userId).get();
    if (snapshot.exists && snapshot.value is Map) {
      _favorites.clear();
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      _favorites.addAll(data.keys);
      notifyListeners();
    }
  }

  // ---------- FIREBASE CART LISTENING ----------
  void startListening() {
    _cartRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map<dynamic, dynamic>) {
        _items.clear();
        data.forEach((key, value) {
          if (key is String && value is Map) {
            _items[key] = Map<String, dynamic>.from(value);
          }
        });
        _selectedItems.removeWhere((id) => !_items.containsKey(id));
        notifyListeners();
      } else {
        _items.clear();
        _selectedItems.clear();
        notifyListeners();
      }
    });
  }

  Future<void> fetchCart() async {
    final snapshot = await _cartRef.get();
    if (snapshot.exists && snapshot.value is Map<dynamic, dynamic>) {
      _items.clear();
      (snapshot.value as Map).forEach((key, value) {
        if (key is String && value is Map) {
          _items[key] = Map<String, dynamic>.from(value);
        }
      });
      _selectedItems.removeWhere((id) => !_items.containsKey(id));
      notifyListeners();
    }
  }

  // ---------- CART MODIFICATIONS ----------
  Future<void> addToCart(
    String productId,
    String name,
    double price,
    String option,
    int quantity,
  ) async {
    if (_items.containsKey(productId)) {
      _items[productId]!['quantity'] += quantity;
    } else {
      _items[productId] = {
        'name': name,
        'price': price,
        'option': option,
        'quantity': quantity,
      };
    }
    notifyListeners();

    try {
      await _cartRef.child(productId).set({
        'name': name,
        'price': price,
        'option': option,
        'quantity': _items[productId]!['quantity'],
      });
    } catch (e) {
      debugPrint('Failed to add to cart: $e');
    }
  }

  Future<void> updateItem({
    required String productId,
    required String newOption,
    required int newQuantity,
  }) async {
    if (_items.containsKey(productId)) {
      _items[productId] = {
        'name': _items[productId]!['name'],
        'price': _items[productId]!['price'],
        'option': newOption,
        'quantity': newQuantity,
      };
      notifyListeners();

      try {
        await _cartRef.child(productId).set({
          'name': _items[productId]!['name'],
          'price': _items[productId]!['price'],
          'option': newOption,
          'quantity': newQuantity,
        });
      } catch (e) {
        debugPrint('Failed to update item: $e');
      }
    }
  }

  Future<void> removeFromCart(String productId) async {
    _items.remove(productId);
    _selectedItems.remove(productId);
    notifyListeners();

    try {
      await _cartRef.child(productId).remove();
    } catch (e) {
      debugPrint('Failed to remove from cart: $e');
    }
  }

  // ---------- SELECTION FUNCTIONS ----------
  void toggleSelection(String productId) {
    if (_selectedItems.contains(productId)) {
      _selectedItems.remove(productId);
    } else {
      _selectedItems.add(productId);
    }
    notifyListeners();
  }

  bool get allSelected => _items.isNotEmpty && _selectedItems.length == _items.length;

  void toggleSelectAll(bool selectAll) {
    if (selectAll) {
      _selectedItems.addAll(_items.keys);
    } else {
      _selectedItems.clear();
    }
    notifyListeners();
  }

  // ---------- PRICE CALCULATION ----------
  double get totalPrice {
    double total = 0.0;
    _items.forEach((key, value) {
      total += value['price'] * value['quantity'];
    });
    return total;
  }

  double get selectedTotal {
    double total = 0.0;
    _selectedItems.forEach((id) {
      if (_items.containsKey(id)) {
        final item = _items[id]!;
        total += item['price'] * item['quantity'];
      }
    });
    return total;
  }

  // ---------- CART CLEAR / DELETE ----------
  Future<void> clearCart() async {
    _items.clear();
    _selectedItems.clear();
    notifyListeners();

    try {
      await _cartRef.remove();
    } catch (e) {
      debugPrint('Failed to clear cart: $e');
    }
  }

  Future<void> removeSelectedItems() async {
    final idsToRemove = _selectedItems.toList();
    for (final id in idsToRemove) {
      _items.remove(id);
      try {
        await _cartRef.child(id).remove();
      } catch (e) {
        debugPrint('Failed to remove selected item $id: $e');
      }
    }
    _selectedItems.clear();
    notifyListeners();
  }
}

