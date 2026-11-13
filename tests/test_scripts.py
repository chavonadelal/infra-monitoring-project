"""Behavior checks with real curl requests and independent log fixtures."""
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
BASH = os.environ.get("BASH_EXECUTABLE", "bash")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response({"/ok": 200, "/missing": 404, "/redirect": 302}.get(self.path, 500))
        self.end_headers()

    def log_message(self, *args):
        pass


class ScriptsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def run_script(self, name, *args, cwd=None):
        return subprocess.run([BASH, (ROOT / name).as_posix(), *args],
                              cwd=cwd, capture_output=True, encoding="utf-8", timeout=25)

    def test_http_codes(self):
        for path, expected in [("/ok", 0), ("/missing", 1), ("/redirect", 1)]:
            with self.subTest(path=path):
                result = self.run_script("check_api.sh", self.url + path)
                self.assertEqual(result.returncode, expected, result.stderr)
                if path == "/missing":
                    self.assertIn("404", result.stdout)

    def test_bad_arguments(self):
        for args in [(), ("not-a-url",), ("file:///etc/passwd",), (self.url, self.url)]:
            with self.subTest(args=args):
                self.assertEqual(self.run_script("check_api.sh", *args).returncode, 1)

    def test_network_error(self):
        # A server-side closed listening socket cannot return an HTTP response.
        import socket
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            url = f"http://127.0.0.1:{sock.getsockname()[1]}"
            result = self.run_script("check_api.sh", url)
        self.assertEqual(result.returncode, 1)
        self.assertIn("000", result.stdout)

    def test_generated_logs(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_script("analyze_logs.sh", cwd=directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len((Path(directory) / "access.log").read_text().splitlines()), 360)
            for expected in ["Общее количество запросов: 360", "120 192.168.1.10",
                             "90 10.0.0.5", "60 172.16.0.3", "4xx: 72", "5xx: 72"]:
                self.assertIn(expected, result.stdout)

    def test_custom_logs_and_invalid_ip(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "custom.log"
            fixture.write_text('1.2.3.4 - - [15/Aug/2026:10:00:00] "GET / HTTP/1.1" 404\n'
                               '1.2.3.4 - - [15/Aug/2026:10:00:01] "POST / HTTP/1.1" 503\n'
                               '999.1.1.1 - - [15/Aug/2026:10:00:02] "GET / HTTP/1.1" 200\n',
                               encoding="utf-8")
            result = self.run_script("analyze_logs.sh", fixture.as_posix())
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Общее количество запросов: 2", result.stdout)
            self.assertIn("2 1.2.3.4", result.stdout)
            self.assertIn("4xx: 1", result.stdout)
            self.assertIn("5xx: 1", result.stdout)
            self.assertNotIn("999.1.1.1", result.stdout)
            fixture.write_text("", encoding="utf-8")
            empty = self.run_script("analyze_logs.sh", fixture.as_posix())
            self.assertEqual(empty.returncode, 0, empty.stderr)
            self.assertIn("Общее количество запросов: 0", empty.stdout)


if __name__ == "__main__":
    unittest.main()
