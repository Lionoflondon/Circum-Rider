part of '../home.dart';

class ConnectingToUser extends StatefulWidget {
  const ConnectingToUser({super.key});

  @override
  ConnectingToUserState createState() => ConnectingToUserState();
}

class ConnectingToUserState extends State<ConnectingToUser> {
  double progressValue = 0;

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (progressValue < 1) {
        setState(() {
          progressValue = progressValue + 0.005;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      // height: MediaQuery.of(context).size.height * 0.3,
      child: LinearProgressIndicator(
        value: progressValue >= 1 ? null : progressValue,
        minHeight: 4,
        backgroundColor: Color(0xFF1F292E),
        color: AppColors.primary,
      ),
    );
  }
}
