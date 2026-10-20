import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CalculatorWidget extends StatefulWidget {
  const CalculatorWidget({super.key});

  @override
  State<CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  String _input = '';
  String _result = '0';
  String _convertedResult = '0';
  String _inputCurrency = 'BHD';
  String _targetCurrency = 'PKR';
  final TextEditingController _rateController = TextEditingController();
  final FocusNode _calcFocusNode = FocusNode();
  late final FocusNode _rateFocusNode = _calcFocusNode;
  final NumberFormat _f = NumberFormat('#,##0.000', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _calcFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _inputCurrency = prefs.getString('calc_input_curr') ?? 'BHD';
      _targetCurrency = prefs.getString('calc_target_curr') ?? 'PKR';
      String key = 'rate_${_inputCurrency}_$_targetCurrency';
      _rateController.text = prefs.getString(key) ?? '1.0';
    });
  }

  Future<void> _updateRateDisplay() async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'rate_${_inputCurrency}_$_targetCurrency';
    setState(() {
      _rateController.text = prefs.getString(key) ?? '1.0';
      _calculate();
    });
  }

  Future<void> _saveCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calc_input_curr', _inputCurrency);
    await prefs.setString('calc_target_curr', _targetCurrency);
    String key = 'rate_${_inputCurrency}_$_targetCurrency';
    await prefs.setString(key, _rateController.text);
  }

  void _onPressed(String text) {
    if (text == 'C') {
      HapticFeedback.heavyImpact();
      setState(() {
        _input = '';
        _result = '0';
        _convertedResult = '0';
      });
    } else if (text == '=') {
      HapticFeedback.mediumImpact();
      _calculate();
    } else if (text == '⌫') {
      HapticFeedback.lightImpact();
      setState(() {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
      });
    } else {
      HapticFeedback.selectionClick();
      setState(() {
        _input += text;
      });
    }
  }

  void _calculate() {
    try {
      if (_input.isEmpty) return;
      String finalInput = _input.replaceAll('x', '*');
      Parser p = Parser();
      Expression exp = p.parse(finalInput);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      _result = _f.format(eval);

      double rate = double.tryParse(_rateController.text) ?? 1.0;
      _convertedResult = _f.format(eval * rate);

      setState(() {});
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() {
        _result = 'Error';
        _convertedResult = '0';
      });
    }
  }

  void _copyToClipboard(String value) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $value'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildButton(String text, {Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ElevatedButton(
          onPressed: () => _onPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? const Color(0xFF2C2C2C),
            foregroundColor: textColor ?? Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _inputCurrency,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  underline: const SizedBox(),
                  items: ['BHD', 'PKR', 'SAR']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _inputCurrency = v!;
                      _updateRateDisplay();
                      _saveCurrentSettings();
                    });
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    '=',
                    style: TextStyle(color: Colors.white38, fontSize: 20),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _rateController,
                    focusNode: _rateFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    onChanged: (v) {
                      _saveCurrentSettings();
                      _calculate();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _targetCurrency,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  underline: const SizedBox(),
                  items: ['BHD', 'PKR', 'SAR']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _targetCurrency = v!;
                      _updateRateDisplay();
                      _saveCurrentSettings();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _input,
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onLongPress: () => _copyToClipboard(_result),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$_result $_inputCurrency',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onLongPress: () => _copyToClipboard(_convertedResult),
                    child: Text(
                      '~ $_convertedResult $_targetCurrency',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildButton(
                        'C',
                        color: Colors.redAccent.withOpacity(0.8),
                      ),
                      _buildButton('(', color: Colors.grey[800]),
                      _buildButton(')', color: Colors.grey[800]),
                      _buildButton('/', color: Colors.orange),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('x', color: Colors.orange),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('-', color: Colors.orange),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('+', color: Colors.orange),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildButton('0'),
                      _buildButton('.'),
                      _buildButton('⌫', color: Colors.grey[800]),
                      _buildButton('=', color: Colors.green),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
