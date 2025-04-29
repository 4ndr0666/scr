# mem-police

**mem-police** is a minimalist Linux daemon designed to monitor system memory usage and terminate processes that exceed a specified memory threshold for a sustained period. It operates based on configurable parameters defined in `/etc/mem_police.conf`.

---

## 🛠️ Features

- **Configurable Thresholds**: Define memory usage limits in megabytes.
- **Grace Period**: Set a delay before terminating over-consuming processes.
- **Process Whitelisting**: Exclude specific processes from monitoring.
- **Logging**: Outputs events to standard output for easy logging.
- **Lightweight**: Minimal dependencies, written in C for efficiency.

---

## 📦 Installation

### Prerequisites

- Linux system with `/proc` filesystem.
- C compiler (e.g., `gcc`).
- `make` utility.

### Build and Install

```sh
make
sudo make install
```

This will compile `mem-police` and install it to `/usr/local/bin/mem-police`.

---

## ⚙️ Configuration

Create or edit the configuration file at `/etc/mem_police.conf` with the following parameters:

```ini
THRESHOLD_MB=800
KILL_SIGNAL=15
KILL_DELAY=10
SLEEP=30
WHITELIST=sshd bash
```

- `THRESHOLD_MB`: Memory usage threshold in megabytes.
- `KILL_SIGNAL`: Signal number to send (e.g., 15 for SIGTERM).
- `KILL_DELAY`: Time in seconds to wait before forcefully killing a process.
- `SLEEP`: Interval in seconds between memory checks.
- `WHITELIST`: Space-separated list of process names to exclude.

---

## 🚀 Usage

Start the daemon:

```sh
sudo /usr/local/bin/mem-police
```

To run `mem-police` in the background and log output:

```sh
sudo nohup /usr/local/bin/mem-police > /var/log/mem-police.log 2>&1 &
```

---

## 🧪 Testing

A test script `mem-police-tester.sh` is provided to simulate a high memory usage scenario and verify that `mem-police` responds appropriately.

### Run the Tester

```sh
chmod +x mem-police-tester.sh
./mem-police-tester.sh 800
```

This script will:

1. Start `mem-police` if not already running.
2. Launch a Python process that consumes the specified amount of memory.
3. Monitor for the creation of a start file indicating the process is over the threshold.
4. Wait for the process to be terminated by `mem-police`.

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

---

## 📞 Contact

For issues or feature requests, please open an issue on the [GitHub repository](https://github.com/yourusername/mem-police).

