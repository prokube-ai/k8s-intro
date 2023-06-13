import http.server
import socketserver
import os

filename = os.getenv('COUNTER_FILE_PATH', 'counter.txt')

class MyHttpRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):

        if self.path == '/':
            count = 0
            if os.path.exists(filename):
                with open(filename, 'r') as file:
                    count = int(file.read())
            count += 1
            with open(filename, 'w') as file:
                file.write(str(count))

            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(bytes(str(count), "utf8"))
        else:
            self.send_response(404)

PORT = 8000
Handler = MyHttpRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print("serving at port", PORT)
    httpd.serve_forever()
