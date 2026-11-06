# OCI Auto-Retry 🚀

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Automated-blue?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Oracle Cloud](https://img.shields.io/badge/Oracle%20Cloud-Always%20Free-F80000?logo=oracle&logoColor=white)](https://www.oracle.com/cloud/free/)
[![Telegram Notification](https://img.shields.io/badge/Telegram-Notification-2CA5E0?logo=telegram&logoColor=white)](https://telegram.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[🇬🇧 English](README.md) | [🇪🇸 Español](README.es.md)

**OCI Auto-Retry** is an automated, serverless provisioning retry system built on **GitHub Actions** and **Oracle Cloud Infrastructure (OCI) Resource Manager**. It continuously attempts to provision high-demand **Always Free Ampere A1 (ARM)** compute instances whenever capacity becomes available, sends an instant notification to your **Telegram** upon success, and **automatically disables itself** to prevent redundant executions.

---

## 📌 Table of Contents

- [Why This Project?](#why-this-project)
- [How It Works](#how-it-works)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Step-by-Step Setup Guide](#step-by-step-setup-guide)
  - [Step 1: Create a Stack in OCI Resource Manager](#step-1-create-a-stack-in-oci-resource-manager)
  - [Step 2: Generate OCI API Key & Gather Credentials](#step-2-generate-oci-api-key--gather-credentials)
  - [Step 3: Set Up Telegram Notifications (Optional)](#step-3-set-up-telegram-notifications-optional)
  - [Step 4: Configure GitHub Repository Secrets](#step-4-configure-github-repository-secrets)
  - [Step 5: Enable Workflow Permissions in GitHub](#step-5-enable-workflow-permissions-in-github)
  - [Step 6: Triggering the Automation](#step-6-triggering-the-automation)
- [Helper Scripts](#helper-scripts)
- [Troubleshooting & FAQ](#troubleshooting--faq)
- [Security Best Practices](#security-best-practices)
- [License](#license)

---

## 💡 Why This Project?

Oracle Cloud Infrastructure offers one of the most generous free tiers in cloud computing:
- **Ampere A1 Compute (ARM):** Up to 4 OCPUs and 24 GB of RAM (can be 1 instance or divided into up to 4).
- **Storage:** 200 GB of free block volume storage.

However, in many popular data centers (e.g., Madrid, Frankfurt, London, Amsterdam, Ashburn, Phoenix), Ampere A1 instances are frequently out of stock, returning the infamous error:

> `Out of host capacity.` (HTTP 500)

Checking manually by clicking in the OCI Console for days or weeks is exhausting. Running local Python scripts or leaving your PC on 24/7 wastes power and can easily crash.

**OCI Auto-Retry** solves this problem by using **OCI Resource Manager Stacks** (Terraform managed natively by Oracle) and running apply jobs directly through GitHub Actions on an external schedule.

---

## ⚙️ How It Works

1. **Stack Execution:** The GitHub Action invokes `oci resource-manager job create-apply-job` on your pre-configured Stack.
2. **Capacity Check:**
   - If capacity is **unavailable**: The job fails gracefully in OCI, but exits with code `0` in GitHub Actions so runs don't show as broken errors. It simply waits for the next cycle.
   - If capacity is **available**: The Stack succeeds and OCI provisions your VM!
3. **Instant Telegram Alert:** A message is sent directly to your phone via Telegram Bot.
4. **Self-Termination:** The workflow uses GitHub CLI (`gh workflow disable retry.yml`) to automatically disable itself, ensuring no further attempts are made.

---

## 🏗️ Architecture

```mermaid
flowchart TD
    Trigger([Trigger: External Cron / Repository Dispatch / Manual]) --> StartJob[GitHub Actions Runner Starts]
    StartJob --> SetupCLI[Install OCI CLI & Configure Credentials]
    SetupCLI --> ApplyStack[Run 'oci resource-manager job create-apply-job']
    ApplyStack --> CheckState{Apply Job Status?}

    CheckState -->|FAILED / Out of Capacity| LogFail[Log failure cleanly\nExit 0\nWait for next cycle]
    CheckState -->|SUCCEEDED / VM Created| Notify[Send Telegram Notification 🚀]
    
    Notify --> Disable[Disable Workflow via 'gh workflow disable retry.yml']
    Disable --> Done([Instance Running & Done!])
```

---

## 📋 Prerequisites

1. An **Oracle Cloud Infrastructure (OCI)** account ([Sign up here](https://www.oracle.com/cloud/free/)).
2. A **GitHub** account (fork or import this repository).
3. *(Optional)* A **Telegram** account to receive alerts when your instance is created.

---

## 🚀 Step-by-Step Setup Guide

### Step 1: Create a Stack in OCI Resource Manager

An OCI Stack is a Terraform configuration managed directly inside Oracle Cloud.

1. Log into your [Oracle Cloud Console](https://cloud.oracle.com).
2. Go to **Compute** > **Instances** > click **Create instance**.
3. Configure your desired instance:
   - **Name:** Any name (e.g., `ampere-server`).
   - **Placement / Availability Domain:** Choose your availability domain.
   - **Image:** Choose your preferred OS (Ubuntu, Oracle Linux, Debian, etc.).
   - **Shape:** Select **Ampere (ARM)** (`VM.Standard.A1.Flex`) with your desired specs (e.g., 4 OCPUs, 24 GB RAM).
   - **Networking:** Select your VCN and public subnet.
   - **Add SSH keys:** Upload or paste your public SSH key (⚠️ **crucial** so you can log in later!).
   - **Boot volume:** Specify size (up to 200 GB total free across your tenancy).
4. **Do not click "Create" directly.** Instead:
   - At the very bottom of the page, click **Save as stack** (or if you click "Create" and it fails with "Out of host capacity", click the **Save as stack** button that appears).
5. Name your Stack (e.g., `Ampere-Stack`), click **Next**, and then click **Create**.
6. On the Stack details page, find and copy the **OCID** of the stack. It looks like:
   ```text
   ocid1.ormstack.oc1.eu-madrid-1.aaaaaaaa...
   ```
   Save this value — this will be `OCI_STACK_ID`.

---

### Step 2: Generate OCI API Key & Gather Credentials

The workflow requires an API signing key to communicate with OCI.

1. In the OCI Console, click on your **Profile icon** in the top-right corner > **My profile** (or **User Settings**).
2. Scroll down on the left sidebar to **Resources** and click **API Keys**.
3. Click **Add API Key**.
4. Choose **Generate API Key Pair**.
5. Click **Download Private Key** (`.pem` file) and store it securely on your computer.
6. Click **Add**.
7. A dialog titled **Configuration File Preview** will appear. Copy the details shown:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..aaaaaaaaxxx
   fingerprint=xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
   tenancy=ocid1.tenancy.oc1..aaaaaaaaxxx
   region=eu-madrid-1
   key_file=<path to your private keyfile>
   ```

Note these values:
- `user`: Your `OCI_USER`
- `fingerprint`: Your `OCI_FINGERPRINT`
- `tenancy`: Your `OCI_TENANCY`
- `region`: Your `OCI_REGION` (e.g. `eu-madrid-1`, `us-ashburn-1`, `eu-frankfurt-1`)
- Contents of the downloaded `.pem` file: Your `OCI_KEY_FILE`

---

### Step 3: Set Up Telegram Notifications (Optional)

Receive instant mobile notifications the second your instance is provisioned.

1. Open Telegram and search for [`@BotFather`](https://t.me/BotFather).
2. Send `/newbot` and follow the instructions to create a bot.
3. Save the **HTTP API Token** provided (e.g., `7123456789:AAFxxx_yyy_zzz`). This is `TELEGRAM_TOKEN`.
4. Start your bot by clicking the link to your bot and pressing **Start** (`/start`).
5. Obtain your personal **Chat ID**:
   - Message [`@userinfobot`](https://t.me/userinfobot) on Telegram to get your numeric ID (e.g., `123456789`).
   - This value is `TELEGRAM_CHAT_ID`.

---

### Step 4: Configure GitHub Repository Secrets

In your GitHub repository:
1. Navigate to **Settings** > **Secrets and variables** > **Actions**.
2. Click **New repository secret** for each of the following:

| Secret Name | Description | Example / Format |
|---|---|---|
| `OCI_USER` | OCID of your OCI user | `ocid1.user.oc1..aaaaaaaaxxx` |
| `OCI_FINGERPRINT` | Fingerprint of your API key | `2a:1b:3c:4d:...` |
| `OCI_TENANCY` | OCID of your OCI tenancy | `ocid1.tenancy.oc1..aaaaaaaaxxx` |
| `OCI_REGION` | Your OCI region identifier | `eu-madrid-1`, `us-ashburn-1`, etc. |
| `OCI_KEY_FILE` | Entire contents of your private `.pem` file | `-----BEGIN RSA PRIVATE KEY----- ... -----END RSA PRIVATE KEY-----` |
| `OCI_STACK_ID` | OCID of the Resource Manager Stack | `ocid1.ormstack.oc1.eu-madrid-1.aaaa...` |
| `TELEGRAM_TOKEN` | *(Optional)* Telegram Bot API token | `7123456789:AAFxxx...` |
| `TELEGRAM_CHAT_ID` | *(Optional)* Telegram Chat ID | `123456789` |

> [!IMPORTANT]
> When pasting `OCI_KEY_FILE`, paste the **entire file** including the `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` headers and footers with no trailing spaces.

---

### Step 5: Enable Workflow Permissions in GitHub

The workflow needs write permissions to disable itself via `gh workflow disable` once the instance is created.

1. Go to your repository's **Settings** > **Actions** > **General**.
2. Scroll to **Workflow permissions**.
3. Select **Read and write permissions**.
4. Check **Allow GitHub Actions to create and approve pull requests** (if visible).
5. Click **Save**.

---

### Step 6: Triggering the Automation

The workflow is configured with `repository_dispatch` and `workflow_dispatch`.

#### Option A: External Cron via Webhook (Recommended)

Using an external cron service prevents GitHub from automatically disabling scheduled workflows after 60 days of inactivity, and provides reliable timing.

1. **Create a GitHub Personal Access Token (PAT):**
   - In GitHub, go to your personal **Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
   - Click **Generate new token (classic)**.
   - Name: `OCI Auto-Retry Trigger`.
   - Expiration: Choose 90 days or No expiration.
   - Select scopes: `repo` (Full control) or at minimum `actions:write`.
   - Copy the generated token (`ghp_...`).

2. **Set Up a Free Scheduled Webhook (e.g., with [cron-job.org](https://cron-job.org)):**
   - Register for free on [cron-job.org](https://cron-job.org).
   - Create a **New Cronjob**:
     - **Title:** `OCI Retry Trigger`
     - **URL:** `https://api.github.com/repos/<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>/dispatches`
     - **Schedule:** Every 10 or 15 minutes.
     - **Request Method:** `POST`
     - **HTTP Headers:**
       ```text
       Accept: application/vnd.github+json
       Authorization: Bearer ghp_YOUR_GITHUB_PERSONAL_ACCESS_TOKEN
       X-GitHub-Api-Version: 2022-11-28
       ```
     - **Request Body (JSON):**
       ```json
       {"event_type": "lanzar-intento-oci"}
       ```
   - Save the cronjob.

#### Option B: GitHub Actions Built-in Schedule

If you prefer not to use an external cron service, you can edit [`.github/workflows/retry.yml`](.github/workflows/retry.yml) and add the `schedule` block back:

```yaml
on:
  schedule:
    - cron: '*/15 * * * *' # Runs every 15 minutes
  repository_dispatch:
    types: [lanzar-intento-oci]
  workflow_dispatch:
```

> [!NOTE]
> GitHub Actions schedules in public repositories may experience jitter (delays during high global GitHub traffic) and may be paused if the repository has no commits for 60 consecutive days.

#### Option C: Manual Trigger

You can test your setup anytime:
1. Go to the **Actions** tab in your GitHub repository.
2. Select **Reintento Automatico OCI** on the left menu.
3. Click the **Run workflow** dropdown button and confirm.

---

## 🛠️ Helper Scripts

Included in this repository are helper scripts to manually or periodically trigger the workflow dispatch:

- **Bash (Linux / macOS / WSL):**
  ```bash
  chmod +x scripts/trigger.sh
  ./scripts/trigger.sh "YOUR_GITHUB_USERNAME" "oci-auto-retry" "ghp_YOUR_TOKEN"
  ```

- **PowerShell (Windows):**
  ```powershell
  .\scripts\trigger.ps1 -Owner "YOUR_GITHUB_USERNAME" -Repo "oci-auto-retry" -Token "ghp_YOUR_TOKEN"
  ```

You can add `scripts/trigger.sh` to a Linux server or Raspberry Pi `crontab`:
```text
*/15 * * * * /path/to/scripts/trigger.sh "USERNAME" "oci-auto-retry" "TOKEN" >/dev/null 2>&1
```

---

## ❓ Troubleshooting & FAQ

### 1. The job logs "Intento fallido (sin capacidad en la región)"
This is **completely normal**. It means Oracle Cloud does not currently have available Ampere A1 capacity in your Availability Domain. The workflow exits with code `0` to avoid marking runs as failures. It will retry on the next scheduled run.

### 2. Error: `NotAuthenticated` or invalid key
- Ensure you copied the exact private key into `OCI_KEY_FILE`, including:
  ```text
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
  ```
- Verify that `OCI_FINGERPRINT` matches the fingerprint shown in the OCI Console under your user profile.

### 3. Error: `gh workflow disable: Resource not accessible by integration`
- You forgot to grant **Read and write permissions** to GitHub Actions.
- Go to repository **Settings** > **Actions** > **General** > **Workflow permissions** > Select **Read and write permissions** and save.

### 4. How long does it usually take to get an Ampere A1 instance?
Depending on your region, it may take anywhere from a few hours to several days or weeks. Regions like Madrid, Frankfurt, and Ashburn have very high demand, so patience is key.

---

## 🔒 Security Best Practices

- **Never commit credentials:** Never push your `.pem` key, API fingerprints, or Telegram tokens to Git.
- **Repository Visibility:** While the repository itself can be public (since all credentials are stored in encrypted GitHub Secrets), you can also keep your fork **Private** for extra peace of mind.
- **Minimal Permissions:** Always restrict Personal Access Tokens to only the necessary scopes (`actions:write` or `repo`).

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
Feel free to use, modify, and distribute it.
