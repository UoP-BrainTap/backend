import 'dart:convert';
import 'dart:math';

import 'package:test/test.dart';
import 'package:shelf/shelf.dart';

import '../bin/controllers/auth.controller.dart';

void main() {
  group('AuthController', () {
    group('Sign up', () {
      test('Sign up Normal', () async {
        var response = await AuthController.signup(
            Request('POST', Uri.parse('http://localhost:8080/signup'),
                context: {
                  'json': {
                    'email': '${getRandomString(5)}@gmail.com',
                    'password': 'D@Ew81&Je536RQRv@%p',
                    'accountType': 'lecturer'
                  }
                }
            ));
        var body = await response.readAsString();
        printOnFailure(body);
        expect(response.statusCode, 200);
        var data = jsonDecode(body);
        expect(data['id'], isNotNull);
        expect(data['id'], isNotNaN);
        expect(data['id'].runtimeType, int);
        expect(data['accessToken'], isNotNull);
        expect(data['accessToken'].runtimeType, String);
      });

      test('Sign up Invalid Email', () async {
        var response = await AuthController.signup(
            Request('POST', Uri.parse('http://localhost:8080/signup'),
                context: {
                  'json': {
                    'email': 'invalid-email',
                    'password': 'D@Ew81&Je536RQRv@%p',
                    'accountType': 'lecturer'
                  }
                }
            ));
        var body = await response.readAsString();
        printOnFailure(body);
        expect(response.statusCode, 400);
      });

      test('Sign up Invalid Password', () async {
        var response = await AuthController.signup(
            Request('POST', Uri.parse('http://localhost:8080/signup'),
                context: {
                  'json': {
                    'email': '${getRandomString(5)}@gmail.com',
                    'password': '',
                    'accountType': 'lecturer'
                  }
                }
            ));
        var body = await response.readAsString();
        printOnFailure(body);
        expect(response.statusCode, 400);
      });
    });

    test('Sign up Invalid Account Type', () async {
      var response = await AuthController.signup(
          Request('POST', Uri.parse('http://localhost:8080/signup'),
              context: {
                'json': {
                  'email': '${getRandomString(5)}@gmail.com',
                  'password': 'D@Ew81&Je536RQRv@%p',
                  'accountType': 'invalid-account-type'
                }
              }
          ));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 400);
    });

    test('Missing data in request', () async {
      var response = await AuthController.signup(
          Request('POST', Uri.parse('http://localhost:8080/signup'),
              context: {
                'json': {}
              }
          ));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 400);
    });
  });

  group('Login', () {
    test('Login Normal', () async {
      var response = await AuthController.login(
          Request('POST', Uri.parse('http://localhost:8080/login'),
              context: {
                'json': {
                  'email': 'test@gmail.com',
                  'password': 'Starter45'
                }
              }
          ));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
      var data = jsonDecode(body);
      expect(data['id'], isNotNull);
      expect(data['id'], isNotNaN);
      expect(data['id'].runtimeType, int);
      expect(data['accessToken'], isNotNull);
      expect(data['accessToken'].runtimeType, String);
      expect(data['role'], isNotNull);
      expect(data['role'].runtimeType, String);
      expect(['lecturer', 'student'].contains(data['role']), isTrue);
    });

    test('Login Invalid Email', () async {
      var response = await AuthController.login(
          Request('POST', Uri.parse('http://localhost:8080/login'),
              context: {
                'json': {
                  'email': 'invalid-email',
                  'password': 'D@Ew81&Je536RQRv@%p'
                }
              }
          ));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 400);
    });

    test('Login invalid password', () async {
      var response = await AuthController.login(
          Request('POST', Uri.parse('http://localhost:8080/login'),
              context: {
                'json': {
                  'email': 'test@gmail.com',
                  'password': ''
                }
              }
          ));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 401);
    });

    test('Login user not found', () async {
      var response = await AuthController.login(
          Request('POST', Uri.parse('http://localhost:8080/login'),
              context: {
                'json': {
                  'email': '${getRandomString(5)}@gmail.com',
                  'password': 'D@Ew81&Je536RQRv@%p'
                }
              }
          ));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 404);
    });

    test('Login password incorrect', () async {
      var response = await AuthController.login(
          Request('POST', Uri.parse('http://localhost:8080/login'),
              context: {
                'json': {
                  'email': 'test@gmail.com',
                  'password': 'D@Ew81&Je536RQRv@%p'
                }
              }
          ));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 401);
    });
  });
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) =>
    String.fromCharCodes(Iterable.generate(
        length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));