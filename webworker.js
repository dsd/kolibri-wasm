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

self.onmessage = async (event) => {
  // make sure loading is done
  await pyodideReadyPromise;
  // Don't bother yet with this line, suppose our API is built in such a way:
  const { python, ...context } = event.data;
  // The worker copies the context in its own "memory" (an object mapping name to values)
  for (const key of Object.keys(context)) {
    self[key] = context[key];
  }
  // Now is the easy part, the one that is similar to working in the main thread:
  try {
    await self.pyodide.loadPackagesFromImports(python);
    let results = await self.pyodide.runPythonAsync(python);
    self.postMessage({ results });
  } catch (error) {
    self.postMessage({ error: error.message });
  }
};

