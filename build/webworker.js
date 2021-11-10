// webworker.js

// Setup your project to serve `py-worker.js`. You should also serve
// `pyodide.js`, and all its associated `.asm.js`, `.data`, `.json`,
// and `.wasm` files as well:
importScripts("https://cdn.jsdelivr.net/pyodide/v0.18.1/full/pyodide.js");

async function loadPyodideAndPackages() {
  self.pyodide = await loadPyodide({
    indexURL: "https://cdn.jsdelivr.net/pyodide/v0.18.1/full/",
  });
  await self.pyodide.loadPackage(["micropip", "setuptools"]);
  await self.pyodide.loadPackage("extra-mods/sqlalchemy.js");
  await self.pyodide.runPythonAsync(`
    import micropip
    await micropip.install('kolibri-0.15.0b1.dev0+git.15.gc3238a85-py2.py3-none-any.whl')
  `);

  const response = await fetch('kolibri-reqs/whlmanifest.txt');
  const text = await response.text();
  var lines = text.split("\n");
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].length == 0)
      continue;
    console.log("load " + lines[i]);
    url = 'kolibri-reqs/' + lines[i];
    self["url"] = url;
    await self.pyodide.runPythonAsync(`
      import micropip
      from js import url
      await micropip.install(url)
  `);

  }
}
let pyodideReadyPromise = loadPyodideAndPackages();
let initialized = false;

async function initializeKolibri() {
  await self.pyodide.runPythonAsync(`
    from kolibri.utils.main import initialize
    initialize()
  `);
  initialized = true;
}

async function handleRequest(env, body='') {
  self.pycontext = {
    'SERVER_NAME': 'fakekolibri.com',
    'SERVER_PORT': '80',
    ...env
  };
  self.pybody = body;

  const script = `
from kolibri.deployment.default.wsgi import application
from js import pycontext, pybody
import io

def request(env):
    headers = []
    body = pybody.encode('utf-8')
    env["wsgi.input"] = io.BytesIO(body)
    env["CONTENT_LENGTH"] = len(body)

    def start_response(status, response_headers, exc_info=None):
        print(status, response_headers)
        headers[:] = [status, response_headers]

    result = application(env, start_response)
    return (result, headers[0], headers[1])

env = pycontext.to_py();
ret = ""
status = None
while status is None or status.startswith("302 "):
    print("request " + env['PATH_INFO'])
    result, status, headers = request(env)
    print(status)
    if status.startswith("302 "):
        for hdr in headers:
            if hdr[0] == "Location":
                env['PATH_INFO'] = hdr[1]
                break

if status.startswith("200 ") or status.startswith("201 "):
    for data in result:
        ret += data.decode('utf-8')
else:
  print("unhandled return")

ret
`;

    await self.pyodide.loadPackagesFromImports(script);
    return self.pyodide.runPythonAsync(script);
}

self.onmessage = async (event) => {
  // make sure loading is done
  await pyodideReadyPromise;

  if (!initialized)
    await initializeKolibri();

  result = await handleRequest(event.data['env'], event.data['body']);
  self.postMessage({ 'id': event.data['id'], 'response': result });
};

