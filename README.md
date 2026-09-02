# 🏍️ OpenCfMoto iOS

**Aplicación nativa en Swift / SwiftUI para proyectar mapas, telemetría y rutas GPX directamente en el cuadro de mandos TFT de motocicletas con sistema Carbit / EasyConnect / MotoPlay.**

Compatible con: **CFMoto** (675SR, 450SR, 450MT, 800NK, 1000 MT-X, 800MT Explore), **Voge** (DS900X, DS800 Rally), **Moto Morini**, **Benelli**, **Zontes**, **QJ Motor** y más.

---

## ✨ Características

- 🗺️ **Proyección de Navegación y HUD**: Velocímetro digital grande, límite de velocidad, flechas de maniobra y brújula.
- ⚡ **Streaming H.264 por Hardware (`VideoToolbox`)**: Latencia ultrabaja a 25 FPS sin consumir batería excesiva.
- 📲 **Escáner QR Automático**: Escaneo del código QR de la pantalla y conexión Wi-Fi automática (`NEHotspotConfigurationManager`).
- 📁 **Rutas GPX**: Importación de archivos `.gpx` y seguimiento de tracks en pantalla.
- 🏍️ **Perfiles de Moto**: Ajuste de resolución y orientación para pantallas horizontales ($800\times384$, $1280\times576$) y verticales ($800\times951$).
- 🔒 **Persistencia con Pantalla Bloqueada**: Modos en segundo plano de localización y audio para mantener la transmisión activa con el iPhone en el bolsillo.

---

## 🏗️ Estructura del Proyecto

```
OpenCfMoto-iOS/
├── Package.swift                     # Definición del Swift Package (iOS 15+, macOS 12+)
├── .github/workflows/build_ios.yml   # Compilación automática en servidores Mac de GitHub
├── Sources/OpenCfMoto/
│   ├── Protocol/                     # Servidor TCP y tramas binarias PXC (10920, 10921, 10922)
│   │   ├── PxcConstants.swift
│   │   ├── PxcFrame.swift
│   │   ├── PxcHandshake.swift
│   │   └── PxcServer.swift
│   ├── Video/                        # Codificación H.264 y renderizado offscreen
│   │   ├── VideoToolboxEncoder.swift
│   │   └── VirtualDisplayRenderer.swift
│   ├── Navigation/                   # Telemetría GPS, rutas y GPX
│   │   ├── DashHUDViewModel.swift
│   │   └── GpxParser.swift
│   ├── Models/                       # Perfiles de motos y parser QR
│   │   ├── BikeProfile.swift
│   │   └── QrParser.swift
│   └── UI/                           # Vistas completas en SwiftUI
│       ├── AppRootView.swift
│       ├── MainDashboardView.swift
│       ├── LiveDashPreviewView.swift
│       ├── QRScannerView.swift
│       ├── RouteManagerView.swift
│       └── GarageView.swift
├── Tests/OpenCfMotoTests/            # Tests unitarios del protocolo
└── tools/                            # Emulador mock en Python para pruebas
    ├── mock_dashboard.py
    └── test_protocol.py
```

---

## 🧪 Pruebas con el Emulador Mock (En tu PC)

Para probar la conexión y recepción de video sin necesidad de estar en la moto:

1. Ejecuta el emulador en una terminal:
   ```bash
   python tools/mock_dashboard.py
   ```
2. Desde la app, pulsa **"Probar con Emulador Mock (PC)"**. El emulador recibirá el apretón de manos y comenzará a recibir los fotogramas H.264 en tiempo real.
