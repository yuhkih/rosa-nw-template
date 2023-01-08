
# 作業環境

以下の環境をセットアップされている環境を前提としています。

- AWS CLI 
- rosa コマンド
- jq コマンド

# Multit AZ Network のデプロイ

1. 以下の CloudFormation のテンプレートを使用して、ROSA をインストールするためのネットワークを作成します。

```
rosa-awsfw-multiaz.yaml
```

1. 一部、CloudFormation ではデプロイできてない部分があるので、デプロイが完了した後、Routeテーブルを変種します。

1. AWS Cosole の EC2=>エンドポイントに行きます。
そこで、エンドポイントタイプ = GatewayLoadBalancer　の エンドポイントの ID と所属する アベイラビリティゾーンの値を以下のようにメモします。これらが　Firewall Endpoint の情報です。後で使用します。

```
　vpce-07fadabe59262d01e ap-northeast-1a (apne1-az4)
　vpce-025ad3e7584202ebf ap-northeast-1c (apne1-az1)
　vpce-091fc77824f78efd3 ap-northeast-1d (apne1-az2)
```

1. NatGateway の Route Table の編集

AWS Console で、VPC=> ルートテーブルに行きます。
NATGW のルートテーブルを探します。 デフォルトだと、`multiaz-NatgwRouteTable1` のような名前です。

`multiaz-NatgwRouteTable1` のルートのエントリーを確認します。

```
10.0.0.0/16     local
```

となっている所を

```
10.0.0.0/16     <各 Zone の Firewall Endpoint の値> 
```

 に置き換えます。

ルートテーブルの「タグ」の画面に AZ が書いてあるので、それに会わせて、Firewall Endpoint (=ゲートウェイロードバランサーのエンドポイント) を指定していきます。

ルートテーブルの編集画面から「ゲートウェイロードバランサーのエンドポイント」 を選ぶと手で入力しなくても、リスト形式で表示されます。AZを間違えないように指定していきます。



この作業を、AZ 毎の Nat Gateway に対して行います。
`multiaz-NatgwRouteTable1` `multiaz-NatgwRouteTable2` `multiaz-NatgwRouteTable3` に対して合計3回作業します。間違えると動作がおかしくなるので良く確認しましょう。


これで以下の構成の Network がデプロイされた事になります。

<絵>


# PrivateLink を使用した RHOAM 用 ROSA Cluster のインストール

CloudFormation の画面で、作成したスタックを選択し「出力」のタブに行くと以下のように Private Subnet の ID が表示されているはずです。PrivateLink を使ったインストールには、インストール時にこの IDの値を聞かれるのでメモしておきます。

```
PrivateSubnetID1 subnet-0a0778983ec208691 Private Subnet ID1
PrivateSubnetID2 subnet-09c7a951f3b1260a0 Private Subnet ID2
PrivateSubnetID3 subnet-075c6919da410b2a5 Private Subnet ID3
```

ROSA のクラスターをデプロイします。

RHOAM の要件として、Node 数は最低4本以上の Worker Node 必要です。
Multi AZ 構成では 3の倍数である必要があるので 6本を指定します。

```
rosa create cluster --sts
```

# RHOAM のデプロイ

1. SRE が RHOAM を管理できるように SRE用の AWS Policy を作成します。

```
cat <<EOM >"rhoam-sre-support-policy.json"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances",
                "rds:DescribeDBClusters",
                "rds:DescribeGlobalClusters",
                "rds:ModifyDBInstance",
                "rds:DeleteDBInstance",
                "rds:DescribeDBSnapshots",
                "rds:RestoreDBInstanceFromDBSnapshot",
                "elasticache:DescribeReplicationGroups",
                "elasticache:ModifyReplicationGroup",
                "elasticache:DescribeSnapshots",
                "elasticache:CreateReplicationGroup",
                "elasticache:DescribeCacheClusters",
                "elasticache:DeleteReplicationGroup",
                "sts:GetCallerIdentity",
                "tag:TagResources"
            ],
            "Resource": "*"
        }
    ]
}
EOM
```

1. 作成した Policy を SRE用の Role にアタッチします。

```
aws iam put-role-policy --role-name ManagedOpenShift-Support-Role --policy-name rhoam-sre-support-policy --policy-document "file://rhoam-sre-support-policy.json"
```

1．rosa CLI を使って RHOAM をインストールします。

```
rosa install addon --cluster <cluster-name> managed-api-service -y --addon-resource-required true --rosa-cli-required true --billing-model standard
```



# 踏み台用 VPC / Transit Gateway と踏み台のデプロイ


1. 以下の CloudFormation のテンプレートを使用してスタックを作成します。

 ```
bastion-vpc-and-transit-gw.yaml
 ```

この CloudFormation Template によって、Bastion 用の VPCとTransit Gateway が構成されます。


PrivateLink の場合は、ROSA のドメインは、ROSA の VPCからのみ解決できるようになっています。

ROSA の VPC の Route 53 の 設定を編集します。この設定は、現在サポートされるかどうか不明なので、設定が取り消される可能性がある事に注意してください。その場合は、必要なドメイン名とホスト名を bastion の /etc/hosts に登録しておく必要があります。

# 踏み台 EC2へのログイン

1. Linux の端末を2つ用意します。

1. Linux 端末1で以下のコマンドを実行します。

Publicネットワークにある踏み台 EC2 サーバーにログインします。ログアウトせずに、接続を保ったままにします。

```
port-forward.sh 1
```

1. Linux 端末2で以下のコマンドを実行します。

Privateネットワークにある踏み台 EC2 サーバーにログインします。

```
port-forward.sh 2
```

この端末から oc コマンドなどが実行できるはずです。踏み台サーバー作成時に oc コマンド等が自動でインストールされているはずですが、まれに失敗している場合があるので、その場合は手動でインストールして下さい。


# ブラウザーからのアクセス

<TBD>