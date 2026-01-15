#!/usr/bin/env node
const puppeteer = require('puppeteer');
const fs = require('fs');

async function renderMockup(outputPath, htmlFile) {
    const html = fs.readFileSync(htmlFile, 'utf8').trim();

    if (!html) {
        console.error('Error: No HTML content in file');
        process.exit(1);
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
const htmlFile = process.argv[3];

if (!outputPath || !htmlFile) {
    console.error('Error: Usage: render_mockup.js <output_path> <html_file>');
    process.exit(1);
}

renderMockup(outputPath, htmlFile).catch(err => {
    console.error('Error rendering mockup:', err.message);
    process.exit(1);
});
