print(r"""<!doctype html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body { font-family: sans-serif; background: #eef3fa; padding: 20px; color: #102440; }
.kartu { background: white; border-radius: 18px; padding: 22px; border-top: 6px solid #ffcf40; }
h1 { color: #143259; font-weight: 900; }
.angka { font-size: 36px; font-weight: 900; color: #b77b00; }
button { background: #ffcf40; border: 0; border-radius: 12px; padding: 14px; font-weight: bold; }
</style></head><body><div class="kartu">
<h1>Smart Campus</h1><p>Huruf <b>tebal</b> dan <i>miring</i>.</p>
<p class="angka">2411015</p><p>Jonathan Christian Wong — IFB5A</p>
<button id="tombol">Klik Saya</button><p id="hasil">Preview siap.</p>
</div><script>
document.getElementById('tombol').onclick = function () {
 document.getElementById('hasil').textContent = 'Berhasil! Interaksi berjalan di WebView Android.';
};
</script></body></html>""")
