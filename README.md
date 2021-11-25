Kolibri in your web browser
===========================

# Introduction

Kolibri is normally accessed using a web browser (or embedded web browser), however it relies on a Kolibri server backend which is written in Python. This architecture brings some complexity to deploying Kolibri - a suitable Python interpreter must be available for your OS, you have to run it, it has to open a socket, etc. Notably, this complicates the prospect of Kolibri as a ChromeOS app.

This experiment runs the Kolibri server entirely within your browser. It does this by creating a javascript thread where a Python interpreter is run (pyodide, using WebAssembly).

It takes a few minutes to load - one of the first learnings from this experiment. Watch the javascript console to see things moving.

# Build instructions

Tested using a Debian Bullseye container, run:

    # make

The output goes in build/, so you can serve it with:

    # cd build
    # python3 -m http.server

# Implementation considerations

## Handling client-server communication

The Kolibri client and server usually communicate over a HTTP socket. However, one of the unique challenges of this project is that we cannot open sockets in this environment. The Web world is limited to outgoing connections only, even in the latest ["raw" sockets proposal](https://github.com/WICG/raw-sockets).

However, since we run both the client and the server within the web browser, we don't need a socket. We can call the server's Python code directly - apart from the consideration that we run the server in a separate worker thread, so we must replace HTTP communications with an IPC system across that thread boundary.

So, what communication protocol should we invent? We do have some awareness of an IDL used internally in Kolibri for some communication, that gets funneled over HTTP somehow, and I was considering looking there.

However, I explored another angle in this initial approach. I was looking at how the Kolibri test suite calls into server code without using HTTP, and noted that it called the [WSGI](https://www.python.org/dev/peps/pep-0333/) interface directly. This is a generic interface designed to allow webservers to call into Python webapps, and I take this approach here.

For example I pass a WSGI-like request (effectively an encoding of a HTTP request) over the thread boundary and pass the response back. The response to the initial "GET /" request is rendered in the browser and everything else goes from there.

There's also some AJAX happening on these pages; internally this seems to go through Kolibri's baseClient.js which ordinarily uses [Axios](https://axios-http.com/). In this experiment, I replace the calls to Axios with the WSGI-like request/response interface to the Python thread.

Sometimes Kolibri makes the browser follow a redirect to another page (e.g. the `redirectuser`/`redirect_user` bits) and we also need to intercept that and translate it into a browser-updating request in the current session. That has not been done yet, that's why you can only go as far as the end of the setup wizard.


## File storage

Clearly file storage is a key aspect of this app (i.e. downloading channel content and storing them for later access). You generally can't write to disk from a web environment so we will need to figure out how to handle this. I have not explored this aspect in detail beyond some research below.

One possibility could be the [File System Access API](https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API). This would require that the user uses a file picker to select Kolibri's storage directory, and then picks the same directory again next time they run the app; not an ideal UI. Alternatively the origin private file system could be used, but it seems like the constraints around that space are still being mapped out. And this would only give us filesystem access from Javascript, it would be inconvenient/challenging to expose this interface to the Python server, if that is needed.

Another possibility is to use the browser cache. All the Kolibri channel assets would need to have a stable URL online, and we'd use the CacheStorage interface to preemptively download the entire channel contents into the browser cache when the user requests channel installation. Then we'd use a PWA Service Worker thread to later intercept outgoing HTTP requests when channels are viewed, and serve them from the cache. There would be some interesting challenges there - we'd be downloading tens of gigabytes of educational content into the browser cache, which may be purged behind our back. And access to this data from the Python side, if needed, would be a challenge.

BrowserFS would also be worth investigation, see some [existing ideas](https://github.com/pyodide/pyodide/issues/613) around using that to have a persistent fs within pyodide.

As ChromeOS is moving towards having all apps as PWAs, there may be more we can learn from that ecosystem as presumably we are not the only ones facing this type of challenge.

## Database

Kolibri uses a SQLite database, accessed via [SQLAlchemy](https://www.sqlalchemy.org/). Presumably this stores information that needs to persist between sessions, such as which channels have been downloaded. This presents similar challenges to the file storage question above, but may even be more complex; would the Javascript file access APIs support any advanced features needed by SQLite such as seeking?

In the web world, [IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API) would be the obvious replacement for a PWA-compatible client side database. But bridging SQLAlchemy in Python to IndexedDB on the Javascript side sounds like another significant challenge.

## CORS

You can't open the resultant build from the local filesystem, because CORS means it doesn't trust the origin to start the worker thread.

That's why a webserver is required.

How does this work on ChromeOS PWA apps? Is the CORS policy relaxed? Does it serve them from a local webserver?

# Conclusions & next steps

I made some interesting progress around setting up the environment for prototyping and experimentation, evaluating the initial integration challenges, performance, etc. It was nice to see the power of these technologies and have the Kolibri UI wizard appear on-screen.

Ultimately though, I did not have enough time to get into the deep questions around file storage and database access. These issues challenge the feasibility of the overall solution. Pyodide is super impressive in making Python work seamlessly in the web browser, but that project has experienced high difficulty & slow movement when having to navigate the gap with the underlying Web/JS "operating system", e.g. threading support is not really present, can't use urllib because it hasn't been linked up to the JS equivalents, and for this project we have the similar challenges of file and database access, which may include some limitations/impracticalities.

For this path to form in a neat way, it seems like the options are:
 1. Pyodide has to gain truly exceptional integration with the web environment in the required areas, or
 2. Kolibri's architecture needs to be modified to have a Javascript server implementation instead of Python, or 
 3. Kolibri's architecture needs to be modified to be much more client-side, or
 4. We do some creative thinking and explore any less obvious approaches to these underlying challenges.

