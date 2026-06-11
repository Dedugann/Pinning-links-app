import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  await Hive.initFlutter();
  // Открываем коробку
  await Hive.openBox('links_box');

  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 650),
    minimumSize: Size(600, 500),
    center: true,
    title: 'Менеджер Закладок',
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _linksBox = Hive.box('links_box');
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  String _searchQuery = '';

  void _launchURL(String urlString) async {
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть ссылку: $urlString')),
      );
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить новую ссылку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Возвращаем поле для ввода ссылки, которое я потерял
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Ссылка (URL)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.isNotEmpty && _urlController.text.isNotEmpty) {
                // Сохраняем структуру Map
                _linksBox.put(_titleController.text, {
                  'url': _urlController.text,
                  'isPinned': false,
                });
                
                _titleController.clear();
                _urlController.clear();
                Navigator.pop(context);
                setState(() {}); 
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _togglePin(String title) {
    final linkData = _linksBox.get(title);
    if (linkData is Map) {
      _linksBox.put(title, {
        'url': linkData['url'],
        'isPinned': !(linkData['isPinned'] ?? false),
      });
      setState(() {}); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final allKeys = _linksBox.keys.map((k) => k.toString()).toList();

    final filteredKeys = allKeys.where((key) {
      final linkData = _linksBox.get(key);
      if (linkData is! Map) return false;

      final title = key.toLowerCase();
      final url = linkData['url'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      
      if (_searchQuery.isEmpty) return true;
      return title.contains(query) || url.contains(query);
    }).toList();

    // Сортировка по закрепам
    filteredKeys.sort((a, b) {
      final dataA = _linksBox.get(a) as Map;
      final dataB = _linksBox.get(b) as Map;
      final isPinnedA = dataA['isPinned'] ?? false;
      final isPinnedB = dataB['isPinned'] ?? false;

      if (isPinnedA && !isPinnedB) return -1; 
      if (!isPinnedA && isPinnedB) return 1;  
      return 0; 
    });

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Мой Менеджер Ссылок',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Поиск по названию или URL...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            Expanded(
              child: filteredKeys.isEmpty
                  ? const Center(child: Text('Ничего не найдено или список пуст'))
                  : ListView.builder(
                      itemCount: filteredKeys.length,
                      itemBuilder: (context, index) {
                        final title = filteredKeys[index];
                        final linkData = _linksBox.get(title) as Map;
                        final url = linkData['url'] ?? '';
                        final isPinned = linkData['isPinned'] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: isPinned 
                              ? RoundedRectangleBorder(
                                  side: const BorderSide(color: Colors.blueAccent, width: 1.5),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.link, 
                              color: isPinned ? Colors.blueAccent : Colors.grey
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                    color: isPinned ? Colors.blueAccent : Colors.grey,
                                  ),
                                  onPressed: () => _togglePin(title),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () {
                                    _linksBox.delete(title);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                            onTap: () => _launchURL(url),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        label: const Text('Добавить ярлык'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}