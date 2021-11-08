import { asyncRun } from "./py-worker.js";

const script = `
    from mymodule import webtest
    webtest.get_html()
`;

async function main() {
  try {
    const { results, error } = await asyncRun(script);
    if (results) {
      console.log("pyodideWorker return results: ", results);
      document.getElementById("content").innerHTML = results;
    } else if (error) {
      console.log("pyodideWorker error: ", error);
    }
  } catch (e) {
    console.log(
      `Error in pyodideWorker at ${e.filename}, Line: ${e.lineno}, ${e.message}`
    );
  }
}

main();
