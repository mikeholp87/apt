<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>@LABEL@</title>
<style>
  body { font: 16px/1.5 system-ui, sans-serif; max-width: 46rem; margin: 2rem auto; padding: 0 1rem; }
  pre { background: #f2f2f2; padding: 1rem; overflow-x: auto; border-radius: 6px; }
  @media (prefers-color-scheme: dark) { body { background: #1b1b1f; color: #e6e6e6; } pre { background: #2a2a30; } a { color: #8da9ff; } }
</style>
</head>
<body>
<h1>@LABEL@</h1>
<p>Signed packages. This is a repository, not a web page for people: add it to apt once,
then install anything below and receive updates through <code>apt upgrade</code>.</p>
<pre>sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL @BASE_URL@/apt.asc | sudo tee /etc/apt/keyrings/@KEYNAME@.asc &gt;/dev/null
echo "deb [signed-by=/etc/apt/keyrings/@KEYNAME@.asc] @BASE_URL@/ ./" | sudo tee /etc/apt/sources.list.d/@KEYNAME@.list
sudo apt update</pre>
<h2>Packages</h2>
<ul>
@PACKAGES@
</ul>
</body>
</html>
