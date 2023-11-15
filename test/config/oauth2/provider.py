import json
import base64
from http.server import BaseHTTPRequestHandler, HTTPServer

token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwOi8vcHJvdmlkZXIuZXhhbXBsZS50ZXN0OjgwMDAvIiwic3ViIjoiODJjMWMzMzRkY2M2ZTMxMWFlNGFhZWJmZTk0NmM1ZTg1OGYwNTVhZmYxY2U1YTM3YWE3Y2M5MWFhYjE3ZTM1YyIsImF1ZCI6Im1haWxzZXJ2ZXIiLCJ1aWQiOiI4OU4zR0NuN1M1Y090WkZNRTVBeVhNbmxURFdVcnEzRmd4YWlyWWhFIn0.zuCytArbphhJn9XT_y9cBdGqDCNo68tBrtOwPIsuKNyF340SaOuZa0xarZofygytdDpLtYr56QlPTKImi-n1ZWrHkRZkwrQi5jQ-j_n2hEAL0vUToLbDnXYfc5q2w7z7X0aoCmiK8-fV7Kx4CVTM7riBgpElf6F3wNAIcX6R1ijUh6ISCL0XYsdogf8WUNZipXY-O4R7YHXdOENuOp3G48hWhxuUh9PsUqE5yxDwLsOVzCTqg9S5gxPQzF2eCN9J0I2XiIlLKvLQPIZ2Y_K7iYvVwjpNdgb4xhm9wuKoIVinYkF_6CwIzAawBWIDJAbix1IslkUPQMGbupTDtOgTiQ"

xoauth2 = base64.b64encode(f"user=user1@localhost.localdomain\1auth=Bearer {token}\1\1".encode("utf-8"))
print("XOAUTH2 string: " + str(xoauth2))


class HTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get("Authorization")
        if auth is None:
            self.send_response(401)
            self.end_headers()
            return
        if len(auth.split()) != 2:
            self.send_response(401)
            self.end_headers()
            return
        auth = auth.split()[1]
        if auth == token:
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({
                "email": "user1@localhost.localdomain",
                "email_verified": True,
                "sub": "82c1c334dcc6e311ae4aaebfe946c5e858f055aff1ce5a37aa7cc91aab17e35c"
            }).encode("utf-8"))
        else:
            self.send_response(401)
        self.end_headers()

server = HTTPServer(('', 80), HTTPRequestHandler)
print("Starting server", flush=True)

try:
    server.serve_forever()
except KeyboardInterrupt:
    print()
    print("Received keyboard interrupt")
finally:
    print("Exiting")
