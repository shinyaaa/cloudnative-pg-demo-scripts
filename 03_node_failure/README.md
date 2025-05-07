## 事前準備
以下のスクリプトを実行します。
```bash
./cleanup.sh
./prepare.sh
```

## シナリオ
（ノード障害を起こしておく）
```bash
NODE=$(kubectl get pod pgcluster-prod-1 -o jsonpath='{.spec.nodeName}')
kubectl delete node $NODE
```

DBに接続しようとしますが繋がりません。
```bash
kubectl exec -it pgcluster-prod-1 -- psql
```

Podの状況を確認してみます。
```bash
kubectl get pod -o wide
kubectl describe pod pgcluster-prod-1
```

特にエラーは出ていません。ノードの状況を確認してみます。
```bash
kubectl get node
```

`pgcluster-prod-1`が起動するはずのノードが`NotReady`（または存在しない状況）になっています。
他のPodも同じノードに起動していたため、全Podがノード障害の影響を受けてしまいました。

このような状況から復旧するには、ノードを復旧させるか、Podをバックアップから復旧するしかありません。
バックアップから復旧したうえで、二度とこのような障害を起こさないように対策を取りましょう。

[pgcluster-backup.yaml](pgcluster-backup.yaml)
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pgcluster-backup
spec:
  instances: 3

  bootstrap:
    recovery:
      backup:
        name: pgcluster-prod-backup

  storage:
    size: 1Gi
```

このままだと先ほどと同じようにノード障害により全てのPodが止まってしまう可能性があるので、ノード障害に耐えられるような設定にしましょう。
PostgreSQL用のノードには`cnds2025.com/role=postgres`というラベルを事前に付けていたので、それを使ってAffinityの設定をします。
```diff
>   affinity:
>     enablePodAntiAffinity: true
>     topologyKey: kubernetes.io/hostname
>     podAntiAffinityType: required
>     nodeSelector:
>       cnds2025.com/role: postgres
>     tolerations:
>     - key: cnds2025.com/role
>       operator: Equal
>       value: postgres
>       effect: NoSchedule
```

マニフェストを適用します。
```bash
kubectl apply -f pgcluster-backup.yaml
```

新規クラスタが別々のノードに分散して起動したことを確認します。
```bash
kubectl get pod -o wide
```

これで無事に復旧でき、旧クラスタは不要になったので削除しておきます。
```bash
kubectl delete cluster pgcluster-prod
```

## 事後処理
以下のスクリプトを実行します。
```bash
./cleanup.sh
```
