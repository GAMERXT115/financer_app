import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'calculator.dart';
import 'login.dart';

class MouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

class Account {
  String id;
  String ownerId;
  String ownerUsername;
  String name;
  String lastFour;
  String currency;
  int colorValue;
  double balance;
  double conversionRate;
  List<String> sharedWith;

  Account({
    required this.id,
    required this.ownerId,
    required this.ownerUsername,
    required this.name,
    required this.lastFour,
    required this.currency,
    required this.colorValue,
    required this.balance,
    this.conversionRate = 0.0014,
    this.sharedWith = const [],
  });

  Map<String, dynamic> toJson() => {
    'ownerId': ownerId,
    'ownerUsername': ownerUsername,
    'name': name,
    'lastFour': lastFour,
    'currency': currency,
    'colorValue': colorValue,
    'balance': balance,
    'conversionRate': conversionRate,
    'sharedWith': sharedWith,
  };

  factory Account.fromJson(Map<String, dynamic> json, String docId) => Account(
    id: docId,
    ownerId: json['ownerId'] ?? '',
    ownerUsername: json['ownerUsername'] ?? 'Unknown',
    name: json['name'] ?? '',
    lastFour: json['lastFour'] ?? '',
    currency: json['currency'] ?? 'BHD',
    colorValue: json['colorValue'] ?? 4282540117,
    balance: (json['balance'] ?? 0.0).toDouble(),
    conversionRate: (json['conversionRate'] ?? 0.0014).toDouble(),
    sharedWith: List<String>.from(json['sharedWith'] ?? []),
  );
}

class Transaction {
  String id;
  String description;
  DateTime dateTime;
  double amount;
  bool isExpense;

  Transaction({
    required this.id,
    required this.description,
    required this.dateTime,
    required this.amount,
    required this.isExpense,
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'dateTime': Timestamp.fromDate(dateTime),
    'amount': amount,
    'isExpense': isExpense,
  };

  factory Transaction.fromJson(Map<String, dynamic> json, String docId) =>
      Transaction(
        id: docId,
        description: json['description'] ?? '',
        dateTime: (json['dateTime'] as Timestamp).toDate(),
        amount: (json['amount'] ?? 0.0).toDouble(),
        isExpense: json['isExpense'] ?? true,
      );
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _myUsername = '';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _accNameController = TextEditingController();
  final TextEditingController _accLastFourController = TextEditingController();
  final TextEditingController _accBalanceController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();
  final ScrollController _settingsScrollController = ScrollController();
  final NumberFormat _f = NumberFormat('#,##0.000', 'en_US');

  late PageController _pageController;
  late Stream<List<Account>> _accountsStream;
  int _activeIdx = 0;
  bool _isExpense = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isFlipped = false;
  String? _editingTxId;
  String? _deletingAccountId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _fetchMyUsername();
    _accountsStream = _getAccountsStream();
  }

  Future<void> _fetchMyUsername() async {
    final doc = await _db.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() {
        _myUsername = doc.data()?['username'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    _descController.dispose();
    _accNameController.dispose();
    _accLastFourController.dispose();
    _accBalanceController.dispose();
    _userSearchController.dispose();
    _settingsScrollController.dispose();
    super.dispose();
  }

  Stream<List<Account>> _getAccountsStream() {
    return _db.collectionGroup('accounts').snapshots().asyncMap((
      snapshot,
    ) async {
      final friendDocs = await _db
          .collection('users')
          .doc(_uid)
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .get();
      final activeFriendUids = friendDocs.docs.map((d) => d.id).toList();

      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final ownerId = data['ownerId'] ?? '';
            final sharedWith = List<String>.from(data['sharedWith'] ?? []);

            bool isMyOwn =
                ownerId == _uid ||
                (ownerId == '' && doc.reference.path.contains(_uid));
            bool isSharedToMeByActiveFriend =
                sharedWith.contains(_uid) && activeFriendUids.contains(ownerId);

            return isMyOwn || isSharedToMeByActiveFriend;
          })
          .map((doc) => Account.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  void _manageFriendsDialog() {
    _userSearchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const Text(
                  'Manage Connections',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _userSearchController,
                  decoration: InputDecoration(
                    labelText: 'Add by @username',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final username = _userSearchController.text
                            .trim()
                            .replaceAll('@', '');
                        if (username.isEmpty || username == _myUsername) return;

                        final query = await _db
                            .collection('users')
                            .where('username', isEqualTo: username)
                            .get();
                        if (query.docs.isNotEmpty) {
                          final targetUid = query.docs.first.id;
                          await _db
                              .collection('users')
                              .doc(_uid)
                              .collection('friends')
                              .doc(targetUid)
                              .set({'username': username, 'status': 'sent'});
                          await _db
                              .collection('users')
                              .doc(targetUid)
                              .collection('friends')
                              .doc(_uid)
                              .set({
                                'username': _myUsername,
                                'status': 'pending',
                              });
                          _userSearchController.clear();
                          setDialogState(() {});
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('users')
                        .doc(_uid)
                        .collection('friends')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final friends = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final fDoc = friends[index];
                          final fData = fDoc.data() as Map<String, dynamic>?;
                          if (fData == null) return const SizedBox.shrink();

                          final fUid = fDoc.id;
                          final status = (fData['status'] ?? 'pending')
                              .toString();
                          final fUsername = (fData['username'] ?? 'Unknown')
                              .toString();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '@$fUsername',
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: status == 'accepted'
                                    ? Colors.green
                                    : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'pending')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await _db
                                          .collection('users')
                                          .doc(_uid)
                                          .collection('friends')
                                          .doc(fUid)
                                          .update({'status': 'accepted'});
                                      await _db
                                          .collection('users')
                                          .doc(fUid)
                                          .collection('friends')
                                          .doc(_uid)
                                          .update({'status': 'accepted'});
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.person_remove,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _confirmRemoveFriend(fUid, fUsername),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveFriend(String fUid, String fUsername) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Remove Friend?'),
        content: Text(
          'Are you sure you want to remove @$fUsername? This will revoke access from all accounts for this user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final batch = _db.batch();
              batch.delete(
                _db
                    .collection('users')
                    .doc(_uid)
                    .collection('friends')
                    .doc(fUid),
              );
              batch.delete(
                _db
                    .collection('users')
                    .doc(fUid)
                    .collection('friends')
                    .doc(_uid),
              );

              final myAccounts = await _db
                  .collection('users')
                  .doc(_uid)
                  .collection('accounts')
                  .get();
              for (var doc in myAccounts.docs) {
                List sharedWith = List.from(doc.data()['sharedWith'] ?? []);
                if (sharedWith.contains(fUid)) {
                  sharedWith.remove(fUid);
                  batch.update(doc.reference, {'sharedWith': sharedWith});
                }
              }

              await batch.commit();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _manageSharing(Account acc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('users')
              .doc(_uid)
              .collection('friends')
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final friends = snapshot.data!.docs;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Share Account Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend =
                            friends[index].data() as Map<String, dynamic>;
                        final friendUid = friends[index].id;
                        final friendUsername = friend['username'];
                        final isShared = acc.sharedWith.contains(friendUid);

                        return CheckboxListTile(
                          title: Text('@$friendUsername'),
                          value: isShared,
                          onChanged: (val) async {
                            List<String> newSharedWith = List.from(
                              acc.sharedWith,
                            );
                            if (val == true) {
                              newSharedWith.add(friendUid);
                            } else {
                              newSharedWith.remove(friendUid);
                            }

                            setDialogState(() {
                              acc.sharedWith = newSharedWith;
                            });

                            String ownerId = acc.ownerId == ''
                                ? _uid
                                : acc.ownerId;
                            await _db
                                .collection('users')
                                .doc(ownerId)
                                .collection('accounts')
                                .doc(acc.id)
                                .update({
                                  'sharedWith': newSharedWith,
                                  'ownerId': ownerId,
                                  'ownerUsername': _myUsername,
                                });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _addAccount() {
    _accNameController.clear();
    _accLastFourController.clear();
    _accBalanceController.clear();
    String selectedCurrency = 'BHD';
    double conversionRate = 0.0014;
    Color selectedCardColor = Colors.blueGrey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'New Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _accNameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accLastFourController,
                  decoration: const InputDecoration(labelText: 'Last 4 Digits'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accBalanceController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Balance',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCurrency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        items: ['BHD', 'PKR', 'SAR']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedCurrency = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Rate to BHD',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) =>
                            conversionRate = double.tryParse(v) ?? 0.0,
                        controller: TextEditingController(
                          text: conversionRate.toString(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Card Color'),
                  trailing: CircleAvatar(
                    backgroundColor: selectedCardColor,
                    radius: 15,
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E1E),
                        title: const Text('Pick Color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: selectedCardColor,
                            onColorChanged: (color) =>
                                setDialogState(() => selectedCardColor = color),
                            enableAlpha: false,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final acc = Account(
                        id: '',
                        ownerId: _uid,
                        ownerUsername: _myUsername,
                        name: _accNameController.text,
                        lastFour: _accLastFourController.text,
                        currency: selectedCurrency,
                        colorValue: selectedCardColor.value,
                        balance:
                            double.tryParse(_accBalanceController.text) ?? 0,
                        conversionRate: conversionRate,
                        sharedWith: [],
                      );
                      await _db
                          .collection('users')
                          .doc(_uid)
                          .collection('accounts')
                          .add(acc.toJson());
                      Navigator.pop(context);
                    },
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEntrySheet(Account acc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _editingTxId == null ? 'New Entry' : 'Edit Entry',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheetState(() => _isExpense = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isExpense
                              ? Colors.green.withOpacity(0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: !_isExpense
                                ? Colors.green
                                : Colors.grey[800]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Income',
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheetState(() => _isExpense = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isExpense
                              ? Colors.red.withOpacity(0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: _isExpense ? Colors.red : Colors.grey[800]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'Expense',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  suffixText: acc.currency,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setSheetState(() => _selectedDate = d);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[800]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yy').format(_selectedDate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (t != null) setSheetState(() => _selectedTime = t);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[800]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _handleTransaction(acc);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    _editingTxId == null ? 'Add Transaction' : 'Update',
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTransaction(Account acc) async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final txDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final batch = _db.batch();
    String ownerId = acc.ownerId == '' ? _uid : acc.ownerId;
    final accRef = _db
        .collection('users')
        .doc(ownerId)
        .collection('accounts')
        .doc(acc.id);
    final txRef = _editingTxId == null
        ? accRef.collection('transactions').doc()
        : accRef.collection('transactions').doc(_editingTxId);

    if (_editingTxId != null) {
      final oldTxSnap = await txRef.get();
      final oldData = oldTxSnap.data() as Map<String, dynamic>;
      final oldAmount = (oldData['amount'] as num).toDouble();
      final oldIsExpense = oldData['isExpense'] as bool;

      double balanceAdjust = oldIsExpense ? oldAmount : -oldAmount;
      balanceAdjust += _isExpense ? -amount : amount;
      batch.update(accRef, {'balance': acc.balance + balanceAdjust});
    } else {
      batch.update(accRef, {
        'balance': acc.balance + (_isExpense ? -amount : amount),
      });
    }

    batch.set(txRef, {
      'description': _descController.text.isEmpty
          ? 'General'
          : _descController.text,
      'dateTime': Timestamp.fromDate(txDate),
      'amount': amount,
      'isExpense': _isExpense,
    });
    await batch.commit();

    _amountController.clear();
    _descController.clear();
    _editingTxId = null;
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
  }

  void _showCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          const SizedBox(height: 600, child: CalculatorWidget()),
    );
  }

  Widget _buildUserHeader() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(_uid)
          .collection('friends')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return PopupMenuButton<String>(
          offset: const Offset(0, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (val) async {
            if (val == 'logout') {
              await FirebaseAuth.instance.signOut();
              if (mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                );
            } else if (val == 'add') {
              _manageFriendsDialog();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'add',
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1, size: 18),
                  const SizedBox(width: 8),
                  const Text('Manage Friends'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Logout', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white12,
                      child: Text(
                        _myUsername.isNotEmpty
                            ? _myUsername[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  _myUsername,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 16,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Account>>(
          stream: _accountsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading account'),
                  ],
                ),
              );
            final accounts = snapshot.data ?? [];
            if (_activeIdx >= accounts.length && accounts.isNotEmpty)
              _activeIdx = accounts.length - 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Finance Tracker',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildUserHeader(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _showCalculator,
                                icon: const Icon(
                                  Icons.calculate_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                              IconButton(
                                onPressed: _addAccount,
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: accounts.isEmpty
                      ? const Center(child: Text('No accounts added'))
                      : ScrollConfiguration(
                          behavior: MouseScrollBehavior(),
                          child: PageView.builder(
                            controller: _pageController,
                            onPageChanged: (i) => setState(() {
                              _activeIdx = i;
                              _isFlipped = false;
                            }),
                            itemCount: accounts.length,
                            itemBuilder: (context, index) {
                              final acc = accounts[index];
                              bool isDeleting = _deletingAccountId == acc.id;

                              return AnimatedOpacity(
                                duration: const Duration(milliseconds: 500),
                                opacity: isDeleting ? 0.0 : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  margin: EdgeInsets.only(
                                    bottom: isDeleting ? 200 : 0,
                                    left: 8.0,
                                    right: 8.0,
                                  ),
                                  child: TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 500),
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: (_isFlipped && _activeIdx == index)
                                          ? pi
                                          : 0,
                                    ),
                                    builder: (context, double value, child) {
                                      bool isBack = value >= pi / 2;
                                      return Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, 0.001)
                                          ..rotateY(value),
                                        child: isBack
                                            ? Transform(
                                                alignment: Alignment.center,
                                                transform: Matrix4.identity()
                                                  ..rotateY(pi),
                                                child: _buildSettingsCard(acc),
                                              )
                                            : _buildFrontCard(acc),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: accounts.isEmpty
                      ? const Center(child: Text('No transactions'))
                      : _buildTransactionList(accounts[_activeIdx]),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: StreamBuilder<List<Account>>(
        stream: _accountsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () {
              setState(() {
                _editingTxId = null;
                _amountController.clear();
                _descController.clear();
                _selectedDate = DateTime.now();
                _selectedTime = TimeOfDay.now();
                _isExpense = true;
              });
              _showEntrySheet(snapshot.data![_activeIdx]);
            },
            backgroundColor: Colors.white,
            child: const Icon(Icons.add, color: Colors.black),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(Account acc) {
    String ownerId = acc.ownerId == '' ? _uid : acc.ownerId;
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(ownerId)
          .collection('accounts')
          .doc(acc.id)
          .collection('transactions')
          .orderBy('dateTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading Transactions'),
              ],
            ),
          );
        if (!snapshot.hasData) return const SizedBox.shrink();
        final txs = snapshot.data!.docs
            .map(
              (doc) => Transaction.fromJson(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList();
        if (txs.isEmpty) return const Center(child: Text('No transactions'));
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: txs.length,
          itemBuilder: (context, index) {
            final tx = txs[index];
            return Dismissible(
              key: Key(tx.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (dir) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2C),
                    title: const Text('Confirm'),
                    content: const Text('Delete this transaction?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes'),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (dir) async {
                final batch = _db.batch();
                final specificAccRef = _db
                    .collection('users')
                    .doc(ownerId)
                    .collection('accounts')
                    .doc(acc.id);
                batch.update(specificAccRef, {
                  'balance':
                      acc.balance + (tx.isExpense ? tx.amount : -tx.amount),
                });
                batch.delete(
                  specificAccRef.collection('transactions').doc(tx.id),
                );
                await batch.commit();
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: ListTile(
                onTap: () {
                  setState(() {
                    _editingTxId = tx.id;
                    _amountController.text = tx.amount.toString();
                    _descController.text = tx.description;
                    _isExpense = tx.isExpense;
                    _selectedDate = tx.dateTime;
                    _selectedTime = TimeOfDay.fromDateTime(tx.dateTime);
                  });
                  _showEntrySheet(acc);
                },
                title: Text(tx.description),
                subtitle: Text(
                  DateFormat('MMM dd, hh:mm a').format(tx.dateTime),
                ),
                trailing: Text(
                  '${tx.isExpense ? "-" : "+"}${_f.format(tx.amount)} ${acc.currency}',
                  style: TextStyle(
                    color: tx.isExpense ? Colors.redAccent : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFrontCard(Account acc) {
    bool isShared = acc.ownerId != '' && acc.ownerId != _uid;
    List<Shadow> textShadows = [
      Shadow(offset: const Offset(1, 1), color: Colors.black.withOpacity(0.8)),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Color(acc.colorValue),
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          colors: [
            Color(acc.colorValue),
            Color(acc.colorValue).withOpacity(0.7),
          ],
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            acc.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              shadows: textShadows,
                            ),
                          ),
                          if (isShared)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                'Shared By @${acc.ownerUsername}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                  shadows: textShadows,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 35),
                      child: Text(
                        acc.currency,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          shadows: textShadows,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '•••• •••• •••• ${acc.lastFour}',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 16,
                    shadows: textShadows,
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: _db
                      .collection('users')
                      .doc(acc.ownerId == '' ? _uid : acc.ownerId)
                      .collection('accounts')
                      .doc(acc.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      );
                    }
                    final data = snapshot.data?.data() as Map<String, dynamic>?;
                    final balance = (data?['balance'] ?? 0.0).toDouble();
                    return Text(
                      '${_f.format(balance)} ${acc.currency}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: textShadows,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 15,
            right: 15,
            child: Row(
              children: [
                if (acc.sharedWith.isNotEmpty)
                  ...acc.sharedWith.take(3).map((uid) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: _db.collection('users').doc(uid).get(),
                      builder: (context, snap) {
                        if (!snap.hasData) return const SizedBox.shrink();
                        String username = snap.data!['username'] ?? '?';
                        return Container(
                          margin: const EdgeInsets.only(left: 4),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.white24,
                            child: Text(
                              username[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
              ],
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: IconButton(
              onPressed: () => setState(() => _isFlipped = true),
              icon: Icon(
                Icons.edit,
                size: 18,
                color: Colors.white70,
                shadows: textShadows,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(Account acc) {
    bool isOwner = acc.ownerId == '' || acc.ownerId == _uid;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white54,
                  ),
                ),
                Row(
                  children: [
                    if (isOwner)
                      IconButton(
                        onPressed: () => _manageSharing(acc),
                        icon: const Icon(
                          Icons.share,
                          size: 16,
                          color: Colors.white54,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _isFlipped = false),
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 4,
              radius: const Radius.circular(10),
              controller: _settingsScrollController,
              child: SingleChildScrollView(
                controller: _settingsScrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: acc.name,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              isDense: true,
                            ),
                            onChanged: (v) => acc.name = v,
                            enabled: isOwner,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: acc.lastFour,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Last 4',
                              isDense: true,
                            ),
                            onChanged: (v) => acc.lastFour = v,
                            enabled: isOwner,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: acc.balance.toString(),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Initial Balance',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) =>
                                acc.balance = double.tryParse(v) ?? 0.0,
                            enabled: isOwner,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: acc.currency,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Currency',
                              isDense: true,
                            ),
                            items: ['BHD', 'PKR', 'SAR']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: isOwner
                                ? (v) => setState(() => acc.currency = v!)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: acc.conversionRate.toString(),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Rate to BHD',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) =>
                                acc.conversionRate = double.tryParse(v) ?? 0.0,
                            enabled: isOwner,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Color',
                              style: TextStyle(fontSize: 11),
                            ),
                            trailing: CircleAvatar(
                              backgroundColor: Color(acc.colorValue),
                              radius: 12,
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E1E1E),
                                  title: const Text('Pick Color'),
                                  content: SingleChildScrollView(
                                    child: ColorPicker(
                                      pickerColor: Color(acc.colorValue),
                                      onColorChanged: (color) => setState(
                                        () => acc.colorValue = color.value,
                                      ),
                                      enableAlpha: false,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Done'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isOwner)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF2C2C2C),
                          title: const Text('Delete Account'),
                          content: const Text(
                            'Are you sure you want to delete this account and its history?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                setState(() {
                                  _isFlipped = false;
                                  _deletingAccountId = acc.id;
                                });

                                await Future.delayed(
                                  const Duration(milliseconds: 600),
                                );

                                String ownerId = acc.ownerId == ''
                                    ? _uid
                                    : acc.ownerId;
                                await _db
                                    .collection('users')
                                    .doc(ownerId)
                                    .collection('accounts')
                                    .doc(acc.id)
                                    .delete();

                                setState(() {
                                  _deletingAccountId = null;
                                  _activeIdx = 0;
                                });
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      String ownerId = acc.ownerId == '' ? _uid : acc.ownerId;
                      await _db
                          .collection('users')
                          .doc(ownerId)
                          .collection('accounts')
                          .doc(acc.id)
                          .update(acc.toJson());
                      setState(() => _isFlipped = false);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
