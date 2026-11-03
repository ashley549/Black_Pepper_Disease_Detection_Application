# Model files

## mobilenetv1_v2_float32.tflite (bundled with the app)

- Source: v2 clean-rebuild training notebook (`Mobilenetv1_v2_clean.ipynb`),
  exported from Colab as `mobilenetv1_v2.tflite`; copied here and renamed
  `mobilenetv1_v2_float32.tflite`.
- Architecture: MobileNetV1, float32 (not quantized).
- Input: `[1, 224, 224, 3]` float32, RGB, normalised `(pixel - 127.5) / 127.5`
  (matches training's `mobilenet.preprocess_input`).
- Output: `[1, 4]` float32 softmax probabilities in this class order:
  `0=Healthy, 1=Leaf_blight, 2=Slow_decline, 3=Yellow_mottle_virus`
  (`assets/labels/labels.txt` must keep this exact order).
- SHA-256: `f21f1451b5ab64a002f13cdd317bc9a1a5ef0543de6cf7c2c8008b97e59e9f9e`
  (12,818,568 bytes). Use this to confirm any copy — Drive, local or bundled —
  is the same file.
- Replaces the retired v1 `pepper_model.tflite`
  (`07b2f824a7d51ac22e20aea0f5027ba56aac44c97668795c2cd5a56a90403ddb`), which
  had learned a background-style shortcut (pale image → Yellow_mottle_virus).
  v2 was trained with a data audit, stronger brightness/contrast augmentation
  and val_accuracy checkpoint selection to fix that.

## Verification vs the Keras model (`mobilenetv1_v2.keras`)

Run `python tools/tflite_probe/bin/parity_check.py <image> [keras_model.keras]`
to re-verify on-device-style preprocessing against the model. The converted
file was evaluated directly in the notebook (Keras vs TFLite agreement check)
before export, so the shipped artifact is the measured one.
