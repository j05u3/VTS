---
layout: default
title: VTS Auto-Update Feed
---

# VTS - Voice Typing Studio

## Auto-Update Feed

This site hosts the Sparkle appcast feed for VTS automatic updates.

### 📡 Appcast URL
```
https://j05u3.github.io/VTS/appcast.xml
```

### 🚀 Latest Releases

{% assign releases = site.github.releases | where_exp: "release", "release.prerelease != true and release.draft != true" | sort: "published_at" | reverse %}

{% for release in releases limit:5 %}
#### [{{ release.tag_name }}]({{ release.html_url }}) - {{ release.published_at | date: "%B %d, %Y" }}

{{ release.body | markdownify }}

**Downloads:**
{% for asset in release.assets %}
- [{{ asset.name }}]({{ asset.browser_download_url }}) ({{ asset.size | divided_by: 1048576.0 | round: 1 }} MB)
{% endfor %}

---
{% endfor %}

### 🔗 Links

- [GitHub Repository](https://github.com/{{ site.repository }})
- [Download Latest Release](https://github.com/{{ site.repository }}/releases/latest)
- [All Releases](https://github.com/{{ site.repository }}/releases)

### 🔧 For Developers

This appcast is automatically generated from GitHub Releases using Jekyll and GitHub Pages. The feed updates whenever a new release is published.

**Feed Structure:**
- Reads from GitHub Releases API via Jekyll
- Filters out prereleases and drafts
- Includes DMG download links with proper Sparkle attributes
- Provides rich HTML descriptions with changelog content
