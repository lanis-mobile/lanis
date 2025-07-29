import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

class FetchMoreIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onAction;
  final IndicatorController? controller;

  const FetchMoreIndicator({
    super.key,
    required this.child,
    required this.onAction,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    const height = 100.0;
    return CustomRefreshIndicator(
      onRefresh: onAction,
      controller: controller,
      trigger: IndicatorTrigger.leadingEdge,
      trailingScrollIndicatorVisible: true,
      leadingScrollIndicatorVisible: false,
      durations: const RefreshIndicatorDurations(
        completeDuration: Duration(milliseconds: 200),
      ),
      child: child,
      builder: (
        BuildContext context,
        Widget child,
        IndicatorController controller,
      ) {
        return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final dy = controller.value.clamp(0.0, 1.25) *
                  -(height - (height * 0.25));
              return Stack(
                children: [
                  child,
                  PositionedIndicatorContainer(
                    controller: controller,
                    displacement: 0,
                    child: Container(
                        padding: const EdgeInsets.all(8.0),
                        transform: Matrix4.translationValues(0.0, dy, 0.0),
                        child: switch (controller.state) {
                          IndicatorState.idle => null,
                          IndicatorState.dragging ||
                          IndicatorState.canceling ||
                          IndicatorState.armed ||
                          IndicatorState.settling =>
                            const Icon(Icons.refresh),
                          IndicatorState.loading => Container(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              width: 16,
                              height: 16,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          IndicatorState.complete ||
                          IndicatorState.finalizing =>
                            const Icon(Icons.check_circle, color: Colors.green),
                        }),
                  ),
                ],
              );
            });
      },
    );
  }
}
