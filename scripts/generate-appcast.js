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
    const sigAsset = release.assets.find(asset => 
      asset.name.includes('.dmg.sig')
    );

    // Extract version number (remove 'v' prefix)
    const version = release.tag_name.replace(/^v/, '');
    
    // For now, we'll use a placeholder signature that will be updated in the workflow
    const signature = 'SIGNATURE_PLACEHOLDER';

    lines.push(xml.startElement('item'));
    lines.push(xml.element('title', `VTS ${version}`));
    lines.push(xml.element('link', release.html_url));
    
    // Description with CDATA
    if (release.body) {
      lines.push(xml.startElement('description'));
      xml.indentLevel++;
      lines.push(xml.cdata(`
        <h2>What's New in Version ${version}</h2>
        <pre>${release.body}</pre>
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
 * Replace signature placeholders with actual signatures from release assets
 */
function injectSignatures(xmlContent, releases) {
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
    })
    .slice(0, 10);

  let result = xmlContent;
  
  for (const release of validReleases) {
    const version = release.tag_name.replace(/^v/, '');
    const sigAsset = release.assets.find(asset => 
      asset.name.includes('.dmg.sig')
    );
    
    if (sigAsset) {
      // Note: In a real implementation, we would fetch the signature content
      // For now, we'll keep the placeholder and let the workflow handle it
      console.error(`⚠️  Found signature asset for ${version}: ${sigAsset.browser_download_url}`);
      console.error(`⚠️  Signature will need to be injected by the workflow`);
    }
  }
  
  return result;
}

// Main execution
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node generate-appcast.js releases.json [--inject-signatures]');
    console.error('');
    console.error('Options:');
    console.error('  --inject-signatures  Attempt to download and inject actual signatures');
    console.error('');
    console.error('Example:');
    console.error('  gh api repos/j05u3/VTS/releases > releases.json');
    console.error('  node generate-appcast.js releases.json > appcast.xml');
    process.exit(1);
  }

  const releasesFile = args[0];
  const injectSigs = args.includes('--inject-signatures');
  
  try {
    const releasesData = fs.readFileSync(releasesFile, 'utf8');
    const releases = JSON.parse(releasesData);
    
    if (!Array.isArray(releases)) {
      throw new Error('Invalid releases data: expected an array');
    }
    
    if (releases.length === 0) {
      console.error('⚠️  No releases found in the provided data');
    }
    
    let appcastXML = generateAppcastXML(releases);
    
    if (injectSigs) {
      appcastXML = injectSignatures(appcastXML, releases);
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
    
  } catch (error) {
    console.error('❌ Error generating appcast:', error.message);
    if (process.env.DEBUG) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

module.exports = { generateAppcastXML, XMLBuilder };
