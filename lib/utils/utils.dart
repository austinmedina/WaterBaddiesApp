import 'package:flutter/foundation.dart'; // Import for Listenable

class BooleanWrapper with ChangeNotifier implements Listenable{
  bool _value;

  BooleanWrapper(this._value);

  bool get value => _value;

  set value(bool newValue) {
    if (_value != newValue) {
      _value = newValue;
      notifyListeners(); // Notify listeners when the value changes
    }
  }
}

class BooleanWrapperValueNotifier extends ValueNotifier<bool> {
  final BooleanWrapper _booleanWrapper;

  BooleanWrapperValueNotifier(this._booleanWrapper) : super(_booleanWrapper.value) {
    _booleanWrapper.addListener(_updateValue);
  }

  void _updateValue() {
    value = _booleanWrapper.value;
  }

  @override
  void dispose() {
    _booleanWrapper.removeListener(_updateValue);
    super.dispose();
  }
}