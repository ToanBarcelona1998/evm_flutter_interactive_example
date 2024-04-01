import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:trust_wallet_core/flutter_trust_wallet_core.dart';
import 'package:trust_wallet_core/trust_wallet_core_ffi.dart';
import 'package:web3dart/web3dart.dart';

// ignore_for_file: public_member_api_docs
import 'package:trust_wallet_core/protobuf/Ethereum.pb.dart' as Ethereum;

import 'package:http/http.dart';

extension BigIntE on BigInt {
  Uint8List toUin8List() {
    final byteMask = BigInt.from(0xff);
    var number = this;
    final size = (number.bitLength + 7) >> 3;
    final result = Uint8List(size);

    for (var i = 0; i < size; i++) {
      result[size - i - 1] = (number & byteMask).toInt();
      number = number >> 8;
    }
    return result;
  }
}

String strip0x(String hex) {
  if (hex.startsWith('0x')) return hex.substring(2);
  return hex;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterTrustWalletCore.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Web3Client _web3client;

  final int coinType = TWCoinType.TWCoinTypeEthereum;

  // Input your phrase
  final String phrase = '';
  //https://ethereum-sepolia-rpc.publicnode.com
  // Input your rpc. Or use ethereum sepolia
  final String rpc = 'https://ethereum-sepolia-rpc.publicnode.com';

  @override
  void initState() {
    _web3client = Web3Client(
      rpc,
      Client(),
    );
    super.initState();
  }

  void _testCreateEthereumWallet() async {
    final HDWallet hdWallet = HDWallet.createWithMnemonic(
      phrase,
    );

    print(
      hdWallet.mnemonic(),
    );

    final address = hdWallet.getAddressForCoin(coinType);

    print(address);

    _web3client.makeRPCCall(
      'eth_getBalance',
      [
        address,
        const BlockNum.current().toBlockParam(),
      ],
    ).then((value) {
      print('Amount = ${BigInt.parse(value)}');
    });
  }

  void _sendTransaction() async {
    try {
      final HDWallet hdWallet = HDWallet.createWithMnemonic(
        phrase,
      );

      final chainId = await _web3client.getChainId();

      print('ethereum chain Id = $chainId');

      // Input your recipient address
      const String recipientAddress = '';

      Ethereum.SigningInput signingInput = Ethereum.SigningInput(
        toAddress: recipientAddress,
        privateKey: hdWallet.getKeyForCoin(coinType).data(),
        chainId: chainId.toUin8List(),
        gasPrice: BigInt.parse('d693a400', radix: 16).toUin8List(),
        gasLimit: BigInt.parse('5208', radix: 16).toUin8List(),
        transaction: Ethereum.Transaction(
          transfer: Ethereum.Transaction_Transfer(
            amount: BigInt.parse('0348bca5a16000', radix: 16).toUin8List(),
          ),
        ),
      );

      final Uint8List signBytes = AnySigner.sign(
        signingInput.writeToBuffer(),
        coinType,
      );

      final outPut = Ethereum.SigningOutput.fromBuffer(signBytes);

      final String hash = await _web3client.sendRawTransaction(
        Uint8List.fromList(outPut.encoded),
      );

      print('receive transaction hash ${hash}');

      final TransactionInformation? tx =
          await _web3client.getTransactionByHash(hash);

      print('tx != null ${tx != null}');
    } catch (e) {
      print('receive error ${e.toString()}');
    }
  }

  void _sendERC721() async {
    try {
      final HDWallet hdWallet = HDWallet.createWithMnemonic(
        phrase,
      );

      final chainId = await _web3client.getChainId();

      final nonce = await _web3client.makeRPCCall('eth_getTransactionCount', [
        hdWallet.getAddressForCoin(
          coinType,
        ),
        const BlockNum.current().toBlockParam(),
      ]);

      print('ethereum chain Id = $chainId');

      // Input your recipient address
      const String recipientAddress = '';
      // Input your contract address
      const String contractAddress = '';
      Ethereum.SigningInput signingInput = Ethereum.SigningInput(
        toAddress: contractAddress,
        privateKey:
            hdWallet.getKeyForCoin(TWCoinType.TWCoinTypeEthereum).data(),
        chainId: chainId.toUin8List(),
        gasPrice: BigInt.parse('d693a4000', radix: 16).toUin8List(),
        gasLimit: BigInt.parse('42208', radix: 16).toUin8List(),
        nonce: BigInt.parse(strip0x(nonce), radix: 16).toUin8List(),
        transaction: Ethereum.Transaction(
            erc721Transfer: Ethereum.Transaction_ERC721Transfer(
              from: hdWallet.getAddressForCoin(
                coinType,
              ),
              to: recipientAddress,
              tokenId: BigInt.from(143).toUin8List(),
            ),
            contractGeneric: Ethereum.Transaction_ContractGeneric()),
      );

      final Uint8List signBytes = AnySigner.sign(
        signingInput.writeToBuffer(),
        coinType,
      );

      final outPut = Ethereum.SigningOutput.fromBuffer(signBytes);

      final String hash = await _web3client.sendRawTransaction(
        Uint8List.fromList(outPut.encoded),
      );

      print('receive transaction hash ${hash}');

      final tx = await _web3client.makeRPCCall(
        'eth_getTransactionByHash',
        [hash],
      );

      print('tx != null ${tx != null}');

      print(tx);
    } catch (e) {
      print('receive error ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: _sendERC721,
              child: const Text('ERC721 transfer'),
            ),
            const SizedBox(
              height: 40,
            ),
            InkWell(
              onTap: _sendTransaction,
              child: const Text('Send token'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _testCreateEthereumWallet,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
