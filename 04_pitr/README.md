## 事前準備
以下のスクリプトを実行します。
```bash
./cleanup.sh
./prepare.sh
```

## シナリオ
DBメンテナンス作業のため、DBに接続します。
```bash
kubectl exec -it pgcluster-prod-1 -- psql
```

DBメンテナンス作業をします。
```sql
SELECT CURRENT_TIMESTAMP;
SELECT * FROM orders;
```

DBメンテナンス作業中に間違えてテーブルを削除してしまいます。
```sql
DROP TABLE orders;
```

DBのバックアップはメンテナンス作業前に取得していたので、それから復旧します。
最新地点まで復旧してしまうとテーブルの削除まで実行されてしまうので、テーブル削除前にPITRします。
CloudNativePGではIn-placeのPITRには対応していないので、新規クラスタを作成します。

[pgcluster-pitr.yaml](pgcluster-pitr.yaml)
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pgcluster-pitr
spec:
  instances: 3

  bootstrap:
    recovery:
      backup:
        name: pgcluster-prod-backup
      recoveryTarget:
        targetTime: "<SELECT CURRENT_TIMESTAMP;のタイムスタンプで置換する>"

  storage:
    size: 1Gi
```

マニフェストを適用します。
```bash
kubectl apply -f pgcluster-pitr.yaml
```

新規クラスタが起動したことを確認します。
```bash
kubectl get cluster
```

新規クラスタに接続し、`orders`テーブルが削除されていないことを確認します。
```bash
kubectl exec -it pgcluster-pitr -- psql
```
```sql
SELECT * FROM orders;
```

これで無事に復旧でき、旧クラスタは不要になったので削除しておきます。
```bash
kubectl delete cluster pgcluster-prod
```

しかし、このままでは、アプリケーションの接続先のServiceを`pgcluster-prod-rw`から`pgcluster-pitr-rw`に変更する必要がありますが、できればアプリケーションの設定は変えたくありません。
そこで、[Adding Your Own Services](https://cloudnative-pg.io/documentation/1.25/service_management/#adding-your-own-services)を参考にServiceを追加します。
以下を`pgcluster-pitr`のマニフェストに追加します。
```diff
>   managed:
>     services:
>       additional:
>         - selectorType: rw
>           serviceTemplate:
>             metadata:
>               name: pgcluster-prod-rw
>             spec:
>               type: ClusterIP
>         - selectorType: ro
>           serviceTemplate:
>             metadata:
>               name: pgcluster-prod-ro
>             spec:
>               type: ClusterIP
>         - selectorType: r
>           serviceTemplate:
>             metadata:
>               name: pgcluster-prod-r
>             spec:
>               type: ClusterIP
```

マニフェストを適用します。
```bash
kubectl apply -f pgcluster-pitr.yaml
```

新しくServiceが追加されていることを確認します。
```bash
kubectl get svc
```

CloudNativePGが自動で作成するServiceが不要になったので削除します。
これらのServiceはCloudNativePGが管理しているので直接削除してはいけません。
そのため、[Disabling Default Services](https://cloudnative-pg.io/documentation/1.25/service_management/#disabling-default-services)を参考に元のServiceを削除します。
しかし、CloudNativePGの仕様では`rw`は削除できないので、`ro`と`r`だけ削除します。
以下を`pgcluster-pitr`のマニフェストに追加します。
```diff
>       disabledDefaultServices: ["ro", "r"]
```

マニフェストを適用します。
```bash
kubectl apply -f pgcluster-pitr.yaml
```

元の`ro`と`r`のServiceが削除されていることを確認します。
```bash
kubectl get svc
```

## 事後処理
以下のスクリプトを実行します。
```bash
./cleanup.sh
```
