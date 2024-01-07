import 'package:circum_rider/utils/theme/text_field.dart';
import 'package:flutter/material.dart';

import '../../../../utils/theme/theme.dart';

showEditBottomSheet(context, {String? val, required String title}) {
  return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      backgroundColor: AppColors.secondary,
      builder: (context) {
        return ButtSheet(
          title: title,
          val: val,
        );
      });
}

class ButtSheet extends StatefulWidget {
  final String? val;
  final String title;
  const ButtSheet({super.key, this.val, required this.title});
  @override
  ButtSheetState createState() => ButtSheetState();
}

class ButtSheetState extends State<ButtSheet> {
  final TextEditingController _textFieldController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _textFieldController.text = widget.val ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: MediaQuery.of(context).viewInsets,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                Row(children: [
                  AppText.text(widget.title,
                      fontWeight: FontWeight.w600, fontSize: 16)
                ]),
                const SizedBox(height: 12),
                AppTextInput.input(controller: _textFieldController),
                const SizedBox(height: 80),
                AppButton.button(
                    widget: Center(
                        child: AppText.text('Update details',
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      if (_textFieldController.text.trim() != '') {
                        Navigator.pop(context, _textFieldController.text);
                      }
                      // print(_textFieldController.text);
                    })
              ],
            )));
  }
}
