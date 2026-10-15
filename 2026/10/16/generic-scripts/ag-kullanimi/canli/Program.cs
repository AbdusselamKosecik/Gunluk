// Anlık ağ kullanımı: çekirdek ETW TCP/UDP olaylarını uygulama × ağ bazında toplar, http://localhost:8765 üzerinden sunar.
// Yönetici olarak çalışmalı (app.manifest requireAdministrator).
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net;
using System.Net.NetworkInformation;
using System.Text;
using System.Text.Json;
using Microsoft.Diagnostics.Tracing.Parsers;
using Microsoft.Diagnostics.Tracing.Session;

const int Port = 8765;
const string OturumAdi = "AgCanliKernel";

var izleyici = new Izleyici();
var aglar = new AgHaritasi();
aglar.Yenile();
using var agZamanlayici = new Timer(_ => aglar.Yenile(), null, TimeSpan.FromSeconds(10), TimeSpan.FromSeconds(10));
using var saniye = new Timer(_ => izleyici.SaniyeKapat(), null, TimeSpan.FromSeconds(1), TimeSpan.FromSeconds(1));

TraceEventSession.GetActiveSession(OturumAdi)?.Stop(true);
using var oturum = new TraceEventSession(OturumAdi) { StopOnDispose = true };
oturum.EnableKernelProvider(KernelTraceEventParser.Keywords.NetworkTCPIP);
var k = oturum.Source.Kernel;
// Kernel TcpIp olaylarında saddr/daddr bağlantı demetidir; yerel olan, makinenin IP'leriyle eşleşen taraftır.
k.TcpIpRecv += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: true, aglar);
k.TcpIpSend += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: false, aglar);
k.TcpIpRecvIPV6 += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: true, aglar);
k.TcpIpSendIPV6 += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: false, aglar);
k.UdpIpRecv += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: true, aglar);
k.UdpIpSend += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: false, aglar);
k.UdpIpRecvIPV6 += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: true, aglar);
k.UdpIpSendIPV6 += d => izleyici.Ekle(d.ProcessID, d.size, d.saddr, d.daddr, d.dport, gelen: false, aglar);
var etw = Task.Run(() => oturum.Source.Process());

var dinleyici = new HttpListener();
dinleyici.Prefixes.Add($"http://localhost:{Port}/");
dinleyici.Start();
Console.WriteLine($"Anlık ağ panosu: http://localhost:{Port}/  (kapatmak için bu pencereyi kapatın veya Ctrl+C)");
Process.Start(new ProcessStartInfo($"http://localhost:{Port}/") { UseShellExecute = true });
Console.CancelKeyPress += (_, e) => { e.Cancel = true; dinleyici.Stop(); };

var json = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
var sayfa = Path.Combine(AppContext.BaseDirectory, "wwwroot", "index.html");
while (dinleyici.IsListening)
{
    HttpListenerContext c;
    try { c = await dinleyici.GetContextAsync(); } catch { break; }
    _ = Task.Run(async () =>
    {
        try
        {
            var yol = c.Request.Url!.AbsolutePath;
            byte[] govde; string tur;
            if (yol == "/api/anlik") { govde = JsonSerializer.SerializeToUtf8Bytes(izleyici.Ozet(aglar), json); tur = "application/json"; }
            else if (yol == "/api/uygulama") { govde = JsonSerializer.SerializeToUtf8Bytes(izleyici.Detay(c.Request.QueryString["ad"] ?? ""), json); tur = "application/json"; }
            else { govde = await File.ReadAllBytesAsync(sayfa); tur = "text/html; charset=utf-8"; }
            c.Response.ContentType = tur;
            c.Response.Headers["Cache-Control"] = "no-store";
            await c.Response.OutputStream.WriteAsync(govde);
        }
        catch (Exception ex) { c.Response.StatusCode = 500; Console.WriteLine(ex.Message); }
        finally { c.Response.Close(); }
    });
}
oturum.Stop();
await etw;

/// <summary>Yerel IP → (ağ adı, tür). Wi-Fi için bağlı SSID kullanılır.</summary>
sealed class AgHaritasi
{
    private volatile Dictionary<IPAddress, (string Ad, string Tur)> _ipler = new();
    public ConcurrentDictionary<string, string> Turler { get; } = new();

    public void Yenile()
    {
        var ssid = WifiSsid();
        var yeni = new Dictionary<IPAddress, (string, string)>();
        foreach (var n in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (n.OperationalStatus != OperationalStatus.Up || n.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
            var (ad, tur) = n.NetworkInterfaceType switch
            {
                NetworkInterfaceType.Wireless80211 => (ssid.GetValueOrDefault(n.Name) ?? n.Name, "Wi-Fi"),
                NetworkInterfaceType.Ethernet or NetworkInterfaceType.GigabitEthernet => (n.Name, n.Description.Contains("Hyper-V") ? "Sanal" : "Ethernet"),
                _ => (n.Name, n.Description.Contains("Tailscale") || n.Description.Contains("WireGuard") || n.Description.Contains("VPN") ? "VPN" : "Diğer"),
            };
            foreach (var a in n.GetIPProperties().UnicastAddresses)
                yeni[a.Address] = (ad, tur);
        }
        _ipler = yeni;
    }

    public (string Ad, string Tur)? Bul(IPAddress ip) => _ipler.TryGetValue(ip, out var x) ? x : null;

    private static Dictionary<string, string> WifiSsid()
    {
        var sonuc = new Dictionary<string, string>();
        try
        {
            var p = Process.Start(new ProcessStartInfo("netsh", "wlan show interfaces")
            { RedirectStandardOutput = true, UseShellExecute = false, CreateNoWindow = true, StandardOutputEncoding = Encoding.UTF8 })!;
            string? ad = null;
            foreach (var satir in p.StandardOutput.ReadToEnd().Split('\n'))
            {
                var parca = satir.Split(':', 2);
                if (parca.Length != 2) continue;
                var (anahtar, deger) = (parca[0].Trim(), parca[1].Trim());
                if (anahtar == "Name") ad = deger;
                else if (anahtar == "SSID" && ad is not null) sonuc[ad] = deger;
            }
        }
        catch { /* Wi-Fi yoksa boş */ }
        return sonuc;
    }
}

sealed class Uygulama(string ad, string yol)
{
    public const int Pencere = 120;   // son 120 saniye
    public string Ad { get; } = ad;
    public string Yol { get; } = yol;
    public long Ind, Yuk;                                  // başlangıçtan beri
    public long AnlikInd, AnlikYuk;                        // şu anki saniye (henüz kapanmadı)
    public readonly long[] SeriInd = new long[Pencere], SeriYuk = new long[Pencere];
    public readonly Dictionary<string, long[]> Ag = new();
    public readonly Dictionary<string, long> Uzak = new();
}

sealed class Izleyici
{
    private readonly object _kilit = new();
    private readonly Dictionary<string, Uygulama> _uyg = new(StringComparer.OrdinalIgnoreCase);
    private readonly ConcurrentDictionary<int, (string Ad, string Yol)> _pid = new();
    private readonly long[] _topInd = new long[Uygulama.Pencere], _topYuk = new long[Uygulama.Pencere];
    private long _anlikInd, _anlikYuk;
    private int _imlec;                                    // halka tamponda en son kapanan saniye
    private readonly DateTime _baslangic = DateTime.Now;

    private (string Ad, string Yol) Surec(int pid) => _pid.GetOrAdd(pid, p =>
    {
        if (p == 4) return ("System", "Çekirdek");
        try
        {
            using var pr = Process.GetProcessById(p);
            string yol;
            try { yol = pr.MainModule?.FileName ?? ""; } catch { yol = ""; }
            return (pr.ProcessName + (pr.ProcessName.EndsWith(".exe") ? "" : ".exe"), yol);
        }
        catch { return ($"PID {p}", ""); }
    });

    public void Ekle(int pid, int boyut, IPAddress s, IPAddress d, int dport, bool gelen, AgHaritasi aglar)
    {
        if (IPAddress.IsLoopback(s) && IPAddress.IsLoopback(d)) return;
        var yerel = aglar.Bul(s);
        var uzak = d;
        if (yerel is null && aglar.Bul(d) is { } y2) { yerel = y2; uzak = s; }
        // Yerel adresi makineye ait olmayanlar çoğunlukla çoklu yayın/yayın paketleri (SSDP, mDNS, cihaz keşfi).
        var (agAd, agTur) = yerel ?? (YayinMi(s) || YayinMi(d) ? ("Yerel ağ (yayın)", "Diğer") : ("Bilinmeyen", "Diğer"));
        aglar.Turler[agAd] = agTur;
        var (ad, yol) = Surec(pid);

        lock (_kilit)
        {
            if (!_uyg.TryGetValue(ad, out var u)) _uyg[ad] = u = new Uygulama(ad, yol);
            if (!u.Ag.TryGetValue(agAd, out var a)) u.Ag[agAd] = a = new long[2];
            if (gelen) { u.Ind += boyut; u.AnlikInd += boyut; a[0] += boyut; _anlikInd += boyut; }
            else { u.Yuk += boyut; u.AnlikYuk += boyut; a[1] += boyut; _anlikYuk += boyut; }
            var anahtar = $"{uzak}:{dport}";
            u.Uzak[anahtar] = u.Uzak.GetValueOrDefault(anahtar) + boyut;
        }
    }

    private static bool YayinMi(IPAddress ip)
    {
        if (ip.IsIPv6Multicast || ip.IsIPv6LinkLocal || ip.Equals(IPAddress.Any) || ip.Equals(IPAddress.IPv6Any)) return true;
        var b = ip.GetAddressBytes();
        return b.Length == 4 && (b[0] >= 224 || b[3] == 255 || (b[0] == 169 && b[1] == 254));
    }

    /// <summary>Her saniye: anlık sayaçları halka tampona yazar.</summary>
    public void SaniyeKapat()
    {
        lock (_kilit)
        {
            _imlec = (_imlec + 1) % Uygulama.Pencere;
            _topInd[_imlec] = _anlikInd; _topYuk[_imlec] = _anlikYuk;
            _anlikInd = _anlikYuk = 0;
            foreach (var u in _uyg.Values)
            {
                u.SeriInd[_imlec] = u.AnlikInd; u.SeriYuk[_imlec] = u.AnlikYuk;
                u.AnlikInd = u.AnlikYuk = 0;
            }
        }
    }

    private long[][] Seri(long[] ind, long[] yuk) =>
        Enumerable.Range(1, Uygulama.Pencere).Select(i => { var j = (_imlec + i) % Uygulama.Pencere; return new[] { ind[j], yuk[j] }; }).ToArray();

    /// <summary>Son 3 saniyenin ortalaması (bayt/sn).</summary>
    private long[] Hiz(long[] ind, long[] yuk)
    {
        long a = 0, b = 0;
        for (var i = 0; i < 3; i++) { var j = (_imlec - i + Uygulama.Pencere) % Uygulama.Pencere; a += ind[j]; b += yuk[j]; }
        return [a / 3, b / 3];
    }

    public object Ozet(AgHaritasi aglar)
    {
        lock (_kilit)
        {
            return new
            {
                Baslangic = _baslangic,
                Zaman = DateTime.Now,
                Aglar = aglar.Turler,
                Hiz = Hiz(_topInd, _topYuk),
                Seri = Seri(_topInd, _topYuk),
                Uygulamalar = _uyg.Values.Select(u => new
                {
                    u.Ad, u.Yol,
                    Hiz = Hiz(u.SeriInd, u.SeriYuk),
                    Top = new[] { u.Ind, u.Yuk },
                    Ag = u.Ag.OrderByDescending(x => x.Value[0] + x.Value[1]).ToDictionary(x => x.Key, x => x.Value),
                }).ToList(),
            };
        }
    }

    public object? Detay(string ad)
    {
        lock (_kilit)
        {
            if (!_uyg.TryGetValue(ad, out var u)) return null;
            return new
            {
                u.Ad, u.Yol,
                Hiz = Hiz(u.SeriInd, u.SeriYuk),
                Top = new[] { u.Ind, u.Yuk },
                Ag = u.Ag.OrderByDescending(x => x.Value[0] + x.Value[1]).ToDictionary(x => x.Key, x => x.Value),
                Seri = Seri(u.SeriInd, u.SeriYuk),
                Uzak = u.Uzak.OrderByDescending(x => x.Value).Take(15).Select(x => new { Adres = x.Key, Bayt = x.Value }),
            };
        }
    }
}
