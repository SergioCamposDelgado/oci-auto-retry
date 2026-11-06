# OCI Auto-Retry 🚀

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Automatizado-blue?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Oracle Cloud](https://img.shields.io/badge/Oracle%20Cloud-Always%20Free-F80000?logo=oracle&logoColor=white)](https://www.oracle.com/es/cloud/free/)
[![Notificación Telegram](https://img.shields.io/badge/Telegram-Notificaci%C3%B3n-2CA5E0?logo=telegram&logoColor=white)](https://telegram.org/)
[![Licencia: MIT](https://img.shields.io/badge/Licencia-MIT-yellow.svg)](LICENSE)

[🇬🇧 English](README.md) | [🇪🇸 Español](README.es.md)

**OCI Auto-Retry** es un sistema automatizado de reintentos continuos basado en **GitHub Actions** y **Oracle Cloud Infrastructure (OCI) Resource Manager**. Permite conseguir instancias gratuitas de alta demanda **Always Free Ampere A1 (ARM)** cuando haya capacidad disponible en tu región, te avisa al instante por **Telegram** en cuanto se cree la máquina virtual y **se auto-desactiva** para no seguir consumiendo ejecuciones.

---

## 📌 Tabla de Contenidos

- [¿Por qué este proyecto?](#por-qué-este-proyecto)
- [¿Cómo funciona?](#cómo-funciona)
- [Arquitectura](#arquitectura)
- [Requisitos previos](#requisitos-previos)
- [Guía de configuración paso a paso](#guía-de-configuración-paso-a-paso)
  - [Paso 1: Crear el Stack en OCI Resource Manager](#paso-1-crear-el-stack-en-oci-resource-manager)
  - [Paso 2: Generar API Key de OCI y recopilar credenciales](#paso-2-generar-api-key-de-oci-y-recopilar-credenciales)
  - [Paso 3: Configurar bot de Telegram (Opcional)](#paso-3-configurar-bot-de-telegram-opcional)
  - [Paso 4: Configurar los Secrets en GitHub](#paso-4-configurar-los-secrets-en-github)
  - [Paso 5: Habilitar permisos del Workflow en GitHub](#paso-5-habilitar-permisos-del-workflow-en-github)
  - [Paso 6: Automatizar el lanzamiento (Disparador)](#paso-6-automatizar-el-lanzamiento-disparador)
- [Scripts de ayuda](#scripts-de-ayuda)
- [Preguntas frecuentes y resolución de problemas](#preguntas-frecuentes-y-resolución-de-problemas)
- [Buenas prácticas de seguridad](#buenas-prácticas-de-seguridad)
- [Licencia](#licencia)

---

## 💡 ¿Por qué este proyecto?

Oracle Cloud Infrastructure ofrece uno de los niveles gratuitos ("Always Free") más potentes de la industria:
- **Compute Ampere A1 (ARM):** Hasta 4 OCPUs y 24 GB de memoria RAM (pueden usarse en 1 sola máquina o repartirse en hasta 4 instancias).
- **Almacenamiento:** 200 GB de volumen de bloques gratis en la cuenta.

Sin embargo, en regiones con altísima demanda (como Madrid, Frankfurt, Londres, Ámsterdam, Santiago, etc.), las instancias Ampere A1 casi nunca tienen stock inmediato, mostrando el molesto mensaje:

> `Out of host capacity.` (Capacidad de host insuficiente / Error HTTP 500)

Pasarse días haciendo clic manualmente en la consola de Oracle Cloud es agotador. Mantener un script de Python corriendo 24/7 en tu ordenador local consume electricidad y puede interrumpirse fácilmente.

**OCI Auto-Retry** soluciona esto usando los **Stacks de OCI Resource Manager** (Terraform nativo y gestionado por la propia Oracle) ejecutados automáticamente desde GitHub Actions.

---

## ⚙️ ¿Cómo funciona?

1. **Ejecución del Stack:** GitHub Actions lanza el comando `oci resource-manager job create-apply-job` sobre el Stack que configuraste con tu instancia.
2. **Evaluación de capacidad:**
   - Si **no hay capacidad**: El trabajo falla en OCI, pero el workflow finaliza con código de salida `0` (verde) para no ensuciar tu historial de GitHub con falsos errores y continúa esperando el siguiente ciclo.
   - Si **hay capacidad disponible**: ¡El Stack se aplica con éxito y Oracle Cloud crea tu máquina virtual!
3. **Notificación inmediata por Telegram:** Recibes un mensaje en tu móvil confirmando que la instancia ya está creada y funcionando.
4. **Auto-desactivación:** El workflow utiliza GitHub CLI (`gh workflow disable retry.yml`) para desactivarse a sí mismo, evitando lanzamientos innecesarios posteriores.

---

## 🏗️ Arquitectura

```mermaid
flowchart TD
    Trigger([Disparador: Cron externo / Repository Dispatch / Manual]) --> StartJob[Se inicia el Runner de GitHub Actions]
    StartJob --> SetupCLI[Instalar OCI CLI y configurar credenciales]
    SetupCLI --> ApplyStack[Ejecutar 'oci resource-manager job create-apply-job']
    ApplyStack --> CheckState{¿Estado del Apply Job?}

    CheckState -->|FAILED / Sin capacidad| LogFail[Registrar intento fallido\nSalir con código 0\nEsperar siguiente ciclo]
    CheckState -->|SUCCEEDED / Instancia Creada| Notify[Enviar notificación por Telegram 🚀]
    
    Notify --> Disable[Desactivar flujo con 'gh workflow disable retry.yml']
    Disable --> Done([¡Instancia lista y automatización finalizada!])
```

---

## 📋 Requisitos previos

1. Una cuenta activa en **Oracle Cloud Infrastructure (OCI)** ([Crear cuenta gratuita](https://www.oracle.com/es/cloud/free/)).
2. Una cuenta en **GitHub** (para clonar o hacer fork de este repositorio).
3. *(Opcional)* Una cuenta en **Telegram** si deseas recibir alertas en tiempo real.

---

## 🚀 Guía de configuración paso a paso

### Paso 1: Crear el Stack en OCI Resource Manager

Un Stack en OCI es una plantilla de Terraform gestionada directamente dentro de Oracle Cloud.

1. Inicia sesión en tu consola de [Oracle Cloud](https://cloud.oracle.com).
2. Ve al menú hamburguesa > **Compute** > **Instances** (Instancias) > pulsa en **Create instance** (Crear instancia).
3. Configura la instancia que quieres conseguir:
   - **Nombre:** El que desees (ej. `mi-servidor-arm`).
   - **Availability Domain:** Selecciona tu dominio de disponibilidad.
   - **Imagen:** Selecciona tu sistema operativo preferido (Ubuntu 22.04/24.04, Oracle Linux, etc.).
   - **Shape:** Selecciona **Ampere (ARM)** (`VM.Standard.A1.Flex`) y asigna los recursos deseados (ej. 4 OCPUs y 24 GB RAM, o menos).
   - **Networking:** Selecciona tu VCN y subnet pública.
   - **Add SSH keys:** Sube o pega tu clave SSH pública (⚠️ **imprescindible** para poder conectarte después).
   - **Boot volume:** El tamaño de disco deseado (hasta 200 GB gratuitos en total).
4. **No pulses "Create" directamente.** En su lugar:
   - En la parte inferior de la página, pulsa en el botón **Save as stack** (Guardar como stack). *(Nota: Si pulsaste en "Create" y te dio el error "Out of host capacity", aparecerá igualmente el botón "Save as stack" para aprovechar los datos introducidos)*.
5. Asigna un nombre al Stack (ej. `Stack-Ampere`), haz clic en **Next** y luego en **Create**.
6. En la pantalla del Stack creado, copia el **OCID** del stack. Tendrá un formato similar a:
   ```text
   ocid1.ormstack.oc1.eu-madrid-1.aaaaaaaa...
   ```
   Guarda este dato: será tu secreto `OCI_STACK_ID`.

---

### Paso 2: Generar API Key de OCI y recopilar credenciales

GitHub Actions necesita una clave de API para autenticarse contra tu cuenta de OCI.

1. En la consola de Oracle Cloud, pulsa sobre el **icono de tu perfil** (arriba a la derecha) > **My profile** (Mi perfil) o **User Settings**.
2. En la barra lateral izquierda, baja hasta la sección **Resources** y haz clic en **API Keys** (Claves de API).
3. Haz clic en **Add API Key** (Agregar clave de API).
4. Selecciona la opción **Generate API Key Pair** (Generar par de claves de API).
5. Haz clic en **Download Private Key** (Descargar clave privada, archivo `.pem`) y guárdala a buen recaudo.
6. Pulsa en **Add** (Agregar).
7. Se abrirá una ventana emergente llamada **Configuration File Preview**. Copia los datos que aparecen:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..aaaaaaaaxxx
   fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
   tenancy=ocid1.tenancy.oc1..aaaaaaaaxxx
   region=eu-madrid-1
   key_file=<path to your private keyfile>
   ```

Guarda estos valores:
- `user`: Tu `OCI_USER`
- `fingerprint`: Tu `OCI_FINGERPRINT`
- `tenancy`: Tu `OCI_TENANCY`
- `region`: Tu `OCI_REGION` (ej. `eu-madrid-1`, `us-ashburn-1`, etc.)
- El contenido completo del archivo `.pem` descargado: Tu `OCI_KEY_FILE`

---

### Paso 3: Configurar bot de Telegram (Opcional)

Para recibir un aviso en el móvil en cuanto la instancia se cree con éxito:

1. Abre Telegram y busca al usuario [`@BotFather`](https://t.me/BotFather).
2. Escribe `/newbot` y sigue las instrucciones para asignarle nombre y usuario.
3. Copia el **HTTP API Token** generado (ej. `7123456789:AAFxxx_yyy_zzz`). Este es `TELEGRAM_TOKEN`.
4. Inicia tu nuevo bot buscándolo en Telegram y pulsando en **Iniciar** (`/start`).
5. Obtén tu **Chat ID**:
   - Habla con [`@userinfobot`](https://t.me/userinfobot) en Telegram y te devolverá tu ID numérico (ej. `123456789`).
   - Este número es `TELEGRAM_CHAT_ID`.

---

### Paso 4: Configurar los Secrets en GitHub

En tu repositorio de GitHub:
1. Ve a **Settings** > **Secrets and variables** > **Actions**.
2. Pulsa en **New repository secret** y añade cada una de las siguientes variables:

| Nombre del Secret | Descripción | Ejemplo / Formato |
|---|---|---|
| `OCI_USER` | OCID de tu usuario en Oracle Cloud | `ocid1.user.oc1..aaaaaaaaxxx` |
| `OCI_FINGERPRINT` | Fingerprint de la clave de API | `2a:1b:3c:4d:...` |
| `OCI_TENANCY` | OCID de tu Tenancy en Oracle Cloud | `ocid1.tenancy.oc1..aaaaaaaaxxx` |
| `OCI_REGION` | Identificador de tu región en OCI | `eu-madrid-1`, `us-ashburn-1`, etc. |
| `OCI_KEY_FILE` | Contenido íntegro del archivo privado `.pem` | `-----BEGIN RSA PRIVATE KEY----- ... -----END RSA PRIVATE KEY-----` |
| `OCI_STACK_ID` | OCID del Stack en Resource Manager | `ocid1.ormstack.oc1.eu-madrid-1.aaaa...` |
| `TELEGRAM_TOKEN` | *(Opcional)* Token del bot de Telegram | `7123456789:AAFxxx...` |
| `TELEGRAM_CHAT_ID` | *(Opcional)* Tu ID numérico de Telegram | `123456789` |

> [!IMPORTANT]
> Al pegar `OCI_KEY_FILE`, pega el **archivo completo**, incluyendo las líneas `-----BEGIN RSA PRIVATE KEY-----` y `-----END RSA PRIVATE KEY-----` sin espacios adicionales.

---

### Paso 5: Habilitar permisos del Workflow en GitHub

Para que GitHub Actions pueda auto-desactivar el workflow al finalizar (`gh workflow disable`), necesita permisos de escritura.

1. En tu repositorio, entra en **Settings** > **Actions** > **General**.
2. Baja hasta el apartado **Workflow permissions**.
3. Marca la casilla **Read and write permissions**.
4. Haz clic en **Save**.

---

### Paso 6: Automatizar el lanzamiento (Disparador)

El workflow está configurado por defecto con eventos `repository_dispatch` y `workflow_dispatch`.

#### Opción A: Cron externo vía Webhook (Recomendada)

Utilizar un cron externo evita que GitHub desactive los cronjobs programados si no hay actividad en el repositorio durante 60 días, además de ofrecer mayor puntualidad.

1. **Crear un Personal Access Token (PAT) en GitHub:**
   - En tu cuenta de GitHub, ve a tu avatar > **Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
   - Pulsa **Generate new token (classic)**.
   - Nombre: `OCI Auto-Retry Trigger`.
   - Marca el permiso: `repo` (control total del repo) o como mínimo `actions:write`.
   - Copia el token generado (`ghp_...`).

2. **Configurar un Webhook gratuito (por ejemplo, con [cron-job.org](https://cron-job.org)):**
   - Regístrate gratis en [cron-job.org](https://cron-job.org).
   - Crea un nuevo cronjob (**Create Cronjob**):
     - **Title:** `OCI Retry`
     - **URL:** `https://api.github.com/repos/<TU_USUARIO_GITHUB>/<TU_REPOSITORIO>/dispatches`
     - **Execution schedule:** Cada 10 o 15 minutos (ej. `User-defined` / `Every 15 minutes`).
     - **Request Method:** `POST`
     - **HTTP Headers:**
       ```text
       Accept: application/vnd.github+json
       Authorization: Bearer ghp_TU_TOKEN_PERSONAL_DE_GITHUB
       X-GitHub-Api-Version: 2022-11-28
       ```
     - **Request Body (JSON):**
       ```json
       {"event_type": "lanzar-intento-oci"}
       ```
   - Guarda el cronjob. ¡Listo! Se ejecutará automáticamente según la frecuencia elegida.

#### Opción B: Cron interno de GitHub Actions (Sin servicios externos)

Si prefieres no usar servicios externos, edita el archivo [`.github/workflows/retry.yml`](.github/workflows/retry.yml) y añade el bloque `schedule`:

```yaml
on:
  schedule:
    - cron: '*/15 * * * *' # Se ejecuta cada 15 minutos
  repository_dispatch:
    types: [lanzar-intento-oci]
  workflow_dispatch:
```

> [!NOTE]
> En repositorios públicos de GitHub, los cronjobs nativos pueden tener pequeños retrasos en horas punta y se pausan automáticamente si el repositorio no recibe actividad tras 60 días.

#### Opción C: Lanzamiento manual

Puedes probar la configuración en cualquier momento:
1. Ve a la pestaña **Actions** en tu repositorio.
2. Selecciona **Reintento Automatico OCI** en la columna izquierda.
3. Haz clic en **Run workflow** > botón verde **Run workflow**.

---

## 🛠️ Scripts de ayuda

En la carpeta `scripts/` dispones de herramientas para disparar el evento fácilmente:

- **En Linux / macOS / WSL (Bash):**
  ```bash
  chmod +x scripts/trigger.sh
  ./scripts/trigger.sh "TU_USUARIO_GITHUB" "oci-auto-retry" "ghp_TU_TOKEN"
  ```

- **En Windows (PowerShell):**
  ```powershell
  .\scripts\trigger.ps1 -Owner "TU_USUARIO_GITHUB" -Repo "oci-auto-retry" -Token "ghp_TU_TOKEN"
  ```

Puedes añadir `scripts/trigger.sh` a tu propio servidor Linux o Raspberry Pi en su `crontab`:
```text
*/15 * * * * /ruta/a/scripts/trigger.sh "USUARIO" "oci-auto-retry" "TOKEN" >/dev/null 2>&1
```

---

## ❓ Preguntas frecuentes y resolución de problemas

### 1. El registro muestra "Intento fallido (sin capacidad en la región)"
Es **totalmente normal**. Significa que Oracle Cloud aún no tiene servidores Ampere A1 libres en tu Availability Domain en ese instante. El flujo finaliza con éxito (código 0) para no marcar la ejecución en rojo y lo volverá a intentar en el siguiente ciclo.

### 2. Error: `NotAuthenticated` o clave inválida
- Asegúrate de haber copiado todo el contenido de la clave `.pem` en `OCI_KEY_FILE`, incluyendo las cabeceras:
  ```text
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
  ```
- Comprueba que el fingerprint en `OCI_FINGERPRINT` coincida con el mostrado en la consola de Oracle Cloud.

### 3. Error: `gh workflow disable: Resource not accessible by integration`
- Olvidaste conceder permisos de escritura al workflow.
- Ve a **Settings** > **Actions** > **General** > **Workflow permissions** > Activa **Read and write permissions** y guarda los cambios.

### 4. ¿Cuánto suele tardar en conseguir una máquina?
Varía según la región. En regiones muy demandadas (como Madrid o Frankfurt) puede tardar desde unas pocas horas hasta un par de semanas según las altas y bajas de otros usuarios. La clave es dejarlo actuar en segundo plano con paciencia.

---

## 🔒 Buenas prácticas de seguridad

- **Nunca subas credenciales:** Nunca hagas `git commit` de tus archivos `.pem`, tus claves privadas ni tus tokens.
- **Visibilidad del repositorio:** Aunque el repositorio puede ser público de forma segura (porque las credenciales se almacenan en Secrets cifrados de GitHub), también puedes mantener tu fork en modo **Privado** para mayor tranquilidad.
- **Principio de menor privilegio:** Al crear el Personal Access Token de GitHub, otórgale únicamente los permisos estrictamente necesarios (`actions:write` o `repo`).

---

## 📄 Licencia

Este proyecto está bajo la [Licencia MIT](LICENSE).
Eres libre de usarlo, modificarlo y compartirlo.
