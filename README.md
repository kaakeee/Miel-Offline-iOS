# 🎓 Miel Offline iOS

**Miel Offline** es una aplicación nativa para iOS diseñada específicamente para los estudiantes de la **Universidad Nacional de La Matanza (UNLaM)**. Su propósito es facilitar el acceso y la descarga de materiales de estudio desde la plataforma MIEL (Materias Interactivas En Línea), permitiendo visualizar videos, clases, PDFs y apuntes sin necesidad de una conexión constante a internet.

## 🎥 Demo en Acción

<p align="center">
  <video src="https://github.com/kaakeee/Miel-Offline-iOS/raw/main/assets/demo.mp4" width="250" controls></video>
</p>

## ✨ Características Principales

- **Navegación Integrada**: Explora el campus virtual de MIEL directamente desde la app de manera segura, manteniendo tu sesión iniciada siempre.
- **Auto-descarga Inteligente**: La app detecta automáticamente cuando reproduces un video de una clase o abres un PDF y lo descarga en segundo plano.
- **Carpetas por Materia**: Todos tus apuntes y videos descargados se organizan automáticamente en carpetas separadas según la materia a la que pertenecen, de forma 100% inteligente y transparente.
- **Nombres Contextuales**: Olvídate de los archivos con nombres genéricos. El sistema extrae el título exacto de la clase desde la plataforma web para nombrar tus descargas.
- **Control de Duplicados**: Si intentas descargar una clase o apunte que ya tienes guardado, la app bloquea la descarga para ahorrar tus datos móviles y te permite abrir la copia local instantáneamente.
- **Integración con iOS**: Todos los archivos se guardan en el "Sandbox" de la app. Además, puedes acceder a ellos desde la app nativa de **Archivos (Files)** de tu iPhone bajo la carpeta `En mi iPhone > Miel Offline`.
- **Modo Oscuro / Claro**: Total compatibilidad con la interfaz de iOS.

## 🛠️ Tecnologías Utilizadas

- **SwiftUI**: Interfaz de usuario declarativa, moderna y fluida.
- **WebKit (WKWebView)**: Motor de navegación embebido para inyectar Javascript, interceptar tráfico y manejar descargas sin perder la sesión (Cookies).
- **QuickLook Framework**: Previsualización nativa de archivos PDF, Word, PowerPoint y videos.
- **Gestión de Archivos (FileManager)**: Almacenamiento local persistente y organizado.

## 🚀 Requisitos

- iOS 16.0 o superior.
- Xcode 15.0 o superior (para compilar el proyecto).
- Cuenta activa de alumno en MIEL UNLaM.

## 📱 Instalación (Para Desarrolladores)

1. Clona este repositorio en tu Mac:
   ```bash
   git clone https://github.com/kaakeee/Miel-Offline-iOS.git
   ```
2. Abre el archivo `Miel Offline.xcodeproj` con Xcode.
3. Selecciona tu iPhone o un Simulador en la parte superior.
4. Presiona el botón de **Play** (▶️) o usa el atajo `Cmd + R` para compilar y ejecutar.

## 💡 Ideas a futuro (Roadmap)
- Recordatorios de parciales leídos desde el calendario del campus.
- Sincronización en iCloud para tener los archivos en el iPad.

---
*Hecho por y para estudiantes. Este proyecto no tiene afiliación oficial con la Universidad Nacional de La Matanza.*
