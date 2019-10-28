import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:veatre/common/globals.dart';
import 'package:veatre/src/api/accountAPI.dart';
import 'package:veatre/src/models/certificate.dart';
import 'package:veatre/src/models/account.dart';
import 'package:veatre/src/storage/walletStorage.dart';
import 'package:veatre/src/storage/activitiyStorage.dart';
import 'package:veatre/src/ui/wallets.dart';
import 'package:veatre/src/ui/commonComponents.dart';

class SignCertificateDialog extends StatefulWidget {
  final SigningCertMessage certMessage;
  final SigningCertOptions options;

  SignCertificateDialog({
    this.certMessage,
    this.options,
  });

  @override
  SignCertificateDialogState createState() => SignCertificateDialogState();
}

class SignCertificateDialogState extends State<SignCertificateDialog> {
  bool loading = true;
  Wallet wallet;
  WalletEntity walletEntity;
  TextEditingController passwordController = TextEditingController();
  Account account;

  @override
  void initState() {
    super.initState();
    getWalletEntity(widget.options.signer).then((walletEntity) {
      this.walletEntity = walletEntity;
      updateWallet(walletEntity).whenComplete(() {
        setState(() {
          this.loading = false;
        });
        Globals.addBlockHeadHandler(_handleHeadChanged);
      });
    });
  }

  void _handleHeadChanged() async {
    if (Globals.blockHeadForNetwork.network == Globals.network) {
      await updateWallet(walletEntity);
    }
  }

  @override
  void dispose() {
    Globals.removeBlockHeadHandler(_handleHeadChanged);
    super.dispose();
  }

  Future<void> updateWallet(WalletEntity walletEntity) async {
    try {
      Account account = await AccountAPI.get(walletEntity.address);
      if (mounted) {
        setState(() {
          this.wallet = Wallet(account: account, entity: walletEntity);
        });
      }
    } catch (e) {
      print('updateWallet error: $e ');
    }
  }

  Future<WalletEntity> getWalletEntity(String signer) async {
    if (signer != null) {
      List<WalletEntity> walletEntities = await WalletStorage.readAll();
      for (WalletEntity walletEntity in walletEntities) {
        if ('0x' + walletEntity.address == signer) {
          return walletEntity;
        }
      }
    }
    WalletEntity mianWalletEntity = await WalletStorage.getMainWallet();
    if (mianWalletEntity != null) {
      return mianWalletEntity;
    }
    List<WalletEntity> walletEntities = await WalletStorage.readAll();
    return walletEntities[0];
  }

  Future<void> showWallets() async {
    final WalletEntity walletEntity = await Navigator.push(
      context,
      new MaterialPageRoute(
        builder: (context) => new Wallets(),
      ),
    );
    if (walletEntity != null) {
      this.walletEntity = walletEntity;
      await updateWallet(walletEntity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Sign Certificate'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            size: 25,
          ),
          onPressed: () async {
            Navigator.of(context).pop();
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              size: 25,
            ),
            onPressed: () async {
              await showWallets();
            },
          )
        ],
      ),
      body: ProgressHUD(
        child: Column(
          children: <Widget>[
            GestureDetector(
              child: Container(
                child: Card(
                  margin: EdgeInsets.all(10),
                  child: Column(
                    children: <Widget>[
                      Container(
                        height: 100,
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF81269D),
                              const Color(0xFFEE112D)
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            Container(
                              width: MediaQuery.of(context).size.width,
                              child: Container(
                                padding: EdgeInsets.all(15),
                                child: Text(
                                  walletEntity?.name ?? '--',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.only(left: 15, right: 15),
                              width: MediaQuery.of(context).size.width,
                              child: Text(
                                '0x' + (walletEntity?.address ?? ''),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Text(wallet?.account?.formatBalance ?? '--'),
                            Container(
                              margin: EdgeInsets.only(left: 5, right: 14),
                              child: Text(
                                'VET',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Text(wallet?.account?.formatEnergy ?? '--'),
                            Container(
                              margin: EdgeInsets.only(left: 5, right: 5),
                              child: Text(
                                'VTHO',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                width: MediaQuery.of(context).size.width,
                height: 195,
              ),
              onTap: () async {
                await showWallets();
              },
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Card(
                          child: Container(
                            margin: EdgeInsets.all(10),
                            child: Text(
                              widget.certMessage.payload.content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 50,
                          child: FlatButton(
                            color: Colors.blue,
                            child: Text(
                              'Confirm',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: () async {
                              Uint8List privateKey = await walletEntity
                                  .decryptPrivateKey(Globals.masterPasscodes);
                              try {
                                final head = Globals.head();
                                int timestamp = head.timestamp;
                                Certificate cert = Certificate(
                                  certMessage: widget.certMessage,
                                  timestamp: timestamp,
                                  domain: widget.options.link,
                                );
                                cert.sign(privateKey);
                                await WalletStorage.setMainWallet(walletEntity);
                                await ActivityStorage.insert(
                                  Activity(
                                    block: head.number,
                                    content: json.encode(cert.unserialized),
                                    link: cert.domain,
                                    address: walletEntity.address,
                                    type: ActivityType.Certificate,
                                    comment: 'Certification',
                                    timestamp: timestamp,
                                    network: Globals.network,
                                    status: ActivityStatus.Finished,
                                  ),
                                );
                                Navigator.of(context).pop(cert.response);
                              } catch (err) {
                                setState(() {
                                  loading = false;
                                });
                                return alert(context, Text("Error"), "$err");
                              } finally {
                                setState(() {
                                  loading = false;
                                });
                              }
                            },
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
            )
          ],
        ),
        isLoading: loading,
      ),
    );
  }
}
