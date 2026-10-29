NEXORA AI WEBSITE — ANDROID SETUP

FILES
- index.html: homepage
- features.html: feature page
- about.html: about page
- chat.html: existing NEXORA AI chat app, retaining its current Cloudflare Worker endpoint
- site.css: responsive site styling
- config.js: Android APK download URL setting
- robots.txt and sitemap.xml: SEO files (edit after publishing)

RECOMMENDED FREE HOSTING: GITHUB PAGES
1. Open https://github.com in Chrome on Android and create/sign into an account.
2. Tap +, then New repository. For the simplest address, name it exactly YOUR-USERNAME.github.io (replace YOUR-USERNAME with your GitHub username). Set it Public and create it.
3. Open the new repository, choose Add file > Upload files. Upload the CONTENTS of this folder (not the ZIP itself): index.html, features.html, about.html, chat.html, site.css, config.js, robots.txt, sitemap.xml, and this guide if desired.
4. Commit the upload.
5. Open repository Settings > Pages. Under Build and deployment, choose Deploy from a branch, select main and /(root), then Save.
6. Wait a few minutes and open https://YOUR-USERNAME.github.io . This is a free subdomain; no custom domain purchase is needed.

IMPORTANT BEFORE GOOGLE INDEXING
1. Replace YOUR-SITE-URL in sitemap.xml with your actual published URL, without a trailing slash before page paths.
2. In robots.txt, replace the commented example with: Sitemap: https://YOUR-USERNAME.github.io/sitemap.xml
3. Commit these changes and make sure https://YOUR-USERNAME.github.io/sitemap.xml opens in Chrome.
4. Open https://search.google.com/search-console/ and add a URL-prefix property for your exact https://YOUR-USERNAME.github.io address. Follow Google's verification instructions available for that property.
5. In Search Console, open Sitemaps and submit sitemap.xml.
6. Use URL Inspection on the homepage and click Request indexing. Repeat for features.html and about.html.
7. Google indexing and ranking are not guaranteed or instant. A new site can take days or longer to appear, and nobody can guarantee the first position for “NEXORA AI”. Publish useful original content and link to the website from official social/app pages.

APK DOWNLOAD
1. Upload your own final, tested APK to a trusted public HTTPS download location.
2. Open config.js in a text editor and set apkUrl to the direct public HTTPS download URL, and appVersion to the actual version.
3. Do not use a web page URL that only describes the APK if it is not the direct file download URL. Test the button on Android Chrome.
4. Until apkUrl is set, the download button intentionally shows a note instead of pretending a download exists.

CHECKS BEFORE LAUNCH
- Open chat.html from the deployed website and test sending a message. The chat uses the existing Cloudflare Worker endpoint from the app.
- Test all pages and links on Android Chrome.
- Review privacy practices for your backend before sharing the site widely. Add your contact details and a privacy policy before collecting information from visitors.
- GitHub Pages hosts static files only; the AI replies continue to depend on the existing backend service.
