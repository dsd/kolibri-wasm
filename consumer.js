const pyodideWorker = new Worker("./webworker.js");

pyodideWorker.request_id = 0;
pyodideWorker.resolvers = {};

pyodideWorker.onmessage = function(event) {
  const id = event.data['id'];
  this.resolvers[id](event.data['response']);
  delete this.resolvers[id];
}

function sendRequest(env, body) {
  const id = pyodideWorker.request_id++;
  pyodideWorker.postMessage({ 'id': id, 'env': env, 'body': body });
  return new Promise(resolve => pyodideWorker.resolvers[id] = resolve);
}

async function doRequest(method, path, body='', contentType='') {
  return sendRequest({
    'REQUEST_METHOD': method,
    'PATH_INFO': path,
    'CONTENT_TYPE': contentType,
  }, body);
}

async function start_app() {
  try {
    results = await doRequest('GET', '/');
    if (results) {
      document.open();
      document.write(results);
      document.close();
    }
  } catch (e) {
    console.log(
      `Error in pyodideWorker at ${e.filename}, Line: ${e.lineno}, ${e.message}`
    );
  }
}

start_app();
