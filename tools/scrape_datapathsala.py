#!/usr/bin/env python3
"""
Scrape datapathsala.com/system-design/ and save articles as Markdown files under
the src/main/Usecases directory inside the Notes workspace.

Usage: run with the Python in your environment. The script will try to use html2text
if available to preserve formatting; otherwise it will fall back to plain text.
"""
import requests
from bs4 import BeautifulSoup
import os
import re
import time
import sys
import json
from urllib.parse import urljoin, urlparse
from pathlib import Path

BASE = 'https://datapathsala.com/system-design/'
OUTDIR = r'C:\Users\rahul_ranjan\Documents\manish\Notes\src\main\Usecases'
HEADERS = {'User-Agent': 'Mozilla/5.0 (compatible; scraper/1.0)'}
RENDER_JS = True

session = requests.Session()

# Try to import Playwright for JS-rendered pages when available
playwright_available = False
try:
    from playwright.sync_api import sync_playwright
    playwright_available = True
except Exception:
    playwright_available = False


def render_page_content(url, timeout=30000):
    """Return rendered HTML for a URL using Playwright if available."""
    if not playwright_available or not RENDER_JS:
        return None
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.set_extra_http_headers(HEADERS)
            page.goto(url, timeout=timeout)
            # wait a short while for dynamic content
            page.wait_for_timeout(3000)
            content = page.content()
            browser.close()
            return content
    except Exception:
        return None


def ensure_outdir():
    os.makedirs(OUTDIR, exist_ok=True)


def gather_listing_links():
    print('Fetching listing:', BASE)
    r = session.get(BASE, headers=HEADERS, timeout=30)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, 'lxml')
    links = set()
    for a in soup.find_all('a', href=True):
        href = a['href']
        if href.startswith('http'):
            url = href
        elif href.startswith('/'):
            url = 'https://datapathsala.com' + href
        else:
            # ignore relative links like ../
            continue
        if '/system-design/' in url and url.rstrip('/') != BASE.rstrip('/'):
            # filter out the listing root and duplicates
            links.add(url.split('#')[0])
    links = sorted(links)
    print('Found', len(links), 'candidate links')
    return links


def extract_content(soup):
    # Try common article selectors first
    selectors = [
        'article',
        'div.entry-content',
        'div.post-content',
        'div.td-post-content',
        'div.content',
        'div#content',
        'div.main-content',
        'div.post',
        'div.article-body',
    ]
    for sel in selectors:
        el = soup.select_one(sel)
        if el and len(el.get_text(strip=True)) > 200:
            return el

    # Fallback: choose the candidate with the most <p> tags and substantial text
    candidates = soup.find_all(['div', 'section', 'article'], recursive=True)
    if not candidates:
        return soup.body or soup

    def score(node):
        text = node.get_text(' ', strip=True)
        # penalize elements that look like nav/menus/sidebars
        cname = ' '.join(filter(None, [node.get('class') and ' '.join(node.get('class')), node.get('id') or '']))
        if re.search(r'nav|menu|header|footer|sidebar|widget|breadcrumb|pagination', cname, re.I):
            return 0
        pcount = len(node.find_all('p'))
        linkcount = len(node.find_all('a'))
        # score prefers many paragraphs and longer text, but penalizes excessive links (likely nav)
        return pcount * 10 + max(0, len(text) - linkcount * 30)

    best = max(candidates, key=score)
    return best


def extract_metadata(soup, url):
    meta = {}
    # title
    meta['title'] = title_from_soup(soup)
    # author
    author = None
    a = soup.find('meta', attrs={'name': 'author'})
    if a and a.get('content'):
        author = a['content'].strip()
    if not author:
        el = soup.select_one('.author, .byline, .post-author')
        if el:
            author = el.get_text(strip=True)
    meta['author'] = author
    # publish date
    pub = None
    p = soup.find('meta', attrs={'property': 'article:published_time'})
    if p and p.get('content'):
        pub = p['content'].strip()
    if not pub:
        p2 = soup.find('meta', attrs={'name': 'date'})
        if p2 and p2.get('content'):
            pub = p2['content'].strip()
    # try common selectors
    if not pub:
        dsel = soup.select_one('time[datetime], .publish-date, .posted-on')
        if dsel:
            pub = dsel.get('datetime') or dsel.get_text(strip=True)
    meta['published'] = pub
    # tags/keywords
    tags = []
    k = soup.find('meta', attrs={'name': 'keywords'})
    if k and k.get('content'):
        tags = [t.strip() for t in k['content'].split(',') if t.strip()]
    if not tags:
        tagels = soup.select('.tags a, .post-tags a, .tag-list a')
        for t in tagels:
            txt = t.get_text(strip=True)
            if txt:
                tags.append(txt)
    meta['tags'] = tags
    meta['url'] = url
    return meta


def title_from_soup(soup):
    h1 = soup.find('h1')
    if h1 and h1.get_text(strip=True):
        return h1.get_text(strip=True)
    if soup.title and soup.title.get_text(strip=True):
        return soup.title.get_text(strip=True)
    return 'untitled'


def to_markdown_or_text(html_str):
    try:
        import html2text
        h = html2text.HTML2Text()
        h.ignore_links = False
        md = h.handle(html_str)
        return md
    except Exception:
        # fallback to plain text
        soup = BeautifulSoup(html_str, 'lxml')
        text = soup.get_text('\n\n', strip=True)
        return text


def sanitize_filename(title):
    # return a safe base filename (no extension)
    name = re.sub(r'[\\/:*?"<>|]', '', title)
    name = re.sub(r'\s+', '_', name).strip('_')
    if len(name) > 180:
        name = name[:180]
    if not name:
        name = 'untitled'
    return name


def save_article(url):
    try:
        print('Fetching', url)
        # try JS-rendered content first if available
        rendered = render_page_content(url)
        if rendered:
            s = BeautifulSoup(rendered, 'lxml')
        else:
            r = session.get(url, headers=HEADERS, timeout=30)
            r.raise_for_status()
            s = BeautifulSoup(r.text, 'lxml')
    except Exception as e:
        print('  Failed to fetch', url, e)
        return None
    title = title_from_soup(s)
    content_el = extract_content(s)
    body_html = str(content_el)
    md = to_markdown_or_text(body_html)
    slug = url.rstrip('/').split('/')[-1] or 'article'
    base = sanitize_filename(title)
    filename = f"{slug}_{base}.md"
    # avoid overwriting: if exists, append a counter
    meta = extract_metadata(s, url)

    # convert updated HTML to markdown
    body_html = str(content_el)
    md = to_markdown_or_text(body_html)

    # ensure output directory exists
    os.makedirs(OUTDIR, exist_ok=True)

    # write markdown file
    filename = f"{slug}_{base}.md"
    outpath = os.path.join(OUTDIR, filename)
    with open(outpath, 'w', encoding='utf-8') as f:
        f.write('# ' + title + '\n\n')
        f.write('Source: ' + url + '\n\n')
        # include metadata header
        if meta.get('author'):
            f.write(f"Author: {meta['author']}\n\n")
        if meta.get('published'):
            f.write(f"Published: {meta['published']}\n\n")
        if meta.get('tags'):
            f.write('Tags: ' + ', '.join(meta['tags']) + '\n\n')
        f.write(md)

    print('  Saved ->', outpath)
    return outpath


def main():
    ensure_outdir()
    links = gather_listing_links()
    if not links:
        print('No links found on listing page. Exiting.')
        return
    saved = []
    for url in links:
        try:
            p = save_article(url)
            if p:
                saved.append(p)
        except Exception as e:
            print('Error processing', url, e)
        time.sleep(1)
    print('\nDone. Saved', len(saved), 'articles to', OUTDIR)


if __name__ == '__main__':
    main()










