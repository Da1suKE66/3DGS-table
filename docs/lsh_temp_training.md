# lsh-temp 3DGS Training Notes

This note records the remote training setup used for the desk scene. It keeps
large/private artifacts out of Git while preserving the commands and parameters
needed to reproduce the run.

## Remote Storage Layout

`/workspace/llc` is the lightweight working entrypoint. Large files live under
`/cache/llc`.

```text
/workspace/llc/data   -> /cache/llc/data
/workspace/llc/output -> /cache/llc/output
/workspace/llc/repos  -> /cache/llc/repos
```

Current remote scene paths:

```text
/cache/llc/data/desk_3dgs
/cache/llc/output/desk_smoke_1000
/cache/llc/repos/gaussian-splatting
/cache/llc/venvs/gaussian_splatting
```

Large artifacts are intentionally ignored by Git:

```text
raw phone photos
converted scene images
COLMAP database and sparse/dense outputs
Gaussian Splatting .ply files
training checkpoints
local viewer installs
```

## Input Data Shape

The official 3D Gaussian Splatting repository expects a COLMAP-style scene.
The scene contains images plus COLMAP's recovered camera parameters and sparse
point cloud.

```text
desk_3dgs/
  input/                  # original JPG images for the 3DGS conversion step
  distorted/
    database.db
    sparse/0/
      cameras.bin         # camera intrinsics
      images.bin          # camera extrinsics / poses
      points3D.bin        # COLMAP sparse points
```

The camera parameters do not need to be typed in manually. COLMAP estimates
them from the photos and writes them into `cameras.bin` and `images.bin`.

## COLMAP Result Used

Local COLMAP reconstruction summary:

```text
registered images: 89 / 89
sparse points: 17760
mean reprojection error: about 1.13 px
```

The low-memory COLMAP settings used locally were:

```bash
COLMAP_MAX_IMAGE_SIZE=1600
COLMAP_FEATURE_THREADS=1
COLMAP_MATCH_THREADS=2
COLMAP_MAX_NUM_FEATURES=4096
```

## Convert To 3DGS Format

On `lsh-temp`:

```bash
cd /cache/llc/repos/gaussian-splatting
source /cache/llc/venvs/gaussian_splatting/bin/activate

python convert.py \
  -s /cache/llc/data/desk_3dgs \
  --skip_matching \
  --no_gpu
```

This creates the undistorted 3DGS scene structure:

```text
/cache/llc/data/desk_3dgs/images
/cache/llc/data/desk_3dgs/sparse/0
```

## Smoke Training Command

The first successful training run was a 1000-iteration smoke test:

```bash
cd /cache/llc/repos/gaussian-splatting
source /cache/llc/venvs/gaussian_splatting/bin/activate

CUDA_VISIBLE_DEVICES=0 python train.py \
  -s /cache/llc/data/desk_3dgs \
  -m /cache/llc/output/desk_smoke_1000 \
  -r 4 \
  --data_device cpu \
  --iterations 1000 \
  --save_iterations 1000 \
  --test_iterations 1000 \
  --checkpoint_iterations 1000 \
  --disable_viewer
```

Important parameters:

```text
-s
  Input scene directory: images plus COLMAP sparse model.

-m
  Output directory for Gaussian splats, checkpoints, cameras, and config.

-r 4
  Train at 1/4 image resolution. This is faster and lighter for large phone
  images. Try -r 2 later for better quality if GPU memory and time are fine.

--data_device cpu
  Keep image data on CPU memory instead of loading it all onto the GPU.

--iterations 1000
  Smoke-test length. Use 7000 or 30000 for a more meaningful result.

--disable_viewer
  Do not start the remote real-time viewer. The model is viewed locally later.
```

Smoke-test output:

```text
initialized Gaussian points: 17760
train PSNR at iteration 1000: about 21.27
output size: about 59M
```

Key output files:

```text
/cache/llc/output/desk_smoke_1000/cameras.json
/cache/llc/output/desk_smoke_1000/chkpnt1000.pth
/cache/llc/output/desk_smoke_1000/input.ply
/cache/llc/output/desk_smoke_1000/point_cloud/iteration_1000/point_cloud.ply
```

## Continue Training

To continue from the 1000-iteration checkpoint to 7000 iterations:

```bash
cd /cache/llc/repos/gaussian-splatting
source /cache/llc/venvs/gaussian_splatting/bin/activate

CUDA_VISIBLE_DEVICES=0 python train.py \
  -s /cache/llc/data/desk_3dgs \
  -m /cache/llc/output/desk_smoke_1000 \
  -r 4 \
  --data_device cpu \
  --iterations 7000 \
  --start_checkpoint /cache/llc/output/desk_smoke_1000/chkpnt1000.pth \
  --save_iterations 7000 \
  --test_iterations 7000 \
  --checkpoint_iterations 7000 \
  --disable_viewer
```

## Local Free-View Viewer

The local viewer uses SuperSplat Viewer:

```text
/Users/doc66/Desktop/Code/3DGS/viewers/supersplat-viewer
```

The 1000-iteration model was copied locally to:

```text
/Users/doc66/Desktop/Code/3DGS/scenes/desk/gaussian/iteration_1000/point_cloud.ply
```

The viewer is served locally with:

```bash
cd /Users/doc66/Desktop/Code/3DGS/viewers/supersplat-viewer
./node_modules/.bin/serve public -C -c ../serve.json -l tcp://127.0.0.1:3017
```

Open:

```text
http://127.0.0.1:3017/?content=./scenes/desk_1000.ply&settings=./settings.json
```

Controls:

```text
left drag: rotate
scroll / trackpad: zoom
fullscreen button: enter fullscreen
```
