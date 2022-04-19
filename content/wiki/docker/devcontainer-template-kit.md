---
title: "Develop container (Remote Container）使用時のテンプレート集"
date: 2022-04-11T12:44:32Z
draft: false
type: docs
tags: []
categories: ["Docker"]
description: Dockerfile，特に開発用コンテナ（ビルド用コンテナではない）を効率よくビルドするためのポイントをまとめたものです．
---
# 前書き・概要W
この記事はメモ書きであることをご理解ください．内容としては稚拙ですので，ご指摘やアドバイスあればぜひお声がけください．

Dockerfile，特に開発用コンテナ（ビルド用コンテナではない）を効率よくビルドするためのポイントをまとめたものです．

## 参考資料
| 概要（タイトル） | URL |
| :-- | :-- |
| DeepLab内で実装されているDockerfile | https://github.com/StreamWest-1629/DeepLab |
| Dockerfileリファレンス（日本語訳） | https://matsuand.github.io/docs.docker.jp.onthefly/engine/reference/builder/ |
| Composeファイルリファレンス（バージョン3，日本語訳） | https://matsuand.github.io/docs.docker.jp.onthefly/compose/compose-file/compose-file-v3/ |

# あると便利な環境変数
| 環境変数 | 内容 | 入れておくべき値 | 備考 |
| :-- | :-- | :-: | :-- |
| `DEBIAN_FRONTEND` | インタラクティブな動作についての環境変数 | `nointeractive` | - |
| `TZ` | タイムゾーン | 各自のタイムゾーン（例: `Asia/Tokyo`） | ARGとして指定しておくのはアリ（面倒だから固定にしがちだけど） |

よって，まとめると以下のようになる．
```Dockerfile
ARG tz=Asia/Tokyo
ENV DEBIAN_FRONTEND=nointeractive \
    TZ=${tz}
```

# ツールのインストールに関する話題
## S3バケットのマウント方法（Dockerfileから見たとき）
Dockerにはボリュームドライバーなるものがあるらしいがよくわからなかったので，普通に　`s3fs` または `goofys` をDockerfile内でインストールした方が正直手っ取り早い．私は `goofys` を使うことにした．

goofysに関して，Golangで開発が進んでいるので，気持ち的にはGolangをインストールしてから `go install` を実行したいところだ．しかし，安定的な動作が他のパッケージと比べても割と低い印象（あくまで個人の感想です）なので，バイナリを直接ダウンロードした方が速い．

内部では `fuse` などを使用しているのでしっかりインストールする．

```Dockerfile
ARG goofys_version=0.24.0

RUN apt-get install -y wget fuse-emulator-utils fuse && \
    wget https://github.com/kahing/goofys/releases/download/v${goofys_version}/goofys -P /usr/local/bin/ && \
    chmod +x /usr/local/bin/goofys
```

# マルチステージビルドに関する話題
## Golangのライブラリ依存
少なくともGolangに関して，ビルド用コンテナでビルドしたバイナリが Official Imageである `alpine` で実行する際にエラーが発生するという問題が起きるようだ．

どうやら `alpine` においてライブラリが不足していることによって発生する問題のようである．

一時しのぎとして以下のコマンドを実行することで解決するが，もっとスマートな方法があればよいと思う．
```Dockerfile
RUN mkdir /lib64 && \
    ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2
```

ネット上で探す対応策は割とこの方法が多いように感じた．他の方法として， `GOARCH=amd64` でビルドするという方法も試したが，AWS上で実行に失敗しているためいまいち有効な手ではないように感じた．

# docker-compose.ymlでの話題
## GPUの有効化
ほぼコピペ．`count` のところでGPUの指定をすることができるが，そもそもGPUを使うコンテナをバカスカ建てることも少ないので `all` にしがち．
```yml
services:
  gpu_container:
  　...
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: ["gpu"]
```

# ビルド高速化の話題
## `RUN apt-get install -y ...` を行う前に
近くのリージョンの日本サーバーを用いた方が物理的に距離が近いのでインストールが速い．

しかし，近隣のサーバーをmirrorsで検索をかけるとhttp通信以外を弾く環境などで上手く回らない可能性があるため，厳密に指定した方が良いことの方が多そうである．
```Dockerfile
RUN sed -i 's@archive.ubuntu.com@ftp.jaist.ac.jp/pub/Linux@g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y (APT packages...)
```

## 各 `RUN` におけるキャッシュ
`npm` や `pip` など，各言語に応じて様々なキャッシュ方法があると思うが，Dockerfileの `RUN` 内で `--mount` 引数を与えることによってキャッシュを持たせることができ，ビルドの高速化を図ることができる．

```Dockerfile
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install -r requirements.txt
```

各言語でどのようなキャッシュを持たせられるのかについては，Github Actionsのキャッシュ機能である [`actions/cache`](https://github.com/actions/cache) のImplementation Examplesでわかりやすく解説しているので参考にした方が良い．
