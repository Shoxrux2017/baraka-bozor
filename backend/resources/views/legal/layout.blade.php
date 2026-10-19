<!doctype html>
<html lang="{{ $language }}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{ $title }} - BarakaBozor</title>
<style>
body{margin:0;background:#fff;color:#151D16;font:16px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:720px;margin:0 auto;padding:24px 16px 48px}
.brand{color:#5AC268;font-weight:700;font-size:20px}
header{display:flex;justify-content:space-between;align-items:center;margin-bottom:24px}
a{color:#2E8B3F}
h1{font-size:26px;line-height:1.25;margin:0 0 4px}
h2{font-size:19px;margin:28px 0 8px}
p,li{margin:0 0 12px}
ul{padding-left:22px;margin:0 0 12px}
.edition{color:#6B776D;font-size:14px;margin:0 0 20px}
</style>
</head>
<body>
<main>
<header>
<span class="brand">BarakaBozor</span>
<a href="{{ $switchUrl }}">{{ $switchName }}</a>
</header>
<h1>{{ $title }}</h1>
@yield('content')
</main>
</body>
</html>
