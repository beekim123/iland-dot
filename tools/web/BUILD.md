# Web 导出

在仓库根目录运行（Python 3，无第三方 Python 依赖）：

```sh
GODOT_BIN=/absolute/path/Godot_v4.7.2-stable_linux.x86_64 \
GODOT_WEB_TEMPLATE=/absolute/path/web_nothreads_release.zip \
python3 tools/web/export.py
```

仅接受已校验 SHA512 的官方 4.7.2 单线程 release 模板。构建复制 godot/ 到 build/web/staging-*，不修改桌面渲染/音频设置：Web 特性使用 Stream playback；启用 ETC2/ASTC 导入满足 Web 移动纹理校验。保留所有 runtime resources 及 raw JSON/许可说明。字体和 WAV 通过 Godot 正常导入资源打包，不重复附原始 WAV。

输出 build/web/sunny-shell-island-web.zip 与同名解压目录。ZIP 测试及 SHA256 写入 export-manifest.json；每个文件 SHA256 在包内 build-manifest.json。source-manifest.json 是源输入的逐文件哈希，git SHA 仅为基线（未提交导出修复会明确标注）。Web 浏览器运行能力须另外验证。

staging 供独立 QA 与资源比对，完成后可删除整个 build/web/staging-*；均被 .gitignore 排除。运行包不含这些目录。GODOT-LICENSE.txt 是该官方二进制 Engine.get_license_text/get_copyright_info/get_license_info 直接导出的完整许可通知。
