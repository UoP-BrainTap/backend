import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'routes/auth.route.dart';
import 'routes/questions.route.dart';
import 'routes/session.route.dart';
import 'middleware/body.middleware.dart';
import 'middleware/auth.middleware.dart';

void main() async {
  await Database.connect();
  
  var service = Service();
  var handler = Pipeline()
    .addMiddleware(logRequests())
    .addMiddleware(BodyMiddleware().middleware)
    .addMiddleware(corsHeaders())
    .addHandler(service.handler);
  var server = await shelf_io.serve(handler, 'localhost', 8080);
}

class Service {
  Handler get handler {
    final root = Router();
    final apiRouterV1 = Router();

    apiRouterV1.mount("/questions", Questions().router.call);
    apiRouterV1.mount("/sessions", Sessions().router.call);

    root.mount("/auth", Auth().router.call);
    root.mount("/ws", Sessions().socket);

    // authenticated routes
    root.mount("/api/v1", Pipeline()
        .addMiddleware(AuthMiddleware().middleware)
        .addHandler(apiRouterV1.call));

    return root.call;
  }
}

/// Handles the database connection
class Database {
  static Connection? _db;

  /// Returns a singleton instance of the database connection. If the connection
  /// is already established, it returns the existing connection.
  static Future<Connection> get db async {
    if (_db == null) {
      _db = await connect();
      return _db!;
    } else {
      return _db!;
    }
  }

  /// Opens a new connection to the database using the provided credentials.
  static Future<Connection> connect() {
     return Connection.open(
        Endpoint(
            host: 'braintap-postgres.postgres.database.azure.com',
            database: 'braintap',
            username: 'ben',
            password: 'BC^7L5VQhN@KMEa6eT4y'
        )
    );
  }
}