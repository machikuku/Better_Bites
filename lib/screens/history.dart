import 'package:flutter/material.dart';
import 'package:betterbitees/screens/history_details.dart';
import 'package:betterbitees/models/food_analysis.dart';
import 'package:betterbitees/repositories/food_analysis_repo.dart';
import 'package:betterbitees/helpers/db.dart';
import 'package:intl/intl.dart' as intl;

class HistoryItem {
  final String timestamp;
  String? title;
  final FoodAnalysis? foodAnalysis;

  HistoryItem({
    required this.timestamp,
    this.title,
    this.foodAnalysis,
  });
}

class HistoryStackedCarousel extends StatefulWidget {
  const HistoryStackedCarousel({super.key});

  @override
  _HistoryStackedCarouselState createState() => _HistoryStackedCarouselState();
}

class _HistoryStackedCarouselState extends State<HistoryStackedCarousel> {
  bool _isDeleteMode = false;
  Set<int> _selectedItems = {};
  List<HistoryItem> _items = [];
  final FoodAnalysisRepo _foodAnalysisRepo = FoodAnalysisRepo();

  static const Color prime = Color(0xFF0d522c);
  static const Color thrd = Color(0xFFD6EFD8);
  static const int maxHistoryItems = 30;

  @override
  void initState() {
    super.initState();
    _loadHistoryItems();
  }

  Future<void> _loadHistoryItems() async {
    try {
      final foodAnalyses = await _foodAnalysisRepo.getAll();
      debugPrint('Fetched food analyses: ${foodAnalyses.length}');

      if (foodAnalyses.length > maxHistoryItems) {
        final db = await DBHelper.open();
        final excessIds = foodAnalyses
            .sublist(maxHistoryItems)
            .map((food) => food.id)
            .where((id) => id != null)
            .toList();

        if (excessIds.isNotEmpty) {
          await db.delete(
            'food_analysis',
            where: 'id IN (${List.filled(excessIds.length, '?').join(',')})',
            whereArgs: excessIds,
          );
          debugPrint('Deleted ${excessIds.length} excess history items');
        }
        foodAnalyses.removeRange(maxHistoryItems, foodAnalyses.length);
      }

      setState(() {
        _items = foodAnalyses.map((foodAnalysis) {
          debugPrint(
              'Processing food analysis: ${foodAnalysis.title}, Ingredients: ${foodAnalysis.ingredientsAnalysis.length}');
          final timestamp = intl.DateFormat('yyyy-MM-dd HH:mm:ss').format(
              foodAnalysis.createdAt.toLocal());
          return HistoryItem(
            timestamp: timestamp,
            title: foodAnalysis.title.isNotEmpty
                ? foodAnalysis.title
                : 'Unnamed Scan',
            foodAnalysis: foodAnalysis,
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                    'Error',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Failed to load history: $e',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: prime,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Exit',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              elevation: 8,
            );
          },
        );
      }
      setState(() {
        _items = [];
      });
    }
  }

  void _toggleDeleteMode() {
    setState(() {
      _isDeleteMode = !_isDeleteMode;
      if (!_isDeleteMode) {
        _selectedItems.clear();
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    const String confirmTitle = 'Delete Items?';
    const String cancelText = 'Cancel';
    const String deleteText = 'Delete';
    const String okText = 'OK';

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        contentPadding: const EdgeInsets.all(20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: thrd,
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                confirmTitle,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: prime,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Are you sure you want to delete ${_selectedItems.length} item${_selectedItems.length > 1 ? 's' : ''}?',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  cancelText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: prime,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  deleteText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: prime,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      final db = await DBHelper.open();
      final int deletedCount = _selectedItems.length;

      final List<int> indicesToRemove = _selectedItems.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final index in indicesToRemove) {
        if (index >= 0 && index < _items.length) {
          final foodAnalysis = _items[index].foodAnalysis;
          if (foodAnalysis?.id != null) {
            await db.delete(
              'food_analysis',
              where: 'id = ?',
              whereArgs: [foodAnalysis!.id],
            );
          }
        }
      }

      setState(() {
        final List<int> indicesToRemove = _selectedItems.toList()
          ..sort((a, b) => b.compareTo(a));
        for (final index in indicesToRemove) {
          if (index >= 0 && index < _items.length) {
            _items.removeAt(index);
          }
        }
        _selectedItems.clear();
      });

      await showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          contentPadding: const EdgeInsets.all(20.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: thrd,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: prime,
                size: 50,
              ),
              const SizedBox(height: 10),
              Text(
                '$deletedCount item${deletedCount > 1 ? 's' : ''} deleted successfully!',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  okText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: prime,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      await showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          contentPadding: const EdgeInsets.all(20.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: thrd,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: prime,
                size: 50,
              ),
              const SizedBox(height: 10),
              const Text(
                'Error',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: prime,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Failed to delete items: ${e.toString()}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: prime,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _selectAllItems() {
    setState(() {
      if (_selectedItems.length == _items.length) {
        _selectedItems.clear();
      } else {
        _selectedItems =
            Set<int>.from(List.generate(_items.length, (index) => index));
      }
    });
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _editItemTitle(int index) async {
    TextEditingController titleController =
        TextEditingController(text: _items[index].title);

    final bool? confirmEdit = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        contentPadding: const EdgeInsets.all(20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: thrd,
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Item Title',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: prime,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Timestamp: ${_items[index].timestamp}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelStyle: TextStyle(fontFamily: 'Poppins', color: prime),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: prime,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: prime,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmEdit != true) return;

    final newTitle = _capitalizeWords(titleController.text);
    if (_items[index].foodAnalysis?.id != null) {
      final food = await _foodAnalysisRepo
          .getFoodAnalysis(_items[index].foodAnalysis!.id!);
      food.title = newTitle;
      final db = await DBHelper.open();
      await db.update(
        'food_analysis',
        {'title': newTitle},
        where: 'id = ?',
        whereArgs: [food.id],
      );
    }

    setState(() {
      _items[index].title = newTitle;
    });

    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        contentPadding: const EdgeInsets.all(20.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: thrd,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: prime,
              size: 50,
            ),
            const SizedBox(height: 10),
            Text(
              'Title "$newTitle" saved successfully!',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: prime,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6EFD8),
      appBar: AppBar(
        backgroundColor: thrd,
        title: const Text(
          'History',
          style: TextStyle(fontFamily: 'Poppins', color: prime, fontSize: 19),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: prime,
            size: 22,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          if (_isDeleteMode)
            IconButton(
              icon: const Icon(Icons.select_all, color: prime, size: 20),
              onPressed: _selectAllItems,
            ),
          if (_isDeleteMode)
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: prime,
                size: 20,
              ),
              onPressed: _deleteSelectedItems,
            ),
          TextButton(
            onPressed: _toggleDeleteMode,
            child: Text(
              _isDeleteMode ? 'Cancel' : 'Delete Items',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: prime,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _items.isEmpty
            ? Center(
                child: Text(
                  'There are no history items',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    color: prime.withOpacity(0.7),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(
                    color: const Color.fromARGB(255, 169, 209, 172),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3)),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Stack(
                        children: [
                          Row(
                            children: [
                              if (_isDeleteMode)
                                Checkbox(
                                  value: _selectedItems.contains(index),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedItems.add(index);
                                      } else {
                                        _selectedItems.remove(index);
                                      }
                                    });
                                  },
                                  fillColor:
                                      MaterialStateProperty.resolveWith<Color>(
                                          (states) {
                                    if (states
                                        .contains(MaterialState.selected)) {
                                      return prime;
                                    }
                                    return const Color(0xFFE0EEE1);
                                  }),
                                  checkColor: Colors.white,
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (item.title != null)
                                      Text(
                                        item.title!,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: prime,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.timestamp,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: prime,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: prime,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 15, vertical: 5),
                                      ),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                HistoryDetails(
                                              foodAnalysis: item.foodAnalysis!,
                                            ),
                                          ),
                                        );
                                        await _loadHistoryItems();
                                      },
                                      child: const Text(
                                        'View Details',
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!_isDeleteMode)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: prime,
                                  size: 18,
                                ),
                                onPressed: () => _editItemTitle(index),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}