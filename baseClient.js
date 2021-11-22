/*
 * Internal module that is used by the default client, http client, and
 * the session fetching apparatus. Made as a separate module to avoid
 * circular dependencies and repeated code.
 */

export default function clientFactory() {
  return {
    request(options) {
      console.log('baseClient request! ' + options.url);
      var data = options.data;
      if (typeof data !== 'string')
        data = JSON.stringify(data);

      return doRequest(options.method, options.url, data, 'application/json').then(
        result => {
          return {
            data: JSON.parse(result),
            status: 200,
          };
        });
    },
    interceptors: {
      request: {
        use() {
          console.log('rq interceptor');
        },
      },
      response: {
        use() {
          console.log('resp interceptor');
        },
      },
    },
  };
}
