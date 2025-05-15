import 'package:test/test.dart';

import '../bin/utils/validators.dart';

void main() {
  group('Validators', () {
    test('Validate Email', () {
      expect(Validators.validateEmail("test@gmail.com"), isTrue);
    });

    test('Validate Incorrect Email 1', () {
      expect(Validators.validateEmail("test@gmail"), isFalse);
    });

    test('Validate Incorrect Email 2', () {
      expect(Validators.validateEmail("test'gmail.com"), isFalse);
    });
    
    test('Validate Account type lecturer', () {
      expect(Validators.validateAccountType("lecturer"), isTrue);
    });
    
    test('Validate Account type student', () {
      expect(Validators.validateAccountType("student"), isTrue);
    });
    
    test('Validate Account type admin', () {
      expect(Validators.validateAccountType("admin"), isTrue);
    });
    
    test('Validate Account type invalid', () {
      expect(Validators.validateAccountType("invalid"), isFalse);
    });
    
    test('Validate Password', () {
      expect(Validators.validatePassword("Ctmnp&%uPvkN2UJR@!6n"), isTrue);
    });

    test('Validate Incorrect Password', () {
      expect(Validators.validatePassword("SimplePassword"), isFalse);
    });
  });
}