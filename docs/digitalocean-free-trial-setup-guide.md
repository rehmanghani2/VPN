# DigitalOcean ($200 Free Trial) Multi-Region VPN Setup Guide

Deploy a globally distributed WireGuard VPN server cluster across **4 continents (New York, Frankfurt, Singapore, London)** in under 3 minutes using DigitalOcean's **$200 Free Trial Credit** and Terraform.

---

## 1. What You Get with DigitalOcean Free Trial
- **$200 Free Credit** valid for 60 days.
- **4 Global Edge Nodes** deployed simultaneously:
  - 🇺🇸 **US East (New York)**: Low latency North America routing
  - 🇩🇪 **Europe (Frankfurt)**: Anti-DPI Stealth camouflage node
  - 🇸🇬 **Asia-Pacific (Singapore)**: Ultra-fast Asia gateway
  - 🇬🇧 **UK (London)**: Privacy & streaming bypass node
- **1,000 GB to 4,000 GB free monthly bandwidth**.
- **Automated WireGuard, BBR Congestion Control & Node Agent auto-registration**.

---

## 2. Step 1: Claim Your $200 Credit & Get Your API Token

### 2.1 Sign Up
1. Go to **[https://www.digitalocean.com/](https://www.digitalocean.com/)** (or click any free \$200 referral link).
2. Create an account with your email or GitHub/Google.
3. Your account will be credited with **\$200 free credit**.

---

### 2.2 Generate Your Personal Access Token (`DO_TOKEN`) in 30 Seconds
1. In the DigitalOcean Control Panel, look at the left sidebar menu and click **API**.
2. Under the **Tokens** tab, click the blue button: **Generate New Token**.
3. Fill in:
   - **Token name:** `antigravity-vpn-deployer`
   - **Expiration:** 60 Days (or custom)
   - **Scopes:** Select **Full Access** (Read & Write)
4. Click **Generate Token**.
5. Copy the generated token string (starts with `dop_v1_...`). Save it!

---

## 3. Step 2: Configure Terraform

1. Open your terminal in the DigitalOcean Terraform directory:
   ```powershell
   cd e:\Projects\VPN\infrastructure\terraform\digitalocean
   ```
2. Copy the example credentials file:
   ```powershell
   copy terraform.tfvars.example terraform.tfvars
   ```
3. Edit `terraform.tfvars`:
   ```hcl
   # 1. Paste your DigitalOcean Personal Access Token
   do_token = "dop_v1_your_actual_token_here"

   # 2. Paste your local SSH Public Key
   # (If you don't have one, generate with: ssh-keygen -t rsa -b 4096)
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@machine"

   # 3. URL where your NestJS backend is reachable from the internet
   backend_api_url = "http://YOUR_CENTRAL_IP:3000/api/v1"
   ```

---

## 4. Step 3: Deploy with Terraform

Run:

```powershell
# 1. Initialize DigitalOcean Provider plugin
terraform init

# 2. Preview the 4 droplets and firewall rules
terraform plan

# 3. Deploy all 4 global nodes simultaneously
terraform apply -auto-approve
```

---

## 5. What Happens Automatically on Boot?

Within **90 seconds**, all 4 droplets boot and run `node-bootstrap-cloudinit.yaml`:
1. 🚀 **Kernel Tuning:** Google BBR TCP congestion control is activated.
2. 🔒 **WireGuard Data Plane:** WireGuard listens on UDP `51820`.
3. 🛡️ **DNS Threat Shield:** Unbound local resolver boots on `10.8.0.53:53` with malware and ad blocking.
4. 📡 **Node Agent Synchronization:** Node Agent starts on TCP `51821`.
5. 🤝 **Automated Backend Self-Registration:** Each droplet automatically fires an HTTP registration call to your NestJS backend:
   - `New York (US)` ➜ Registers automatically
   - `Frankfurt (DE)` ➜ Registers automatically
   - `Singapore (SG)` ➜ Registers automatically
   - `London (GB)` ➜ Registers automatically
6. 📱 **Live Everywhere:** The 4 servers will instantly light up in:
   - **Your Next.js Web Admin Console** (`/servers` page)
   - **Your Flutter Mobile App** (Available in the server drawer/list with ping latency indicators)

---

## 6. How to Tear Down (When Done Testing)

When you are done testing or before the 60-day trial ends:
```powershell
terraform destroy -auto-approve
```
This terminates all droplets cleanly with zero lingering costs.
