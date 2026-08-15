abstract class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final int? statusCode;
  const ApiFailure(this.message, {this.statusCode});
}

class NetworkError<T> extends ApiResult<T> {
  const NetworkError();
}

class TimeoutError<T> extends ApiResult<T> {
  const TimeoutError();
}
