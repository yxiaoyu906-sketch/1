# 完整当前工程备份

版本：2026-10-05。包含当前Godot源码、Assets全部原始模型贴图与许可、Player、Scripts、scenes、tools，以及Web适配代码和中文字体。未包含可重新生成的.godot缓存、桌面可执行程序或演示视频。

资源备份约538MB，按GitHub文件限制分片保存，游戏运行不会下载这些源码分片。

下载本目录的restore_source.py并运行 `python3 restore_source.py`，脚本会自动下载缺少的分片、逐块校验并恢复history1831_current_source.zip；也可以下载全部分片和清单后在本地运行脚本。解压后用Godot 4.7.2打开Godot/project.godot。

WebAdaptation保留网页使用的Player、Scripts、Fonts和工程/导出配置。网页使用Compatibility和512像素贴图；源码原工程保留原桌面渲染。重新网页导出时需将WebAdaptation对应文件覆盖到工程的独立工作副本，将纹理导入尺寸上限设512，并配置本机的Godot网页导出模板路径。

源文件中的本机用户绝对目录替换为<LOCAL_USER>，不包含API密钥。第三方资源许可与史料来源保留原记录。
