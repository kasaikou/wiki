---
title: "Usage of Type Params"
date: 2022-04-17T06:25:12Z
draft: true
type: docs
tags: []
categories: ["Golang"]
---

# 前書き・概要
この記事はメモ書きであることをご理解ください．内容としては稚拙ですので，ご指摘やアドバイスあればぜひお声がけください．

この記事はGolangの1.18から追加された型パラメータの基本的なユースケースについて検討したものです．

## 参考資料
| 概要（タイトル） | URL |
| :-- | :-- |
| mattn/go-generics-example | https://github.com/mattn/go-generics-example |

# アルゴリズム系
ボクが書くよりも人の書いたやつを見た方が速そう．

参考資料読んで．

# 部分テスト分割インターフェイス
SQL系で作りがちなインターフェイス．

あるプログラムを実装したときにそのプログラムをテストする際に必要な関数だけを型情報として与えることができる．
```go

type SQLDriver[Exec interface{}] {
    // make transaction
    Tx(func(fn Exec) error) (internalErr error, err error)
    // close connection
    Close() error
}

// how to use in testing

import "testing"

func TestGetName(t *testing.T) {
    type TestSQLExec interface {
        GetName(id string) (name string, err error)
    }
    
    driver := SQLDriver[TestSQLExec](/* set sql driver instance */)
    defer driver.Close()

    // make transaction
    internalErr, err := driver.Tx(func(fn TestSQLExec) error {

        // test
        testId, testName := "test_id", "test_name"
        if name, err := fn.GetName("test_id"); err != nil {
            return err
        } else if name != testName {
            return errors.New("returned name is not right")
        }

        return nil
    })
    if internalErr != nil {
        t.Log(internalErr.Error())
        t.Fail()
    } else if err != nil {
        t.Log(err.Error())
        t.Fail()
    }
}
```

