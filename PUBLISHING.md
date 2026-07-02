# Publishing The Notes Website

This repository now has a static notes website at the root:

- `index.html`
- `styles.css`
- `app.js`
- `notes-data.js`

Refresh the website data after editing notes:

```bash
python3 tools/build_notes_data.py
```

Preview locally:

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000`.

Free hosting options:

1. GitHub Pages: push this repo to GitHub, open repository settings, enable Pages from the main branch root.
2. Netlify: drag the repository folder into Netlify Drop or connect the GitHub repo.
3. Cloudflare Pages: connect the GitHub repo and set the build command to `python3 tools/build_notes_data.py`; leave the output directory as `/`.
