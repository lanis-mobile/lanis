import 'package:lanis/core/applet_parser.dart';

mixin DemoFetchMixin<T> on AppletParser<T> {
  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    if (isEmpty || forceRefresh) {
      addResponse(FetcherResponse(status: FetcherStatus.fetching, error: null));
      try {
        final data = await getHome();
        addResponse(
          FetcherResponse<T>(status: FetcherStatus.done, content: data, error: null),
        );
        isEmpty = false;
      } catch (ex, stack) {
        addResponse(
          FetcherResponse<T>(
            status: FetcherStatus.error,
            error: ExceptionWithStackTrace(
              exception: ex is Exception ? ex : Exception(ex.toString()),
              stackTrace: stack,
            ),
          ),
        );
      }
    }
  }
}
