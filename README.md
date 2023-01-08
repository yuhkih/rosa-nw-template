
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
    デプロイ完了まで待ちます。

1. デプロイが完了したら AWS Cosole の `EC2`-> `仮想プライベートクラウド` -> `エンドポイント` に行きます。

    そこで、`エンドポイントタイプ` が  `GatewayLoadBalancer`　の エンドポイントID と所属する アベイラビリティゾーンの値を以下のようにメモします。

    ```
    [詳細タブのエンドポイントID]     [サブネットタブのアベイラビリティーゾーン]
    vpce-07fadabe59262d01e         ap-northeast-1a (apne1-az4)
    vpce-025ad3e7584202ebf         ap-northeast-1c (apne1-az1)
    vpce-091fc77824f78efd3         ap-northeast-1d (apne1-az2)
    ```

1. AWS Console で、`VPC` -> `仮想プライベートクラウド` -> `ルートテーブル` に行きます。
    `multiaz-NatgwRouteTable1` という名前のルートテーブルを探します。このルートテーブルの `ルート`タブを見ます。
    ```
    10.0.0.0/16     local
    ```
    となっている所を
    ```    
    10.0.0.0/16     <各 Zone の Firewall Endpoint の値>
    ```
    のようにに置き換えます。
    
    ルートテーブルの`タグ`の画面に AZ が書いてあるので、それに会わせて、同じ AZ に所属する先ほどメモした `エンドポイント` (=ゲートウェイロードバランサーのエンドポイント) を指定していきます。

    ルートテーブルの編集画面から`ゲートウェイロードバランサーのエンドポイント` を選ぶと手で入力しなくても、リスト形式で表示されます。

    この作業を `multiaz-NatgwRouteTable1` `multiaz-NatgwRouteTable2` `multiaz-NatgwRouteTable3` に対して合計3回作業します。間違えると動作がおかしくなるので良く確認しましょう。
    
    これで以下の構成の Network がデプロイされた事になります。

<絵:TBD>


# PrivateLink を使用した RHOAM 用 ROSA Cluster のインストール

1. CloudFormation の画面で、作成したスタックを選択し「出力」のタブに行くと以下のように Private Subnet の ID が表示されているはずです。PrivateLink を使ったインストールには、インストール時にこの IDの値を聞かれるのでメモしておきます。

    ```
    PrivateSubnetID1 subnet-098e7998da1721a95 Private Subnet ID1
    PrivateSubnetID2 subnet-047a7fa3fb3e1307e Private Subnet ID2
    PrivateSubnetID3 subnet-0c73a76a9757a2174 Private Subnet ID3
    ```

1. ROSA の作成に必要な Role と Policy を作成します。
    ```
    rosa create account-roles -m auto -y
    ```

1. ROSA のクラスターをデプロイします。
RHOAM の要件として、Node 数は最低4本以上の Worker Node 必要です。
Multi AZ 構成では 3の倍数である必要があるので 6本を指定します。
    ```bash
    rosa create cluster --sts
    I: Enabling interactive mode
    ? Cluster name: mycluster
    ...
    ...
    ? External ID (optional): 
    ? Operator roles prefix: mycluster-r6h2
    ? Multiple availability zones (optional): Yes
    ? AWS region: ap-northeast-1
    ? PrivateLink cluster (optional): Yes
    ? Subnet IDs (optional):  [Use arrows to move, space to select, <right> to    all, <left> to none, type to filter, ? for more help]
    [ ]  subnet-0872f119b038bf6fa (ap-northeast-1c)
    [ ]  subnet-0591073b34256e366 (ap-northeast-1d)
    [x]  subnet-098e7998da1721a95 (ap-northeast-1d)
    [ ]  subnet-0ad6cc99b8f3eb93c (ap-northeast-1d)
    [ ]  subnet-008441a144bcdb32f (ap-northeast-1a)
    [x]  subnet-047a7fa3fb3e1307e (ap-northeast-1a)
    [x]  subnet-0c73a76a9757a2174 (ap-northeast-1c)
    ...
    ...
    ```
    - Multiple availability zones (optional)は Yes です。
    - AWS region は、 ap-northeast-1 です。
    - PrivateLink cluster (optional)は Yes にしてください。
    - PrivateLink を使った Private Cluster の場合は、途中で 3つのサブネットＩＤを指定するように指示されるので、前述のメモしてあった Private サブネットの IDを入力します。

1. 必要な AWS の IAM Role と、OIDC Provider を作成します。
    ```
    ClusterName=<クラスター名>
    rosa create operator-roles -y -m auto --cluster $ClusterName
    rosa create oidc-provider -y -m auto --cluster $ClusterName
    ```
    (この作業をしないと rosa create cluster が途中で止まったままになっています)
1. インストールが終わるまで待ちます。
    ```
    rosa logs install -c $ClusterName --watch
    ```
1. インストールが完了したら管理者ユーザーを作成します。
    ```
    rosa create admin -c $ClusterName
    ```
    ログインできるようになるまで、5分程度かかる事があります。
    この時出てきた管理者用のログインコマンドは忘れずにメモしておきます。

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
1. rosa CLI を使って RHOAM をインストールします。(現状 STS 構成では GUIでの導入ができません)
    ```
    rosa install addon --cluster <cluster-name> managed-api-service -y --addon-resource-required true --rosa-cli-required true --billing-model standard
    ```




# 踏み台用 VPC / Transit Gateway と踏み台のデプロイ


1. 以下の CloudFormation のテンプレートを使用してスタックを作成します。
    ```
    bastion-vpc-and-transit-gw-mz.yaml
    ```
    この CloudFormation Template によって、Bastion 用の VPCとTransit Gateway が構成されます。
    PrivateLink の場合は、ROSA のドメインは、ROSA の VPCからのみ解決できるようになっています。

1. ROSA の VPC の Route 53 の 設定を編集します。

    この設定は、現在サポートされるかどうか不明なので、設定が取り消される可能性がある事に注意してください。その場合は、必要なドメイン名とホスト名を bastion の /etc/hosts に登録しておく必要があります。

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

    この端末から oc コマンドなどが実行できるはずです。
    - 踏み台サーバー作成時に oc コマンド等が自動でインストールされているはずですが、まれに失敗している場合があるので、その場合は手動でインストールして下さい。
