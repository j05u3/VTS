#!/usr/bin/env node

/**
 * Generate Sparkle appcast.xml from GitHub releases
 * Usage: node generate-appcast.js releases.json > appcast.xml
 */

const fs = require('fs');
const path = require('path');

/**
 * Simple XML builder for generating clean, properly formatted XML
 */
class XMLBuilder {
  constructor() {
    this.indentLevel = 0;
    this.indentSize = 2;
  }

  indent() {
    return ' '.repeat(this.indentLevel * this.indentSize);
  }

  escapeXML(text) {
    if (typeof text !== 'string') text = String(text);
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  startElement(name, attributes = {}) {
    const attrs = Object.entries(attributes)
      .map(([key, value]) => ` ${key}="${this.escapeXML(value)}"`)
      .join('');
    
    const line = `${this.indent()}<${name}${attrs}>`;
    this.indentLevel++;
    return line;
  }

  endElement(name) {
    this.indentLevel--;
    return `${this.indent()}</${name}>`;
  }

  element(name, content, attributes = {}) {
    const attrs = Object.entries(attributes)
      .map(([key, value]) => ` ${key}="${this.escapeXML(value)}"`)
      .join('');
    
    if (content === null || content === undefined || content === '') {
      return `${this.indent()}<${name}${attrs} />`;
    }
    
    const escapedContent = this.escapeXML(content);
    return `${this.indent()}<${name}${attrs}>${escapedContent}</${name}>`;
  }

  cdata(content) {
    return `${this.indent()}<![CDATA[${content}]]>`;
  }
}

function formatDate(dateString) {
  return new Date(dateString).toUTCString();
}

function formatFileSize(bytes) {
  return Math.round(bytes / (1024 * 1024) * 10) / 10; // MB with 1 decimal
}

/**
 * Convert basic markdown to HTML
 */
function markdownToHtml(markdown) {
  if (!markdown) return '';
  
  let html = markdown
    // Convert headers
    .replace(/^### (.*$)/gim, '<h3>$1</h3>')
    .replace(/^## (.*$)/gim, '<h2>$1</h2>')
    .replace(/^# (.*$)/gim, '<h1>$1</h1>')
    
    // Convert lists
    .replace(/^\* (.*$)/gim, '<li>$1</li>')
    .replace(/^- (.*$)/gim, '<li>$1</li>')
    
    // Convert bold and italic
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    
    // Convert code blocks (simple approach)
    .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
    .replace(/`(.*?)`/g, '<code>$1</code>')
    
    // Convert links
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>')
    
    // Convert line breaks to paragraphs
    .split('\n\n')
    .map(paragraph => {
      paragraph = paragraph.trim();
      if (!paragraph) return '';
      
      // Check if it's a list
      if (paragraph.includes('<li>')) {
        // Wrap list items in ul tags
        return '<ul>\n' + paragraph.replace(/\n/g, '\n') + '\n</ul>';
      }
      
      // Check if it's already a heading or has HTML tags
      if (paragraph.match(/^<h[1-6]>/) || paragraph.match(/^<[^>]+>/)) {
        return paragraph;
      }
      
      // Regular paragraph
      return '<p>' + paragraph.replace(/\n/g, '<br>') + '</p>';
    })
    .filter(p => p.length > 0)
    .join('\n');
    
  return html;
}

async function generateAppcastXMLWithSignatures(releases, downloadHistoricalSignatures = false) {
  const xml = new XMLBuilder();
  const lines = [];
  
  // XML declaration
  lines.push('<?xml version="1.0" encoding="utf-8"?>');
  
  // RSS root element
  lines.push(xml.startElement('rss', {
    version: '2.0',
    'xmlns:sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle',
    'xmlns:dc': 'http://purl.org/dc/elements/1.1/'
  }));
  
  // Channel start
  lines.push(xml.startElement('channel'));
  
  // Channel metadata
  lines.push(xml.element('title', 'VTS - Voice Typing Studio'));
  lines.push(xml.element('link', 'https://github.com/j05u3/VTS'));
  lines.push(xml.element('description', 'Voice Typing Studio - Open-source macOS dictation replacement with AI-powered transcription'));
  lines.push(xml.element('language', 'en'));
  lines.push(xml.element('lastBuildDate', formatDate(new Date().toISOString())));
  lines.push('');

  // Filter and process releases
  const validReleases = releases
    .filter(release => !release.draft && !release.prerelease)
    .filter(release => {
      // Find DMG asset and signature
      const dmgAsset = release.assets.find(asset => 
        asset.name.includes('.dmg') && asset.name.includes('Universal')
      );
      const sigAsset = release.assets.find(asset => 
        asset.name.includes('.dmg.sig')
      );
      return dmgAsset && sigAsset;
    })
    .slice(0, 100); // Keep latest 100 releases

  // Generate items
  for (let i = 0; i < validReleases.length; i++) {
    const release = validReleases[i];
    const isLatest = i === 0;
    
    const dmgAsset = release.assets.find(asset => 
      asset.name.includes('.dmg') && asset.name.includes('Universal')
    );

    // Extract version number (remove 'v' prefix)
    const version = release.tag_name.replace(/^v/, '');
    
    // Get the appropriate signature
    let signature;
    if (downloadHistoricalSignatures) {
      signature = await getSignatureForRelease(release, isLatest);
    } else {
      // Use placeholder for all releases - workflow will handle current release
      signature = 'SIGNATURE_PLACEHOLDER';
    }

    lines.push(xml.startElement('item'));
    lines.push(xml.element('title', `VTS ${version}`));
    lines.push(xml.element('link', release.html_url));
    
    // Description with CDATA
    if (release.body) {
      const htmlBody = markdownToHtml(release.body);
      lines.push(xml.startElement('description'));
      xml.indentLevel++;
      lines.push(xml.cdata(`
        <h2>What's New in Version ${version}</h2>
        ${htmlBody}
        <hr>
        <p><strong>Size:</strong> ${formatFileSize(dmgAsset.size)} MB</p>
        <p><strong>Release Date:</strong> ${new Date(release.published_at).toLocaleDateString()}</p>
      `));
      xml.indentLevel--;
      lines.push(xml.endElement('description'));
    }
    
    lines.push(xml.element('pubDate', formatDate(release.published_at)));
    
    // Enclosure element with Sparkle attributes
    lines.push(xml.element('enclosure', '', {
      url: dmgAsset.browser_download_url,
      length: dmgAsset.size,
      type: 'application/octet-stream',
      'sparkle:version': version,
      'sparkle:shortVersionString': version,
      'sparkle:edSignature': signature
    }));
    
    lines.push(xml.element('guid', `VTS-${release.tag_name}`, { isPermaLink: 'false' }));
    lines.push(xml.endElement('item'));
    lines.push('');
  }

  // Close channel and rss
  lines.push(xml.endElement('channel'));
  lines.push(xml.endElement('rss'));
  
  return lines.join('\n');
}

// Legacy function for backward compatibility  
function generateAppcastXML(releases) {
  const xml = new XMLBuilder();
  const lines = [];
  
  // XML declaration
  lines.push('<?xml version="1.0" encoding="utf-8"?>');
  
  // RSS root element
  lines.push(xml.startElement('rss', {
    version: '2.0',
    'xmlns:sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle',
    'xmlns:dc': 'http://purl.org/dc/elements/1.1/'
  }));
  
  // Channel start
  lines.push(xml.startElement('channel'));
  
  // Channel metadata
  lines.push(xml.element('title', 'VTS - Voice Typing Studio'));
  lines.push(xml.element('link', 'https://github.com/j05u3/VTS'));
  lines.push(xml.element('description', 'Voice Typing Studio - Open-source macOS dictation replacement with AI-powered transcription'));
  lines.push(xml.element('language', 'en'));
  lines.push(xml.element('lastBuildDate', formatDate(new Date().toISOString())));
  lines.push('');

  // Filter and process releases
  const validReleases = releases
    .filter(release => !release.draft && !release.prerelease)
    .filter(release => {
      // Find DMG asset and signature
      const dmgAsset = release.assets.find(asset => 
        asset.name.includes('.dmg') && asset.name.includes('Universal')
      );
      const sigAsset = release.assets.find(asset => 
        asset.name.includes('.dmg.sig')
      );
      return dmgAsset && sigAsset;
    })
    .slice(0, 100); // Keep latest 100 releases

  // Generate items  
  for (const release of validReleases) {
    const dmgAsset = release.assets.find(asset => 
      asset.name.includes('.dmg') && asset.name.includes('Universal')
    );

    // Extract version number (remove 'v' prefix)
    const version = release.tag_name.replace(/^v/, '');
    
    // Use placeholder signature that will be updated in the workflow
    const signature = 'SIGNATURE_PLACEHOLDER';

    lines.push(xml.startElement('item'));
    lines.push(xml.element('title', `VTS ${version}`));
    lines.push(xml.element('link', release.html_url));
    
    // Description with CDATA
    if (release.body) {
      const htmlBody = markdownToHtml(release.body);
      lines.push(xml.startElement('description'));
      xml.indentLevel++;
      lines.push(xml.cdata(`
        <h2>What's New in Version ${version}</h2>
        ${htmlBody}
        <hr>
        <p><strong>Size:</strong> ${formatFileSize(dmgAsset.size)} MB</p>
        <p><strong>Release Date:</strong> ${new Date(release.published_at).toLocaleDateString()}</p>
      `));
      xml.indentLevel--;
      lines.push(xml.endElement('description'));
    }
    
    lines.push(xml.element('pubDate', formatDate(release.published_at)));
    
    // Enclosure element with Sparkle attributes
    lines.push(xml.element('enclosure', '', {
      url: dmgAsset.browser_download_url,
      length: dmgAsset.size,
      type: 'application/octet-stream',
      'sparkle:version': version,
      'sparkle:shortVersionString': version,
      'sparkle:edSignature': signature
    }));
    
    lines.push(xml.element('guid', `VTS-${release.tag_name}`, { isPermaLink: 'false' }));
    lines.push(xml.endElement('item'));
    lines.push('');
  }

  // Close channel and rss
  lines.push(xml.endElement('channel'));
  lines.push(xml.endElement('rss'));
  
  return lines.join('\n');
}

/**
 * Download signature for a release
 */
async function downloadSignature(sigAsset) {
  const https = require('https');
  const { URL } = require('url');
  
  return new Promise((resolve, reject) => {
    const download = (url, maxRedirects = 5) => {
      if (maxRedirects <= 0) {
        reject(new Error('Too many redirects'));
        return;
      }
      
      const options = new URL(url);
      
      https.get(options, (res) => {
        // Handle redirects
        if (res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 307 || res.statusCode === 308) {
          const location = res.headers.location;
          if (location) {
            download(location, maxRedirects - 1);
            return;
          }
        }
        
        if (res.statusCode !== 200) {
          reject(new Error(`Failed to download signature: ${res.statusCode}`));
          return;
        }
        
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => resolve(data.trim()));
      }).on('error', reject);
    };
    
    download(sigAsset.browser_download_url);
  });
}

/**
 * Get signature for a release (download if historical, placeholder if current)
 */
async function getSignatureForRelease(release, isLatest) {
  if (isLatest) {
    // For the latest release, use placeholder that will be replaced by workflow
    return 'SIGNATURE_PLACEHOLDER';
  }
  
  // For historical releases, try to download the actual signature
  const sigAsset = release.assets.find(asset => 
    asset.name.includes('.dmg.sig')
  );
  
  if (!sigAsset) {
    console.error(`⚠️  No signature asset found for ${release.tag_name}`);
    return 'SIGNATURE_MISSING';
  }
  
  try {
    const signature = await downloadSignature(sigAsset);
    console.error(`✅ Downloaded signature for ${release.tag_name}`);
    return signature;
  } catch (error) {
    console.error(`⚠️  Failed to download signature for ${release.tag_name}: ${error.message}`);
    return 'SIGNATURE_DOWNLOAD_FAILED';
  }
}

// Main execution
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node generate-appcast.js releases.json [--inject-signatures]');
    console.error('');
    console.error('Options:');
    console.error('  --inject-signatures  Download and inject actual signatures for historical releases');
    console.error('');
    console.error('Example:');
    console.error('  gh api repos/j05u3/VTS/releases > releases.json');
    console.error('  node generate-appcast.js releases.json > appcast.xml');
    console.error('  node generate-appcast.js releases.json --inject-signatures > appcast.xml');
    process.exit(1);
  }

  const releasesFile = args[0];
  const injectSigs = args.includes('--inject-signatures');
  
  (async () => {
    try {
      const releasesData = fs.readFileSync(releasesFile, 'utf8');
      const releases = JSON.parse(releasesData);
      
      if (!Array.isArray(releases)) {
        throw new Error('Invalid releases data: expected an array');
      }
      
      if (releases.length === 0) {
        console.error('⚠️  No releases found in the provided data');
      }
      
      let appcastXML;
      if (injectSigs) {
        console.error('🔐 Downloading historical signatures...');
        appcastXML = await generateAppcastXMLWithSignatures(releases, true);
      } else {
        appcastXML = generateAppcastXML(releases);
      }
      
      console.log(appcastXML);
      
      // Log some useful info to stderr
      const validReleases = releases
        .filter(release => !release.draft && !release.prerelease)
        .filter(release => {
          const dmgAsset = release.assets.find(asset => 
            asset.name.includes('.dmg') && asset.name.includes('Universal')
          );
          const sigAsset = release.assets.find(asset => 
            asset.name.includes('.dmg.sig')
          );
          return dmgAsset && sigAsset;
        });
        
      console.error(`✅ Generated appcast with ${validReleases.length} releases`);
      if (validReleases.length > 0) {
        const latest = validReleases[0];
        console.error(`📦 Latest release: ${latest.tag_name} (${new Date(latest.published_at).toLocaleDateString()})`);
      }
      
      if (injectSigs) {
        console.error('💡 Historical signatures downloaded. Current release signature will be injected by workflow.');
      } else {
        console.error('💡 Using placeholders for all signatures. Current release signature will be injected by workflow.');
      }
      
    } catch (error) {
      console.error('❌ Error generating appcast:', error.message);
      if (process.env.DEBUG) {
        console.error(error.stack);
      }
      process.exit(1);
    }
  })();
}

module.exports = { generateAppcastXML, generateAppcastXMLWithSignatures, XMLBuilder };
