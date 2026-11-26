param([string]$root, [int]$port = 8765)
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$port/")
$l.Start()
while ($l.IsListening) {
  $c = $l.GetContext()
  $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
  $f = Join-Path $root $p
  if ((Test-Path $f -PathType Leaf)) {
    $b = [IO.File]::ReadAllBytes($f)
    if ($f -like '*.html') { $c.Response.ContentType = 'text/html; charset=utf-8' }
    $c.Response.OutputStream.Write($b, 0, $b.Length)
  } else { $c.Response.StatusCode = 404 }
  $c.Response.Close()
}
