import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import "package:pointycastle/api.dart" as api;
import 'package:veatre/common/globals.dart';
import 'package:veatre/src/utils/common.dart';
import 'package:veatre/src/models/account.dart';
import 'package:veatre/src/models/crypto.dart';
import 'package:veatre/src/storage/configStorage.dart';
import 'package:veatre/src/storage/walletStorage.dart';
import 'package:veatre/src/ui/commonComponents.dart';
import 'package:veatre/src/ui/recoveryPhrasesBackup.dart';

class WalletOperation extends StatefulWidget {
  final WalletEntity walletEntity;
  WalletOperation({this.walletEntity});

  @override
  WalletOperationState createState() => WalletOperationState();
}

class WalletOperationState extends State<WalletOperation> {
  TextEditingController passwordController = TextEditingController();
  TextEditingController walletNameController = TextEditingController();
  bool hasBackup;

  @override
  void initState() {
    hasBackup = widget.walletEntity.hasBackup;
    super.initState();
  }

  Future<void> updateBackup() async {
    final walletEntity = await WalletStorage.read(widget.walletEntity.address);
    setState(() {
      this.hasBackup = walletEntity.hasBackup;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        title: Text('Operation'),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.only(top: 20),
        children: [
          buildCell(
            "Change Wallet Name",
            onTap: () async {
              await customAlert(context,
                  title: Text('Input Wallet Name'),
                  content: Column(
                    children: <Widget>[
                      Text(
                        'Please input new wallet name to continue',
                        style: TextStyle(fontSize: 14),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: TextField(
                          autofocus: true,
                          controller: walletNameController,
                          maxLength: 10,
                          decoration: InputDecoration(
                              hintText: 'Please input wallet name'),
                        ),
                      ),
                    ],
                  ), confirmAction: () async {
                String walletName = walletNameController.text;
                if (walletName.isEmpty) {
                  return alert(context, Text('Incorrect Wallet Name'),
                      "Wallet name can't be empty");
                }
                await WalletStorage.updateName(
                    widget.walletEntity.address, walletName);
                Navigator.of(context).pop();
              });
              walletNameController.clear();
            },
          ),
          buildCell(
            "Backup Recovery Phrases",
            showWarnning: !hasBackup,
            onTap: () async {
              String password = await verifyPassword();
              if (password != null) {
                String mnemonicCipher = widget.walletEntity.mnemonicCipher;
                String iv = widget.walletEntity.iv;
                Uint8List mnemonicData = AESCipher.decrypt(
                  utf8.encode(password),
                  hexToBytes(mnemonicCipher),
                  hexToBytes(iv),
                );
                String mnemonic = utf8.decode(mnemonicData);
                String name = ModalRoute.of(context).settings.name;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RecoveryPhraseBackup(
                      hasBackup: hasBackup,
                      mnemonic: mnemonic,
                      rootRouteName: name,
                    ),
                  ),
                );
                await updateBackup();
              }
            },
          ),
          buildCell(
            "Delete",
            important: true,
            centerTitle: true,
            showArrow: false,
            onTap: () async {
              String password = await verifyPassword();
              if (password != null) {
                await customAlert(context,
                    title: Text('Delete Wallet'),
                    content: Text(
                      'Are you sure to delete this wallet',
                    ), confirmAction: () async {
                  await WalletStorage.delete(widget.walletEntity.address);
                  Navigator.of(context)
                      .popUntil(ModalRoute.withName('/wallets'));
                });
              }
            },
          )
        ],
      ),
    );
  }

  Widget buildCell(
    String title, {
    bool showArrow = true,
    bool centerTitle = false,
    bool showWarnning = false,
    bool important = false,
    Future Function() onTap,
  }) {
    return Container(
      child: GestureDetector(
        onTap: () async {
          if (onTap != null) {
            await onTap();
          }
        },
        child: Card(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Text(
                    title,
                    textAlign: centerTitle ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: important ? Colors.red : Colors.grey[500],
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              showArrow
                  ? Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Row(
                        children: <Widget>[
                          showWarnning
                              ? Padding(
                                  padding: EdgeInsets.only(right: 10),
                                  child: Icon(
                                    Icons.error,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                )
                              : SizedBox(),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 20,
                            color: Colors.grey,
                          )
                        ],
                      ),
                    )
                  : SizedBox(),
            ],
          ),
        ),
      ),
      height: 60,
    );
  }

  Future<String> verifyPassword() async {
    String password = await customAlert(context,
        title: Text('Input Master Code'),
        content: Column(
          children: <Widget>[
            Text(
              'Please input the master code to continue',
              style: TextStyle(fontSize: 14),
            ),
            Padding(
              padding: EdgeInsets.only(top: 15),
              child: TextField(
                autofocus: true,
                controller: passwordController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Master code'),
                maxLength: 6,
              ),
            ),
          ],
        ), confirmAction: () async {
      String password = passwordController.text;
      String passwordHash = await Config.passwordHash;
      String hash =
          bytesToHex(new api.Digest("SHA-512").process(utf8.encode(password)));
      if (hash != passwordHash) {
        Navigator.of(context).pop();
        return alert(context, Text('Incorrect Master Code'),
            'Please input correct master code');
      } else {
        Globals.updateMasterPasscodes(password);
        Navigator.of(context).pop(password);
      }
    });
    passwordController.clear();
    return password;
  }
}
