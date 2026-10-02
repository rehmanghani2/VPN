# Oracle Cloud (OCI) Always Free VPN Edge Node - Deployment Guide

This guide details how to claim your **100% Free Forever** high-performance WireGuard edge server on Oracle Cloud Infrastructure (OCI) and deploy it automatically using Terraform and Cloud-Init.

---

## 1. Always Free Specifications
- **CPU:** 2 to 4 OCPUs (Ampere Altra A1 ARM64)
- **Memory:** 12 to 24 GB RAM
- **Storage:** 50 to 200 GB NVMe Boot Volume
- **Bandwidth:** **10,000 GB (10 TB) / month free**
- **Public IPv4:** 1x Permanent Static Public IP (Free)
- **Cost:** **$0.00 / month forever**

---

## 2. Step-by-Step: How to Get Your Oracle Cloud API Keys

### Step 2.1: Sign Up for Oracle Cloud Always Free
1. Go to **[https://www.oracle.com/cloud/free/](https://www.oracle.com/cloud/free/)**
2. Click **Start for free**.
3. Select your **Home Region** (e.g., `US East (Ashburn)`, `Germany Central (Frankfurt)`, or `Singapore`).
   > *Note: Choose the location where you want your primary VPN server to reside. The Always Free Ampere shape is provisioned in your Home Region.*
4. Complete registration with your email and card for identity verification ($1 temporary pre-authorization hold, refunded immediately).

---

### Step 2.2: Generate Your API Key (3 Clicks)
1. Log in to the **Oracle Cloud Console** ([cloud.oracle.com](https://cloud.oracle.com)).
2. In the top-right corner, click your **Profile icon** ➜ Click your **Username / Email**.
3. Under the left menu **Resources**, click **API Keys**.
4. Click **Add API Key**:
   - Select **Generate API Key Pair**.
   - Click **Download Private Key** (`.pem` file). Save this file to:
     - Windows: `C:\Users\<YourUser>\.oci\oci_api_key.pem`
     - Linux/macOS: `~/.oci/oci_api_key.pem`
   - Click **Add**.
5. A text box titled **Configuration File Preview** will pop up showing:
   ```ini
   [DEFAULT]
   user=ocid1.user.oc1..aaaaaaaaxxxxxxxxx
   fingerprint=12:34:56:78:9a:bc:de:f0:12:34:56:78:9a:bc:de:f0
   tenancy=ocid1.tenancy.oc1..aaaaaaaaxxxxxxxxx
   region=us-ashburn-1
   ```
6. Copy these 4 values! (Your `user`, `fingerprint`, `tenancy`, and `region`).

---

## 3. Configure Terraform

1. Open the Terraform directory:
   ```bash
   cd infrastructure/terraform/oci
   ```
2. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Edit `terraform.tfvars`:
   ```hcl
   tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaaxxxxxxxxx"
   user_ocid        = "ocid1.user.oc1..aaaaaaaaxxxxxxxxx"
   compartment_ocid = "ocid1.tenancy.oc1..aaaaaaaaxxxxxxxxx" # Same as tenancy_ocid for Root

   fingerprint      = "12:34:56:78:9a:bc:de:f0:12:34:56:78:9a:bc:de:f0"
   private_key_path = "C:/Users/<YourUser>/.oci/oci_api_key.pem"
   region           = "us-ashburn-1"

   # Your local public SSH key for terminal access
   ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@laptop"

   # URL of your central NestJS backend
   backend_api_url  = "http://YOUR_CENTRAL_IP:3000/api/v1"
   ```

---

## 4. Deploy the VPN Edge Node

Run the following commands:

```bash
# 1. Initialize OCI Provider
terraform init

# 2. Review resources to be created (VCN, Subnet, Firewall, Ampere VM)
terraform plan

# 3. Deploy
terraform apply -auto-approve
```

---

## 5. What Happens Automatically on Boot?
The node executes our cloud-init bootstrap script (`node-bootstrap-cloudinit.yaml`):
1. ✅ **Google BBR** TCP congestion control is activated.
2. ✅ **WireGuard Kernel Module** is loaded and listening on UDP port `51820`.
3. ✅ **Unbound DNSSEC Resolver** with Threat Shield is configured on `10.8.0.53:53`.
4. ✅ **Node Agent Daemon** starts on TCP port `51821`.
5. ✅ **Auto-Registration:** The node sends an automated HTTP handshake to your NestJS backend:
   ```http
   POST /api/v1/vpn/nodes/register
   ```
6. ✅ **Instant Availability:** The new server immediately appears in your **Next.js Admin Console** and in the **Flutter App** server list!
