import 'package:bot_toast/bot_toast.dart';
import 'package:circum_rider/app/account/bloc/account_bloc.dart';
import 'package:circum_rider/utils/theme/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../../helper/amount_formatter.dart';
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
  final TextEditingController _sortCodeTextFieldController =
      TextEditingController();
  final TextEditingController _amountTextFieldController =
      TextEditingController();
  final TextEditingController _bankNameTextFieldController =
      TextEditingController();
  final TextEditingController _accountNumberTextFieldController =
      TextEditingController();

  final TextEditingController _addressTextFieldController =
      TextEditingController();

  final GlobalKey _key = GlobalKey();

  bool saveAccountDetails = true;

  bool balanceValid = true;

  var maskFormatter = MaskTextInputFormatter(
      mask: '##,###.##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy);

  @override
  void initState() {
    super.initState();
    _amountTextFieldController.text = '';
    _bankNameTextFieldController.text = '';
    _accountNumberTextFieldController.text = '';
    _sortCodeTextFieldController.text = '';
    _addressTextFieldController.text = '';

    context.read<AccountBloc>().add(GetRequests());
  }

  @override
  void dispose() {
    super.dispose();
    _amountTextFieldController.dispose();
    _bankNameTextFieldController.dispose();
    _accountNumberTextFieldController.dispose();
    _sortCodeTextFieldController.dispose();
    _addressTextFieldController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.secondary,
        key: _key,
        body: BlocBuilder<AccountBloc, AccountState>(builder: (context, state) {
          if (state.status == AccountStatus.success) {
            context
                .read<AccountBloc>()
                .add(ResetAccountStatus(status: AccountStatus.initialized));
            Navigator.pop(context, 'req-sent');
          }

          if (state.isWithdrawRequestActive == true &&
              state.withdrawRequest != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: MediaQuery.of(context).size.width),
                AppText.text(
                    'Pending request\n£${state.withdrawRequest!.amount}',
                    textAlign: TextAlign.center,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                const SizedBox(
                  height: 8,
                ),
                AppButton.button(
                    widget: AppText.text('Cancel request'),
                    onPressed: () {
                      context
                          .read<AccountBloc>()
                          .add(CancelWithdrawalRequest());
                    })
              ],
            );
          }
          return Column(
            children: [
              if (state.status == AccountStatus.loading)
                const LinearProgressIndicator(color: AppColors.primary),
              Expanded(
                  child: SingleChildScrollView(
                      padding: MediaQuery.of(context).viewInsets,
                      child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20)
                              .copyWith(top: 0),
                          constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height),
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
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                  )
                                ],
                              ),
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 20),
                                  child: Row(children: [
                                    AppText.text('Withdraw Earnings',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16)
                                  ])),
                              const SizedBox(height: 24),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppText.text('Amount'),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppTextInput.input(
                                    borderColor: balanceValid == false
                                        ? Colors.red
                                        : null,
                                    activeBorderColor: balanceValid == false
                                        ? Colors.red
                                        : null,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    // inputFormatters: [maskFormatter],
                                    onChanged: (val) {
                                      if (val != "") {
                                        double amount = double.parse(val);
                                        if (amount >
                                            state.earnings!.accountBalance) {
                                          setState(
                                            () {
                                              balanceValid = false;
                                            },
                                          );
                                        } else {
                                          setState(
                                            () {
                                              balanceValid = true;
                                            },
                                          );
                                        }
                                      }
                                    },
                                    controller: _amountTextFieldController),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppText.text(
                                    state.earnings != null
                                        ? 'Balance: £${state.earnings?.accountBalance}'
                                        : '',
                                    fontSize: 12,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppText.text('Sort Code'),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppTextInput.input(
                                    keyboardType: TextInputType.number,
                                    controller: _sortCodeTextFieldController),
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppText.text('Bank Name'),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppTextInput.input(
                                    controller: _bankNameTextFieldController),
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppText.text('Account Number'),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppTextInput.input(
                                    keyboardType: TextInputType.number,
                                    controller:
                                        _accountNumberTextFieldController),
                              ),
                              const SizedBox(height: 20),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppText.text('Address'),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: AppTextInput.input(
                                    keyboardType: TextInputType.number,
                                    controller: _addressTextFieldController),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  const SizedBox(width: 10),
                                  Checkbox(
                                    value: saveAccountDetails,
                                    onChanged: (val) {
                                      setState(() {
                                        saveAccountDetails =
                                            !saveAccountDetails;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                    // fillColor: ,
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        saveAccountDetails =
                                            !saveAccountDetails;
                                      });
                                    },
                                    child: AppText.text(
                                        'Save this bank as an option'),
                                  )
                                ],
                              ),
                            ],
                          )))),
              const SizedBox(height: 10),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AppButton.button(
                      widget: Center(
                          child: AppText.text('Proceed',
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        if (_sortCodeTextFieldController.text.trim() != '' &&
                            _amountTextFieldController.text.trim() != '' &&
                            _bankNameTextFieldController.text.trim() != '' &&
                            _accountNumberTextFieldController.text.trim() !=
                                '' &&
                            _addressTextFieldController.text.trim() != '' &&
                            balanceValid == true) {
                          context.read<AccountBloc>().add(RequestWithdrawal(
                              sortCode: _sortCodeTextFieldController.text,
                              amount: _amountTextFieldController.text,
                              bankName: _bankNameTextFieldController.text,
                              accountNumber:
                                  _accountNumberTextFieldController.text,
                              address: _addressTextFieldController.text,
                              saveAccountDetails: saveAccountDetails));
                        }
                        // print(_textFieldController.text);
                      }))
            ],
          );
        }));
  }
}
