import 'package:circum_rider/app/account/bloc/account_bloc.dart';
import 'package:circum_rider/utils/theme/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../utils/theme/theme.dart';

showWithdrawalBottomSheet(context) {
  return showModalBottomSheet(
      shape: RoundedRectangleBorder(),
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      backgroundColor: AppColors.secondary,
      builder: (context) {
        return ButtSheet();
      });
}

class ButtSheet extends StatefulWidget {
  const ButtSheet({super.key});
  @override
  ButtSheetState createState() => ButtSheetState();
}

class ButtSheetState extends State<ButtSheet> {
  final TextEditingController _textFieldController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _textFieldController.text = '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(builder: (context, state) {
      return SingleChildScrollView(
          padding: MediaQuery.of(context).viewInsets,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              constraints:
                  BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      )
                    ],
                  ),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      child: Row(children: [
                        AppText.text('Withdraw Earnings',
                            fontWeight: FontWeight.w600, fontSize: 16)
                      ])),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppText.text('Amount'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppTextInput.input(
                        keyboardType: TextInputType.number,
                        controller: _textFieldController),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppText.text(
                        'Balance: £${state.earnings!.accountBalance}',
                        fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppText.text('Choose Bank'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppTextInput.input(controller: _textFieldController),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppText.text('Account Number'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppTextInput.input(controller: _textFieldController),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Checkbox(
                        value: true,
                        onChanged: (val) {},
                        activeColor: AppColors.primary,
                        // fillColor: ,
                      ),
                      GestureDetector(
                        child: AppText.text('Save this bank as an option'),
                      )
                    ],
                  ),
                  const SizedBox(height: 60),
                  AppButton.button(
                      widget: Center(
                          child: AppText.text('Proceed',
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        if (_textFieldController.text.trim() != '') {
                          Navigator.pop(context, _textFieldController.text);
                        }
                        // print(_textFieldController.text);
                      })
                ],
              )));
    });
  }
}
