import 'package:flutter/material.dart';
import 'database_helper.dart';

final dbHelper = DatabaseHelper();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dbHelper.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Card Organizer',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      home: const FoldersPage(),
    );
  }
}

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});
  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  late Future<List<Map<String, dynamic>>> _folders;
  @override
  void initState() {
    super.initState();
    _folders = dbHelper.fetchFolders();
  }
  Future<int> _count(int id) => dbHelper.countCardsInFolder(id);
  Future<String?> _firstUrl(int id) => dbHelper.firstImageUrlForFolder(id);

  void _refresh() {
    setState(() {
      _folders = dbHelper.fetchFolders();
    });
  }

  Future<void> _createFolderDialog() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await dbHelper.createFolder(name);
              if (mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameFolderDialog(Map<String, dynamic> folder) async {
    final ctrl = TextEditingController(text: folder[DatabaseHelper.foldersColName] as String);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'New name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await dbHelper.renameFolder(folder[DatabaseHelper.foldersColId] as int, name);
              if (mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFolderDialog(Map<String, dynamic> folder) async {
    final id = folder[DatabaseHelper.foldersColId] as int;
    final count = await dbHelper.countCardsInFolder(id);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text('Delete this folder and its $count cards?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await dbHelper.deleteFolder(id);
              if (mounted) Navigator.pop(context);
              _refresh();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _folders,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final folders = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: folders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final f = folders[i];
              final id = f[DatabaseHelper.foldersColId] as int;
              return FutureBuilder<int>(
                future: _count(id),
                builder: (context, countSnap) {
                  final count = countSnap.data ?? 0;
                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    tileColor: Colors.teal.withAlpha(20),
                    leading: FutureBuilder<String?>(
                      future: _firstUrl(id),
                      builder: (context, urlSnap) {
                        final url = urlSnap.data ?? '';
                        if (url.isEmpty) {
                          return const CircleAvatar(child: Icon(Icons.folder));
                        }
                        return CircleAvatar(
                          backgroundImage: NetworkImage(url),
                          onBackgroundImageError: (_, __) {},
                        );
                      },
                    ),
                    title: Text(f[DatabaseHelper.foldersColName] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    subtitle: Text('$count cards'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'rename') _renameFolderDialog(f);
                        if (v == 'delete') _deleteFolderDialog(f);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CardsPage(folderId: id),
                      )).then((_) => _refresh());
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFolderDialog,
        label: const Text('Add Folder'),
        icon: const Icon(Icons.create_new_folder),
      ),
    );
  }
}

class CardsPage extends StatefulWidget {
  final int folderId;
  const CardsPage({super.key, required this.folderId});
  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late Future<Map<String, dynamic>?> _folder;
  late Future<List<Map<String, dynamic>>> _cards;

  @override
  void initState() {
    super.initState();
    _folder = dbHelper.getFolderById(widget.folderId);
    _cards = dbHelper.fetchCardsForFolder(widget.folderId);
  }

  void _refresh() {
    setState(() {
      _cards = dbHelper.fetchCardsForFolder(widget.folderId);
    });
  }

  Future<void> _addCardDialog(Map<String, dynamic> folder) async {
    final nameCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    String suit = folder[DatabaseHelper.foldersColName] as String;
    final currentCount = await dbHelper.countCardsInFolder(widget.folderId);
    if (currentCount >= 6) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Limit Reached'),
          content: const Text('This folder can only hold 6 cards.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Add Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (e.g., Ace of Hearts)')),
              TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: suit,
                items: const [
                  DropdownMenuItem(value: 'Hearts', child: Text('Hearts')),
                  DropdownMenuItem(value: 'Spades', child: Text('Spades')),
                  DropdownMenuItem(value: 'Diamonds', child: Text('Diamonds')),
                  DropdownMenuItem(value: 'Clubs', child: Text('Clubs')),
                ],
                onChanged: (v) => suit = v ?? suit,
                decoration: const InputDecoration(labelText: 'Suit'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final img = imageCtrl.text.trim();
                if (name.isEmpty) return;
                final countNow = await dbHelper.countCardsInFolder(widget.folderId);
                if (countNow >= 6) return;
                await dbHelper.addCard(name: name, suit: suit, folderId: widget.folderId, imageUrl: img);
                if (mounted) Navigator.pop(context);
                _refresh();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCardDialog(Map<String, dynamic> card, Map<String, dynamic> folder) async {
    final nameCtrl = TextEditingController(text: card[DatabaseHelper.cardsColName] as String);
    final imageCtrl = TextEditingController(text: (card[DatabaseHelper.cardsColImageUrl] as String?) ?? '');
    String suit = card[DatabaseHelper.cardsColSuit] as String;
    int targetFolderId = widget.folderId;
    final folders = await dbHelper.fetchFolders();
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Edit Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: suit,
                items: const [
                  DropdownMenuItem(value: 'Hearts', child: Text('Hearts')),
                  DropdownMenuItem(value: 'Spades', child: Text('Spades')),
                  DropdownMenuItem(value: 'Diamonds', child: Text('Diamonds')),
                  DropdownMenuItem(value: 'Clubs', child: Text('Clubs')),
                ],
                onChanged: (v) => suit = v ?? suit,
                decoration: const InputDecoration(labelText: 'Suit'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: targetFolderId,
                items: [
                  for (final f in folders)
                    DropdownMenuItem(
                      value: f[DatabaseHelper.foldersColId] as int,
                      child: Text(f[DatabaseHelper.foldersColName] as String),
                    )
                ],
                onChanged: (v) => targetFolderId = v ?? targetFolderId,
                decoration: const InputDecoration(labelText: 'Folder'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final img = imageCtrl.text.trim();
                if (name.isEmpty) return;
                if (targetFolderId != widget.folderId) {
                  final cnt = await dbHelper.countCardsInFolder(targetFolderId);
                  if (cnt >= 6) return;
                }
                await dbHelper.updateCard(
                  id: card[DatabaseHelper.cardsColId] as int,
                  name: name,
                  suit: suit,
                  folderId: targetFolderId,
                  imageUrl: img,
                );
                if (mounted) Navigator.pop(context);
                _refresh();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCard(int id) async {
    await dbHelper.deleteCard(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _folder,
      builder: (context, folderSnap) {
        if (!folderSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final folder = folderSnap.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text(folder[DatabaseHelper.foldersColName] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            centerTitle: true,
          ),
          body: Column(
            children: [
              FutureBuilder<int>(
                future: dbHelper.countCardsInFolder(widget.folderId),
                builder: (context, cntSnap) {
                  final c = cntSnap.data ?? 0;
                  if (c >= 3) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded),
                        SizedBox(width: 8),
                        Expanded(child: Text('You need at least 3 cards in this folder.')),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _cards,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final cards = snapshot.data!;
                    if (cards.isEmpty) return const Center(child: Text('No cards'));
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3 / 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, i) {
                        final card = cards[i];
                        final name = card[DatabaseHelper.cardsColName] as String;
                        final url = (card[DatabaseHelper.cardsColImageUrl] as String?) ?? '';
                        return InkWell(
                          onTap: () => _editCardDialog(card, folder),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              children: [
                                Expanded(
                                  child: url.isEmpty
                                      ? Container(
                                          alignment: Alignment.center,
                                          child: Text(name.split(' ').first, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                                        )
                                      : ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                          child: Image.network(url, width: double.infinity, height: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported))),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                                      PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') _editCardDialog(card, folder);
                                          if (v == 'delete') _deleteCard(card[DatabaseHelper.cardsColId] as int);
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FutureBuilder<int>(
            future: dbHelper.countCardsInFolder(widget.folderId),
            builder: (context, cntSnap) {
              final c = cntSnap.data ?? 0;
              return FloatingActionButton.extended(
                onPressed: c >= 6 ? null : () => _addCardDialog(folder),
                label: const Text('Add Card'),
                icon: const Icon(Icons.add),
              );
            },
          ),
        );
      },
    );
  }
}
