import { asyncRun } from "./py-worker.js";

const script = `
import io
from kolibri.utils.main import initialize
from django.core.management import execute_from_command_line

initialize()
execute_from_command_line(["kolibri manage", "migrate"])

from kolibri.deployment.default.wsgi import application

def request(path):
    headers = []
    env = {
        "wsgi.input": io.StringIO(),
        "REQUEST_METHOD": "GET",
        "SERVER_NAME": "fakekolibri.com",
        "SERVER_PORT": "80",
        "PATH_INFO": path,
    }

    def start_response(status, response_headers, exc_info=None):
        print(status, response_headers)
        headers[:] = [status, response_headers]

    result = application(env, start_response)
    return (result, headers[0], headers[1])

path = "/"
ret = "foo"
while True:
    print("request " + path)
    result, status, headers = request(path)
    if status.startswith("302 "):
        for hdr in headers:
            if hdr[0] == "Location":
                path = hdr[1]
                break
    elif status.startswith("500 "):
        print("ERROR 500")
        break
    elif status.startswith("200 "):
        print("200!")
        for data in result:
            ret = data.decode('utf-8')
        break

ret
`;

async function main() {
  try {
    const { results, error } = await asyncRun(script);
    if (results) {
      document.open();
      document.write(results);
      document.close();
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
