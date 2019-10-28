import 'dart:convert';
import 'dart:typed_data';

import 'package:veatre/common/net.dart';
import 'package:veatre/common/globals.dart';
import 'package:veatre/src/utils/common.dart';
import 'package:veatre/src/models/account.dart';
import 'package:veatre/src/models/crypto.dart';
import 'package:veatre/src/storage/database.dart';

enum Appearance {
  light,
  dark,
}

enum Network {
  MainNet,
  TestNet,
}

class Config {
  static final testnet = "https://sync-testnet.vechain.org";
  static final mainnet = "https://sync-mainnet.vechain.org";

  static Future<void> setAppearance(Appearance appearance) async {
    final db = await Storage.instance;
    await db.update(
        configTableName, {'theme': appearance == Appearance.light ? 0 : 1});
  }

  static Future<Appearance> get appearance async {
    final db = await Storage.instance;
    final rows = await db.query(
      configTableName,
    );
    return rows.first['theme'] == 0 ? Appearance.light : Appearance.dark;
  }

  static Future<void> setNetwork(Network network) async {
    final db = await Storage.instance;
    await db.update(
        configTableName, {'network': network == Network.MainNet ? 0 : 1});
  }

  static Net net({Network network}) {
    if ((network ?? Globals.network) == Network.MainNet) {
      return Net(Config.mainnet);
    }
    return Net(Config.testnet);
  }

  static Future<Network> get network async {
    final db = await Storage.instance;
    final rows = await db.query(
      configTableName,
      limit: 1,
    );
    Network network =
        rows.first['network'] == 0 ? Network.MainNet : Network.TestNet;
    return network;
  }

  static Future<String> get passwordHash async {
    final db = await Storage.instance;
    final rows = await db.query(
      configTableName,
      limit: 1,
    );
    return rows.first['passwordHash'];
  }

  static Future<void> setPasswordHash(String passwordHash) async {
    final db = await Storage.instance;
    await db.update(configTableName, {'passwordHash': passwordHash});
  }

  static Future<void> changePassword(
    String originPasscodes,
    String newPasscodes,
    String newPasscodeHash,
  ) async {
    final db = await Storage.instance;
    List<Map<String, dynamic>> rows = await db.query(walletTableName);
    final batch = db.batch();
    for (Map<String, dynamic> row in rows) {
      WalletEntity walletEntity = WalletEntity.fromJSON(row);
      Uint8List mnemonicData = AESCipher.decrypt(
        utf8.encode(originPasscodes),
        hexToBytes(walletEntity.mnemonicCipher),
        hexToBytes(row['iv']),
      );
      final newIV = randomBytes(16);
      final newMnemonicCipher = AESCipher.encrypt(
        utf8.encode(newPasscodes),
        mnemonicData,
        newIV,
      );
      walletEntity.iv = bytesToHex(newIV);
      walletEntity.mnemonicCipher = bytesToHex(newMnemonicCipher);
      batch.update(
        walletTableName,
        walletEntity.encoded,
        where: 'address = ? and network = ?',
        whereArgs: [
          walletEntity.address,
          walletEntity.network == Network.MainNet ? 0 : 1,
        ],
      );
    }
    batch.update(configTableName, {'passwordHash': newPasscodeHash});
    await batch.commit(noResult: true);
  }
}
