import '../models/device_model.dart';

String buildWebPortal(DeviceModel currentDevice) {
  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CrossShare Web Portal</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background: #1e293b; padding: 24px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
    h1 { font-size: 1.5rem; margin-top: 0; color: #38bdf8; display: flex; align-items: center; gap: 10px; }
    .card { background: #334155; padding: 16px; border-radius: 12px; margin-bottom: 16px; }
    .file-item { display: flex; justify-content: space-between; align-items: center; padding: 12px; border-bottom: 1px solid #475569; }
    .file-item:last-child { border-bottom: none; }
    .btn { background: #0284c7; color: white; border: none; padding: 8px 16px; border-radius: 8px; text-decoration: none; cursor: pointer; font-weight: 600; display: inline-block; }
    .btn:hover { background: #0369a1; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🚀 CrossShare Browser Download Portal</h1>
    <p>Connected to <strong>${currentDevice.alias}</strong></p>
    
    <div class="card">
      <h3>📁 Shared Files</h3>
      <div id="fileList">Loading shared files...</div>
    </div>
  </div>

  <script>
    async function loadFiles() {
      try {
        const res = await fetch('/web/shared');
        const files = await res.json();
        const listEl = document.getElementById('fileList');
        if (files.length === 0) {
          listEl.innerHTML = '<p style="color:#94a3b8">No files currently shared by the host.</p>';
          return;
        }
        listEl.innerHTML = files.map(f => `
          <div class="file-item">
            <div>
              <strong>\${f.fileName}</strong><br/>
              <small style="color:#94a3b8">\${f.formattedSize || ''}</small>
            </div>
            <a href="/web/download/\${f.id}" class="btn" download>Download</a>
          </div>
        `).join('');
      } catch (e) {
        document.getElementById('fileList').innerHTML = 'Error loading files.';
      }
    }
    loadFiles();
  </script>
</body>
</html>
''';
}
