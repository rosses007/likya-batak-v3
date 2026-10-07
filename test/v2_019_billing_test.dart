import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:batak_app/providers/store_provider.dart';

class FakeGateway implements PurchaseGateway {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  bool failRestore = false;
  bool failComplete = false;
  int restores = 0;
  int completes = 0;
  int buys = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: [
        ProductDetails(
          id: vipMonthlyProductId,
          title: 'VIP',
          description: 'VIP',
          price: '₺49,99',
          rawPrice: 49.99,
          currencyCode: 'TRY',
        )
      ], notFoundIDs: []);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buys++;
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restores++;
    if (failRestore) throw StateError('offline');
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completes++;
    if (failComplete) throw StateError('completion failed');
  }

  void send(PurchaseDetails purchase) => controller.add([purchase]);
}

PurchaseDetails event(
  PurchaseStatus status, {
  String product = vipMonthlyProductId,
  bool receipt = true,
  bool complete = false,
}) {
  final purchase = PurchaseDetails(
    productID: product,
    purchaseID: 'transaction-1',
    transactionDate: '1000',
    status: status,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: receipt ? 'receipt' : '',
      source: 'google_play',
    ),
  );
  purchase.pendingCompletePurchase = complete;
  return purchase;
}

Future<void> settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway gateway;
  late StoreProvider store;
  bool disposed = false;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gateway = FakeGateway();
    store = StoreProvider(gateway: gateway);
    disposed = false;
    await settle();
  });
  tearDown(() async {
    if (!disposed) store.dispose();
    await gateway.controller.close();
  });

  test(
      'valid purchase activates VIP and completes once across duplicate events',
      () async {
    final purchase = event(PurchaseStatus.purchased, complete: true);
    gateway.send(purchase);
    await settle();
    expect(store.isVip, isTrue);
    expect(gateway.completes, 1);
    gateway.send(purchase);
    await settle();
    expect(gateway.completes, 1);
    expect((await SharedPreferences.getInstance()).getBool('isVip'), isTrue);
  });
  test('valid restored purchase activates fresh install', () async {
    expect(store.isVip, isFalse);
    gateway.send(event(PurchaseStatus.restored));
    await settle();
    expect(store.isVip, isTrue);
  });
  test('completion failure does not revoke VIP or crash', () async {
    gateway.failComplete = true;
    gateway.send(event(PurchaseStatus.purchased, complete: true));
    await settle();
    expect(store.isVip, isTrue);
    expect(gateway.completes, 1);
  });
  test('wrong product and missing verification data do not grant VIP',
      () async {
    gateway.send(event(PurchaseStatus.purchased, product: 'unknown'));
    await settle();
    expect(store.isVip, isFalse);
    gateway.send(event(PurchaseStatus.purchased, receipt: false));
    await settle();
    expect(store.isVip, isFalse);
  });
  test('pending, error, and canceled never activate VIP', () async {
    for (final status in [
      PurchaseStatus.pending,
      PurchaseStatus.error,
      PurchaseStatus.canceled
    ]) {
      gateway.send(event(status));
      await settle();
      expect(store.isVip, isFalse);
    }
  });
  test('error and cancellation preserve existing entitlement', () async {
    gateway.send(event(PurchaseStatus.purchased));
    await settle();
    gateway.send(event(PurchaseStatus.error));
    gateway.send(event(PurchaseStatus.canceled));
    await settle();
    expect(store.isVip, isTrue);
  });
  test('restore action uses gateway and reports failure', () async {
    final before = gateway.restores;
    await store.restorePurchases();
    expect(gateway.restores, before + 1);
    expect(store.isRestoring, isFalse);
    gateway.failRestore = true;
    await store.restorePurchases();
    expect(store.feedback, contains('yüklenemedi'));
  });
  test('buy action calls gateway without prematurely granting VIP', () async {
    store.buyVip();
    await settle();
    expect(gateway.buys, 1);
    expect(store.isVip, isFalse);
    expect(store.isPurchasePending, isTrue);
  });
  test('cached VIP survives unavailable store and loads deterministically',
      () async {
    store.dispose();
    await gateway.controller.close();
    SharedPreferences.setMockInitialValues({'isVip': true});
    gateway = FakeGateway()..available = false;
    store = StoreProvider(gateway: gateway);
    await settle();
    expect(store.vipStatusLoaded, isTrue);
    expect(store.isVip, isTrue);
  });
  test('fresh install offline keeps ad gate closed until entitlement refresh', () async {
    store.dispose();
    await gateway.controller.close();
    SharedPreferences.setMockInitialValues({});
    gateway = FakeGateway()..available = false;
    store = StoreProvider(gateway: gateway);
    await settle();
    expect(store.isVip, isFalse);
    expect(store.vipStatusLoaded, isFalse);
  });
  test('dispose cancels purchase subscription', () async {
    store.dispose();
    disposed = true;
    expect(gateway.controller.hasListener, isFalse);
  });
}
