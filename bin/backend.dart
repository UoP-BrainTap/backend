import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  var handler = const Pipeline().addMiddleware(logRequests()).addHandler(handler);
  var service = Service();
  var server = await shelf_io.serve(service.handler, 'localhost', 8080);
}

class Service {
  Handler get handler {
    final route = Router();
    // my comment here
    // new comment

    return route;
  }
}