# Licenças e componentes de terceiros

## UnityCapture DirectShow Filter (somente no Windows, opcional)

Autor: Bernhard Schelling; baseado em UnityCam de MHD Yamen Saraiji.
Fonte: https://github.com/schellingb/UnityCapture
Revisão fixada: `3ed54c325e0ad71afcf4f246c07e5e17b3d7f2d2`

Os arquivos `UnityCaptureFilter32.dll` e `UnityCaptureFilter64.dll` são baixados durante o build e validados pelos respectivos identificadores de blob Git. O LAN Cam OBS não instala nem registra esse componente automaticamente: o registro exige autorização explícita do usuário, por UAC, e permite que o Windows disponibilize uma webcam DirectShow para Google Meet, Zoom e Teams. O filtro é compartilhado pelo sistema e não é desinstalado automaticamente quando o LAN Cam OBS é removido; use o atalho específico para removê-lo antes de desinstalar o aplicativo.

**UnityCaptureFilter — MIT License**

Copyright (c) 2018 Bernhard Schelling

Based on UnityCam — Copyright (c) 2016 MHD Yamen Saraiji

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## QRCode generator

A biblioteca já existente no projeto está em
`public/vendor/qrcode.js` e sua licença acompanha o arquivo
`public/vendor/LICENSE-qrcode-generator.txt`.
