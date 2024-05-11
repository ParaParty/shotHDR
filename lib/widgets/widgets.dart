import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

Widget makeDefaultPage(BuildContext context,
    {Widget? titleRow,
    List<Widget>? actions,
    Widget? content,
    bool automaticallyImplyLeading = true,
    String title = "",
    bool useBodyContainer = false}) {
  return NavigationView(
    appBar: NavigationAppBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: DragToMoveArea(
          child: titleRow ??
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(title),
                      ],
                    ),
                  )
                ],
              ),
        ),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [...?actions, const WindowButtons()],
        )),
    content: useBodyContainer
        ? Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: content,
          )
        : content,
  );
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);
    return SizedBox(
      width: 138,
      height: 50,
      child: WindowCaption(
        brightness: theme.brightness,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}