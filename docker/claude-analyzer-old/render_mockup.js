#!/usr/bin/env node
/**
 * Enhanced Mockup Renderer
 * Renders HTML mockups to PNG with quality detection, adaptive viewport,
 * and comprehensive diagnostics.
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Viewport presets for different content types
const VIEWPORTS = {
    mobile: { width: 375, height: 667 },
    tablet: { width: 768, height: 1024 },
    desktop: { width: 800, height: 600 },
    wide: { width: 1200, height: 800 },
    terminal: { width: 600, height: 400 },
    tui: { width: 720, height: 480 }
};

// Fallback CSS for fonts and icons when CDNs fail
const FALLBACK_CSS = `
/* Font fallbacks */
@font-face {
    font-family: 'Inter';
    src: local('Inter'), local('system-ui'), local('-apple-system'), local('BlinkMacSystemFont');
    font-weight: 100 900;
}

/* FontAwesome unicode fallbacks for common icons */
.fa, .fas, .far, .fab, [class^="fa-"], [class*=" fa-"] {
    font-family: system-ui, -apple-system, sans-serif !important;
}
.fa-check::before, .fa-check-circle::before { content: "\\2713" !important; }
.fa-times::before, .fa-times-circle::before, .fa-close::before { content: "\\2717" !important; }
.fa-arrow-right::before { content: "\\2192" !important; }
.fa-arrow-left::before { content: "\\2190" !important; }
.fa-arrow-up::before { content: "\\2191" !important; }
.fa-arrow-down::before { content: "\\2193" !important; }
.fa-plus::before { content: "+" !important; }
.fa-minus::before { content: "\\2212" !important; }
.fa-search::before { content: "\\1F50D" !important; }
.fa-user::before { content: "\\1F464" !important; }
.fa-cog::before, .fa-gear::before { content: "\\2699" !important; }
.fa-home::before { content: "\\1F3E0" !important; }
.fa-envelope::before, .fa-mail::before { content: "\\2709" !important; }
.fa-phone::before { content: "\\260E" !important; }
.fa-edit::before, .fa-pencil::before { content: "\\270E" !important; }
.fa-trash::before { content: "\\1F5D1" !important; }
.fa-download::before { content: "\\2B07" !important; }
.fa-upload::before { content: "\\2B06" !important; }
.fa-star::before { content: "\\2605" !important; }
.fa-heart::before { content: "\\2665" !important; }
.fa-warning::before, .fa-exclamation-triangle::before { content: "\\26A0" !important; }
.fa-info::before, .fa-info-circle::before { content: "\\2139" !important; }
.fa-question::before, .fa-question-circle::before { content: "?" !important; }
.fa-lock::before { content: "\\1F512" !important; }
.fa-unlock::before { content: "\\1F513" !important; }
.fa-eye::before { content: "\\1F441" !important; }
.fa-eye-slash::before { content: "\\1F648" !important; }
.fa-copy::before { content: "\\1F4CB" !important; }
.fa-save::before { content: "\\1F4BE" !important; }
.fa-spinner::before { content: "\\21BB" !important; }
.fa-refresh::before, .fa-sync::before { content: "\\21BB" !important; }
.fa-external-link::before { content: "\\2197" !important; }
.fa-link::before { content: "\\1F517" !important; }
.fa-calendar::before { content: "\\1F4C5" !important; }
.fa-clock::before { content: "\\1F550" !important; }
.fa-file::before { content: "\\1F4C4" !important; }
.fa-folder::before { content: "\\1F4C1" !important; }
.fa-github::before { content: "\\1F4BB" !important; }

/* TUI monospace font support */
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap');
@import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500;600;700&display=swap');

.tui-app, .tui-container, [data-viewport="tui"] body {
    font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Monaco, 'Cascadia Code', monospace !important;
}
`;

function getViewportFromHtml(html) {
    const viewportMatch = html.match(/data-viewport=["'](\w+)["']/i);
    const viewportType = viewportMatch ? viewportMatch[1].toLowerCase() : 'wide';
    return VIEWPORTS[viewportType] || VIEWPORTS.wide;
}

function injectFallbackStyles(html) {
    // Inject fallback CSS right after opening head tag
    if (/<head/i.test(html)) {
        return html.replace(/<head([^>]*)>/i, `<head$1><style id="fallback-styles">${FALLBACK_CSS}</style>`);
    }
    // If no head tag, wrap in basic HTML structure
    return `<!DOCTYPE html><html><head><style id="fallback-styles">${FALLBACK_CSS}</style></head><body>${html}</body></html>`;
}

async function renderMockup(outputPath, htmlFile) {
    const html = fs.readFileSync(htmlFile, 'utf8').trim();

    if (!html) {
        console.error('Error: No HTML content in file');
        process.exit(1);
    }

    // Determine viewport from HTML hints
    const viewport = getViewportFromHtml(html);

    // Tracking for diagnostics
    const pageErrors = [];
    const consoleMessages = [];
    const failedResources = [];
    const loadedResources = [];

    const browser = await puppeteer.launch({
        headless: 'new',
        executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium',
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--disable-web-security'  // Allow loading cross-origin resources
        ]
    });

    let renderMetrics = {};

    try {
        const page = await browser.newPage();

        // Capture page errors
        page.on('pageerror', err => {
            pageErrors.push(err.message);
        });

        // Capture console messages
        page.on('console', msg => {
            const entry = { type: msg.type(), text: msg.text() };
            consoleMessages.push(entry);
            if (msg.type() === 'error') {
                pageErrors.push(msg.text());
            }
        });

        // Track resource loading
        page.on('requestfinished', request => {
            loadedResources.push({
                url: request.url(),
                resourceType: request.resourceType()
            });
        });

        page.on('requestfailed', request => {
            failedResources.push({
                url: request.url(),
                resourceType: request.resourceType(),
                reason: request.failure()?.errorText || 'Unknown'
            });
        });

        // Set viewport based on content type hint
        await page.setViewport({
            width: viewport.width,
            height: viewport.height,
            deviceScaleFactor: 2 // Retina quality
        });

        // Load HTML file directly via file:// so relative paths (e.g., ../mockup_assets/) resolve correctly
        const fileUrl = `file://${path.resolve(htmlFile)}`;
        await page.goto(fileUrl, {
            waitUntil: 'networkidle0',
            timeout: 15000  // 15 second timeout
        }).catch(err => {
            // If networkidle0 times out, try with just domcontentloaded
            console.warn('Network idle timeout, continuing with available content');
            return page.goto(fileUrl, {
                waitUntil: 'domcontentloaded',
                timeout: 5000
            });
        });

        // Inject fallback styles for fonts and icons after page loads
        await page.addStyleTag({ content: FALLBACK_CSS });

        // Get the actual content size
        const bodyHandle = await page.$('body');
        const boundingBox = await bodyHandle.boundingBox();

        // Analyze render quality
        renderMetrics = await page.evaluate(() => {
            const body = document.body;
            const rect = body.getBoundingClientRect();
            const computedStyle = window.getComputedStyle(body);

            // Count visible elements
            const visibleElements = document.querySelectorAll('div, p, h1, h2, h3, h4, h5, h6, span, button, input, form, table, ul, ol, li, img, a, nav, header, footer, section, article');

            // Check for text content
            const textContent = body.innerText.trim();

            // Check for images
            const images = document.querySelectorAll('img');
            const loadedImages = Array.from(images).filter(img => img.complete && img.naturalWidth > 0);

            return {
                width: rect.width,
                height: rect.height,
                hasChildren: body.children.length > 0,
                childCount: body.children.length,
                visibleElementCount: visibleElements.length,
                hasTextContent: textContent.length > 0,
                textLength: textContent.length,
                backgroundColor: computedStyle.backgroundColor,
                imageCount: images.length,
                loadedImageCount: loadedImages.length
            };
        });

        // Determine if render is likely broken
        renderMetrics.isLikelyBlank =
            renderMetrics.width < 10 ||
            renderMetrics.height < 10 ||
            (!renderMetrics.hasChildren && !renderMetrics.hasTextContent) ||
            (renderMetrics.visibleElementCount === 0 && renderMetrics.textLength === 0);

        // Screenshot with padding, capped at reasonable dimensions
        const screenshotHeight = Math.min(Math.ceil(boundingBox.height) + 48, 1200);
        const screenshotWidth = Math.min(Math.ceil(boundingBox.width) + 48, viewport.width);

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

        console.log(`Rendered mockup: ${screenshotWidth}x${screenshotHeight}px (viewport: ${viewport.width}x${viewport.height})`);

        // Warn about potential issues
        if (renderMetrics.isLikelyBlank) {
            console.warn('Warning: Rendered image appears blank or nearly blank');
        }
        if (failedResources.length > 0) {
            console.warn(`Warning: ${failedResources.length} resource(s) failed to load`);
        }

    } finally {
        await browser.close();
    }

    // Write diagnostics JSON
    const diagnosticsPath = outputPath.replace('.png', '_diagnostics.json');
    const diagnostics = {
        timestamp: new Date().toISOString(),
        viewport: viewport,
        metrics: renderMetrics,
        pageErrors: pageErrors,
        failedResources: failedResources,
        loadedResourceCount: loadedResources.length,
        qualityScore: calculateQualityScore(renderMetrics, pageErrors, failedResources)
    };

    fs.writeFileSync(diagnosticsPath, JSON.stringify(diagnostics, null, 2));

    return diagnostics;
}

function calculateQualityScore(metrics, pageErrors, failedResources) {
    let score = 100;
    const deductions = [];

    // Deduct for page errors
    if (pageErrors.length > 0) {
        const deduction = Math.min(pageErrors.length * 10, 30);
        score -= deduction;
        deductions.push(`-${deduction}: ${pageErrors.length} page error(s)`);
    }

    // Deduct for failed resources (less severe)
    if (failedResources.length > 0) {
        const deduction = Math.min(failedResources.length * 3, 15);
        score -= deduction;
        deductions.push(`-${deduction}: ${failedResources.length} failed resource(s)`);
    }

    // Deduct for likely blank
    if (metrics.isLikelyBlank) {
        score -= 50;
        deductions.push('-50: Appears blank');
    }

    // Deduct for very small content
    if (metrics.visibleElementCount < 3) {
        score -= 10;
        deductions.push('-10: Very few visible elements');
    }

    // Bonus for having styles (already injected, so less relevant)
    // Bonus for proper structure is implicit

    const rating = score >= 80 ? 'good' : score >= 50 ? 'acceptable' : 'poor';

    return {
        score: Math.max(0, Math.min(100, score)),
        rating,
        deductions
    };
}

// Main execution
const outputPath = process.argv[2];
const htmlFile = process.argv[3];

if (!outputPath || !htmlFile) {
    console.error('Error: Usage: render_mockup.js <output_path> <html_file>');
    process.exit(1);
}

renderMockup(outputPath, htmlFile)
    .then(diagnostics => {
        if (diagnostics.qualityScore.rating === 'poor') {
            console.error(`Warning: Render quality is poor (score: ${diagnostics.qualityScore.score})`);
            // Don't exit with error - still produce the image for debugging
        }
    })
    .catch(err => {
        console.error('Error rendering mockup:', err.message);
        process.exit(1);
    });
