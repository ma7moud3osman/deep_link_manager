import 'package:deep_link_manager/deep_link_manager.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deepLinkManager = DeepLinkManager();

  // Initialize with strategies and auth provider
  await deepLinkManager.initialize(
    strategies: [ProductDeepLinkStrategy()],
    authProvider: SimpleDeepLinkAuthProvider(deepLinkManager.navigatorKey),
    onLog: (message) => debugPrint(message),
  );

  runApp(
    ChangeNotifierProvider(create: (_) => AuthNotifier(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Use the navigatorKey from DeepLinkManager
    final router = GoRouter(
      navigatorKey: DeepLinkManager().navigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'];
            return ProductScreen(id: id ?? 'Unknown');
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Deep Link Manager Example',
      routerConfig: router,
    );
  }
}

// --- Strategies ---

class ProductDeepLinkStrategy implements DeepLinkStrategy {
  @override
  String get identifier => 'ProductStrategy';

  @override
  int get priority => 1;

  @override
  bool canHandle(Uri uri) {
    // Handles deep links like: scheme://product/123 or https://domain.com/product/123
    // For this example, we assume the path starts with 'product'
    return uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'product';
  }

  @override
  Object? extractData(Uri uri) {
    if (uri.pathSegments.length > 1) {
      return uri.pathSegments[1]; // The product ID
    }
    return null;
  }

  @override
  bool get requiresAuth => true;

  @override
  void handle(Uri uri, BuildContext context, Object? data) {
    if (data is String) {
      GoRouter.of(context).push('/product/$data');
    }
  }
}

// --- Auth Provider ---

class SimpleDeepLinkAuthProvider implements DeepLinkAuthProvider {
  final GlobalKey<NavigatorState> navigatorKey;

  SimpleDeepLinkAuthProvider(this.navigatorKey);

  @override
  bool get isAuthenticated {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    // Check our simple AuthNotifier
    return Provider.of<AuthNotifier>(context, listen: false).isLoggedIn;
  }

  @override
  void onAuthRequired(Uri uri) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).push('/login');
    }
  }
}

// --- State Management ---

class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  void login() {
    _isLoggedIn = true;
    notifyListeners();
    // After login, check for pending deep links
    DeepLinkManager().setAppReady();
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
    DeepLinkManager().clearPendingLink();
  }
}

// --- Screens ---

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Signal that the app is ready to process deep links
    // In a real app, you might do this after a splash screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkManager().setAppReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Status: ${auth.isLoggedIn ? "Logged In" : "Guest"}'),
            const SizedBox(height: 20),
            if (!auth.isLoggedIn)
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Go to Login'),
              ),
            if (auth.isLoggedIn)
              ElevatedButton(
                onPressed: () => auth.logout(),
                child: const Text('Logout'),
              ),
            const Divider(height: 40),
            const Text(
              'Test Deep Links via ADB (Android):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'adb shell am start -a android.intent.action.VIEW -d "example://product/123"',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            context.read<AuthNotifier>().login();
            if (context.canPop()) context.pop();
          },
          child: const Text('Login & Continue'),
        ),
      ),
    );
  }
}

class ProductScreen extends StatelessWidget {
  final String id;
  const ProductScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Product $id')),
      body: Center(
        child: Text(
          'Viewing Product Details for ID: $id',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
