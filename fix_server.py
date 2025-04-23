#!/usr/bin/env python3

# This script fixes the indentation issues in server.py

with open('server.py', 'w') as f:
    f.write('''import os
from http.server import HTTPServer, SimpleHTTPRequestHandler
import webbrowser

class AtomicMomentumApp(SimpleHTTPRequestHandler):
    def do_GET(self):
        """Serve a GET request."""
        if self.path == '/notifications-test' or self.path == '/notifications-test.html':
            # Serve the notification test page
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            with open('templates/notifications-test.html', 'rb') as file:
                self.wfile.write(file.read())
            return
            
        if self.path == '/projects' or self.path == '/projects.html':
            # Serve the projects page
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            with open('templates/projects.html', 'rb') as file:
                self.wfile.write(file.read())
            return
        
        # Handle static files
        if self.path.startswith('/styles/') or self.path.startswith('/scripts/') or self.path.startswith('/assets/'):
            file_path = self.path[1:]  # Remove leading slash
            
            if os.path.exists(file_path) and os.path.isfile(file_path):
                self.send_response(200)
                
                # Set content type based on file extension
                if file_path.endswith('.css'):
                    self.send_header('Content-type', 'text/css')
                elif file_path.endswith('.js'):
                    self.send_header('Content-type', 'application/javascript')
                elif file_path.endswith('.png'):
                    self.send_header('Content-type', 'image/png')
                elif file_path.endswith('.jpg') or file_path.endswith('.jpeg'):
                    self.send_header('Content-type', 'image/jpeg')
                else:
                    self.send_header('Content-type', 'application/octet-stream')
                
                self.end_headers()
                
                with open(file_path, 'rb') as file:
                    self.wfile.write(file.read())
                return
        
        # For all other paths, serve the main app from templates
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        
        with open('templates/index.html', 'rb') as file:
            self.wfile.write(file.read())

# Start the server
httpd = HTTPServer(('0.0.0.0', 5001), AtomicMomentumApp)
print('Server running at http://0.0.0.0:5001')
print('Project demo available at http://0.0.0.0:5001/projects')
httpd.serve_forever()
''') 