# 3DGS Phone Capture Pipeline

这个仓库用于把手机拍摄的一组照片整理成 COLMAP 可处理的数据，并先完成第一阶段目标：

```text
手机照片 -> COLMAP 相机位姿 + 稀疏点云 -> 导出 PLY 点云
```

后续如果要训练 3D Gaussian Splatting，可以把 COLMAP 结果迁移到支持 CUDA 的 Linux/NVIDIA 机器上继续跑。

远端 `lsh-temp` 上已经跑通一次 1000 iteration 的 3DGS 冒烟训练。远端目录、转换命令、训练参数和本地 viewer 打开方式记录在：

```text
docs/lsh_temp_training.md
```

## 目录结构

```text
.
├── README.md
├── scripts/
│   ├── check_env.sh
│   ├── prepare_images.sh
│   ├── run_colmap_sparse.sh
│   └── export_sparse_ply.sh
└── scenes/
    └── <scene_name>/
        ├── raw/       # 原始照片，可选
        ├── images/    # COLMAP 输入照片
        ├── database.db
        └── sparse/    # COLMAP 稀疏重建输出
```

`scenes/` 下的照片、数据库和重建结果默认不进 git。

## 第一次跑

先检查环境：

```bash
./scripts/check_env.sh
```

如果没有 COLMAP，Mac 上通常可以用其中一种方式安装：

```bash
brew install colmap
```

或者：

```bash
conda install -c conda-forge colmap
```

## 准备照片

建议先建一个场景名，例如 `desk`：

```bash
mkdir -p scenes/desk/images
```

把手机拍的 90 张左右照片放进：

```text
scenes/desk/images/
```

如果你的照片在另一个目录，可以用脚本复制/转换到项目里：

```bash
./scripts/prepare_images.sh desk /path/to/your/photos
```

说明：

- JPG/JPEG/PNG 会被复制为连续文件名。
- HEIC/HEIF 会尝试用 macOS 自带的 `sips` 转成 JPEG。
- 如果你从 iPhone 导出，优先导出 JPEG 原图，尽量保留 EXIF。

## 跑 COLMAP 稀疏点云

```bash
./scripts/run_colmap_sparse.sh desk
```

如果要重跑同一个场景：

```bash
./scripts/run_colmap_sparse.sh desk --force
```

默认使用 `sequential_matcher`，适合手机绕场景顺序拍摄的图片。如果照片顺序很乱，可以改用穷举匹配：

```bash
MATCHER=exhaustive ./scripts/run_colmap_sparse.sh desk --force
```

## 导出 PLY 点云

```bash
./scripts/export_sparse_ply.sh desk
```

输出通常在：

```text
scenes/desk/sparse/model_0.ply
```

可以用 CloudCompare、MeshLab 或支持 PLY 的查看器打开。

## 成功标准

COLMAP 成功时你应该能看到：

- 多个小相机图标，表示每张照片的位置和方向。
- 一团彩色 3D 点，大致像你拍摄的场景。
- `scenes/<scene_name>/sparse/0/` 下有 `cameras.bin`、`images.bin`、`points3D.bin`。

如果只有很少图片被注册，或者点云完全不像原场景，通常是照片重叠不足、场景纹理太少、反光/透明物太多，或者拍摄时光照变化太大。

## 拍摄建议

- 60-150 张照片通常够做小场景。
- 相邻照片保持 60%-80% 重叠。
- 围绕目标缓慢移动，不要只原地旋转。
- 避免人、宠物、屏幕、镜子、玻璃、纯白墙。
- 尽量锁定曝光/焦距，避免强 HDR、虚化和夜景模式。
