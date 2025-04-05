# 🧙‍♂️ Ghost CMS One-Click Installer

A powerful and interactive Bash script to install Ghost CMS on any **Ubuntu** server (20.04 or newer) in just a few steps!  
Created with ❤️ by [Ritik Barnwal](https://ritikbarnwal.in)

---

## 🚀 Features

- ✅ Interactive prompts for domain and MySQL credentials
- ✅ Automatic installation of Ghost CLI, Node.js LTS, MySQL, and Nginx
- ✅ Secured SSL setup with Let's Encrypt
- ✅ Ghost service auto-start on boot via systemd
- ✅ Clean installation summary on completion
- ✅ Domain validation built-in (e.g., `example.com`, `blog.example.com`)

---

## 📂 Files

| File Name          | Description                          |
|--------------------|--------------------------------------|
| `ghost-installer.sh` | Main Bash script to install Ghost CMS |

---

## ⚙️ How to Use

### 🛠️ Step 1: Prepare your server

- Use **Ubuntu 20.04+**
- Make sure your domain is pointed to the server’s IP (A record)

### 🧾 Step 2: Download and run the script

```bash
sudo apt install curl -y 
curl -O https://raw.githubusercontent.com/RitikBarnwal/Ghost-CMS-One-Click-Installer/main/ghost-installer.sh
chmod +x ghost-installer.sh
./ghost-installer.sh
```
---

## 👨‍💻 Author

**Ritik Barnwal**  
🚀 Developer • 🛠 Server Admin • 💡 Tech Enthusiast  
🌐 Website: [ritikbarnwal.in](https://ritikbarnwal.in)  
📧 Email: [ritikbarnwal@pm.me](mailto:hello@myserverhelper.com)  
📸 Instagram: [@ritik121sk](https://instagram.com/ritik121sk)  
<!--🐦 Twitter/X: [@ritikbarnwal__](https://twitter.com/ritikbarnwal__)  
💬 LinkedIn: [ritikbarnwal](https://www.linkedin.com/in/ritikbarnwal)-->

### 🙋 Need Help?

If you face any issues or need support, feel free to [open an issue](https://github.com/RitikBarnwal/Ghost-CMS-One-Click-Installer/issues) or contact me directly. I'm happy to help!

---

## 🪄 License

This project is licensed under the [MIT License](LICENSE).

---

> Made with 💻 + ☕ by [Ritik Barnwal](https://ritikbarnwal.in) — Owner of [MyServerHelper](https://myserverhelper.com)
