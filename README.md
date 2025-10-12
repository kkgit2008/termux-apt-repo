
# 一键检查yaml语法
- https://www.yamllint.com

原仓名 termux-apt-repo



# ⚠️以下内容与此仓库无关！

# 

# deb-simpl 自建apt本地服务器简易教程: 

在安卓手机上本地部署 `deb-simple` ，尤其适合在没有电脑的情况下，或者在移动环境中快速搭建一个临时的 APT 仓库。

这个方案主要依赖于 **Termux** 应用。Termux 是一个在 Android 上提供 Linux 环境的终端模拟器，它让你可以像在 Linux 服务器上一样执行命令、安装软件。

---

### 目录

1.  **准备工作：安装 Termux**
2.  **在 Termux 中安装必要工具**
3.  **下载并运行 deb-simple**
4.  **上传 .deb 包到仓库**
5.  **在本地设备上使用仓库**
6.  **在局域网内其他设备上使用仓库**
7.  **管理和后台运行**
8.  **总结与注意事项**

---

### 1. 准备工作：安装 Termux

1.  **下载 Termux**: 强烈建议从 F-Droid 应用商店下载 Termux，因为 Google Play 上的版本已经不再维护。
    *   访问 F-Droid 官网: [https://f-droid.org/](https://f-droid.org/)
    *   下载并安装 F-Droid 客户端。
    *   在 F-Droid 中搜索 "Termux" 并安装。

2.  **初始化 Termux**: 第一次打开 Termux，它会自动配置基本环境。建议先运行更新命令：
    ```bash
    pkg update && pkg upgrade
    ```

### 2. 在 Termux 中安装必要工具

我们需要 `wget` (用于下载文件) 和 `curl` (用于上传 `.deb` 包)。
```bash
pkg install wget curl
```

### 3. 下载并运行 deb-simple

`deb-simple` 是一个静态编译的 Go 程序，我们可以直接下载它的 ARM 架构版本（因为大多数现代安卓手机都使用 ARM 处理器）。

1.  **确定手机架构**: 在 Termux 中运行 `uname -m`。
    *   如果输出是 `aarch64`，你需要下载 `arm64` 版本。
    *   如果输出是 `armv7l`，你需要下载 `arm` 版本。
    现代手机几乎都是 `aarch64`。

2.  **下载最新版本的 deb-simple**:
    访问 `deb-simple` 的 GitHub Releases 页面 ([https://github.com/metacubex/deb-simple/releases](https://github.com/metacubex/deb-simple/releases))，找到最新版本，然后复制对应架构的下载链接。

    假设最新版本是 `v0.1.0`，并且你的手机是 `aarch64`：
    ```bash
    # 下载 arm64 版本
    wget https://github.com/metacubex/deb-simple/releases/download/v0.1.0/deb-simple-linux-arm64
    ```

3.  **重命名并赋予执行权限**:
    ```bash
    # 重命名为更简单的名字
    mv deb-simple-linux-arm64 deb-simple

    # 赋予执行权限
    chmod +x deb-simple
    ```

4.  **运行 deb-simple**:
    我们让它监听所有网络接口的 `8080` 端口，并将仓库数据保存在一个名为 `repo` 的目录中。
    ```bash
    ./deb-simple -listen :8080 -storage ./repo
    ```
    现在，`deb-simple` 服务已经在你的手机上启动了！

### 4. 上传 .deb 包到仓库

现在你需要将 `.deb` 文件上传到 `deb-simple`。

1.  **将 .deb 文件传输到手机**:
    *   **最简单的方法**: 通过手机浏览器下载 `.deb` 文件，它通常会保存在 `/storage/emulated/0/Download/` 目录下。
    *   **其他方法**: 使用数据线将文件复制到手机的 "下载" 文件夹。

2.  **在 Termux 中访问文件**:
    Termux 可以通过 `/sdcard/` 目录访问手机的公共存储空间。
    ```bash
    # 列出下载文件夹中的文件
    ls /sdcard/Download/
    ```
    确认你的 `.deb` 文件（例如 `my-app_1.0_amd64.deb`）在这个列表中。

3.  **使用 curl 上传**:
    假设你要上传到为 `bullseye` 发行版和 `amd64` 架构准备的仓库。

    **注意**: 因为我们没有设置密码 (`-auth`)，所以可以省略 `-u` 参数。
    ```bash
    curl -X POST \
         -F "file=@/sdcard/Download/my-app_1.0_amd64.deb" \
         http://localhost:8080/upload/bullseye/amd64/
    ```
    上传成功后，`deb-simple` 会自动处理并创建索引。你可以在 `repo/` 目录下看到生成的 `dists` 和 `pool` 结构。

### 5. 在本地设备上使用仓库

现在，你的安卓手机既是服务器又是客户端。你可以在 Termux 中使用 `apt` 来安装你上传的包。

1.  **安装 apt**: Termux 默认使用 `pkg`，但它底层是基于 `apt` 的。我们可以直接安装 `apt` 工具。
    ```bash
    pkg install apt
    ```

2.  **添加仓库源**:
    创建一个 sources.list 文件。
    ```bash
    # 使用 nano 编辑器创建文件
    nano $PREFIX/etc/apt/sources.list.d/my-local-repo.list
    ```
    在文件中添加以下内容，然后按 `Ctrl+X`，再按 `Y` 保存退出。
    ```
    deb [trusted=yes] http://localhost:8080/ bullseye main
    ```
    *   `[trusted=yes]` 是必须的，因为我们的仓库没有 GPG 签名。
    *   `bullseye` 必须与你上传时指定的发行版一致。

3.  **更新并安装**:
    ```bash
    # 更新 apt 缓存
    apt update

    # 安装你的软件包
    apt install my-app
    ```
    现在，你的应用就应该被安装到 Termux 环境中了！

### 6. 在局域网内其他设备上使用仓库

这才是这个方案的强大之处！你的安卓手机可以作为一个仓库服务器，为同一 Wi-Fi 网络下的其他 Debian/Ubuntu 设备提供软件包。

1.  **获取手机的局域网 IP 地址**:
    *   **方法一 (推荐)**: 在 Termux 中运行 `ip addr show wlan0`，查找 `inet` 后面的 IP 地址（例如 `192.168.1.105`）。
    *   **方法二**: 在手机的 "设置" -> "Wi-Fi" -> 点击已连接网络旁边的齿轮图标，查看 "IP 地址"。

2.  **在其他设备上配置**:
    在你的电脑或其他 Debian/Ubuntu 设备上，创建源文件。
    ```bash
    # 在电脑上打开终端
    sudo nano /etc/apt/sources.list.d/android-repo.list
    ```
    添加以下内容，将 `<手机的IP地址>` 替换为你刚刚查到的地址。
    ```
    deb [trusted=yes] http://<手机的IP地址>:8080/ bullseye main
    ```

3.  **更新并安装**:
    在电脑上运行：
    ```bash
    sudo apt update
    sudo apt install my-app
    ```
    现在，电脑就会从你的安卓手机上下载并安装软件包！

### 7. 管理和后台运行

*   **后台运行**: 直接运行 `./deb-simple ...` 会占用当前的 Termux 窗口。你可以使用 `nohup` 和 `&` 让它在后台运行。
    ```bash
    nohup ./deb-simple -listen :8080 -storage ./repo &
    ```
    这样即使你关闭 Termux 窗口，服务也能继续运行（但可能会被系统内存管理杀死）。

*   **停止服务**: 如果是前台运行，直接按 `Ctrl+C`。如果是后台运行，需要先找到进程 ID。
    ```bash
    # 查找进程 ID
    ps aux | grep deb-simple
    # 假设输出的 PID 是 12345
    kill 12345
    ```

*   **开机自启**: Termux 提供了 `termux-boot` 插件可以实现开机自启脚本，但配置稍复杂，对于临时使用来说，手动启动通常足够了。

### 8. 总结与注意事项

*   **优点**:
    *   **高度便携**: 你的安卓手机变成了一个移动的软件包服务器。
    *   **设置简单**: 相比在 Linux 服务器上配置，Termux 提供了一个非常轻量的环境。
    *   **用途广泛**: 非常适合在没有中央服务器的小型团队、现场演示或离线环境中分发软件。

*   **注意事项**:
    *   **性能**: 手机的 CPU 和内存资源有限，同时服务多个客户端可能会有性能瓶颈。
    *   **稳定性**: Android 系统可能会在内存不足时杀死后台的 Termux 进程，导致服务中断。
    *   **网络**: 此方案依赖 Wi-Fi 网络，手机热点功能也可以实现，但会消耗更多电量。
    *   **安全性**: 我们使用了 `[trusted=yes]` 并且没有设置上传密码，这只适用于完全可信的内部环境。

通过这个方法，你已经成功地将安卓手机变成了一个功能完备的本地 APT 仓库！
