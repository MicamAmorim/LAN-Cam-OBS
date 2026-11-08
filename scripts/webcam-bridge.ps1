# Ponte Windows para enviar os quadros JPEG locais a um filtro DirectShow.
# Usa apenas Windows PowerShell 5.1 e .NET Framework (sem Python, Node extra ou OBS).
$ErrorActionPreference = 'Stop'
if (-not $env:LAN_CAM_PORT -or -not $env:LAN_CAM_KEY) { throw 'Configuração local ausente.' }
$source = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.IO.MemoryMappedFiles;
using System.Net.WebSockets;
using System.Threading;
using System.Runtime.InteropServices;

public static class LanCamWebcamBridge
{
    const int MaxFrameBytes = 1600000;
    static MemoryMappedFile map;
    static MemoryMappedViewAccessor accessor;
    static Mutex mutex;
    static EventWaitHandle sent;

    static bool Attach()
    {
        if (accessor != null) return true;
        try
        {
            map = MemoryMappedFile.OpenExisting("UnityCapture_Data", MemoryMappedFileRights.Write);
            accessor = map.CreateViewAccessor(0, 0, MemoryMappedFileAccess.Write);
            mutex = Mutex.OpenExisting("UnityCapture_Mutx");
            sent = EventWaitHandle.OpenExisting("UnityCapture_Sent");
            return true;
        }
        catch { Detach(); return false; }
    }
    static void Detach()
    {
        if (accessor != null) accessor.Dispose();
        if (map != null) map.Dispose();
        if (mutex != null) mutex.Dispose();
        if (sent != null) sent.Dispose();
        accessor = null; map = null; mutex = null; sent = null;
    }
    static void PutFrame(byte[] jpeg)
    {
        // O filtro só cria a memória compartilhada quando um aplicativo abre a câmera.
        if (!Attach()) return;
        try
        {
            using (var input = new MemoryStream(jpeg))
            using (var picture = Image.FromStream(input, false, true))
            {
                int w = Math.Min(1280, picture.Width), h = (int)Math.Round(picture.Height * (double)w / picture.Width);
                if (h > 720) { h = 720; w = (int)Math.Round(picture.Width * (double)h / picture.Height); }
                w = Math.Max(4, w & ~3); h = Math.Max(2, h);
                using (var bitmap = new Bitmap(w, h, PixelFormat.Format32bppArgb))
                {
                    using (var g = Graphics.FromImage(bitmap))
                    {
                        g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.Bilinear;
                        g.DrawImage(picture, 0, 0, w, h);
                    }
                    var bits = bitmap.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                    byte[] rgba = new byte[w * h * 4];
                    try
                    {
                        for (int y = 0; y < h; ++y)
                            Marshal.Copy(IntPtr.Add(bits.Scan0, y * bits.Stride), rgba, y * w * 4, w * 4);
                    }
                    finally { bitmap.UnlockBits(bits); }
                    // Bitmap retorna BGRA; UnityCapture interpreta os dados como RGBA.
                    for (int i = 0; i < rgba.Length; i += 4)
                    {
                        byte b = rgba[i]; rgba[i] = rgba[i + 2]; rgba[i + 2] = b;
                    }
                    bool locked = false;
                    try
                    {
                        try { locked = mutex.WaitOne(150); }
                        catch (AbandonedMutexException) { locked = true; }
                        if (!locked) return;
                        if (accessor.ReadInt32(0) < rgba.Length) return;
                        accessor.Write(4, w);
                        accessor.Write(8, h);
                        accessor.Write(12, w);
                        accessor.Write(16, 0); // UINT8 RGBA
                        accessor.Write(20, 1); // redimensionar para a resolução solicitada
                        accessor.Write(24, 0); // sem espelhamento
                        accessor.Write(28, 1200);
                        accessor.WriteArray<byte>(32, rgba, 0, rgba.Length);
                    }
                    finally { if (locked) mutex.ReleaseMutex(); }
                    sent.Set();
                }
            }
        }
        catch (FileNotFoundException) { Detach(); }
        catch (UnauthorizedAccessException) { Detach(); }
        catch (ObjectDisposedException) { Detach(); }
        catch (IOException) { Detach(); }
        catch (ArgumentException) { /* imagem inválida: ignorar quadro */ }
    }
    public static void Run(string port, string key)
    {
        if (String.IsNullOrWhiteSpace(port) || String.IsNullOrWhiteSpace(key)) return;
        var uri = new Uri("ws://127.0.0.1:" + port + "/signal?role=webcam&key=" + Uri.EscapeDataString(key));
        while (true)
        {
            try
            {
                using (var socket = new ClientWebSocket())
                {
                    socket.ConnectAsync(uri, CancellationToken.None).GetAwaiter().GetResult();
                    byte[] buf = new byte[MaxFrameBytes];
                    using (var data = new MemoryStream())
                    {
                        while (socket.State == WebSocketState.Open)
                        {
                            data.SetLength(0);
                            WebSocketReceiveResult packet;
                            do
                            {
                                packet = socket.ReceiveAsync(new ArraySegment<byte>(buf), CancellationToken.None)
                                    .GetAwaiter().GetResult();
                                if (packet.MessageType == WebSocketMessageType.Close) return;
                                if (data.Length + packet.Count > MaxFrameBytes)
                                    throw new InvalidDataException("Quadro grande demais.");
                                data.Write(buf, 0, packet.Count);
                            }
                            while (!packet.EndOfMessage);
                            if (packet.MessageType == WebSocketMessageType.Binary)
                                PutFrame(data.ToArray());
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Console.Error.WriteLine("Webcam bridge: " + e.Message);
                Thread.Sleep(1200);
                Detach();
            }
        }
    }
}
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies @('System.dll', 'System.Drawing.dll', 'System.Core.dll')
[LanCamWebcamBridge]::Run($env:LAN_CAM_PORT, $env:LAN_CAM_KEY)
