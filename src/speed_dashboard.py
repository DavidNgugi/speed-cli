#!/usr/bin/env python3
"""
Speed CLI - Web Dashboard
A simple web interface to view your internet speed monitoring data
"""

import http.server
import socketserver
import json
import csv
import glob
import os
from urllib.parse import urlparse
import statistics

PORT = 6432
LOG_DIR = os.path.expanduser("~/internet_logs")

class MonitorHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/':
            self.serve_dashboard()
        elif parsed_path.path == '/api/data':
            self.serve_data()
        elif parsed_path.path == '/api/stats':
            self.serve_stats()
        elif parsed_path.path == '/api/trigger':
            self.trigger_test()
        else:
            self.send_error(404)
    
    def serve_dashboard(self):
        html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Speed CLI Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        header {
            background: rgba(255, 255, 255, 0.95);
            padding: 30px;
            border-radius: 20px;
            margin-bottom: 20px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        h1 {
            color: #667eea;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .subtitle {
            color: #666;
            font-size: 1.1em;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: rgba(255, 255, 255, 0.95);
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
            transition: transform 0.2s;
        }
        .stat-card:hover {
            transform: translateY(-5px);
        }
        .stat-label {
            color: #888;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
        }
        .stat-value {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-unit {
            font-size: 0.5em;
            color: #888;
            font-weight: normal;
        }
        .stat-sub {
            margin-top: 10px;
            color: #666;
            font-size: 0.9em;
        }
        .chart-container {
            background: rgba(255, 255, 255, 0.95);
            padding: 30px;
            border-radius: 20px;
            margin-bottom: 20px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        .chart-title {
            font-size: 1.5em;
            color: #333;
            margin-bottom: 20px;
        }
        canvas {
            max-height: 400px;
        }
        .controls {
            background: rgba(255, 255, 255, 0.95);
            padding: 20px;
            border-radius: 15px;
            margin-bottom: 20px;
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
            display: flex;
            gap: 15px;
            align-items: center;
        }
        button {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 1em;
            transition: background 0.2s;
        }
        button:hover {
            background: #5568d3;
        }
        button:disabled {
            background: #ccc;
            cursor: not-allowed;
        }
        .status {
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: bold;
        }
        .status.ok {
            background: #d4edda;
            color: #155724;
        }
        .status.degraded {
            background: #fff3cd;
            color: #856404;
        }
        .loading {
            text-align: center;
            padding: 40px;
            color: white;
            font-size: 1.2em;
        }
        .footer {
            text-align: center;
            color: rgba(255,255,255,0.8);
            margin-top: 40px;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Speed CLI Dashboard</h1>
            <p class="subtitle">Real-time monitoring of your internet connection quality</p>
        </header>

        <div class="controls">
            <button onclick="runTest()" id="testBtn">Run Test Now</button>
            <button onclick="loadData()">Refresh Data</button>
            <span id="lastUpdate"></span>
        </div>

        <div class="stats-grid" id="stats">
            <div class="loading">Loading data...</div>
        </div>

        <div class="chart-container">
            <h2 class="chart-title">Download Speed Over Time</h2>
            <canvas id="downloadChart"></canvas>
        </div>

        <div class="chart-container">
            <h2 class="chart-title">Upload Speed Over Time</h2>
            <canvas id="uploadChart"></canvas>
        </div>

        <div class="chart-container">
            <h2 class="chart-title">Latency Over Time</h2>
            <canvas id="latencyChart"></canvas>
        </div>

        <div class="footer">
            <p>Data updates every hour automatically. Server running on localhost:${PORT}</p>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <script>
        let downloadChart, uploadChart, latencyChart;

        async function loadData() {
            try {
                const [dataRes, statsRes] = await Promise.all([
                    fetch('/api/data'),
                    fetch('/api/stats')
                ]);
                
                const data = await dataRes.json();
                const stats = await statsRes.json();
                
                updateStats(stats);
                updateCharts(data);
                
                document.getElementById('lastUpdate').textContent = 
                    'Last updated: ' + new Date().toLocaleTimeString();
            } catch (error) {
                console.error('Error loading data:', error);
            }
        }

        function updateStats(stats) {
            const statsHtml = `
                <div class="stat-card">
                    <div class="stat-label">Average Download</div>
                    <div class="stat-value">${stats.avg_download.toFixed(1)} <span class="stat-unit">Mbps</span></div>
                    <div class="stat-sub">Min: ${stats.min_download.toFixed(1)} | Max: ${stats.max_download.toFixed(1)}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Average Upload</div>
                    <div class="stat-value">${stats.avg_upload.toFixed(1)} <span class="stat-unit">Mbps</span></div>
                    <div class="stat-sub">Min: ${stats.min_upload.toFixed(1)} | Max: ${stats.max_upload.toFixed(1)}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Average Latency</div>
                    <div class="stat-value">${stats.avg_latency.toFixed(1)} <span class="stat-unit">ms</span></div>
                    <div class="stat-sub">Min: ${stats.min_latency.toFixed(1)} | Max: ${stats.max_latency.toFixed(1)}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Connection Quality</div>
                    <div class="stat-value">${stats.degraded_pct.toFixed(1)} <span class="stat-unit">%</span></div>
                    <div class="stat-sub">${stats.degraded_count} of ${stats.total_tests} tests degraded</div>
                </div>
            `;
            document.getElementById('stats').innerHTML = statsHtml;
        }

        function updateCharts(data) {
            const labels = data.map(d => new Date(d.timestamp).toLocaleString());
            const downloads = data.map(d => d.download);
            const uploads = data.map(d => d.upload);
            const latencies = data.map(d => d.latency);

            const chartConfig = (label, data, color) => ({
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [{
                        label: label,
                        data: data,
                        borderColor: color,
                        backgroundColor: color + '20',
                        tension: 0.4,
                        fill: true
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    plugins: {
                        legend: { display: false }
                    },
                    scales: {
                        y: { beginAtZero: true }
                    }
                }
            });

            if (downloadChart) downloadChart.destroy();
            if (uploadChart) uploadChart.destroy();
            if (latencyChart) latencyChart.destroy();

            downloadChart = new Chart(
                document.getElementById('downloadChart'),
                chartConfig('Download (Mbps)', downloads, '#667eea')
            );

            uploadChart = new Chart(
                document.getElementById('uploadChart'),
                chartConfig('Upload (Mbps)', uploads, '#764ba2')
            );

            latencyChart = new Chart(
                document.getElementById('latencyChart'),
                chartConfig('Latency (ms)', latencies, '#f093fb')
            );
        }

        async function runTest() {
            const btn = document.getElementById('testBtn');
            btn.disabled = true;
            btn.textContent = 'Running test...';
            
            try {
                await fetch('/api/trigger');
                await new Promise(resolve => setTimeout(resolve, 15000)); // Wait 15s for test
                await loadData();
            } catch (error) {
                console.error('Error running test:', error);
            }
            
            btn.disabled = false;
            btn.textContent = 'Run Test Now';
        }

        // Load data on page load
        loadData();
        
        // Auto-refresh every 5 minutes
        setInterval(loadData, 300000);
    </script>
</body>
</html>
"""
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def serve_data(self):
        data = []
        pattern = os.path.join(LOG_DIR, "speed_log_*.csv")
        
        for file in sorted(glob.glob(pattern)):
            with open(file, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row['status'] not in ['FAILED', 'PARSE_ERROR']:
                        try:
                            data.append({
                                'timestamp': row['timestamp'],
                                'download': float(row['download_mbps']),
                                'upload': float(row['upload_mbps']),
                                'latency': float(row['latency_ms']),
                                'status': row['status']
                            })
                        except ValueError:
                            continue
        
        # Return last 168 entries (7 days of hourly data)
        data = data[-168:]
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def serve_stats(self):
        data = []
        pattern = os.path.join(LOG_DIR, "speed_log_*.csv")
        
        for file in sorted(glob.glob(pattern)):
            with open(file, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row['status'] not in ['FAILED', 'PARSE_ERROR']:
                        try:
                            data.append({
                                'download': float(row['download_mbps']),
                                'upload': float(row['upload_mbps']),
                                'latency': float(row['latency_ms']),
                                'status': row['status']
                            })
                        except ValueError:
                            continue
        
        if not data:
            stats = {
                'total_tests': 0,
                'avg_download': 0,
                'avg_upload': 0,
                'avg_latency': 0,
                'min_download': 0,
                'max_download': 0,
                'min_upload': 0,
                'max_upload': 0,
                'min_latency': 0,
                'max_latency': 0,
                'degraded_count': 0,
                'degraded_pct': 0
            }
        else:
            downloads = [d['download'] for d in data]
            uploads = [d['upload'] for d in data]
            latencies = [d['latency'] for d in data]
            degraded = sum(1 for d in data if d['status'] == 'DEGRADED')
            
            stats = {
                'total_tests': len(data),
                'avg_download': statistics.mean(downloads),
                'avg_upload': statistics.mean(uploads),
                'avg_latency': statistics.mean(latencies),
                'min_download': min(downloads),
                'max_download': max(downloads),
                'min_upload': min(uploads),
                'max_upload': max(uploads),
                'min_latency': min(latencies),
                'max_latency': max(latencies),
                'degraded_count': degraded,
                'degraded_pct': (degraded / len(data) * 100) if data else 0
            }
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(stats).encode())
    
    def trigger_test(self):
        os.system('launchctl start com.user.internet.monitor')
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'status': 'triggered'}).encode())

def main():
    with socketserver.TCPServer(("", PORT), MonitorHandler) as httpd:
        print(f"Speed CLI Dashboard")
        print(f"[INFO] Server running at: http://localhost:{PORT}")
        print(f"[INFO] Open your browser and visit the URL above")
        print(f"[INFO] Press Ctrl+C to stop")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[INFO] Server stopped")

if __name__ == "__main__":
    main()