# Cymatics Lab — 設計ドキュメント

## 1. 概要 / ゴール

Cymatics Lab は、トラック分離済みの楽曲を入力として、数式ベースのパターンを音楽に連動させて生成・合成するビジュアライゼーションツール。

### 何をするか

- GLSL シェーダによる数式パターン生成（フラクタル、SDFレイマーチング、ストレンジアトラクタ等）
- 万華鏡などのポストエフェクト
- 複数レイヤーのスタック合成（ON/OFF・順序入れ替え可能）
- ステム別音声特徴量を任意のシェーダ uniform にバインド
- ライブプレビュー（音声と同期、シェーダ・シーンのホットリロード）
- mp4 動画書き出し

### 何をしないか

- 音楽自体の生成（楽曲は外部で作成・ステム分離済み前提）
- 自動的なステム分離（Demucs 等は別途実行する前提）
- リアルタイム配信機能

## 2. アーキテクチャ概観

### レイヤースタックモデル

```
[Layer 0: 背景生成]      → FBO_0 ─┐
[Layer 1: フラクタル]    → FBO_1 ─┼→ Composite → 画面 / mp4
[Layer 2: アトラクタ点群] → FBO_2 ─┤
[Layer 3: 万華鏡(post)]   → FBO_3 ─┘
                ↑
       Audio Features (毎フレーム)
       ─ stem.drums.onset
       ─ stem.bass.rms
       ─ stem.melody.pitch
       ...
```

各レイヤーは「入力 (任意の前段FBO) → 自分のFBOへ描画」という統一インターフェースを持つ。生成系もエフェクト系も同じ箱に入る。レイヤーの順序入れ替え・有効/無効はランタイムで変更可能。

### データフロー

```
楽曲 (stem別 .wav)
  │
  ├─[事前解析: numpy/scipy]──→ features.npz (時刻インデックス付き特徴量)
  │
  └─[再生: sounddevice]───────→ playback_time
                                     │
                                     ▼
                          features.npz を時刻でlookup
                                     │
                                     ▼
                  [変換オペレータ] (smooth/threshold/decay/...)
                                     │
                                     ▼
                       各 Layer の uniform へ送信
                                     │
                                     ▼
                  Shader → FBO → Composite → 画面 / mp4
```

音声と映像の同期は `sounddevice` のコールバックから取得する再生サンプル位置を真実の時刻とする（描画ループの時計は信用しない）。

### 主要コンポーネント

| コンポーネント | 責務 |
|---|---|
| `LayerStack` | レイヤーの順序・有効無効・FBO 割当・合成 |
| `AudioPlayer` | 音声再生 + 現在再生位置の供給 |
| `FeatureCache` | 事前解析済み特徴量の時刻ルックアップ |
| `Binding` | 特徴量 → 変換オペレータ → uniform のマッピング |
| `SceneLoader` | TOML からの読込・ホットリロード |

## 3. レイヤーの種類

| 種類 | 役割 | 入力 | 出力 |
|---|---|---|---|
| **Generator** | 数式から絵を作る | uniform のみ | FBO (RGBA) |
| **Particle/Curve** | 点群・曲線を描く | uniform / バッファ | FBO (RGBA) |
| **Effect** | 前段 FBO を変形 | 前段 FBO + uniform | FBO (RGBA) |
| **Composite** | 2 つの FBO を合成 | 下段 FBO + 上段 FBO | FBO (RGBA) |

### Generator 例

- つぶやき GLSL 風フラクタル（西辻スタイル）
- SDF レイマーチング
- 反応拡散 (Gray-Scott、ping-pong FBO)
- ノイズフィールド (Perlin / Simplex / ドメインワーピング)
- マンデルブロ / ジュリア集合

### Particle/Curve 例

- ストレンジアトラクタ (Lorenz, Clifford, de Jong, Aizawa)
- リサジュー曲線
- ハーモノグラフ
- L-system / IFS

### Effect 例

- 万華鏡（UV 極座標化 → 楔形折り返し）
- ブルーム / グロー
- 色収差
- フィードバック残像
- 歪み（バレル / ピンクッション）

### Composite ブレンドモード

`normal (alpha)` / `add` / `screen` / `multiply` / `overlay` / `replace`

## 4. 音声バインディング 3 層モデル

```
[特徴量抽出] → [変換オペレータ] → [uniform バインド]
  音 → 数値    数値の整形・整流   シェーダの何を動かすか
```

### Layer A: 特徴量

ステム別に取得（`stem.<name>.<feature>`）／全体ミックスからも取得可（`total.<feature>`）。

| 特徴量 | 意味 | 用途例 |
|---|---|---|
| `rms` | 音量 (エネルギー) | 全体スケール、明度 |
| `peak` | 瞬間最大値 | キックの強さ |
| `band(low/mid/high)` | 帯域別エネルギー | 帯域マッピング |
| `onset` | 立ち上がり (0/1 のパルス) | カット切替、粒子バースト |
| `onset_density` | 直近 N 秒のオンセット数 | 盛り上がり度 |
| `pitch` | 基音 (Hz / MIDI) | 色相、形状 |
| `centroid` | スペクトル重心 | 明るさ、キラキラ度 |
| `flux` | スペクトル変化量 | 動きの激しさ |

### Layer B: 変換オペレータ

| 演算 | 動作 |
|---|---|
| `scale(a, b)` | 線形変換 `a*x + b` |
| `map([lo,hi] → [lo',hi'])` | 範囲変換 |
| `smooth(τ)` | 指数移動平均ローパス（ガクつき除去） |
| `threshold(t)` | 閾値超えで 1, 以下で 0 |
| `gate(t, hold)` | 閾値超えから hold 秒だけ 1 を維持 |
| `decay(τ)` | 上昇は瞬時、下降は時定数 τ で減衰 |
| `accumulate` | 値を積分（オンセット累計など） |

オペレータはチェーン可能。

### Layer C: uniform へのバインド

各レイヤーは「動かせる口」（公開 uniform）を予め定義する。シーン TOML で `特徴量 + オペレータ → uniform 名` を宣言的に対応付ける。代表的なバインド例：

| レイヤー | 公開 uniform | おすすめ音源 |
|---|---|---|
| Nishitsuji フラクタル | 反復回数, ドメイン歪み量, 時間スケール, 色相 | bass.rms→歪み、melody.pitch→色相 |
| 万華鏡 | 分割数 N, 中心オフセット, 回転角 | drums.onset→分割数、time→回転 |
| ストレンジアトラクタ | パラメータ a,b,c,d, 描画速度 | melody.pitch→a, pad.centroid→b |
| 反応拡散 | feed 率, kill 率, 時間ステップ | pad.rms→feed |
| ブルーム | 強度, 半径 | total.rms→強度 |

## 5. シーン記述 (TOML スキーマ)

### 例

```toml
[scene]
song       = "songs/song01"
fps        = 60
resolution = [1920, 1080]

[[layers]]
name   = "fractal"
type   = "shader"
source = "shaders/generators/nishitsuji.glsl"
blend  = "normal"
[layers.uniforms]
t    = { source = "time" }
warp = { source = "stem.bass.rms",     smooth = 0.1, map = [0, 1, 0.5, 3.0] }
hue  = { source = "stem.melody.pitch", map    = [40, 80, 0.0, 1.0] }

[[layers]]
name  = "particles"
type  = "attractor"
kind  = "clifford"
blend = "screen"
[layers.uniforms]
a = { source = "stem.pad.centroid" }
b = { value  = 1.7 }

[[layers]]
name   = "kaleido"
type   = "effect"
source = "shaders/effects/kaleidoscope.glsl"
blend  = "replace"
[layers.uniforms]
segments = { source = "stem.drums.onset", accumulate = true, map = [0, 100, 6, 24] }
rotation = { source = "time", scale = 0.05 }
```

### フィールド定義

#### `[scene]`

| フィールド | 型 | 意味 |
|---|---|---|
| `song` | string | ステム wav を置いたディレクトリ |
| `fps` | int | フレームレート |
| `resolution` | [int, int] | 出力解像度 [幅, 高] |

#### `[[layers]]` 共通

| フィールド | 型 | 意味 |
|---|---|---|
| `name` | string | 一意なレイヤー名 |
| `type` | string | `shader` / `attractor` / `effect` |
| `blend` | string | `normal` / `add` / `screen` / `multiply` / `overlay` / `replace` |
| `enabled` | bool | デフォルト `true` |

#### type 別の追加フィールド

| type | 追加フィールド |
|---|---|
| `shader` | `source` (path) — フラグメントシェーダのパス |
| `attractor` | `kind` (string) — `clifford` / `lorenz` / `de_jong` / `aizawa` |
| `effect` | `source` (path) — エフェクトシェーダのパス |

#### `[layers.uniforms]` の各値

固定値の場合：

```toml
b = { value = 1.7 }
```

音声特徴量バインドの場合：

```toml
warp = { source = "stem.bass.rms", smooth = 0.1, map = [0, 1, 0.5, 3.0] }
```

- `source`: `time` / `stem.<name>.<feature>` / `total.<feature>` のいずれか
- `scale`, `map`, `smooth`, `threshold`, `gate`, `decay`, `accumulate` は任意で組合せ可能

## 6. 技術スタック

| 役割 | ライブラリ | 補足 |
|---|---|---|
| GL / シェーダ | `moderngl` | FBO・uniform・テクスチャ管理 |
| ウィンドウ | `moderngl-window` または `glfw` | 前者は moderngl 専用で楽 |
| 音声再生 | `sounddevice` | 低レイテンシ、再生サンプル位置取得 |
| 音声デコード | `soundfile` | wav / flac / ogg |
| 解析 | `numpy`, `scipy.signal` | FFT / オンセット / RMS |
| シーン記述 | 標準 `tomllib` + `pydantic` | TOML 読込 + スキーマ検証 |
| ホットリロード | `watchdog` | shaders / と scene.toml を監視 |
| GUI | `imgui-bundle` | プレビュー上にオーバーレイ表示 |
| 動画書き出し | `ffmpeg` (subprocess) | 各フレームをパイプ送出 |

## 7. ディレクトリ構成

```
cymatics-lab/
├── README.md
├── CLAUDE.md                    # 開発ロードマップ・運用メモ
├── docs/
│   └── design.md                # このファイル
├── shaders/
│   ├── lib/                     # 共有関数 (hash, hsv, sdf, ...)
│   ├── generators/
│   │   ├── nishitsuji.glsl
│   │   ├── reaction_diffusion.glsl
│   │   └── raymarch_sdf.glsl
│   └── effects/
│       ├── kaleidoscope.glsl
│       ├── bloom.glsl
│       └── feedback.glsl
├── src/
│   ├── core/
│   │   ├── layer.py             # Layer 抽象基底
│   │   ├── stack.py             # LayerStack (FBO 管理・合成)
│   │   ├── shader_layer.py
│   │   ├── effect_layer.py
│   │   └── particle_layer.py
│   ├── audio/
│   │   ├── analyze.py           # 事前解析 → .npz
│   │   └── player.py            # sounddevice 再生 + 時刻
│   ├── scene/
│   │   ├── schema.py            # TOML スキーマ (pydantic)
│   │   └── binding.py           # uniform ← 特徴量
│   ├── render/
│   │   ├── preview.py           # ライブプレビュー
│   │   └── offline.py           # mp4 書き出し
│   └── ui/
│       └── imgui_panel.py       # パラメータ調整 GUI
├── scenes/
│   └── song01.toml
├── songs/
│   └── song01/{drums,bass,melody,pad}.wav
└── cache/
    └── song01.features.npz
```
