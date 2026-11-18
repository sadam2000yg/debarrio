# D'BARRIO — Plataforma de Comercio Colaborativo y Mercado de Barrio Digital

**D'BARRIO** es una aplicación móvil desarrollada en **Flutter** y respaldada por **Supabase** que conecta a **Vecinos** (compradores locales) con **Emprendedores y Negocios de Barrio** (puestos de comida, salteñerías, abarrotes, artesanías, etc.).

---

## 🚀 Características Principales

* 🔄 **Doble Rol Dinámico (`VECINO` / `EMPRENDEDOR`):** Cambia entre el rol de comprador y vendedor desde una sola cuenta.
* 📍 **Búsqueda Geográfica por Radio GPS:** Muestra los negocios y puestos abiertos más cercanos según las coordenadas GPS del vecino.
* 🛡️ **Verificación de Identidad KYC:** Proceso de registro con subida de Selfie, foto de Fachada de residencia/puesto, y C.I. Anverso y Reverso.
* 📦 **Gestión de Inventarios Especializados:**
  * `DIARIO_PERECEDERO`: Comidas y productos frescos del día (se reinician al cerrar el puesto).
  * `RECURRENTE`: Abarrotes y víveres estándar.
  * `UNICO`: Artesanías y piezas exclusivas.
* 📱 **Pago por QR Simple:** Métodos de pago descentralizados mediante transferencia directa entre bancos locales.
* 📋 **Comanda en Vivo:** Panel interactivo para el emprendedor con actualización de estados del pedido (`PENDIENTE` ➔ `EN_PREPARACION` ➔ `LISTO` ➔ `ENTREGADO`).

---

## 🛠️ Tecnologías Utilizadas

* **Frontend:** Flutter ^3.13.7 / Dart
* **State Management:** Provider ^6.1.2
* **Backend & Autenticación:** Supabase (PostgreSQL, Supabase Auth, Supabase Storage)
* **Mapas & GPS:** `flutter_map`, `latlong2`, `geolocator`
* **Almacenamiento Seguro:** `flutter_secure_storage`
* **Carga de Imágenes:** `image_picker`, `cached_network_image`

---

## 📦 Requisitos Previos

1. **Flutter SDK:** ^3.13.7 instalado y configurado en el PATH.
2. **Android Studio / VS Code** con las extensiones de Flutter y Dart.
3. **Cuenta de Supabase:** Proyecto creado en Supabase con las credenciales `SUPABASE_URL` y `SUPABASE_ANON_KEY`.

---

## ⚡ Instalación y Configuración

### 1. Clonar el Repositorio
```bash
git clone https://github.com/TU_USUARIO/d_barrio.git
cd d_barrio
```

### 2. Instalar Dependencias
```bash
flutter pub get
```

### 3. Configuración de Supabase
Asegúrate de contar con las variables de entorno o configurar las credenciales predeterminadas en `lib/main.dart`:

```dart
await Supabase.initialize(
  url: const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yazcljvhigeojtjletfb.supabase.co',
  ),
  publishableKey: const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'TU_SUPABASE_ANON_KEY',
  ),
);
```

---

## 📱 Ejecución y Compilación

### Modo Desarrollo (Debug)
```bash
flutter run
```

### Compilar APK en Release (con variables de entorno)
```bash
flutter clean; flutter pub get; flutter build apk --release \
  --dart-define=SUPABASE_URL=https://yazcljvhigeojtjletfb.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

El binario generado se ubicará en:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📂 Estructura del Proyecto

```text
lib/
├── core/
│   ├── theme/          # Estilos globales y paleta de colores (Material 3)
│   ├── utils/          # Validadores y utilidades de prueba
│   └── widgets/        # UI Kit (Botones, campos de texto, notificaciones)
├── features/
│   ├── auth/           # Login, Registro KYC y AuthProvider
│   ├── carrito/        # Carrito de Compras y pantalla Mis Compras
│   ├── comanda/        # Comanda en tiempo real para Emprendedores
│   ├── explorar/       # Búsqueda geográfica, mapa y escaparate de puestos
│   ├── negocio/        # Gestión de catálogo, productos y configuración del puesto
│   └── profile/        # Perfil de usuario, cambio de rol y cuadrícula KYC
├── services/
│   ├── location_service.dart  # Geolocalización GPS
│   └── storage_service.dart   # Subida de imágenes a Supabase Storage
└── main.dart           # Punto de entrada principal y enrutador dinámico
```

---

## 🔗 Vincular a tu Repositorio de GitHub

Si aún no has vinculado tu proyecto local a tu cuenta de GitHub, ejecuta los siguientes comandos en tu consola:

```bash
git remote add origin https://github.com/TU_USUARIO/d_barrio.git
git branch -M main
git add .
git commit -m "Initial commit: D'BARRIO App con Supabase, KYC y mapa"
git push -u origin main
```
