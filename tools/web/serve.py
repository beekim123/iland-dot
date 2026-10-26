#!/usr/bin/env python3
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os, webbrowser
os.chdir(Path(__file__).resolve().parent)
class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, '.wasm': 'application/wasm', '.pck': 'application/octet-stream'}
server = ThreadingHTTPServer(('127.0.0.1', 8071), Handler)
print('打开 http://127.0.0.1:8071/ — Ctrl+C 停止', flush=True)
webbrowser.open('http://127.0.0.1:8071/')
server.serve_forever()
