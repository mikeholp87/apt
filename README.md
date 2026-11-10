# apt repository

Signed flat apt repository, published to GitHub Pages. It is rebuilt from the `.deb`
files attached to every GitHub Release of each project in `projects.txt` (one
`owner/repo` per line; projects must be public).

- Add a project: append its `owner/repo` to `projects.txt` and push to `main`.
- Rebuild now: **Run workflow** on the Actions tab. A nightly run catches the rest.
- The signing key is the repository secret `APT_GPG_PRIVATE_KEY`; the public half is
  `apt.asc`. Changing the key means every user must re-import it, so keep a backup of
  the private key.

Users add the repository with the snippet on the published page.
