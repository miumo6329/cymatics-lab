# Cymatics Lab

数式ベースのパターンを音楽（ステム分離済み）に連動させて生成・合成するビジュアライザ。
詳細設計は [docs/design.md](docs/design.md) を参照。

## 開発ロードマップ

各ステップは独立して動作確認できる順序になっている。完了したらチェックを入れる。

- [ ] **Step 1 — MVP**: 単一フラグメントシェーダを画面に表示。`time` uniform 送信のみ。Nishitsuji コードを動かす
- [ ] **Step 2 — Hot reload**: `watchdog` でシェーダ変更検知 → 再コンパイル
- [ ] **Step 3 — Audio sync**: `sounddevice` で曲再生、再生位置を `time` に置換
- [ ] **Step 4 — Layer abstraction**: `ShaderLayer` クラス、`LayerStack` で 2 枚合成
- [ ] **Step 5 — Effect layer**: 万華鏡 `effects/kaleidoscope.glsl` を Effect レイヤーとして追加
- [ ] **Step 6 — Scene file**: TOML からレイヤー構成を読込
- [ ] **Step 7 — Audio binding**: 事前解析済み特徴量を時刻 lookup → uniform へ
- [ ] **Step 8 — GUI**: `imgui-bundle` でレイヤー ON/OFF・スライダ
- [ ] **Step 9 — Offline render**: mp4 書き出し（固定 fps・固定サンプル時刻でループ）
- [ ] **Step 10 — Particle / Attractor レイヤー**: compute shader か instanced rendering で点群

Step 3 完了時点で「Nishitsuji 風フラクタルが自分の曲に合わせて動く」状態に到達する。ここで一度成功体験を取れる設計。

## 開発メモ

- 略語・このアプリ固有のドメイン用語は、各ソースファイル冒頭のコメントに記載する（プロジェクト全体の用語集は作らない）
- 主要な技術スタックと依存ライブラリは [docs/design.md §6](docs/design.md) を参照
- シーン TOML のスキーマと音声バインディングモデルは [docs/design.md §4-5](docs/design.md)
