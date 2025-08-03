import 'package:flutter/material.dart';
import 'package:lanis/core/database/account_database/account_db.dart';
import 'package:lanis/view/login/auth.dart';

import '../../core/sph/sph.dart';
import '../../utils/authentication_state.dart';
import 'account_list_tile.dart';

class AccountSwitcher extends StatefulWidget {
  const AccountSwitcher({super.key});

  @override
  State<AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends State<AccountSwitcher> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Switch Account'),
      ),
      body: StreamBuilder(
        stream: accountDatabase.select(accountDatabase.accountsTable).watch(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final account = snapshot.data![index];
              return AccountListTile(
                schoolName: account.schoolName,
                userName: account.username,
                lastLogin: account.lastLogin ?? DateTime.now(),
                onTap: () async {
                  if (sph!.account.localId == account.id) {
                    Navigator.of(context).pop();
                    return;
                  }
                  await sph!.session.deAuthenticate();
                  await accountDatabase.setNextLogin(account.id);
                  if (context.mounted) authenticationState.reset(context);
                },
                dbID: account.id,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => Scaffold(
            body: LoginForm(
              showBackButton: true,
            ),
          ),
        )),
        label: Text('Add Account'),
        icon: Icon(Icons.person_add),
      ),
    );
  }
}
