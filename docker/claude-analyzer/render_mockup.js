#!/usr/bin/env node
const puppeteer = require('puppeteer');

async function renderMockup(outputPath) {
    // Read HTML from stdin
    let html = '';
    for await (const chunk of process.stdin) {
        html += chunk;
    }

    if (!html.trim()) {
        console.error('Error: No HTML content provided');
        process.exit(1);
    }

    // Wrap HTML in a styled container if it's not a complete document
    if (!html.includes('<!DOCTYPE') && !html.includes('<html')) {
        html = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: #f8fafc;
            padding: 24px;
        }
        /* Default mockup container styles */
        .mockup-container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            padding: 24px;
            max-width: 600px;
        }
        /* Common UI element styles */
        .btn {
            display: inline-block;
            padding: 10px 20px;
            border-radius: 6px;
            font-weight: 500;
            cursor: pointer;
            border: none;
            font-size: 14px;
        }
        .btn-primary {
            background: #4f46e5;
            color: white;
        }
        .btn-secondary {
            background: #e5e7eb;
            color: #374151;
        }
        .btn-danger {
            background: #dc2626;
            color: white;
        }
        .btn-success {
            background: #16a34a;
            color: white;
        }
        .input {
            width: 100%;
            padding: 10px 14px;
            border: 1px solid #d1d5db;
            border-radius: 6px;
            font-size: 14px;
            background: white;
        }
        .input:focus {
            outline: none;
            border-color: #4f46e5;
            box-shadow: 0 0 0 3px rgba(79, 70, 229, 0.1);
        }
        .label {
            display: block;
            font-size: 14px;
            font-weight: 500;
            color: #374151;
            margin-bottom: 6px;
        }
        .card {
            background: white;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            padding: 16px;
        }
        .heading {
            font-size: 18px;
            font-weight: 600;
            color: #111827;
        }
        .subheading {
            font-size: 14px;
            color: #6b7280;
        }
        /* Text utilities */
        .text-gray { color: #6b7280; }
        .text-dark { color: #111827; }
        .text-sm { font-size: 14px; }
        .text-xs { font-size: 12px; }
        .text-lg { font-size: 18px; }
        .font-medium { font-weight: 500; }
        .font-bold { font-weight: 700; }
        /* Spacing utilities */
        .mt-1 { margin-top: 4px; }
        .mt-2 { margin-top: 8px; }
        .mt-3 { margin-top: 12px; }
        .mt-4 { margin-top: 16px; }
        .mb-1 { margin-bottom: 4px; }
        .mb-2 { margin-bottom: 8px; }
        .mb-3 { margin-bottom: 12px; }
        .mb-4 { margin-bottom: 16px; }
        .p-2 { padding: 8px; }
        .p-4 { padding: 16px; }
        /* Flexbox utilities */
        .flex { display: flex; }
        .inline-flex { display: inline-flex; }
        .items-center { align-items: center; }
        .items-start { align-items: flex-start; }
        .justify-between { justify-content: space-between; }
        .justify-center { justify-content: center; }
        .gap-1 { gap: 4px; }
        .gap-2 { gap: 8px; }
        .gap-3 { gap: 12px; }
        .gap-4 { gap: 16px; }
        .flex-col { flex-direction: column; }
        .flex-1 { flex: 1; }
        /* Layout utilities */
        .w-full { width: 100%; }
        .rounded { border-radius: 6px; }
        .rounded-lg { border-radius: 8px; }
        .border { border: 1px solid #e5e7eb; }
        .shadow { box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1); }
        /* Form elements */
        .checkbox {
            width: 16px;
            height: 16px;
            accent-color: #4f46e5;
        }
        .toggle {
            width: 44px;
            height: 24px;
            background: #e5e7eb;
            border-radius: 12px;
            position: relative;
            cursor: pointer;
        }
        .toggle.active {
            background: #4f46e5;
        }
        .toggle::after {
            content: '';
            position: absolute;
            width: 20px;
            height: 20px;
            background: white;
            border-radius: 50%;
            top: 2px;
            left: 2px;
            transition: transform 0.2s;
        }
        .toggle.active::after {
            transform: translateX(20px);
        }
        /* Icons (simple shapes) */
        .icon {
            width: 20px;
            height: 20px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
        }
        .icon-circle {
            width: 8px;
            height: 8px;
            background: currentColor;
            border-radius: 50%;
        }
        /* Alert/notification styles */
        .alert {
            padding: 12px 16px;
            border-radius: 6px;
            font-size: 14px;
        }
        .alert-info {
            background: #eff6ff;
            color: #1e40af;
            border: 1px solid #bfdbfe;
        }
        .alert-success {
            background: #f0fdf4;
            color: #166534;
            border: 1px solid #bbf7d0;
        }
        .alert-warning {
            background: #fffbeb;
            color: #92400e;
            border: 1px solid #fde68a;
        }
        .alert-error {
            background: #fef2f2;
            color: #991b1b;
            border: 1px solid #fecaca;
        }
        /* Table styles */
        .table {
            width: 100%;
            border-collapse: collapse;
        }
        .table th, .table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e5e7eb;
        }
        .table th {
            font-weight: 500;
            color: #6b7280;
            font-size: 12px;
            text-transform: uppercase;
        }
        /* Navigation/tabs */
        .tabs {
            display: flex;
            border-bottom: 1px solid #e5e7eb;
        }
        .tab {
            padding: 12px 16px;
            font-size: 14px;
            color: #6b7280;
            border-bottom: 2px solid transparent;
            margin-bottom: -1px;
        }
        .tab.active {
            color: #4f46e5;
            border-bottom-color: #4f46e5;
        }
        /* Dropdown/menu */
        .dropdown {
            background: white;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
            padding: 4px;
        }
        .dropdown-item {
            padding: 8px 12px;
            font-size: 14px;
            color: #374151;
            border-radius: 4px;
        }
        .dropdown-item:hover, .dropdown-item.active {
            background: #f3f4f6;
        }
        /* Avatar */
        .avatar {
            width: 32px;
            height: 32px;
            border-radius: 50%;
            background: #e5e7eb;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 14px;
            font-weight: 500;
            color: #374151;
        }
        .avatar-lg {
            width: 48px;
            height: 48px;
            font-size: 18px;
        }
        /* Badge */
        .badge {
            display: inline-flex;
            align-items: center;
            padding: 2px 8px;
            font-size: 12px;
            font-weight: 500;
            border-radius: 9999px;
        }
        .badge-gray {
            background: #f3f4f6;
            color: #374151;
        }
        .badge-blue {
            background: #dbeafe;
            color: #1e40af;
        }
        .badge-green {
            background: #dcfce7;
            color: #166534;
        }
        .badge-red {
            background: #fee2e2;
            color: #991b1b;
        }
        /* Terminal mockup styles */
        .terminal {
            background: #1e1e1e;
            border-radius: 8px;
            overflow: hidden;
            font-family: 'SF Mono', Monaco, Inconsolata, 'Fira Code', 'Courier New', monospace;
            font-size: 13px;
            max-width: 700px;
        }
        .terminal-header {
            background: #323232;
            padding: 8px 12px;
            color: #8b8b8b;
            font-size: 12px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .terminal-dots {
            display: flex;
            gap: 6px;
        }
        .terminal-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
        }
        .terminal-dot.red { background: #ff5f56; }
        .terminal-dot.yellow { background: #ffbd2e; }
        .terminal-dot.green { background: #27ca40; }
        .terminal-body {
            padding: 16px;
            color: #d4d4d4;
            line-height: 1.6;
        }
        .terminal-line {
            white-space: pre-wrap;
            margin-bottom: 4px;
        }
        .prompt {
            color: #6a9955;
            margin-right: 8px;
        }
        .terminal-output {
            color: #9cdcfe;
        }
        .terminal-success {
            color: #4ec9b0;
        }
        .terminal-error {
            color: #f14c4c;
        }
        .terminal-warning {
            color: #cca700;
        }
        .terminal-dim {
            color: #6a6a6a;
        }
    </style>
</head>
<body>
${html}
</body>
</html>`;
    }

    const browser = await puppeteer.launch({
        headless: 'new',
        executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium',
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu'
        ]
    });

    try {
        const page = await browser.newPage();

        // Set viewport for consistent rendering
        await page.setViewport({
            width: 800,
            height: 600,
            deviceScaleFactor: 2 // Retina quality
        });

        await page.setContent(html, {
            waitUntil: 'networkidle0'
        });

        // Get the actual content size
        const bodyHandle = await page.$('body');
        const boundingBox = await bodyHandle.boundingBox();

        // Screenshot with padding, capped at reasonable dimensions
        const screenshotHeight = Math.min(Math.ceil(boundingBox.height) + 48, 1200);
        const screenshotWidth = Math.min(Math.ceil(boundingBox.width) + 48, 800);

        await page.screenshot({
            path: outputPath,
            type: 'png',
            clip: {
                x: 0,
                y: 0,
                width: screenshotWidth,
                height: screenshotHeight
            }
        });

        console.log(`Rendered mockup: ${screenshotWidth}x${screenshotHeight}px`);
    } finally {
        await browser.close();
    }
}

const outputPath = process.argv[2];
if (!outputPath) {
    console.error('Error: Output path required');
    process.exit(1);
}

renderMockup(outputPath).catch(err => {
    console.error('Error rendering mockup:', err.message);
    process.exit(1);
});
