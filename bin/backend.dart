import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'routes/auth.route.dart';
import 'middleware/body.middleware.dart';

void main() async {
  await Database.connect();
  
  var service = Service();
  var handler = Pipeline()
    .addMiddleware(logRequests())
    .addMiddleware(BodyMiddleware().middleware)
    .addHandler(service.handler);
  var server = await shelf_io.serve(handler, 'localhost', 8080);
}

class Service {
  Handler get handler {
    final root = Router();
    final apiRouterV1 = Router();

    root.mount("/auth", Auth().router.call);

    root.mount("/api/v1", apiRouterV1.call);
    return root.call;
  }
}

class Database {
  static late Connection db;

  static Future<void> connect() async {
    db = await Connection.open(
        Endpoint(
            host: 'braintap-postgres.postgres.database.azure.com',
            database: 'braintap',
            username: 'ben',
            password: 'Yc7weLX5!hff5a#c2mJB'
        )
    );
  }
}