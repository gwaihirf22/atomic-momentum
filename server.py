import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

class HabitTrackerHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        # Serve index.html from templates as the main page
        if self.path == '/' or self.path == '/index.html':
            self.path = '/templates/index.html'
        
        # Handle static file requests
        if self.path.startswith('/styles/') or self.path.startswith('/scripts/'):
            # Keep the path as is to serve from the correct directories
            pass
        elif self.path == '/notifications-test':
            self.path = '/templates/notifications-test.html'
            
        return SimpleHTTPRequestHandler.do_GET(self)

if __name__ == '__main__':
    # Set the working directory to the script's directory
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    # Create server
    server_address = ('', 8000)
    httpd = HTTPServer(server_address, HabitTrackerHandler)
    
    print("Server running at http://localhost:8000/")
    print("To access from your phone, use your computer's local IP address")
    print("For example: http://192.168.1.xxx:8000")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()
